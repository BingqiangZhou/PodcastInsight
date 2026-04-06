import 'package:personal_ai_assistant/features/podcast/data/models/podcast_highlight_model.dart';

/// Represents a matched highlight within a text segment
class MatchedHighlight {

  const MatchedHighlight({
    required this.highlight,
    required this.startIndex,
    required this.endIndex,
    required this.matchScore,
  });
  final HighlightResponse highlight;
  final int startIndex;
  final int endIndex;
  final double matchScore;
}

/// Utility class for matching highlight text to transcript segments
class HighlightMatcher {
  /// Find highlights that match within a given text segment
  ///
  /// Returns a list of [MatchedHighlight] sorted by match score (best first)
  static List<MatchedHighlight> findMatchingHighlights({
    required String text,
    required List<HighlightResponse> highlights,
    double threshold = 0.5,
  }) {
    final matches = <MatchedHighlight>[];
    final normalizedText = _normalize(text);

    for (final highlight in highlights) {
      final normalizedHighlight = _normalize(highlight.originalText);

      // Skip if highlight is too short
      if (normalizedHighlight.length < 10) {
        continue;
      }

      // Try exact match first
      var index = normalizedText.indexOf(normalizedHighlight);
      if (index != -1) {
        matches.add(MatchedHighlight(
          highlight: highlight,
          startIndex: index,
          endIndex: index + normalizedHighlight.length,
          matchScore: 1,
        ));
        continue;
      }

      // Try matching first 50% of highlight (more lenient)
      final partialLength = (normalizedHighlight.length * 0.5).floor();
      if (partialLength >= 10) {
        final partialHighlight = normalizedHighlight.substring(0, partialLength);
        index = normalizedText.indexOf(partialHighlight);
        if (index != -1) {
          matches.add(MatchedHighlight(
            highlight: highlight,
            startIndex: index,
            endIndex: index + normalizedHighlight.length,
            matchScore: 0.8,
          ));
          continue;
        }
      }

      // Try matching last 50% of highlight
      if (partialLength >= 10) {
        final partialHighlight = normalizedHighlight.substring(
          normalizedHighlight.length - partialLength,
        );
        index = normalizedText.indexOf(partialHighlight);
        if (index != -1) {
          matches.add(MatchedHighlight(
            highlight: highlight,
            startIndex: index,
            endIndex: index + normalizedHighlight.length,
            matchScore: 0.7,
          ));
          continue;
        }
      }

      // Try matching middle portion
      if (normalizedHighlight.length >= 30) {
        final start = (normalizedHighlight.length * 0.25).floor();
        final end = (normalizedHighlight.length * 0.75).floor();
        final middlePortion = normalizedHighlight.substring(start, end);
        index = normalizedText.indexOf(middlePortion);
        if (index != -1) {
          matches.add(MatchedHighlight(
            highlight: highlight,
            startIndex: index,
            endIndex: index + normalizedHighlight.length,
            matchScore: 0.6,
          ));
          continue;
        }
      }

      // Try fuzzy match with contextBefore
      final contextBefore = highlight.contextBefore;
      if (contextBefore != null && contextBefore.isNotEmpty) {
        final normalizedContext = _normalize(contextBefore);
        // Check if at least 50% of context matches
        final contextPartialLength = (normalizedContext.length * 0.5).floor();
        if (contextPartialLength >= 5) {
          final partialContext = normalizedContext.substring(0, contextPartialLength);
          index = normalizedText.indexOf(partialContext);
          if (index != -1) {
            matches.add(MatchedHighlight(
              highlight: highlight,
              startIndex: index + contextPartialLength,
              endIndex: index + contextPartialLength + normalizedHighlight.length,
              matchScore: 0.5,
            ));
            continue;
          }
        }
      }
    }

    // Sort by match score (best first), then by overall score
    matches.sort((a, b) {
      final scoreCompare = b.matchScore.compareTo(a.matchScore);
      if (scoreCompare != 0) return scoreCompare;
      return b.highlight.overallScore.compareTo(a.highlight.overallScore);
    });

    return matches;
  }

  /// Check if a text segment contains any highlight text
  static bool containsHighlight({
    required String text,
    required HighlightResponse highlight,
  }) {
    final normalizedText = _normalize(text);
    final normalizedHighlight = _normalize(highlight.originalText);

    // Skip if highlight is too short
    if (normalizedHighlight.length < 10) {
      return false;
    }

    // Exact match
    if (normalizedText.contains(normalizedHighlight)) {
      return true;
    }

    // Check first 50% of highlight (more lenient)
    final partialLength = (normalizedHighlight.length * 0.5).floor();
    if (partialLength >= 10) {
      final partialHighlight = normalizedHighlight.substring(0, partialLength);
      if (normalizedText.contains(partialHighlight)) {
        return true;
      }
    }

    // Check last 50% of highlight
    if (partialLength >= 10) {
      final partialHighlight = normalizedHighlight.substring(
        normalizedHighlight.length - partialLength,
      );
      if (normalizedText.contains(partialHighlight)) {
        return true;
      }
    }

    // Check middle portion for longer highlights
    if (normalizedHighlight.length >= 30) {
      final start = (normalizedHighlight.length * 0.25).floor();
      final end = (normalizedHighlight.length * 0.75).floor();
      final middlePortion = normalizedHighlight.substring(start, end);
      if (normalizedText.contains(middlePortion)) {
        return true;
      }
    }

    // Check with contextBefore
    if (highlight.contextBefore != null &&
        highlight.contextBefore!.isNotEmpty) {
      final normalizedContext = _normalize(highlight.contextBefore!);
      final contextPartialLength = (normalizedContext.length * 0.5).floor();
      if (contextPartialLength >= 5) {
        final partialContext = normalizedContext.substring(0, contextPartialLength);
        if (normalizedText.contains(partialContext)) {
          return true;
        }
      }
    }

    return false;
  }

  /// Find the best matching highlight for a text segment
  static MatchedHighlight? findBestMatch({
    required String text,
    required List<HighlightResponse> highlights,
    double threshold = 0.5,
  }) {
    final matches = findMatchingHighlights(
      text: text,
      highlights: highlights,
      threshold: threshold,
    );
    return matches.isNotEmpty ? matches.first : null;
  }

  /// Normalize text for matching
  ///
  /// Converts to lowercase, collapses whitespace, and removes punctuation
  static String _normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[^\w\s\u4e00-\u9fff]'), '') // Keep Chinese chars
        .trim();
  }
}
