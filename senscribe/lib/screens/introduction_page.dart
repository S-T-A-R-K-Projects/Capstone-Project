import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:introduction_screen/introduction_screen.dart';

class IntroductionPage extends StatelessWidget {
  final VoidCallback? onDone;

  const IntroductionPage({super.key, this.onDone});

  // ── Design tokens ──────────────────────────────────────────────────────────
  static const Color _bg = Color(0xFF0F1724);
  static const Color _primary = Color(0xFF8AB4FF);
  static const Color _textPrimary = Color(0xFFE7EDF8);
  static const Color _textSecondary = Color(0xFFB0BEC5);

  // ── Shared decoration ──────────────────────────────────────────────────────
  PageDecoration _pageDecoration(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isCompactHeight = screenHeight < 760;

    return PageDecoration(
      pageColor: _bg,
      titlePadding: EdgeInsets.only(
        top: isCompactHeight ? 10 : 16,
        bottom: 8,
      ),
      contentMargin: EdgeInsets.symmetric(
        horizontal: 28,
        vertical: isCompactHeight ? 6 : 10,
      ),
      bodyAlignment: Alignment.center,
      imageAlignment: Alignment.center,
      imageFlex: isCompactHeight ? 3 : 4,
      bodyFlex: isCompactHeight ? 4 : 5,
      titleTextStyle: GoogleFonts.inter(
        fontSize: 27,
        fontWeight: FontWeight.bold,
        color: _textPrimary,
        letterSpacing: 0.2,
      ),
      bodyTextStyle: GoogleFonts.inter(
        fontSize: 15.5,
        color: _textSecondary,
        height: 1.65,
      ),
    );
  }

  // ── Reusable widgets ───────────────────────────────────────────────────────
  Widget _iconBubble(
    BuildContext context,
    IconData icon, {
    required Color gradientStart,
    required Color gradientEnd,
  }) {
    final size = MediaQuery.of(context).size;
    final shortestSide = size.shortestSide;
    final bubbleSize = shortestSide < 380 ? 140.0 : 160.0;
    final iconSize = shortestSide < 380 ? 64.0 : 72.0;

    final imageOffset = size.height < 760 ? 28.0 : 36.0;

    return Center(
      child: Transform.translate(
        offset: Offset(0, imageOffset),
        child: Container(
          width: bubbleSize,
          height: bubbleSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                gradientStart.withValues(alpha: 0.90),
                gradientEnd.withValues(alpha: 0.90),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: gradientStart.withValues(alpha: 0.35),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Icon(icon, size: iconSize, color: Colors.white),
        ),
      ),
    );
  }

