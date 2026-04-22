# Flutter Onboarding / Introduction Screen — Replication Guide

A complete step-by-step guide to recreate the exact multi-slide onboarding flow used in SenScribe. Copy the code, swap the content, and you have a production-ready first-launch experience.

---

## What You'll Build

- A 5-slide full-screen onboarding flow using the `introduction_screen` package
- Dark navy background with per-slide gradient icon bubbles
- Skip / Back / Next / Get Started navigation buttons
- Active pill-shaped dot indicator
- First-launch gate using `SharedPreferences` — shows once, never again
- Accessible semantic labels on all buttons

---

## 1. Dependencies

Add these to your `pubspec.yaml` under `dependencies`:

```yaml
dependencies:
  flutter:
    sdk: flutter

  # introduction_screen — provides the IntroductionScreen widget and PageViewModel.
  # This is the entire engine of the onboarding flow. Without it nothing works.
  introduction_screen: ^4.0.0

  # google_fonts — downloads and caches the Inter typeface at runtime.
  # Used for every Text widget in the onboarding (titles, body, buttons).
  # If you want a different font just swap 'GoogleFonts.inter(...)' calls.
  google_fonts: ^6.2.1

  # shared_preferences — a key/value store backed by NSUserDefaults (iOS)
  # or SharedPreferences (Android). We store a single boolean flag here
  # ('intro_completed') so the onboarding only shows on the very first launch.
  shared_preferences: ^2.1.0
```

Then run:

```bash
flutter pub get
```

---

## 2. File Structure

Create one new file:

```
lib/
  screens/
    introduction_page.dart   ← the entire onboarding widget lives here
  main.dart                  ← wires the first-launch gate
```

---

## 3. `introduction_page.dart` — Full Source

