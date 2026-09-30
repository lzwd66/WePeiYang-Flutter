import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:we_pei_yang_flutter/commons/channel/image_save/image_save.dart';
import 'package:we_pei_yang_flutter/commons/environment/config.dart';
import 'package:we_pei_yang_flutter/commons/themes/template/wpy_theme_data.dart';
import 'package:we_pei_yang_flutter/commons/themes/wpy_theme.dart';
import 'package:we_pei_yang_flutter/commons/util/text_util.dart';
import 'package:we_pei_yang_flutter/commons/util/toast_provider.dart';
import 'package:we_pei_yang_flutter/commons/widgets/w_button.dart';
import 'package:we_pei_yang_flutter/commons/widgets/wpy_pic.dart';

/// 路由参数：沿用项目"专用 Args 类"的约定（参考 PersonPageArgs）
class AvatarViewPageArgs {
  /// 头像文件名（Post.avatar / Floor.avatar 原样传入，相对 qnhdpic/download/origin/）
  final String avatar;
  final String nickName;
  final int uid;

  /// 匿名帖（type == 1）没有真实头像，标记后页面降级为占位图且禁用保存
  final bool anonymous;

  AvatarViewPageArgs({
    required this.avatar,
    required this.nickName,
    required this.uid,
    this.anonymous = false,
  });
}

class AvatarViewPage extends StatefulWidget {
  final AvatarViewPageArgs args;
  const AvatarViewPage(this.args);

  @override
  State<AvatarViewPage> createState() => _AvatarViewPageState();
}

class _AvatarViewPageState extends State<AvatarViewPage> {
  bool get _canSave =>
      !widget.args.anonymous && widget.args.avatar.isNotEmpty;

  String get _avatarUrl =>
      '${EnvConfig.QNHDPIC}download/origin/${widget.args.avatar}';

  /// 从文件名猜扩展名（服务端头像大多无后缀或为 jpg）
  String get _fileName {
    final raw = widget.args.avatar.split('/').last.split('#').first;
    if (raw.contains('.') && raw.split('.').last.length <= 5) return raw;
    return '$raw.jpg';
  }

  Future<void> _showSaveSheet() async {
    if (!_canSave) return;
    await showModalBottomSheet<bool>(
      context: context,
      backgroundColor:
          WpyTheme.of(context).get(WpyColorKey.primaryBackgroundColor),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18.h))),
      builder: (sheetContext) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(height: 10.h),
          WButton(
            onPressed: () async {
              try {
                ToastProvider.running('保存中…');
                await ImageSave.saveImageToDcim(_avatarUrl, _fileName);
                if (!sheetContext.mounted) return;
                Navigator.pop(sheetContext, true);
                ToastProvider.success('已保存到 DCIM/wby/');
              } on PlatformException catch (e) {
                ToastProvider.error(e.message ?? e.code);
              } catch (_) {
                ToastProvider.error('保存失败，请重试');
              }
            },
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 14.h),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.file_download_outlined,
                    color: WpyTheme.of(sheetContext).primary, size: 22.r),
                SizedBox(width: 8.w),
                Text('保存头像',
                    style: TextUtil.base.w600.NotoSansSC
                        .sp(15)
                        .primary(sheetContext)),
              ]),
            ),
          ),
          SizedBox(height: 8.h),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reverseBg =
        WpyTheme.of(context).get(WpyColorKey.reverseBackgroundColor);
    return Scaffold(
      backgroundColor: reverseBg,
      body: SafeArea(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 主体：整页手势区（长按保存）
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onLongPress: _showSaveSheet,
              child: Center(
                child: widget.args.anonymous || widget.args.avatar.isEmpty
                    // 匿名/无头像：昵称首字占位（复刻 AvatarPlaceholder 的思路）
                    ? CircleAvatar(
                        radius: 80.w,
                        backgroundColor: WpyTheme.of(context)
                            .get(WpyColorKey.secondaryBackgroundColor),
                        child: Text(
                          widget.args.nickName.isEmpty
                              ? '?'
                              : widget.args.nickName.substring(0, 1),
                          style: TextUtil.base.NotoSansSC.w400
                              .sp(56)
                              .bright(context),
                        ),
                      )
                    // 真实头像：大图（withCache 复用磁盘缓存，列表里已加载过秒开）
                    : SizedBox(
                        width: 1.sw,
                        height: 1.sw,
                        child: WpyPic(
                          _avatarUrl,
                          width: 1.sw,
                          height: 1.sw,
                          fit: BoxFit.contain,
                          withCache: true,
                          withHolder: true,
                        ),
                      ),
              ),
            ),

            // 左上角返回
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: EdgeInsets.fromLTRB(15.h, 15.h, 0, 0),
                child: WButton(
                  onPressed: () => Navigator.pop(context),
                  child: Icon(Icons.arrow_back_ios_new,
                      color: WpyTheme.of(context)
                          .get(WpyColorKey.primaryBackgroundColor),
                      size: 28.h),
                ),
              ),
            ),

            // 底部信息条：昵称 + uid + 长按提示
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: 1.sw,
                padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 20.h),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [reverseBg.withValues(alpha: 0), reverseBg],
                  ),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(
                      widget.args.nickName.isEmpty
                          ? '没名字的微友'
                          : widget.args.nickName,
                      style: TextUtil.base.w600.NotoSansSC.sp(18).bright(context)),
                  SizedBox(height: 4.h),
                  Text('uid: ${widget.args.uid}',
                      style: TextUtil.base.ProductSans.secondaryInfo(context)
                          .sp(13)),
                  SizedBox(height: 10.h),
                  Text('长按头像可保存',
                      style:
                          TextUtil.base.secondary(context).NotoSansSC.sp(12)),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
