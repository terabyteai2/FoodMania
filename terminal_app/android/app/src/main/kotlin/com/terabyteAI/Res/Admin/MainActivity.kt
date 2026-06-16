package com.terabyteai.foodmania.posadmin

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.provider.Settings
import androidx.core.content.FileProvider
import com.facebook.CallbackManager
import com.facebook.FacebookCallback
import com.facebook.FacebookException
import com.facebook.FacebookSdk
import com.facebook.login.LoginBehavior
import com.facebook.login.LoginManager
import com.facebook.login.LoginResult
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.view.inputmethod.InputMethodManager
import java.io.File
import java.io.FileInputStream

/**
 * Hosts a [MethodChannel] used by [SystemNotificationService] on the Dart
 * side to install notification sounds and create Android channels with
 * explicit audio attributes so alerts play outside the app without manual
 * channel sound toggles in system settings.
 *
 * Built-in printer support (Sunmi/iMin/PAX) lives entirely in Dart now, via
 * vendor-specific plugins behind `lib/src/services/printer/`
 * (`BuiltInPrinterAdapter` + `PrinterVendorDetector`) — this activity no
 * longer hosts any printer MethodChannel, AIDL binding, USB host code, or
 * printer diagnostics logging.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "com.terabyteai.foodmania/notification_sound"
    private val appUpdateChannelName = "com.terabyteai.foodmania/app_update"
    private val browserChannelName = "com.terabyteai.foodmania/browser"
    private val facebookLoginChannelName = "com.terabyteai.foodmania/facebook_login"
    private val facebookCallbackManager: CallbackManager = CallbackManager.Factory.create()
    private var facebookCallbackRegistered = false
    private var pendingFacebookLoginResult: MethodChannel.Result? = null

    companion object {
        private const val PENDING_CHANNEL_ID = "pos_pending_orders_v2"
        private const val ACCEPTED_CHANNEL_ID = "pos_accepted_orders_v2"
        private const val DEFAULT_CHANNEL_ID = "pos_orders_default_v2"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        registerBrowserChannel(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "ensureNotificationChannels" -> {
                        try {
                            ensureNotificationChannels()
                            result.success(true)
                        } catch (error: Exception) {
                            result.error("CHANNEL_FAILED", error.message, null)
                        }
                    }
                    "playRawNotificationSound" -> {
                        val resource = call.argument<String>("resource") ?: "order_pending_request"
                        try {
                            result.success(playRawNotificationSound(resource))
                        } catch (_: Exception) {
                            result.success(false)
                        }
                    }
                    "registerNotificationSound" -> {
                        val path = call.argument<String>("path")
                        if (path.isNullOrBlank()) {
                            result.error("INVALID_ARGUMENT", "path is required", null)
                            return@setMethodCallHandler
                        }
                        try {
                            result.success(registerNotificationSound(path))
                        } catch (error: Exception) {
                            result.error("REGISTER_FAILED", error.message, null)
                        }
                    }
                    "defaultNotificationSoundUri" -> {
                        result.success(
                            RingtoneManager
                                .getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                                ?.toString()
                                ?: Settings.System.DEFAULT_NOTIFICATION_URI.toString()
                        )
                    }
                    "playDefaultNotificationSound" -> {
                        try {
                            val uri =
                                RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                                    ?: Settings.System.DEFAULT_NOTIFICATION_URI
                            val ringtone = RingtoneManager.getRingtone(applicationContext, uri)
                            if (ringtone != null) {
                                ringtone.play()
                                result.success(true)
                            } else {
                                result.success(false)
                            }
                        } catch (_: Exception) {
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, appUpdateChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "runtimeInfo" -> {
                        try {
                            result.success(runtimeInfo())
                        } catch (error: Exception) {
                            result.error("RUNTIME_INFO_FAILED", error.message, null)
                        }
                    }
                    "canRequestPackageInstalls" -> {
                        result.success(canRequestPackageInstalls())
                    }
                    "openInstallPermissionSettings" -> {
                        try {
                            openInstallPermissionSettings()
                            result.success(true)
                        } catch (error: Exception) {
                            result.error("PERMISSION_SETTINGS_FAILED", error.message, null)
                        }
                    }
                    "installApk" -> {
                        val path = call.argument<String>("path")
                        if (path.isNullOrBlank()) {
                            result.error("INVALID_ARGUMENT", "path is required", null)
                            return@setMethodCallHandler
                        }
                        try {
                            installApk(path)
                            result.success(true)
                        } catch (error: Exception) {
                            result.error("INSTALL_APK_FAILED", error.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.terabyteai.foodmania/keyboard")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "forceShow" -> {
                        val view = currentFocus
                        if (view != null) {
                            val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
                            imm.showSoftInput(view, InputMethodManager.SHOW_FORCED)
                        }
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun registerFacebookLoginChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, facebookLoginChannelName)
            .setMethodCallHandler { call, result ->
                if (call.method != "login") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                if (pendingFacebookLoginResult != null) {
                    result.error("LOGIN_IN_PROGRESS", "Facebook Login is already in progress.", null)
                    return@setMethodCallHandler
                }
                val appId = call.argument<String>("appId")?.trim().orEmpty()
                val clientToken = call.argument<String>("clientToken")?.trim().orEmpty()
                val scopes = call.argument<List<String>>("scopes")
                    ?.map { it.trim() }
                    ?.filter { it.isNotEmpty() }
                    .orEmpty()
                if (appId.isEmpty() || clientToken.isEmpty() || scopes.isEmpty()) {
                    result.error("INVALID_ARGUMENT", "Facebook Login configuration is incomplete.", null)
                    return@setMethodCallHandler
                }
                try {
                    FacebookSdk.setApplicationId(appId)
                    FacebookSdk.setClientToken(clientToken)
                    FacebookSdk.setAutoInitEnabled(false)
                    FacebookSdk.setAutoLogAppEventsEnabled(false)
                    FacebookSdk.setAdvertiserIDCollectionEnabled(false)
                    @Suppress("DEPRECATION")
                    FacebookSdk.sdkInitialize(applicationContext)
                    ensureFacebookLoginCallbackRegistered()
                    pendingFacebookLoginResult = result
                    LoginManager.getInstance()
                        .setLoginBehavior(LoginBehavior.NATIVE_ONLY)
                        .logInWithReadPermissions(this, scopes)
                } catch (error: Exception) {
                    pendingFacebookLoginResult = null
                    result.error("FACEBOOK_LOGIN_FAILED", error.message, null)
                }
            }
    }

    private fun ensureFacebookLoginCallbackRegistered() {
        if (facebookCallbackRegistered) return
        LoginManager.getInstance().registerCallback(
            facebookCallbackManager,
            object : FacebookCallback<LoginResult> {
                override fun onSuccess(result: LoginResult) {
                    val token = result.accessToken.token
                    finishFacebookLogin(mapOf("status" to "success", "accessToken" to token))
                }

                override fun onCancel() {
                    finishFacebookLogin(mapOf("status" to "cancelled"))
                }

                override fun onError(error: FacebookException) {
                    finishFacebookLogin(
                        mapOf("status" to "failed", "message" to (error.message ?: "Facebook Login failed"))
                    )
                }
            },
        )
        facebookCallbackRegistered = true
    }

    private fun registerBrowserChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, browserChannelName)
            .setMethodCallHandler { call, result ->
                if (call.method != "openUrl") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val url = call.argument<String>("url")?.trim()
                if (url.isNullOrBlank()) {
                    result.error("INVALID_ARGUMENT", "url is required", null)
                    return@setMethodCallHandler
                }
                try {
                    val uri = Uri.parse(url)
                    val intent = Intent(Intent.ACTION_VIEW, uri).apply {
                        addCategory(Intent.CATEGORY_BROWSABLE)
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(intent)
                    result.success(true)
                } catch (error: Exception) {
                    result.error("BROWSER_OPEN_FAILED", error.message, null)
                }
            }
    }

    private fun finishFacebookLogin(value: Map<String, String>) {
        val result = pendingFacebookLoginResult ?: return
        pendingFacebookLoginResult = null
        result.success(value)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        facebookCallbackManager.onActivityResult(requestCode, resultCode, data)
        super.onActivityResult(requestCode, resultCode, data)
    }

    private fun runtimeInfo(): Map<String, Any> {
        val info = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.getPackageInfo(packageName, android.content.pm.PackageManager.PackageInfoFlags.of(0))
        } else {
            @Suppress("DEPRECATION")
            packageManager.getPackageInfo(packageName, 0)
        }
        val versionCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.longVersionCode
        } else {
            @Suppress("DEPRECATION")
            info.versionCode.toLong()
        }
        return mapOf(
            "versionName" to (info.versionName ?: ""),
            "versionCode" to versionCode,
        )
    }

    private fun canRequestPackageInstalls(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            packageManager.canRequestPackageInstalls()
        } else {
            true
        }
    }

    private fun openInstallPermissionSettings() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val intent = Intent(
            Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
            Uri.parse("package:$packageName"),
        ).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
    }

    private fun installApk(path: String) {
        val apk = File(path)
        require(apk.exists()) { "APK file does not exist: $path" }
        val uri = FileProvider.getUriForFile(
            this,
            "$packageName.fileprovider",
            apk,
        )
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
    }

    private fun ensureNotificationChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager =
            getSystemService(NotificationManager::class.java) ?: return

        val legacyIds = listOf(
            "pos_pending_orders",
            "pos_accepted_orders",
            "pos_orders_default",
        )
        for (id in legacyIds) {
            try {
                manager.deleteNotificationChannel(id)
            } catch (_: Exception) {}
        }

        createChannel(
            manager,
            PENDING_CHANNEL_ID,
            "Pending order alerts",
            "Sound plays when a new order needs attention.",
            R.raw.order_pending_request,
        )
        createChannel(
            manager,
            ACCEPTED_CHANNEL_ID,
            "Accepted order alerts",
            "Sound plays when an order is accepted.",
            R.raw.general_notification,
        )
        val defaultUri =
            RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                ?: Settings.System.DEFAULT_NOTIFICATION_URI
        createChannelWithUri(
            manager,
            DEFAULT_CHANNEL_ID,
            "Order alerts",
            "General order notifications with sound.",
            defaultUri,
        )
    }

    private fun createChannel(
        manager: NotificationManager,
        id: String,
        name: String,
        description: String,
        rawResId: Int,
    ) {
        val soundUri = Uri.parse("android.resource://${packageName}/$rawResId")
        createChannelWithUri(manager, id, name, description, soundUri)
    }

    private fun createChannelWithUri(
        manager: NotificationManager,
        id: String,
        name: String,
        description: String,
        soundUri: Uri,
    ) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val attrs = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_NOTIFICATION)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        val channel = NotificationChannel(
            id,
            name,
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            this.description = description
            setSound(soundUri, attrs)
            enableVibration(true)
            enableLights(true)
        }
        manager.createNotificationChannel(channel)
    }

    private fun playRawNotificationSound(resourceName: String): Boolean {
        val resId = resources.getIdentifier(resourceName, "raw", packageName)
        if (resId == 0) return false
        val uri = Uri.parse("android.resource://${packageName}/$resId")
        val ringtone = RingtoneManager.getRingtone(applicationContext, uri) ?: return false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            ringtone.audioAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
        }
        ringtone.play()
        return true
    }

    private fun registerNotificationSound(path: String): String {
        val source = File(path)
        require(source.exists()) { "Source sound file does not exist: $path" }

        val mimeType = when (source.extension.lowercase()) {
            "mp3" -> "audio/mpeg"
            "wav" -> "audio/wav"
            "ogg" -> "audio/ogg"
            "m4a" -> "audio/mp4"
            "aac" -> "audio/aac"
            else -> "audio/mpeg"
        }
        val displayName = "foodmania_notif_${System.currentTimeMillis()}_${source.name}"

        val resolver = contentResolver
        val collection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        } else {
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
        }

        val existing = findExistingByDisplayPrefix(resolver, collection, source.name)
        if (existing != null) return existing.toString()

        val values = ContentValues().apply {
            put(MediaStore.Audio.Media.DISPLAY_NAME, displayName)
            put(MediaStore.Audio.Media.MIME_TYPE, mimeType)
            put(MediaStore.Audio.Media.IS_NOTIFICATION, 1)
            put(MediaStore.Audio.Media.IS_MUSIC, 0)
            put(MediaStore.Audio.Media.IS_ALARM, 0)
            put(MediaStore.Audio.Media.IS_RINGTONE, 0)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(MediaStore.Audio.Media.RELATIVE_PATH, "Notifications/Foodmania")
                put(MediaStore.Audio.Media.IS_PENDING, 1)
            }
        }

        val itemUri: Uri = resolver.insert(collection, values)
            ?: throw IllegalStateException("MediaStore.insert returned null")

        try {
            FileInputStream(source).use { input ->
                val output = resolver.openOutputStream(itemUri)
                    ?: throw IllegalStateException("openOutputStream returned null")
                output.use { input.copyTo(it) }
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val publish = ContentValues().apply {
                    put(MediaStore.Audio.Media.IS_PENDING, 0)
                }
                resolver.update(itemUri, publish, null, null)
            }
            return itemUri.toString()
        } catch (error: Exception) {
            try { resolver.delete(itemUri, null, null) } catch (_: Exception) {}
            throw error
        }
    }

    private fun findExistingByDisplayPrefix(
        resolver: android.content.ContentResolver,
        collection: Uri,
        originalName: String,
    ): Uri? {
        val projection = arrayOf(MediaStore.Audio.Media._ID, MediaStore.Audio.Media.DISPLAY_NAME)
        val selection = "${MediaStore.Audio.Media.DISPLAY_NAME} LIKE ?"
        val args = arrayOf("foodmania_notif_%_$originalName")
        return try {
            resolver.query(collection, projection, selection, args, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val idIndex = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media._ID)
                    val id = cursor.getLong(idIndex)
                    Uri.withAppendedPath(collection, id.toString())
                } else null
            }
        } catch (_: Exception) {
            null
        }
    }
}
