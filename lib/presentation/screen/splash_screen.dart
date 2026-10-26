import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_colors.dart';
import '../controller/splash_controller.dart';

/// 스플래시 — 흰 바탕 가운데 PICT. 로고, 아래로 앱 이름
class SplashScreen extends GetView<SplashController> {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final logoWidth = (size.width * 0.18).clamp(160.0, 300.0);

    return Scaffold(
      backgroundColor: Colors.white,
      body: FadeTransition(
        opacity: controller.sceneOpacity,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FadeTransition(
                opacity: controller.logoOpacity,
                child: ScaleTransition(
                  scale: controller.logoScale,
                  child: Image.asset(
                    SplashController.logoAsset,
                    width: logoWidth,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
              SizedBox(height: logoWidth * 0.22),
              FadeTransition(
                opacity: controller.titleOpacity,
                child: SlideTransition(
                  position: controller.titleOffset,
                  child: Column(
                    children: [
                      Text(
                        '신발장 배치기',
                        style: TextStyle(
                          fontSize: logoWidth * 0.11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'SHOE LOCKER',
                        style: TextStyle(
                          fontSize: logoWidth * 0.05,
                          fontWeight: FontWeight.w600,
                          color: AppColors.inkMute,
                          letterSpacing: 3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
