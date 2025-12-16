import Flutter
import HawcxFramework
import UIKit

public class HawcxFlutterSdkPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private enum ErrorCode: String {
    case config = "hawcx.config"
    case sdk = "hawcx.sdk"
    case input = "hawcx.input"
    case storage = "hawcx.storage"
  }

  private let maxQueuedEvents = 50

  private var eventSink: FlutterEventSink?
  private var queuedEvents: [[String: Any]] = []

  private var hawcxSDK: HawcxSDK?
  private var authCallbackProxy: AuthCallbackProxy?
  private var sessionCallbackProxy: SessionCallbackProxy?
  private var pushDelegateProxy: PushDelegateProxy?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "hawcx_flutter", binaryMessenger: registrar.messenger())
    let instance = HawcxFlutterSdkPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)

    let events = FlutterEventChannel(name: "hawcx_flutter/events", binaryMessenger: registrar.messenger())
    events.setStreamHandler(instance)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "initialize":
      handleInitialize(call, result: result)
    case "authenticateV5", "authenticate":
      handleAuthenticate(call, result: result)
    case "submitOtpV5", "submitOtp":
      handleSubmitOtp(call, result: result)
    case "getDeviceDetails":
      handleGetDeviceDetails(call, result: result)
    case "webLogin":
      handleWebLogin(call, result: result)
    case "webApprove":
      handleWebApprove(call, result: result)
    case "storeBackendOAuthTokens":
      handleStoreBackendOAuthTokens(call, result: result)
    case "getLastLoggedInUser":
      handleGetLastLoggedInUser(call, result: result)
    case "clearSessionTokens":
      handleClearSessionTokens(call, result: result)
    case "clearUserKeychainData":
      handleClearUserKeychainData(call, result: result)
    case "clearLastLoggedInUser":
      handleClearLastLoggedInUser(call, result: result)
    case "setApnsDeviceToken":
      handleSetApnsDeviceToken(call, result: result)
    case "setPushToken":
      handleSetPushToken(call, result: result)
    case "userDidAuthenticate":
      handleUserDidAuthenticate(call, result: result)
    case "handlePushNotification":
      handlePushNotification(call, result: result)
    case "approvePushRequest":
      handleApprovePushRequest(call, result: result)
    case "declinePushRequest":
      handleDeclinePushRequest(call, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    DispatchQueue.main.async {
      self.eventSink = events
      self.flushQueuedEvents()
    }
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    DispatchQueue.main.async {
      self.eventSink = nil
    }
    return nil
  }

  // MARK: - Method handlers

  private func handleInitialize(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = asDict(call.arguments)

    let projectApiKey = (stringValue(args["projectApiKey"]) ?? stringValue(args["apiKey"]))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if projectApiKey.isEmpty {
      result(FlutterError(code: ErrorCode.config.rawValue, message: "projectApiKey (or apiKey) is required", details: nil))
      return
    }

    let baseUrl = resolveBaseUrl(args: args)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if baseUrl.isEmpty {
      result(FlutterError(code: ErrorCode.config.rawValue, message: "baseUrl is required", details: nil))
      return
    }

    var oauthConfig: HawcxOAuthConfig?
    if let oauthDict = asDictOrNil(args["oauthConfig"]) {
      do {
        oauthConfig = try makeOAuthConfig(from: oauthDict)
      } catch let flutterError as FlutterError {
        result(flutterError)
        return
      } catch {
        result(FlutterError(code: ErrorCode.config.rawValue, message: error.localizedDescription, details: nil))
        return
      }
    }

    DispatchQueue.main.async {
      self.hawcxSDK = HawcxSDK(projectApiKey: projectApiKey, baseURL: baseUrl, oauthConfig: oauthConfig)
      self.authCallbackProxy = AuthCallbackProxy(emitter: self)
      self.sessionCallbackProxy = SessionCallbackProxy(emitter: self)
      let pushProxy = PushDelegateProxy(emitter: self)
      self.pushDelegateProxy = pushProxy
      self.hawcxSDK?.pushAuthDelegate = pushProxy
      result(nil)
    }
  }

  private func handleAuthenticate(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let sdk = hawcxSDK else {
      result(FlutterError(code: ErrorCode.sdk.rawValue, message: "initialize must be called before authenticate", details: nil))
      return
    }
    guard let callback = authCallbackProxy else {
      result(FlutterError(code: ErrorCode.sdk.rawValue, message: "Auth callback not configured", details: nil))
      return
    }

    let args = asDict(call.arguments)
    let userId = (stringValue(args["userId"]) ?? stringValue(args["userid"]) ?? stringValue(call.arguments))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if userId.isEmpty {
      result(FlutterError(code: ErrorCode.input.rawValue, message: "userId cannot be empty", details: nil))
      return
    }

    DispatchQueue.main.async {
      sdk.authenticateV5(userid: userId, callback: callback)
      result(nil)
    }
  }

  private func handleSubmitOtp(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let sdk = hawcxSDK else {
      result(FlutterError(code: ErrorCode.sdk.rawValue, message: "initialize must be called before submitOtp", details: nil))
      return
    }
    let args = asDict(call.arguments)
    let otp = (stringValue(args["otp"]) ?? stringValue(call.arguments))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if otp.isEmpty {
      result(FlutterError(code: ErrorCode.input.rawValue, message: "otp cannot be empty", details: nil))
      return
    }

    DispatchQueue.main.async {
      sdk.submitOtpV5(otp: otp)
      result(nil)
    }
  }

  private func handleGetDeviceDetails(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let sdk = hawcxSDK else {
      result(FlutterError(code: ErrorCode.sdk.rawValue, message: "initialize must be called before getDeviceDetails", details: nil))
      return
    }
    guard let callback = sessionCallbackProxy else {
      result(FlutterError(code: ErrorCode.sdk.rawValue, message: "Session callback not configured", details: nil))
      return
    }
    DispatchQueue.main.async {
      sdk.getDeviceDetails(callback: callback)
      result(nil)
    }
  }

  private func handleWebLogin(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let sdk = hawcxSDK else {
      result(FlutterError(code: ErrorCode.sdk.rawValue, message: "initialize must be called before webLogin", details: nil))
      return
    }
    guard let callback = sessionCallbackProxy else {
      result(FlutterError(code: ErrorCode.sdk.rawValue, message: "Session callback not configured", details: nil))
      return
    }
    let args = asDict(call.arguments)
    let pin = (stringValue(args["pin"]) ?? stringValue(call.arguments))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if pin.isEmpty {
      result(FlutterError(code: ErrorCode.input.rawValue, message: "pin cannot be empty", details: nil))
      return
    }
    DispatchQueue.main.async {
      sdk.webLogin(pin: pin, callback: callback)
      result(nil)
    }
  }

  private func handleWebApprove(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let sdk = hawcxSDK else {
      result(FlutterError(code: ErrorCode.sdk.rawValue, message: "initialize must be called before webApprove", details: nil))
      return
    }
    guard let callback = sessionCallbackProxy else {
      result(FlutterError(code: ErrorCode.sdk.rawValue, message: "Session callback not configured", details: nil))
      return
    }
    let args = asDict(call.arguments)
    let token = (stringValue(args["token"]) ?? stringValue(call.arguments))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if token.isEmpty {
      result(FlutterError(code: ErrorCode.input.rawValue, message: "token cannot be empty", details: nil))
      return
    }
    DispatchQueue.main.async {
      sdk.webApprove(token: token, callback: callback)
      result(nil)
    }
  }

  private func handleStoreBackendOAuthTokens(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let sdk = hawcxSDK else {
      result(FlutterError(code: ErrorCode.sdk.rawValue, message: "initialize must be called before storeBackendOAuthTokens", details: nil))
      return
    }

    let args = asDict(call.arguments)
    let userId = stringValue(args["userId"])?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let accessToken = stringValue(args["accessToken"])?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let refreshToken = stringValue(args["refreshToken"])?.trimmingCharacters(in: .whitespacesAndNewlines)

    if userId.isEmpty {
      result(FlutterError(code: ErrorCode.input.rawValue, message: "userId cannot be empty", details: nil))
      return
    }
    if accessToken.isEmpty {
      result(FlutterError(code: ErrorCode.input.rawValue, message: "accessToken cannot be empty", details: nil))
      return
    }

    DispatchQueue.main.async {
      let stored = sdk.storeBackendOAuthTokens(accessToken: accessToken, refreshToken: refreshToken?.isEmpty == false ? refreshToken : nil, forUser: userId)
      if stored {
        result(true)
      } else {
        result(FlutterError(code: ErrorCode.storage.rawValue, message: "Failed to persist backend-issued tokens", details: nil))
      }
    }
  }

  private func handleGetLastLoggedInUser(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let sdk = hawcxSDK else {
      result(FlutterError(code: ErrorCode.sdk.rawValue, message: "initialize must be called before getLastLoggedInUser", details: nil))
      return
    }
    result(sdk.getLastLoggedInUser())
  }

  private func handleClearSessionTokens(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let sdk = hawcxSDK else {
      result(FlutterError(code: ErrorCode.sdk.rawValue, message: "initialize must be called before clearSessionTokens", details: nil))
      return
    }
    let args = asDict(call.arguments)
    let userId = (stringValue(args["userId"]) ?? stringValue(call.arguments))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if userId.isEmpty {
      result(FlutterError(code: ErrorCode.input.rawValue, message: "userId cannot be empty", details: nil))
      return
    }
    DispatchQueue.main.async {
      sdk.clearSessionTokens(forUser: userId)
      result(nil)
    }
  }

  private func handleClearUserKeychainData(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let sdk = hawcxSDK else {
      result(FlutterError(code: ErrorCode.sdk.rawValue, message: "initialize must be called before clearUserKeychainData", details: nil))
      return
    }
    let args = asDict(call.arguments)
    let userId = (stringValue(args["userId"]) ?? stringValue(call.arguments))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if userId.isEmpty {
      result(FlutterError(code: ErrorCode.input.rawValue, message: "userId cannot be empty", details: nil))
      return
    }
    DispatchQueue.main.async {
      sdk.clearUserKeychainData(forUser: userId)
      result(nil)
    }
  }

  private func handleClearLastLoggedInUser(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let sdk = hawcxSDK else {
      result(FlutterError(code: ErrorCode.sdk.rawValue, message: "initialize must be called before clearLastLoggedInUser", details: nil))
      return
    }
    DispatchQueue.main.async {
      sdk.clearLastLoggedInUser()
      result(nil)
    }
  }

  private func handleSetApnsDeviceToken(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let sdk = hawcxSDK else {
      result(FlutterError(code: ErrorCode.sdk.rawValue, message: "initialize must be called before setApnsDeviceToken", details: nil))
      return
    }
    let args = asDict(call.arguments)
    let tokenString = (stringValue(args["token"]) ?? stringValue(args["tokenBase64"]) ?? stringValue(call.arguments))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    guard let tokenData = decodeTokenString(tokenString) else {
      result(FlutterError(code: ErrorCode.input.rawValue, message: "APNs token must be a base64 or hex string", details: nil))
      return
    }
    DispatchQueue.main.async {
      sdk.setAPNsDeviceToken(tokenData)
      result(nil)
    }
  }

  private func handleSetPushToken(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = asDict(call.arguments)
    let platform = stringValue(args["platform"])?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
    let token = stringValue(args["token"])?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if token.isEmpty {
      result(FlutterError(code: ErrorCode.input.rawValue, message: "token cannot be empty", details: nil))
      return
    }
    if platform.isEmpty || platform == "ios" || platform == "apns" {
      // iOS expects APNs device token bytes; accept base64 or hex.
      handleSetApnsDeviceToken(FlutterMethodCall(methodName: "setApnsDeviceToken", arguments: ["token": token]), result: result)
      return
    }
    if platform == "android" || platform == "fcm" {
      // Allow shared code to call setPushToken on both platforms.
      result(nil)
      return
    }
    result(FlutterError(code: ErrorCode.input.rawValue, message: "Unsupported platform '\(platform)'", details: nil))
  }

  private func handleUserDidAuthenticate(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let sdk = hawcxSDK else {
      result(FlutterError(code: ErrorCode.sdk.rawValue, message: "initialize must be called before userDidAuthenticate", details: nil))
      return
    }
    DispatchQueue.main.async {
      sdk.userDidAuthenticate()
      result(nil)
    }
  }

  private func handlePushNotification(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let sdk = hawcxSDK else {
      result(FlutterError(code: ErrorCode.sdk.rawValue, message: "initialize must be called before handlePushNotification", details: nil))
      return
    }
    guard let payload = call.arguments as? [String: Any] ?? (call.arguments as? NSDictionary as? [String: Any]) else {
      result(FlutterError(code: ErrorCode.input.rawValue, message: "payload is required", details: nil))
      return
    }
    let userInfo: [AnyHashable: Any] = payload.reduce(into: [:]) { $0[$1.key] = $1.value }
    DispatchQueue.main.async {
      let handled = sdk.handlePushNotification(userInfo: userInfo)
      result(handled)
    }
  }

  private func handleApprovePushRequest(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let sdk = hawcxSDK else {
      result(FlutterError(code: ErrorCode.sdk.rawValue, message: "initialize must be called before approvePushRequest", details: nil))
      return
    }
    let args = asDict(call.arguments)
    let requestId = (stringValue(args["requestId"]) ?? stringValue(call.arguments))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if requestId.isEmpty {
      result(FlutterError(code: ErrorCode.input.rawValue, message: "requestId cannot be empty", details: nil))
      return
    }
    DispatchQueue.main.async {
      sdk.approveLoginRequest(requestId: requestId) { error in
        if let error {
          result(FlutterError(code: ErrorCode.sdk.rawValue, message: error.localizedDescription, details: nil))
        } else {
          result(nil)
        }
      }
    }
  }

  private func handleDeclinePushRequest(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let sdk = hawcxSDK else {
      result(FlutterError(code: ErrorCode.sdk.rawValue, message: "initialize must be called before declinePushRequest", details: nil))
      return
    }
    let args = asDict(call.arguments)
    let requestId = (stringValue(args["requestId"]) ?? stringValue(call.arguments))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if requestId.isEmpty {
      result(FlutterError(code: ErrorCode.input.rawValue, message: "requestId cannot be empty", details: nil))
      return
    }
    DispatchQueue.main.async {
      sdk.declineLoginRequest(requestId: requestId) { error in
        if let error {
          result(FlutterError(code: ErrorCode.sdk.rawValue, message: error.localizedDescription, details: nil))
        } else {
          result(nil)
        }
      }
    }
  }

  // MARK: - Event dispatch

  fileprivate func emitEvent(_ event: [String: Any]) {
    DispatchQueue.main.async {
      if let sink = self.eventSink {
        sink(event)
        return
      }
      self.queueEvent(event)
    }
  }

  private func queueEvent(_ event: [String: Any]) {
    if queuedEvents.count >= maxQueuedEvents {
      queuedEvents.removeFirst(queuedEvents.count - maxQueuedEvents + 1)
    }
    queuedEvents.append(event)
  }

  private func flushQueuedEvents() {
    guard let sink = eventSink else { return }
    if queuedEvents.isEmpty { return }
    queuedEvents.forEach { sink($0) }
    queuedEvents.removeAll()
  }

  // MARK: - Argument helpers

  private func asDict(_ args: Any?) -> [String: Any] {
    if let dict = args as? [String: Any] { return dict }
    if let dict = args as? NSDictionary { return dict as? [String: Any] ?? [:] }
    return [:]
  }

  private func asDictOrNil(_ args: Any?) -> [String: Any]? {
    let dict = asDict(args)
    return dict.isEmpty ? nil : dict
  }

  private func stringValue(_ value: Any?) -> String? {
    if let string = value as? String { return string }
    if let string = value as? NSString { return string as String }
    return nil
  }

  private func resolveBaseUrl(args: [String: Any]) -> String? {
    if let direct = stringValue(args["baseUrl"]) {
      let trimmed = direct.trimmingCharacters(in: .whitespacesAndNewlines)
      if !trimmed.isEmpty { return trimmed }
    }
    if let endpoints = args["endpoints"] as? [String: Any],
       let authBase = stringValue(endpoints["authBaseUrl"]) {
      let trimmed = authBase.trimmingCharacters(in: .whitespacesAndNewlines)
      if !trimmed.isEmpty { return trimmed }
    }
    return nil
  }

  private func makeOAuthConfig(from dict: [String: Any]) throws -> HawcxOAuthConfig {
    guard
      let endpointString = stringValue(dict["tokenEndpoint"]),
      let endpointURL = URL(string: endpointString),
      let clientId = stringValue(dict["clientId"])?.trimmingCharacters(in: .whitespacesAndNewlines),
      let publicKeyPem = stringValue(dict["publicKeyPem"])?.trimmingCharacters(in: .whitespacesAndNewlines),
      !clientId.isEmpty,
      !publicKeyPem.isEmpty
    else {
      throw FlutterError(code: ErrorCode.config.rawValue, message: "oauthConfig must include tokenEndpoint, clientId, and publicKeyPem", details: nil)
    }
    return HawcxOAuthConfig(tokenEndpoint: endpointURL, clientId: clientId, publicKeyPem: publicKeyPem)
  }

  private func decodeTokenString(_ token: String) -> Data? {
    let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty { return nil }
    if let base64 = Data(base64Encoded: trimmed) { return base64 }

    let cleaned = trimmed
      .replacingOccurrences(of: "<", with: "")
      .replacingOccurrences(of: ">", with: "")
      .replacingOccurrences(of: " ", with: "")
      .lowercased()

    guard cleaned.count % 2 == 0 else { return nil }
    var data = Data(capacity: cleaned.count / 2)
    var idx = cleaned.startIndex
    while idx < cleaned.endIndex {
      let next = cleaned.index(idx, offsetBy: 2)
      let byteString = cleaned[idx..<next]
      guard let byte = UInt8(byteString, radix: 16) else { return nil }
      data.append(byte)
      idx = next
    }
    return data
  }
}

