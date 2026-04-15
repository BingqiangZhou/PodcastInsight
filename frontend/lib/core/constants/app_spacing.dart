/// Spacing system for the Personal AI Assistant.
///
/// Follows a 4-point grid scale for consistent, predictable spacing.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4; // tight: icon-text gap, compact elements
  static const double sm = 8; // small: within-group spacing
  static const double smMd = 12; // medium-small: list item internal
  static const double md = 16; // standard: default element gap (most used)
  static const double mdLg = 20; // medium-large: card content padding
  static const double lg = 24; // large: section separators
  static const double xl = 32; // extra-large: major block separators
  static const double xxl = 48; // page-level whitespace
}
