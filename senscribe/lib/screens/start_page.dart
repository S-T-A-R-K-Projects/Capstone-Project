import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class StartPage extends StatefulWidget {
  final VoidCallback? onGetStarted;

  const StartPage({Key? key, this.onGetStarted}) : super(key: key);

  @override
  State<StartPage> createState() => _StartPageState();
}

class _OnboardingStep {
  final IconData icon;
  final String title;
  final String description;

  const _OnboardingStep({
    required this.icon,
    required this.title,
    required this.description,
  });
}

class _StartPageState extends State<StartPage> {
  final PageController _pageController = PageController();
  int _pageIndex = 0;

  static const List<_OnboardingStep> _steps = [
    _OnboardingStep(
      icon: Icons.volume_up,
      title: 'Text to Speech',
      description:
          'Type text and let SenScribe speak it aloud with natural voice settings.',
    ),
    _OnboardingStep(
      icon: Icons.mic,
      title: 'Speech to Text',
      description:
          'Convert your spoken words to text for notes, transcripts, and sharing.',
    ),
    _OnboardingStep(
      icon: Icons.hearing,
      title: 'Sound Recognition',
      description:
          'Detect alarms, glass breaking, and other important sounds instantly.',
    ),
    _OnboardingStep(
      icon: Icons.history,
      title: 'History',
      description:
          'Review your past events and recognized sounds in the History section.',
    ),
    _OnboardingStep(
      icon: Icons.description,
      title: 'Summarization',
      description:
          'Generate summaries from history entries to quickly catch up on what matters.',
    ),
    _OnboardingStep(
      icon: Icons.notifications,
      title: 'Custom Alerts',
      description:
          'Add your own sounds and phrases so the app alerts you on what you care about.',
    ),
    _OnboardingStep(
      icon: Icons.settings,
      title: 'More Features',
      description:
          'Adjust permissions, monitor performance, and explore experimental tools.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goNext() {
    if (_pageIndex < _steps.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _goBack() {
    if (_pageIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _completeOnboarding() {
    widget.onGetStarted?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return SafeArea(
      top: true,
      bottom: true,
      child: AdaptiveScaffold(
        appBar: const AdaptiveAppBar(title: 'Welcome to SenScribe'),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        'assets/images/real_logo.png',
                        height: 36,
                        width: 36,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'SenScribe',
                      style: GoogleFonts.outfit(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _steps.length,
                  onPageChanged: (index) => setState(() => _pageIndex = index),
                  itemBuilder: (context, index) {
                    final step = _steps[index];
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 170,
                          height: 170,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                theme.colorScheme.primary.withOpacity(0.85),
                                theme.colorScheme.secondary.withOpacity(0.85),
                              ],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: theme.colorScheme.primary.withOpacity(
                                  0.3,
                                ),
                                blurRadius: 14,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Icon(
                              step.icon,
                              size: 72,
                              color: theme.colorScheme.onPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          step.title,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          step.description,
                          style: theme.textTheme.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _steps.length,
                    (index) => Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _pageIndex == index
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface.withOpacity(0.25),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(bottom: 12 + bottomInset),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: _pageIndex > 0 ? _goBack : null,
                          child: const Text('Back'),
                        ),
                        TextButton(
                          onPressed: _completeOnboarding,
                          child: const Text('Skip'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    AdaptiveButton(
                      label: _pageIndex == _steps.length - 1
                          ? 'Start using SenScribe'
                          : 'Next',
                      onPressed: _goNext,
                      style: AdaptiveButtonStyle.filled,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