```dart
// ─── Imports ─────────────────────────────────────────────────────────────────
// flutter/material.dart — gives us StatelessWidget, Color, Icon, Text, etc.
import 'package:flutter/material.dart';
// google_fonts — lets us load the Inter typeface without bundling a font file.
import 'package:google_fonts/google_fonts.dart';
// introduction_screen — the package that drives the entire slide-based flow.
// Key types we use: IntroductionScreen (the root widget),
// PageViewModel (one slide), DotsDecorator (the progress indicator),
// and PageDecoration (layout/styling for a slide).
import 'package:introduction_screen/introduction_screen.dart';

// IntroductionPage is a StatelessWidget — it holds no mutable state itself.
// All state ("which slide am I on?") is managed internally by IntroductionScreen.
class IntroductionPage extends StatelessWidget {
  // onDone is a callback passed in from main.dart.
  // It is called when the user taps "Get Started" OR "Skip".
  // Making it nullable (VoidCallback?) means the widget is safe to use
  // even if no callback is provided (nothing crashes, nothing happens).
  final VoidCallback? onDone;

  const IntroductionPage({super.key, this.onDone});

  // ─────────────────────────── Design tokens ───────────────────────────────
  // Define colors once as static constants so every widget in this file
  // references the same values. Change a color here and it updates everywhere.

  static const Color _bg            = Color(0xFF0F1724); // dark navy — page background
  static const Color _primary       = Color(0xFF8AB4FF); // periwinkle blue — buttons, active dot
  static const Color _textPrimary   = Color(0xFFE7EDF8); // almost-white — slide titles
  static const Color _textSecondary = Color(0xFFB0BEC5); // cool grey — body text

  // ─────────────────────────── Shared decoration ───────────────────────────
  // PageDecoration controls how each slide is laid out and what the default
  // text styles look like. We return a new instance (not a constant) because
  // EdgeInsets constructors are not const in all Dart versions.

  PageDecoration _pageDecoration() => PageDecoration(
        pageColor: _bg,                         // background colour for this slide
        titlePadding: const EdgeInsets.only(top: 20, bottom: 8),
        contentMargin: const EdgeInsets.symmetric(horizontal: 28, vertical: 4),
        bodyAlignment: Alignment.center,        // body text sits in the centre of its area
        imageAlignment: Alignment.center,       // icon bubble sits in the centre of its area
        // imageFlex / bodyFlex split the slide vertically like a Flex widget.
        // imageFlex: 2, bodyFlex: 3  →  top 2/5 = icon, bottom 3/5 = title + text.
        // Increase imageFlex to give the icon more room; decrease for more text room.
        imageFlex: 2,
        bodyFlex: 3,
        // titleTextStyle is used when you pass a plain String to PageViewModel.title.
        // We override this by passing a titleWidget instead, but it's here as a fallback.
        titleTextStyle: GoogleFonts.inter(
          fontSize: 27,
          fontWeight: FontWeight.bold,
          color: _textPrimary,
          letterSpacing: 0.2,
        ),
        // bodyTextStyle is used when you pass a plain String to PageViewModel.body.
        // Same as above — we use bodyWidget to pass custom widgets, but this acts
        // as a sensible default.
        bodyTextStyle: GoogleFonts.inter(
          fontSize: 15.5,
          color: _textSecondary,
          height: 1.65, // line-height multiplier — 1.65× the font size
        ),
      );

  // ─────────────────────────── Reusable widgets ────────────────────────────

  // _iconBubble builds the circular gradient image shown at the top of each slide.
  // Parameters:
  //   icon          — any IconData from Icons.*
  //   gradientStart — top-left colour of the circle background
  //   gradientEnd   — bottom-right colour of the circle background
  Widget _iconBubble(
    IconData icon, {
    required Color gradientStart,
    required Color gradientEnd,
  }) {
    return Center(
      child: Container(
        width: 160,   // fixed 160×160 so every slide looks the same
        height: 160,
        decoration: BoxDecoration(
          shape: BoxShape.circle, // makes the Container a circle
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              // alpha: 0.90 = 90% opacity — slightly transparent so it looks soft
              gradientStart.withValues(alpha: 0.90),
              gradientEnd.withValues(alpha: 0.90),
            ],
          ),
          boxShadow: [
            BoxShadow(
              // shadow color = the start color at 35% opacity — matches the gradient
              color: gradientStart.withValues(alpha: 0.35),
              blurRadius: 28,             // how soft/spread the shadow is
              offset: const Offset(0, 12), // shifted 12px downward for a lifted look
            ),
          ],
        ),
        // The icon itself — white so it pops against any gradient color
        child: Icon(icon, size: 72, color: Colors.white),
      ),
    );
  }

  // _title wraps a string in a styled Text widget with extra top padding.
  // We use titleWidget (not the title string param) in PageViewModel so we
  // have full control over padding and style.
  Widget _title(String text) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 6),
        child: Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 27,
            fontWeight: FontWeight.bold,
            color: _textPrimary,
            letterSpacing: 0.2, // slight letter spacing makes bold titles breathe
          ),
          textAlign: TextAlign.center,
        ),
      );

  // _body wraps a string in a styled Text widget.
  // We use bodyWidget (not the body string param) so we can center the text
  // and control line height.
  Widget _body(String text) => Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 15.5,
          color: _textSecondary,
          height: 1.65, // generous line height improves readability on mobile
        ),
        textAlign: TextAlign.center,
      );

  // _featureList builds the scrollable list of feature rows shown on slide 4.
  // Each entry is a Dart record: (icon, bold label, grey subtitle).
  // To customise: just edit the `features` list — add, remove, or reorder tuples.
  Widget _featureList() {
    // Dart records (Dart 3+) — each tuple is (IconData, label, subtitle).
    // Access fields with entry.$1 (icon), entry.$2 (label), entry.$3 (subtitle).
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
      // BouncingScrollPhysics = iOS-style rubber-band scroll effect
      physics: const BouncingScrollPhysics(),
      child: Column(
        mainAxisSize: MainAxisSize.min, // don't expand taller than needed
        crossAxisAlignment: CrossAxisAlignment.start,
        children: features.map((entry) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 10), // gap between rows
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start, // align icon to top of text
              children: [
                // Left side: rounded square icon chip
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    // primary color at 14% opacity = subtle tinted background
                    color: _primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(entry.$1, color: _primary, size: 22),
                ),
                const SizedBox(width: 14), // horizontal gap between chip and text
                // Right side: label + subtitle, expands to fill remaining width
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.$2, // bold feature name
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        entry.$3, // lighter description below the name
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

  // ─────────────────────────── Pages ───────────────────────────────────────
  // _buildPages returns the ordered list of PageViewModel slides.
  // The order here is exactly the order the user sees them.
  // Each PageViewModel has:
  //   titleWidget — the widget shown above the body (use _title())
  //   bodyWidget  — main content for the slide (use _body() or a custom widget)
  //   image       — widget shown in the top imageFlex area (use _iconBubble())
  //   decoration  — layout + default text styles (always pass _pageDecoration())

  List<PageViewModel> _buildPages() => [
        // ── 1. Project Identity ──────────────────────────────────────────
        // Purpose: tell the user what the app is in one sentence.
        PageViewModel(
          titleWidget: _title('SenScribe'),
          bodyWidget: _body(
            'An Accessibility-First Sound Detection App\n\n'
            'Designed for individuals with hearing impairments and people '
            'in high-noise environments who need real-time audio awareness.',
          ),
          image: _iconBubble(
            Icons.hearing_rounded,
            gradientStart: const Color(0xFF8AB4FF), // light blue
            gradientEnd: const Color(0xFF0B57D0),   // deep blue
          ),
          decoration: _pageDecoration(),
        ),

        // ── 2. Problem Statement ─────────────────────────────────────────
        // Purpose: make the user feel the problem before revealing the solution.
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
            Icons.warning_amber_rounded,
            gradientStart: const Color(0xFFFF6B6B), // coral red
            gradientEnd: const Color(0xFFFF8E53),   // warm orange
          ),
          decoration: _pageDecoration(),
        ),

        // ── 3. Core Solution ─────────────────────────────────────────────
        // Purpose: introduce the product value proposition.
        PageViewModel(
          titleWidget: _title('Sound Made Visible'),
          bodyWidget: _body(
            'SenScribe converts surrounding audio into instant visual and '
            'haptic feedback — no extra hardware required.\n\n'
            'Real-time captions, smart alerts, and sound direction cues '
            'work together to keep you informed and safe.',
          ),
          image: _iconBubble(
            Icons.auto_awesome_rounded,
            gradientStart: const Color(0xFF66BB6A), // green
            gradientEnd: const Color(0xFF00ACC1),   // teal
          ),
          decoration: _pageDecoration(),
        ),

        // ── 4. Key Features ──────────────────────────────────────────────
        // Purpose: quickly enumerate the four main features.
        // Uses _featureList() instead of _body() because it has icons + rows.
        PageViewModel(
          titleWidget: _title('Key Features'),
          bodyWidget: _featureList(),
          image: _iconBubble(
            Icons.dashboard_rounded,
            gradientStart: const Color(0xFFAB47BC), // purple
            gradientEnd: const Color(0xFF7E57C2),   // deep purple
          ),
          decoration: _pageDecoration(),
        ),

        // ── 5. Technical Foundation ──────────────────────────────────────
        // Purpose: build trust — on-device AI, no data leaves the phone.
        // This is also the last slide, so "Next" is replaced by "Get Started".
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
            Icons.shield_rounded,
            gradientStart: const Color(0xFF29B6F6), // light blue
            gradientEnd: const Color(0xFF0288D1),   // medium blue
          ),
          decoration: _pageDecoration(),
        ),
      ];

  // ─────────────────────────── Build ───────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return IntroductionScreen(
      // globalBackgroundColor fills the area behind the slides during transitions.
      // Without this you might see a white flash between pages.
      globalBackgroundColor: _bg,

      // The ordered list of slides produced by _buildPages().
      pages: _buildPages(),

      // ── Navigation buttons ─────────────────────────────────────────────
      // Setting these to true enables the widgets passed below.
      // If showSkipButton is false, the `skip` widget is ignored.
      showSkipButton: true,
      showBackButton: true,
      showNextButton: true,

      // Each button accepts any Widget — we use Text/Icon with matching style.
      skip: Text(
        'Skip',
        style: GoogleFonts.inter(
          color: _primary,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
      ),
      // Back button — shown on slides 2-5, hidden on slide 1
      back: const Icon(Icons.arrow_back_rounded, color: _primary),
      // Next button — a Row so we can put text and an arrow icon side by side
      next: Row(
        mainAxisSize: MainAxisSize.min, // Row takes only as much space as its children
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
      // Done replaces Next on the very last slide
      done: Text(
        'Get Started',
        style: GoogleFonts.inter(
          color: _primary,
          fontWeight: FontWeight.bold, // bold to signal this is the primary action
          fontSize: 14,
        ),
      ),

      // Both callbacks point to the same function so Skip and Get Started
      // have identical behaviour: write the flag and switch to the home screen.
      onDone: onDone,
      onSkip: onDone,

      // ── Dot indicator ──────────────────────────────────────────────────
      dotsDecorator: DotsDecorator(
        size: const Size(8, 8),          // inactive dot: 8×8 circle
        activeSize: const Size(26, 8),   // active dot: 26×8 — wider pill shape
        color: Colors.white24,           // inactive dot colour
        activeColor: _primary,           // active dot colour
        spacing: const EdgeInsets.symmetric(horizontal: 4), // gap between dots
        // activeShape makes the active dot a pill instead of a circle.
        // RoundedRectangleBorder with a large radius on a wide rect = pill.
        activeShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      // ── Layout & animation ─────────────────────────────────────────────
      // Margin outside the controls bar (Skip / dots / Next row)
      controlsMargin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      // Padding inside the controls bar
      controlsPadding: const EdgeInsets.all(12),
      // Easing curve for the slide transition animation
      curve: Curves.easeInOut,
      // Duration of each slide transition in milliseconds
      animationDuration: 350,

      // ── Button semantics (accessibility) ──────────────────────────────
      // These strings are read aloud by screen readers (TalkBack / VoiceOver).
      // Always set these — it costs nothing and makes the app accessible.
      skipSemantic: 'Skip introduction',
      nextSemantic: 'Go to next page',
      doneSemantic: 'Finish and open SenScribe', // update with your app name
      backSemantic: 'Go to previous page',
    );
  }
}
```

