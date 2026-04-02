// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Stella';

  @override
  String get appSlogan => 'Your personal assistant for everything you follow.';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get languageFollowSystem => 'Follow System';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageChinese => 'Chinese';

  @override
  String get about => 'About';

  @override
  String get version => 'Version';

  @override
  String get profile => 'Profile';

  @override
  String get preferences => 'Preferences';

  @override
  String get logout => 'Logout';

  @override
  String get cancel => 'Cancel';

  @override
  String get clear => 'Clear';

  @override
  String get confirm => 'Confirm';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get add => 'Add';

  @override
  String get update => 'Update';

  @override
  String get search => 'Search';

  @override
  String get filter => 'Filter';

  @override
  String get refresh => 'Refresh';

  @override
  String get loading => 'Loading...';

  @override
  String get error => 'Error';

  @override
  String get success => 'Success';

  @override
  String get retry => 'Retry';

  @override
  String get close => 'Close';

  @override
  String get ok => 'OK';

  @override
  String get no => 'No';

  @override
  String get auth_welcome_back => 'Dawn\'s near. Let\'s begin.';

  @override
  String get auth_sign_in_subtitle => 'Sign in to continue';

  @override
  String get auth_enter_email => 'Please enter your email';

  @override
  String get auth_enter_valid_email => 'Please enter a valid email';

  @override
  String get auth_enter_password => 'Please enter your password';

  @override
  String get auth_password_too_short =>
      'Password must be at least 8 characters';

  @override
  String get auth_email => 'Email';

  @override
  String get auth_password => 'Password';

  @override
  String get auth_remember_me => 'Remember me';

  @override
  String get auth_forgot_password => 'Forgot Password?';

  @override
  String get auth_login => 'Sign In';

  @override
  String get auth_no_account => 'Don\'t have an account?';

  @override
  String get auth_sign_up => 'Sign Up';

  @override
  String get auth_create_account => 'Create Account';

  @override
  String get auth_sign_up_subtitle => 'Join us to get started';

  @override
  String get auth_full_name => 'Full Name';

  @override
  String get auth_enter_name => 'Please enter your name';

  @override
  String get auth_confirm_password => 'Confirm Password';

  @override
  String get auth_passwords_not_match => 'Passwords do not match';

  @override
  String get auth_agree_terms => 'I agree to the Terms and Conditions';

  @override
  String get auth_already_have_account => 'Already have an account?';

  @override
  String get auth_sign_in_link => 'Sign In';

  @override
  String get auth_reset_password => 'Reset Password';

  @override
  String get auth_reset_password_subtitle =>
      'Enter your email to receive reset instructions';

  @override
  String get auth_send_reset_link => 'Send Reset Link';

  @override
  String get auth_back_to_login => 'Back to Login';

  @override
  String get auth_reset_email_sent => 'Password reset email sent';

  @override
  String get profile_subscriptions => 'Subscriptions';

  @override
  String get podcast_episodes => 'Episodes';

  @override
  String get podcast_unknown_author => 'Unknown Author';

  @override
  String get podcast_no_subscriptions => 'No subscriptions yet';

  @override
  String get podcast_play => 'Play';

  @override
  String get home => 'Home';

  @override
  String get nav_feed => 'Library';

  @override
  String get nav_podcast => 'Discover';

  @override
  String get nav_profile => 'Profile';

  @override
  String get podcast_feed_page_title => 'Library';

  @override
  String get podcast_add_podcast => 'Add Podcast';

  @override
  String get podcast_bulk_import => 'Bulk Import';

  @override
  String get podcast_failed_to_load_feed => 'Failed to load feed';

  @override
  String get podcast_retry => 'Retry';

  @override
  String get podcast_no_episodes_found => 'No episodes found';

  @override
  String get podcast_daily_report_title => 'Daily Report';

  @override
  String get podcast_daily_report_open => 'Open daily report';

  @override
  String get podcast_daily_report_entry_subtitle =>
      'Review history and generate reports by date';

  @override
  String get podcast_daily_report_generate_success => 'Daily report generated';

  @override
  String get podcast_daily_report_generate_failed =>
      'Failed to generate daily report';

  @override
  String get podcast_daily_report_empty => 'No daily report available yet';

  @override
  String get podcast_daily_report_loading => 'Loading daily report...';

  @override
  String get podcast_daily_report_dates => 'History';

  @override
  String get podcast_daily_report_generated_prefix => 'Generated';

  @override
  String podcast_daily_report_items(int count) {
    return '$count items';
  }

  @override
  String get podcast_share_as_image => 'Share as Image';

  @override
  String get podcast_save_image_success => 'Image saved successfully';

  @override
  String get podcast_save_image_failed => 'Failed to save image';

  @override
  String get podcast_save_image_permission =>
      'Photo permission is required to save image';

  @override
  String get podcast_share_all_content => 'Share All';

  @override
  String get podcast_share_selection_required =>
      'Please select content before sharing';

  @override
  String get podcast_share_not_supported =>
      'Image sharing is not supported on this platform';

  @override
  String get podcast_share_failed => 'Failed to share image';

  @override
  String get podcast_share_preparing_image => 'Preparing image...';

  @override
  String get podcast_share_in_progress => 'Image generation is in progress';

  @override
  String podcast_share_truncated(int max) {
    return 'Content truncated to first $max characters';
  }

  @override
  String get podcast_default_podcast => 'Podcast';

  @override
  String get validation_invalid_url => 'Invalid URL format';

  @override
  String get validation_too_short => 'Too short';

  @override
  String get unknown_error => 'An unknown error occurred';

  @override
  String get forbidden => 'Access denied';

  @override
  String get action_completed => 'Action completed successfully';

  @override
  String get no_data => 'No data available';

  @override
  String get pull_to_refresh => 'Pull to refresh';

  @override
  String get refreshing => 'Refreshing...';

  @override
  String get podcast_title => 'Podcasts';

  @override
  String get podcast_description => 'No description';

  @override
  String get podcast_player_unknown_episode => 'Unknown Episode';

  @override
  String get podcast_player_no_audio => 'No audio link';

  @override
  String get podcast_coming_soon => 'Coming Soon';

  @override
  String get podcast_filter_all => 'All';

  @override
  String get podcast_filter_unplayed => 'Unplayed';

  @override
  String get podcast_filter_played => 'Played';

  @override
  String get podcast_filter_with_summary => 'Summary';

  @override
  String get podcast_mark_all_played => 'Mark All as Played';

  @override
  String get podcast_mark_all_unplayed => 'Mark All as Unplayed';

  @override
  String get podcast_no_episodes => 'No Episodes Found';

  @override
  String get podcast_no_episodes_with_summary => 'No Episodes with Summary';

  @override
  String get podcast_try_adjusting_filters => 'Try adjusting your filters';

  @override
  String get podcast_no_episodes_yet =>
      'This podcast might not have any episodes yet';

  @override
  String get podcast_failed_load_episodes => 'Failed to Load Episodes';

  @override
  String get podcast_filter_episodes => 'Filter Episodes';

  @override
  String get podcast_playback_status => 'Playback Status:';

  @override
  String get podcast_all_episodes => 'All Episodes';

  @override
  String get podcast_unplayed_only => 'Unplayed Only';

  @override
  String get podcast_played_only => 'Played Only';

  @override
  String get podcast_only_with_summary => 'Only episodes with Summary';

  @override
  String get podcast_apply => 'Apply';

  @override
  String get podcast_add_dialog_title => 'Add Podcast';

  @override
  String get podcast_rss_feed_url => 'RSS Feed URL';

  @override
  String get podcast_feed_url_hint => 'https://example.com/feed.xml';

  @override
  String get podcast_enter_url => 'Please enter a URL';

  @override
  String get podcast_added_successfully => 'Podcast added successfully!';

  @override
  String get podcast_failed_add => 'Failed to add podcast:';

  @override
  String get podcast_need_many => 'Need to add many?';

  @override
  String get podcast_adding => 'Adding...';

  @override
  String get profile_guest_user => 'Guest User';

  @override
  String get profile_please_login => 'Please log in';

  @override
  String get profile_account_settings => 'Account Settings';

  @override
  String get profile_edit_profile => 'Edit Profile';

  @override
  String get profile_security => 'Security';

  @override
  String get profile_security_subtitle =>
      'Password, authentication, and privacy';

  @override
  String get profile_notifications => 'Notifications';

  @override
  String get profile_notifications_subtitle =>
      'Push notifications and email alerts';

  @override
  String get profile_auto_sync => 'Auto Sync';

  @override
  String get profile_help_center => 'Help Center';

  @override
  String get profile_help_center_subtitle => 'Get help and support';

  @override
  String get profile_clear_cache => 'Clear Cache';

  @override
  String get profile_cache_management => 'Storage & Cache';

  @override
  String get profile_cache_management_subtitle =>
      'View and clear images, audio, and other cached data';

  @override
  String get profile_clear_cache_confirm =>
      'This will remove cached images, audio, and API caches. Continue?';

  @override
  String get profile_clearing_cache => 'Clearing cache...';

  @override
  String get profile_cache_cleared => 'Cache cleared';

  @override
  String profile_cache_clear_failed(String error) {
    return 'Failed to clear cache: $error';
  }

  @override
  String get profile_cache_manage_title => 'Storage & Cache';

  @override
  String get profile_cache_manage_total_used => 'Total Used';

  @override
  String get profile_cache_manage_images => 'Images';

  @override
  String get profile_cache_manage_audio => 'Audio';

  @override
  String get profile_cache_manage_other => 'Other';

  @override
  String profile_cache_manage_item_count(int count) {
    return '$count items';
  }

  @override
  String get profile_cache_manage_details => 'DETAILS';

  @override
  String get profile_cache_manage_clean => 'Clean';

  @override
  String get profile_cache_manage_notice =>
      'Clearing cache will remove downloaded images and temporary files. Your subscriptions and preferences will be kept.';

  @override
  String profile_cache_manage_deep_clean_all(String size) {
    return 'Deep Clean All ($size)';
  }

  @override
  String profile_cache_manage_delete_selected_confirm(int count, String size) {
    return 'Delete $count cached items ($size) from selected categories?';
  }

  @override
  String get profile_about_subtitle => 'App version and information';

  @override
  String get profile_name => 'Name';

  @override
  String get profile_email_field => 'Email';

  @override
  String get profile_bio => 'Bio';

  @override
  String get profile_updated_successfully => 'Profile updated successfully';

  @override
  String get profile_change_password => 'Change Password';

  @override
  String get profile_biometric_auth => 'Biometric Authentication';

  @override
  String get profile_two_factor_auth => 'Two-Factor Authentication';

  @override
  String get profile_user_guide => 'User Guide';

  @override
  String get profile_user_guide_subtitle => 'Learn how to use the app';

  @override
  String get profile_video_tutorials => 'Video Tutorials';

  @override
  String get profile_video_tutorials_subtitle => 'Watch step-by-step guides';

  @override
  String get profile_contact_support => 'Contact Support';

  @override
  String get profile_contact_support_subtitle => 'Get help from our team';

  @override
  String get profile_logout_title => 'Logout';

  @override
  String get profile_logout_message => 'Are you sure you want to logout?';

  @override
  String get profile_logged_out => 'Logged out successfully';

  @override
  String get invalid_navigation_arguments => 'Invalid navigation arguments';

  @override
  String get invalid_episode_id => 'Invalid episode ID';

  @override
  String get backend_api_server_config => 'Backend API Server Configuration';

  @override
  String get backend_api_url_label => 'Backend API URL';

  @override
  String get backend_api_url_hint =>
      'https://api.example.com\\nor http://192.168.1.10:8080';

  @override
  String get backend_api_description =>
      'Note: This is the backend API server, not related to AI model API';

  @override
  String get use_local_url => 'Local Server';

  @override
  String get connection_error_hint => 'Connection error';

  @override
  String get connection_status_unverified => 'Unverified';

  @override
  String get connection_status_verifying => 'Verifying...';

  @override
  String get connection_status_success => 'Success';

  @override
  String get connection_status_failed => 'Failed';

  @override
  String get server_history_title => 'History';

  @override
  String get profile_viewed_title => 'Viewed';

  @override
  String get server_history_empty => 'No history';

  @override
  String save_failed(Object error) {
    return 'Save failed: $error';
  }

  @override
  String get restore_defaults_success => 'Restored default server address';

  @override
  String get profile_server_switch_title => 'Switch Server';

  @override
  String get profile_server_switch_message =>
      'Switching server will clear all local data and require re-login. Continue?';

  @override
  String get profile_server_switch_success =>
      'Server switched successfully. Please log in again.';

  @override
  String get profile_server_switch_clearing => 'Clearing data...';

  @override
  String get drop_files_here => 'Drop files here!';

  @override
  String get podcast_enter_select_mode => 'Select Mode';

  @override
  String get podcast_deselect_all => 'Deselect All';

  @override
  String podcast_selected_count(int count) {
    return '$count selected';
  }

  @override
  String get update_check_updates => 'Check for Updates';

  @override
  String get update_auto_check => 'Automatically check for updates';

  @override
  String get update_new_version_available => 'New Version Available';

  @override
  String get update_skip_this_version => 'Skip This Version';

  @override
  String get update_later => 'Later';

  @override
  String get update_download => 'Download';

  @override
  String get update_latest_version => 'Latest Version';

  @override
  String get update_published_at => 'Published';

  @override
  String get update_file_size => 'Size';

  @override
  String get update_release_notes => 'Release Notes';

  @override
  String get update_download_failed => 'Download failed';

  @override
  String get update_checking => 'Checking for updates...';

  @override
  String get update_check_failed => 'Check Failed';

  @override
  String get update_up_to_date => 'You\'re up to date';

  @override
  String get update_try_again => 'Try Again';

  @override
  String get update_platform_no_asset =>
      'No installer available for your platform';

  @override
  String get back_button => 'Back';

  @override
  String get feed_no_subscriptions_hint =>
      'Subscribe to podcasts you\'re interested in!';

  @override
  String get podcast_no_shownotes => 'No show notes available';

  @override
  String get podcast_no_transcript => 'No transcript available';

  @override
  String get podcast_click_to_transcribe =>
      'Click \"Start Transcription\" to generate transcript';

  @override
  String get podcast_transcription_failed => 'Failed';

  @override
  String date_format(int year, String month, String day) {
    return '$year-$month-$day';
  }

  @override
  String get podcast_discover_title => 'Discover';

  @override
  String get podcast_discover_top_charts => 'Top Charts';

  @override
  String podcast_discover_trending_in(String country) {
    return 'Trending in $country';
  }

  @override
  String get podcast_discover_see_all => 'See All';

  @override
  String get podcast_discover_no_chart_data => 'No chart data available';

  @override
  String get podcast_discover_browse_by_category => 'Browse by Category';

  @override
  String get podcast_country_label => 'Country/Region';

  @override
  String get podcast_search_no_results => 'No results found';

  @override
  String get podcast_search_section_podcasts => 'Podcasts';

  @override
  String get podcast_search_section_episodes => 'Episodes';

  @override
  String get podcast_subscribe => 'Subscribe';

  @override
  String get podcast_subscribed => 'Subscribed';

  @override
  String podcast_subscribe_success(String podcastName) {
    return 'Subscribed to $podcastName';
  }

  @override
  String podcast_subscribe_failed(String error) {
    return 'Failed to subscribe: $error';
  }

  @override
  String get podcast_country_china => 'China';

  @override
  String get podcast_country_usa => 'USA';

  @override
  String get podcast_country_japan => 'Japan';

  @override
  String get podcast_country_uk => 'United Kingdom';

  @override
  String get podcast_country_germany => 'Germany';

  @override
  String get podcast_country_france => 'France';

  @override
  String get podcast_country_canada => 'Canada';

  @override
  String get podcast_country_australia => 'Australia';

  @override
  String get podcast_country_korea => 'South Korea';

  @override
  String get podcast_country_taiwan => 'Taiwan';

  @override
  String get podcast_country_hong_kong => 'Hong Kong';

  @override
  String get podcast_country_india => 'India';

  @override
  String get podcast_country_brazil => 'Brazil';

  @override
  String get podcast_country_mexico => 'Mexico';

  @override
  String get podcast_country_spain => 'Spain';

  @override
  String get podcast_country_italy => 'Italy';

  @override
  String get podcast_reparse_tooltip =>
      'Reparse podcast (fetch latest episodes and links)';

  @override
  String get podcast_reparsing => 'Reparse podcast...';

  @override
  String get podcast_reparse_completed => '✅ Reparse completed!';

  @override
  String get podcast_reparse_failed => '❌ Reparse failed:';

  @override
  String get podcast_player_now_playing => 'Now Playing';

  @override
  String get podcast_player_collapse => 'Collapse';

  @override
  String get podcast_player_list => 'Playlist';

  @override
  String get podcast_player_sleep_mode => 'Sleep Mode';

  @override
  String get podcast_player_play => 'Play';

  @override
  String get podcast_player_pause => 'Pause';

  @override
  String get podcast_player_rewind_10 => 'Rewind 10s';

  @override
  String get podcast_player_forward_30 => 'Forward 30s';

  @override
  String get podcast_play_episode => 'Play';

  @override
  String get podcast_play_episode_full => 'Play';

  @override
  String get podcast_resume_episode => 'Resume';

  @override
  String get podcast_episode_playing => 'Playing';

  @override
  String get podcast_source => 'Source';

  @override
  String get podcast_speed_title => 'Playback Speed';

  @override
  String get podcast_speed_done => 'Done';

  @override
  String get podcast_tab_shownotes => 'Shownotes';

  @override
  String get podcast_tab_transcript => 'Transcript';

  @override
  String get podcast_tab_summary => 'Summary';

  @override
  String get podcast_tab_chat => 'Chat';

  @override
  String get podcast_transcription_processing => 'Transcription in progress...';

  @override
  String get podcast_transcription_auto_starting =>
      'Auto-starting transcription...';

  @override
  String get podcast_conversation_title => 'Chat with AI';

  @override
  String get podcast_conversation_empty_title => 'Start a conversation';

  @override
  String get podcast_conversation_empty_hint =>
      'Ask questions about this episode and get AI-powered answers based on the transcript.';

  @override
  String get podcast_conversation_history => 'Chat History';

  @override
  String get podcast_conversation_delete_title => 'Delete Chat';

  @override
  String get podcast_conversation_delete_confirm =>
      'Are you sure you want to delete this chat? This action cannot be undone.';

  @override
  String get podcast_conversation_send_hint => 'Send message (Ctrl+Enter)';

  @override
  String get podcast_conversation_no_summary_hint =>
      'Conversation requires a completed transcript. Please wait for transcription to complete.';

  @override
  String get podcast_conversation_loading_failed =>
      'Failed to load conversation history';

  @override
  String get podcast_conversation_user => 'You';

  @override
  String get podcast_conversation_assistant => 'AI Assistant';

  @override
  String get podcast_conversation_reload => 'Reload';

  @override
  String get podcast_conversation_new_chat => 'New Chat';

  @override
  String get podcast_conversation_new_chat_confirm =>
      'Starting a new chat will clear the current conversation history. Are you sure?';

  @override
  String podcast_conversation_message_count(int count) {
    return '$count messages';
  }

  @override
  String get podcast_error_loading => 'Failed to load content';

  @override
  String get podcast_transcription_delete => 'Delete';

  @override
  String get podcast_transcription_clear => 'Clear';

  @override
  String get podcast_episode_not_found => 'Episode not found';

  @override
  String get podcast_go_back => 'Go back';

  @override
  String get podcast_load_failed => 'Failed to load';

  @override
  String get podcast_summary_empty_hint => 'No summary available';

  @override
  String get podcast_please_select_time => 'Please select a time';

  @override
  String get podcast_please_select_time_and_day =>
      'Please select a time and day';

  @override
  String podcast_bulk_import_file_error(String error) {
    return 'Failed to read file: $error';
  }

  @override
  String get podcast_bulk_import_input_text => 'Text';

  @override
  String get podcast_bulk_import_input_file => 'File';

  @override
  String get podcast_bulk_import_no_urls_text => 'No URLs found in text';

  @override
  String podcast_bulk_import_links_found(int total, int valid) {
    return 'Found $total links, $valid valid RSS feeds';
  }

  @override
  String get podcast_bulk_import_urls_exist =>
      'All URLs already exist in the list';

  @override
  String get podcast_bulk_import_edit_url => 'Edit RSS URL';

  @override
  String get podcast_bulk_import_save_revalidate => 'Save & Re-validate';

  @override
  String get podcast_bulk_import_no_urls_file => 'No URLs found in file';

  @override
  String get podcast_bulk_import_no_valid_feeds =>
      'No valid RSS feeds to import. Please remove invalid URLs or wait for validation to complete.';

  @override
  String podcast_bulk_import_imported_count(int count) {
    return 'Successfully imported $count RSS feeds';
  }

  @override
  String podcast_bulk_import_failed(String error) {
    return 'Import failed: $error';
  }

  @override
  String podcast_bulk_import_valid_count(int count) {
    return 'Valid ($count)';
  }

  @override
  String podcast_bulk_import_invalid_count(int count) {
    return 'Invalid ($count)';
  }

  @override
  String get podcast_unknown_title => 'Unknown Title';

  @override
  String get podcast_copy => 'Copy';

  @override
  String get podcast_edit_retry => 'Edit & Retry';

  @override
  String get podcast_remove => 'Remove';

  @override
  String get podcast_bulk_import_drag_drop => 'Drag & Drop files here or';

  @override
  String get podcast_bulk_import_select_file => 'Select File';

  @override
  String get podcast_rss_list => 'RSS List';

  @override
  String get podcast_import_all => 'Import All';

  @override
  String get podcast_no_items => 'No items';

  @override
  String get podcast_bulk_import_extract => 'Extract';

  @override
  String get podcast_bulk_import_click_select => 'Click to Select File';

  @override
  String get podcast_bulk_import_or_drag_drop => 'or drag & drop here';

  @override
  String get podcast_bulk_import_paste_hint =>
      'Paste URLs or OPML content here...';

  @override
  String get podcast_not_valid_rss => 'Not a valid RSS feed';

  @override
  String podcast_copied(String text) {
    return 'Copied: $text';
  }

  @override
  String get podcast_bulk_import_hint_text => 'URL';

  @override
  String get podcast_global_rss_settings_title => 'Global RSS Settings';

  @override
  String podcast_updated_subscriptions(int count) {
    return 'Updated $count subscriptions';
  }

  @override
  String get podcast_summary_generate_failed => 'Failed to generate summary';

  @override
  String get podcast_summary_no_summary => 'No summary available';

  @override
  String get podcast_summary_generate => 'Generate Summary';

  @override
  String get podcast_summary_transcription_required =>
      'Transcription required to generate AI summary';

  @override
  String get podcast_advanced_options => 'Advanced Options';

  @override
  String get podcast_regenerate => 'Regenerate';

  @override
  String get podcast_ai_model => 'AI Model';

  @override
  String get podcast_default_model => 'Default';

  @override
  String get podcast_custom_prompt => 'Custom Prompt (Optional)';

  @override
  String get podcast_custom_prompt_hint => 'e.g., Focus on technical points...';

  @override
  String get podcast_generating_summary => 'Generating AI summary...';

  @override
  String get podcast_summary_chars => 'chars';

  @override
  String get theme_mode => 'Theme Mode';

  @override
  String get theme_mode_subtitle => 'Choose your preferred theme';

  @override
  String get theme_mode_follow_system => 'Follow System';

  @override
  String get theme_mode_light => 'Light';

  @override
  String get theme_mode_dark => 'Dark';

  @override
  String get theme_mode_select_title => 'Select Theme Mode';

  @override
  String theme_mode_changed(String mode) {
    return 'Theme mode changed to $mode';
  }

  @override
  String get podcast_transcript_search_hint => 'Search transcript content...';

  @override
  String get podcast_transcript_no_match => 'No matching content found';

  @override
  String podcast_transcript_match(int index) {
    return 'Match $index';
  }

  @override
  String get transcription_start_title => 'Start Transcription';

  @override
  String get transcription_start_desc =>
      'Generate full text transcription for this episode\nSupports multi-language and high accuracy';

  @override
  String get transcription_start_button => 'Start Transcription';

  @override
  String get transcription_auto_hint =>
      'Or enable auto-transcription in settings';

  @override
  String get transcription_starting => 'Starting transcription...';

  @override
  String get transcription_started_success =>
      '✓ Transcription started successfully';

  @override
  String transcription_start_failed(String error) {
    return '✗ Failed to start: $error';
  }

  @override
  String get transcription_pending_title => 'Pending';

  @override
  String get transcription_pending_desc =>
      'Transcription task has been queued\nProcessing will start shortly';

  @override
  String get transcription_progress_complete => 'Complete';

  @override
  String transcription_duration_label(String duration) {
    return 'Duration: $duration';
  }

  @override
  String transcription_words_label(String count) {
    return '~${count}K words';
  }

  @override
  String get transcription_step_download => 'Download';

  @override
  String get transcription_step_convert => 'Convert';

  @override
  String get transcription_step_split => 'Split';

  @override
  String get transcription_step_transcribe => 'Transcribe';

  @override
  String get transcription_step_merge => 'Merge';

  @override
  String get transcription_complete_title => 'Transcription Complete';

  @override
  String get transcription_complete_desc =>
      'Transcript generated successfully\nYou can now read and search the content';

  @override
  String get transcription_stat_words => 'Words';

  @override
  String get transcription_stat_duration => 'Duration';

  @override
  String get transcription_stat_accuracy => 'Accuracy';

  @override
  String transcription_completed_at(String time) {
    return 'Completed at: $time';
  }

  @override
  String get transcription_view_button => 'View Transcript';

  @override
  String get transcription_failed_title => 'Transcription Failed';

  @override
  String get transcription_unknown_error => 'Unknown error';

  @override
  String get transcription_technical_details => 'Technical Details';

  @override
  String get transcription_retry_button => 'Retry';

  @override
  String get transcription_error_already_progress =>
      'Transcription already in progress';

  @override
  String get transcription_error_network => 'Network connection failed';

  @override
  String get transcription_error_audio_download => 'Failed to download audio';

  @override
  String get transcription_error_service => 'Transcription service error';

  @override
  String get transcription_error_format => 'Audio format conversion failed';

  @override
  String get transcription_error_server_restart => 'Service was restarted';

  @override
  String get transcription_error_generic => 'Transcription failed';

  @override
  String get transcription_suggest_network =>
      'Check your internet connection and try again';

  @override
  String get transcription_suggest_audio =>
      'The audio file may be unavailable. Try again later';

  @override
  String get transcription_suggest_service =>
      'The transcription service may be busy. Retry in a moment';

  @override
  String get transcription_suggest_format =>
      'The audio format may not be supported. Try a different episode';

  @override
  String get transcription_suggest_restart =>
      'Click Retry to start a new transcription task';

  @override
  String get transcription_suggest_generic =>
      'Try clicking Retry to start over';

  @override
  String get player_playback_speed_title => 'Playback Speed';

  @override
  String get player_apply_subscription_only =>
      'Apply to current subscription only';

  @override
  String get player_apply_subscription_subtitle =>
      'Checked: current subscription only; Unchecked: global default';

  @override
  String get player_sleep_timer_title => 'Sleep Timer';

  @override
  String get player_sleep_timer_desc =>
      'Playback will automatically pause after the set time';

  @override
  String get player_stop_after_episode => 'Stop after this episode';

  @override
  String get player_cancel_timer => 'Cancel timer';

  @override
  String player_minutes(int count) {
    return '$count min';
  }

  @override
  String player_hours_minutes(int hours, int minutes) {
    return '${hours}h ${minutes}min';
  }

  @override
  String player_hours(int count) {
    return '${count}h';
  }

  @override
  String get global_rss_failed_load => 'Failed to load';

  @override
  String get global_rss_retry => 'Retry';

  @override
  String global_rss_affected_count(int count) {
    return 'Affected Subscriptions ($count)';
  }

  @override
  String get global_rss_no_subscriptions => 'No RSS subscriptions';

  @override
  String get global_rss_schedule_title =>
      'Update Schedule for All RSS Subscriptions';

  @override
  String global_rss_apply_desc(int count) {
    return 'This will apply to all $count subscriptions';
  }

  @override
  String get global_rss_update_frequency => 'Update Frequency';

  @override
  String get global_rss_hourly => 'Hourly';

  @override
  String get global_rss_daily => 'Daily';

  @override
  String get global_rss_weekly => 'Weekly';

  @override
  String get global_rss_update_time => 'Update Time';

  @override
  String get global_rss_select_time => 'Select time';

  @override
  String get global_rss_select_time_button => 'Select Time';

  @override
  String get global_rss_day_of_week => 'Day of Week';

  @override
  String get global_rss_applying => 'Applying...';

  @override
  String get global_rss_apply_all => 'Apply to All Subscriptions';

  @override
  String get global_rss_failed_update => 'Failed to update subscriptions';

  @override
  String get page_not_found => 'Page Not Found';

  @override
  String get page_not_found_subtitle =>
      'Please select a valid tab from the navigation';

  @override
  String error_prefix(String error) {
    return 'Error: $error';
  }

  @override
  String get downloading_in_background => 'Downloading in background...';

  @override
  String version_label(String version) {
    return 'Version: $version';
  }

  @override
  String build_label(String build) {
    return 'Build: $build';
  }

  @override
  String get added_to_queue => 'Added to queue';

  @override
  String failed_to_add_to_queue(String error) {
    return 'Failed to add to queue: $error';
  }

  @override
  String error_opening_link(String error) {
    return 'Error opening link: $error';
  }

  @override
  String get queue_is_empty => 'Queue is empty';

  @override
  String get queue_up_next => 'Up Next';

  @override
  String get queue_now_playing => 'Now playing';

  @override
  String get queue_in_queue => 'in queue';

  @override
  String get queue_remaining_label => 'Remaining';

  @override
  String get queue_syncing => 'Syncing queue';

  @override
  String get queue_saving_order => 'Saving order';

  @override
  String get queue_updating => 'Updating queue';

  @override
  String get queue_subtitle_separator => ' • ';

  @override
  String failed_to_load_queue(String error) {
    return 'Failed to load queue: $error';
  }

  @override
  String failed_to_reorder_queue(String error) {
    return 'Failed to reorder queue: $error';
  }

  @override
  String failed_to_play_item(String error) {
    return 'Failed to play item: $error';
  }

  @override
  String failed_to_remove_item(String error) {
    return 'Failed to remove item: $error';
  }

  @override
  String get apply_button => 'Apply';

  @override
  String get auth_verification_title => 'Auth Verification';

  @override
  String get auth_password_requirement_uppercase =>
      'Contain at least one uppercase letter';

  @override
  String get auth_password_requirement_lowercase =>
      'Contain at least one lowercase letter';

  @override
  String get auth_password_requirement_number => 'Contain at least one number';

  @override
  String get auth_password_req_uppercase_short =>
      'At least one uppercase letter (A-Z)';

  @override
  String get auth_password_req_lowercase_short =>
      'At least one lowercase letter (a-z)';

  @override
  String get auth_password_req_number_short => 'At least one number (0-9)';

  @override
  String get auth_password_requirement_min_length => 'Be at least 8 characters';

  @override
  String get auth_password_requirements_title => 'Password must:';

  @override
  String get auth_terms_and_conditions => 'Terms and Conditions';

  @override
  String get auth_privacy_policy => 'Privacy Policy';

  @override
  String get auth_set_new_password => 'Set New Password';

  @override
  String get auth_new_password => 'New Password';

  @override
  String get podcast_add_to_queue => 'Add to queue';

  @override
  String get episode_unknown_title => 'Unknown Episode';

  @override
  String get transcription_status_pending => 'Pending';

  @override
  String get transcription_status_downloading => 'Downloading audio...';

  @override
  String get transcription_status_converting => 'Converting format...';

  @override
  String get transcription_status_transcribing => 'Transcribing...';

  @override
  String get transcription_status_processing => 'Processing text...';

  @override
  String get transcription_status_completed => 'Completed';

  @override
  String get transcription_status_failed => 'Failed';

  @override
  String get profile_ai_summary => 'AI Summary';

  @override
  String get profile_support_section => 'Support';

  @override
  String get auth_and => ' and ';

  @override
  String get sidebarCollapseMenu => 'Collapse Menu';

  @override
  String get sidebarExpandMenu => 'Expand Menu';

  @override
  String get sidebarAppTitle => 'AI Assistant';

  @override
  String get podcast_highlights_title => 'Highlights';

  @override
  String get podcast_highlights_loading => 'Loading...';

  @override
  String get podcast_highlights_empty => 'No highlights yet';

  @override
  String podcast_highlights_items(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count highlights',
      one: '1 highlight',
    );
    return '$_temp0';
  }

  @override
  String get podcast_highlights_insight => 'Insight';

  @override
  String get podcast_highlights_novelty => 'Novelty';

  @override
  String get podcast_highlights_actionability => 'Actionability';

  @override
  String get podcast_highlights_favorite => 'Favorite';

  @override
  String get podcast_highlights_unfavorite => 'Unfavorite';

  @override
  String get podcast_highlights_dates => 'Select Date';

  @override
  String get podcast_highlights_generated_prefix => 'Generated at';

  @override
  String get podcast_highlights_original_quote => 'Original Quote';

  @override
  String get podcast_highlights_load_failed => 'Failed to load';

  @override
  String get podcast_highlights_cannot_load => 'Cannot load highlights';

  @override
  String get podcast_highlights_retry => 'Retry';

  @override
  String get podcast_highlights_no_highs => 'No highlights';

  @override
  String get podcast_highlights_loading_highlights => 'Loading highlights...';

  @override
  String get podcast_highlights_favorited => 'Favorited';

  @override
  String podcast_highlights_overall_score(double score) {
    return 'Score: $score';
  }

  @override
  String get podcast_highlights_topic_tags => 'Topics';

  @override
  String podcast_highlights_multiple_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count highlights',
      one: '1 highlight',
    );
    return '$_temp0';
  }

  @override
  String get podcast_highlights_extract_hint =>
      'Extract key insights from this transcript';

  @override
  String get podcast_highlights_extract_action => 'Extract';

  @override
  String get podcast_highlights_extract_queued =>
      'Highlight extraction started. Please check back in a few minutes.';

  @override
  String get podcast_highlights_extract_failed =>
      'Failed to start highlight extraction';

  @override
  String get podcast_transcript_view_full => 'Full Text';

  @override
  String get podcast_transcript_view_highlights => 'Highlights';

  @override
  String get podcast_highlights_empty_title => 'No Highlights Yet';

  @override
  String get podcast_highlights_empty_subtitle =>
      'Extract key insights from this episode';

  @override
  String get auth_brand_name => 'Personal AI Workspace';

  @override
  String get auth_agree_prefix => 'I agree to the ';

  @override
  String auth_reset_email_sent_to(String email) {
    return 'We\'ve sent a password reset link to\n$email';
  }

  @override
  String get auth_check_email_fallback =>
      'Please check your email and click the link to reset your password';

  @override
  String get auth_resend_email => 'Didn\'t receive the email? Resend';

  @override
  String get auth_invalid_reset_link =>
      'Invalid reset link. Please request a new password reset.';

  @override
  String get auth_password_reset_success =>
      'Your password has been successfully reset. You can now login with your new password.';

  @override
  String get auth_new_password_instruction =>
      'Your new password must be different from\nprevious used passwords';

  @override
  String get podcast_report_label => 'Report';

  @override
  String get podcast_queue_loading_title => 'Loading';

  @override
  String get podcast_queue_loading_subtitle => 'Please wait...';

  @override
  String get profile_subscriptions_subtitle => 'Subscribed shows';

  @override
  String profile_subscriptions_count(int count) {
    return '$count subscribed shows';
  }

  @override
  String podcast_episode_number(int number) {
    return 'EP $number';
  }

  @override
  String get podcast_summary_task_added => 'Summary task added to task list';

  @override
  String connection_error_prefix(String error) {
    return 'Connection error: $error';
  }
}
