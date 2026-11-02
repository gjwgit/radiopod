// Hls — just enough HLS to follow a live radio playlist.
//
// Copyright (C) 2026, Togaware Pty Ltd
//
// Licensed under the GNU General Public License, Version 3 (the "License");
//
// License: https://opensource.org/license/gpl-3-0

import AudioToolbox
import Foundation

/// A media playlist, reduced to what following a live stream needs.

struct HlsMedia {
  var sequence = 0
  var targetDuration = 6.0
  var segments = [URL]()
  var ended = false
}

enum HlsError: LocalizedError {
  case encrypted
  case fragmentedMp4
  case noVariant

  var errorDescription: String? {
    switch self {
    case .encrypted: return "This station's stream is encrypted, so it cannot be captioned."
    case .fragmentedMp4: return "This station's stream format is not yet supported for captions."
    case .noVariant: return "This station's playlist has no stream to caption."
    }
  }
}

enum Hls {
  static func isMaster(_ text: String) -> Bool { text.contains("#EXT-X-STREAM-INF") }

  /// The lowest-bandwidth variant of a master playlist. Speech is resampled
  /// to 16 kHz mono anyway, so a richer variant would only cost data.

  static func lowestVariant(_ text: String, base: URL) -> URL? {
    var best: (bandwidth: Int, url: URL)?
    var bandwidth: Int?

    for raw in text.components(separatedBy: .newlines) {
      let line = raw.trimmingCharacters(in: .whitespaces)
      if line.hasPrefix("#EXT-X-STREAM-INF:") {
        bandwidth = attribute("BANDWIDTH", in: line).flatMap { Int($0) } ?? Int.max
        continue
      }
      guard let bw = bandwidth, !line.isEmpty, !line.hasPrefix("#") else { continue }
      bandwidth = nil
      guard let url = URL(string: line, relativeTo: base)?.absoluteURL else { continue }
      if best == nil || bw < best!.bandwidth { best = (bw, url) }
    }

    return best?.url
  }

  static func media(_ text: String, base: URL) throws -> HlsMedia {
    var media = HlsMedia()

    for raw in text.components(separatedBy: .newlines) {
      let line = raw.trimmingCharacters(in: .whitespaces)
      if line.isEmpty { continue }

      if line.hasPrefix("#EXT-X-MEDIA-SEQUENCE:") {
        media.sequence = Int(line.dropFirst("#EXT-X-MEDIA-SEQUENCE:".count)) ?? 0
      } else if line.hasPrefix("#EXT-X-TARGETDURATION:") {
        media.targetDuration = Double(line.dropFirst("#EXT-X-TARGETDURATION:".count)) ?? 6
      } else if line.hasPrefix("#EXT-X-KEY:") {
        if attribute("METHOD", in: line)?.uppercased() != "NONE" { throw HlsError.encrypted }
      } else if line.hasPrefix("#EXT-X-MAP:") {
        throw HlsError.fragmentedMp4
      } else if line.hasPrefix("#EXT-X-ENDLIST") {
        media.ended = true
      } else if !line.hasPrefix("#"), let url = URL(string: line, relativeTo: base)?.absoluteURL {
        media.segments.append(url)
      }
    }

    return media
  }

  /// The value of [name] in an attribute list such as
  /// `BANDWIDTH=64000,CODECS="mp4a.40.5"`, without any quotes.

  static func attribute(_ name: String, in line: String) -> String? {
    guard let range = line.range(of: "\(name)=") else { return nil }
    var rest = line[range.upperBound...]
    if rest.hasPrefix("\"") {
      rest = rest.dropFirst()
      return String(rest.prefix { $0 != "\"" })
    }
    return String(rest.prefix { $0 != "," })
  }

  /// Drop the ID3 tag that starts every packed-audio segment, which carries
  /// the segment's timestamp and is not audio.

  static func stripId3(_ data: Data) -> Data {
    let b = [UInt8](data.prefix(10))
    guard b.count == 10, b[0] == 0x49, b[1] == 0x44, b[2] == 0x33 else { return data }

    let size =
      Int(b[6] & 0x7f) << 21 | Int(b[7] & 0x7f) << 14 | Int(b[8] & 0x7f) << 7 | Int(b[9] & 0x7f)
    let footer = (b[5] & 0x10) != 0 ? 10 : 0
    let total = 10 + size + footer

    return total < data.count ? data.subdata(in: (data.startIndex + total)..<data.endIndex) : Data()
  }
}

