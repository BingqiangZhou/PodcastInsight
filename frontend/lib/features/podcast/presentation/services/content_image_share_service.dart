import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_selector/file_selector.dart' as file_selector;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/core/utils/app_logger.dart' as logger;
import 'package:personal_ai_assistant/core/widgets/top_floating_notice.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_conversation_model.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/services/content_image_share_text_selection.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

export 'content_image_share_text_selection.dart'
    show
        extractMarkdownSelection,
        extractMarkdownSelectionAsync,
        truncateShareContent;

const int kDefaultShareMaxChars = 10000;
const String kShareImagePrimaryFontFamily = 'SF Pro Text';
const List<String> kShareImageFontFallback = <String>[
  'PingFang SC',
  'Hiragino Sans GB',
  'Noto Sans CJK SC',
  'Microsoft YaHei',
  'Segoe UI',
  'Helvetica Neue',
  'Arial',
];
const String kShareImageCodeFontFamily = 'SFMono-Regular';
const List<String> kShareImageCodeFontFallback = <String>[
  'Menlo',
  'Consolas',
  'Monaco',
  'monospace',
];
const double kShareCardDesktopWidth = 900;
const double kShareCardMobileHorizontalMargin = 32;
const double kShareCardMobileMinWidth = 320;
const double kShareCardMobileMaxWidth = 430;
const double kShareCardMobileFallbackWidth = 390;
const double kShareImageMinPixelRatio = 1;
const double kShareImageMobilePixelBudget = 8000000;
const double kShareImageDesktopPixelBudget = 12000000;
const double kShareImageEstimatedBaseHeight = 220;
const double kShareImageEstimatedLineHeight = 26;

enum ShareContentType { summary, transcript, chat }

enum ShareImageRenderMode { plainText, markdown, conversation }

enum ShareImageExportBehavior { share, save, unsupported }

class ShareConversationItem {

  const ShareConversationItem({
    required this.roleLabel,
    required this.content,
    required this.isUser,
  });
  final String roleLabel;
  final String content;
  final bool isUser;

  ShareConversationItem copyWith({
    String? roleLabel,
    String? content,
    bool? isUser,
  }) {
    return ShareConversationItem(
      roleLabel: roleLabel ?? this.roleLabel,
      content: content ?? this.content,
      isUser: isUser ?? this.isUser,
    );
  }
}

class ShareImagePayload {

  const ShareImagePayload({
    required this.episodeTitle,
    required this.contentType,
    required this.content,
    this.sourceLabel,
    this.maxChars = kDefaultShareMaxChars,
    this.renderMode = ShareImageRenderMode.plainText,
    this.conversationItems = const <ShareConversationItem>[],
  });
  final String episodeTitle;
  final ShareContentType contentType;
  final String content;
  final String? sourceLabel;
  final int maxChars;
  final ShareImageRenderMode renderMode;
  final List<ShareConversationItem> conversationItems;
}

class ContentImageShareException implements Exception {

  const ContentImageShareException(this.message);
  final String message;

  @override
  String toString() => message;
}

TextStyle _shareTextStyle(
  TextStyle? base, {
  Color? color,
  double? height,
  FontWeight? fontWeight,
  FontStyle? fontStyle,
  TextDecoration? decoration,
  String? fontFamily,
  List<String>? fontFamilyFallback,
}) {
  final resolved = base ?? const TextStyle();
  return resolved.copyWith(
    color: color,
    height: height,
    fontWeight: fontWeight,
    fontStyle: fontStyle,
    decoration: decoration,
    fontFamily: fontFamily ?? kShareImagePrimaryFontFamily,
    fontFamilyFallback: fontFamilyFallback ?? kShareImageFontFallback,
  );
}

List<ShareConversationItem> truncateConversationItemsForShare({
  required List<ShareConversationItem> items,
  required int maxChars,
  required String truncatedSuffix,
}) {
  final normalizedItems = items
      .map(
        (item) => item.copyWith(
          roleLabel: item.roleLabel.trim(),
          content: item.content.trim(),
        ),
      )
      .where((item) => item.content.isNotEmpty)
      .toList();

  if (normalizedItems.isEmpty) {
    return const <ShareConversationItem>[];
  }

  var remaining = maxChars;
  final result = <ShareConversationItem>[];

  for (final item in normalizedItems) {
    if (remaining <= 0) {
      break;
    }

    if (item.content.length <= remaining) {
      result.add(item);
      remaining -= item.content.length;
      continue;
    }

    final truncated = item.content.substring(0, remaining);
    result.add(item.copyWith(content: '$truncated\n\n$truncatedSuffix'));
    remaining = 0;
    break;
  }

  return result;
}

