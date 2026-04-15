import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

class AppLogger {
  static const String _navigationLogName = 'SenScribe.Navigation';
  static const String _errorLogName = 'SenScribe.Errors';

  static String? _currentPageName;
  static String? _currentSectionName;

  static String? get currentPageName => _currentPageName;
  static String? get currentSectionName => _currentSectionName;

  static void logPageVisit(String pageName) {
    _currentPageName = pageName;
    _currentSectionName = null;
    _emitNavigation('On page: $pageName');
  }

  static void logSectionOpened(
    String sectionName, {
    String? targetPageName,
  }) {
    _currentSectionName = sectionName;
    _emitNavigation('Opened: $sectionName');
    if (targetPageName != null) {
      _currentPageName = targetPageName;
      _emitNavigation('On page: $targetPageName');
    }
  }

  static void logFlutterError(FlutterErrorDetails details) {
    final message = _buildErrorMessage('FlutterError');
    _emitError(message);
    developer.log(
      message,
      name: _errorLogName,
      error: details.exception,
      stackTrace: details.stack,
    );
  }

  static void logUnhandledError(Object error, StackTrace stackTrace) {
    final message = _buildErrorMessage('UnhandledError');
    _emitError(message);
    developer.log(
      message,
      name: _errorLogName,
      error: error,
      stackTrace: stackTrace,
    );
  }

  static String _buildErrorMessage(String prefix) {
    final pageName = _currentPageName ?? 'unknown';
    final sectionName = _currentSectionName;
    if (sectionName == null || sectionName.isEmpty) {
      return '$prefix on page: $pageName';
    }
    return '$prefix on page: $pageName | section: $sectionName';
  }

  static void _emitNavigation(String message) {
    developer.log(message, name: _navigationLogName);
    debugPrintSynchronously('[SenScribe] $message');
  }

  static void _emitError(String message) {
    developer.log(message, name: _errorLogName);
    debugPrintSynchronously('[SenScribe] $message');
  }
}
