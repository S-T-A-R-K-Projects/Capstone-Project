import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../models/sound_caption.dart';
import '../widgets/sound_caption_card.dart';
import '../services/audio_classification_service.dart';

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
  final List<SoundCaption> _captions = [];
  StreamSubscription<Map<String, dynamic>>? _classificationSubscription;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _classificationSubscription?.cancel();
    if (_isMonitoring) {
      _audioService.stop();
    }
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _toggleMonitoring() async {
    if (!Platform.isIOS) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Audio classification is currently available on iOS only.')),
      );
      return;
    }

    setState(() {
      _isMonitoring = !_isMonitoring;
      if (_isMonitoring) {
        _pulseController.repeat();
      } else {
        _pulseController.stop();
        _pulseController.reset();
      }
    });

    if (_isMonitoring) {
      await _startMonitoring();
    } else {
      await _stopMonitoring();
    }
  }

  Future<void> _startMonitoring() async {
    _classificationSubscription ??= _audioService.classificationStream.listen(
      _handleClassificationEvent,
      onError: (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Audio classification error: $error')),
        );
        setState(() {
          _isMonitoring = false;
          _pulseController.stop();
          _pulseController.reset();
        });
      },
    );

    try {
      await _audioService.start();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to start monitoring: $error')),
      );
      setState(() {
        _isMonitoring = false;
        _pulseController.stop();
        _pulseController.reset();
      });
    }
  }

  Future<void> _stopMonitoring() async {
    await _audioService.stop();
  }

  void _handleClassificationEvent(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    if (type == 'status') {
      final status = data['status'] as String?;
      if (status == 'stopped' && mounted) {
        setState(() {
          _isMonitoring = false;
          _pulseController.stop();
          _pulseController.reset();
        });
      }
      return;
    }
    if (type != null && type != 'result') {
      return;
    }

    final label = data['label'] as String? ?? 'Unknown sound';
    final confidence = (data['confidence'] as num?)?.toDouble() ?? 0.0;
    final timestampMs = (data['timestampMs'] as num?)?.toInt();
    final DateTime timestamp;
    if (timestampMs != null) {
      timestamp = DateTime.fromMillisecondsSinceEpoch(timestampMs, isUtc: true).toLocal();
    } else {
      timestamp = DateTime.now();
    }

    const criticalLabels = {
      'siren',
      'fire_alarm',
      'smoke_alarm',
      'scream',
      'baby_crying',
      'dog_bark',
      'gunshot',
      'glass_breaking',
    };
    final normalizedLabel = label.toLowerCase().replaceAll(' ', '_');
    final isCritical = criticalLabels.contains(normalizedLabel);

    setState(() {
      _captions.insert(
        0,
        SoundCaption(
          sound: label,
          timestamp: timestamp,
          isCritical: isCritical,
          direction: 'Unknown',
          confidence: confidence,
        ),
      );
      if (_captions.length > 50) {
        _captions.removeRange(50, _captions.length);
      }
    });
  }

  List<SoundCaption> get _filteredCaptions {
    if (_selectedFilter == 'Critical') {
      return _captions.where((caption) => caption.isCritical).toList();
    }
    return List<SoundCaption>.from(_captions);
  }

  @override
  Widget build(BuildContext context) {
    final filteredCaptions = _filteredCaptions;

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
          filteredCaptions.isEmpty 
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
                            child: SoundCaptionCard(caption: filteredCaptions[index]),
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: filteredCaptions.length,
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
