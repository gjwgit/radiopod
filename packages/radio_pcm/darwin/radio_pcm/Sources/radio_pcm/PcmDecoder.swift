// PcmDecoder — compressed radio audio in, 16 kHz mono Float32 out.
//
// Copyright (C) 2026, Togaware Pty Ltd
//
// Licensed under the GNU General Public License, Version 3 (the "License");
//
// License: https://opensource.org/license/gpl-3-0

import AVFoundation
import AudioToolbox

/// Parses an elementary MP3 or ADTS AAC byte stream and resamples it to the
/// format the speech recogniser wants.
///
/// AudioFileStream finds the frames in whatever byte chunks the network
/// happens to deliver, and AVAudioConverter decodes, downmixes and resamples
/// them in one step. Neither is thread safe, so every call must come from the
/// same serial queue — StationReader owns that queue.

final class PcmDecoder {
  private let outputFormat: AVAudioFormat
  private let chunkFrames: Int
  private let onSamples: (Data) -> Void

  private var stream: AudioFileStreamID?
  private var inputFormat: AVAudioFormat?
  private var converter: AVAudioConverter?
  private var pending = [Float]()
  private var closed = false

  /// Packets decoded so far. A parse error before the first packet means the
  /// format is not one we can read; after it, a corrupt frame or two is just
  /// radio, and is skipped.

  private var packetsSeen = 0
  private var discontinuity = false

  /// Why decoding stopped, in words fit to show the listener.

  private(set) var failure: String?

  init?(sampleRate: Double, chunkFrames: Int, onSamples: @escaping (Data) -> Void) {
    guard
      let format = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: sampleRate,
        channels: 1,
        interleaved: false
      )
    else { return nil }

