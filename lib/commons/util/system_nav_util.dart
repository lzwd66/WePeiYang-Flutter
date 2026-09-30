import 'dart:io';

import 'package:flutter/services.dart';

/// Android 系统导航模式工具：金刚键（经典三键导航）由 SystemUI 绘制在应用内容之上，
/// 页面贴底控件需按导航模式决定是否为导航栏留白
///
/// 原生实现：WbyDeviceInfoPlugin.getNavigationMode（com.twt.service/device_info）。
class SystemNavUtil {
  SystemNavUtil._();

  static const _channel = MethodChannel('com.twt.service/device_info');

  /// 当前是否为经典三键导航（金刚键）。
  ///
  /// Android 10+ 读 Settings.Secure.navigation_mode："0"=三键，"1"=两键药丸
  /// （按手势类处理，不留白），"2"=全手势；Android 10 以下只有三键，原生侧直接
  /// 返回 "0"。每次调用实时读取（毫秒级本地查询），不做缓存，避免用户中途切换
  /// 导航模式后残留过期值。
  ///
  /// 非 Android 平台及通道调用失败（插件未注册/ROM 抛异常）时返回 false——
  /// 不留白即保持现状，检测绝不能成为页面崩溃源。
  static Future<bool> isThreeButtonNav() async {
    if (!Platform.isAndroid) return false;
    try {
      /// 调用系统原生方法
      final mode = await _channel.invokeMethod<String>('getNavigationMode');
      return mode == '0';
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
