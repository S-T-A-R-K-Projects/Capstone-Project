import 'dart:io';

import '../models/sound_filter.dart';

class SoundFilterReferenceSection {
  const SoundFilterReferenceSection({
    required this.filterId,
    required this.labels,
  });

  final SoundFilterId filterId;
  final List<String> labels;
}

class SoundFilterCatalog {
  SoundFilterCatalog._();

  static final List<String> androidKnownBuiltInLabels =
      List<String>.unmodifiable(
    _androidKnownBuiltInLabelsRaw
        .trim()
        .split('\n')
        .map((label) => label.trim())
        .where((label) => label.isNotEmpty),
  );

  static final List<String> iosKnownBuiltInLabels = List<String>.unmodifiable(
    _iosKnownBuiltInLabelsRaw
        .trim()
        .split('\n')
        .map((label) => label.trim())
        .where((label) => label.isNotEmpty),
  );

  static final Map<SoundFilterId, Set<String>> _androidLabelsByFilter =
      _buildLabelsByFilter(androidKnownBuiltInLabels, isAndroid: true);
  static final Map<SoundFilterId, Set<String>> _iosLabelsByFilter =
      _buildLabelsByFilter(iosKnownBuiltInLabels, isAndroid: false);

  static final Map<String, Set<SoundFilterId>> _androidExactLookup =
      _buildExactLookup(androidKnownBuiltInLabels, isAndroid: true);
  static final Map<String, Set<SoundFilterId>> _iosExactLookup =
      _buildExactLookup(iosKnownBuiltInLabels, isAndroid: false);
  static final Map<String, Set<SoundFilterId>> _androidNormalizedLookup =
      _buildNormalizedLookup(_androidExactLookup);
  static final Map<String, Set<SoundFilterId>> _iosNormalizedLookup =
      _buildNormalizedLookup(_iosExactLookup);

  static final Map<String, Set<SoundFilterId>> _androidOverrides =
      _buildOverrideMap(const <String, List<SoundFilterId>>{
    'Air brake': <SoundFilterId>[
      SoundFilterId.vehiclesTransport,
      SoundFilterId.impactsToolsAlarms,
    ],
    'Air horn, truck horn': <SoundFilterId>[
      SoundFilterId.vehiclesTransport,
      SoundFilterId.impactsToolsAlarms,
    ],
    'Alarm': <SoundFilterId>[SoundFilterId.impactsToolsAlarms],
    'Arrow': <SoundFilterId>[SoundFilterId.impactsToolsAlarms],
    'Bell': <SoundFilterId>[
      SoundFilterId.homeObjects,
      SoundFilterId.musicPerformance,
    ],
    'Children playing': <SoundFilterId>[SoundFilterId.peopleSpeech],
    'Hands': <SoundFilterId>[SoundFilterId.peopleSpeech],
    'Hiss': <SoundFilterId>[SoundFilterId.animals],
    'Lawn mower': <SoundFilterId>[
      SoundFilterId.homeObjects,
      SoundFilterId.impactsToolsAlarms,
    ],
    'Shuffle': <SoundFilterId>[SoundFilterId.peopleSpeech],
    'Toot': <SoundFilterId>[
      SoundFilterId.vehiclesTransport,
      SoundFilterId.impactsToolsAlarms,
    ],
    'Walk, footsteps': <SoundFilterId>[SoundFilterId.peopleSpeech],
  });

