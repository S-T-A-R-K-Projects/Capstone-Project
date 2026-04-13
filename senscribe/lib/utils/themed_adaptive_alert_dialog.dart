import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

Future<void> showThemedAdaptiveAlertDialog({
  required BuildContext context,
  required String title,
  String? message,
  required List<AlertAction> actions,
  dynamic icon,
  double? iconSize,
  Color? iconColor,
  String? oneTimeCode,
}) {
  final theme = Theme.of(context);
  final cupertinoTheme = MaterialBasedCupertinoThemeData(materialTheme: theme);
  final mediaQuery = MediaQuery.of(context).copyWith(
    platformBrightness: theme.brightness,
  );

  if (PlatformInfo.isIOS26OrHigher()) {
    String? iconString;
    if (icon is String) {
      iconString = icon;
    }

    return showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => MediaQuery(
        data: mediaQuery,
        child: CupertinoTheme(
          data: cupertinoTheme,
          child: IOS26AlertDialog(
            title: title,
            message: message,
            actions: actions,
            icon: iconString,
            iconSize: iconSize,
            iconColor: iconColor,
            oneTimeCode: oneTimeCode,
          ),
        ),
      ),
    );
  }

  if (PlatformInfo.isIOS) {
    return showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) {
        Widget? contentWidget;

        if (icon != null || oneTimeCode != null || message != null) {
          contentWidget = ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 60, maxHeight: 300),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (icon != null && icon is IconData && iconSize != null) ...[
                    Icon(
                      icon,
                      size: iconSize,
                      color: iconColor ?? CupertinoColors.systemBlue,
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (message != null) ...[
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (oneTimeCode != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey6,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        oneTimeCode,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Courier',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          );
        }

        return MediaQuery(
          data: mediaQuery,
          child: CupertinoTheme(
            data: cupertinoTheme,
            child: CupertinoAlertDialog(
              title: Text(title),
              content: contentWidget != null
                  ? Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: contentWidget,
                    )
                  : null,
              actions: actions.map((action) {
                return CupertinoDialogAction(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    action.onPressed();
                  },
                  isDefaultAction: action.style == AlertActionStyle.primary,
                  isDestructiveAction:
                      action.style == AlertActionStyle.destructive,
                  child: Text(action.title),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  return AdaptiveAlertDialog.show(
    context: context,
    title: title,
    message: message,
    actions: actions,
    icon: icon,
    iconSize: iconSize,
    iconColor: iconColor,
    oneTimeCode: oneTimeCode,
  );
}
