import 'package:get/get.dart';

import '../../presentation/controller/draw_controller.dart';
import '../../presentation/controller/splash_controller.dart';
import '../../presentation/screen/draw_screen.dart';
import '../../presentation/screen/main_screen.dart';
import '../../presentation/screen/splash_screen.dart';

abstract final class PageInfo {
  static const splash = '/splash';
  static const main = '/main';
  static const draw = '/draw';

  static final appNavigation = <GetPage<dynamic>>[
    GetPage(
      name: splash,
      page: () => const SplashScreen(),
      binding: BindingsBuilder(() {
        Get.put(SplashController());
      }),
    ),
    GetPage(
      name: main,
      page: () => const MainScreen(),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 350),
    ),
    GetPage(
      name: draw,
      page: () => const DrawScreen(),
      binding: BindingsBuilder(() {
        Get.put(DrawController());
      }),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 250),
    ),
  ];
}
