import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/modules/mine/account/douyin/desktop_login_mode.dart';
import 'package:simple_live_app/modules/mine/account/douyin/web_login_controller.dart';

class DouyinWebLoginPage extends GetView<DouyinWebLoginController> {
  const DouyinWebLoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(controller.isVerification ? '抖音安全验证' : '抖音网页登录'),
        actions: [
          IconButton(
            tooltip: "刷新",
            onPressed: controller.reload,
            icon: const Icon(Icons.refresh),
          ),
          Obx(
            () => TextButton.icon(
              onPressed: controller.checking.value
                  ? null
                  : () => controller.saveCookie(),
              icon: const Icon(Icons.save_outlined),
              label: Text(controller.isVerification ? '完成验证并重试' : '保存'),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: Obx(() {
            final progress = controller.progress.value;
            return progress >= 1
                ? const SizedBox(height: 3)
                : LinearProgressIndicator(minHeight: 3, value: progress);
          }),
        ),
      ),
      body: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: ListTile(
              dense: true,
              leading: const Icon(Icons.qr_code_scanner),
              title: Text(controller.isVerification
                  ? '请手动完成抖音网页中的安全验证，再点击右上角“完成验证并重试”。'
                  : '点击网页中的“登录”显示二维码；双指缩放或移动，单指操作网页。登录后自动保存。'),
            ),
          ),
          Obx(() {
            final error = controller.errorMessage.value;
            if (error.isEmpty) return const SizedBox.shrink();
            return Material(
              color: Theme.of(context).colorScheme.errorContainer,
              child: ListTile(
                leading: const Icon(Icons.error_outline),
                title: Text(error),
                trailing: TextButton(
                  onPressed: controller.reload,
                  child: const Text("重试"),
                ),
              ),
            );
          }),
          Expanded(
            child: InAppWebView(
              initialUserScripts: UnmodifiableListView([
                UserScript(
                  source: DouyinDesktopLoginMode.viewportScript,
                  injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                  forMainFrameOnly: true,
                ),
              ]),
              // The controller configures native client hints before loading.
              onWebViewCreated: controller.onWebViewCreated,
              onLoadStart: controller.onLoadStart,
              onLoadStop: controller.onLoadStop,
              onProgressChanged: controller.onProgressChanged,
              onReceivedError: controller.onReceivedError,
              onReceivedHttpError: controller.onReceivedHttpError,
              initialSettings: InAppWebViewSettings(
                userAgent: controller.userAgent,
                preferredContentMode: UserPreferredContentMode.DESKTOP,
                useWideViewPort: true,
                loadWithOverviewMode: true,
                // Via uses the native WebView for pinch zoom and panning.
                supportZoom: true,
                builtInZoomControls: true,
                displayZoomControls: false,
                javaScriptEnabled: true,
                domStorageEnabled: true,
                sharedCookiesEnabled: true,
                thirdPartyCookiesEnabled: true,
                useShouldOverrideUrlLoading: true,
                javaScriptCanOpenWindowsAutomatically: true,
                supportMultipleWindows: true,
              ),
              shouldOverrideUrlLoading: (webController, action) async {
                final scheme = action.request.url?.scheme;
                return scheme == 'https' ||
                        scheme == 'http' ||
                        scheme == 'about'
                    ? NavigationActionPolicy.ALLOW
                    : NavigationActionPolicy.CANCEL;
              },
              onCreateWindow: (webController, createWindowAction) async {
                final url = createWindowAction.request.url;
                if (url != null &&
                    (url.scheme == 'https' || url.scheme == 'http')) {
                  await webController.loadUrl(urlRequest: URLRequest(url: url));
                }
                return false;
              },
            ),
          ),
        ],
      ),
    );
  }
}
