import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../models/sound_caption.dart';
import '../widgets/sound_caption_card.dart';
import '../services/audio_classification_service.dart';
import '../services/permission_service.dart';
import 'dart:async';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  bool _isMonitoring = false;
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Critical', 'Custom', 'Speech'];
  late AnimationController _pulseController;
  
  final AudioClassificationService _audioService = AudioClassificationService();
  final PermissionService _permissionService = PermissionService();
  StreamSubscription<AudioClassificationResult>? _audioSubscription;
  
  // Real-time captions data
  final List<SoundCaption> _captions = [];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _initializeAudioService();
  }

  Future<void> _initializeAudioService() async {
    try {
      await _audioService.initialize();
      _setupAudioListener();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initialize audio service: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _setupAudioListener() {
    _audioSubscription = _audioService.resultsStream.listen(
      (result) {
        if (mounted) {
          setState(() {
            // Determine if sound is critical
            final isCritical = _isCriticalSound(result.label);
            
            // Add new caption to the beginning of the list
            _captions.insert(
              0,
              SoundCaption(
                sound: result.label,
                timestamp: result.timestamp,
                isCritical: isCritical,
                direction: result.direction ?? 'Unknown',
                confidence: result.confidence,
              ),
            );
            
            // Limit to 50 most recent captions
            if (_captions.length > 50) {
              _captions.removeLast();
            }
          });
        }
      },
      onError: (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Audio processing error: $error'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      },
    );
  }

  bool _isCriticalSound(String label) {
    // Define critical sound keywords
    final criticalKeywords = [
      'siren', 'alarm', 'fire', 'smoke', 'emergency',
      'car horn', 'honk', 'beep', 'crash', 'glass',
      'scream', 'shout', 'cry', 'baby crying'
    ];
    
    final lowerLabel = label.toLowerCase();
    return criticalKeywords.any((keyword) => lowerLabel.contains(keyword));
  }

  @override
  void dispose() {
    _audioSubscription?.cancel();
    _pulseController.dispose();
    _audioService.dispose();
    super.dispose();
  }

  Future<void> _toggleMonitoring() async {
    if (!_isMonitoring) {
      print('Toggle monitoring - requesting permission via native...');
      
      // Use native iOS permission request
      final hasPermission = await _audioService.requestMicrophonePermission();
      print('Native permission result: $hasPermission');
      
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Microphone permission denied. Please enable it in Settings.'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Settings',
                textColor: Colors.white,
                onPressed: () {
                  _permissionService.openSettings();
                },
              ),
            ),
          );
        }
        return;
      }
      
      // Start monitoring
      try {
        await _audioService.startMonitoring();
        setState(() {
          _isMonitoring = true;
          _pulseController.repeat();
        });
      } catch (e) {
        if (mounted) {
          final errorMessage = e.toString().toLowerCase().contains('simulator') || 
                               e.toString().contains('0 Hz')
              ? 'Audio recording not supported on iOS Simulator. Please use a physical device.'
              : 'Failed to start monitoring: $e';
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } else {
      // Stop monitoring
      try {
        await _audioService.stopMonitoring();
        setState(() {
          _isMonitoring = false;
          _pulseController.stop();
          _pulseController.reset();
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to stop monitoring: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            floating: false,
            pinned: true,
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            title: Text(
              'SenScribe',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.secondary,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Monitoring Status Card
                        Card(
                          elevation: 4,
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                AnimatedBuilder(
                                  animation: _pulseController,
                                  builder: (context, child) {
                                    return Transform.scale(
                                      scale: _isMonitoring 
                                        ? 1.0 + (_pulseController.value * 0.2)
                                        : 1.0,
                                      child: Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: _isMonitoring 
                                            ? Colors.green.withValues(alpha: 0.2)
                                            : Colors.grey.withValues(alpha: 0.2),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          _isMonitoring ? Icons.mic_rounded : Icons.mic_off_rounded,
                                          size: 24,
                                          color: _isMonitoring ? Colors.green : Colors.grey,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _isMonitoring ? 'Monitoring Active' : 'Monitoring Stopped',
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          color: _isMonitoring ? Colors.green : Colors.grey[600],
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        _isMonitoring 
                                          ? 'Listening for sounds...' 
                                          : 'Tap to start monitoring',
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: _toggleMonitoring,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _isMonitoring ? Colors.red : Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  ),
                                  child: Text(_isMonitoring ? 'Stop' : 'Start'),
                                ).animate()
                                  .scale(duration: 200.ms)
                                  .then()
                                  .shimmer(duration: 1000.ms, delay: 500.ms),
                              ],
                            ),
                          ),
                        ).animate()
                          .slideY(begin: 0.3, duration: 600.ms)
                          .fadeIn(),
                        
                        const SizedBox(height: 16),
                        
                        // Filter Chips
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _filters.asMap().entries.map((entry) {
                              final index = entry.key;
                              final filter = entry.value;
                              final isSelected = _selectedFilter == filter;
                              
                              return AnimationConfiguration.staggeredList(
                                position: index,
                                duration: const Duration(milliseconds: 375),
                                child: SlideAnimation(
                                  horizontalOffset: 50.0,
                                  child: FadeInAnimation(
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: FilterChip(
                                        label: Text(
                                          filter,
                                          style: GoogleFonts.inter(
                                            color: isSelected ? Colors.white : Colors.black87,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        selected: isSelected,
                                        onSelected: (selected) {
                                          setState(() {
                                            _selectedFilter = filter;
                                          });
                                        },
                                        selectedColor: Theme.of(context).colorScheme.secondary,
                                        backgroundColor: Colors.white,
                                        elevation: 2,
                                        pressElevation: 4,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // Real-time Feed Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.hearing_rounded,
                      color: Theme.of(context).colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Real-time Sound Feed',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ).animate()
                .slideX(begin: -0.2, duration: 500.ms)
                .fadeIn(),
            ),
          ),
          
          // Sound Captions List
          _captions.isEmpty 
            ? SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.volume_off_rounded,
                        size: 80,
                        color: Colors.grey[400],
                      ).animate()
                        .scale(duration: 600.ms)
                        .then()
                        .shimmer(duration: 1000.ms),
                      const SizedBox(height: 24),
                      Text(
                        'No sounds detected yet',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Start monitoring to see live captions',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ).animate()
                    .fadeIn(duration: 800.ms)
                    .slideY(begin: 0.2),
                ),
              )
            : SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return AnimationConfiguration.staggeredList(
                      position: index,
                      duration: const Duration(milliseconds: 375),
                      child: SlideAnimation(
                        verticalOffset: 50.0,
                        child: FadeInAnimation(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: SoundCaptionCard(caption: _captions[index]),
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: _captions.length,
                ),
              ),
              
          // Bottom padding for FAB
          const SliverToBoxAdapter(
            child: SizedBox(height: 100),
          ),
        ],
      ),
    );
  }
}