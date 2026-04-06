import 'package:flutter/foundation.dart';

Future<String> extractMarkdownSelectionAsync({
  required String markdown,
  required String selectedText,
}) {
  return compute(_extractMarkdownSelectionOnBackground, <String, String>{
    'markdown': markdown,
    'selected_text': selectedText,
  });
}

String _extractMarkdownSelectionOnBackground(Map<String, String> task) {
  return extractMarkdownSelection(
    markdown: task['markdown'] ?? '',
    selectedText: task['selected_text'] ?? '',
  );
}

String truncateShareContent({
  required String content,
  required int maxChars,
  required String truncatedSuffix,
}) {
  if (content.length <= maxChars) {
    return content;
  }
  return '${content.substring(0, maxChars)}\n\n$truncatedSuffix';
}

String extractMarkdownSelection({
  required String markdown,
  required String selectedText,
}) {
  final source = markdown.trim();
  final selected = selectedText.trim();
  if (source.isEmpty || selected.isEmpty) {
    return selected;
  }

  final lines = source.split('\n');
  final mapping = _buildMarkdownVisibleMapping(lines);
  final directRange = _findBestVisibleRange(
    haystack: mapping.visibleText,
    needle: selected,
    lineByVisibleChar: mapping.lineByVisibleChar,
  );
  if (directRange != null) {
    return _extractMarkdownBlockFromVisibleRange(
      lines: lines,
      mapping: mapping,
      visibleStart: directRange.start,
      visibleLength: directRange.length,
      fallback: selected,
    );
  }

  final collapsedVisible = _collapseWhitespaceWithMapping(mapping.visibleText);
  final collapsedSelected = _collapseWhitespaceWithMapping(selected);
  if (collapsedSelected.collapsedText.isEmpty) {
    return selected;
  }
  final collapsedRange = _findBestCollapsedVisibleRange(
    collapsedVisible: collapsedVisible,
    collapsedNeedle: collapsedSelected.collapsedText,
    lineByVisibleChar: mapping.lineByVisibleChar,
  );
  if (collapsedRange != null) {
    return _extractMarkdownBlockFromVisibleRange(
      lines: lines,
      mapping: mapping,
      visibleStart: collapsedRange.start,
      visibleLength: collapsedRange.length,
      fallback: selected,
    );
  }

  final compactVisible = _compactTextWithMapping(mapping.visibleText);
  final compactSelected = _compactTextWithMapping(selected).compactText;
  if (compactSelected.isNotEmpty) {
    final compactRange = _findBestCompactedVisibleRange(
      compactVisible: compactVisible,
      compactNeedle: compactSelected,
      lineByVisibleChar: mapping.lineByVisibleChar,
    );
    if (compactRange != null) {
      return _extractMarkdownBlockFromVisibleRange(
        lines: lines,
        mapping: mapping,
        visibleStart: compactRange.start,
        visibleLength: compactRange.length,
        fallback: selected,
      );
    }
  }

  final lineWindowRange = _findBestLineWindowMatch(
    lines: lines,
    selectedText: selected,
  );
  if (lineWindowRange == null) {
    return selected;
  }
  final expanded = _expandMarkdownLineRange(
    lines: lines,
    startLine: lineWindowRange.$1,
    endLine: lineWindowRange.$2,
  );
  final snippet = lines.sublist(expanded.$1, expanded.$2 + 1).join('\n').trim();
  return snippet.isNotEmpty ? snippet : selected;
}

_VisibleRange? _findBestVisibleRange({
  required String haystack,
  required String needle,
  required List<int> lineByVisibleChar,
}) {
  if (haystack.isEmpty || needle.isEmpty || needle.length > haystack.length) {
    return null;
  }

  _VisibleRange? best;
  var searchFrom = 0;
  while (searchFrom <= haystack.length - needle.length) {
    final matchStart = haystack.indexOf(needle, searchFrom);
    if (matchStart < 0) {
      break;
    }

    final candidate = _VisibleRange(start: matchStart, length: needle.length);
    if (_isBetterVisibleRange(
      candidate: candidate,
      current: best,
      lineByVisibleChar: lineByVisibleChar,
    )) {
      best = candidate;
    }

    searchFrom = matchStart + 1;
  }

  return best;
}