String formatShareConversationItems(List<ShareConversationItem> items) {
  final blocks = <String>[];
  for (final item in items) {
    final trimmed = item.content.trim();
    if (trimmed.isEmpty) {
      continue;
    }
    blocks.add('[${item.roleLabel}]\n$trimmed');
  }
  return blocks.join('\n\n');
}

String formatChatMessagesForShare({
  required List<PodcastConversationMessage> messages,
  required String userLabel,
  required String assistantLabel,
}) {
  final blocks = <String>[];
  for (final message in messages) {
    final trimmed = message.content.trim();
    if (trimmed.isEmpty) {
      continue;
    }
    final roleLabel = message.isUser ? userLabel : assistantLabel;
    blocks.add('[$roleLabel]\n$trimmed');
  }
  return blocks.join('\n\n');
}

@visibleForTesting
double resolveShareCardWidth({
  required TargetPlatform platform,
  required double screenWidth,
}) {
  switch (platform) {
    case TargetPlatform.android:
    case TargetPlatform.iOS:
      if (screenWidth <= 0) {
        return kShareCardMobileFallbackWidth;
      }
      final candidate = screenWidth - kShareCardMobileHorizontalMargin;
      return candidate
          .clamp(kShareCardMobileMinWidth, kShareCardMobileMaxWidth)
          ;
    case TargetPlatform.windows:
    case TargetPlatform.macOS:
    case TargetPlatform.linux:
    case TargetPlatform.fuchsia:
      return kShareCardDesktopWidth;
  }
}

@visibleForTesting
double estimateShareImageHeight({
  required ShareImageRenderMode renderMode,
  required int contentLength,
  required int conversationItemCount,
  required double cardWidth,
}) {
  final normalizedLength = contentLength < 0 ? 0 : contentLength;
  final charsPerLine = (cardWidth / 13).clamp(24, 70).toDouble();
  var estimatedLines = (normalizedLength / charsPerLine).ceil();
  if (estimatedLines < 8) {
    estimatedLines = 8;
  }

  var bodyHeight = estimatedLines * kShareImageEstimatedLineHeight;
  switch (renderMode) {
    case ShareImageRenderMode.markdown:
      bodyHeight *= 1.12;
    case ShareImageRenderMode.conversation:
      bodyHeight += conversationItemCount * 36;
    case ShareImageRenderMode.plainText:
      break;
  }

  return (kShareImageEstimatedBaseHeight + bodyHeight)
      .clamp(kShareImageEstimatedBaseHeight, 20000)
      .toDouble();
}

@visibleForTesting
double applyShareImagePixelBudgetGuard({
  required double pixelRatio,
  required double estimatedWidth,
  required double estimatedHeight,
  required double pixelBudget,
}) {
  if (pixelRatio <= kShareImageMinPixelRatio) {
    return kShareImageMinPixelRatio;
  }
  if (estimatedWidth <= 0 || estimatedHeight <= 0 || pixelBudget <= 0) {
    return pixelRatio;
  }

  final estimatedPixels =
      estimatedWidth * estimatedHeight * pixelRatio * pixelRatio;
  if (estimatedPixels <= pixelBudget) {
    return pixelRatio;
  }

  final guardedRatio = math.sqrt(
    pixelBudget / (estimatedWidth * estimatedHeight),
  );
  return guardedRatio.clamp(kShareImageMinPixelRatio, pixelRatio);
}

