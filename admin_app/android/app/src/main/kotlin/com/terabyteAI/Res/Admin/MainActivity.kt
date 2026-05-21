package com.terabyteai.foodmania.posadmin

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.ContentValues
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream

/**
 * Hosts a [MethodChannel] used by [SystemNotificationService] on the Dart
 * side to install notification sounds and create Android channels with
 * explicit audio attributes so alerts play outside the app without manual
 * channel sound toggles in system settings.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "com.terabyteai.foodmania/notification_sound"

    companion object {
        private const val PENDING_CHANNEL_ID = "pos_pending_orders_v2"
        private const val ACCEPTED_CHANNEL_ID = "pos_accepted_orders_v2"
        private const val DEFAULT_CHANNEL_ID = "pos_orders_default_v2"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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
                        val resource = call.argument<String>("resource") ?: "pending_order"
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
            R.raw.pending_order,
        )
        createChannel(
            manager,
            ACCEPTED_CHANNEL_ID,
            "Accepted order alerts",
            "Sound plays when an order is accepted.",
            R.raw.accepted_order,
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
