import Flutter
import UIKit
import PushKit
import CallKit
import CryptoKit
import AVFoundation
import flutter_callkit_incoming

// Maps an arbitrary backend call ID to a deterministic UUIDv4 string so every
// CallKit report/endCall reference for the same call resolves to one UUID.
private func stableCallUUID(from id: String) -> String {
  guard !id.isEmpty else { return UUID().uuidString }
  let digest = SHA256.hash(data: Data(("murihspace-voip-call-" + id).utf8))
  let bytes = Array(digest)
  return String(
    format: "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x",
    bytes[0], bytes[1], bytes[2], bytes[3],
    bytes[4], bytes[5],
    (bytes[6] & 0x0F) | 0x40, bytes[7],
    (bytes[8] & 0x3F) | 0x80, bytes[9],
    bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
  )
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, PKPushRegistryDelegate {

  private var voipRegistry: PKPushRegistry?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Register for VoIP pushes. Unlike a silent FCM data push (which iOS
    // throttles), a PushKit VoIP push is allowed to wake a terminated app and
    // is the only reliable way to ring on iOS when the app is not running.
    // The token is handed to flutter_callkit_incoming, which forwards it to
    // Dart (DID_UPDATE_DEVICE_PUSH_TOKEN_VOIP) so it can be registered with the
    // backend for APNs delivery.
    let mainQueue = DispatchQueue.main
    let registry = PKPushRegistry(queue: mainQueue)
    registry.delegate = self
    registry.desiredPushTypes = [.voIP]
    voipRegistry = registry

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // If an accept/end happened while the plugin was not yet available, the
    // event was queued locally — deliver it now that the Dart listeners exist.
    VoIPFallbackCallProvider.shared.flushPendingEvents()

    // Lets the Dart call layer end phone-level calls that were reported by the
    // fallback provider (flutter_callkit_incoming can only end its own calls).
    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "VoIPFallbackBridge")
    let channel = FlutterMethodChannel(name: "murihspace/voip_fallback", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, _ in
      switch call.method {
      case "endActive":
        VoIPFallbackCallProvider.shared.requestEndActive()
      default:
        break
      }
    }
  }

  // MARK: - PKPushRegistryDelegate

  func pushRegistry(
    _ registry: PKPushRegistry,
    didUpdate credentials: PKPushCredentials,
    for type: PKPushType
  ) {
    let deviceToken = credentials.token.map { String(format: "%02x", $0) }.joined()
    let redacted = deviceToken.count > 8
      ? "\(deviceToken.prefix(4))...\(deviceToken.suffix(4)) (\(deviceToken.count) hex chars)"
      : "(short token)"
    print("[VoIP] didUpdate token: \(redacted)")
    SwiftFlutterCallkitIncomingPlugin.sharedInstance?.setDevicePushTokenVoIP(deviceToken)
  }

  func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
    print("[VoIP] token invalidated")
    SwiftFlutterCallkitIncomingPlugin.sharedInstance?.setDevicePushTokenVoIP("")
  }

  func pushRegistry(
    _ registry: PKPushRegistry,
    didReceiveIncomingPushWith payload: PKPushPayload,
    for type: PKPushType,
    completion: @escaping () -> Void
  ) {
    guard type == .voIP else {
      completion()
      return
    }

    let payloadDict = payload.dictionaryPayload
    // FCM may nest the custom keys under a "data" key; the raw VoIP dict has
    // them at the top level. Read from either.
    let d = (payloadDict["data"] as? [String: Any]) ?? payloadDict
    let rawId = d["id"].map { String(describing: $0) } ?? UUID().uuidString
    let callID = d["call_id"].map { String(describing: $0) } ?? rawId
    // CallKit requires a UUID for the CXProvider. Backend call IDs are not
    // UUIDs, so derive a stable UUIDv4 from the call ID instead of letting the
    // provider mint an unpredictable one — every report (and the endCall flow
    // that later references the same call) must resolve to the same UUID.
    let id = stableCallUUID(from: callID)
    let nameCaller = d["nameCaller"] as? String ?? "Unknown Caller"
    let handle = d["handle"] as? String ?? "Murihspace Call"
    let isVideo = (d["isVideo"] as? Bool) ?? (d["isVideo"] as? String == "true")
      || (d["is_video"] as? Bool) ?? (d["is_video"] as? String == "true")

    let data = flutter_callkit_incoming.Data(
      id: id,
      nameCaller: nameCaller,
      handle: handle,
      type: isVideo ? 1 : 0
    )
    data.extra = [
      "call_id": d["call_id"] ?? callID,
      "room_name": d["room_name"] ?? "",
      "livekit_host": d["livekit_host"] ?? "",
      "livekit_token": d["livekit_token"] ?? "",
    ]

    // Report the call to CallKit. `completion` must always be invoked promptly
    // or iOS terminates the app for failing to report the VoIP push.
    guard let plugin = SwiftFlutterCallkitIncomingPlugin.sharedInstance else {
      // The Flutter engine / plugin is not up yet (e.g. push woke a terminated
      // app). Report the call with a local CXProvider so the OS ring UI still
      // appears, and forward the accepted/ended action to Dart via the plugin's
      // own event channel once it is available, so the in-app join flow works.
      VoIPFallbackCallProvider.shared.reportIncoming(data: data, completion: completion)
      return
    }
    plugin.showCallkitIncoming(data, fromPushKit: true) {
      completion()
    }
  }
}