  static final Map<String, Set<SoundFilterId>> _iosOverrides =
      _buildOverrideMap(const <String, List<SoundFilterId>>{
    'air_conditioner': <SoundFilterId>[SoundFilterId.homeObjects],
    'battle_cry': <SoundFilterId>[SoundFilterId.peopleSpeech],
    'bell': <SoundFilterId>[
      SoundFilterId.homeObjects,
      SoundFilterId.musicPerformance,
    ],
    'booing': <SoundFilterId>[SoundFilterId.peopleSpeech],
    'click': <SoundFilterId>[SoundFilterId.homeObjects],
    'giggling': <SoundFilterId>[SoundFilterId.peopleSpeech],
    'lawn_mower': <SoundFilterId>[
      SoundFilterId.homeObjects,
      SoundFilterId.impactsToolsAlarms,
    ],
    'playing_badminton': <SoundFilterId>[
      SoundFilterId.peopleSpeech,
      SoundFilterId.impactsToolsAlarms,
    ],
    'playing_hockey': <SoundFilterId>[
      SoundFilterId.peopleSpeech,
      SoundFilterId.impactsToolsAlarms,
    ],
    'playing_squash': <SoundFilterId>[
      SoundFilterId.peopleSpeech,
      SoundFilterId.impactsToolsAlarms,
    ],
    'playing_table_tennis': <SoundFilterId>[
      SoundFilterId.peopleSpeech,
      SoundFilterId.impactsToolsAlarms,
    ],
    'playing_tennis': <SoundFilterId>[
      SoundFilterId.peopleSpeech,
      SoundFilterId.impactsToolsAlarms,
    ],
    'playing_volleyball': <SoundFilterId>[
      SoundFilterId.peopleSpeech,
      SoundFilterId.impactsToolsAlarms,
    ],
    'sailing': <SoundFilterId>[SoundFilterId.vehiclesTransport],
  });

