import CarPlay
import Flutter
import UIKit

// CarPlay — the station library on the car's screen.
//
// Android Auto is served by audio_service's MediaBrowserService, but
// audio_service has no CarPlay support on iOS, so the car's screens are
// built here from CarPlay templates. Only the BROWSING is native. Playback
// still goes through the one RadioAudioHandler in Dart: a tap in the car is
// sent back over the channel and played exactly as a tap in the app would
// be, and audio_service's Now Playing info and remote commands are what the
// car's Now Playing screen and steering-wheel buttons already use.

/// One playable station, as reached through a browse folder.
struct CarPlayStation {
  /// The browse-tree media id, which also carries the folder the station was
  /// reached through, so Next and Previous stay inside that folder.
  let mediaId: String
  let stationId: String
  let title: String
  let subtitle: String?
  let artUri: URL?

  init?(_ map: [String: Any]) {
    guard let mediaId = map["mediaId"] as? String,
      let stationId = map["stationId"] as? String,
      let title = map["title"] as? String
    else { return nil }
    self.mediaId = mediaId
    self.stationId = stationId
    self.title = title
    self.subtitle = map["subtitle"] as? String
    self.artUri = (map["artUri"] as? String).flatMap(URL.init(string:))
  }
}

/// A playlist and the stations in it, in the playlist's own order.
struct CarPlayPlaylist {
  let id: String
  let title: String
  let subtitle: String?
  let stations: [CarPlayStation]

  init?(_ map: [String: Any]) {
    guard let id = map["id"] as? String, let title = map["title"] as? String
    else { return nil }
    self.id = id
    self.title = title
    self.subtitle = map["subtitle"] as? String
    self.stations = (map["stations"] as? [[String: Any]] ?? []).compactMap(CarPlayStation.init)
  }
}

/// The method channel between Dart and the CarPlay scene.
///
/// Dart pushes the library whenever it changes and says which station is on
/// air; the car sends back the media id of a station the driver tapped. The
/// bridge outlives any one CarPlay connection, so the library is already to
/// hand when the car is plugged in, rather than being requested and waited
/// for with the driver looking at an empty list.
final class CarPlayBridge {
  static let shared = CarPlayBridge()

  private static let channelName = "com.togaware.radiopod/carplay"

  private var channel: FlutterMethodChannel?

  /// Nil until Dart has published the library for the first time, so the car
  /// can say it is loading rather than that there are no stations.
  private(set) var stations: [CarPlayStation]?
  private(set) var playlists: [CarPlayPlaylist] = []
  private(set) var nowPlayingStationId: String?

  /// Called on the main thread whenever the library or the station on air
  /// changes. Set by whichever CarPlay scene is connected.
  var onLibraryChanged: (() -> Void)?
  var onNowPlayingChanged: (() -> Void)?

  func attach(to messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { return result(nil) }
      let args = call.arguments as? [String: Any] ?? [:]

      switch call.method {
      case "setLibrary":
        self.stations = (args["stations"] as? [[String: Any]] ?? []).compactMap(CarPlayStation.init)
        self.playlists = (args["playlists"] as? [[String: Any]] ?? []).compactMap(CarPlayPlaylist.init)
        self.onLibraryChanged?()
        result(nil)
      case "setNowPlaying":
        self.nowPlayingStationId = args["stationId"] as? String
        self.onNowPlayingChanged?()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    self.channel = channel
  }

  /// Ask Dart to play [mediaId]. [completion] receives nil on success, or a
  /// message fit to show the driver when the station would not start.
  func play(mediaId: String, completion: @escaping (String?) -> Void) {
    guard let channel else { return completion("RadioPod is still starting up.") }
    channel.invokeMethod("playFromMediaId", arguments: mediaId) { reply in
      if let error = reply as? FlutterError {
        completion(error.message ?? "The station could not be played.")
      } else if (reply as AnyObject) === FlutterMethodNotImplemented {
        completion("RadioPod is still starting up.")
      } else {
        completion(nil)
      }
    }
  }
}

/// The CarPlay scene: a tab bar of Stations and Playlists.
///
/// These are the two tabs of the app that make sense at the wheel. Search
/// needs a keyboard, which CarPlay does not give audio apps, and
/// Export/Import and Settings are not things to do while driving, so they
/// stay on the phone. The Now Playing screen is the system's own, reached
/// from the button CarPlay adds once something is on air.
class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
  private let bridge = CarPlayBridge.shared
  private var interfaceController: CPInterfaceController?

