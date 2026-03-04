import 'package:flutter/foundation.dart';
import 'package:live_activities/live_activities.dart';

/// Wrapper around the `live_activities` plugin.  The class is responsible for
/// initializing the plugin and creating/updating a single live activity that
/// reflects the most recent trigger word detected by the speech engine.
///
/// The iOS and Android projects still require the native setup steps described
/// in the package README (widget extension, app group, Info.plist flag, etc.).
class LiveActivityService {
  LiveActivityService._internal();
  static final LiveActivityService instance = LiveActivityService._internal();

  final LiveActivities _plugin = LiveActivities();
  String? _currentActivityId;
  bool _initialized = false;

  /// Must be called once before attempting to create or update an activity.
  ///
  /// [appGroupId] should match the App Group that you configure in Xcode
  /// for both the Runner target and the widget extension (on iOS).
  /// On Android this also requests notification permission by default.
  Future<void> init({required String appGroupId, String? urlScheme}) async {
    if (_initialized) return;
    await _plugin.init(appGroupId: appGroupId, urlScheme: urlScheme);
    _initialized = true;
  }

  /// Create a new live activity or update the existing one with the latest
  /// [triggerWord].  The map stored in the activity is intentionally simple
  /// (just a string) so it can easily be read from native extension code.
  Future<void> createOrUpdate(String triggerWord) async {
    if (!await _plugin.areActivitiesEnabled()) return;

    final Map<String, dynamic> data = {'triggerWord': triggerWord};
    try {
      if (_currentActivityId == null) {
        _currentActivityId = await _plugin.createActivity(data);
      } else {
        await _plugin.updateActivity(_currentActivityId!, data);
      }
    } catch (e) {
      debugPrint('LiveActivityService.createOrUpdate failed: $e');
    }
  }

  /// Ends the current live activity (if any).
  Future<void> endCurrent() async {
    if (_currentActivityId != null) {
      await _plugin.endActivity(_currentActivityId!);
      _currentActivityId = null;
    }
  }

  /// Ends all activities the app may have running.
  Future<void> endAll() => _plugin.endAllActivities();
}