  static const Map<SoundFilterId, List<String>> _keywordRules =
      <SoundFilterId, List<String>>{
    SoundFilterId.peopleSpeech: <String>[
      'speech',
      'speaking',
      'conversation',
      'narration',
      'monologue',
      'babbl',
      'whisper',
      'laughter',
      'giggle',
      'snicker',
      'laugh',
      'cry',
      'sobb',
      'wail',
      'moan',
      'sigh',
      'groan',
      'grunt',
      'breathing',
      'wheeze',
      'snor',
      'cough',
      'throat',
      'sneeze',
      'sniff',
      'shout',
      'bellow',
      'whoop',
      'yell',
      'scream',
      'battle cry',
      'child speech',
      'children shouting',
      'male',
      'female',
      'human',
      'humming',
      'whistling',
      'chant',
      'mantra',
      'clap',
      'clapping',
      'applause',
      'cheer',
      'cheering',
      'booing',
      'crowd',
      'chatter',
      'burp',
      'hiccup',
      'fart',
      'finger',
      'heartbeat',
      'singing',
      'rapping',
      'gasp',
      'pant',
      'gargling',
      'stomach rumble',
      'hands',
      'heart murmur',
      'children playing',
      'person',
      'shuffle',
      'walking',
      'footsteps',
      'run',
      'nose blowing',
      'throat clearing',
      'chewing',
      'biting',
      'gulp',
      'swallowing',
      'chuckle',
      'chortle',
    ],
    SoundFilterId.animals: <String>[
      'animal',
      'bird',
      'dog',
      'cat',
      'cow',
      'pig',
      'goat',
      'horse',
      'sheep',
      'rooster',
      'chicken',
      'duck',
      'frog',
      'bee',
      'wasp',
      'fly',
      'mosquito',
      'cricket',
      'snake',
      'crocodile',
      'elephant',
      'lion',
      'tiger',
      'monkey',
      'whale',
      'dolphin',
      'owl',
      'crow',
      'coyote',
      'wolf',
      'elk',
      'canidae',
      'bovinae',
      'purr',
      'meow',
      'bark',
      'howl',
      'growl',
      'whimper',
      'moo',
      'quack',
      'chirp',
      'tweet',
      'squawk',
      'caw',
      'hoot',
      'bleat',
      'buzz',
      'yip',
      'bow wow',
      'hiss',
      'clip clop',
      'neigh',
      'whinny',
      'oink',
      'cluck',
      'turkey',
      'gobble',
      'goose',
      'roar',
      'coo',
      'mouse',
      'croak',
      'rattle',
      'patter',
      'paw',
      'vocalization',
      'bugle',
    ],
    SoundFilterId.musicPerformance: <String>[
      'music',
      'singing',
      'choir',
      'yodel',
      'rapping',
      'humming',
      'whistling',
      'piano',
      'guitar',
      'violin',
      'cello',
      'banjo',
      'drum',
      'bass',
      'accordion',
      'saxophone',
      'clarinet',
      'flute',
      'trumpet',
      'trombone',
      'harp',
      'mandolin',
      'ukulele',
      'organ',
      'sitar',
      'tabla',
      'bagpipes',
      'maraca',
      'tambourine',
      'gong',
      'orchestra',
      'a capella',
      'acapella',
      'beatboxing',
      'dj',
      'scratching',
      'lullaby',
      'anthem',
      'jingle',
      'melody',
      'song',
      'opera',
      'folk',
      'jazz',
      'blues',
      'rock',
      'metal',
      'hip hop',
      'afrobeat',
      'bluegrass',
      'carnatic',
      'classical',
      'electronic',
      'ambient music',
      'soundtrack',
      'disco',
      'reggae',
      'rhythm',
      'brass instrument',
      'string instrument',
      'woodwind',
      'percussion',
      'strum',
      'zither',
      'synthesizer',
      'sampler',
      'rimshot',
      'timpani',
      'cymbal',
      'hi hat',
      'wood block',
      'marimba',
      'xylophone',
      'glockenspiel',
      'vibraphone',
      'steelpan',
      'string section',
      'tuning fork',
      'campanology',
      'harmonica',
      'didgeridoo',
      'shofar',
      'theremin',
      'country',
      'funk',
      'techno',
      'dubstep',
      'flamenco',
      'ska',
      'oboe',
      'bassoon',
      'tuba',
      'pipe organ',
      'acoustic',
      'electric guitar',
      'lute',
      'bell',
    ],
    SoundFilterId.vehiclesTransport: <String>[
      'vehicle',
      'car',
      'bus',
      'truck',
      'train',
      'rail',
      'subway',
      'motor',
      'motorcycle',
      'bike',
      'bicycle',
      'skateboard',
      'scooter',
      'boat',
      'ship',
      'water vehicle',
      'aircraft',
      'airplane',
      'plane',
      'helicopter',
      'engine',
      'siren',
      'horn',
      'accelerating',
      'revving',
      'vroom',
      'idling',
      'brake',
      'tire',
      'wheel',
      'race car',
      'car passing by',
      'skidding',
      'traffic noise',
      'roadway noise',
      'propeller',
      'airscrew',
      'sailing',
    ],
    SoundFilterId.homeObjects: <String>[
      'door',
      'drawer',
      'cupboard',
      'cabinet',
      'dishes',
      'pots',
      'pans',
      'cutlery',
      'silverware',
      'sink',
      'faucet',
      'toilet',
      'bathtub',
      'shower',
      'washing',
      'dishwasher',
      'microwave',
      'oven',
      'blender',
      'vacuum',
      'toothbrush',
      'electric shaver',
      'hair dryer',
      'clock',
      'alarm clock',
      'camera',
      'cash register',
      'typing',
      'keyboard',
      'computer',
      'printer',
      'page',
      'paper',
      'scissors',
      'zipper',
      'keys',
      'coin',
      'bottle',
      'can',
      'ceramic',
      'porcelain',
      'fan',
      'air conditioner',
      'air conditioning',
      'telephone',
      'phone',
      'ringtone',
      'door bell',
      'doorbell',
      'bicycle bell',
      'church bell',
      'tick',
      'tick tock',
      'crumpling',
      'crinkling',
      'rolling pin',
      'marble',
      'tap',
      'click',
      'switch',
      'mechanical fan',
      'door slam',
      'door sliding',
      'drawer open close',
      'liquid filling container',
      'liquid sloshing',
      'liquid spraying',
      'liquid squishing',
      'liquid trickle dribble',
      'sewing machine',
      'ratchet and pawl',
      'keys jangling',
      'knock',
      'frying food',
      'sink filling washing',
    ],
    SoundFilterId.environmentNature: <String>[
      'rain',
      'thunder',
      'wind',
      'storm',
      'water',
      'stream',
      'river',
      'ocean',
      'sea',
      'waves',
      'surf',
      'fire',
      'crackle',
      'forest',
      'woodland',
      'nature',
      'environment',
      'eruption',
      'volcano',
      'earthquake',
      'thunderstorm',
      'rustling',
      'leaves',
      'snow',
      'ice',
      'drip',
      'pour',
      'splash',
      'boiling',
      'gurgling',
      'steam',
      'outside',
      'silence',
      'scuba diving',
      'rain on surface',
      'rainstorm',
      'wind noise',
      'fire crackle',
    ],
    SoundFilterId.impactsToolsAlarms: <String>[
      'alarm',
      'siren',
      'gunshot',
      'gun',
      'explosion',
      'boom',
      'bang',
      'smash',
      'breaking',
      'break',
      'shatter',
      'crash',
      'thud',
      'impact',
      'hit',
      'hammer',
      'drill',
      'saw',
      'chainsaw',
      'tool',
      'chop',
      'chopping',
      'axe',
      'burst',
      'pop',
      'clink',
      'chink',
      'crack',
      'whack',
      'artillery',
      'fireworks',
      'buzzer',
      'beep',
      'air horn',
      'horn',
      'whistle',
      'squeal',
      'scrape',
      'friction',
      'bounce',
      'basketball bounce',
      'bowling impact',
      'coin dropping',
      'slap',
      'punch',
      'crushing',
      'hedge trimmer',
      'lawn mower',
      'toot',
    ],
  };

