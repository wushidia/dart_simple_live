import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/services/local_storage_service.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_app/modules/mine/account/douyin/desktop_login_mode.dart';

class DouyinAccountService extends GetxService {
  static DouyinAccountService get instance => Get.find<DouyinAccountService>();

  var cookie = "";
  var hasCookie = false.obs;

  @override
  void onInit() {
    cookie = LocalStorageService.instance
        .getValue(LocalStorageService.kDouyinCookie, "");
    hasCookie.value = cookie.isNotEmpty;
    setSite();
    super.onInit();
    unawaited(refreshFromWebView());
  }

  void setSite() {
    var site = (Sites.allSites[Constant.kDouyin]!.liveSite as DouyinSite);
    site.cookie = cookie;
  }

  void setCookie(String cookie) {
    this.cookie = cookie;
    LocalStorageService.instance
        .setValue(LocalStorageService.kDouyinCookie, cookie);
    hasCookie.value = cookie.isNotEmpty;
    setSite();
  }

  void clearCookie() {
    cookie = "";
    LocalStorageService.instance
        .setValue(LocalStorageService.kDouyinCookie, "");
    hasCookie.value = false;
    setSite();
  }

  Future<void> refreshFromWebView() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final webCookie = await DouyinDesktopLoginMode.readCookies();
      if (webCookie == null || !DouyinCookieHelper.hasLoginSession(webCookie)) {
        return;
      }
      if (webCookie != cookie) {
        setCookie(webCookie);
      }
    } catch (_) {
      // The WebView channel is unavailable on older/non-Android builds.
    }
  }
}
