import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/custom_sound_profile.dart';

class CustomSoundService {
  static const _kProfilesKey = 'custom_sound_profiles_v1';
  static const MethodChannel _methodChannel =
      MethodChannel('senscribe/audio_classifier');
  static const int maxProfiles = 5;

  static final CustomSoundService _instance = CustomSoundService._internal();
  factory CustomSoundService() => _instance;
  CustomSoundService._internal();

  final _profilesController =
      StreamController<List<CustomSoundProfile>>.broadcast();

  Stream<List<CustomSoundProfile>> get profilesStream =>
      _profilesController.stream;

  Future<List<CustomSoundProfile>> loadProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final persisted = _decodeProfiles(prefs.getString(_kProfilesKey));

    if (!Platform.isIOS && !Platform.isAndroid) {
      return persisted;
    }

    try {
      final nativeProfiles = await _loadProfilesFromNative();
      final merged = _mergeProfiles(persisted, nativeProfiles);
      await saveProfiles(merged);
      return merged;
    } catch (_) {
      return persisted;
    }
  }

  Future<void> saveProfiles(List<CustomSoundProfile> profiles) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = List<CustomSoundProfile>.from(profiles)
      ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
    await prefs.setString(
      _kProfilesKey,
      CustomSoundProfile.encodeList(normalized),
    );
    _profilesController.add(List.unmodifiable(normalized));
  }

  Future<CustomSoundProfile> createDraftProfile(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Please enter a custom sound name.');
    }

    final existing = await loadProfiles();
    if (existing.length >= maxProfiles) {
      throw StateError('You can only create up to $maxProfiles custom sounds.');
    }

    final duplicate = existing.any(
      (profile) => profile.name.toLowerCase() == trimmed.toLowerCase(),
    );
    if (duplicate) {
      throw StateError('A custom sound with that name already exists.');
    }

    final now = DateTime.now();
    final profile = CustomSoundProfile(
      id: const Uuid().v4(),
      name: trimmed,
      createdAt: now,
      updatedAt: now,
    );

    final updated = List<CustomSoundProfile>.from(existing)..insert(0, profile);
    await saveProfiles(updated);
    return profile;
  }

  Future<CustomSoundProfile> captureTargetSample(
    CustomSoundProfile profile,
    int sampleIndex,
  ) {
    return _captureSample(
      profile,
      sampleKind: 'target',
      sampleIndex: sampleIndex,
    );
  }

  Future<CustomSoundProfile> captureBackgroundSample(
    CustomSoundProfile profile,
  ) {
    return _captureSample(
      profile,
      sampleKind: 'background',
      sampleIndex: 0,
    );
  }

  Future<List<CustomSoundProfile>> trainOrRebuildModel() async {
    if (!Platform.isIOS && !Platform.isAndroid) {
      return loadProfiles();
    }

    final response = await _methodChannel.invokeMethod<dynamic>(
      'trainOrRebuildCustomModel',
    );

    final profiles = _profilesFromDynamic(response);
    await saveProfiles(profiles);
    return profiles;
  }

  Future<CustomSoundProfile> setEnabled(String profileId, bool enabled) async {
    if (!Platform.isIOS && !Platform.isAndroid) {
      final profiles = await loadProfiles();
      final index = profiles.indexWhere((profile) => profile.id == profileId);
      if (index == -1) {
        throw StateError('Custom sound not found.');
      }
      final updatedProfile = profiles[index].copyWith(
        enabled: enabled,
        updatedAt: DateTime.now(),
      );
      final next = List<CustomSoundProfile>.from(profiles)
        ..[index] = updatedProfile;
      await saveProfiles(next);
      return updatedProfile;
    }

    final response = await _methodChannel.invokeMethod<dynamic>(
      'setCustomSoundEnabled',
      <String, dynamic>{
        'soundId': profileId,
        'enabled': enabled,
      },
    );

    final updatedProfile = _profileFromDynamic(response);
    await _upsertProfile(updatedProfile);
    await trainOrRebuildModel();
    return updatedProfile;
  }

  Future<void> deleteProfile(String profileId) async {
    final profiles = await loadProfiles();
    final next = profiles.where((profile) => profile.id != profileId).toList();
    await saveProfiles(next);

    if (!Platform.isIOS && !Platform.isAndroid) {
      return;
    }

    await _methodChannel.invokeMethod<void>(
      'deleteCustomSound',
      <String, dynamic>{'soundId': profileId},
    );
    await trainOrRebuildModel();
  }

  Future<void> discardDraft(String profileId) async {
    final profiles = await loadProfiles();
    CustomSoundProfile? profile;
    for (final entry in profiles) {
      if (entry.id == profileId) {
        profile = entry;
        break;
      }
    }
    if (profile == null) return;
    if (profile.targetSampleCount > 0 || profile.backgroundSampleCount > 0) {
      return;
    }
    await deleteProfile(profileId);
  }

  Future<void> refresh() async {
    final profiles = await loadProfiles();
    _profilesController.add(List.unmodifiable(profiles));
  }

  Future<CustomSoundProfile> _captureSample(
    CustomSoundProfile profile, {
    required String sampleKind,
    required int sampleIndex,
  }) async {
    if (!Platform.isIOS && !Platform.isAndroid) {
      throw UnsupportedError(
        'Custom sound enrollment is currently supported on iOS and Android only.',
      );
    }

    final response = await _methodChannel.invokeMethod<dynamic>(
      'captureSample',
      <String, dynamic>{
        'soundId': profile.id,
        'name': profile.name,
        'sampleKind': sampleKind,
        'sampleIndex': sampleIndex,
      },
    );

    final updatedProfile = _profileFromDynamic(response);
    await _upsertProfile(updatedProfile);
    return updatedProfile;
  }

  Future<List<CustomSoundProfile>> _loadProfilesFromNative() async {
    final response =
        await _methodChannel.invokeMethod<dynamic>('loadCustomSounds');
    return _profilesFromDynamic(response);
  }

  Future<void> _upsertProfile(CustomSoundProfile profile) async {
    final profiles = await loadProfiles();
    final index = profiles.indexWhere((entry) => entry.id == profile.id);
    final updated = List<CustomSoundProfile>.from(profiles);
    if (index == -1) {
      updated.insert(0, profile);
    } else {
      updated[index] = profile;
    }
    await saveProfiles(updated);
  }

  List<CustomSoundProfile> _mergeProfiles(
    List<CustomSoundProfile> localProfiles,
    List<CustomSoundProfile> nativeProfiles,
  ) {
    final merged = <String, CustomSoundProfile>{
      for (final profile in localProfiles) profile.id: profile,
    };

    for (final profile in nativeProfiles) {
      merged[profile.id] = profile;
    }

    return merged.values.toList(growable: false);
  }

  List<CustomSoundProfile> _decodeProfiles(String? encoded) {
    if (encoded == null || encoded.isEmpty) return [];
    try {
      return CustomSoundProfile.decodeList(encoded);
    } catch (_) {
      return [];
    }
  }

  List<CustomSoundProfile> _profilesFromDynamic(dynamic response) {
    if (response is List) {
      return response
          .map((entry) => _profileFromDynamic(entry))
          .toList(growable: false);
    }
    return const [];
  }

  CustomSoundProfile _profileFromDynamic(dynamic response) {
    if (response is Map) {
      return CustomSoundProfile.fromJson(Map<String, dynamic>.from(response));
    }
    throw StateError('Unexpected custom sound response: $response');
  }
}
