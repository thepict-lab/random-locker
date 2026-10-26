import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/navigation/app_navigation.dart';
import 'locker_controller.dart';

/// 스플래시 연출 — PICTLAB PMS 와 같은 흰 바탕 + PICT. 로고.
/// 구간을 밀리초로 적고 Interval 비율은 자동으로 계산한다.
class SplashController extends GetxController with GetSingleTickerProviderStateMixin {
  static const logoAsset = 'assets/images/thepict_logo.png';

  static const totalDuration = Duration(milliseconds: 2300);

  static const _logoStart = 0;
  static const _logoEnd = 800; // 로고가 살짝 커지며 나타난다
  static const _titleStart = 650; // 로고가 자리 잡을 즈음 앱 이름이 올라온다
  static const _titleEnd = 1350;
  static const _fadeOutStart = 1900; // 전체 페이드 아웃 → 메인

  late final AnimationController timeline;
  late final Animation<double> logoOpacity;
  late final Animation<double> logoScale;
  late final Animation<double> titleOpacity;
  late final Animation<Offset> titleOffset;
  late final Animation<double> sceneOpacity;

  static Interval _span(int startMs, int endMs, {Curve curve = Curves.linear}) {
    final total = totalDuration.inMilliseconds;
    return Interval(startMs / total, endMs / total, curve: curve);
  }

  @override
  void onInit() {
    super.onInit();
    timeline = AnimationController(vsync: this, duration: totalDuration);
    logoOpacity = CurvedAnimation(
      parent: timeline,
      curve: _span(_logoStart, _logoEnd, curve: Curves.easeOut),
    );
    logoScale = Tween<double>(begin: 0.86, end: 1).animate(CurvedAnimation(
      parent: timeline,
      curve: _span(_logoStart, _logoEnd, curve: Curves.easeOutCubic),
    ));
    titleOpacity = CurvedAnimation(
      parent: timeline,
      curve: _span(_titleStart, _titleEnd, curve: Curves.easeOutCubic),
    );
    titleOffset = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
        .animate(CurvedAnimation(
      parent: timeline,
      curve: _span(_titleStart, _titleEnd, curve: Curves.easeOutCubic),
    ));
    sceneOpacity = Tween<double>(begin: 1, end: 0).animate(CurvedAnimation(
      parent: timeline,
      curve: _span(_fadeOutStart, totalDuration.inMilliseconds, curve: Curves.easeIn),
    ));
  }

  @override
  void onReady() {
    super.onReady();
    _run();
  }

  Future<void> _run() async {
    // 로고 디코딩 전에 시작하면 빈 화면 위로 시간만 흐른다.
    final context = Get.context;
    if (context != null) {
      try {
        await precacheImage(const AssetImage(logoAsset), context)
            .timeout(const Duration(milliseconds: 800));
      } catch (_) {}
    }
    if (isClosed) return;
    // 저장 파일 읽기와 연출이 둘 다 끝나야 넘어간다.
    await Future.wait([
      timeline.forward().orCancel.catchError((_) {}),
      LockerController.to.ready,
    ]);
    if (isClosed) return;
    Get.offAllNamed<void>(PageInfo.main);
  }

  @override
  void onClose() {
    timeline.dispose();
    super.onClose();
  }
}