  Widget _title(String text) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 6),
        child: Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 27,
            fontWeight: FontWeight.bold,
            color: _textPrimary,
            letterSpacing: 0.2,
          ),
          textAlign: TextAlign.center,
        ),
      );

  Widget _body(String text) => Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 15.5,
          color: _textSecondary,
          height: 1.65,
        ),
        textAlign: TextAlign.center,
      );

  Widget _featureList() {
    final features = <(IconData, String, String)>[
      (
        Icons.graphic_eq_rounded,
        'Real-time Sound Classification',
        'Instantly identify alarms, voices, and environmental sounds.',
      ),
      (
        Icons.explore_rounded,
        'Visual Direction Detection',
        'Know exactly where a sound is coming from at a glance.',
      ),
      (
        Icons.record_voice_over_rounded,
        'AI Name Recognition',
        'Get alerted the moment your name is called.',
      ),
      (
        Icons.summarize_rounded,
        'Smart Summarization',
        'Catch up on missed audio events with concise AI summaries.',
      ),
    ];

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: features.map((entry) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(entry.$1, color: _primary, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.$2,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        entry.$3,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: _textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Pages ──────────────────────────────────────────────────────────────────
  List<PageViewModel> _buildPages(BuildContext context) => [
        // 1. Project Identity
        PageViewModel(
          titleWidget: _title('SenScribe'),
          bodyWidget: _body(
            'An Accessibility-First Sound Detection App\n\n'
            'Designed for individuals with hearing impairments and people '
            'in high-noise environments who need real-time audio awareness.',
          ),
          image: _iconBubble(
            context,
            Icons.hearing_rounded,
            gradientStart: const Color(0xFF8AB4FF),
            gradientEnd: const Color(0xFF0B57D0),
          ),
          decoration: _pageDecoration(context),
        ),

        // 2. Problem Statement
        PageViewModel(
          titleWidget: _title('The Challenge'),
          bodyWidget: _body(
            'Every day, millions of people with hearing loss miss critical '
            'environmental sounds — doorbells, fire alarms, a colleague '
            'calling their name.\n\n'
            'Existing solutions are expensive, bulky, or require specialized '
            'hardware that limits everyday independence.',
          ),
          image: _iconBubble(
            context,
            Icons.warning_amber_rounded,
            gradientStart: const Color(0xFFFF6B6B),
            gradientEnd: const Color(0xFFFF8E53),
          ),
          decoration: _pageDecoration(context),
        ),

        // 3. Core Solution
        PageViewModel(
          titleWidget: _title('Sound Made Visible'),
          bodyWidget: _body(
            'SenScribe converts surrounding audio into instant visual and '
            'haptic feedback — no extra hardware required.\n\n'
            'Real-time captions, smart alerts, and sound direction cues '
            'work together to keep you informed and safe.',
          ),
          image: _iconBubble(
            context,
            Icons.auto_awesome_rounded,
            gradientStart: const Color(0xFF66BB6A),
            gradientEnd: const Color(0xFF00ACC1),
          ),
          decoration: _pageDecoration(context),
        ),

        // 4. Key Features
        PageViewModel(
          titleWidget: _title('Key Features'),
          bodyWidget: _featureList(),
          image: _iconBubble(
            context,
            Icons.dashboard_rounded,
            gradientStart: const Color(0xFFAB47BC),
            gradientEnd: const Color(0xFF7E57C2),
          ),
          decoration: _pageDecoration(context),
        ),

        // 5. Technical Foundation
        PageViewModel(
          titleWidget: _title('Built for Trust'),
          bodyWidget: _body(
            'Powered by Flutter for seamless cross-platform performance '
            'on iOS and Android.\n\n'
            'All AI runs fully on-device — your audio data never leaves '
            'your phone, guaranteeing complete privacy and instant '
            'responses with no internet required.',
          ),
          image: _iconBubble(
            context,
            Icons.shield_rounded,
            gradientStart: const Color(0xFF29B6F6),
            gradientEnd: const Color(0xFF0288D1),
          ),
          decoration: _pageDecoration(context),
        ),
      ];

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return IntroductionScreen(
      globalBackgroundColor: _bg,
      pages: _buildPages(context),
      showSkipButton: true,
      showBackButton: true,
      showNextButton: true,
      skip: Text(
        'Skip',
        style: GoogleFonts.inter(
          color: _primary,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
      ),
      back: const Icon(Icons.arrow_back_rounded, color: _primary),
      next: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Next',
            style: GoogleFonts.inter(
              color: _primary,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_forward_rounded, color: _primary, size: 18),
        ],
      ),
      done: Text(
        'Get Started',
        style: GoogleFonts.inter(
          color: _primary,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
      onDone: onDone,
      onSkip: onDone,
      dotsDecorator: DotsDecorator(
        size: const Size(8, 8),
        activeSize: const Size(26, 8),
        color: Colors.white24,
        activeColor: _primary,
        spacing: const EdgeInsets.symmetric(horizontal: 4),
        activeShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      controlsMargin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      controlsPadding: const EdgeInsets.all(12),
      curve: Curves.easeInOut,
      animationDuration: 350,
      skipSemantic: 'Skip introduction',
      nextSemantic: 'Go to next page',
      doneSemantic: 'Finish and open SenScribe',
      backSemantic: 'Go to previous page',
    );
  }
}