@visibleForTesting
double resolveShareImagePixelRatio({
  required TargetPlatform platform,
  required ShareImageRenderMode renderMode,
  required int contentLength,
  required int conversationItemCount,
  required double cardWidth,
}) {
  final isMobile =
      platform == TargetPlatform.android || platform == TargetPlatform.iOS;
  final normalizedLength = contentLength < 0 ? 0 : contentLength;

  double pixelRatio;
  if (normalizedLength <= 1200) {
    pixelRatio = isMobile ? 1.6 : 1.35;
  } else if (normalizedLength <= 2500) {
    pixelRatio = isMobile ? 1.45 : 1.25;
  } else if (normalizedLength <= 4500) {
    pixelRatio = isMobile ? 1.3 : 1.15;
  } else if (normalizedLength <= 7000) {
    pixelRatio = isMobile ? 1.15 : 1.05;
  } else {
    pixelRatio = 1.0;
  }

  switch (renderMode) {
    case ShareImageRenderMode.markdown:
      pixelRatio += isMobile ? 0.05 : 0.03;
    case ShareImageRenderMode.conversation:
      pixelRatio -= isMobile ? 0.05 : 0.03;
    case ShareImageRenderMode.plainText:
      break;
  }
  pixelRatio = pixelRatio.clamp(kShareImageMinPixelRatio, 1.6);

  final estimatedHeight = estimateShareImageHeight(
    renderMode: renderMode,
    contentLength: normalizedLength,
    conversationItemCount: conversationItemCount,
    cardWidth: cardWidth,
  );
  final pixelBudget = isMobile
      ? kShareImageMobilePixelBudget
      : kShareImageDesktopPixelBudget;
  return applyShareImagePixelBudgetGuard(
    pixelRatio: pixelRatio,
    estimatedWidth: cardWidth,
    estimatedHeight: estimatedHeight,
    pixelBudget: pixelBudget,
  );
}

@visibleForTesting
ShareImageExportBehavior resolveImageExportBehavior(TargetPlatform platform) {
  switch (platform) {
    case TargetPlatform.android:
    case TargetPlatform.iOS:
      return ShareImageExportBehavior.share;
    case TargetPlatform.windows:
    case TargetPlatform.macOS:
    case TargetPlatform.linux:
      return ShareImageExportBehavior.save;
    case TargetPlatform.fuchsia:
      return ShareImageExportBehavior.unsupported;
  }
}

class ContentImageShareService {
  static final ScreenshotController _screenshotController =
      ScreenshotController();
  static bool _isShareInProgress = false;

  @visibleForTesting
  static bool get isShareInProgress => _isShareInProgress;

  @visibleForTesting
  static void setShareInProgressForTest(bool value) {
    _isShareInProgress = value;
  }

