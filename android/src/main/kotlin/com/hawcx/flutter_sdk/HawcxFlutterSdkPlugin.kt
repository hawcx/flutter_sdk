package com.hawcx.flutter_sdk

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import com.hawcx.internal.HawcxSDK
import com.hawcx.model.PushLoginRequestDetails
import com.hawcx.utils.AuthV5Callback
import com.hawcx.utils.AuthV5ErrorCode
import com.hawcx.utils.DevSessionCallback
import com.hawcx.utils.HawcxPushAuthDelegate
import com.hawcx.utils.WebLoginCallback
import com.hawcx.utils.WebLoginError

private const val AUTH_EVENT_NAME = "hawcx.auth.event"
private const val SESSION_EVENT_NAME = "hawcx.session.event"
private const val PUSH_EVENT_NAME = "hawcx.push.event"

class HawcxFlutterSdkPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
  private enum class ErrorCode(val value: String) {
    CONFIG("hawcx.config"),
    SDK("hawcx.sdk"),
    INPUT("hawcx.input"),
    STORAGE("hawcx.storage"),
  }

  private val maxQueuedEvents = 50
  private val mainHandler = Handler(Looper.getMainLooper())

  private lateinit var methodChannel: MethodChannel
  private lateinit var eventChannel: EventChannel
  private var eventSink: EventChannel.EventSink? = null
  private val queuedEvents: ArrayDeque<Map<String, Any?>> = ArrayDeque()
  private var appContext: Context? = null

  @Volatile
  private var hawcxSDK: HawcxSDK? = null
  @Volatile
  private var authCallbackProxy: AuthCallbackProxy? = null
  @Volatile
  private var sessionCallbackProxy: SessionCallbackProxy? = null
  @Volatile
  private var pushDelegateProxy: PushDelegateProxy? = null

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    appContext = binding.applicationContext
    methodChannel = MethodChannel(binding.binaryMessenger, "hawcx_flutter")
    methodChannel.setMethodCallHandler(this)
    eventChannel = EventChannel(binding.binaryMessenger, "hawcx_flutter/events")
    eventChannel.setStreamHandler(this)
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    methodChannel.setMethodCallHandler(null)
    eventChannel.setStreamHandler(null)
    eventSink = null
    queuedEvents.clear()
    appContext = null
    hawcxSDK = null
    authCallbackProxy = null
    sessionCallbackProxy = null
    pushDelegateProxy = null
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      "initialize" -> handleInitialize(call, result)
      "authenticateV5", "authenticate" -> handleAuthenticate(call, result)
      "submitOtpV5", "submitOtp" -> handleSubmitOtp(call, result)
      "getDeviceDetails" -> handleGetDeviceDetails(call, result)
      "webLogin" -> handleWebLogin(call, result)
      "webApprove" -> handleWebApprove(call, result)
      "storeBackendOAuthTokens" -> handleStoreBackendOAuthTokens(call, result)
      "getLastLoggedInUser" -> handleGetLastLoggedInUser(call, result)
      "clearSessionTokens" -> handleClearSessionTokens(call, result)
      "clearUserKeychainData" -> handleClearUserKeychainData(call, result)
      "clearLastLoggedInUser" -> handleClearLastLoggedInUser(call, result)
      "setFcmToken" -> handleSetFcmToken(call, result)
      "setPushToken" -> handleSetPushToken(call, result)
      "userDidAuthenticate" -> handleUserDidAuthenticate(call, result)
      "handlePushNotification" -> handlePushNotification(call, result)
      "approvePushRequest" -> handleApprovePushRequest(call, result)
      "declinePushRequest" -> handleDeclinePushRequest(call, result)
      else -> result.notImplemented()
    }
  }

  override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
    eventSink = events
    flushQueuedEvents()
  }

  override fun onCancel(arguments: Any?) {
    eventSink = null
  }

  // MARK: - Method handlers

  private fun handleInitialize(call: MethodCall, result: MethodChannel.Result) {
    val context = appContext ?: run {
      result.error(ErrorCode.SDK.value, "Context not available", null)
      return
    }

    val args = call.arguments as? Map<*, *> ?: emptyMap<Any?, Any?>()

    val projectApiKey = ((args["projectApiKey"] ?: args["apiKey"]) as? String)?.trim().orEmpty()
    if (projectApiKey.isEmpty()) {
      result.error(ErrorCode.CONFIG.value, "projectApiKey (or apiKey) is required", null)
      return
    }

    val baseUrl = resolveBaseUrl(args).trim()
    if (baseUrl.isEmpty()) {
      result.error(ErrorCode.CONFIG.value, "baseUrl is required", null)
      return
    }

    // Keep the Flutter config shape aligned with other SDKs.
    // The Android SDK may ignore oauthConfig; do not reject initialize() when it's present.
    if (args["oauthConfig"] != null) {
      // No-op: intentionally ignored on Android for parity and to avoid requiring client creds on-device.
    }

    runOnUiThread {
      try {
        val sdk = HawcxSDK(
          context = context,
          projectApiKey = projectApiKey,
          baseUrl = baseUrl
        )
        hawcxSDK = sdk
        val authProxy = AuthCallbackProxy(::emitEvent)
        val sessionProxy = SessionCallbackProxy(::emitEvent)
        val pushProxy = PushDelegateProxy(::emitEvent)
        authCallbackProxy = authProxy
        sessionCallbackProxy = sessionProxy
        pushDelegateProxy = pushProxy
        sdk.pushAuthDelegate = pushProxy
        result.success(null)
      } catch (error: Exception) {
        result.error(ErrorCode.SDK.value, error.message ?: "Failed to initialize SDK", null)
      }
    }
  }

  private fun handleAuthenticate(call: MethodCall, result: MethodChannel.Result) {
    val sdk = hawcxSDK ?: run {
      result.error(ErrorCode.SDK.value, "initialize must be called before authenticate", null)
      return
    }
    val callback = authCallbackProxy ?: run {
      result.error(ErrorCode.SDK.value, "Auth callback not configured", null)
      return
    }
    val args = call.arguments as? Map<*, *> ?: emptyMap<Any?, Any?>()
    val userId = ((args["userId"] ?: args["userid"] ?: call.arguments) as? String)?.trim().orEmpty()
    if (userId.isEmpty()) {
      result.error(ErrorCode.INPUT.value, "userId cannot be empty", null)
      return
    }

    runOnUiThread {
      sdk.authenticateV5(userId, callback)
      result.success(null)
    }
  }

  private fun handleSubmitOtp(call: MethodCall, result: MethodChannel.Result) {
    val sdk = hawcxSDK ?: run {
      result.error(ErrorCode.SDK.value, "initialize must be called before submitOtp", null)
      return
    }
    val args = call.arguments as? Map<*, *> ?: emptyMap<Any?, Any?>()
    val otp = ((args["otp"] ?: call.arguments) as? String)?.trim().orEmpty()
    if (otp.isEmpty()) {
      result.error(ErrorCode.INPUT.value, "otp cannot be empty", null)
      return
    }

    runOnUiThread {
      sdk.submitOtpV5(otp)
      result.success(null)
    }
  }

  private fun handleGetDeviceDetails(call: MethodCall, result: MethodChannel.Result) {
    val sdk = hawcxSDK ?: run {
      result.error(ErrorCode.SDK.value, "initialize must be called before getDeviceDetails", null)
      return
    }
    val callback = sessionCallbackProxy ?: run {
      result.error(ErrorCode.SDK.value, "Session callback not configured", null)
      return
    }
    runOnUiThread {
      sdk.getDeviceDetails(callback)
      result.success(null)
    }
  }

  private fun handleWebLogin(call: MethodCall, result: MethodChannel.Result) {
    val sdk = hawcxSDK ?: run {
      result.error(ErrorCode.SDK.value, "initialize must be called before webLogin", null)
      return
    }
    val callback = sessionCallbackProxy ?: run {
      result.error(ErrorCode.SDK.value, "Session callback not configured", null)
      return
    }
    val args = call.arguments as? Map<*, *> ?: emptyMap<Any?, Any?>()
    val pin = ((args["pin"] ?: call.arguments) as? String)?.trim().orEmpty()
    if (pin.isEmpty()) {
      result.error(ErrorCode.INPUT.value, "pin cannot be empty", null)
      return
    }
    runOnUiThread {
      sdk.webLogin(pin, callback)
      result.success(null)
    }
  }

  private fun handleWebApprove(call: MethodCall, result: MethodChannel.Result) {
    val sdk = hawcxSDK ?: run {
      result.error(ErrorCode.SDK.value, "initialize must be called before webApprove", null)
      return
    }
    val callback = sessionCallbackProxy ?: run {
      result.error(ErrorCode.SDK.value, "Session callback not configured", null)
      return
    }
    val args = call.arguments as? Map<*, *> ?: emptyMap<Any?, Any?>()
    val token = ((args["token"] ?: call.arguments) as? String)?.trim().orEmpty()
    if (token.isEmpty()) {
      result.error(ErrorCode.INPUT.value, "token cannot be empty", null)
      return
    }
    runOnUiThread {
      sdk.webApprove(token, callback)
      result.success(null)
    }
  }

  private fun handleStoreBackendOAuthTokens(call: MethodCall, result: MethodChannel.Result) {
    val sdk = hawcxSDK ?: run {
      result.error(ErrorCode.SDK.value, "initialize must be called before storeBackendOAuthTokens", null)
      return
    }
    val args = call.arguments as? Map<*, *> ?: emptyMap<Any?, Any?>()
    val userId = (args["userId"] as? String)?.trim().orEmpty()
    if (userId.isEmpty()) {
      result.error(ErrorCode.INPUT.value, "userId cannot be empty", null)
      return
    }
    val accessToken = (args["accessToken"] as? String)?.trim().orEmpty()
    if (accessToken.isEmpty()) {
      result.error(ErrorCode.INPUT.value, "accessToken cannot be empty", null)
      return
    }
    val refreshToken = (args["refreshToken"] as? String)?.trim().orEmpty().ifBlank { null }

    runCatching { sdk.storeBackendOAuthTokens(accessToken, refreshToken, userId) }
      .onSuccess { stored ->
        if (stored) {
          result.success(true)
        } else {
          result.error(ErrorCode.STORAGE.value, "Failed to persist backend-issued tokens", null)
        }
      }
      .onFailure { error ->
        result.error(ErrorCode.STORAGE.value, error.message ?: "Failed to persist backend-issued tokens", null)
      }
  }

  private fun handleGetLastLoggedInUser(call: MethodCall, result: MethodChannel.Result) {
    val sdk = hawcxSDK ?: run {
      result.error(ErrorCode.SDK.value, "initialize must be called before getLastLoggedInUser", null)
      return
    }
    result.success(sdk.getLastLoggedInUser())
  }

  private fun handleClearSessionTokens(call: MethodCall, result: MethodChannel.Result) {
    val sdk = hawcxSDK ?: run {
      result.error(ErrorCode.SDK.value, "initialize must be called before clearSessionTokens", null)
      return
    }
    val args = call.arguments as? Map<*, *> ?: emptyMap<Any?, Any?>()
    val userId = ((args["userId"] ?: call.arguments) as? String)?.trim().orEmpty()
    if (userId.isEmpty()) {
      result.error(ErrorCode.INPUT.value, "userId cannot be empty", null)
      return
    }
    runOnUiThread {
      sdk.clearSessionTokens(userId)
      result.success(null)
    }
  }

  private fun handleClearUserKeychainData(call: MethodCall, result: MethodChannel.Result) {
    val sdk = hawcxSDK ?: run {
      result.error(ErrorCode.SDK.value, "initialize must be called before clearUserKeychainData", null)
      return
    }
    val args = call.arguments as? Map<*, *> ?: emptyMap<Any?, Any?>()
    val userId = ((args["userId"] ?: call.arguments) as? String)?.trim().orEmpty()
    if (userId.isEmpty()) {
      result.error(ErrorCode.INPUT.value, "userId cannot be empty", null)
      return
    }
    runOnUiThread {
      sdk.clearUserKeychainData(userId)
      result.success(null)
    }
  }

  private fun handleClearLastLoggedInUser(call: MethodCall, result: MethodChannel.Result) {
    val sdk = hawcxSDK ?: run {
      result.error(ErrorCode.SDK.value, "initialize must be called before clearLastLoggedInUser", null)
      return
    }
    runOnUiThread {
      sdk.clearLastLoggedInUser()
      result.success(null)
    }
  }

  private fun handleSetFcmToken(call: MethodCall, result: MethodChannel.Result) {
    val sdk = hawcxSDK ?: run {
      result.error(ErrorCode.SDK.value, "initialize must be called before setFcmToken", null)
      return
    }
    val args = call.arguments as? Map<*, *> ?: emptyMap<Any?, Any?>()
    val token = ((args["token"] ?: call.arguments) as? String)?.trim().orEmpty()
    if (token.isEmpty()) {
      result.error(ErrorCode.INPUT.value, "token cannot be empty", null)
      return
    }
    runOnUiThread {
      sdk.setFcmToken(token)
      result.success(null)
    }
  }

  private fun handleSetPushToken(call: MethodCall, result: MethodChannel.Result) {
    val args = call.arguments as? Map<*, *> ?: emptyMap<Any?, Any?>()
    val platform = (args["platform"] as? String)?.trim()?.lowercase().orEmpty()
    val token = (args["token"] as? String)?.trim().orEmpty()
    if (token.isEmpty()) {
      result.error(ErrorCode.INPUT.value, "token cannot be empty", null)
      return
    }
    if (platform.isEmpty() || platform == "android" || platform == "fcm") {
      handleSetFcmToken(MethodCall("setFcmToken", mapOf("token" to token)), result)
      return
    }
    if (platform == "ios" || platform == "apns") {
      // Allow shared code to call setPushToken on both platforms.
      result.success(null)
      return
    }
    result.error(ErrorCode.INPUT.value, "Unsupported platform '$platform'", null)
  }

  private fun handleUserDidAuthenticate(call: MethodCall, result: MethodChannel.Result) {
    val sdk = hawcxSDK ?: run {
      result.error(ErrorCode.SDK.value, "initialize must be called before userDidAuthenticate", null)
      return
    }
    runOnUiThread {
      sdk.userDidAuthenticate()
      result.success(null)
    }
  }

  private fun handlePushNotification(call: MethodCall, result: MethodChannel.Result) {
    val sdk = hawcxSDK ?: run {
      result.error(ErrorCode.SDK.value, "initialize must be called before handlePushNotification", null)
      return
    }
    val payload = call.arguments as? Map<*, *> ?: run {
      result.error(ErrorCode.INPUT.value, "payload is required", null)
      return
    }
    val stringMap = mutableMapOf<String, String>()
    payload.forEach { (key, value) ->
      val k = key?.toString() ?: return@forEach
      val v = value?.toString() ?: return@forEach
      stringMap[k] = v
    }
    runOnUiThread {
      sdk.handlePushNotification(stringMap)
      result.success(stringMap.containsKey("request_id"))
    }
  }

  private fun handleApprovePushRequest(call: MethodCall, result: MethodChannel.Result) {
    val sdk = hawcxSDK ?: run {
      result.error(ErrorCode.SDK.value, "initialize must be called before approvePushRequest", null)
      return
    }
    val args = call.arguments as? Map<*, *> ?: emptyMap<Any?, Any?>()
    val requestId = ((args["requestId"] ?: call.arguments) as? String)?.trim().orEmpty()
    if (requestId.isEmpty()) {
      result.error(ErrorCode.INPUT.value, "requestId cannot be empty", null)
      return
    }
    sdk.approveLoginRequest(requestId) { error ->
      if (error == null) {
        result.success(null)
      } else {
        result.error(ErrorCode.SDK.value, error.message ?: "Failed to approve push request", null)
      }
    }
  }

  private fun handleDeclinePushRequest(call: MethodCall, result: MethodChannel.Result) {
    val sdk = hawcxSDK ?: run {
      result.error(ErrorCode.SDK.value, "initialize must be called before declinePushRequest", null)
      return
    }
    val args = call.arguments as? Map<*, *> ?: emptyMap<Any?, Any?>()
    val requestId = ((args["requestId"] ?: call.arguments) as? String)?.trim().orEmpty()
    if (requestId.isEmpty()) {
      result.error(ErrorCode.INPUT.value, "requestId cannot be empty", null)
      return
    }
    sdk.declineLoginRequest(requestId) { error ->
      if (error == null) {
        result.success(null)
      } else {
        result.error(ErrorCode.SDK.value, error.message ?: "Failed to decline push request", null)
      }
    }
  }

  // MARK: - Event helpers

  private fun emitEvent(event: Map<String, Any?>) {
    runOnUiThread {
      val sink = eventSink
      if (sink != null) {
        sink.success(event)
      } else {
        if (queuedEvents.size >= maxQueuedEvents) {
          repeat(queuedEvents.size - maxQueuedEvents + 1) { queuedEvents.removeFirstOrNull() }
        }
        queuedEvents.addLast(event)
      }
    }
  }

  private fun flushQueuedEvents() {
    val sink = eventSink ?: return
    while (true) {
      val next = queuedEvents.removeFirstOrNull() ?: break
      sink.success(next)
    }
  }

  // MARK: - Misc helpers

  private fun resolveBaseUrl(args: Map<*, *>): String {
    val direct = (args["baseUrl"] as? String)?.trim()
    if (!direct.isNullOrBlank()) {
      return direct
    }
    val endpoints = args["endpoints"] as? Map<*, *>
    val authBase = (endpoints?.get("authBaseUrl") as? String)?.trim()
    if (!authBase.isNullOrBlank()) {
      return authBase
    }
    return ""
  }

  private fun runOnUiThread(block: () -> Unit) {
    if (Looper.getMainLooper() == Looper.myLooper()) {
      block()
    } else {
      mainHandler.post(block)
    }
  }

  private class AuthCallbackProxy(
    private val emit: (Map<String, Any?>) -> Unit
  ) : AuthV5Callback {

    override fun onOtpRequired() {
      emit(mapOf("name" to AUTH_EVENT_NAME, "type" to "otp_required"))
    }

    override fun onAuthSuccess(accessToken: String, refreshToken: String, isLoginFlow: Boolean) {
      val payload = mutableMapOf<String, Any?>(
        "isLoginFlow" to isLoginFlow
      )
      if (accessToken.isNotBlank()) {
        payload["accessToken"] = accessToken
      }
      if (refreshToken.isNotBlank()) {
        payload["refreshToken"] = refreshToken
      }
      emit(mapOf("name" to AUTH_EVENT_NAME, "type" to "auth_success", "payload" to payload))
    }

    override fun onError(errorCode: AuthV5ErrorCode, errorMessage: String) {
      emit(
        mapOf(
          "name" to AUTH_EVENT_NAME,
          "type" to "auth_error",
          "payload" to mapOf(
            "code" to errorCode.name,
            "message" to errorMessage
          )
        )
      )
    }

    override fun onAuthorizationCode(code: String, expiresIn: Int?) {
      val payload = mutableMapOf<String, Any?>("code" to code)
      expiresIn?.let { payload["expiresIn"] = it }
      emit(mapOf("name" to AUTH_EVENT_NAME, "type" to "authorization_code", "payload" to payload))
    }

    override fun onAdditionalVerificationRequired(sessionId: String, detail: String?) {
      val payload = mutableMapOf<String, Any?>("sessionId" to sessionId)
      if (!detail.isNullOrBlank()) {
        payload["detail"] = detail
      }
      emit(mapOf("name" to AUTH_EVENT_NAME, "type" to "additional_verification_required", "payload" to payload))
    }
  }

  private class SessionCallbackProxy(
    private val emit: (Map<String, Any?>) -> Unit
  ) : DevSessionCallback, WebLoginCallback {

    override fun onSuccess() {
      emit(mapOf("name" to SESSION_EVENT_NAME, "type" to "session_success"))
    }

    override fun onError() {
      emit(
        mapOf(
          "name" to SESSION_EVENT_NAME,
          "type" to "session_error",
          "payload" to mapOf(
            "code" to "session_error",
            "message" to "Failed to fetch device session"
          )
        )
      )
    }

    override fun onError(webLoginErrorCode: WebLoginError, errorMessage: String) {
      emit(
        mapOf(
          "name" to SESSION_EVENT_NAME,
          "type" to "session_error",
          "payload" to mapOf(
            "code" to webLoginErrorCode.name,
            "message" to errorMessage
          )
        )
      )
    }
  }

  private class PushDelegateProxy(
    private val emit: (Map<String, Any?>) -> Unit
  ) : HawcxPushAuthDelegate {

    override fun hawcx(didReceiveLoginRequest: String, details: PushLoginRequestDetails) {
      val payload = mutableMapOf<String, Any?>(
        "requestId" to didReceiveLoginRequest,
        "ipAddress" to details.ipAddress,
        "deviceInfo" to details.deviceInfo,
        "timestamp" to details.timestamp
      )
      if (!details.location.isNullOrBlank()) {
        payload["location"] = details.location
      }
      emit(mapOf("name" to PUSH_EVENT_NAME, "type" to "push_login_request", "payload" to payload))
    }

    override fun hawcx(failedToFetchLoginRequestDetails: Throwable) {
      emit(
        mapOf(
          "name" to PUSH_EVENT_NAME,
          "type" to "push_error",
          "payload" to mapOf(
            "code" to "push_error",
            "message" to (failedToFetchLoginRequestDetails.message ?: "Failed to fetch login request details")
          )
        )
      )
    }
  }
}
