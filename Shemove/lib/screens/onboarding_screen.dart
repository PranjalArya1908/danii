import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

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
      badgeColor: AppColors.primaryViolet,
    ),
    OnboardingSlide(
      title: 'Adaptive Safety Check-Ins',
      description:
          'Effortless gesture-based check-ins that adapt to your speed, late night hours, and transport mode.',
      icon: Icons.touch_app,
      badgeColor: AppColors.vibrantLavender,
    ),
    OnboardingSlide(
      title: 'Discreet Duress & SOS',
      description:
          'A silent duress PIN that appears routine to an attacker while covertly dispatching your live beacon to trusted contacts.',
      icon: Icons.lock,
      badgeColor: AppColors.primaryViolet,
    ),
    OnboardingSlide(
      title: 'Trusted Circle Escalation',
      description:
          'Automated escalation alerts your family with live route tracking if a check-in is missed.',
      icon: Icons.people,
      badgeColor: AppColors.safeGreen,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNext() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      widget.onFinish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.midnightDarkBackground : AppColors.lightBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              // Top Header: SafeLoop Logo & Skip
              Padding(
                padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.primaryViolet.withValues(alpha: isDark ? 0.2 : 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.shield,
                            color: AppColors.primaryViolet,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'SheMove',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: widget.onFinish,
                      child: Text(
                        'Skip',
                        style: TextStyle(
                          color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Hero Visual Card with Background Image and Gradient Overlay
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Container(
                    width: double.infinity,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.midnightDarkSurface : AppColors.lightSurface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isDark
                            ? AppColors.midnightDarkCardBorder
                            : AppColors.lightCardBorder,
                      ),
                    ),
                    child: Stack(
                      children: [
                        // Background Hero Image
                        Positioned.fill(
                          child: Image.asset(
                            'assets/images/img_safeloop_hero.jpg',
                            fit: BoxFit.cover,
                            alignment: Alignment.topCenter,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      AppColors.primaryViolet.withValues(alpha: 0.35),
                                      isDark
                                          ? AppColors.midnightDarkBackground
                                          : AppColors.lightBackground,
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                        // Vertical Gradient Overlay
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                stops: const [0.0, 0.35, 0.7, 1.0],
                                colors: isDark
                                    ? [
                                        Colors.transparent,
                                        AppColors.midnightDarkBackground.withValues(alpha: 0.4),
                                        AppColors.midnightDarkBackground.withValues(alpha: 0.88),
                                        AppColors.midnightDarkBackground.withValues(alpha: 0.98),
                                      ]
                                    : [
                                        Colors.transparent,
                                        Colors.white.withValues(alpha: 0.4),
                                        Colors.white.withValues(alpha: 0.88),
                                        Colors.white.withValues(alpha: 0.98),
                                      ],
                              ),
                            ),
                          ),
                        ),

                        // Horizontal Pager with slide info inside the card
                        PageView.builder(
                          controller: _pageController,
                          onPageChanged: (idx) {
                            setState(() {
                              _currentPage = idx;
                            });
                          },
                          itemCount: _slides.length,
                          itemBuilder: (context, index) {
                            final slide = _slides[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Container(
                                    width: 54,
                                    height: 54,
                                    decoration: BoxDecoration(
                                      color: slide.badgeColor.withValues(alpha: 0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Icon(
                                        slide.icon,
                                        size: 28,
                                        color: slide.badgeColor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    slide.title,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? AppColors.textPrimary
                                          : AppColors.lightTextPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    slide.description,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14,
                                      height: 1.4,
                                      color: isDark
                                          ? AppColors.textSecondary
                                          : AppColors.lightTextSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
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

              // Bottom Section: Page Indicators & Primary Action Button
              Padding(
                padding: const EdgeInsets.only(bottom: 24.0),
                child: Column(
                  children: [
                    // Page indicator bars
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_slides.length, (index) {
                        final isSelected = _currentPage == index;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 6,
                          width: isSelected ? 24 : 6,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primaryViolet
                                : (isDark
                                    ? AppColors.midnightDarkCardBorder
                                    : AppColors.lightCardBorder),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 16),

                    // Primary Action Button (Next / Get Started)
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton(
                        onPressed: _onNext,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primaryViolet,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _currentPage == _slides.length - 1 ? 'Get Started' : 'Next',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.arrow_forward,
                              size: 18,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Tagline
                    Text(
                      'Every journey deserves a safety net.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
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