  static Future<void> shareAsImage(
    BuildContext context,
    ShareImagePayload payload,
  ) async {
    final l10n = context.l10n;
    final normalizedText = payload.content.trim();
    final normalizedConversation = payload.conversationItems
        .map(
          (item) => item.copyWith(
            roleLabel: item.roleLabel.trim(),
            content: item.content.trim(),
          ),
        )
        .where((item) => item.content.isNotEmpty)
        .toList();

    if (payload.renderMode == ShareImageRenderMode.conversation) {
      if (normalizedConversation.isEmpty) {
        throw ContentImageShareException(l10n.podcast_share_selection_required);
      }
    } else if (normalizedText.isEmpty) {
      throw ContentImageShareException(l10n.podcast_share_selection_required);
    }

    if (kIsWeb) {
      throw ContentImageShareException(l10n.podcast_share_not_supported);
    }
    final exportBehavior = resolveImageExportBehavior(defaultTargetPlatform);
    if (exportBehavior == ShareImageExportBehavior.unsupported) {
      throw ContentImageShareException(l10n.podcast_share_not_supported);
    }
    if (_isShareInProgress) {
      throw ContentImageShareException(l10n.podcast_share_in_progress);
    }
    _isShareInProgress = true;

    final typeLabel = _resolveTypeLabel(context, payload.contentType);
    final rawSourceLabel = payload.sourceLabel;
    final sourceLabel = rawSourceLabel != null && rawSourceLabel.trim().isNotEmpty
        ? rawSourceLabel.trim()
        : typeLabel;
    final truncatedSuffix = l10n.podcast_share_truncated(payload.maxChars);

    late final String truncatedText;
    late final List<ShareConversationItem> truncatedConversation;

    switch (payload.renderMode) {
      case ShareImageRenderMode.conversation:
        truncatedConversation = truncateConversationItemsForShare(
          items: normalizedConversation,
          maxChars: payload.maxChars,
          truncatedSuffix: truncatedSuffix,
        );
        truncatedText = formatShareConversationItems(truncatedConversation);
      case ShareImageRenderMode.plainText:
      case ShareImageRenderMode.markdown:
        truncatedText = truncateShareContent(
          content: normalizedText,
          maxChars: payload.maxChars,
          truncatedSuffix: truncatedSuffix,
        );
        truncatedConversation = const <ShareConversationItem>[];
    }

    OverlayEntry? preparingOverlayEntry;
    try {
      preparingOverlayEntry = _showPreparingOverlay(
        context,
        message: l10n.podcast_share_preparing_image,
      );
      await Future<void>.delayed(const Duration(milliseconds: 16));
      if (!context.mounted) {
        return;
      }

      final shareOrigin = _resolveShareOrigin(context);
      final fileName = _buildFileName(payload.contentType);
      final cardWidth = resolveShareCardWidth(
        platform: defaultTargetPlatform,
        screenWidth: MediaQuery.sizeOf(context).width,
      );
      final contentLength = _calculateShareContentLength(
        renderMode: payload.renderMode,
        text: truncatedText,
        conversationItems: truncatedConversation,
      );
      final pixelRatio = resolveShareImagePixelRatio(
        platform: defaultTargetPlatform,
        renderMode: payload.renderMode,
        contentLength: contentLength,
        conversationItemCount: truncatedConversation.length,
        cardWidth: cardWidth,
      );

      final bytes = await _screenshotController.captureFromLongWidget(
        _buildShareCard(
          context,
          cardWidth: cardWidth,
          title: payload.episodeTitle.trim().isNotEmpty
              ? payload.episodeTitle.trim()
              : sourceLabel,
          subtitle: sourceLabel,
          body: _buildShareBody(
            context,
            renderMode: payload.renderMode,
            content: truncatedText,
            conversationItems: truncatedConversation,
          ),
        ),
        context: context,
        pixelRatio: pixelRatio,
        delay: const Duration(milliseconds: 60),
      );
      if (!context.mounted) {
        return;
      }

      switch (exportBehavior) {
        case ShareImageExportBehavior.share:
          final tempFile = await _writeTemporaryShareImage(
            bytes: bytes,
            fileName: fileName,
          );
          try {
            await SharePlus.instance.share(
              ShareParams(
                title: payload.episodeTitle,
                subject: payload.episodeTitle,
                text: sourceLabel,
                sharePositionOrigin: shareOrigin,
                files: <XFile>[
                  XFile(tempFile.path, mimeType: 'image/png', name: fileName),
                ],
                fileNameOverrides: <String>[fileName],
              ),
            );
          } finally {
            unawaited(_deleteTemporaryShareImage(tempFile));
          }
          return;
        case ShareImageExportBehavior.save:
          await _saveImage(context, bytes: bytes, fileName: fileName);
          return;
        case ShareImageExportBehavior.unsupported:
          throw ContentImageShareException(l10n.podcast_share_not_supported);
      }
    } on ContentImageShareException {
      rethrow;
    } catch (error, stackTrace) {
      logger.AppLogger.error(
        'ContentImageShareService.shareAsImage failed',
        error: error,
        stackTrace: stackTrace,
      );
      throw ContentImageShareException(l10n.podcast_share_failed);
    } finally {
      preparingOverlayEntry?.remove();
      _isShareInProgress = false;
    }
  }

  static int _calculateShareContentLength({
    required ShareImageRenderMode renderMode,
    required String text,
    required List<ShareConversationItem> conversationItems,
  }) {
    switch (renderMode) {
      case ShareImageRenderMode.conversation:
        var total = 0;
        for (final item in conversationItems) {
          total += item.roleLabel.length;
          total += item.content.length;
        }
        return total;
      case ShareImageRenderMode.plainText:
      case ShareImageRenderMode.markdown:
        return text.length;
    }
  }

