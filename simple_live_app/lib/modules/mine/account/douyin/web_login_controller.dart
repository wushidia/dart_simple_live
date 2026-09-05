import 'dart:async';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/modules/mine/account/douyin/desktop_login_mode.dart';
import 'package:simple_live_app/services/douyin_account_service.dart';
import 'package:simple_live_core/simple_live_core.dart';

class DouyinWebLoginController extends BaseController {
  static const loginUrl = "https://www.douyin.com/";
  String? verificationKeyword;
  bool get isVerification => verificationKeyword != null;
  String get initialUrl => isVerification
      ? 'https://www.douyin.com/search/${Uri.encodeComponent(verificationKeyword!)}?type=user'
      : loginUrl;

  @override
  void onInit() {
    final args = Get.arguments;
    if (args is Map && args['verificationKeyword'] is String) {
      verificationKeyword = args['verificationKeyword'] as String;
    }
    super.onInit();
  }

  InAppWebViewController? webViewController;
  final progress = 0.0.obs;
  final checking = false.obs;
  final errorMessage = "".obs;
  Timer? _cookieTimer;
  bool _closed = false;
  bool _saved = false;
  bool _loading = false;

  Future<void> onWebViewCreated(InAppWebViewController controller) async {
    webViewController = controller;
    await reload();
  }

  @override
  void onClose() {
    _closed = true;
    _cookieTimer?.cancel();
    webViewController = null;
    super.onClose();
  }

  void onProgressChanged(InAppWebViewController controller, int value) {
    progress.value = value / 100;
  }

  void onLoadStart(InAppWebViewController controller, Uri? uri) {
    progress.value = 0;
    errorMessage.value = "";
  }

  void onLoadStop(InAppWebViewController controller, Uri? uri) {
    progress.value = 1;
    if (!isVerification) unawaited(saveCookie(silent: true));
  }

  void onReceivedError(
    InAppWebViewController controller,
    WebResourceRequest request,
    WebResourceError error,
  ) {
    if (request.isForMainFrame == true) {
      progress.value = 1;
      errorMessage.value = "网页加载失败，请重试或返回使用 Cookie 登录。";
    }
  }

  void onReceivedHttpError(
    InAppWebViewController controller,
    WebResourceRequest request,
    WebResourceResponse response,
  ) {
    if (request.isForMainFrame == true) {
      progress.value = 1;
      errorMessage.value = "网页加载失败（HTTP ${response.statusCode ?? '-'}），请重试。";
    }
  }

  Future<void> reload() async {
    final controller = webViewController;
    if (_closed || _loading || controller == null) return;
    _loading = true;
    errorMessage.value = "";
    try {
      await DouyinDesktopLoginMode.configure(controller.getViewId());
      if (_closed) return;
      await controller.loadUrl(urlRequest: URLRequest(url: WebUri(initialUrl)));
      if (_closed) return;
      // QR/SMS login changes cookies without necessarily navigating the SPA.
      if (!isVerification) {
        _cookieTimer ??= Timer.periodic(
          const Duration(seconds: 2),
          (_) => saveCookie(silent: true),
        );
      }
    } catch (error) {
      if (!_closed) {
        Log.logPrint(error);
        progress.value = 1;
        errorMessage.value = "网页登录初始化失败，请重试。";
      }
    } finally {
      _loading = false;
    }
  }

  Future<void> saveCookie({bool silent = false}) async {
    // An existing login cookie does not mean a security challenge was solved.
    if (isVerification && silent) return;
    if (_closed || _saved || checking.value) return;
    checking.value = true;
    try {
      final cookie = await readCookie();
      // Leaving the page while the native cookie store is being read must not
      // save a session or pop the next route.
      if (_closed) return;
      if (!DouyinCookieHelper.hasLoginSession(cookie)) {
        if (!silent) {
          SmartDialog.showToast("还没有检测到登录态，请先在页面中完成抖音登录");
        }
        return;
      }
      DouyinAccountService.instance.setCookie(cookie);
      _saved = true;
      _cookieTimer?.cancel();
      SmartDialog.showToast(isVerification
          ? '抖音登录态已更新，正在重试搜索'
          : '抖音登录态已保存，可用于搜索和关注刷新');
      Get.back(result: true);
    } catch (_) {
      // Native errors may contain URLs or credentials; do not log their text.
      if (!silent && !_closed) {
        Log.w("读取抖音网页登录状态失败");
        SmartDialog.showToast("读取登录状态失败，请重试或返回使用 Cookie 登录");
      }
    } finally {
      if (!_closed) checking.value = false;
    }
  }

  Future<String> readCookie() async {
    final values = <String, String>{};
    try {
      final nativeCookie = await DouyinDesktopLoginMode.readCookies();
      _mergeCookieHeader(values, nativeCookie);
    } catch (_) {
      // Older Android WebView/plugin combinations may not expose the native
      // channel; retain the plugin CookieManager fallback below.
    }
    final cookieManager = CookieManager.instance();
    for (final url in const [
      "https://www.douyin.com/",
      "https://live.douyin.com/",
      "https://douyin.com/",
    ]) {
      // The native cookie store includes HttpOnly cookies that document.cookie
      // cannot read. Prefer www cookies when hosts have duplicate names.
      final cookies = await cookieManager.getCookies(url: WebUri(url));
      for (final item in cookies) {
        final name = item.name.trim();
        final value = item.value.trim();
        if (name.isNotEmpty && value.isNotEmpty) {
          values.putIfAbsent(name, () => value);
        }
      }
    }
    return values.entries.map((e) => "${e.key}=${e.value}").join("; ");
  }

  void _mergeCookieHeader(Map<String, String> values, String? cookieHeader) {
    for (final item in (cookieHeader ?? '').split(';')) {
      final separator = item.indexOf('=');
      if (separator <= 0) continue;
      final name = item.substring(0, separator).trim();
      final value = item.substring(separator + 1).trim();
      if (name.isNotEmpty && value.isNotEmpty) {
        values.putIfAbsent(name, () => value);
      }
    }
  }

  String get userAgent => DouyinDesktopLoginMode.userAgent;
}
