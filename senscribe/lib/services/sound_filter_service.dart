import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/sound_caption.dart';
import '../models/sound_filter.dart';
import '../utils/sound_filter_catalog.dart';
import 'app_settings_service.dart';

enum SoundFilterSelectionResult {
  updated,
  noChange,
}

class SoundFilterService {
  static final SoundFilterService _instance = SoundFilterService._internal();
  factory SoundFilterService() => _instance;
  SoundFilterService._internal();

  final AppSettingsService _settingsService = AppSettingsService();
  final StreamController<Set<SoundFilterId>> _selectionController =
      StreamController<Set<SoundFilterId>>.broadcast();

  Future<void>? _initializationFuture;
  final bool _platformIsAndroid = !Platform.isIOS;
  Set<SoundFilterId> _selectedFilters = Set<SoundFilterId>.from(
    SoundFilterId.defaultSelection,
  );
  Map<SoundFilterId, Set<String>> _disabledBuiltInLabelsByFilter =
      <SoundFilterId, Set<String>>{};

  Stream<Set<SoundFilterId>> get selectionStream => _selectionController.stream;
  Set<SoundFilterId> get selectedFilters =>
      Set<SoundFilterId>.unmodifiable(_selectedFilters);
  bool get hasAnySelectedFilters => _selectedFilters.isNotEmpty;
  bool get areAllFiltersSelected =>
      SoundFilterId.displayOrder.every(_selectedFilters.contains);

  Future<void> initialize() {
    if (_initializationFuture != null) {
      return _initializationFuture!;
    }

    _initializationFuture = _initializeInternal();
    return _initializationFuture!;
  }

  Future<void> _initializeInternal() async {
    final results = await Future.wait<dynamic>(<Future<dynamic>>[
      _settingsService.loadSelectedSoundFilters(),
      _settingsService.loadDisabledSoundLabelsByFilter(
        isAndroid: _platformIsAndroid,
      ),
    ]);

    final persisted = results[0] as Set<SoundFilterId>;
    final disabledLabels = results[1] as Map<SoundFilterId, Set<String>>;
    _selectedFilters = _sanitizeSelection(persisted);
    _disabledBuiltInLabelsByFilter = _sanitizeDisabledLabelMap(disabledLabels);
    _selectionController.add(selectedFilters);
  }

  Future<void> selectAllFilters() async {
    await initialize();
    final nextSelection = areAllFiltersSelected
        ? <SoundFilterId>{}
        : Set<SoundFilterId>.from(SoundFilterId.defaultSelection);
    await _updateSelection(nextSelection);
  }

  Future<SoundFilterSelectionResult> setFilterSelected(
    SoundFilterId filterId,
    bool isSelected,
  ) async {
    await initialize();

    final nextSelection = Set<SoundFilterId>.from(_selectedFilters);
    final currentlySelected = nextSelection.contains(filterId);

    if (isSelected == currentlySelected) {
      return SoundFilterSelectionResult.noChange;
    }

    if (isSelected) {
      nextSelection.add(filterId);
    } else {
      nextSelection.remove(filterId);
    }

    await _updateSelection(nextSelection);
    return SoundFilterSelectionResult.updated;
  }

  bool matchesCaption(
    SoundCaption caption, {
    Set<SoundFilterId>? selectedFilters,
    bool? isAndroid,
  }) {
    final effectiveSelection = _sanitizeSelection(selectedFilters);

    if (caption.source == SoundCaptionSource.custom) {
      return effectiveSelection.contains(SoundFilterId.customSounds);
    }

    final builtInFilters = SoundFilterCatalog.filtersForBuiltInLabel(
      caption.sound,
      isAndroid: isAndroid ?? _currentPlatformIsAndroid,
    );

    if (builtInFilters == null || builtInFilters.isEmpty) {
      return allowsUnknownBuiltInLabels(selectedFilters: effectiveSelection);
    }

    for (final filter in builtInFilters) {
      if (effectiveSelection.contains(filter) &&
          isBuiltInLabelEnabledForFilter(
            filter,
            caption.sound,
            isAndroid: isAndroid ?? _currentPlatformIsAndroid,
          )) {
        return true;
      }
    }
    return false;
  }