  private lazy var stationsTemplate: CPListTemplate = {
    let template = CPListTemplate(title: "Stations", sections: [])
    template.tabTitle = "Stations"
    template.tabImage = UIImage(systemName: "radio")
    return template
  }()

  private lazy var playlistsTemplate: CPListTemplate = {
    let template = CPListTemplate(title: "Playlists", sections: [])
    template.tabTitle = "Playlists"
    template.tabImage = UIImage(systemName: "music.note.list")
    return template
  }()

  /// The playlist the driver has opened, if any, so a library change can
  /// refresh it in place instead of leaving stale rows on screen.
  private var openPlaylist: (id: String, template: CPListTemplate)?

  /// Station logos already fetched, keyed by URL, so scrolling back and forth
  /// or a library refresh does not download them again.
  private let artwork = NSCache<NSURL, UIImage>()

  // MARK: Connection

  func templateApplicationScene(
    _ templateApplicationScene: CPTemplateApplicationScene,
    didConnect interfaceController: CPInterfaceController
  ) {
    self.interfaceController = interfaceController

    bridge.onLibraryChanged = { [weak self] in self?.reload() }
    bridge.onNowPlayingChanged = { [weak self] in self?.refreshPlayingIndicators() }

    let tabs = CPTabBarTemplate(templates: [stationsTemplate, playlistsTemplate])
    interfaceController.setRootTemplate(tabs, animated: false, completion: nil)
    reload()
  }

  func templateApplicationScene(
    _ templateApplicationScene: CPTemplateApplicationScene,
    didDisconnect interfaceController: CPInterfaceController
  ) {
    bridge.onLibraryChanged = nil
    bridge.onNowPlayingChanged = nil
    openPlaylist = nil
    self.interfaceController = nil
  }

  // MARK: Building the lists

  /// Rebuild every list on screen from the bridge's copy of the library.
  private func reload() {
    guard let stations = bridge.stations else {
      let loading = ["Loading your stations…"]
      stationsTemplate.emptyViewTitleVariants = loading
      playlistsTemplate.emptyViewTitleVariants = loading
      stationsTemplate.emptyViewSubtitleVariants = []
      playlistsTemplate.emptyViewSubtitleVariants = []
      return
    }

    stationsTemplate.emptyViewTitleVariants = ["No stations yet"]
    stationsTemplate.emptyViewSubtitleVariants = [
      "Search for stations in RadioPod on your iPhone and save them to listen here."
    ]
    stationsTemplate.updateSections([CPListSection(items: stationItems(stations))])

    playlistsTemplate.emptyViewTitleVariants = ["No playlists yet"]
    playlistsTemplate.emptyViewSubtitleVariants = [
      "Create playlists in RadioPod on your iPhone to group your stations."
    ]
    playlistsTemplate.updateSections([CPListSection(items: playlistItems())])

    refreshOpenPlaylist()
  }

  private func playlistItems() -> [CPListItem] {
    bridge.playlists.prefix(Int(CPListTemplate.maximumItemCount)).map { playlist in
      let item = CPListItem(
        text: playlist.title,
        detailText: playlist.subtitle,
        image: UIImage(systemName: "music.note.list"))
      item.accessoryType = .disclosureIndicator
      item.handler = { [weak self] _, completion in
        self?.open(playlist)
        completion()
      }
      return item
    }
  }

  /// Rows for [stations], capped at what CarPlay allows in a list. Excess
  /// stations are simply not shown: the library order puts the ones the user
  /// reaches for most at the top.
  private func stationItems(_ stations: [CarPlayStation]) -> [CPListItem] {
    stations.prefix(Int(CPListTemplate.maximumItemCount)).map { station in
      let item = CPListItem(
        text: station.title,
        detailText: station.subtitle,
        image: UIImage(systemName: "radio"))
      item.userInfo = station.stationId
      item.isPlaying = station.stationId == bridge.nowPlayingStationId
      item.handler = { [weak self] _, completion in
        self?.play(station)
        completion()
      }
      loadArtwork(station.artUri, into: item)
      return item
    }
  }

