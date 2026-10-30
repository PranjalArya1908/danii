import 'package:flutter/material.dart';
import '../theme/colors.dart';

class OnboardingSlide {
  final String title;
  final String description;
  final IconData icon;
  final Color badgeColor;

  const OnboardingSlide({
    required this.title,
    required this.description,
    required this.icon,
    required this.badgeColor,
  });
}

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onFinish;

  const OnboardingScreen({super.key, required this.onFinish});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingSlide> _slides = const [
    OnboardingSlide(
      title: 'Protected Journeys',
      description:
          'Intelligent route guardian monitors your transit from departure to destination with real-time GPS telemetry.',
      icon: Icons.shield,
      badgeColor: SafeLoopColors.primaryViolet,
    ),
    OnboardingSlide(
      title: 'Adaptive Safety Check-Ins',
      description:
          'Effortless gesture-based check-ins that adapt to your speed, late night hours, and transport mode.',
      icon: Icons.touch_app,
      badgeColor: SafeLoopColors.vibrantLavender,
    ),
    OnboardingSlide(
      title: 'Discreet Duress & SOS',
      description:
          'A silent duress PIN that appears routine to an attacker while covertly dispatching your live beacon to trusted contacts.',
      icon: Icons.lock,
      badgeColor: SafeLoopColors.primaryViolet,
    ),
    OnboardingSlide(
      title: 'Trusted Circle Escalation',
      description:
          'Automated escalation alerts your family with live route tracking if a check-in is missed.',
      icon: Icons.people,
      badgeColor: SafeLoopColors.safeGreen,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top Header: Logo & Skip
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: SafeLoopColors.primaryViolet.withValues(alpha: isDark ? 0.2 : 0.12),
                          ),
                          child: const Icon(
                            Icons.shield,
                            color: SafeLoopColors.primaryViolet,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'SafeLoop',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: widget.onFinish,
                      child: Text(
                        'Skip',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Hero Visual Card with PageView
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24.0),
                    child: Container(
                      color: theme.colorScheme.surface,
                      child: Stack(
                        children: [
                          // Hero Image Background
                          Positioned.fill(
                            child: Image.asset(
                              'assets/images/img_safeloop_hero.jpg',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: isDark
                                          ? [const Color(0xFF1E1B4B), const Color(0xFF0F172A)]
                                          : [const Color(0xFFEDE9FE), const Color(0xFFE0E7FF)],
                                    ),
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.shield,
                                      size: 80,
                                      color: SafeLoopColors.primaryViolet,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),

                          // Gradient Overlay
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: isDark
                                      ? [Colors.transparent, SafeLoopColors.midnightDarkBackground.withValues(alpha: 0.95)]
                                      : [Colors.transparent, Colors.white.withValues(alpha: 0.96)],
                                  stops: const [0.3, 0.85],
                                ),
                              ),
                            ),
                          ),

                          // Pager content inside card
                          PageView.builder(
                            controller: _pageController,
                            itemCount: _slides.length,
                            onPageChanged: (page) {
                              setState(() {
                                _currentPage = page;
                              });
                            },
                            itemBuilder: (context, index) {
                              final slide = _slides[index];
                              return Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Container(
                                      width: 54,
                                      height: 54,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: slide.badgeColor.withValues(alpha: 0.2),
                                      ),
                                      child: Icon(
                                        slide.icon,
                                        color: slide.badgeColor,
                                        size: 28,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    Text(
                                      slide.title,
                                      style: theme.textTheme.headlineMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? SafeLoopColors.textPrimary : theme.colorScheme.onSurface,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      slide.description,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: isDark ? SafeLoopColors.textSecondary : theme.colorScheme.onSurfaceVariant,
                                        height: 1.4,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Bottom Section: Dots and Action Button
              Padding(
                padding: const EdgeInsets.only(bottom: 24.0),
                child: Column(
                  children: [
                    // Indicator Dots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_slides.length, (index) {
                        final isSelected = _currentPage == index;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 4.0),
                          height: 6.0,
                          width: isSelected ? 24.0 : 6.0,
                          decoration: BoxDecoration(
                            color: isSelected ? SafeLoopColors.primaryViolet : theme.colorScheme.outline,
                            borderRadius: BorderRadius.circular(3.0),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 16),

                    // Primary Button
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: () {
                          if (_currentPage < _slides.length - 1) {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          } else {
                            widget.onFinish();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: SafeLoopColors.primaryViolet,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _currentPage == _slides.length - 1 ? 'Get Started' : 'Next',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward, size: 18, color: Colors.white),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Every journey deserves a safety net.',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
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