  static bool get isCurrentPlatformAndroid => !Platform.isIOS;

  static Set<SoundFilterId>? filtersForBuiltInLabel(
    String label, {
    bool? isAndroid,
  }) {
    final platformIsAndroid = isAndroid ?? isCurrentPlatformAndroid;
    final exactLookup =
        platformIsAndroid ? _androidExactLookup : _iosExactLookup;
    final normalizedLookup =
        platformIsAndroid ? _androidNormalizedLookup : _iosNormalizedLookup;

    final exactMatch = exactLookup[label];
    if (exactMatch != null) {
      return exactMatch;
    }

    return normalizedLookup[_normalizeLabel(label)];
  }

  static Map<SoundFilterId, Set<String>> labelsByFilterForPlatform({
    bool? isAndroid,
  }) {
    final platformIsAndroid = isAndroid ?? isCurrentPlatformAndroid;
    return platformIsAndroid ? _androidLabelsByFilter : _iosLabelsByFilter;
  }

  static List<SoundFilterReferenceSection> referenceSectionsForPlatform({
    bool? isAndroid,
  }) {
    final labelsByFilter = labelsByFilterForPlatform(isAndroid: isAndroid);
    return SoundFilterId.displayOrder.map((filterId) {
      final labels = labelsByFilter[filterId]?.toList() ?? const <String>[];
      labels.sort(
          (left, right) => left.toLowerCase().compareTo(right.toLowerCase()));
      return SoundFilterReferenceSection(filterId: filterId, labels: labels);
    }).toList(growable: false);
  }

  static Map<String, Set<SoundFilterId>> _buildExactLookup(
    List<String> labels, {
    required bool isAndroid,
  }) {
    return Map<String, Set<SoundFilterId>>.unmodifiable(
      <String, Set<SoundFilterId>>{
        for (final label in labels)
          label: Set<SoundFilterId>.unmodifiable(
            _classifyKnownBuiltInLabel(label, isAndroid: isAndroid),
          ),
      },
    );
  }

  static Map<String, Set<SoundFilterId>> _buildNormalizedLookup(
    Map<String, Set<SoundFilterId>> exactLookup,
  ) {
    final normalizedLookup = <String, Set<SoundFilterId>>{};
    for (final entry in exactLookup.entries) {
      final normalizedKey = _normalizeLabel(entry.key);
      normalizedLookup
          .putIfAbsent(normalizedKey, () => <SoundFilterId>{})
          .addAll(
            entry.value,
          );
    }

    return Map<String, Set<SoundFilterId>>.unmodifiable(
      normalizedLookup.map(
        (key, value) => MapEntry(key, Set<SoundFilterId>.unmodifiable(value)),
      ),
    );
  }