  // MARK: Playlists

  private func open(_ playlist: CarPlayPlaylist) {
    let template = CPListTemplate(
      title: playlist.title,
      sections: [CPListSection(items: stationItems(playlist.stations))])
    template.emptyViewTitleVariants = ["This playlist is empty"]
    template.emptyViewSubtitleVariants = [
      "Add stations to it in RadioPod on your iPhone."
    ]
    openPlaylist = (playlist.id, template)
    interfaceController?.pushTemplate(template, animated: true, completion: nil)
  }

  /// Bring an open playlist up to date, or close it if it has been deleted.
  private func refreshOpenPlaylist() {
    guard let open = openPlaylist else { return }

    // The driver may have backed out since; stop tracking it if so.
    guard interfaceController?.templates.contains(where: { $0 === open.template }) == true else {
      openPlaylist = nil
      return
    }

    if let playlist = bridge.playlists.first(where: { $0.id == open.id }) {
      open.template.updateSections([CPListSection(items: stationItems(playlist.stations))])
    } else {
      openPlaylist = nil
      interfaceController?.popToRootTemplate(animated: true, completion: nil)
    }
  }

  // MARK: Playback

  private func play(_ station: CarPlayStation) {
    showNowPlaying()
    bridge.play(mediaId: station.mediaId) { [weak self] failure in
      guard let failure else { return }
      self?.showAlert("Could not play \(station.title)", failure)
    }
  }

  /// Move to the system Now Playing screen, unless it is already showing.
  private func showNowPlaying() {
    guard let controller = interfaceController,
      !(controller.topTemplate is CPNowPlayingTemplate)
    else { return }
    controller.pushTemplate(CPNowPlayingTemplate.shared, animated: true, completion: nil)
  }

  private func showAlert(_ title: String, _ message: String) {
    guard let controller = interfaceController else { return }
    let alert = CPAlertTemplate(
      titleVariants: [title, "Could not play station"],
      actions: [
        CPAlertAction(title: "OK", style: .cancel) { _ in
          controller.dismissTemplate(animated: true, completion: nil)
        }
      ])
    if controller.presentedTemplate != nil {
      controller.dismissTemplate(animated: false, completion: nil)
    }
    controller.presentTemplate(alert, animated: true, completion: nil)
    NSLog("[CarPlay] \(title): \(message)")
  }

  /// Mark the station on air in every list, without rebuilding the rows.
  private func refreshPlayingIndicators() {
    var templates: [CPListTemplate] = [stationsTemplate]
    if let open = openPlaylist { templates.append(open.template) }

    for template in templates {
      for section in template.sections {
        for case let item as CPListItem in section.items {
          item.isPlaying = (item.userInfo as? String) == bridge.nowPlayingStationId
        }
      }
    }
  }

  // MARK: Artwork

  /// Replace the placeholder with the station's logo once it has downloaded.
  ///
  /// Best-effort: a good share of Radio-Browser logos are missing or dead,
  /// and a row with the placeholder is perfectly usable.
  private func loadArtwork(_ url: URL?, into item: CPListItem) {
    guard let url else { return }
    if let cached = artwork.object(forKey: url as NSURL) {
      item.setImage(cached)
      return
    }

    URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
      guard let self, let data, let image = UIImage(data: data) else { return }
      let scaled = Self.fit(image, within: CPListItem.maximumImageSize)
      DispatchQueue.main.async {
        self.artwork.setObject(scaled, forKey: url as NSURL)
        item.setImage(scaled)
      }
    }.resume()
  }

  /// Scale [image] down to fit [size], keeping its proportions.
  private static func fit(_ image: UIImage, within size: CGSize) -> UIImage {
    let scale = min(size.width / image.size.width, size.height / image.size.height, 1)
    guard scale < 1 else { return image }
    let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
    return UIGraphicsImageRenderer(size: target).image { _ in
      image.draw(in: CGRect(origin: .zero, size: target))
    }
  }
}