---

## 4. First-Launch Gate in `main.dart`

This is the logic that shows the intro only once. The key pieces to add to your root `StatefulWidget`:

```dart
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/introduction_page.dart';
// Import your main home page here — e.g.:
// import 'navigation/main_navigation.dart';

class _YourAppState extends State<YourApp> {
  // We use a nullable bool as a three-state flag:
  //   null  — AsyncStorage read hasn't finished yet (app just opened)
  //   false — Key was not found; this is the user's first launch
  //   true  — Key exists; user has already seen the intro
  // The nullable type is important: it lets us show a loading spinner
  // instead of accidentally flashing the wrong screen while we wait.
  bool? _introCompleted;

  @override
  void initState() {
    super.initState();
    // Kick off the async read immediately when the widget is first inserted.
    // We cannot make initState itself async, so we call a helper.
    _checkIntroCompleted();
  }

  // Reads the 'intro_completed' boolean from disk.
  // SharedPreferences.getInstance() is cheap after the first call — it's cached.
  // The ?? false means: if the key doesn't exist yet, treat it as false (first launch).
  Future<void> _checkIntroCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    final completed = prefs.getBool('intro_completed') ?? false;
    // setState triggers a rebuild. _introCompleted changes from null → false or true,
    // which causes _buildHome() to return the correct screen.
    setState(() {
      _introCompleted = completed;
    });
  }

  // Called by IntroductionPage when the user taps "Get Started" or "Skip".
  // Writes the flag to disk first, then updates state to switch screens.
  // Writing before setState means the flag is safe even if the user force-quits
  // immediately after finishing the intro.
  Future<void> _markIntroCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('intro_completed', true); // persist to disk
    setState(() {
      _introCompleted = true; // triggers rebuild → shows home screen
    });
  }

  // _buildHome is called every time build() runs.
  // It switches between three different widgets based on the flag state.
  Widget _buildHome() {
    // Phase 1 — null: still waiting for the SharedPreferences read.
    // Show a dark spinner so there's no white flash on startup.
    if (_introCompleted == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F1724), // match onboarding bg so there's no jump
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Phase 2 — true: returning user. Go straight to the main app.
    if (_introCompleted == true) {
      return const YourMainHomePage(); // replace with your actual home widget
    }

    // Phase 3 — false: first launch.
    // Pass _markIntroCompleted as the onDone callback so the intro can
    // hand control back here when it finishes.
    return IntroductionPage(onDone: _markIntroCompleted);
  }

  @override
  Widget build(BuildContext context) {
    // home: is evaluated lazily each rebuild, so switching screens is
    // just a matter of changing _introCompleted and calling setState.
    return MaterialApp(
      home: _buildHome(),
    );
  }
}
```