  static Map<SoundFilterId, Set<String>> _buildLabelsByFilter(
    List<String> labels, {
    required bool isAndroid,
  }) {
    final labelsByFilter = <SoundFilterId, Set<String>>{
      for (final filter in SoundFilterId.displayOrder) filter: <String>{},
    };

    for (final label in labels) {
      final filters = _classifyKnownBuiltInLabel(label, isAndroid: isAndroid);
      for (final filter in filters) {
        labelsByFilter[filter]!.add(label);
      }
    }

    return Map<SoundFilterId, Set<String>>.unmodifiable(
      labelsByFilter.map(
        (key, value) => MapEntry(key, Set<String>.unmodifiable(value)),
      ),
    );
  }

  static Set<SoundFilterId> _classifyKnownBuiltInLabel(
    String label, {
    required bool isAndroid,
  }) {
    final overrides = isAndroid ? _androidOverrides : _iosOverrides;
    final override = overrides[label];
    if (override != null) {
      return override;
    }

    final normalizedLabel = _normalizeLabel(label);
    final matches = <SoundFilterId>{};

    for (final entry in _keywordRules.entries) {
      if (entry.value.any(
        (keyword) => normalizedLabel.contains(_normalizeLabel(keyword)),
      )) {
        matches.add(entry.key);
      }
    }

    if (matches.contains(SoundFilterId.musicPerformance) &&
        normalizedLabel.contains('alarm')) {
      matches.remove(SoundFilterId.musicPerformance);
    }

    if (matches.contains(SoundFilterId.homeObjects) &&
        _containsAny(
          normalizedLabel,
          const <String>[
            'car',
            'bus',
            'train',
            'aircraft',
            'airplane',
            'boat',
            'vehicle',
            'engine',
          ],
        ) &&
        !normalizedLabel.contains('door')) {
      matches.remove(SoundFilterId.homeObjects);
    }

    if (matches.isEmpty) {
      matches.add(SoundFilterId.homeObjects);
    }

    return Set<SoundFilterId>.unmodifiable(matches);
  }

  static Map<String, Set<SoundFilterId>> _buildOverrideMap(
    Map<String, List<SoundFilterId>> source,
  ) {
    return Map<String, Set<SoundFilterId>>.unmodifiable(
      source.map(
        (label, filters) =>
            MapEntry(label, Set<SoundFilterId>.unmodifiable(filters.toSet())),
      ),
    );
  }

  static bool _containsAny(String value, List<String> tokens) {
    for (final token in tokens) {
      if (value.contains(token)) {
        return true;
      }
    }
    return false;
  }

