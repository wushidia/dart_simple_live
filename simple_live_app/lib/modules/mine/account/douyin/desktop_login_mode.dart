import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Matches the default desktop mode in the supplied Via 7.3.3 APK:
/// z8/b4.c (UA), c8/rc.a (viewport), and s4/b.f (native zoom settings).
abstract final class DouyinDesktopLoginMode {
  static const _channel = MethodChannel('simple_live/douyin_desktop_webview');

  /// Apply native client hints before issuing the first page request.
  static Future<void> configure(dynamic viewId) async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await _channel.invokeMethod<void>('configure', {'viewId': viewId});
    }
  }

  static Future<String?> readCookies() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return _channel.invokeMethod<String>('readCookies');
    }
    return null;
  }

  static const userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/148.0.0.0 Safari/537.36';

  // Set a desktop CSS viewport instead of scaling the entire platform view.
  // Preserve its original width across repeated injections, as Via does, so
  // zooming cannot progressively increase the layout width.
  static const viewportScript = r'''
(() => {
  function applyDesktopViewport() {
    if (!document.head) return;
    const marker = 'data-simple-live-desktop-width';
    const viewports = Array.from(document.querySelectorAll('meta[name="viewport"]'));
    const viewport = viewports.find(meta => meta.hasAttribute(marker))
      || document.createElement('meta');
    const originalWidth = Number(viewport.getAttribute(marker)) || window.innerWidth;
    for (const meta of viewports) {
      if (meta !== viewport) meta.remove();
    }
    viewport.setAttribute('name', 'viewport');
    viewport.setAttribute(marker, String(originalWidth));
    viewport.setAttribute('content', 'width=' + Math.max(1280, originalWidth) + ', user-scalable=1');
    if (!viewport.parentNode) document.head.appendChild(viewport);
  }
  applyDesktopViewport();
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', applyDesktopViewport, { once: true });
  }
  if (document.readyState !== 'complete') {
    window.addEventListener('load', applyDesktopViewport, { once: true });
  }
})();
''';
}
