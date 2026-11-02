// StationReader — a second, listen-only connection to a radio station.
//
// Copyright (C) 2026, Togaware Pty Ltd
//
// Licensed under the GNU General Public License, Version 3 (the "License");
//
// License: https://opensource.org/license/gpl-3-0

import AudioToolbox
import Foundation

/// Reads a station's stream and hands its audio, decoded, to [emit].
///
/// A SEPARATE CONNECTION FROM THE PLAYER. just_audio plays through AVPlayer,
/// which gives no access to the decoded samples of a live stream, and
/// MTAudioProcessingTap does not work for HLS at all. So captions open their
/// own connection, and only while captions are on.
///
/// Progressive streams (Icecast, Shoutcast) are read as they arrive. HLS,
/// recognised by its content type, is followed by polling the playlist and
/// fetching each new segment, the way a player would.

final class StationReader: NSObject, URLSessionDataDelegate {
  enum Event {
    case samples(Data)
    case failed(code: String, message: String)
    case ended
  }

  private static let userAgent = "RadioPod (+https://github.com/gjwgit/radiopod)"

  private let url: URL
  private let emit: (Event) -> Void
  private let queue = DispatchQueue(label: "au.togaware.radiopod.radio_pcm")

  private var decoder: PcmDecoder?
  private var session: URLSession?
  private var hlsTask: Task<Void, Never>?
  private var hint: AudioFileTypeID = 0

  /// Guarded by [queue]. Once either is set nothing more is emitted.

  private var stopped = false
  private var finished = false
  private var switchedToHls = false

  init(url: URL, sampleRate: Double, emit: @escaping (Event) -> Void) {
    self.url = url
    self.emit = emit
    super.init()

    // A fifth of a second per event: frequent enough for words to appear as
    // they are spoken, few enough that the channel is not busy.

    decoder = PcmDecoder(sampleRate: sampleRate, chunkFrames: Int(sampleRate / 5)) {
      [weak self] data in
      self?.emitOnce(.samples(data), final: false)
    }
  }

  func start() {
    let config = URLSessionConfiguration.default
    config.requestCachePolicy = .reloadIgnoringLocalCacheData
    config.timeoutIntervalForRequest = 30

    let delegateQueue = OperationQueue()
    delegateQueue.underlyingQueue = queue
    delegateQueue.maxConcurrentOperationCount = 1

    let session = URLSession(configuration: config, delegate: self, delegateQueue: delegateQueue)
    self.session = session

    // No Icy-MetaData header: without it the server sends pure audio, with
    // no metadata blocks interleaved for the parser to trip over.

    var request = URLRequest(url: url)
    request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
    session.dataTask(with: request).resume()
  }

  func stop() {
    queue.async {
      self.stopped = true
      self.hlsTask?.cancel()
      self.session?.invalidateAndCancel()
      self.decoder?.close()
      self.decoder = nil
    }
  }

  /// Must be called on [queue].

  private func emitOnce(_ event: Event, final: Bool) {
    if stopped || finished { return }
    if final { finished = true }
    emit(event)
  }

  private func fail(_ code: String, _ message: String) {
    emitOnce(.failed(code: code, message: message), final: true)
    session?.invalidateAndCancel()
    hlsTask?.cancel()
  }

  // ── Progressive streams ─────────────────────────────────────────────────

  func urlSession(
    _ session: URLSession,
    dataTask: URLSessionDataTask,
    didReceive response: URLResponse,
    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
  ) {
    if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
      completionHandler(.cancel)
      fail("http", "The station answered with HTTP \(http.statusCode).")
      return
    }

    let mime = (response.mimeType ?? "").lowercased()
    let finalUrl = response.url ?? url

    if mime.contains("mpegurl") || finalUrl.pathExtension.lowercased() == "m3u8" {
      completionHandler(.cancel)
      switchedToHls = true
      startHls(finalUrl)
      return
    }

    if mime.contains("ogg") || mime.contains("opus") || mime.contains("flac") {
      completionHandler(.cancel)
      fail("format", "This station streams Ogg, which cannot yet be captioned.")
      return
    }

