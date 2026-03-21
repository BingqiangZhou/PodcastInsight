import 'package:flutter/material.dart';

/// App-specific icons for the Personal AI Assistant application.
///
/// These icons extend the Material Icons with brand-specific styling
/// and are consistent with the overall design language.
class AppIcons {
  AppIcons._();

  // Navigation & Shell
  static const IconData home = Icons.home;
  static const IconData homeOutlined = Icons.home_outlined;
  static const IconData explore = Icons.explore;
  static const IconData exploreOutlined = Icons.explore_outlined;
  static const IconData library = Icons.library_books;
  static const IconData libraryOutlined = Icons.local_library_outlined;
  static const IconData settings = Icons.settings;
  static const IconData settingsOutlined = Icons.settings_outlined;
  static const IconData profile = Icons.person;
  static const IconData profileOutlined = Icons.person_outlined;

  // Player & Audio
  static const IconData play = Icons.play_arrow;
  static const IconData playOutlined = Icons.play_arrow_outlined;
  static const IconData pause = Icons.pause;
  static const IconData pauseOutlined = Icons.pause_outlined;
  static const IconData skip = Icons.skip_next;
  static const IconData skipOutlined = Icons.skip_next_outlined;
  static const IconData replay = Icons.replay;
  static const IconData speed = Icons.speed;
  static const IconData speedOutlined = Icons.speed_outlined;
  static const IconData queue = Icons.queue_music;
  static const IconData queueOutlined = Icons.queue_music_outlined;

  // Search & Discovery
  static const IconData search = Icons.search;
  static const IconData searchOutlined = Icons.search_outlined;
  static const IconData mic = Icons.mic;
  static const IconData micOutlined = Icons.mic_outlined;
  static const IconData filter = Icons.filter_alt;
  static const IconData filterOutlined = Icons.filter_alt_outlined;
  static const IconData sort = Icons.sort;
  static const IconData sortOutlined = Icons.sort_outlined;
  static const IconData bookmark = Icons.bookmark_border;
  static const IconData bookmarkOutlined = Icons.bookmark_border_outlined;
  static const IconData bookmarkAdd = Icons.bookmark_add;

  // AI & Intelligence
  static const IconData aiChip = Icons.memory;
  static const IconData aiChipOutlined = Icons.memory_outlined;
  static const IconData sparkles = Icons.auto_awesome;
  static const IconData sparklesOutlined = Icons.auto_awesome_outlined;
  static const IconData chatBubble = Icons.chat_bubble_outline;
  static const IconData chatBubbleOutline = Icons.chat_bubble_outline;
  static const IconData message = Icons.message;
  static const IconData messageOutlined = Icons.message_outlined;
  static const IconData send = Icons.send;
  static const IconData share = Icons.share;
  static const IconData shareOutlined = Icons.share_outlined;

  // Media & Content
  static const IconData image = Icons.image;
  static const IconData imageOutlined = Icons.image_outlined;
  static const IconData video = Icons.video_file;
  static const IconData videoOutlined = Icons.video_file_outlined;
  static const IconData download = Icons.download;
  static const IconData downloadOutlined = Icons.download_outlined;
  static const IconData upload = Icons.upload;
  static const IconData uploadOutlined = Icons.upload_outlined;
  static const IconData link = Icons.link;
  static const IconData externalLink = Icons.open_in_new;

  // Status & Actions
  static const IconData check = Icons.check;
  static const IconData checkOutlined = Icons.check_box_outlined;
  static const IconData checkCircle = Icons.check_circle;
  static const IconData checkCircleOutlined = Icons.check_circle_outline;
  static const IconData error = Icons.error;
  static const IconData errorOutlined = Icons.error_outline;
  static const IconData warning = Icons.warning;
  static const IconData warningOutlined = Icons.warning_amber_outlined;
  static const IconData info = Icons.info;
  static const IconData infoOutlined = Icons.info_outlined;
  static const IconData help = Icons.help;
  static const IconData helpOutlined = Icons.help_outline;

  // User & Profile
  static const IconData user = Icons.person;
  static const IconData userOutlined = Icons.person_outline;
  static const IconData edit = Icons.edit;
  static const IconData editOutlined = Icons.edit_outlined;
  static const IconData delete = Icons.delete;
  static const IconData deleteOutlined = Icons.delete_outlined;
  static const IconData add = Icons.add;
  static const IconData addOutlined = Icons.add_box_outlined;

  // Common UI Actions
  static const IconData refresh = Icons.refresh;
  static const IconData more = Icons.more_horiz;
  static const IconData moreOutlined = Icons.more_horiz;
  static const IconData expand = Icons.expand_more;
  static const IconData collapse = Icons.unfold_less;
  static const IconData close = Icons.close;
  static const IconData minimize = Icons.minimize;
  static const IconData maximize = Icons.maximize;

  // Illustrative brand icons (for empty states)
  static const IconData emptyPodcast = Icons.podcasts;
  static const IconData emptySearch = Icons.search_off;
  static const IconData emptyLibrary = Icons.library_books;
  static const IconData emptyHistory = Icons.history;
  static const IconData emptyChat = Icons.chat_bubble_outline;

  // Helper method to create a custom icon button
  static Widget iconButton({
    required IconData icon,
    required VoidCallback? onPressed,
    Color? color,
    double size = 24,
    String? tooltip,
  }) {
    return IconButton(
      icon: Icon(icon, size: size, color: color),
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }
}
