/// Named animation duration constants for consistent timing across the app.
///
/// Use these instead of hardcoded `Duration(milliseconds:)` values to ensure
/// animation timing is consistent and easy to tune globally.
class AppDurations {
  AppDurations._();

  // Entrance / exit animations
  static const Duration entranceFast = Duration(milliseconds: 160);
  static const Duration entranceNormal = Duration(milliseconds: 200);
  static const Duration entranceSlow = Duration(milliseconds: 300);

  // Transition durations
  static const Duration transitionFast = Duration(milliseconds: 180);
  static const Duration transitionNormal = Duration(milliseconds: 280);

  // Stagger delays
  static const Duration staggerQuick = Duration(milliseconds: 50);
  static const Duration staggerNormal = Duration(milliseconds: 100);

  // Scrolling
  static const Duration scrollAnimation = Duration(milliseconds: 300);

  // Loading shimmer / pulse
  static const Duration shimmerPulse = Duration(milliseconds: 800);

  // Fade
  static const Duration fadeFast = Duration(milliseconds: 150);
  static const Duration fadeNormal = Duration(milliseconds: 300);

  // Scale
  static const Duration scaleFast = Duration(milliseconds: 200);

  // Navigation transitions
  static const Duration navigationTransition = Duration(milliseconds: 220);

  // Slide animations
  static const Duration slideNormal = Duration(milliseconds: 260);
}