  bool matchesBuiltInLabel(
    String label, {
    required bool isAndroid,
    Set<SoundFilterId>? selectedFilters,
  }) {
    final effectiveSelection = _sanitizeSelection(selectedFilters);
    final builtInFilters = SoundFilterCatalog.filtersForBuiltInLabel(
      label,
      isAndroid: isAndroid,
    );

    if (builtInFilters == null || builtInFilters.isEmpty) {
      return allowsUnknownBuiltInLabels(selectedFilters: effectiveSelection);
    }

    return builtInFilters.any(
      (filter) =>
          effectiveSelection.contains(filter) &&
          isBuiltInLabelEnabledForFilter(
            filter,
            label,
            isAndroid: isAndroid,
          ),
    );
  }

  bool allowsUnknownBuiltInLabels({Set<SoundFilterId>? selectedFilters}) {
    final effectiveSelection = _sanitizeSelection(selectedFilters);
    return SoundFilterId.builtInFilters.every(effectiveSelection.contains);
  }

  List<SoundCaption> visibleCaptions(
    List<SoundCaption> captions, {
    Set<SoundFilterId>? selectedFilters,
    bool? isAndroid,
  }) {
    return captions
        .where(
          (caption) => matchesCaption(
            caption,
            selectedFilters: selectedFilters,
            isAndroid: isAndroid,
          ),
        )
        .toList(growable: false);
  }

  bool isBuiltInLabelEnabledForFilter(
    SoundFilterId filterId,
    String label, {
    bool? isAndroid,
  }) {
    if (!filterId.isBuiltInCategory) {
      return true;
    }

    final platformIsAndroid = isAndroid ?? _currentPlatformIsAndroid;
    final labelsByFilter = SoundFilterCatalog.labelsByFilterForPlatform(
      isAndroid: platformIsAndroid,
    );
    final exactLabel = _resolveKnownLabel(
      label,
      labelsByFilter[filterId] ?? const <String>{},
    );

    if (exactLabel == null) {
      return true;
    }

    final disabledLabels = _disabledBuiltInLabelsByFilter[filterId];
    return disabledLabels == null || !disabledLabels.contains(exactLabel);
  }

  List<String> enabledBuiltInLabelsForFilter(
    SoundFilterId filterId, {
    bool? isAndroid,
  }) {
    final labelsByFilter = SoundFilterCatalog.labelsByFilterForPlatform(
      isAndroid: isAndroid ?? _currentPlatformIsAndroid,
    );
    final labels = labelsByFilter[filterId]?.toList() ?? const <String>[];
    labels.sort(
        (left, right) => left.toLowerCase().compareTo(right.toLowerCase()));
    return labels
        .where(
          (label) => isBuiltInLabelEnabledForFilter(
            filterId,
            label,
            isAndroid: isAndroid,
          ),
        )
        .toList(growable: false);
  }

  Future<void> setBuiltInLabelEnabledForFilter(
    SoundFilterId filterId,
    String label,
    bool isEnabled, {
    bool? isAndroid,
  }) async {
    await initialize();

    if (!filterId.isBuiltInCategory) {
      return;
    }

    final platformIsAndroid = isAndroid ?? _currentPlatformIsAndroid;
    final labelsByFilter = SoundFilterCatalog.labelsByFilterForPlatform(
      isAndroid: platformIsAndroid,
    );
    final exactLabel = _resolveKnownLabel(
      label,
      labelsByFilter[filterId] ?? const <String>{},
    );
    if (exactLabel == null) {
      return;
    }

    final nextMap = <SoundFilterId, Set<String>>{
      for (final entry in _disabledBuiltInLabelsByFilter.entries)
        entry.key: Set<String>.from(entry.value),
    };
    final matchingFilters = SoundFilterCatalog.filtersForBuiltInLabel(
      exactLabel,
      isAndroid: platformIsAndroid,
    );
    final filtersToUpdate = matchingFilters == null || matchingFilters.isEmpty
        ? <SoundFilterId>{filterId}
        : matchingFilters;

    for (final currentFilter in filtersToUpdate) {
      final disabledLabels =
          nextMap.putIfAbsent(currentFilter, () => <String>{});

      if (isEnabled) {
        disabledLabels.remove(exactLabel);
      } else {
        disabledLabels.add(exactLabel);
      }

      if (disabledLabels.isEmpty) {
        nextMap.remove(currentFilter);
      }
    }

    _disabledBuiltInLabelsByFilter = _sanitizeDisabledLabelMap(nextMap);
    await _settingsService.saveDisabledSoundLabelsByFilter(
      _disabledBuiltInLabelsByFilter,
      isAndroid: platformIsAndroid,
    );
    _selectionController.add(selectedFilters);
  }