_VisibleRange? _findBestCompactedVisibleRange({
  required _CompactedTextMapping compactVisible,
  required String compactNeedle,
  required List<int> lineByVisibleChar,
}) {
  final compactHaystack = compactVisible.compactText;
  if (compactHaystack.isEmpty ||
      compactNeedle.isEmpty ||
      compactNeedle.length > compactHaystack.length) {
    return null;
  }

  _VisibleRange? best;
  var searchFrom = 0;
  while (searchFrom <= compactHaystack.length - compactNeedle.length) {
    final compactStart = compactHaystack.indexOf(compactNeedle, searchFrom);
    if (compactStart < 0) {
      break;
    }

    final visibleStart = compactVisible.originalIndices[compactStart];
    final visibleEnd =
        compactVisible.originalIndices[compactStart + compactNeedle.length - 1];
    final candidate = _VisibleRange(
      start: visibleStart,
      length: visibleEnd - visibleStart + 1,
    );

    if (_isBetterVisibleRange(
      candidate: candidate,
      current: best,
      lineByVisibleChar: lineByVisibleChar,
    )) {
      best = candidate;
    }

    searchFrom = compactStart + 1;
  }

  return best;
}

_VisibleRange? _findBestCollapsedVisibleRange({
  required _CollapsedTextMapping collapsedVisible,
  required String collapsedNeedle,
  required List<int> lineByVisibleChar,
}) {
  final collapsedHaystack = collapsedVisible.collapsedText;
  if (collapsedHaystack.isEmpty ||
      collapsedNeedle.isEmpty ||
      collapsedNeedle.length > collapsedHaystack.length) {
    return null;
  }

  _VisibleRange? best;
  var searchFrom = 0;
  while (searchFrom <= collapsedHaystack.length - collapsedNeedle.length) {
    final collapsedStart = collapsedHaystack.indexOf(
      collapsedNeedle,
      searchFrom,
    );
    if (collapsedStart < 0) {
      break;
    }

    final visibleStart = collapsedVisible.originalIndices[collapsedStart];
    final visibleEnd = collapsedVisible
        .originalIndices[collapsedStart + collapsedNeedle.length - 1];
    final candidate = _VisibleRange(
      start: visibleStart,
      length: visibleEnd - visibleStart + 1,
    );

    if (_isBetterVisibleRange(
      candidate: candidate,
      current: best,
      lineByVisibleChar: lineByVisibleChar,
    )) {
      best = candidate;
    }

    searchFrom = collapsedStart + 1;
  }

  return best;
}

bool _isBetterVisibleRange({
  required _VisibleRange candidate,
  required _VisibleRange? current,
  required List<int> lineByVisibleChar,
}) {
  if (candidate.start < 0 ||
      candidate.length <= 0 ||
      candidate.start + candidate.length > lineByVisibleChar.length) {
    return false;
  }
  if (current == null) {
    return true;
  }

  final candidateLineSpan = _lineSpanForVisibleRange(
    candidate,
    lineByVisibleChar,
  );
  final currentLineSpan = _lineSpanForVisibleRange(current, lineByVisibleChar);
  if (candidateLineSpan != currentLineSpan) {
    return candidateLineSpan < currentLineSpan;
  }
  if (candidate.length != current.length) {
    return candidate.length < current.length;
  }
  return candidate.start < current.start;
}

int _lineSpanForVisibleRange(_VisibleRange range, List<int> lineByVisibleChar) {
  final startLine = lineByVisibleChar[range.start];
  final endLine = lineByVisibleChar[range.start + range.length - 1];
  return endLine - startLine;
}

(int, int)? _findBestLineWindowMatch({
  required List<String> lines,
  required String selectedText,
}) {
  if (lines.isEmpty || selectedText.isEmpty) {
    return null;
  }

  final visibleLines = lines.map(_lineToVisibleText).toList(growable: false);
  final collapsedSelected = _collapseWhitespaceWithMapping(
    selectedText,
  ).collapsedText;
  final compactSelected = _compactTextWithMapping(selectedText).compactText;
  if (collapsedSelected.isEmpty) {
    return null;
  }

  (int, int)? best;
  for (var start = 0; start < visibleLines.length; start++) {
    final buffer = StringBuffer();
    for (var end = start; end < visibleLines.length; end++) {
      if (end > start) {
        buffer.write('\n');
      }
      buffer.write(visibleLines[end]);

      final visibleWindow = buffer.toString();
      final directMatch = visibleWindow.contains(selectedText);
      final collapsedWindow = _collapseWhitespaceWithMapping(
        visibleWindow,
      ).collapsedText;
      final compactWindow = _compactTextWithMapping(visibleWindow).compactText;
      final collapsedMatch = collapsedWindow.contains(collapsedSelected);
      final compactMatch =
          compactSelected.isNotEmpty && compactWindow.contains(compactSelected);
      if (!directMatch && !collapsedMatch && !compactMatch) {
        continue;
      }

      final candidate = (start, end);
      if (_isBetterLineRange(candidate: candidate, current: best)) {
        best = candidate;
      }
      break;
    }
  }
  return best;
}