> **To reset the intro during development** (so it shows again), either:
> - Delete the app from the simulator/device, or
> - Add a debug button that calls:
>   ```dart
>   // Removing the key is the same as it never being set.
>   // Next time _checkIntroCompleted runs, getBool returns null → treated as false → intro shows.
>   final prefs = await SharedPreferences.getInstance();
>   await prefs.remove('intro_completed');
>   ```

---

## 5. Customization Reference

### Color Scheme

| Token | Hex | Used For |
|---|---|---|
| `_bg` | `#0F1724` | All slide backgrounds |
| `_primary` | `#8AB4FF` | Buttons, active dot, icon chips |
| `_textPrimary` | `#E7EDF8` | Slide titles |
| `_textSecondary` | `#B0BEC5` | Body text, feature subtitles |

### Icon Bubble Gradients Per Slide

| Slide | Icon | Start | End |
|---|---|---|---|
| 1 — Identity | `Icons.hearing_rounded` | `#8AB4FF` | `#0B57D0` |
| 2 — Problem | `Icons.warning_amber_rounded` | `#FF6B6B` | `#FF8E53` |
| 3 — Solution | `Icons.auto_awesome_rounded` | `#66BB6A` | `#00ACC1` |
| 4 — Features | `Icons.dashboard_rounded` | `#AB47BC` | `#7E57C2` |
| 5 — Trust | `Icons.shield_rounded` | `#29B6F6` | `#0288D1` |