  Map<String, dynamic> androidLiveUpdateFilterConfig({
    Set<SoundFilterId>? selectedFilters,
  }) {
    final effectiveSelection = _sanitizeSelection(selectedFilters);
    final allowedBuiltInLabels = SoundFilterCatalog.androidKnownBuiltInLabels
        .where(
          (label) => matchesBuiltInLabel(
            label,
            isAndroid: true,
            selectedFilters: effectiveSelection,
          ),
        )
        .toList(growable: false)
      ..sort(
          (left, right) => left.toLowerCase().compareTo(right.toLowerCase()));

    return <String, dynamic>{
      'allowedBuiltInLabels': allowedBuiltInLabels,
      'allowUnknownBuiltInLabels': allowsUnknownBuiltInLabels(
        selectedFilters: effectiveSelection,
      ),
      'customSoundsEnabled':
          effectiveSelection.contains(SoundFilterId.customSounds),
    };
  }

  Future<void> _updateSelection(Set<SoundFilterId> nextSelection) async {
    final sanitized = _sanitizeSelection(nextSelection);
    _selectedFilters = sanitized;
    await _settingsService.saveSelectedSoundFilters(sanitized);
    _selectionController.add(selectedFilters);
  }

  Set<SoundFilterId> _sanitizeSelection(Set<SoundFilterId>? candidate) {
    final rawSelection = candidate ?? _selectedFilters;
    return Set<SoundFilterId>.from(rawSelection);
  }

  bool get _currentPlatformIsAndroid => !Platform.isIOS;

  Map<SoundFilterId, Set<String>> _sanitizeDisabledLabelMap(
    Map<SoundFilterId, Set<String>> candidate,
  ) {
    final sanitized = <SoundFilterId, Set<String>>{};
    final labelsByFilter = SoundFilterCatalog.labelsByFilterForPlatform(
      isAndroid: _platformIsAndroid,
    );

    for (final entry in candidate.entries) {
      if (!entry.key.isBuiltInCategory) {
        continue;
      }

      final knownLabels = labelsByFilter[entry.key] ?? const <String>{};
      final disabledLabels = entry.value
          .map((label) => _resolveKnownLabel(label, knownLabels))
          .whereType<String>()
          .toSet();
      if (disabledLabels.isNotEmpty) {
        sanitized[entry.key] = disabledLabels;
      }
    }

    return sanitized;
  }

  String? _resolveKnownLabel(String label, Set<String> candidates) {
    if (candidates.contains(label)) {
      return label;
    }

    final normalizedLabel = _normalizeLabel(label);
    for (final candidate in candidates) {
      if (_normalizeLabel(candidate) == normalizedLabel) {
        return candidate;
      }
    }
    return null;
  }

  String _normalizeLabel(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[_\-/,()]+'), ' ')
        .replaceAll('&', ' and ')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  @visibleForTesting
  Future<void> debugReset({
    Set<SoundFilterId>? selectedFilters,
    Map<SoundFilterId, Set<String>>? disabledLabelsByFilter,
  }) async {
    _initializationFuture = null;
    _selectedFilters = Set<SoundFilterId>.from(
      selectedFilters ?? SoundFilterId.defaultSelection,
    );
    _disabledBuiltInLabelsByFilter = _sanitizeDisabledLabelMap(
      disabledLabelsByFilter ?? <SoundFilterId, Set<String>>{},
    );
    if (selectedFilters != null) {
      await _settingsService.saveSelectedSoundFilters(_selectedFilters);
    }
    if (disabledLabelsByFilter != null) {
      await _settingsService.saveDisabledSoundLabelsByFilter(
        _disabledBuiltInLabelsByFilter,
        isAndroid: _platformIsAndroid,
      );
    }
  }

  @visibleForTesting
  bool get isInitializedForTesting => _initializationFuture != null;
}