// MARK: - Local CallKit fallback
//
// Used only when SwiftFlutterCallkitIncomingPlugin.sharedInstance is nil at
// push-handling time (Flutter engine not yet up). The plugin instance is not
// guaranteed to exist here, so answer/end(CallKit) actions are forwarded to
// Dart over the plugin's event channel via sendEventCustom rather than relying
// on the plugin's own CXProvider (which is not the one reporting these calls).

private final class VoIPFallbackCallProvider: NSObject, CXProviderDelegate {
  static let shared = VoIPFallbackCallProvider()

  private let provider: CXProvider
  private let callController = CXCallController()
  private var pendingPayloads: [String: NSDictionary] = [:]
  private var reportedUUIDs: Set<String> = []
  private let queueLock = NSLock()
  private var pendingEvents: [(event: String, body: NSDictionary, callUUID: String)] = []

  private override init() {
    let config = CXProviderConfiguration(localizedName: "MurihSpace")
    config.supportsVideo = true
    config.maximumCallsPerCallGroup = 1
    config.supportedHandleTypes = [.generic, .phoneNumber]
    provider = CXProvider(configuration: config)
    super.init()
    provider.setDelegate(self, queue: DispatchQueue.main)
  }

  func reportIncoming(data: flutter_callkit_incoming.Data, completion: @escaping () -> Void) {
    pendingPayloads[data.uuid] = data.toJSON() as NSDictionary
    reportedUUIDs.insert(data.uuid)
    let callUUID = UUID(uuidString: data.uuid) ?? UUID()
    let update = CXCallUpdate()
    update.remoteHandle = CXHandle(type: .generic, value: data.handle)
    update.localizedCallerName = data.nameCaller
    update.hasVideo = data.type == 1
    provider.reportNewIncomingCall(with: callUUID, update: update) { error in
      if let error = error {
        print("[VoIP] fallback CallKit report failed: \(error.localizedDescription)")
      }
      completion()
    }
  }

  /// Ends every call this provider reported (used when the in-app layer hangs
  /// up, since flutter_callkit_incoming cannot end calls it did not report).
  func requestEndActive() {
    let uuids = reportedUUIDs
    reportedUUIDs.removeAll()
    for uuidString in uuids {
      guard let callUUID = UUID(uuidString: uuidString) else { continue }
      callController.request(CXTransaction(action: CXEndCallAction(call: callUUID))) { error in
        if let error = error {
          print("[VoIP] fallback end request failed: \(error.localizedDescription)")
        }
      }
    }
  }

  func providerDidReset(_ provider: CXProvider) {
    print("[VoIP] fallback provider did reset")
  }

  func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
    action.fulfill()
    forwardEvent("com.hiennv.flutter_callkit_incoming.ACTION_CALL_ACCEPT", callUUID: action.callUUID.uuidString)
  }

  func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
    action.fulfill()
    reportedUUIDs.remove(action.callUUID.uuidString)
    forwardEvent("com.hiennv.flutter_callkit_incoming.ACTION_CALL_ENDED", callUUID: action.callUUID.uuidString)
  }

  func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
    // Muting is handled by the LiveKit session in-app; acknowledge so the OS
    // keeps its mute state consistent for the cold-start path.
    action.fulfill()
  }

  func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
    // The cold-start path renders no system audio, but LiveKit needs an active
    // .playAndRecord session to carry call audio after the engine comes up.
    do {
      try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth, .defaultToSpeaker])
      try audioSession.setActive(true)
    } catch {
      print("[VoIP] fallback audio activation failed: \(error.localizedDescription)")
    }
  }

  func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {}

  /// Delivers any accept/end events that were queued while the plugin was not
  /// yet initialized. Called once the Flutter engine + plugin are registered.
  func flushPendingEvents() {
    guard let plugin = SwiftFlutterCallkitIncomingPlugin.sharedInstance else { return }
    queueLock.lock()
    let events = pendingEvents
    pendingEvents.removeAll()
    queueLock.unlock()
    for (event, body, callUUID) in events {
      plugin.sendEventCustom(event, body: body)
      // The same payload may still be needed for a subsequent end event, so
      // only drop it after the end has actually been delivered.
      if event.hasSuffix("ACTION_CALL_ENDED") {
        pendingPayloads.removeValue(forKey: callUUID)
      }
    }
  }

  private func forwardEvent(_ event: String, callUUID: String) {
    let isEnd = event.hasSuffix("ACTION_CALL_ENDED")
    guard let payload = pendingPayloads[callUUID] else { return }
    guard let plugin = SwiftFlutterCallkitIncomingPlugin.sharedInstance else {
      // Plugin not up yet — keep the event so it is flushed after registration
      // instead of dropping the answer/end.
      queueLock.lock()
      pendingEvents.append((event, payload, callUUID))
      queueLock.unlock()
      return
    }
    plugin.sendEventCustom(event, body: payload)
    if isEnd {
      pendingPayloads.removeValue(forKey: callUUID)
    }
  }
}
