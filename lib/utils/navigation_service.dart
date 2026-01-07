import 'package:flutter/material.dart';
import 'package:ell_tall_market/core/logger.dart';

class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static Future<dynamic> navigateTo(String routeName, {Object? arguments}) {
    final navigatorState = navigatorKey.currentState;
    if (navigatorState == null) {
      AppLogger.warning('NavigationService: navigatorState is null');
      return Future.value(null);
    }
    return navigatorState.pushNamed(routeName, arguments: arguments);
  }

  static void goBack() {
    final navigatorState = navigatorKey.currentState;
    if (navigatorState == null) {
      AppLogger.warning('NavigationService: navigatorState is null');
      return;
    }
    if (navigatorState.canPop()) {
      navigatorState.pop();
    }
  }

  static Future<dynamic> replaceWith(String routeName, {Object? arguments}) {
    final navigatorState = navigatorKey.currentState;
    if (navigatorState == null) {
      AppLogger.warning('NavigationService: navigatorState is null');
      return Future.value(null);
    }
    return navigatorState.pushReplacementNamed(routeName, arguments: arguments);
  }
}