private final class AuthCallbackProxy: NSObject, AuthV5Callback {
  weak var emitter: HawcxFlutterSdkPlugin?

  init(emitter: HawcxFlutterSdkPlugin) {
    self.emitter = emitter
  }

  func onOtpRequired() {
    emitter?.emitEvent(["type": "otp_required"])
  }

  func onAuthSuccess(accessToken: String?, refreshToken: String?, isLoginFlow: Bool) {
    var payload: [String: Any] = ["isLoginFlow": isLoginFlow]
    if let accessToken, !accessToken.isEmpty { payload["accessToken"] = accessToken }
    if let refreshToken, !refreshToken.isEmpty { payload["refreshToken"] = refreshToken }
    emitter?.emitEvent(["type": "auth_success", "payload": payload])
  }

  func onError(errorCode: AuthV5ErrorCode, errorMessage: String) {
    let payload: [String: Any] = ["code": errorCode.rawValue, "message": errorMessage]
    emitter?.emitEvent(["type": "auth_error", "payload": payload])
  }

  func onAuthorizationCode(code: String, expiresIn: Int?) {
    var payload: [String: Any] = ["code": code]
    if let expiresIn { payload["expiresIn"] = expiresIn }
    emitter?.emitEvent(["type": "authorization_code", "payload": payload])
  }

