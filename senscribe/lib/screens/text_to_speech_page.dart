import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

class TextToSpeechPage extends StatefulWidget {
  final bool isMonitoring;
  final AnimationController pulseController;
  final VoidCallback onToggleMonitoring;

  const TextToSpeechPage({
    super.key,
    required this.isMonitoring,
    required this.pulseController,
    required this.onToggleMonitoring,
  });

  @override
  State<TextToSpeechPage> createState() => _TextToSpeechPageState();
}

class _TextToSpeechPageState extends State<TextToSpeechPage> {
  final TextEditingController _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _clearText() {
    setState(() {
      _textController.clear();
    });
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
                        // Speaking Status Card
                        Card(
                          elevation: 4,
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                AnimatedBuilder(
                                  animation: widget.pulseController,
                                  builder: (context, child) {
                                    return Transform.scale(
                                      scale: widget.isMonitoring
                                          ? 1.0 + (widget.pulseController.value * 0.2)
                                          : 1.0,
                                      child: Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: widget.isMonitoring
                                              ? Colors.green.withValues(alpha: 0.2)
                                              : Colors.grey.withValues(alpha: 0.2),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          widget.isMonitoring
                                              ? Icons.volume_up_rounded
                                              : Icons.volume_off_rounded,
                                          size: 24,
                                          color: widget.isMonitoring
                                              ? Colors.green
                                              : Colors.grey,
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
                                        widget.isMonitoring
                                            ? 'Monitoring Active'
                                            : 'Monitoring Stopped',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              color: widget.isMonitoring
                                                  ? Colors.green
                                                  : Colors.grey[600],
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      Text(
                                        widget.isMonitoring
                                            ? 'Listening for text...'
                                            : 'Tap to start monitoring',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: Colors.grey[600],
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: widget.onToggleMonitoring,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: widget.isMonitoring
                                        ? Colors.red
                                        : Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 12,
                                    ),
                                  ),
                                  child: Text(
                                    widget.isMonitoring ? 'Stop' : 'Start',
                                  ),
                                )
                                    .animate()
                                    .scale(duration: 200.ms)
                                    .then()
                                    .shimmer(duration: 1000.ms, delay: 500.ms),
                              ],
                            ),
                          ),
                        )
                            .animate()
                            .slideY(begin: 0.3, duration: 600.ms)
                            .fadeIn(),

                        const SizedBox(height: 64),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Text to Speech Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.volume_up_rounded,
                      color: Theme.of(context).colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Text to Speech',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const Spacer(),
                  if (_textController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: _clearText,
                      tooltip: 'Clear text',
                    ),
                ],
              ).animate().slideX(begin: -0.2, duration: 500.ms).fadeIn(),
            ),
          ),

          // Text Input Area
          SliverFillRemaining(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Enter text to convert to speech',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          maxLines: null,
                          expands: true,
                          decoration: InputDecoration(
                            hintText: 'Type or paste your text here...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Theme.of(context).colorScheme.primary,
                                width: 2,
                              ),
                            ),
                          ),
                          textAlignVertical: TextAlignVertical.top,
                        ),
                      ),
                    ],
                  ),
                ),
              )
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: 0.1),
            ),
          ),

          // Bottom padding for FAB
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}
