package com.twt.service.image

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.webkit.MimeTypeMap
import com.twt.service.common.LogUtil
import com.twt.service.common.WbyPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import okhttp3.*
import java.io.File
import java.io.FileOutputStream
import java.io.IOException

// 1. 通过 url 保存图片
// 2. 通过 path 保存图片
class WbyImageSavePlugin : WbyPlugin() {

    override val name: String
        get() = "com.twt.service/saveImg"

    private val imgDir by lazy { context.getExternalFilesDir(Environment.DIRECTORY_PICTURES) }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "savePictureToAlbum" -> savePictureToAlbum(call, result)
            "savePictureFromUrl" -> savePictureFromUrl(call, result)
            "savePictureToDcim" -> savePictureToDcim(call, result)
        }
    }

    private fun savePictureToAlbum(call: MethodCall, result: MethodChannel.Result) {
        runCatching {
            val path = call.argument<String>("path")
            if (path == null) {
                result.error("", "path is null", null)
                return
            }
            ImageSave.savePictureToAlbum(context, path)
            result.success("success")
        }.onFailure {
            result.error("", it.message, "$it")
        }
    }

    private fun savePictureFromUrl(call: MethodCall, result: MethodChannel.Result) {
        runCatching {
            val url = call.argument<String>("url")
            // TODO: path如果一样怎么办？
            val saveToAlbum = call.argument<Boolean>("album") ?: false
            if (url == null) {
                result.error("", "url is null", null)
                return
            }
            val fileName = call.argument<String>("fileName") ?: url.split("/").last()

            val path = File(imgDir, fileName).path

            val request = Request.Builder().url(url).build()
            OkHttpClient().newCall(request).enqueue(object : Callback {
                override fun onFailure(call: Call, e: IOException) {
                    result.error("", e.message, "$e")
                }

                override fun onResponse(call: Call, response: Response) {
                    response.body?.byteStream()?.let { input ->
                        FileOutputStream(path).use { output ->
                            input.copyTo(output)
                            output.flush()
                        }
                    }
                    if (saveToAlbum) {
                        ImageSave.savePictureToAlbum(context, path)
                    }
                    CoroutineScope(Dispatchers.Main).launch {
                        result.success(path)
                    }
                }
            })
        }.onFailure {
            result.error("", it.message, "$it")
        }
    }


    private fun savePictureToDcim(call: MethodCall, result: MethodChannel.Result) {
        runCatching {
            val url = call.argument<String>("url")
            val fileName = call.argument<String>("fileName") ?: url?.split("/")?.last()
            val relativeDir = call.argument<String>("relativeDir") ?: "DCIM/wby"
            if (url == null || fileName == null) {
                result.error("", "url or fileName is null", null)
                return
            }

            val request = Request.Builder().url(url).build()
            OkHttpClient().newCall(request).enqueue(object : Callback {
                override fun onFailure(call: Call, e: IOException) {
                    result.error("", e.message, "$e")
                }

                override fun onResponse(call: Call, response: Response) {
                    // Android 9- 没有公共 DCIM 写入能力（未声明存储权限），明确报错
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
                        CoroutineScope(Dispatchers.Main).launch {
                            result.error("", "仅支持 Android 10 及以上", null)
                        }
                        return
                    }
                    try {
                        if (!response.isSuccessful) throw IOException("HTTP ${response.code}")
                        val bytes = response.body?.bytes() ?: throw IOException("empty body")
                        val displayName =
                            if (fileName.contains('.')) fileName else "$fileName.jpg"

                        // MediaStore 插入：RELATIVE_PATH 决定落在 DCIM/wby，无需存储权限
                        val values = ContentValues().apply {
                            put(MediaStore.Images.Media.DISPLAY_NAME, displayName)
                            put(
                                MediaStore.Images.Media.MIME_TYPE,
                                MimeTypeMap.getSingleton()
                                    .getMimeTypeFromExtension(displayName.substringAfterLast('.'))
                                    ?: "image/jpeg"
                            )
                            put(MediaStore.Images.Media.RELATIVE_PATH, relativeDir)
                            put(MediaStore.Images.Media.IS_PENDING, 1)
                        }
                        val resolver = context.contentResolver
                        val uri = resolver.insert(
                            MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values
                        ) ?: throw IOException("MediaStore insert failed")
                        resolver.openOutputStream(uri)?.use { it.write(bytes) }
                            ?: throw IOException("openOutputStream failed")
                        values.clear()
                        values.put(MediaStore.Images.Media.IS_PENDING, 0)
                        resolver.update(uri, values, null, null)   // 结束 IS_PENDING，相册可见

                        CoroutineScope(Dispatchers.Main).launch {
                            result.success(displayName)   // OkHttp 回调在子线程，result 需切主线程
                        }
                    } catch (e: Exception) {
                        CoroutineScope(Dispatchers.Main).launch {
                            result.error("", e.message, "$e")
                        }
                    }
                }
            })
        }.onFailure {
            result.error("", it.message, "$it")
        }
    }


    companion object {
        const val TAG = "SAVE_IMAGE"
        fun log(message: String) = LogUtil.d(TAG, message)
    }
}