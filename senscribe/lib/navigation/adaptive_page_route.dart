import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../services/app_logger.dart';

Route<T> buildAdaptivePageRoute<T>({
  required WidgetBuilder builder,
  RouteSettings? settings,
  bool fullscreenDialog = false,
  bool maintainState = true,
}) {
  if (PlatformInfo.isIOS) {
    return CupertinoPageRoute<T>(
      builder: builder,
      settings: settings,
      fullscreenDialog: fullscreenDialog,
      maintainState: maintainState,
      allowSnapshotting: false,
    );
  }

  return MaterialPageRoute<T>(
    builder: builder,
    settings: settings,
    fullscreenDialog: fullscreenDialog,
    maintainState: maintainState,
  );
}

Future<T?> pushAdaptivePage<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  String? pageName,
  String? openedLabel,
  String? returnPageName,
  RouteSettings? settings,
  bool fullscreenDialog = false,
  bool maintainState = true,
}) {
  if (openedLabel != null || pageName != null) {
    AppLogger.logSectionOpened(
      openedLabel ?? pageName!,
      targetPageName: pageName,
    );
  }

  final routeSettings = settings == null
      ? (pageName == null ? null : RouteSettings(name: pageName))
      : RouteSettings(
          name: settings.name ?? pageName,
          arguments: settings.arguments,
        );

  final future = Navigator.of(context).push<T>(
    buildAdaptivePageRoute<T>(
      builder: builder,
      settings: routeSettings,
      fullscreenDialog: fullscreenDialog,
      maintainState: maintainState,
    ),
  );

  if (returnPageName == null) {
    return future;
  }

  return future.whenComplete(() {
    if (context.mounted) {
      AppLogger.logPageVisit(returnPageName);
    }
  });
}
