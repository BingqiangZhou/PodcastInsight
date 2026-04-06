const List<double> kPlaybackSpeedOptions = <double>[
  0.5,
  0.75,
  1,
  1.25,
  1.5,
  1.75,
  2,
  2.5,
  3,
];

String formatPlaybackSpeed(double speed) {
  final raw = speed.toStringAsFixed(2);
  final normalized = raw
      .replaceAll(RegExp(r'0+$'), '')
      .replaceAll(RegExp(r'\.$'), '');
  return '${normalized}x';
}
