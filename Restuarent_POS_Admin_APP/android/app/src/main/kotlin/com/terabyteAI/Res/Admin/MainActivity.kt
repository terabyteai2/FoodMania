package com.terabyteai.foodmania.posadmin

import android.content.ContentValues
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
 * side to install a user-picked sound file into Android's MediaStore. The
 * resulting `content://` URI is readable by the NotificationManager
 * (system_server) — a plain `file://` URI to the app's private storage is
 * not, which is why custom channel sounds were playing silently before.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "com.terabyteai.foodmania/notification_sound"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
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
                        // Used as a fallback so the channel always has an
                        // explicit sound URI — some OEM Android builds don't
                        // play the system default when channel.sound is null.
                        result.success(
                            RingtoneManager
                                .getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                                ?.toString()
                                ?: Settings.System.DEFAULT_NOTIFICATION_URI.toString()
                        )
                    }
                    else -> result.notImplemented()
                }
            }
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

        // If a previous registration of the same source path is still around,
        // re-use it instead of cluttering MediaStore with duplicates.
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
        // DISPLAY_NAME includes a timestamp prefix; match by suffix.
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
