import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../navigation/main_navigation.dart';

typedef AdaptiveSheetBuilder<T> = Widget Function(
  BuildContext context,
  void Function(T? result) closeSheet,
);

class AdaptiveSheetAction<T> {
  const AdaptiveSheetAction({
    required this.label,
    required this.onPressed,
    this.style = AdaptiveButtonStyle.plain,
    this.expand = true,
  });

  final String label;
  final AdaptiveButtonStyle style;
  final void Function(void Function(T? result) closeSheet) onPressed;
  final bool expand;
}

Future<T?> showAdaptiveModalSheet<T>({
  required BuildContext context,
  required AdaptiveSheetBuilder<T> builder,
  bool hideMainTabBarOnIOS = true,
  bool isDismissible = true,
  bool enableDrag = true,
  bool useRootNavigator = true,
  AnimationStyle? animationStyle,
}) async {
  final shouldHideTabBar =
      hideMainTabBarOnIOS && PlatformInfo.isIOS26OrHigher();

  if (shouldHideTabBar) {
    MainNavigationPage.setTabBarHidden(true);
  }

  try {
    return await showModalBottomSheet<T>(
      context: context,
      useRootNavigator: useRootNavigator,
      isScrollControlled: true,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.28),
      sheetAnimationStyle: animationStyle ??
          const AnimationStyle(
            duration: Duration(milliseconds: 180),
            reverseDuration: Duration(milliseconds: 140),
          ),
      builder: (sheetContext) {
        void closeSheet(T? result) {
          Navigator.of(sheetContext).pop(result);
        }

        return builder(sheetContext, closeSheet);
      },
    );
  } finally {
    if (shouldHideTabBar) {
      MainNavigationPage.setTabBarHidden(false);
    }
  }
}

class AdaptiveInputSheet extends StatelessWidget {
  const AdaptiveInputSheet({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
    this.maxWidth = 560,
    this.contentPadding = const EdgeInsets.fromLTRB(20, 8, 20, 20),
  });

  final String title;
  final Widget child;
  final List<AdaptiveSheetAction<dynamic>> actions;
  final double maxWidth;
  final EdgeInsets contentPadding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final horizontalPadding =
        MediaQuery.sizeOf(context).width >= 700 ? 24.0 : 12.0;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        12,
        horizontalPadding,
        bottomInset + 12,
      ),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Material(
            color: scheme.surface,
            elevation: 24,
            shadowColor: Colors.black.withValues(alpha: 0.18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
              side: BorderSide(
                color: scheme.outline.withValues(alpha: 0.18),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: contentPadding,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 42,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 18),
                      decoration: BoxDecoration(
                        color: scheme.outline.withValues(alpha: 0.28),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 20),
                    child,
                    if (actions.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _AdaptiveInputSheetActions(actions: actions),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdaptiveInputSheetActions extends StatelessWidget {
  const _AdaptiveInputSheetActions({
    required this.actions,
  });

  final List<AdaptiveSheetAction<dynamic>> actions;

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 420;

    if (isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < actions.length; index++) ...[
            _AdaptiveInputSheetActionButton(action: actions[index]),
            if (index < actions.length - 1) const SizedBox(height: 12),
          ],
        ],
      );
    }

    return Row(
      children: [
        for (var index = 0; index < actions.length; index++) ...[
          if (actions[index].expand)
            Expanded(
              child: _AdaptiveInputSheetActionButton(action: actions[index]),
            )
          else
            _AdaptiveInputSheetActionButton(action: actions[index]),
          if (index < actions.length - 1) const SizedBox(width: 12),
        ],
      ],
    );
  }
}

class _AdaptiveInputSheetActionButton extends StatelessWidget {
  const _AdaptiveInputSheetActionButton({
    required this.action,
  });

  final AdaptiveSheetAction<dynamic> action;

  @override
  Widget build(BuildContext context) {
    return AdaptiveButton(
      onPressed: () {
        action.onPressed((result) {
          Navigator.of(context).pop(result);
        });
      },
      label: action.label,
      style: action.style,
      borderRadius: BorderRadius.circular(18),
    );
  }
}

class AdaptiveTextEntrySheet extends StatefulWidget {
  const AdaptiveTextEntrySheet({
    super.key,
    required this.title,
    required this.placeholder,
    required this.primaryActionLabel,
    this.initialValue = '',
    this.textCapitalization = TextCapitalization.none,
    this.maxLength,
    this.autofocus = true,
    this.onSubmittedValue,
  });

  final String title;
  final String placeholder;
  final String primaryActionLabel;
  final String initialValue;
  final TextCapitalization textCapitalization;
  final int? maxLength;
  final bool autofocus;
  final ValueChanged<String>? onSubmittedValue;

  @override
  State<AdaptiveTextEntrySheet> createState() => _AdaptiveTextEntrySheetState();
}

class _AdaptiveTextEntrySheetState extends State<AdaptiveTextEntrySheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final trimmedValue = _controller.text.trim();
    final value =
        widget.maxLength == null || trimmedValue.length <= widget.maxLength!
            ? trimmedValue
            : trimmedValue.substring(0, widget.maxLength!);

    widget.onSubmittedValue?.call(value);
    Navigator.of(context).pop(value.isEmpty ? null : value);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AdaptiveInputSheet(
      title: widget.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdaptiveTextField(
            controller: _controller,
            placeholder: widget.placeholder,
            autofocus: widget.autofocus,
            textCapitalization: widget.textCapitalization,
            onSubmitted: (_) => _submit(),
            style: GoogleFonts.inter(
              fontSize: 16,
              color: scheme.onSurface,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
          ),
        ],
      ),
      actions: [
        AdaptiveSheetAction<String?>(
          label: 'Cancel',
          style: AdaptiveButtonStyle.plain,
          onPressed: (closeSheet) => closeSheet(null),
        ),
        AdaptiveSheetAction<String?>(
          label: widget.primaryActionLabel,
          style: PlatformInfo.isIOS26OrHigher()
              ? AdaptiveButtonStyle.glass
              : AdaptiveButtonStyle.filled,
          onPressed: (closeSheet) => _submit(),
        ),
      ],
    );
  }
}

Future<String?> showAdaptiveTextEntrySheet({
  required BuildContext context,
  required String title,
  required String placeholder,
  required String primaryActionLabel,
  String initialValue = '',
  TextCapitalization textCapitalization = TextCapitalization.none,
  int? maxLength,
  bool autofocus = true,
  bool hideMainTabBarOnIOS = true,
}) {
  return showAdaptiveModalSheet<String>(
    context: context,
    hideMainTabBarOnIOS: hideMainTabBarOnIOS,
    builder: (sheetContext, closeSheet) {
      return AdaptiveTextEntrySheet(
        title: title,
        placeholder: placeholder,
        primaryActionLabel: primaryActionLabel,
        initialValue: initialValue,
        textCapitalization: textCapitalization,
        maxLength: maxLength,
        autofocus: autofocus,
      );
    },
  );
}