bool _isBetterLineRange({
  required (int, int) candidate,
  required (int, int)? current,
}) {
  if (current == null) {
    return true;
  }
  final candidateSpan = candidate.$2 - candidate.$1;
  final currentSpan = current.$2 - current.$1;
  if (candidateSpan != currentSpan) {
    return candidateSpan < currentSpan;
  }
  return candidate.$1 < current.$1;
}

String _extractMarkdownBlockFromVisibleRange({
  required List<String> lines,
  required _MarkdownVisibleMapping mapping,
  required int visibleStart,
  required int visibleLength,
  required String fallback,
}) {
  if (visibleStart < 0 ||
      visibleLength <= 0 ||
      visibleStart + visibleLength > mapping.visibleText.length) {
    return fallback;
  }

  final startLine = mapping.lineByVisibleChar[visibleStart];
  final endLine = mapping.lineByVisibleChar[visibleStart + visibleLength - 1];
  if (startLine < 0 ||
      endLine < startLine ||
      startLine >= lines.length ||
      endLine >= lines.length) {
    return fallback;
  }

  final expanded = _expandMarkdownLineRange(
    lines: lines,
    startLine: startLine,
    endLine: endLine,
  );
  final snippet = lines.sublist(expanded.$1, expanded.$2 + 1).join('\n').trim();
  return snippet.isNotEmpty ? snippet : fallback;
}

_MarkdownVisibleMapping _buildMarkdownVisibleMapping(List<String> lines) {
  final visibleLines = <String>[];
  var inFence = false;

  for (final line in lines) {
    if (_isFenceLine(line)) {
      inFence = !inFence;
      visibleLines.add('');
      continue;
    }
    if (inFence) {
      visibleLines.add(line);
      continue;
    }
    visibleLines.add(_lineToVisibleText(line));
  }

  final visibleBuffer = StringBuffer();
  final lineByVisibleChar = <int>[];

  for (var i = 0; i < visibleLines.length; i++) {
    final visibleLine = visibleLines[i];
    for (var j = 0; j < visibleLine.length; j++) {
      visibleBuffer.write(visibleLine[j]);
      lineByVisibleChar.add(i);
    }
    if (i < visibleLines.length - 1) {
      visibleBuffer.write('\n');
      lineByVisibleChar.add(i);
    }
  }

  return _MarkdownVisibleMapping(
    visibleText: visibleBuffer.toString(),
    lineByVisibleChar: lineByVisibleChar,
  );
}

String _lineToVisibleText(String line) {
  var text = line;

  // Leading block markers
  text = text.replaceFirst(RegExp(r'^\s{0,3}#{1,6}\s+'), '');
  text = text.replaceFirst(RegExp(r'^\s*(>\s*)+'), '');
  text = text.replaceFirst(RegExp(r'^\s*[-+*]\s+'), '\u2022 ');
  text = text.replaceFirst(RegExp(r'^\s*\[(?: |x|X)\]\s+'), '\u2022 ');

  // Inline markdown markers
  text = text.replaceAllMapped(
    RegExp(r'!\[([^\]]*)\]\([^)]+\)'),
    (match) => match.group(1) ?? '',
  );
  text = text.replaceAllMapped(
    RegExp(r'\[([^\]]+)\]\([^)]+\)'),
    (match) => match.group(1) ?? '',
  );
  text = text.replaceAllMapped(
    RegExp('`([^`]+)`'),
    (match) => match.group(1) ?? '',
  );
  text = text.replaceAll('**', '');
  text = text.replaceAll('__', '');
  text = text.replaceAll('*', '');
  text = text.replaceAll('_', '');
  text = text.replaceAll('~~', '');

  return text;
}

