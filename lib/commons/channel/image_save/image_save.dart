import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class ImageSave {
  static const _channel = MethodChannel('com.twt.service/saveImg');

  /// 使用数据流保存图片到本地，可选保存到相册
  static Future<String> saveImageFromBytes(
    Uint8List data,
    String name, {
    bool album = false,
  }) async {
    final tempDir =
        await getExternalStorageDirectories(type: StorageDirectory.pictures);
    final img = File("${tempDir!.first.path}/$name")..writeAsBytesSync(data);
    if (album) {
      await _channel.invokeMethod("savePictureToAlbum", {
        "path": img.absolute.path,
      });
    }
    return img.absolute.path;
  }

  /// 使用url保存图片到本地，可选保存到相册
  static Future<String> saveImageFromUrl(
    String url,
    String fileName, {
    bool album = false,
  }) async {
    final resultPath = await _channel.invokeMethod<String>("savePictureFromUrl",
        {"url": url, "fileName": fileName, "album": album});
    return resultPath!;
  }

  /// 下载网络图片并保存到公共 DCIM 子目录（如 DCIM/wby）
  ///
  /// Android 10+ 走 MediaStore 插入，无需存储权限；Android 9- 由原生侧返回错误。
  static Future<String> saveImageToDcim(
    String url,
    String fileName, {
    String relativeDir = 'DCIM/wby',
  }) async {
    final savedName = await _channel.invokeMethod<String>("savePictureToDcim",
        {"url": url, "fileName": fileName, "relativeDir": relativeDir});
    return savedName ?? fileName;
  }
}