    outputFormat = format
    self.chunkFrames = chunkFrames
    self.onSamples = onSamples
  }

  deinit { close() }

  func close() {
    closed = true
    if let s = stream {
      AudioFileStreamClose(s)
      stream = nil
    }
    converter = nil
  }

  /// Feed the next bytes of the stream. [hint] is only consulted on the first
  /// call, when the parser is opened. Returns false once decoding has failed.

  @discardableResult
  func feed(_ data: Data, hint: AudioFileTypeID) -> Bool {
    if closed || failure != nil { return false }
    if data.isEmpty { return true }

    if stream == nil {
      let me = Unmanaged.passUnretained(self).toOpaque()
      let status = AudioFileStreamOpen(
        me,
        { client, stream, property, _ in
          Unmanaged<PcmDecoder>.fromOpaque(client).takeUnretainedValue()
            .propertyChanged(stream, property)
        },
        { client, bytes, packets, data, descriptions in
          Unmanaged<PcmDecoder>.fromOpaque(client).takeUnretainedValue()
            .packets(bytes, packets, data, descriptions)
        },
        hint,
        &stream
      )
      guard status == noErr, stream != nil else {
        failure = "The audio parser could not be started (\(status))."
        return false
      }
    }

    let flags: AudioFileStreamParseFlags = discontinuity ? .discontinuity : []
    discontinuity = false

    let status = data.withUnsafeBytes { raw -> OSStatus in
      guard let base = raw.baseAddress, let s = stream else { return noErr }
      return AudioFileStreamParseBytes(s, UInt32(raw.count), base, flags)
    }

    if status != noErr {
      if packetsSeen == 0 {
        failure = "This station's audio format cannot be read for captions."
      } else {
        discontinuity = true
      }
    }

    return failure == nil
  }

  // ── AudioFileStream callbacks ───────────────────────────────────────────

  fileprivate func propertyChanged(
    _ stream: AudioFileStreamID,
    _ property: AudioFileStreamPropertyID
  ) {
    guard property == kAudioFileStreamProperty_ReadyToProducePackets else { return }

    var base = AudioStreamBasicDescription()
    var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
    guard
      AudioFileStreamGetProperty(stream, kAudioFileStreamProperty_DataFormat, &size, &base)
        == noErr
    else {
      failure = "This station's audio format cannot be read for captions."
      return
    }

    // HE-AAC announces its full-quality layer only through the format list,
    // best first. Try that, and fall back to the plain AAC core it wraps.

    var candidates = [AudioStreamBasicDescription]()
    var listSize: UInt32 = 0
    if AudioFileStreamGetPropertyInfo(stream, kAudioFileStreamProperty_FormatList, &listSize, nil)
      == noErr, listSize > 0
    {
      let count = Int(listSize) / MemoryLayout<AudioFormatListItem>.size
      var items = [AudioFormatListItem](repeating: AudioFormatListItem(), count: count)
      if AudioFileStreamGetProperty(stream, kAudioFileStreamProperty_FormatList, &listSize, &items)
        == noErr, let first = items.first
      {
        candidates.append(first.mASBD)
      }
    }
    candidates.append(base)

    var cookie: Data?
    var cookieSize: UInt32 = 0
    if AudioFileStreamGetPropertyInfo(
      stream, kAudioFileStreamProperty_MagicCookieData, &cookieSize, nil) == noErr,
      cookieSize > 0
    {
      var bytes = [UInt8](repeating: 0, count: Int(cookieSize))
      if AudioFileStreamGetProperty(
        stream, kAudioFileStreamProperty_MagicCookieData, &cookieSize, &bytes) == noErr
      {
        cookie = Data(bytes)
      }
    }

    for var asbd in candidates {
      guard let format = AVAudioFormat(streamDescription: &asbd) else { continue }
      if let cookie { format.magicCookie = cookie }
      guard let conv = AVAudioConverter(from: format, to: outputFormat) else { continue }

      conv.downmix = true
      inputFormat = format
      converter = conv
      return
    }

    failure = "This station's audio codec cannot be decoded for captions."
  }

  fileprivate func packets(
    _ numberBytes: UInt32,
    _ numberPackets: UInt32,
    _ data: UnsafeRawPointer,
    _ descriptions: UnsafePointer<AudioStreamPacketDescription>?
  ) {
    guard !closed, let converter, let inputFormat, let descriptions, numberPackets > 0 else {
      return
    }
    packetsSeen += Int(numberPackets)

    var largest: UInt32 = 0
    for i in 0..<Int(numberPackets) {
      largest = max(largest, descriptions[i].mDataByteSize)
    }

    let buffer = AVAudioCompressedBuffer(
      format: inputFormat,
      packetCapacity: numberPackets,
      maximumPacketSize: Int(largest)
    )
    guard Int(numberBytes) <= buffer.byteCapacity else { return }

    memcpy(buffer.data, data, Int(numberBytes))
    if let out = buffer.packetDescriptions {
      for i in 0..<Int(numberPackets) { out[i] = descriptions[i] }
    }
    buffer.packetCount = numberPackets
    buffer.byteLength = numberBytes

    // Room for the whole block after resampling. HE-AAC packets carry 2048
    // frames, so that is the most any supported codec could produce per
    // packet.

    let perPacket = max(Double(inputFormat.streamDescription.pointee.mFramesPerPacket), 2048)
    let ratio = outputFormat.sampleRate / max(inputFormat.sampleRate, 1)
    let capacity = AVAudioFrameCount(Double(numberPackets) * perPacket * ratio) + 4096
    guard let out = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else {
      return
    }

    var supplied = false
    while true {
      out.frameLength = 0
      var error: NSError?
      let status = converter.convert(to: out, error: &error) { _, inputStatus in
        if supplied {
          inputStatus.pointee = .noDataNow
          return nil
        }
        supplied = true
        inputStatus.pointee = .haveData
        return buffer
      }

      if out.frameLength > 0, let channel = out.floatChannelData {
        pending.append(
          contentsOf: UnsafeBufferPointer(start: channel[0], count: Int(out.frameLength)))
      }

      // haveData means the output filled before the input was used up.

      if status != .haveData { break }
    }

    flush()
  }

  /// Hand on whole chunks. Small, steady chunks keep the platform channel
  /// cheap and let the recogniser work as the audio arrives.

  private func flush() {
    while pending.count >= chunkFrames {
      let chunk = pending.withUnsafeBufferPointer { Data(buffer: UnsafeBufferPointer(rebasing: $0[0..<chunkFrames])) }
      pending.removeFirst(chunkFrames)
      onSamples(chunk)
    }
  }
}