(int, int) _expandMarkdownLineRange({
  required List<String> lines,
  required int startLine,
  required int endLine,
}) {
  var start = startLine;
  var end = endLine;

  // Expand to include full fenced code block when selection intersects it.
  for (final fence in _collectFenceRanges(lines)) {
    final intersects = !(end < fence.$1 || start > fence.$2);
    if (intersects) {
      if (fence.$1 < start) {
        start = fence.$1;
      }
      if (fence.$2 > end) {
        end = fence.$2;
      }
    }
  }

  // Keep contiguous list block structure.
  if (_rangeContainsLineType(lines, start, end, _isListLine)) {
    while (start > 0 && _isListLine(lines[start - 1])) {
      start--;
    }
    while (end + 1 < lines.length && _isListLine(lines[end + 1])) {
      end++;
    }
  }

  // Keep contiguous quote block structure.
  if (_rangeContainsLineType(lines, start, end, _isQuoteLine)) {
    while (start > 0 && _isQuoteLine(lines[start - 1])) {
      start--;
    }
    while (end + 1 < lines.length && _isQuoteLine(lines[end + 1])) {
      end++;
    }
  }

  // Keep contiguous paragraph lines together so markdown context is preserved.
  if (_rangeContainsLineType(lines, start, end, _isParagraphLine)) {
    while (start > 0 && _isParagraphLine(lines[start - 1])) {
      start--;
    }
    while (end + 1 < lines.length && _isParagraphLine(lines[end + 1])) {
      end++;
    }
  }

  return (start, end);
}

bool _rangeContainsLineType(
  List<String> lines,
  int start,
  int end,
  bool Function(String line) matcher,
) {
  for (var i = start; i <= end; i++) {
    if (matcher(lines[i])) {
      return true;
    }
  }
  return false;
}

List<(int, int)> _collectFenceRanges(List<String> lines) {
  final ranges = <(int, int)>[];
  int? currentStart;

  for (var i = 0; i < lines.length; i++) {
    if (!_isFenceLine(lines[i])) {
      continue;
    }
    if (currentStart == null) {
      currentStart = i;
    } else {
      ranges.add((currentStart, i));
      currentStart = null;
    }
  }

  if (currentStart != null) {
    ranges.add((currentStart, lines.length - 1));
  }
  return ranges;
}

bool _isFenceLine(String line) => RegExp(r'^\s*(```|~~~)').hasMatch(line);

bool _isHeadingLine(String line) => RegExp(r'^\s{0,3}#{1,6}\s+').hasMatch(line);

bool _isListLine(String line) {
  final trimmed = line.trimLeft();
  return RegExp(r'^([-+*]|\d+\.)\s+').hasMatch(trimmed);
}

bool _isQuoteLine(String line) => RegExp(r'^\s*>\s?').hasMatch(line);

bool _isThematicBreakLine(String line) =>
    RegExp(r'^\s{0,3}([-*_])(?:\s*\1){2,}\s*$').hasMatch(line);

bool _isParagraphLine(String line) {
  final trimmed = line.trim();
  if (trimmed.isEmpty) {
    return false;
  }
  if (_isFenceLine(line) ||
      _isHeadingLine(line) ||
      _isListLine(line) ||
      _isQuoteLine(line) ||
      _isThematicBreakLine(line)) {
    return false;
  }
  return true;
}

_CollapsedTextMapping _collapseWhitespaceWithMapping(String input) {
  final buffer = StringBuffer();
  final originalIndices = <int>[];
  var pendingWhitespace = false;

  for (var i = 0; i < input.length; i++) {
    final char = input[i];
    if (char.trim().isEmpty) {
      pendingWhitespace = true;
      continue;
    }

    if (pendingWhitespace && buffer.isNotEmpty) {
      buffer.write(' ');
      originalIndices.add(i);
    }
    buffer.write(char);
    originalIndices.add(i);
    pendingWhitespace = false;
  }

  return _CollapsedTextMapping(
    collapsedText: buffer.toString(),
    originalIndices: originalIndices,
  );
}

_CompactedTextMapping _compactTextWithMapping(String input) {
  final buffer = StringBuffer();
  final originalIndices = <int>[];

  for (var i = 0; i < input.length; i++) {
    final char = input[i];
    if (char.trim().isEmpty) {
      continue;
    }
    buffer.write(char);
    originalIndices.add(i);
  }

  return _CompactedTextMapping(
    compactText: buffer.toString(),
    originalIndices: originalIndices,
  );
}

class _MarkdownVisibleMapping {

  const _MarkdownVisibleMapping({
    required this.visibleText,
    required this.lineByVisibleChar,
  });
  final String visibleText;
  final List<int> lineByVisibleChar;
}

class _CollapsedTextMapping {

  const _CollapsedTextMapping({
    required this.collapsedText,
    required this.originalIndices,
  });
  final String collapsedText;
  final List<int> originalIndices;
}

class _CompactedTextMapping {

  const _CompactedTextMapping({
    required this.compactText,
    required this.originalIndices,
  });
  final String compactText;
  final List<int> originalIndices;
}

class _VisibleRange {

  const _VisibleRange({required this.start, required this.length});
  final int start;
  final int length;
}