### `PageDecoration` Layout Ratios

```dart
// imageFlex and bodyFlex work like Flex weights — same concept as a Row/Column
// with Expanded children. The total is imageFlex + bodyFlex = 5 parts.
// imageFlex: 2  →  icon gets 2/5 (40%) of the slide height
// bodyFlex:  3  →  title + text get 3/5 (60%) of the slide height
// To give the icon more space (e.g. if using an image instead of an icon):
//   imageFlex: 3, bodyFlex: 2
// To give text more space (e.g. if body text is very long):
//   imageFlex: 1, bodyFlex: 4
imageFlex: 2
bodyFlex:  3
```

Increase `imageFlex` to make the icon bigger on screen; decrease it for more text room.

### Dot Indicator

```dart
// size — width × height of each inactive dot (a perfect circle here)
size:        Size(8, 8)
// activeSize — the active dot is wider than it is tall, creating the pill shape.
// The key is that width > height. The shape itself is controlled by activeShape below.
activeSize:  Size(26, 8)
// color — inactive dot fill; white24 = white at ~14% opacity (barely visible)
color:       Colors.white24
// activeColor — uses the same _primary blue as the buttons for visual consistency
activeColor: _primary
```

The pill effect comes from `activeShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))`.

### Animation

```dart
// curve — the easing applied to the scroll/page-turn animation.
// Curves.easeInOut starts slow, speeds up in the middle, slows at the end.
// Other good options: Curves.easeOutCubic (snappier), Curves.linear (mechanical)
curve: Curves.easeInOut

// animationDuration — how long each slide transition takes in milliseconds.
// 350ms feels natural. Go lower (200ms) for snappy; higher (500ms) for dramatic.
animationDuration: 350
```

---

## 6. Adding / Removing Slides

Each slide is a `PageViewModel`. To add a slide, append one to the list in `_buildPages()`:

```dart
PageViewModel(
  // titleWidget accepts any Widget — _title() gives you the standard bold style.
  // You could also pass a custom widget if you want something fancier (e.g. gradient text).
  titleWidget: _title('Your Slide Title'),

  // bodyWidget accepts any Widget — _body() for plain centered text,
  // or pass a custom Column/Row/etc. for richer layouts (like the feature list on slide 4).
  bodyWidget: _body('Your slide description text here.'),

  // image is shown in the top imageFlex section of the slide.
  // _iconBubble() is the circular gradient style used throughout.
  // You could also pass Image.asset(...) if you want a real image instead.
  image: _iconBubble(
    Icons.your_icon,                         // replace with any Icons.* constant
    gradientStart: const Color(0xFFYOURCOLOR), // top-left gradient colour
    gradientEnd:   const Color(0xFFYOURCOLOR), // bottom-right gradient colour
  ),

  // Always pass _pageDecoration() — it sets the background color, padding,
  // imageFlex/bodyFlex split, and fallback text styles for every slide consistently.
  decoration: _pageDecoration(),
),
```

To remove a slide, just delete its `PageViewModel` entry from the list.

---

## 7. Using a Custom Widget as Body (like the Feature List)

Instead of `_body()`, pass any widget to `bodyWidget`. The feature list pattern:

```dart
PageViewModel(
  titleWidget: _title('Key Features'),
  bodyWidget: _featureList(), // returns a scrollable Column of rows
  image: _iconBubble(...),
  decoration: _pageDecoration(),
),
```

Each row in `_featureList()` is defined as a Dart record: `(IconData, String label, String subtitle)`. Add, remove, or reorder entries freely in the `features` list inside that method.

---

## 8. Accessibility

The following semantic labels are set on all navigation buttons so screen readers announce them correctly:

```dart
skipSemantic: 'Skip introduction',
nextSemantic: 'Go to next page',
doneSemantic: 'Finish and open [your app name]',
backSemantic: 'Go to previous page',
```

Update `doneSemantic` to match your app name.