  static OverlayEntry? _showPreparingOverlay(
    BuildContext context, {
    required String message,
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      return null;
    }

    final entry = OverlayEntry(
      builder: (_) {
        return Stack(
          children: [
            const ModalBarrier(dismissible: false, color: Color(0x4D000000)),
            Center(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        message,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
    overlay.insert(entry);
    return entry;
  }

  static Future<File> _writeTemporaryShareImage({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final safeName = fileName.replaceAll(RegExp('[^A-Za-z0-9._-]'), '_');
    final tempFile = File(
      '${Directory.systemTemp.path}/'
      '${DateTime.now().microsecondsSinceEpoch}_$safeName',
    );
    await tempFile.writeAsBytes(bytes, flush: true);
    return tempFile;
  }

  static Future<void> _deleteTemporaryShareImage(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (error) {
      logger.AppLogger.warning(
        'ContentImageShareService temporary image cleanup failed: $error',
      );
    }
  }

  static Widget _buildShareBody(
    BuildContext context, {
    required ShareImageRenderMode renderMode,
    required String content,
    required List<ShareConversationItem> conversationItems,
  }) {
    final theme = Theme.of(context);

    switch (renderMode) {
      case ShareImageRenderMode.plainText:
        return Text(
          content,
          style: _shareTextStyle(
            theme.textTheme.bodyLarge,
            height: 1.6,
            color: Colors.black,
          ),
        );
      case ShareImageRenderMode.markdown:
        return MarkdownBody(
          data: content,
          styleSheet: MarkdownStyleSheet(
            p: _shareTextStyle(
              theme.textTheme.bodyLarge,
              height: 1.6,
              color: Colors.black,
            ),
            h1: _shareTextStyle(
              theme.textTheme.headlineSmall,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
            h2: _shareTextStyle(
              theme.textTheme.titleLarge,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
            h3: _shareTextStyle(
              theme.textTheme.titleMedium,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
            h4: _shareTextStyle(
              theme.textTheme.titleSmall,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
            h5: _shareTextStyle(
              theme.textTheme.titleSmall,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
            h6: _shareTextStyle(
              theme.textTheme.titleSmall,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
            listBullet: _shareTextStyle(
              theme.textTheme.bodyLarge,
              color: Colors.black,
            ),
            strong: _shareTextStyle(
              theme.textTheme.bodyLarge,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
            em: _shareTextStyle(
              theme.textTheme.bodyLarge,
              color: Colors.black,
              fontStyle: FontStyle.italic,
            ),
            code: _shareTextStyle(
              theme.textTheme.bodyMedium,
              color: Colors.black,
              fontFamily: kShareImageCodeFontFamily,
              fontFamilyFallback: kShareImageCodeFontFallback,
            ),
            blockquote: _shareTextStyle(
              theme.textTheme.bodyMedium,
              color: Colors.black,
              fontStyle: FontStyle.italic,
            ),
            a: _shareTextStyle(
              theme.textTheme.bodyMedium,
              color: Colors.black,
              decoration: TextDecoration.underline,
            ),
          ),
        );
      case ShareImageRenderMode.conversation:
        return Column(
          children: conversationItems
              .map((item) => _buildConversationBubble(context, item))
              .toList(),
        );
    }
  }

  static Widget _buildConversationBubble(
    BuildContext context,
    ShareConversationItem item,
  ) {
    final theme = Theme.of(context);
    const bubbleColor = Colors.white;
    const textColor = Colors.black;
    final borderColor = item.isUser ? Colors.black54 : Colors.black38;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Align(
        alignment: item.isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.roleLabel,
                  style: _shareTextStyle(
                    theme.textTheme.labelSmall,
                    color: Colors.black,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.content,
                  style: _shareTextStyle(
                    theme.textTheme.bodyMedium,
                    color: textColor,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _resolveTypeLabel(BuildContext context, ShareContentType type) {
    final l10n = context.l10n;
    switch (type) {
      case ShareContentType.summary:
        return l10n.podcast_filter_with_summary;
      case ShareContentType.transcript:
        return l10n.podcast_tab_transcript;
      case ShareContentType.chat:
        return l10n.podcast_tab_chat;
    }
  }

  static Rect _resolveShareOrigin(BuildContext context) {
    final renderObject = context.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize) {
      return renderObject.localToGlobal(Offset.zero) & renderObject.size;
    }
    final size = MediaQuery.sizeOf(context);
    if (size.width > 0 && size.height > 0) {
      return Offset.zero & size;
    }
    return const Rect.fromLTWH(0, 0, 1, 1);
  }

  static Future<void> _saveImage(
    BuildContext context, {
    required Uint8List bytes,
    required String fileName,
  }) async {
    final l10n = context.l10n;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        await _saveImageToGallery(context, bytes: bytes, fileName: fileName);
      case TargetPlatform.windows:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
        final location = await file_selector.getSaveLocation(
          suggestedName: fileName,
          confirmButtonText: l10n.save,
          acceptedTypeGroups: const <file_selector.XTypeGroup>[
            file_selector.XTypeGroup(
              label: 'PNG Image',
              extensions: <String>['png'],
            ),
          ],
        );
        if (location == null) {
          return;
        }
        final file = XFile.fromData(
          bytes,
          mimeType: 'image/png',
          name: fileName,
        );
        await file.saveTo(location.path);
      case TargetPlatform.fuchsia:
        throw ContentImageShareException(l10n.podcast_share_not_supported);
    }

    if (context.mounted) {
      showTopFloatingNotice(context, message: l10n.podcast_save_image_success);
    }
  }

  static Future<void> _saveImageToGallery(
    BuildContext context, {
    required Uint8List bytes,
    required String fileName,
  }) async {
    final l10n = context.l10n;
    final granted = await _requestGalleryPermission();
    if (!granted) {
      throw ContentImageShareException(l10n.podcast_save_image_permission);
    }

    final imageName = fileName.endsWith('.png')
        ? fileName.substring(0, fileName.length - 4)
        : fileName;
    final result = await ImageGallerySaverPlus.saveImage(
      bytes,
      name: imageName,
    );
    if (!_isSaveResultSuccess(result)) {
      throw ContentImageShareException(l10n.podcast_save_image_failed);
    }
  }

  static Future<bool> _requestGalleryPermission() async {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        final photosStatus = await Permission.photos.request();
        if (photosStatus.isGranted || photosStatus.isLimited) {
          return true;
        }
        final storageStatus = await Permission.storage.request();
        return storageStatus.isGranted;
      case TargetPlatform.iOS:
        final photosStatus = await Permission.photosAddOnly.request();
        return photosStatus.isGranted || photosStatus.isLimited;
      case TargetPlatform.windows:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return true;
    }
  }

  static bool _isSaveResultSuccess(dynamic result) {
    if (result is! Map) {
      return false;
    }
    final success = result['isSuccess'] ?? result['success'];
    if (success is bool) {
      return success;
    }
    if (success is num) {
      return success != 0;
    }
    if (success is String) {
      final normalized = success.toLowerCase();
      return normalized == 'true' || normalized == '1';
    }
    final filePath = result['filePath'] ?? result['path'];
    if (filePath is String) {
      return filePath.trim().isNotEmpty;
    }
    return false;
  }

  static String _buildFileName(ShareContentType type) {
    final now = DateTime.now();
    final yyyy = now.year.toString().padLeft(4, '0');
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    final hh = now.hour.toString().padLeft(2, '0');
    final min = now.minute.toString().padLeft(2, '0');
    final ss = now.second.toString().padLeft(2, '0');
    return 'personal_ai_${type.name}_$yyyy$mm${dd}_$hh$min$ss.png';
  }

  static Widget _buildShareCard(
    BuildContext context, {
    required double cardWidth,
    required String title,
    required String subtitle,
    required Widget body,
  }) {
    final theme = Theme.of(context);
    final isCompactMobileWidth = cardWidth <= kShareCardMobileMaxWidth;
    final outerPadding = isCompactMobileWidth ? 20.0 : 28.0;
    final contentPadding = isCompactMobileWidth ? 14.0 : 16.0;

    return Material(
      color: Colors.white,
      child: Container(
        width: cardWidth,
        padding: EdgeInsets.all(outerPadding),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black38, width: 1.2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DefaultTextStyle.merge(
              style: _shareTextStyle(
                theme.textTheme.bodyMedium,
                color: Colors.black,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: _shareTextStyle(
                      theme.textTheme.titleLarge,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.black38),
                    ),
                    child: Text(
                      subtitle,
                      style: _shareTextStyle(
                        theme.textTheme.labelMedium,
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(contentPadding),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black38, width: 1.1),
                    ),
                    child: body,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Generated by Personal AI Assistant',
                    style: _shareTextStyle(
                      theme.textTheme.labelSmall,
                      color: Colors.black,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