  func onAdditionalVerificationRequired(sessionId: String, detail: String?) {
    var payload: [String: Any] = ["sessionId": sessionId]
    if let detail, !detail.isEmpty { payload["detail"] = detail }
    emitter?.emitEvent(["type": "additional_verification_required", "payload": payload])
  }
}

private final class SessionCallbackProxy: NSObject, DevSessionCallback, WebLoginCallback {
  weak var emitter: HawcxFlutterSdkPlugin?

  init(emitter: HawcxFlutterSdkPlugin) {
    self.emitter = emitter
  }

  func onSuccess() {
    emitter?.emitEvent(["type": "session_success"])
  }

  func showError() {
    emitter?.emitEvent([
      "type": "session_error",
      "payload": [
        "code": "session_error",
        "message": "Failed to fetch device session",
      ],
    ])
  }

  func showError(webLoginErrorCode: WebLoginErrorCode, errorMessage: String) {
    emitter?.emitEvent([
      "type": "session_error",
      "payload": [
        "code": webLoginErrorCode.rawValue,
        "message": errorMessage,
      ],
    ])
  }
}

private final class PushDelegateProxy: NSObject, HawcxPushAuthDelegate {
  weak var emitter: HawcxFlutterSdkPlugin?

  init(emitter: HawcxFlutterSdkPlugin) {
    self.emitter = emitter
  }

  func hawcx(didReceiveLoginRequest requestId: String, details: PushLoginRequestDetails) {
    var payload: [String: Any] = [
      "requestId": requestId,
      "ipAddress": details.ipAddress,
      "deviceInfo": details.deviceInfo,
      "timestamp": details.timestamp,
    ]
    if let location = details.location { payload["location"] = location }
    emitter?.emitEvent(["type": "push_login_request", "payload": payload])
  }

  func hawcx(failedToFetchLoginRequestDetails error: Error) {
    emitter?.emitEvent([
      "type": "push_error",
      "payload": [
        "code": "push_error",
        "message": error.localizedDescription,
      ],
    ])
  }
}
