package com.terabyteai.foodmania.posadmin

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbConstants
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbDeviceConnection
import android.hardware.usb.UsbEndpoint
import android.hardware.usb.UsbInterface
import android.hardware.usb.UsbManager
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.provider.Settings
import android.util.Log
import androidx.core.content.FileProvider
import com.facebook.CallbackManager
import com.facebook.FacebookCallback
import com.facebook.FacebookException
import com.facebook.FacebookSdk
import com.facebook.login.LoginBehavior
import com.facebook.login.LoginManager
import com.facebook.login.LoginResult
import com.sunmi.peripheral.printer.InnerPrinterCallback
import com.sunmi.peripheral.printer.InnerPrinterManager
import com.sunmi.peripheral.printer.SunmiPrinterService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.lang.reflect.Modifier
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Hosts a [MethodChannel] used by [SystemNotificationService] on the Dart
 * side to install notification sounds and create Android channels with
 * explicit audio attributes so alerts play outside the app without manual
 * channel sound toggles in system settings.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "com.terabyteai.foodmania/notification_sound"
    private val appUpdateChannelName = "com.terabyteai.foodmania/app_update"
    private val usbPrinterChannelName = "com.terabyteai.foodmania/usb_printer"
    private val builtInPrinterChannelName = "com.terabyteai.foodmania/built_in_printer"
    private val browserChannelName = "com.terabyteai.foodmania/browser"
    private val facebookLoginChannelName = "com.terabyteai.foodmania/facebook_login"
    private val facebookCallbackManager: CallbackManager = CallbackManager.Factory.create()
    private var facebookCallbackRegistered = false
    private var pendingFacebookLoginResult: MethodChannel.Result? = null

    companion object {
        private const val PENDING_CHANNEL_ID = "pos_pending_orders_v2"
        private const val ACCEPTED_CHANNEL_ID = "pos_accepted_orders_v2"
        private const val DEFAULT_CHANNEL_ID = "pos_orders_default_v2"
        private const val ACTION_USB_PERMISSION =
            "com.terabyteai.foodmania.posadmin.USB_PRINTER_PERMISSION"
        private const val PRINTER_TAG = "QB-PRINTER"
        private const val PRINTER_DIAGNOSTICS_FILE = "printer_diagnostics.txt"
        private const val MAX_PRINTER_DIAGNOSTICS_BYTES = 64 * 1024
        private const val SUNMI_REBIND_DELAY_MS = 1500L
    }

    private data class UsbPrinterTarget(
        val device: UsbDevice,
        val usbInterface: UsbInterface,
        val endpoint: UsbEndpoint,
    )

    private data class PendingUsbPrint(
        val bytes: ByteArray,
        val result: MethodChannel.Result,
    )

    private data class BuiltInPrinterTarget(
        val vendor: String,
    )

    private var pendingUsbPrint: PendingUsbPrint? = null
    private var usbReceiverRegistered = false
    private var sunmiBinding = false
    private var sunmiBound = false
    private var sunmiRebindScheduled = false
    private var destroyed = false
    private val mainHandler = Handler(Looper.getMainLooper())
    @Volatile private var sunmiPrinterService: SunmiPrinterService? = null

    private val sunmiPrinterCallback = object : InnerPrinterCallback() {
        override fun onConnected(service: SunmiPrinterService) {
            sunmiPrinterService = service
            sunmiBinding = false
            sunmiBound = true
            printerLog("SUNMI service connected hasPrinter=${hasSunmiPrinter()}")
        }

        override fun onDisconnected() {
            sunmiPrinterService = null
            sunmiBinding = false
            sunmiBound = false
            printerLog("SUNMI service disconnected")
            scheduleSunmiRebind()
        }
    }

    private val usbPermissionReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action != ACTION_USB_PERMISSION) return
            val pending = pendingUsbPrint ?: return
            pendingUsbPrint = null
            val granted = intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)
            printerLog("USB permission result granted=$granted bytes=${pending.bytes.size}")
            if (!granted) {
                pending.result.success(false)
                return
            }
            try {
                pending.result.success(writeUsbPrinterBytes(pending.bytes))
            } catch (error: Exception) {
                pending.result.error("USB_PRINT_FAILED", error.message, null)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        printerLog(
            "Device manufacturer=${Build.MANUFACTURER} model=${Build.MODEL} " +
                "android=${Build.VERSION.RELEASE} sdk=${Build.VERSION.SDK_INT}"
        )
        ensureSunmiPrinterBound()
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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, usbPrinterChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasPrinter" -> {
                        try {
                            val target = findUsbPrinterTarget()
                            printerLog("hasPrinter=${target != null} target=${target?.let { describeTarget(it) } ?: "none"}")
                            result.success(target != null)
                        } catch (error: Exception) {
                            printerLog("hasPrinter failed", error)
                            result.success(false)
                        }
                    }
                    "printBytes" -> {
                        val bytes = call.argument<ByteArray>("bytes")
                        if (bytes == null || bytes.isEmpty()) {
                            result.error("INVALID_ARGUMENT", "bytes are required", null)
                            return@setMethodCallHandler
                        }
                        printUsbPrinterBytes(bytes, result)
                    }
                    "getDiagnostics" -> result.success(readPrinterDiagnostics())
                    "clearDiagnostics" -> {
                        clearPrinterDiagnostics()
                        printerLog("Diagnostics cleared")
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, builtInPrinterChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasPrinter" -> {
                        val target = findBuiltInPrinterTarget()
                        printerLog("built-in hasPrinter=${target != null} vendor=${target?.vendor ?: "none"}")
                        result.success(target != null)
                    }
                    "printBytes" -> {
                        val bytes = call.argument<ByteArray>("bytes")
                        if (bytes == null || bytes.isEmpty()) {
                            result.error("INVALID_ARGUMENT", "bytes are required", null)
                            return@setMethodCallHandler
                        }
                        result.success(printBuiltInPrinterBytes(bytes))
                    }
                    "getDiagnostics" -> result.success(readPrinterDiagnostics())
                    "clearDiagnostics" -> {
                        clearPrinterDiagnostics()
                        printerLog("Diagnostics cleared")
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

    override fun onDestroy() {
        destroyed = true
        mainHandler.removeCallbacksAndMessages(null)
        if (sunmiBound || sunmiBinding) {
            try {
                InnerPrinterManager.getInstance()
                    .unBindService(applicationContext, sunmiPrinterCallback)
            } catch (error: Exception) {
                printerLog("SUNMI unbind failed", error)
            }
        }
        if (usbReceiverRegistered) {
            try {
                unregisterReceiver(usbPermissionReceiver)
            } catch (_: Exception) {}
            usbReceiverRegistered = false
        }
        super.onDestroy()
    }

    private fun ensureSunmiPrinterBound(): Boolean {
        if (destroyed || sunmiPrinterService != null || sunmiBinding) {
            return sunmiPrinterService != null
        }
        return try {
            sunmiBinding = true
            val requested = InnerPrinterManager.getInstance()
                .bindService(applicationContext, sunmiPrinterCallback)
            sunmiBound = requested
            sunmiBinding = requested
            printerLog("SUNMI bind requested=$requested")
            requested
        } catch (error: Exception) {
            sunmiBinding = false
            sunmiBound = false
            printerLog("SUNMI bind unavailable", error)
            false
        }
    }

    private fun scheduleSunmiRebind() {
        if (destroyed || sunmiRebindScheduled) return
        sunmiRebindScheduled = true
        mainHandler.postDelayed({
            sunmiRebindScheduled = false
            ensureSunmiPrinterBound()
        }, SUNMI_REBIND_DELAY_MS)
    }

    private fun hasSunmiPrinter(): Boolean {
        ensureSunmiPrinterBound()
        val service = sunmiPrinterService ?: run {
            printerLog("SUNMI hasPrinter=false service=disconnected")
            return false
        }
        return try {
            val available = InnerPrinterManager.getInstance().hasPrinter(service)
            printerLog("SUNMI hasPrinter=$available service=connected")
            available
        } catch (error: Exception) {
            printerLog("SUNMI hasPrinter failed", error)
            false
        }
    }

    private fun printSunmiPrinterBytes(bytes: ByteArray): Boolean {
        val service = sunmiPrinterService ?: run {
            ensureSunmiPrinterBound()
            printerLog("SUNMI printBytes failed service=disconnected bytes=${bytes.size}")
            return false
        }
        if (!hasSunmiPrinter()) {
            printerLog("SUNMI printBytes failed printer=unavailable bytes=${bytes.size}")
            return false
        }
        return try {
            service.sendRAWData(bytes, null)
            printerLog("SUNMI printBytes submitted bytes=${bytes.size}")
            true
        } catch (error: Exception) {
            printerLog("SUNMI printBytes failed bytes=${bytes.size}", error)
            false
        }
    }

    private fun findBuiltInPrinterTarget(): BuiltInPrinterTarget? {
        if (hasSunmiPrinter()) return BuiltInPrinterTarget("SUNMI")
        if (hasIminPrinterBridge()) return BuiltInPrinterTarget("iMin")
        if (hasPaxPrinterBridge()) return BuiltInPrinterTarget("PAX")
        return null
    }

    private fun printBuiltInPrinterBytes(bytes: ByteArray): Boolean {
        val target = findBuiltInPrinterTarget() ?: run {
            printerLog("built-in printBytes failed: no supported built-in bridge")
            return false
        }
        return when (target.vendor) {
            "SUNMI" -> printSunmiPrinterBytes(bytes)
            "iMin" -> printIminPrinterBytes(bytes)
            "PAX" -> printPaxPrinterBytes(bytes)
            else -> false
        }
    }

    private fun hasIminPrinterBridge(): Boolean {
        val likelyDevice = deviceIdentity().contains("imin")
        val available = classAvailable("com.imin.printerlib.IminPrintUtils")
        if (likelyDevice || available) {
            printerLog("iMin bridge check device=$likelyDevice sdkClass=$available")
        }
        return available
    }

    private fun printIminPrinterBytes(bytes: ByteArray): Boolean {
        val printer = singletonInstance(
            "com.imin.printerlib.IminPrintUtils",
            applicationContext,
        ) ?: run {
            printerLog("iMin printBytes failed: IminPrintUtils unavailable")
            return false
        }
        return try {
            invokeNoArgIfPresent(printer, listOf("initPrinter", "init"))
            val rawOk = invokeRawBytes(
                printer,
                bytes,
                listOf("sendRAWData", "sendRawData", "printRawData", "printBytes"),
            )
            invokeNoArgIfPresent(printer, listOf("printAndFeedPaper", "feedPaper"))
            printerLog("iMin printBytes rawOk=$rawOk bytes=${bytes.size}")
            rawOk
        } catch (error: Exception) {
            printerLog("iMin printBytes failed bytes=${bytes.size}", error)
            false
        }
    }

    private fun hasPaxPrinterBridge(): Boolean {
        val likelyDevice = deviceIdentity().contains("pax")
        val available = classAvailable("com.pax.neptunelite.api.NeptuneLiteUser")
        if (likelyDevice || available) {
            printerLog("PAX bridge check device=$likelyDevice sdkClass=$available")
        }
        return available
    }

    private fun printPaxPrinterBytes(bytes: ByteArray): Boolean {
        val printer = paxPrinterInstance() ?: run {
            printerLog("PAX printBytes failed: printer service unavailable")
            return false
        }
        return try {
            invokeNoArgIfPresent(printer, listOf("init"))
            val rawOk = invokeRawBytes(
                printer,
                bytes,
                listOf("sendRAWData", "sendRawData", "printRawData", "printBytes"),
            )
            if (rawOk) {
                invokeNoArgIfPresent(printer, listOf("start"))
            }
            printerLog("PAX printBytes rawOk=$rawOk bytes=${bytes.size}")
            rawOk
        } catch (error: Exception) {
            printerLog("PAX printBytes failed bytes=${bytes.size}", error)
            false
        }
    }

    private fun paxPrinterInstance(): Any? {
        val user = singletonInstance(
            "com.pax.neptunelite.api.NeptuneLiteUser",
        ) ?: return null
        val dal = invokeFirst(user, listOf("getDal"), applicationContext) ?: return null
        return invokeFirst(dal, listOf("getPrinter", "printer"))
    }

    private fun singletonInstance(className: String, vararg args: Any): Any? {
        return try {
            val clazz = Class.forName(className)
            val candidates = clazz.methods.filter {
                it.name == "getInstance" && Modifier.isStatic(it.modifiers)
            }
            for (method in candidates) {
                val types = method.parameterTypes
                if (types.isEmpty()) return method.invoke(null)
                if (types.size == args.size && types.indices.all { index ->
                        types[index].isAssignableFrom(args[index].javaClass)
                    }
                ) {
                    return method.invoke(null, *args)
                }
            }
            null
        } catch (error: Exception) {
            printerLog("$className singleton unavailable", error)
            null
        }
    }

    private fun invokeFirst(target: Any, names: List<String>, vararg args: Any): Any? {
        for (method in target.javaClass.methods) {
            if (!names.any { method.name.equals(it, ignoreCase = true) }) continue
            val types = method.parameterTypes
            if (types.size != args.size) continue
            if (!types.indices.all { index -> types[index].isAssignableFrom(args[index].javaClass) }) {
                continue
            }
            return method.invoke(target, *args)
        }
        return null
    }

    private fun invokeNoArgIfPresent(target: Any, names: List<String>): Boolean {
        for (method in target.javaClass.methods) {
            if (!names.any { method.name.equals(it, ignoreCase = true) }) continue
            if (method.parameterTypes.isNotEmpty()) continue
            method.invoke(target)
            return true
        }
        return false
    }

    private fun invokeRawBytes(target: Any, bytes: ByteArray, names: List<String>): Boolean {
        for (method in target.javaClass.methods) {
            if (!names.any { method.name.equals(it, ignoreCase = true) }) continue
            val types = method.parameterTypes
            if (types.size == 1 && types[0] == ByteArray::class.java) {
                method.invoke(target, bytes)
                return true
            }
            if (types.size == 2 && types[0] == ByteArray::class.java) {
                method.invoke(target, bytes, null)
                return true
            }
        }
        printerLog(
            "raw byte method unavailable on ${target.javaClass.name}; " +
                "USB/Bluetooth fallback will be used"
        )
        return false
    }

    private fun classAvailable(className: String): Boolean {
        return try {
            Class.forName(className)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun deviceIdentity(): String {
        return listOf(Build.MANUFACTURER, Build.BRAND, Build.MODEL)
            .joinToString(" ")
            .lowercase(Locale.US)
    }

    private fun printUsbPrinterBytes(bytes: ByteArray, result: MethodChannel.Result) {
        val manager = getSystemService(USB_SERVICE) as UsbManager
        printerLog("printBytes request bytes=${bytes.size} devices=${manager.deviceList.size}")
        val target = findUsbPrinterTarget() ?: run {
            printerLog("printBytes no USB printer target")
            result.success(false)
            return
        }
        printerLog(
            "printBytes target=${describeTarget(target)} hasPermission=${manager.hasPermission(target.device)}"
        )
        if (manager.hasPermission(target.device)) {
            try {
                result.success(writeUsbPrinterBytes(bytes))
            } catch (error: Exception) {
                result.error("USB_PRINT_FAILED", error.message, null)
            }
            return
        }

        if (pendingUsbPrint != null) {
            result.error("USB_PRINT_BUSY", "USB printer permission request is already active.", null)
            return
        }

        pendingUsbPrint = PendingUsbPrint(bytes, result)
        ensureUsbPermissionReceiver()
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                PendingIntent.FLAG_MUTABLE
            } else {
                0
            }
        val intent = Intent(ACTION_USB_PERMISSION).setPackage(packageName)
        val permissionIntent = PendingIntent.getBroadcast(this, 0, intent, flags)
        printerLog("requesting USB permission for ${describeDevice(target.device)}")
        manager.requestPermission(target.device, permissionIntent)
    }

    private fun ensureUsbPermissionReceiver() {
        if (usbReceiverRegistered) return
        val filter = IntentFilter(ACTION_USB_PERMISSION)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(usbPermissionReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            registerReceiver(usbPermissionReceiver, filter)
        }
        usbReceiverRegistered = true
    }

    private fun writeUsbPrinterBytes(bytes: ByteArray): Boolean {
        val manager = getSystemService(USB_SERVICE) as UsbManager
        val target = findUsbPrinterTarget() ?: run {
            printerLog("write failed: no target")
            return false
        }
        if (!manager.hasPermission(target.device)) {
            printerLog("write failed: no permission for ${describeDevice(target.device)}")
            return false
        }
        val connection = manager.openDevice(target.device) ?: run {
            printerLog("write failed: openDevice returned null for ${describeDevice(target.device)}")
            return false
        }
        return try {
            val claimed = connection.claimInterface(target.usbInterface, true)
            printerLog("claimInterface=$claimed ${describeTarget(target)}")
            claimed && writeBulkBytes(connection, target.endpoint, bytes)
        } finally {
            try {
                connection.releaseInterface(target.usbInterface)
            } catch (_: Exception) {}
            connection.close()
        }
    }

    private fun writeBulkBytes(
        connection: UsbDeviceConnection,
        endpoint: UsbEndpoint,
        bytes: ByteArray,
    ): Boolean {
        var offset = 0
        val chunkSize = minOf(4096, maxOf(64, endpoint.maxPacketSize * 16))
        printerLog("bulk write start bytes=${bytes.size} chunkSize=$chunkSize maxPacket=${endpoint.maxPacketSize}")
        while (offset < bytes.size) {
            val length = minOf(chunkSize, bytes.size - offset)
            val written = connection.bulkTransfer(endpoint, bytes, offset, length, 3000)
            if (written <= 0) {
                printerLog("bulk write failed offset=$offset requested=$length written=$written")
                return false
            }
            offset += written
        }
        printerLog("bulk write complete bytes=$offset")
        return true
    }

    private fun findUsbPrinterTarget(): UsbPrinterTarget? {
        val manager = getSystemService(USB_SERVICE) as UsbManager
        manager.deviceList.values.forEach { device ->
            printerLog("USB device ${describeDevice(device)} interfaces=${device.interfaceCount}")
            for (i in 0 until device.interfaceCount) {
                printerLog("  iface[$i]=${describeInterface(device.getInterface(i))}")
            }
        }
        val targets = manager.deviceList.values.mapNotNull { device ->
            findUsbPrinterTarget(device)
        }
        if (targets.isNotEmpty()) {
            val target = targets.sortedByDescending { targetScore(it.device, it.usbInterface) }.first()
            printerLog("selected printer-class target ${describeTarget(target)}")
            return target
        }
        val bulkOutTargets = manager.deviceList.values.mapNotNull { device ->
            findAnyBulkOutTarget(device)
        }
        val fallback = bulkOutTargets.sortedByDescending {
            targetScore(it.device, it.usbInterface)
        }.firstOrNull()
        if (fallback != null) {
            printerLog("selected bulk-out fallback ${describeTarget(fallback)} candidates=${bulkOutTargets.size}")
        }
        return fallback
    }

    private fun findUsbPrinterTarget(device: UsbDevice): UsbPrinterTarget? {
        for (i in 0 until device.interfaceCount) {
            val usbInterface = device.getInterface(i)
            val endpoint = bulkOutEndpoint(usbInterface) ?: continue
            if (isPrinterInterface(device, usbInterface)) {
                return UsbPrinterTarget(device, usbInterface, endpoint)
            }
        }
        return null
    }

    private fun findAnyBulkOutTarget(device: UsbDevice): UsbPrinterTarget? {
        for (i in 0 until device.interfaceCount) {
            val usbInterface = device.getInterface(i)
            val endpoint = bulkOutEndpoint(usbInterface) ?: continue
            return UsbPrinterTarget(device, usbInterface, endpoint)
        }
        return null
    }

    private fun bulkOutEndpoint(usbInterface: UsbInterface): UsbEndpoint? {
        for (i in 0 until usbInterface.endpointCount) {
            val endpoint = usbInterface.getEndpoint(i)
            if (
                endpoint.type == UsbConstants.USB_ENDPOINT_XFER_BULK &&
                endpoint.direction == UsbConstants.USB_DIR_OUT
            ) {
                return endpoint
            }
        }
        return null
    }

    private fun isPrinterInterface(device: UsbDevice, usbInterface: UsbInterface): Boolean {
        if (usbInterface.interfaceClass == UsbConstants.USB_CLASS_PRINTER) return true
        if (usbInterface.interfaceClass != UsbConstants.USB_CLASS_VENDOR_SPEC) return false
        return printerNameHint(device)
    }

    private fun targetScore(device: UsbDevice, usbInterface: UsbInterface): Int {
        var score = 0
        if (usbInterface.interfaceClass == UsbConstants.USB_CLASS_PRINTER) score += 100
        if (printerNameHint(device)) score += 50
        return score
    }

    private fun printerNameHint(device: UsbDevice): Boolean {
        val value = listOfNotNull(
            safeDeviceName { device.manufacturerName },
            safeDeviceName { device.productName },
            safeDeviceName { device.deviceName },
        ).joinToString(" ").lowercase()
        return listOf(
            "printer",
            "thermal",
            "receipt",
            "pos",
            "esc",
            "deli",
            "xprinter",
            "gprinter",
            "rongta",
            "epson",
            "zjiang",
        ).any { value.contains(it) }
    }

    private fun safeDeviceName(read: () -> String?): String? {
        return try {
            read()?.takeIf { it.isNotBlank() }
        } catch (_: Exception) {
            null
        }
    }

    private fun describeTarget(target: UsbPrinterTarget): String {
        return "${describeDevice(target.device)} ${describeInterface(target.usbInterface)} endpoint=${target.endpoint.endpointNumber}/${target.endpoint.maxPacketSize}"
    }

    private fun describeDevice(device: UsbDevice): String {
        return "vid=${device.vendorId} pid=${device.productId} name=${safeDeviceName { device.productName } ?: safeDeviceName { device.deviceName } ?: "unknown"}"
    }

    private fun describeInterface(usbInterface: UsbInterface): String {
        return "class=${usbInterface.interfaceClass} subclass=${usbInterface.interfaceSubclass} protocol=${usbInterface.interfaceProtocol} endpoints=${usbInterface.endpointCount}"
    }

    @Synchronized
    private fun printerLog(message: String, error: Throwable? = null) {
        if (error == null) {
            Log.i(PRINTER_TAG, message)
        } else {
            Log.w(PRINTER_TAG, message, error)
        }
        try {
            val timestamp = SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS", Locale.US).format(Date())
            val errorText = error?.let { " | ${it.javaClass.simpleName}: ${it.message}" } ?: ""
            val file = File(filesDir, PRINTER_DIAGNOSTICS_FILE)
            file.appendText("$timestamp $message$errorText\n")
            if (file.length() > MAX_PRINTER_DIAGNOSTICS_BYTES) {
                file.writeText(file.readText().takeLast(MAX_PRINTER_DIAGNOSTICS_BYTES / 2))
            }
        } catch (_: Exception) {
            // Diagnostics must never interfere with printing.
        }
    }

    @Synchronized
    private fun readPrinterDiagnostics(): String {
        val file = File(filesDir, PRINTER_DIAGNOSTICS_FILE)
        return if (file.exists()) file.readText() else "No printer diagnostics recorded yet."
    }

    @Synchronized
    private fun clearPrinterDiagnostics() {
        File(filesDir, PRINTER_DIAGNOSTICS_FILE).delete()
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