    if mime.hasPrefix("text/") {
      completionHandler(.cancel)
      fail("format", "The station address returned a web page, not audio.")
      return
    }

    hint = Self.hint(mime: mime, url: finalUrl)
    completionHandler(.allow)
  }

  func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
    if stopped || finished { return }
    guard let decoder else { return }
    if !decoder.feed(data, hint: hint) {
      fail("format", decoder.failure ?? "The stream could not be decoded.")
    }
  }

  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    if switchedToHls { return }
    if let error {
      if (error as NSError).code == NSURLErrorCancelled { return }
      fail("network", error.localizedDescription)
    } else {
      emitOnce(.ended, final: true)
    }
  }

  static func hint(mime: String, url: URL) -> AudioFileTypeID {
    if mime.contains("mpeg") || mime.contains("mp3") { return kAudioFileMP3Type }
    if mime.contains("aac") || mime.contains("mp4a") { return kAudioFileAAC_ADTSType }

    switch url.pathExtension.lowercased() {
    case "mp3": return kAudioFileMP3Type
    case "aac", "aacp", "adts": return kAudioFileAAC_ADTSType
    default: return 0
    }
  }

  // ── HLS ─────────────────────────────────────────────────────────────────

  private func startHls(_ playlist: URL) {
    hlsTask = Task { [weak self] in
      await self?.followHls(playlist)
    }
  }

  private var isStopped: Bool { queue.sync { stopped || finished } }

  private func followHls(_ playlist: URL) async {
    do {
      var mediaUrl = playlist
      var text = try await fetchText(playlist)

      if Hls.isMaster(text) {
        guard let variant = Hls.lowestVariant(text, base: playlist) else { throw HlsError.noVariant }
        mediaUrl = variant
        text = try await fetchText(variant)
      }

      var demuxer = TsDemuxer()
      var next: Int?

      while !isStopped {
        let media = try Hls.media(text, base: mediaUrl)

        // Start three segments from the live edge, as players do, so the
        // audio captioned is close to the audio being heard.

        let last = media.sequence + media.segments.count
        if next == nil || next! < media.sequence { next = max(media.sequence, last - 3) }

        for (i, segment) in media.segments.enumerated() where media.sequence + i >= next! {
          if isStopped { return }
          let data = try await fetch(segment)
          next = media.sequence + i + 1

          let ok: Bool = queue.sync {
            guard !stopped, !finished, let decoder else { return true }

            if TsDemuxer.looksLikeTs(data) {
              let audio = demuxer.feed(data)
              return decoder.feed(audio, hint: demuxer.hint)
            }

            let hint: AudioFileTypeID =
              segment.pathExtension.lowercased() == "mp3" ? kAudioFileMP3Type : kAudioFileAAC_ADTSType
            return decoder.feed(Hls.stripId3(data), hint: hint)
          }
          if !ok {
            queue.sync { fail("format", decoder?.failure ?? "The stream could not be decoded.") }
            return
          }
        }

        if media.ended {
          queue.sync { emitOnce(.ended, final: true) }
          return
        }

        try await Task.sleep(nanoseconds: UInt64(max(media.targetDuration / 2, 1) * 1e9))
        text = try await fetchText(mediaUrl)
      }
    } catch {
      if isStopped || error is CancellationError { return }
      queue.sync { fail("network", error.localizedDescription) }
    }
  }

  private func fetchText(_ url: URL) async throws -> String {
    String(decoding: try await fetch(url), as: UTF8.self)
  }

  private func fetch(_ url: URL) async throws -> Data {
    try await withCheckedThrowingContinuation { continuation in
      var request = URLRequest(
        url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
      request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")

      URLSession.shared.dataTask(with: request) { data, response, error in
        if let error {
          continuation.resume(throwing: error)
        } else if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
          continuation.resume(
            throwing: NSError(
              domain: "radio_pcm", code: http.statusCode,
              userInfo: [
                NSLocalizedDescriptionKey: "The station answered with HTTP \(http.statusCode)."
              ]))
        } else {
          continuation.resume(returning: data ?? Data())
        }
      }.resume()
    }
  }
}