  static String _normalizeLabel(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[_\-/,()]+'), ' ')
        .replaceAll('&', ' and ')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  static const String _androidKnownBuiltInLabelsRaw = '''
Speech
Child speech, kid speaking
Conversation
Narration, monologue
Babbling
Speech synthesizer
Shout
Bellow
Whoop
Yell
Children shouting
Screaming
Whispering
Laughter
Baby laughter
Giggle
Snicker
Belly laugh
Chuckle, chortle
Crying, sobbing
Baby cry, infant cry
Whimper
Wail, moan
Sigh
Singing
Choir
Yodeling
Chant
Mantra
Child singing
Synthetic singing
Rapping
Humming
Groan
Grunt
Whistling
Breathing
Wheeze
Snoring
Gasp
Pant
Snort
Cough
Throat clearing
Sneeze
Sniff
Run
Shuffle
Walk, footsteps
Chewing, mastication
Biting
Gargling
Stomach rumble
Burping, eructation
Hiccup
Fart
Hands
Finger snapping
Clapping
Heart sounds, heartbeat
Heart murmur
Cheering
Applause
Chatter
Crowd
Hubbub, speech noise, speech babble
Children playing
Animal
Domestic animals, pets
Dog
Bark
Yip
Howl
Bow-wow
Growling
Whimper (dog)
Cat
Purr
Meow
Hiss
Caterwaul
Livestock, farm animals, working animals
Horse
Clip-clop
Neigh, whinny
Cattle, bovinae
Moo
Cowbell
Pig
Oink
Goat
Bleat
Sheep
Fowl
Chicken, rooster
Cluck
Crowing, cock-a-doodle-doo
Turkey
Gobble
Duck
Quack
Goose
Honk
Wild animals
Roaring cats (lions, tigers)
Roar
Bird
Bird vocalization, bird call, bird song
Chirp, tweet
Squawk
Pigeon, dove
Coo
Crow
Caw
Owl
Hoot
Bird flight, flapping wings
Canidae, dogs, wolves
Rodents, rats, mice
Mouse
Patter
Insect
Cricket
Mosquito
Fly, housefly
Buzz
Bee, wasp, etc.
Frog
Croak
Snake
Rattle
Whale vocalization
Music
Musical instrument
Plucked string instrument
Guitar
Electric guitar
Bass guitar
Acoustic guitar
Steel guitar, slide guitar
Tapping (guitar technique)
Strum
Banjo
Sitar
Mandolin
Zither
Ukulele
Keyboard (musical)
Piano
Electric piano
Organ
Electronic organ
Hammond organ
Synthesizer
Sampler
Harpsichord
Percussion
Drum kit
Drum machine
Drum
Snare drum
Rimshot
Drum roll
Bass drum
Timpani
Tabla
Cymbal
Hi-hat
Wood block
Tambourine
Rattle (instrument)
Maraca
Gong
Tubular bells
Mallet percussion
Marimba, xylophone
Glockenspiel
Vibraphone
Steelpan
Orchestra
Brass instrument
French horn
Trumpet
Trombone
Bowed string instrument
String section
Violin, fiddle
Pizzicato
Cello
Double bass
Wind instrument, woodwind instrument
Flute
Saxophone
Clarinet
Harp
Bell
Church bell
Jingle bell
Bicycle bell
Tuning fork
Chime
Wind chime
Change ringing (campanology)
Harmonica
Accordion
Bagpipes
Didgeridoo
Shofar
Theremin
Singing bowl
Scratching (performance technique)
Pop music
Hip hop music
Beatboxing
Rock music
Heavy metal
Punk rock
Grunge
Progressive rock
Rock and roll
Psychedelic rock
Rhythm and blues
Soul music
Reggae
Country
Swing music
Bluegrass
Funk
Folk music
Middle Eastern music
Jazz
Disco
Classical music
Opera
Electronic music
House music
Techno
Dubstep
Drum and bass
Electronica
Electronic dance music
Ambient music
Trance music
Music of Latin America
Salsa music
Flamenco
Blues
Music for children
New-age music
Vocal music
A capella
Music of Africa
Afrobeat
Christian music
Gospel music
Music of Asia
Carnatic music
Music of Bollywood
Ska
Traditional music
Independent music
Song
Background music
Theme music
Jingle (music)
Soundtrack music
Lullaby
Video game music
Christmas music
Dance music
Wedding music
Happy music
Sad music
Tender music
Exciting music
Angry music
Scary music
Wind
Rustling leaves
Wind noise (microphone)
Thunderstorm
Thunder
Water
Rain
Raindrop
Rain on surface
Stream
Waterfall
Ocean
Waves, surf
Steam
Gurgling
Fire
Crackle
Vehicle
Boat, Water vehicle
Sailboat, sailing ship
Rowboat, canoe, kayak
Motorboat, speedboat
Ship
Motor vehicle (road)
Car
Vehicle horn, car horn, honking
Toot
Car alarm
Power windows, electric windows
Skidding
Tire squeal
Car passing by
Race car, auto racing
Truck
Air brake
Air horn, truck horn
Reversing beeps
Ice cream truck, ice cream van
Bus
Emergency vehicle
Police car (siren)
Ambulance (siren)
Fire engine, fire truck (siren)
Motorcycle
Traffic noise, roadway noise
Rail transport
Train
Train whistle
Train horn
Railroad car, train wagon
Train wheels squealing
Subway, metro, underground
Aircraft
Aircraft engine
Jet engine
Propeller, airscrew
Helicopter
Fixed-wing aircraft, airplane
Bicycle
Skateboard
Engine
Light engine (high frequency)
Dental drill, dentist's drill
Lawn mower
Chainsaw
Medium engine (mid frequency)
Heavy engine (low frequency)
Engine knocking
Engine starting
Idling
Accelerating, revving, vroom
Door
Doorbell
Ding-dong
Sliding door
Slam
Knock
Tap
Squeak
Cupboard open or close
Drawer open or close
Dishes, pots, and pans
Cutlery, silverware
Chopping (food)
Frying (food)
Microwave oven
Blender
Water tap, faucet
Sink (filling or washing)
Bathtub (filling or washing)
Hair dryer
Toilet flush
Toothbrush
Electric toothbrush
Vacuum cleaner
Zipper (clothing)
Keys jangling
Coin (dropping)
Scissors
Electric shaver, electric razor
Shuffling cards
Typing
Typewriter
Computer keyboard
Writing
Alarm
Telephone
Telephone bell ringing
Ringtone
Telephone dialing, DTMF
Dial tone
Busy signal
Alarm clock
Siren
Civil defense siren
Buzzer
Smoke detector, smoke alarm
Fire alarm
Foghorn
Whistle
Steam whistle
Mechanisms
Ratchet, pawl
Clock
Tick
Tick-tock
Gears
Pulleys
Sewing machine
Mechanical fan
Air conditioning
Cash register
Printer
Camera
Single-lens reflex camera
Tools
Hammer
Jackhammer
Sawing
Filing (rasp)
Sanding
Power tool
Drill
Explosion
Gunshot, gunfire
Machine gun
Fusillade
Artillery fire
Cap gun
Fireworks
Firecracker
Burst, pop
Eruption
Boom
Wood
Chop
Splinter
Crack
Glass
Chink, clink
Shatter
Liquid
Splash, splatter
Slosh
Squish
Drip
Pour
Trickle, dribble
Gush
Fill (with liquid)
Spray
Pump (liquid)
Stir
Boiling
Sonar
Arrow
Whoosh, swoosh, swish
Thump, thud
Thunk
Electronic tuner
Effects unit
Chorus effect
Basketball bounce
Bang
Slap, smack
Whack, thwack
Smash, crash
Breaking
Bouncing
Whip
Flap
Scratch
Scrape
Rub
Roll
Crushing
Crumpling, crinkling
Tearing
Beep, bleep
Ping
Ding
Clang
Squeal
Creak
Rustle
Whir
Clatter
Sizzle
Clicking
Clickety-clack
Rumble
Plop
Jingle, tinkle
Hum
Zing
Boing
Crunch
Silence
Sine wave
Harmonic
Chirp tone
Sound effect
Pulse
Inside, small room
Inside, large room or hall
Inside, public space
Outside, urban or manmade
Outside, rural or natural
Reverberation
Echo
Noise
Environmental noise
Static
Mains hum
Distortion
Sidetone
Cacophony
White noise
Pink noise
Throbbing
Vibration
Television
Radio
Field recording
''';

  static const String _iosKnownBuiltInLabelsRaw = '''
accordion
acoustic_guitar
air_conditioner
air_horn
aircraft
airplane
alarm_clock
ambulance_siren
applause
artillery_fire
babble
baby_crying
baby_laughter
bagpipes
banjo
basketball_bounce
bass_drum
bass_guitar
bassoon
bathtub_filling_washing
battle_cry
bee_buzz
beep
bell
belly_laugh
bicycle
bicycle_bell
bird
bird_chirp_tweet
bird_flapping
bird_squawk
bird_vocalization
biting
blender
boat_water_vehicle
boiling
booing
boom
bowed_string_instrument
bowling_impact
brass_instrument
breathing
burp
bus
camera
car_horn
car_passing_by
cat
cat_meow
cat_purr
cello
chainsaw
chatter
cheering
chewing
chicken
chicken_cluck
children_shouting
chime
choir_singing
chopping_food
chopping_wood
chuckle_chortle
church_bell
civil_defense_siren
clapping
clarinet
click
clock
coin_dropping
cough
cow_moo
cowbell
coyote_howl
cricket_chirp
crow_caw
crowd
crumpling_crinkling
crushing
crying_sobbing
cutlery_silverware
cymbal
didgeridoo
disc_scratching
dishes_pots_pans
dog
dog_bark
dog_bow_wow
dog_growl
dog_howl
dog_whimper
door
door_bell
door_slam
door_sliding
double_bass
drawer_open_close
drill
drum
drum_kit
duck_quack
electric_guitar
electric_piano
electric_shaver
electronic_organ
elk_bugle
emergency_vehicle
engine
engine_accelerating_revving
engine_idling
engine_knocking
engine_starting
eruption
finger_snapping
fire
fire_crackle
fire_engine_siren
firecracker
fireworks
flute
fly_buzz
foghorn
fowl
french_horn
frog
frog_croak
frying_food
gargling
gasp
giggling
glass_breaking
glass_clink
glockenspiel
gong
goose_honk
guitar
guitar_strum
guitar_tapping
gunshot_gunfire
gurgling
hair_dryer
hammer
hammond_organ
harmonica
harp
harpsichord
hedge_trimmer
helicopter
hi_hat
hiccup
horse_clip_clop
horse_neigh
humming
insect
keyboard_musical
keys_jangling
knock
laughter
lawn_mower
lion_roar
liquid_dripping
liquid_filling_container
liquid_pouring
liquid_sloshing
liquid_splashing
liquid_spraying
liquid_squishing
liquid_trickle_dribble
mallet_percussion
mandolin
marimba_xylophone
mechanical_fan
microwave_oven
mosquito_buzz
motorboat_speedboat
motorcycle
music
nose_blowing
oboe
ocean
orchestra
organ
owl_hoot
percussion
person_running
person_shuffling
person_walking
piano
pig_oink
pigeon_dove_coo
playing_badminton
playing_hockey
playing_squash
playing_table_tennis
playing_tennis
playing_volleyball
plucked_string_instrument
police_siren
power_tool
power_windows
printer
race_car
rail_transport
railroad_car
rain
raindrop
rapping
ratchet_and_pawl
rattle_instrument
reverse_beeps
ringtone
rooster_crow
rope_skipping
rowboat_canoe_kayak
sailing
saw
saxophone
scissors
screaming
scuba_diving
sea_waves
sewing_machine
sheep_bleat
shofar
shout
sigh
silence
singing
singing_bowl
sink_filling_washing
siren
sitar
skateboard
skiing
slap_smack
slurp
smoke_detector
snake_hiss
snake_rattle
snare_drum
sneeze
snicker
snoring
speech
squeak
steel_guitar_slide_guitar
steelpan
stream_burbling
subway_metro
synthesizer
tabla
tambourine
tap
tearing
telephone
telephone_bell_ringing
theremin
thump_thud
thunder
thunderstorm
tick
tick_tock
timpani
toilet_flush
toothbrush
traffic_noise
train
train_horn
train_wheels_squealing
train_whistle
trombone
truck
trumpet
tuning_fork
turkey_gobble
typewriter
typing
typing_computer_keyboard
ukulele
underwater_bubbling
vacuum_cleaner
vehicle_skidding
vibraphone
violin_fiddle
water
water_pump
water_tap_faucet
waterfall
whale_vocalization
whispering
whistling
whoosh_swoosh_swish
wind
wind_chime
wind_instrument
wind_noise_microphone
wind_rustling_leaves
wood_cracking
writing
yell
yodeling
zipper
zither
''';
}
