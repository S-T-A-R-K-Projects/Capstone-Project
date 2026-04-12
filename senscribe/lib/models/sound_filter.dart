enum SoundFilterId {
  peopleSpeech(
    storageKey: 'people_speech',
    label: 'People & Speech',
    isBuiltInCategory: true,
  ),
  animals(
    storageKey: 'animals',
    label: 'Animals',
    isBuiltInCategory: true,
  ),
  musicPerformance(
    storageKey: 'music_performance',
    label: 'Music & Performance',
    isBuiltInCategory: true,
  ),
  vehiclesTransport(
    storageKey: 'vehicles_transport',
    label: 'Vehicles & Transport',
    isBuiltInCategory: true,
  ),
  homeObjects(
    storageKey: 'home_everyday_objects',
    label: 'Home & Everyday Objects',
    isBuiltInCategory: true,
  ),
  environmentNature(
    storageKey: 'environment_nature',
    label: 'Environment & Nature',
    isBuiltInCategory: true,
  ),
  impactsToolsAlarms(
    storageKey: 'impacts_tools_alarms',
    label: 'Impacts, Tools & Alarms',
    isBuiltInCategory: true,
  ),
  customSounds(
    storageKey: 'custom_sounds',
    label: 'Custom Sounds',
    isBuiltInCategory: false,
  );

  const SoundFilterId({
    required this.storageKey,
    required this.label,
    required this.isBuiltInCategory,
  });

  final String storageKey;
  final String label;
  final bool isBuiltInCategory;

  static final List<SoundFilterId> displayOrder =
      List<SoundFilterId>.unmodifiable(values);

  static final Set<SoundFilterId> defaultSelection =
      Set<SoundFilterId>.unmodifiable(values.toSet());

  static final Set<SoundFilterId> builtInFilters =
      Set<SoundFilterId>.unmodifiable(
    values.where((filter) => filter.isBuiltInCategory).toSet(),
  );

  static SoundFilterId? fromStorageKey(String rawValue) {
    for (final filter in values) {
      if (filter.storageKey == rawValue) {
        return filter;
      }
    }
    return null;
  }
}
