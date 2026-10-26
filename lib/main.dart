import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'core/navigation/app_navigation.dart';
import 'core/theme/app_colors.dart';
import 'data/repository/locker_repository.dart';
import 'presentation/controller/locker_controller.dart';

/// 화면 어디서든 안내 문구를 띄울 때 쓴다
final messengerKey = GlobalKey<ScaffoldMessengerState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // 저장된 명단 · 배치는 스플래시가 도는 동안 읽는다.
  Get.put(LockerController(LockerRepository()), permanent: true).ready;
  runApp(const RandomLockerApp());
}

class RandomLockerApp extends StatelessWidget {
  const RandomLockerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: '신발장 배치기',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: messengerKey,
      initialRoute: PageInfo.splash,
      getPages: PageInfo.appNavigation,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.brand,
          primary: AppColors.brand,
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: AppColors.canvas,
        fontFamily: 'Malgun Gothic',
        fontFamilyFallback: const ['Apple SD Gothic Neo', 'Noto Sans KR', 'sans-serif'],
        dividerColor: AppColors.line,
        tooltipTheme: const TooltipThemeData(waitDuration: Duration(milliseconds: 400)),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          width: 440,
        ),
        inputDecorationTheme: InputDecorationTheme(
          isDense: true,
          filled: true,
          fillColor: AppColors.canvas,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.brand, width: 1.4),
          ),
        ),
      ),
    );
  }
}

/// 화면 아래에 짧은 안내를 띄운다.
void showToast(String message, {String? actionLabel, VoidCallback? onAction}) {
  final messenger = messengerKey.currentState;
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 4),
      action: actionLabel == null
          ? null
          : SnackBarAction(label: actionLabel, onPressed: onAction ?? () {}),
    ));
}