/// Pulls the audio elementary stream out of MPEG transport stream segments.
///
/// Radio over HLS is usually AAC in TS. Only the audio is wanted, so this
/// reads the PAT to find the PMT, the PMT to find the audio PID, and then
/// strips the PES headers from that PID's packets. The payload left is plain
/// ADTS (or MP3), which PcmDecoder already understands.

struct TsDemuxer {
  private var pmtPid: Int?
  private var audioPid: Int?
  private var pes = [UInt8]()
  private var carry = [UInt8]()

  /// What the audio PID carries, for opening the parser.

  private(set) var hint: AudioFileTypeID = kAudioFileAAC_ADTSType

  static func looksLikeTs(_ data: Data) -> Bool {
    data.count >= 188 && data[data.startIndex] == 0x47
  }

  mutating func feed(_ data: Data) -> Data {
    let bytes = carry + [UInt8](data)
    carry = []

    var out = [UInt8]()
    var i = 0
    while i + 188 <= bytes.count {
      if bytes[i] != 0x47 {
        i += 1
        continue
      }
      packet(bytes, at: i, into: &out)
      i += 188
    }
    if i < bytes.count { carry = Array(bytes[i...]) }

    return Data(out)
  }

  private mutating func packet(_ b: [UInt8], at o: Int, into out: inout [UInt8]) {
    let start = (b[o + 1] & 0x40) != 0
    let pid = Int(b[o + 1] & 0x1f) << 8 | Int(b[o + 2])
    let control = (b[o + 3] >> 4) & 0x3

    // No payload in this packet, only adaptation (padding, clock).

    if control == 0 || control == 2 { return }

    var p = o + 4
    if control == 3 { p += 1 + Int(b[o + 4]) }
    let end = o + 188
    guard p < end else { return }
    let payload = b[p..<end]

    if pid == 0 {
      if start { readPat(payload) }
      return
    }
    if let pmt = pmtPid, pid == pmt {
      if start { readPmt(payload) }
      return
    }
    guard let audio = audioPid, pid == audio else { return }

    if start {
      flushPes(into: &out)
      pes = Array(payload)
    } else if !pes.isEmpty {
      pes.append(contentsOf: payload)
    }
  }

  /// One PSI section, located through the pointer field. Radio tables are
  /// tiny and always fit in the packet that starts them.

  private static func section(_ payload: ArraySlice<UInt8>) -> [UInt8]? {
    let a = Array(payload)
    guard let pointer = a.first else { return nil }
    let s = 1 + Int(pointer)
    guard s + 3 <= a.count else { return nil }
    let length = Int(a[s + 1] & 0x0f) << 8 | Int(a[s + 2])

    return Array(a[s..<min(a.count, s + 3 + length)])
  }

  private mutating func readPat(_ payload: ArraySlice<UInt8>) {
    guard let sec = Self.section(payload), sec.count >= 12 else { return }
    var i = 8
    while i + 4 <= sec.count - 4 {
      let program = Int(sec[i]) << 8 | Int(sec[i + 1])
      if program != 0 {
        pmtPid = Int(sec[i + 2] & 0x1f) << 8 | Int(sec[i + 3])
        return
      }
      i += 4
    }
  }

  private mutating func readPmt(_ payload: ArraySlice<UInt8>) {
    guard let sec = Self.section(payload), sec.count >= 16 else { return }
    let infoLength = Int(sec[10] & 0x0f) << 8 | Int(sec[11])
    var i = 12 + infoLength
    while i + 5 <= sec.count - 4 {
      let type = sec[i]
      let pid = Int(sec[i + 1] & 0x1f) << 8 | Int(sec[i + 2])
      let esInfo = Int(sec[i + 3] & 0x0f) << 8 | Int(sec[i + 4])
      switch type {
      case 0x0f:
        audioPid = pid
        hint = kAudioFileAAC_ADTSType
        return
      case 0x03, 0x04:
        audioPid = pid
        hint = kAudioFileMP3Type
        return
      default:
        i += 5 + esInfo
      }
    }
  }

  private mutating func flushPes(into out: inout [UInt8]) {
    defer { pes.removeAll(keepingCapacity: true) }
    guard pes.count >= 9, pes[0] == 0, pes[1] == 0, pes[2] == 1 else { return }
    let s = 9 + Int(pes[8])
    guard s < pes.count else { return }
    out.append(contentsOf: pes[s...])
  }
}
