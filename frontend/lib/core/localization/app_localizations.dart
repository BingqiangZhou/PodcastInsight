import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'localization/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// The title of the application
  ///
  /// In en, this message translates to:
  /// **'Stella'**
  String get appTitle;

  /// The slogan of the application
  ///
  /// In en, this message translates to:
  /// **'Your personal assistant for everything you follow.'**
  String get appSlogan;

  /// Settings page title
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Language setting label
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// Option to follow system language
  ///
  /// In en, this message translates to:
  /// **'Follow System'**
  String get languageFollowSystem;

  /// English language option
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// Chinese language option
  ///
  /// In en, this message translates to:
  /// **'Chinese'**
  String get languageChinese;

  /// About section title
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// App version label
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// Profile page title
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// Preferences section title
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get preferences;

  /// Logout button label
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// Cancel button label
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Clear button label
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// Confirm button label
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// Save button label
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Delete button label
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Edit button label
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// Add button label
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// Update button label
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get update;

  /// Search button label
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// Filter button label
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filter;

  /// Refresh button label
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// Loading message
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// Error label
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// Success label
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get success;

  /// Retry button label
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// Close button label
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// OK button label
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No button label
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// Login page welcome title
  ///
  /// In en, this message translates to:
  /// **'Dawn\'s near. Let\'s begin.'**
  String get auth_welcome_back;

  /// Login page subtitle
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue'**
  String get auth_sign_in_subtitle;

  /// Email field validation message
  ///
  /// In en, this message translates to:
  /// **'Please enter your email'**
  String get auth_enter_email;

  /// Email validation error
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email'**
  String get auth_enter_valid_email;

  /// Password field validation message
  ///
  /// In en, this message translates to:
  /// **'Please enter your password'**
  String get auth_enter_password;

  /// Password length validation
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters'**
  String get auth_password_too_short;

  /// Email field label
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get auth_email;

  /// Password field label
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get auth_password;

  /// Remember me checkbox label
  ///
  /// In en, this message translates to:
  /// **'Remember me'**
  String get auth_remember_me;

  /// Forgot password link
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get auth_forgot_password;

  /// Login button label
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get auth_login;

  /// No account prompt
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get auth_no_account;

  /// Sign up button label
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get auth_sign_up;

  /// Create account page title
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get auth_create_account;

  /// Sign up page subtitle
  ///
  /// In en, this message translates to:
  /// **'Join us to get started'**
  String get auth_sign_up_subtitle;

  /// Full name field label
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get auth_full_name;

  /// Name field validation
  ///
  /// In en, this message translates to:
  /// **'Please enter your name'**
  String get auth_enter_name;

  /// Confirm password field label
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get auth_confirm_password;

  /// Password mismatch error
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get auth_passwords_not_match;

  /// Terms agreement checkbox
  ///
  /// In en, this message translates to:
  /// **'I agree to the Terms and Conditions'**
  String get auth_agree_terms;

  /// Already have account prompt
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get auth_already_have_account;

  /// Sign in link label
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get auth_sign_in_link;

  /// Reset password page title
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get auth_reset_password;

  /// Reset password subtitle
  ///
  /// In en, this message translates to:
  /// **'Enter your email to receive reset instructions'**
  String get auth_reset_password_subtitle;

  /// Send reset link button
  ///
  /// In en, this message translates to:
  /// **'Send Reset Link'**
  String get auth_send_reset_link;

  /// Back to login link
  ///
  /// In en, this message translates to:
  /// **'Back to Login'**
  String get auth_back_to_login;

  /// Reset email sent message
  ///
  /// In en, this message translates to:
  /// **'Password reset email sent'**
  String get auth_reset_email_sent;

  /// Subscriptions label (without "My")
  ///
  /// In en, this message translates to:
  /// **'Subscriptions'**
  String get profile_subscriptions;

  /// Episodes label
  ///
  /// In en, this message translates to:
  /// **'Episodes'**
  String get podcast_episodes;

  /// Unknown author label for podcasts
  ///
  /// In en, this message translates to:
  /// **'Unknown Author'**
  String get podcast_unknown_author;

  /// No subscriptions state
  ///
  /// In en, this message translates to:
  /// **'No subscriptions yet'**
  String get podcast_no_subscriptions;

  /// Play button
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get podcast_play;

  /// Home page title
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// Navigation item: Feed
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get nav_feed;

  /// Navigation item: Podcast
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get nav_podcast;

  /// Navigation item: Profile
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get nav_profile;

  /// Podcast feed page title
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get podcast_feed_page_title;

  /// Add podcast button
  ///
  /// In en, this message translates to:
  /// **'Add Podcast'**
  String get podcast_add_podcast;

  /// Bulk import button
  ///
  /// In en, this message translates to:
  /// **'Bulk Import'**
  String get podcast_bulk_import;

  /// Failed to load feed error message
  ///
  /// In en, this message translates to:
  /// **'Failed to load feed'**
  String get podcast_failed_to_load_feed;

  /// Retry button
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get podcast_retry;

  /// No episodes state
  ///
  /// In en, this message translates to:
  /// **'No episodes found'**
  String get podcast_no_episodes_found;

  /// Podcast daily report card title
  ///
  /// In en, this message translates to:
  /// **'Daily Report'**
  String get podcast_daily_report_title;

  /// Accessible label and tooltip for opening daily report page
  ///
  /// In en, this message translates to:
  /// **'Open daily report'**
  String get podcast_daily_report_open;

  /// Subtitle text for the daily report entry in library feed
  ///
  /// In en, this message translates to:
  /// **'Review history and generate reports by date'**
  String get podcast_daily_report_entry_subtitle;

  /// Success message after generating daily report
  ///
  /// In en, this message translates to:
  /// **'Daily report generated'**
  String get podcast_daily_report_generate_success;

  /// Error message when generating daily report fails
  ///
  /// In en, this message translates to:
  /// **'Failed to generate daily report'**
  String get podcast_daily_report_generate_failed;

  /// Empty state text for daily report card
  ///
  /// In en, this message translates to:
  /// **'No daily report available yet'**
  String get podcast_daily_report_empty;

  /// Loading text for daily report card
  ///
  /// In en, this message translates to:
  /// **'Loading daily report...'**
  String get podcast_daily_report_loading;

  /// Button label for opening daily report date selector
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get podcast_daily_report_dates;

  /// Prefix text for report generation time
  ///
  /// In en, this message translates to:
  /// **'Generated'**
  String get podcast_daily_report_generated_prefix;

  /// Daily report total item count label
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String podcast_daily_report_items(int count);

  /// Share selected text as image action
  ///
  /// In en, this message translates to:
  /// **'Share as Image'**
  String get podcast_share_as_image;

  /// Image save success message
  ///
  /// In en, this message translates to:
  /// **'Image saved successfully'**
  String get podcast_save_image_success;

  /// Image save failed message
  ///
  /// In en, this message translates to:
  /// **'Failed to save image'**
  String get podcast_save_image_failed;

  /// Permission message for saving image
  ///
  /// In en, this message translates to:
  /// **'Photo permission is required to save image'**
  String get podcast_save_image_permission;

  /// Share all content as image action
  ///
  /// In en, this message translates to:
  /// **'Share All'**
  String get podcast_share_all_content;

  /// Selection required message before sharing as image
  ///
  /// In en, this message translates to:
  /// **'Please select content before sharing'**
  String get podcast_share_selection_required;

  /// Platform not supported message for image sharing
  ///
  /// In en, this message translates to:
  /// **'Image sharing is not supported on this platform'**
  String get podcast_share_not_supported;

  /// Share image failed message
  ///
  /// In en, this message translates to:
  /// **'Failed to share image'**
  String get podcast_share_failed;

  /// Progress message while generating share image
  ///
  /// In en, this message translates to:
  /// **'Preparing image...'**
  String get podcast_share_preparing_image;

  /// Message shown when share image generation is already running
  ///
  /// In en, this message translates to:
  /// **'Image generation is in progress'**
  String get podcast_share_in_progress;

  /// Content truncation message for long share text
  ///
  /// In en, this message translates to:
  /// **'Content truncated to first {max} characters'**
  String podcast_share_truncated(int max);

  /// Default podcast name
  ///
  /// In en, this message translates to:
  /// **'Podcast'**
  String get podcast_default_podcast;

  /// Invalid URL validation
  ///
  /// In en, this message translates to:
  /// **'Invalid URL format'**
  String get validation_invalid_url;

  /// Too short validation
  ///
  /// In en, this message translates to:
  /// **'Too short'**
  String get validation_too_short;

  /// Unknown error message
  ///
  /// In en, this message translates to:
  /// **'An unknown error occurred'**
  String get unknown_error;

  /// Forbidden error message
  ///
  /// In en, this message translates to:
  /// **'Access denied'**
  String get forbidden;

  /// Generic success message
  ///
  /// In en, this message translates to:
  /// **'Action completed successfully'**
  String get action_completed;

  /// No data state message
  ///
  /// In en, this message translates to:
  /// **'No data available'**
  String get no_data;

  /// Pull to refresh hint
  ///
  /// In en, this message translates to:
  /// **'Pull to refresh'**
  String get pull_to_refresh;

  /// Refreshing message
  ///
  /// In en, this message translates to:
  /// **'Refreshing...'**
  String get refreshing;

  /// Podcasts page title
  ///
  /// In en, this message translates to:
  /// **'Podcasts'**
  String get podcast_title;

  /// No description label
  ///
  /// In en, this message translates to:
  /// **'No description'**
  String get podcast_description;

  /// Unknown episode title
  ///
  /// In en, this message translates to:
  /// **'Unknown Episode'**
  String get podcast_player_unknown_episode;

  /// No audio link message
  ///
  /// In en, this message translates to:
  /// **'No audio link'**
  String get podcast_player_no_audio;

  /// Coming soon label
  ///
  /// In en, this message translates to:
  /// **'Coming Soon'**
  String get podcast_coming_soon;

  /// Filter all episodes
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get podcast_filter_all;

  /// Filter unplayed episodes
  ///
  /// In en, this message translates to:
  /// **'Unplayed'**
  String get podcast_filter_unplayed;

  /// Filter played episodes
  ///
  /// In en, this message translates to:
  /// **'Played'**
  String get podcast_filter_played;

  /// Summary label
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get podcast_filter_with_summary;

  /// Mark all as played option
  ///
  /// In en, this message translates to:
  /// **'Mark All as Played'**
  String get podcast_mark_all_played;

  /// Mark all as unplayed option
  ///
  /// In en, this message translates to:
  /// **'Mark All as Unplayed'**
  String get podcast_mark_all_unplayed;

  /// No episodes state
  ///
  /// In en, this message translates to:
  /// **'No Episodes Found'**
  String get podcast_no_episodes;

  /// No episodes with summary state
  ///
  /// In en, this message translates to:
  /// **'No Episodes with Summary'**
  String get podcast_no_episodes_with_summary;

  /// Try adjusting filters hint
  ///
  /// In en, this message translates to:
  /// **'Try adjusting your filters'**
  String get podcast_try_adjusting_filters;

  /// No episodes yet message
  ///
  /// In en, this message translates to:
  /// **'This podcast might not have any episodes yet'**
  String get podcast_no_episodes_yet;

  /// Failed to load episodes error
  ///
  /// In en, this message translates to:
  /// **'Failed to Load Episodes'**
  String get podcast_failed_load_episodes;

  /// Filter episodes dialog title
  ///
  /// In en, this message translates to:
  /// **'Filter Episodes'**
  String get podcast_filter_episodes;

  /// Playback status label
  ///
  /// In en, this message translates to:
  /// **'Playback Status:'**
  String get podcast_playback_status;

  /// All episodes filter option
  ///
  /// In en, this message translates to:
  /// **'All Episodes'**
  String get podcast_all_episodes;

  /// Unplayed only filter option
  ///
  /// In en, this message translates to:
  /// **'Unplayed Only'**
  String get podcast_unplayed_only;

  /// Played only filter option
  ///
  /// In en, this message translates to:
  /// **'Played Only'**
  String get podcast_played_only;

  /// Only with summary filter option
  ///
  /// In en, this message translates to:
  /// **'Only episodes with Summary'**
  String get podcast_only_with_summary;

  /// Apply button label
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get podcast_apply;

  /// Add podcast dialog title
  ///
  /// In en, this message translates to:
  /// **'Add Podcast'**
  String get podcast_add_dialog_title;

  /// RSS Feed URL field label
  ///
  /// In en, this message translates to:
  /// **'RSS Feed URL'**
  String get podcast_rss_feed_url;

  /// Feed URL hint
  ///
  /// In en, this message translates to:
  /// **'https://example.com/feed.xml'**
  String get podcast_feed_url_hint;

  /// Enter URL validation
  ///
  /// In en, this message translates to:
  /// **'Please enter a URL'**
  String get podcast_enter_url;

  /// Podcast added success message
  ///
  /// In en, this message translates to:
  /// **'Podcast added successfully!'**
  String get podcast_added_successfully;

  /// Failed to add podcast error
  ///
  /// In en, this message translates to:
  /// **'Failed to add podcast:'**
  String get podcast_failed_add;

  /// Need to add many prompt
  ///
  /// In en, this message translates to:
  /// **'Need to add many?'**
  String get podcast_need_many;

  /// Adding podcast loading text
  ///
  /// In en, this message translates to:
  /// **'Adding...'**
  String get podcast_adding;

  /// Guest user label when not logged in
  ///
  /// In en, this message translates to:
  /// **'Guest User'**
  String get profile_guest_user;

  /// Please log in message
  ///
  /// In en, this message translates to:
  /// **'Please log in'**
  String get profile_please_login;

  /// Account settings section
  ///
  /// In en, this message translates to:
  /// **'Account Settings'**
  String get profile_account_settings;

  /// Edit profile button/title
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get profile_edit_profile;

  /// Security settings
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get profile_security;

  /// Security settings subtitle
  ///
  /// In en, this message translates to:
  /// **'Password, authentication, and privacy'**
  String get profile_security_subtitle;

  /// Notifications settings
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get profile_notifications;

  /// Notifications subtitle
  ///
  /// In en, this message translates to:
  /// **'Push notifications and email alerts'**
  String get profile_notifications_subtitle;

  /// Auto sync toggle
  ///
  /// In en, this message translates to:
  /// **'Auto Sync'**
  String get profile_auto_sync;

  /// Help center title
  ///
  /// In en, this message translates to:
  /// **'Help Center'**
  String get profile_help_center;

  /// Help center subtitle
  ///
  /// In en, this message translates to:
  /// **'Get help and support'**
  String get profile_help_center_subtitle;

  /// Clear cache title
  ///
  /// In en, this message translates to:
  /// **'Clear Cache'**
  String get profile_clear_cache;

  /// Cache management title
  ///
  /// In en, this message translates to:
  /// **'Storage & Cache'**
  String get profile_cache_management;

  /// Cache management subtitle
  ///
  /// In en, this message translates to:
  /// **'View and clear images, audio, and other cached data'**
  String get profile_cache_management_subtitle;

  /// Clear cache confirm message
  ///
  /// In en, this message translates to:
  /// **'This will remove cached images, audio, and API caches. Continue?'**
  String get profile_clear_cache_confirm;

  /// Clearing cache in progress message
  ///
  /// In en, this message translates to:
  /// **'Clearing cache...'**
  String get profile_clearing_cache;

  /// Cache cleared success message
  ///
  /// In en, this message translates to:
  /// **'Cache cleared'**
  String get profile_cache_cleared;

  /// Clear cache failed message
  ///
  /// In en, this message translates to:
  /// **'Failed to clear cache: {error}'**
  String profile_cache_clear_failed(String error);

  /// Cache management page title
  ///
  /// In en, this message translates to:
  /// **'Storage & Cache'**
  String get profile_cache_manage_title;

  /// Cache management total used title
  ///
  /// In en, this message translates to:
  /// **'Total Used'**
  String get profile_cache_manage_total_used;

  /// Cache management images label
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get profile_cache_manage_images;

  /// Cache management audio label
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get profile_cache_manage_audio;

  /// Cache management other label
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get profile_cache_manage_other;

  /// Cache management item count
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String profile_cache_manage_item_count(int count);

  /// Cache management details header
  ///
  /// In en, this message translates to:
  /// **'DETAILS'**
  String get profile_cache_manage_details;

  /// Cache management clean button label
  ///
  /// In en, this message translates to:
  /// **'Clean'**
  String get profile_cache_manage_clean;

  /// Cache management notice text
  ///
  /// In en, this message translates to:
  /// **'Clearing cache will remove downloaded images and temporary files. Your subscriptions and preferences will be kept.'**
  String get profile_cache_manage_notice;

  /// Cache management deep clean all button
  ///
  /// In en, this message translates to:
  /// **'Deep Clean All ({size})'**
  String profile_cache_manage_deep_clean_all(String size);

  /// Cache management delete selected confirm message
  ///
  /// In en, this message translates to:
  /// **'Delete {count} cached items ({size}) from selected categories?'**
  String profile_cache_manage_delete_selected_confirm(int count, String size);

  /// About subtitle
  ///
  /// In en, this message translates to:
  /// **'App version and information'**
  String get profile_about_subtitle;

  /// Name field label
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get profile_name;

  /// Email field label in profile
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get profile_email_field;

  /// Bio field label
  ///
  /// In en, this message translates to:
  /// **'Bio'**
  String get profile_bio;

  /// Profile updated success message
  ///
  /// In en, this message translates to:
  /// **'Profile updated successfully'**
  String get profile_updated_successfully;

  /// Change password option
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get profile_change_password;

  /// Biometric authentication option
  ///
  /// In en, this message translates to:
  /// **'Biometric Authentication'**
  String get profile_biometric_auth;

  /// Two-factor authentication option
  ///
  /// In en, this message translates to:
  /// **'Two-Factor Authentication'**
  String get profile_two_factor_auth;

  /// User guide option
  ///
  /// In en, this message translates to:
  /// **'User Guide'**
  String get profile_user_guide;

  /// User guide subtitle
  ///
  /// In en, this message translates to:
  /// **'Learn how to use the app'**
  String get profile_user_guide_subtitle;

  /// Video tutorials option
  ///
  /// In en, this message translates to:
  /// **'Video Tutorials'**
  String get profile_video_tutorials;

  /// Video tutorials subtitle
  ///
  /// In en, this message translates to:
  /// **'Watch step-by-step guides'**
  String get profile_video_tutorials_subtitle;

  /// Contact support option
  ///
  /// In en, this message translates to:
  /// **'Contact Support'**
  String get profile_contact_support;

  /// Contact support subtitle
  ///
  /// In en, this message translates to:
  /// **'Get help from our team'**
  String get profile_contact_support_subtitle;

  /// Logout dialog title
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get profile_logout_title;

  /// Logout confirmation message
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to logout?'**
  String get profile_logout_message;

  /// Logged out success message
  ///
  /// In en, this message translates to:
  /// **'Logged out successfully'**
  String get profile_logged_out;

  /// Invalid navigation arguments error
  ///
  /// In en, this message translates to:
  /// **'Invalid navigation arguments'**
  String get invalid_navigation_arguments;

  /// Invalid episode ID error
  ///
  /// In en, this message translates to:
  /// **'Invalid episode ID'**
  String get invalid_episode_id;

  /// Backend API server configuration dialog title
  ///
  /// In en, this message translates to:
  /// **'Backend API Server Configuration'**
  String get backend_api_server_config;

  /// Backend API URL label
  ///
  /// In en, this message translates to:
  /// **'Backend API URL'**
  String get backend_api_url_label;

  /// Backend API URL hint text
  ///
  /// In en, this message translates to:
  /// **'https://api.example.com\\nor http://192.168.1.10:8080'**
  String get backend_api_url_hint;

  /// Backend API description
  ///
  /// In en, this message translates to:
  /// **'Note: This is the backend API server, not related to AI model API'**
  String get backend_api_description;

  /// Use local URL button label
  ///
  /// In en, this message translates to:
  /// **'Local Server'**
  String get use_local_url;

  /// Connection error hint text
  ///
  /// In en, this message translates to:
  /// **'Connection error'**
  String get connection_error_hint;

  /// Connection status - not verified yet
  ///
  /// In en, this message translates to:
  /// **'Unverified'**
  String get connection_status_unverified;

  /// Connection status - currently verifying
  ///
  /// In en, this message translates to:
  /// **'Verifying...'**
  String get connection_status_verifying;

  /// Connection status - successful connection
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get connection_status_success;

  /// Connection status - connection failed
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get connection_status_failed;

  /// Server history title
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get server_history_title;

  /// Profile viewed history title
  ///
  /// In en, this message translates to:
  /// **'Viewed'**
  String get profile_viewed_title;

  /// No server history message
  ///
  /// In en, this message translates to:
  /// **'No history'**
  String get server_history_empty;

  /// Save failed error message
  ///
  /// In en, this message translates to:
  /// **'Save failed: {error}'**
  String save_failed(Object error);

  /// Restore defaults success message
  ///
  /// In en, this message translates to:
  /// **'Restored default server address'**
  String get restore_defaults_success;

  /// Server switch confirmation dialog title
  ///
  /// In en, this message translates to:
  /// **'Switch Server'**
  String get profile_server_switch_title;

  /// Server switch confirmation dialog message
  ///
  /// In en, this message translates to:
  /// **'Switching server will clear all local data and require re-login. Continue?'**
  String get profile_server_switch_message;

  /// Server switch success message
  ///
  /// In en, this message translates to:
  /// **'Server switched successfully. Please log in again.'**
  String get profile_server_switch_success;

  /// Loading message while clearing data
  ///
  /// In en, this message translates to:
  /// **'Clearing data...'**
  String get profile_server_switch_clearing;

  /// Drop files hint
  ///
  /// In en, this message translates to:
  /// **'Drop files here!'**
  String get drop_files_here;

  /// Tooltip to enter selection mode
  ///
  /// In en, this message translates to:
  /// **'Select Mode'**
  String get podcast_enter_select_mode;

  /// Deselect all tooltip
  ///
  /// In en, this message translates to:
  /// **'Deselect All'**
  String get podcast_deselect_all;

  /// Selected count label
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String podcast_selected_count(int count);

  /// Check for updates button/label
  ///
  /// In en, this message translates to:
  /// **'Check for Updates'**
  String get update_check_updates;

  /// Auto check for updates description
  ///
  /// In en, this message translates to:
  /// **'Automatically check for updates'**
  String get update_auto_check;

  /// New version available title
  ///
  /// In en, this message translates to:
  /// **'New Version Available'**
  String get update_new_version_available;

  /// Skip this version button label
  ///
  /// In en, this message translates to:
  /// **'Skip This Version'**
  String get update_skip_this_version;

  /// Remind me later button label
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get update_later;

  /// Download update button label
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get update_download;

  /// Latest version label
  ///
  /// In en, this message translates to:
  /// **'Latest Version'**
  String get update_latest_version;

  /// Published date label
  ///
  /// In en, this message translates to:
  /// **'Published'**
  String get update_published_at;

  /// File size label
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get update_file_size;

  /// Release notes section label
  ///
  /// In en, this message translates to:
  /// **'Release Notes'**
  String get update_release_notes;

  /// Download failed error message
  ///
  /// In en, this message translates to:
  /// **'Download failed'**
  String get update_download_failed;

  /// Checking for updates message
  ///
  /// In en, this message translates to:
  /// **'Checking for updates...'**
  String get update_checking;

  /// Update check failed title
  ///
  /// In en, this message translates to:
  /// **'Check Failed'**
  String get update_check_failed;

  /// App is up to date message
  ///
  /// In en, this message translates to:
  /// **'You\'re up to date'**
  String get update_up_to_date;

  /// Try again button label
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get update_try_again;

  /// Message when no download asset is available for the current platform
  ///
  /// In en, this message translates to:
  /// **'No installer available for your platform'**
  String get update_platform_no_asset;

  /// Back button tooltip label
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back_button;

  /// Hint to subscribe to podcasts
  ///
  /// In en, this message translates to:
  /// **'Subscribe to podcasts you\'re interested in!'**
  String get feed_no_subscriptions_hint;

  /// No show notes message
  ///
  /// In en, this message translates to:
  /// **'No show notes available'**
  String get podcast_no_shownotes;

  /// No transcript message
  ///
  /// In en, this message translates to:
  /// **'No transcript available'**
  String get podcast_no_transcript;

  /// Click to transcribe hint
  ///
  /// In en, this message translates to:
  /// **'Click \"Start Transcription\" to generate transcript'**
  String get podcast_click_to_transcribe;

  /// Transcription failed status
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get podcast_transcription_failed;

  /// Date format pattern
  ///
  /// In en, this message translates to:
  /// **'{year}-{month}-{day}'**
  String date_format(int year, String month, String day);

  /// Podcast discover page title
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get podcast_discover_title;

  /// Top charts section title on podcast discover page
  ///
  /// In en, this message translates to:
  /// **'Top Charts'**
  String get podcast_discover_top_charts;

  /// Subtitle showing trending country on podcast discover page
  ///
  /// In en, this message translates to:
  /// **'Trending in {country}'**
  String podcast_discover_trending_in(String country);

  /// See all button text on podcast discover charts
  ///
  /// In en, this message translates to:
  /// **'See All'**
  String get podcast_discover_see_all;

  /// Empty state text when discover charts are unavailable
  ///
  /// In en, this message translates to:
  /// **'No chart data available'**
  String get podcast_discover_no_chart_data;

  /// Category section title on podcast discover page
  ///
  /// In en, this message translates to:
  /// **'Browse by Category'**
  String get podcast_discover_browse_by_category;

  /// Country selector label
  ///
  /// In en, this message translates to:
  /// **'Country/Region'**
  String get podcast_country_label;

  /// No search results message
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get podcast_search_no_results;

  /// Podcasts section title in search results
  ///
  /// In en, this message translates to:
  /// **'Podcasts'**
  String get podcast_search_section_podcasts;

  /// Episodes section title in search results
  ///
  /// In en, this message translates to:
  /// **'Episodes'**
  String get podcast_search_section_episodes;

  /// Subscribe button label
  ///
  /// In en, this message translates to:
  /// **'Subscribe'**
  String get podcast_subscribe;

  /// Subscribed status label
  ///
  /// In en, this message translates to:
  /// **'Subscribed'**
  String get podcast_subscribed;

  /// Subscribe success message
  ///
  /// In en, this message translates to:
  /// **'Subscribed to {podcastName}'**
  String podcast_subscribe_success(String podcastName);

  /// Subscribe failed message
  ///
  /// In en, this message translates to:
  /// **'Failed to subscribe: {error}'**
  String podcast_subscribe_failed(String error);

  /// Country name: China
  ///
  /// In en, this message translates to:
  /// **'China'**
  String get podcast_country_china;

  /// Country name: USA
  ///
  /// In en, this message translates to:
  /// **'USA'**
  String get podcast_country_usa;

  /// Country name: Japan
  ///
  /// In en, this message translates to:
  /// **'Japan'**
  String get podcast_country_japan;

  /// Country name: United Kingdom
  ///
  /// In en, this message translates to:
  /// **'United Kingdom'**
  String get podcast_country_uk;

  /// Country name: Germany
  ///
  /// In en, this message translates to:
  /// **'Germany'**
  String get podcast_country_germany;

  /// Country name: France
  ///
  /// In en, this message translates to:
  /// **'France'**
  String get podcast_country_france;

  /// Country name: Canada
  ///
  /// In en, this message translates to:
  /// **'Canada'**
  String get podcast_country_canada;

  /// Country name: Australia
  ///
  /// In en, this message translates to:
  /// **'Australia'**
  String get podcast_country_australia;

  /// Country name: South Korea
  ///
  /// In en, this message translates to:
  /// **'South Korea'**
  String get podcast_country_korea;

  /// Country name: Taiwan
  ///
  /// In en, this message translates to:
  /// **'Taiwan'**
  String get podcast_country_taiwan;

  /// Country name: Hong Kong
  ///
  /// In en, this message translates to:
  /// **'Hong Kong'**
  String get podcast_country_hong_kong;

  /// Country name: India
  ///
  /// In en, this message translates to:
  /// **'India'**
  String get podcast_country_india;

  /// Country name: Brazil
  ///
  /// In en, this message translates to:
  /// **'Brazil'**
  String get podcast_country_brazil;

  /// Country name: Mexico
  ///
  /// In en, this message translates to:
  /// **'Mexico'**
  String get podcast_country_mexico;

  /// Country name: Spain
  ///
  /// In en, this message translates to:
  /// **'Spain'**
  String get podcast_country_spain;

  /// Country name: Italy
  ///
  /// In en, this message translates to:
  /// **'Italy'**
  String get podcast_country_italy;

  /// Reparse podcast button tooltip
  ///
  /// In en, this message translates to:
  /// **'Reparse podcast (fetch latest episodes and links)'**
  String get podcast_reparse_tooltip;

  /// Reparsing podcast message
  ///
  /// In en, this message translates to:
  /// **'Reparse podcast...'**
  String get podcast_reparsing;

  /// Reparse completed message
  ///
  /// In en, this message translates to:
  /// **'✅ Reparse completed!'**
  String get podcast_reparse_completed;

  /// Reparse failed message
  ///
  /// In en, this message translates to:
  /// **'❌ Reparse failed:'**
  String get podcast_reparse_failed;

  /// Now playing label in floating player
  ///
  /// In en, this message translates to:
  /// **'Now Playing'**
  String get podcast_player_now_playing;

  /// Collapse button tooltip in floating player
  ///
  /// In en, this message translates to:
  /// **'Collapse'**
  String get podcast_player_collapse;

  /// Playlist button tooltip in floating player
  ///
  /// In en, this message translates to:
  /// **'Playlist'**
  String get podcast_player_list;

  /// Sleep mode button tooltip in floating player
  ///
  /// In en, this message translates to:
  /// **'Sleep Mode'**
  String get podcast_player_sleep_mode;

  /// Play button tooltip in floating player
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get podcast_player_play;

  /// Pause button tooltip in floating player
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get podcast_player_pause;

  /// Rewind 10 seconds button tooltip
  ///
  /// In en, this message translates to:
  /// **'Rewind 10s'**
  String get podcast_player_rewind_10;

  /// Forward 30 seconds button tooltip
  ///
  /// In en, this message translates to:
  /// **'Forward 30s'**
  String get podcast_player_forward_30;

  /// Play button label (short version for mobile)
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get podcast_play_episode;

  /// Play button label (full version for desktop)
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get podcast_play_episode_full;

  /// Resume button label for episodes with saved progress
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get podcast_resume_episode;

  /// Current episode is already playing
  ///
  /// In en, this message translates to:
  /// **'Playing'**
  String get podcast_episode_playing;

  /// Source link label
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get podcast_source;

  /// Playback speed selection title
  ///
  /// In en, this message translates to:
  /// **'Playback Speed'**
  String get podcast_speed_title;

  /// Speed selection done button
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get podcast_speed_done;

  /// Episode detail tab: Shownotes
  ///
  /// In en, this message translates to:
  /// **'Shownotes'**
  String get podcast_tab_shownotes;

  /// Episode detail tab: Transcript
  ///
  /// In en, this message translates to:
  /// **'Transcript'**
  String get podcast_tab_transcript;

  /// Episode detail tab: Summary
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get podcast_tab_summary;

  /// Episode detail tab: Chat
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get podcast_tab_chat;

  /// Transcription status: Processing
  ///
  /// In en, this message translates to:
  /// **'Transcription in progress...'**
  String get podcast_transcription_processing;

  /// Transcription auto-starting message
  ///
  /// In en, this message translates to:
  /// **'Auto-starting transcription...'**
  String get podcast_transcription_auto_starting;

  /// Conversation screen title
  ///
  /// In en, this message translates to:
  /// **'Chat with AI'**
  String get podcast_conversation_title;

  /// Empty conversation title
  ///
  /// In en, this message translates to:
  /// **'Start a conversation'**
  String get podcast_conversation_empty_title;

  /// Empty conversation hint
  ///
  /// In en, this message translates to:
  /// **'Ask questions about this episode and get AI-powered answers based on the transcript.'**
  String get podcast_conversation_empty_hint;

  /// Chat history title
  ///
  /// In en, this message translates to:
  /// **'Chat History'**
  String get podcast_conversation_history;

  /// Delete chat dialog title
  ///
  /// In en, this message translates to:
  /// **'Delete Chat'**
  String get podcast_conversation_delete_title;

  /// Delete chat confirmation message
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this chat? This action cannot be undone.'**
  String get podcast_conversation_delete_confirm;

  /// Send message hint text
  ///
  /// In en, this message translates to:
  /// **'Send message (Ctrl+Enter)'**
  String get podcast_conversation_send_hint;

  /// No summary hint for conversation
  ///
  /// In en, this message translates to:
  /// **'Conversation requires a completed transcript. Please wait for transcription to complete.'**
  String get podcast_conversation_no_summary_hint;

  /// Failed to load conversation message
  ///
  /// In en, this message translates to:
  /// **'Failed to load conversation history'**
  String get podcast_conversation_loading_failed;

  /// User label in conversation
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get podcast_conversation_user;

  /// Assistant label in conversation
  ///
  /// In en, this message translates to:
  /// **'AI Assistant'**
  String get podcast_conversation_assistant;

  /// Reload button label
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get podcast_conversation_reload;

  /// New chat button tooltip
  ///
  /// In en, this message translates to:
  /// **'New Chat'**
  String get podcast_conversation_new_chat;

  /// New chat confirmation message
  ///
  /// In en, this message translates to:
  /// **'Starting a new chat will clear the current conversation history. Are you sure?'**
  String get podcast_conversation_new_chat_confirm;

  /// Conversation message count
  ///
  /// In en, this message translates to:
  /// **'{count} messages'**
  String podcast_conversation_message_count(int count);

  /// Generic error loading message
  ///
  /// In en, this message translates to:
  /// **'Failed to load content'**
  String get podcast_error_loading;

  /// Transcription delete button
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get podcast_transcription_delete;

  /// Transcription clear button
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get podcast_transcription_clear;

  /// Episode not found message
  ///
  /// In en, this message translates to:
  /// **'Episode not found'**
  String get podcast_episode_not_found;

  /// Go back button label
  ///
  /// In en, this message translates to:
  /// **'Go back'**
  String get podcast_go_back;

  /// Load failed message
  ///
  /// In en, this message translates to:
  /// **'Failed to load'**
  String get podcast_load_failed;

  /// Summary empty hint
  ///
  /// In en, this message translates to:
  /// **'No summary available'**
  String get podcast_summary_empty_hint;

  /// Please select time validation message
  ///
  /// In en, this message translates to:
  /// **'Please select a time'**
  String get podcast_please_select_time;

  /// Please select time and day validation message
  ///
  /// In en, this message translates to:
  /// **'Please select a time and day'**
  String get podcast_please_select_time_and_day;

  /// Bulk import file error message
  ///
  /// In en, this message translates to:
  /// **'Failed to read file: {error}'**
  String podcast_bulk_import_file_error(String error);

  /// Bulk import input tab label for text input
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get podcast_bulk_import_input_text;

  /// Bulk import input tab label for file upload
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get podcast_bulk_import_input_file;

  /// Bulk import message when no URLs found in text input
  ///
  /// In en, this message translates to:
  /// **'No URLs found in text'**
  String get podcast_bulk_import_no_urls_text;

  /// Bulk import message showing total links found and valid feeds count
  ///
  /// In en, this message translates to:
  /// **'Found {total} links, {valid} valid RSS feeds'**
  String podcast_bulk_import_links_found(int total, int valid);

  /// Bulk import message when all URLs already exist
  ///
  /// In en, this message translates to:
  /// **'All URLs already exist in the list'**
  String get podcast_bulk_import_urls_exist;

  /// Bulk import edit URL dialog title
  ///
  /// In en, this message translates to:
  /// **'Edit RSS URL'**
  String get podcast_bulk_import_edit_url;

  /// Bulk import save and re-validate button text
  ///
  /// In en, this message translates to:
  /// **'Save & Re-validate'**
  String get podcast_bulk_import_save_revalidate;

  /// Bulk import message when no URLs found in file
  ///
  /// In en, this message translates to:
  /// **'No URLs found in file'**
  String get podcast_bulk_import_no_urls_file;

  /// Bulk import message when no valid feeds to import
  ///
  /// In en, this message translates to:
  /// **'No valid RSS feeds to import. Please remove invalid URLs or wait for validation to complete.'**
  String get podcast_bulk_import_no_valid_feeds;

  /// Bulk import success message with count
  ///
  /// In en, this message translates to:
  /// **'Successfully imported {count} RSS feeds'**
  String podcast_bulk_import_imported_count(int count);

  /// Bulk import failed message
  ///
  /// In en, this message translates to:
  /// **'Import failed: {error}'**
  String podcast_bulk_import_failed(String error);

  /// Bulk import valid count label
  ///
  /// In en, this message translates to:
  /// **'Valid ({count})'**
  String podcast_bulk_import_valid_count(int count);

  /// Bulk import invalid count label
  ///
  /// In en, this message translates to:
  /// **'Invalid ({count})'**
  String podcast_bulk_import_invalid_count(int count);

  /// Default title when podcast title is unknown
  ///
  /// In en, this message translates to:
  /// **'Unknown Title'**
  String get podcast_unknown_title;

  /// Copy button tooltip
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get podcast_copy;

  /// Edit and retry button tooltip
  ///
  /// In en, this message translates to:
  /// **'Edit & Retry'**
  String get podcast_edit_retry;

  /// Remove button tooltip
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get podcast_remove;

  /// Bulk import drag and drop instruction
  ///
  /// In en, this message translates to:
  /// **'Drag & Drop files here or'**
  String get podcast_bulk_import_drag_drop;

  /// Bulk import select file button text
  ///
  /// In en, this message translates to:
  /// **'Select File'**
  String get podcast_bulk_import_select_file;

  /// RSS list heading
  ///
  /// In en, this message translates to:
  /// **'RSS List'**
  String get podcast_rss_list;

  /// Import all button text
  ///
  /// In en, this message translates to:
  /// **'Import All'**
  String get podcast_import_all;

  /// No items message
  ///
  /// In en, this message translates to:
  /// **'No items'**
  String get podcast_no_items;

  /// Bulk import extract button text
  ///
  /// In en, this message translates to:
  /// **'Extract'**
  String get podcast_bulk_import_extract;

  /// Bulk import click to select file text
  ///
  /// In en, this message translates to:
  /// **'Click to Select File'**
  String get podcast_bulk_import_click_select;

  /// Bulk import or drag drop text
  ///
  /// In en, this message translates to:
  /// **'or drag & drop here'**
  String get podcast_bulk_import_or_drag_drop;

  /// Bulk import paste text area hint
  ///
  /// In en, this message translates to:
  /// **'Paste URLs or OPML content here...'**
  String get podcast_bulk_import_paste_hint;

  /// Not a valid RSS feed error message
  ///
  /// In en, this message translates to:
  /// **'Not a valid RSS feed'**
  String get podcast_not_valid_rss;

  /// Copied to clipboard message
  ///
  /// In en, this message translates to:
  /// **'Copied: {text}'**
  String podcast_copied(String text);

  /// URL hint text in text field
  ///
  /// In en, this message translates to:
  /// **'URL'**
  String get podcast_bulk_import_hint_text;

  /// Global RSS settings page title
  ///
  /// In en, this message translates to:
  /// **'Global RSS Settings'**
  String get podcast_global_rss_settings_title;

  /// Updated subscriptions message with count
  ///
  /// In en, this message translates to:
  /// **'Updated {count} subscriptions'**
  String podcast_updated_subscriptions(int count);

  /// Summary generation failed message
  ///
  /// In en, this message translates to:
  /// **'Failed to generate summary'**
  String get podcast_summary_generate_failed;

  /// No summary available message
  ///
  /// In en, this message translates to:
  /// **'No summary available'**
  String get podcast_summary_no_summary;

  /// Generate AI summary button
  ///
  /// In en, this message translates to:
  /// **'Generate Summary'**
  String get podcast_summary_generate;

  /// Message when transcription is required
  ///
  /// In en, this message translates to:
  /// **'Transcription required to generate AI summary'**
  String get podcast_summary_transcription_required;

  /// Advanced options button
  ///
  /// In en, this message translates to:
  /// **'Advanced Options'**
  String get podcast_advanced_options;

  /// Regenerate summary button
  ///
  /// In en, this message translates to:
  /// **'Regenerate'**
  String get podcast_regenerate;

  /// Model selector label
  ///
  /// In en, this message translates to:
  /// **'AI Model'**
  String get podcast_ai_model;

  /// Default model badge
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get podcast_default_model;

  /// Prompt input field label
  ///
  /// In en, this message translates to:
  /// **'Custom Prompt (Optional)'**
  String get podcast_custom_prompt;

  /// Prompt input placeholder
  ///
  /// In en, this message translates to:
  /// **'e.g., Focus on technical points...'**
  String get podcast_custom_prompt_hint;

  /// Loading text for summary generation
  ///
  /// In en, this message translates to:
  /// **'Generating AI summary...'**
  String get podcast_generating_summary;

  /// Word count unit
  ///
  /// In en, this message translates to:
  /// **'chars'**
  String get podcast_summary_chars;

  /// Theme mode setting label
  ///
  /// In en, this message translates to:
  /// **'Theme Mode'**
  String get theme_mode;

  /// Theme mode subtitle
  ///
  /// In en, this message translates to:
  /// **'Choose your preferred theme'**
  String get theme_mode_subtitle;

  /// Option to follow system theme
  ///
  /// In en, this message translates to:
  /// **'Follow System'**
  String get theme_mode_follow_system;

  /// Light theme option
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get theme_mode_light;

  /// Dark theme option
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get theme_mode_dark;

  /// Theme mode selection dialog title
  ///
  /// In en, this message translates to:
  /// **'Select Theme Mode'**
  String get theme_mode_select_title;

  /// Theme mode changed success message
  ///
  /// In en, this message translates to:
  /// **'Theme mode changed to {mode}'**
  String theme_mode_changed(String mode);

  /// Search hint text for transcript content
  ///
  /// In en, this message translates to:
  /// **'Search transcript content...'**
  String get podcast_transcript_search_hint;

  /// No matching content found message
  ///
  /// In en, this message translates to:
  /// **'No matching content found'**
  String get podcast_transcript_no_match;

  /// Match number label for search results
  ///
  /// In en, this message translates to:
  /// **'Match {index}'**
  String podcast_transcript_match(int index);

  /// Title for start transcription state
  ///
  /// In en, this message translates to:
  /// **'Start Transcription'**
  String get transcription_start_title;

  /// Description for start transcription state
  ///
  /// In en, this message translates to:
  /// **'Generate full text transcription for this episode\nSupports multi-language and high accuracy'**
  String get transcription_start_desc;

  /// Button text to start transcription
  ///
  /// In en, this message translates to:
  /// **'Start Transcription'**
  String get transcription_start_button;

  /// Hint about auto-transcription setting
  ///
  /// In en, this message translates to:
  /// **'Or enable auto-transcription in settings'**
  String get transcription_auto_hint;

  /// Snackbar text when starting transcription
  ///
  /// In en, this message translates to:
  /// **'Starting transcription...'**
  String get transcription_starting;

  /// Success snackbar text
  ///
  /// In en, this message translates to:
  /// **'✓ Transcription started successfully'**
  String get transcription_started_success;

  /// Failed to start transcription snackbar
  ///
  /// In en, this message translates to:
  /// **'✗ Failed to start: {error}'**
  String transcription_start_failed(String error);

  /// Title for pending transcription state
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get transcription_pending_title;

  /// Description for pending transcription state
  ///
  /// In en, this message translates to:
  /// **'Transcription task has been queued\nProcessing will start shortly'**
  String get transcription_pending_desc;

  /// Label below percentage in progress ring
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get transcription_progress_complete;

  /// Duration label in processing state
  ///
  /// In en, this message translates to:
  /// **'Duration: {duration}'**
  String transcription_duration_label(String duration);

  /// Word count label in processing state
  ///
  /// In en, this message translates to:
  /// **'~{count}K words'**
  String transcription_words_label(String count);

  /// Step label for download
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get transcription_step_download;

  /// Step label for convert
  ///
  /// In en, this message translates to:
  /// **'Convert'**
  String get transcription_step_convert;

  /// Step label for split
  ///
  /// In en, this message translates to:
  /// **'Split'**
  String get transcription_step_split;

  /// Step label for transcribe
  ///
  /// In en, this message translates to:
  /// **'Transcribe'**
  String get transcription_step_transcribe;

  /// Step label for merge
  ///
  /// In en, this message translates to:
  /// **'Merge'**
  String get transcription_step_merge;

  /// Title for completed transcription state
  ///
  /// In en, this message translates to:
  /// **'Transcription Complete'**
  String get transcription_complete_title;

  /// Description for completed transcription state
  ///
  /// In en, this message translates to:
  /// **'Transcript generated successfully\nYou can now read and search the content'**
  String get transcription_complete_desc;

  /// Stat label for word count
  ///
  /// In en, this message translates to:
  /// **'Words'**
  String get transcription_stat_words;

  /// Stat label for duration
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get transcription_stat_duration;

  /// Stat label for accuracy
  ///
  /// In en, this message translates to:
  /// **'Accuracy'**
  String get transcription_stat_accuracy;

  /// Completed time label
  ///
  /// In en, this message translates to:
  /// **'Completed at: {time}'**
  String transcription_completed_at(String time);

  /// Button to view transcript
  ///
  /// In en, this message translates to:
  /// **'View Transcript'**
  String get transcription_view_button;

  /// Title for failed transcription state
  ///
  /// In en, this message translates to:
  /// **'Transcription Failed'**
  String get transcription_failed_title;

  /// Default error message
  ///
  /// In en, this message translates to:
  /// **'Unknown error'**
  String get transcription_unknown_error;

  /// Expandable section for error details
  ///
  /// In en, this message translates to:
  /// **'Technical Details'**
  String get transcription_technical_details;

  /// Button to retry transcription
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get transcription_retry_button;

  /// Error text when transcription is already running
  ///
  /// In en, this message translates to:
  /// **'Transcription already in progress'**
  String get transcription_error_already_progress;

  /// Network error message
  ///
  /// In en, this message translates to:
  /// **'Network connection failed'**
  String get transcription_error_network;

  /// Audio download error
  ///
  /// In en, this message translates to:
  /// **'Failed to download audio'**
  String get transcription_error_audio_download;

  /// Service error
  ///
  /// In en, this message translates to:
  /// **'Transcription service error'**
  String get transcription_error_service;

  /// Format conversion error
  ///
  /// In en, this message translates to:
  /// **'Audio format conversion failed'**
  String get transcription_error_format;

  /// Server restart error
  ///
  /// In en, this message translates to:
  /// **'Service was restarted'**
  String get transcription_error_server_restart;

  /// Generic transcription failure
  ///
  /// In en, this message translates to:
  /// **'Transcription failed'**
  String get transcription_error_generic;

  /// Network error suggestion
  ///
  /// In en, this message translates to:
  /// **'Check your internet connection and try again'**
  String get transcription_suggest_network;

  /// Audio error suggestion
  ///
  /// In en, this message translates to:
  /// **'The audio file may be unavailable. Try again later'**
  String get transcription_suggest_audio;

  /// Service error suggestion
  ///
  /// In en, this message translates to:
  /// **'The transcription service may be busy. Retry in a moment'**
  String get transcription_suggest_service;

  /// Format error suggestion
  ///
  /// In en, this message translates to:
  /// **'The audio format may not be supported. Try a different episode'**
  String get transcription_suggest_format;

  /// Server restart suggestion
  ///
  /// In en, this message translates to:
  /// **'Click Retry to start a new transcription task'**
  String get transcription_suggest_restart;

  /// Generic error suggestion
  ///
  /// In en, this message translates to:
  /// **'Try clicking Retry to start over'**
  String get transcription_suggest_generic;

  /// Title for playback speed section
  ///
  /// In en, this message translates to:
  /// **'Playback Speed'**
  String get player_playback_speed_title;

  /// Checkbox label for subscription-specific speed
  ///
  /// In en, this message translates to:
  /// **'Apply to current subscription only'**
  String get player_apply_subscription_only;

  /// Subtitle for subscription checkbox
  ///
  /// In en, this message translates to:
  /// **'Checked: current subscription only; Unchecked: global default'**
  String get player_apply_subscription_subtitle;

  /// Title for sleep timer section
  ///
  /// In en, this message translates to:
  /// **'Sleep Timer'**
  String get player_sleep_timer_title;

  /// Description for sleep timer
  ///
  /// In en, this message translates to:
  /// **'Playback will automatically pause after the set time'**
  String get player_sleep_timer_desc;

  /// Option to stop playback after current episode
  ///
  /// In en, this message translates to:
  /// **'Stop after this episode'**
  String get player_stop_after_episode;

  /// Button to cancel sleep timer
  ///
  /// In en, this message translates to:
  /// **'Cancel timer'**
  String get player_cancel_timer;

  /// Duration in minutes
  ///
  /// In en, this message translates to:
  /// **'{count} min'**
  String player_minutes(int count);

  /// Duration in hours and minutes
  ///
  /// In en, this message translates to:
  /// **'{hours}h {minutes}min'**
  String player_hours_minutes(int hours, int minutes);

  /// Duration in hours only
  ///
  /// In en, this message translates to:
  /// **'{count}h'**
  String player_hours(int count);

  /// Error title when loading fails
  ///
  /// In en, this message translates to:
  /// **'Failed to load'**
  String get global_rss_failed_load;

  /// Retry button text
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get global_rss_retry;

  /// Section title showing affected subscriptions count
  ///
  /// In en, this message translates to:
  /// **'Affected Subscriptions ({count})'**
  String global_rss_affected_count(int count);

  /// Empty state text
  ///
  /// In en, this message translates to:
  /// **'No RSS subscriptions'**
  String get global_rss_no_subscriptions;

  /// Card title for global RSS schedule
  ///
  /// In en, this message translates to:
  /// **'Update Schedule for All RSS Subscriptions'**
  String get global_rss_schedule_title;

  /// Description of global apply scope
  ///
  /// In en, this message translates to:
  /// **'This will apply to all {count} subscriptions'**
  String global_rss_apply_desc(int count);

  /// Label for frequency selector
  ///
  /// In en, this message translates to:
  /// **'Update Frequency'**
  String get global_rss_update_frequency;

  /// Hourly frequency option
  ///
  /// In en, this message translates to:
  /// **'Hourly'**
  String get global_rss_hourly;

  /// Daily frequency option
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get global_rss_daily;

  /// Weekly frequency option
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get global_rss_weekly;

  /// Label for time picker
  ///
  /// In en, this message translates to:
  /// **'Update Time'**
  String get global_rss_update_time;

  /// Hint text for time picker
  ///
  /// In en, this message translates to:
  /// **'Select time'**
  String get global_rss_select_time;

  /// Button text for time picker
  ///
  /// In en, this message translates to:
  /// **'Select Time'**
  String get global_rss_select_time_button;

  /// Label for day of week selector
  ///
  /// In en, this message translates to:
  /// **'Day of Week'**
  String get global_rss_day_of_week;

  /// Button text when applying
  ///
  /// In en, this message translates to:
  /// **'Applying...'**
  String get global_rss_applying;

  /// Button text to apply to all
  ///
  /// In en, this message translates to:
  /// **'Apply to All Subscriptions'**
  String get global_rss_apply_all;

  /// Error message when update fails
  ///
  /// In en, this message translates to:
  /// **'Failed to update subscriptions'**
  String get global_rss_failed_update;

  /// Page not found error title
  ///
  /// In en, this message translates to:
  /// **'Page Not Found'**
  String get page_not_found;

  /// Page not found error message
  ///
  /// In en, this message translates to:
  /// **'Please select a valid tab from the navigation'**
  String get page_not_found_subtitle;

  /// Generic error message prefix
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String error_prefix(String error);

  /// Message shown when downloading update in background
  ///
  /// In en, this message translates to:
  /// **'Downloading in background...'**
  String get downloading_in_background;

  /// Version label with placeholder
  ///
  /// In en, this message translates to:
  /// **'Version: {version}'**
  String version_label(String version);

  /// Build label with placeholder
  ///
  /// In en, this message translates to:
  /// **'Build: {build}'**
  String build_label(String build);

  /// Message shown when item is added to queue
  ///
  /// In en, this message translates to:
  /// **'Added to queue'**
  String get added_to_queue;

  /// Error message when failing to add to queue
  ///
  /// In en, this message translates to:
  /// **'Failed to add to queue: {error}'**
  String failed_to_add_to_queue(String error);

  /// Error message when failing to open link
  ///
  /// In en, this message translates to:
  /// **'Error opening link: {error}'**
  String error_opening_link(String error);

  /// Message shown when queue is empty
  ///
  /// In en, this message translates to:
  /// **'Queue is empty'**
  String get queue_is_empty;

  /// Title for the playback queue sheet
  ///
  /// In en, this message translates to:
  /// **'Up Next'**
  String get queue_up_next;

  /// Label for the current playing section in the queue sheet
  ///
  /// In en, this message translates to:
  /// **'Now playing'**
  String get queue_now_playing;

  /// Suffix label for queue item count
  ///
  /// In en, this message translates to:
  /// **'in queue'**
  String get queue_in_queue;

  /// Label before remaining queue duration
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get queue_remaining_label;

  /// Status label when the queue is syncing
  ///
  /// In en, this message translates to:
  /// **'Syncing queue'**
  String get queue_syncing;

  /// Status label when queue reorder is being saved
  ///
  /// In en, this message translates to:
  /// **'Saving order'**
  String get queue_saving_order;

  /// Status label when queue content is being updated
  ///
  /// In en, this message translates to:
  /// **'Updating queue'**
  String get queue_updating;

  /// Separator between podcast title and playback progress in queue items
  ///
  /// In en, this message translates to:
  /// **' • '**
  String get queue_subtitle_separator;

  /// Error message when failing to load queue
  ///
  /// In en, this message translates to:
  /// **'Failed to load queue: {error}'**
  String failed_to_load_queue(String error);

  /// Error message when failing to reorder queue
  ///
  /// In en, this message translates to:
  /// **'Failed to reorder queue: {error}'**
  String failed_to_reorder_queue(String error);

  /// Error message when failing to play item
  ///
  /// In en, this message translates to:
  /// **'Failed to play item: {error}'**
  String failed_to_play_item(String error);

  /// Error message when failing to remove item
  ///
  /// In en, this message translates to:
  /// **'Failed to remove item: {error}'**
  String failed_to_remove_item(String error);

  /// Generic apply button label
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply_button;

  /// Authentication verification page title
  ///
  /// In en, this message translates to:
  /// **'Auth Verification'**
  String get auth_verification_title;

  /// Password requirement: at least one uppercase letter
  ///
  /// In en, this message translates to:
  /// **'Contain at least one uppercase letter'**
  String get auth_password_requirement_uppercase;

  /// Password requirement: at least one lowercase letter
  ///
  /// In en, this message translates to:
  /// **'Contain at least one lowercase letter'**
  String get auth_password_requirement_lowercase;

  /// Password requirement: at least one number
  ///
  /// In en, this message translates to:
  /// **'Contain at least one number'**
  String get auth_password_requirement_number;

  /// Password requirement short: uppercase letter
  ///
  /// In en, this message translates to:
  /// **'At least one uppercase letter (A-Z)'**
  String get auth_password_req_uppercase_short;

  /// Password requirement short: lowercase letter
  ///
  /// In en, this message translates to:
  /// **'At least one lowercase letter (a-z)'**
  String get auth_password_req_lowercase_short;

  /// Password requirement short: number
  ///
  /// In en, this message translates to:
  /// **'At least one number (0-9)'**
  String get auth_password_req_number_short;

  /// Password requirement: minimum 8 characters
  ///
  /// In en, this message translates to:
  /// **'Be at least 8 characters'**
  String get auth_password_requirement_min_length;

  /// Password requirements section title
  ///
  /// In en, this message translates to:
  /// **'Password must:'**
  String get auth_password_requirements_title;

  /// Terms and conditions link text
  ///
  /// In en, this message translates to:
  /// **'Terms and Conditions'**
  String get auth_terms_and_conditions;

  /// Privacy policy link text
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get auth_privacy_policy;

  /// Set new password page title
  ///
  /// In en, this message translates to:
  /// **'Set New Password'**
  String get auth_set_new_password;

  /// New password field label
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get auth_new_password;

  /// Add episode to queue button
  ///
  /// In en, this message translates to:
  /// **'Add to queue'**
  String get podcast_add_to_queue;

  /// Fallback episode title when name is empty
  ///
  /// In en, this message translates to:
  /// **'Unknown Episode'**
  String get episode_unknown_title;

  /// Transcription status: waiting to start
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get transcription_status_pending;

  /// Transcription status: downloading audio file
  ///
  /// In en, this message translates to:
  /// **'Downloading audio...'**
  String get transcription_status_downloading;

  /// Transcription status: converting audio format
  ///
  /// In en, this message translates to:
  /// **'Converting format...'**
  String get transcription_status_converting;

  /// Transcription status: processing audio
  ///
  /// In en, this message translates to:
  /// **'Transcribing...'**
  String get transcription_status_transcribing;

  /// Transcription status: processing transcript text
  ///
  /// In en, this message translates to:
  /// **'Processing text...'**
  String get transcription_status_processing;

  /// Transcription status: successfully completed
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get transcription_status_completed;

  /// Transcription status: failed
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get transcription_status_failed;

  /// AI Summary section in profile
  ///
  /// In en, this message translates to:
  /// **'AI Summary'**
  String get profile_ai_summary;

  /// Support section in profile
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get profile_support_section;

  /// Conjunction 'and' for linking terms
  ///
  /// In en, this message translates to:
  /// **' and '**
  String get auth_and;

  /// Tooltip for collapsing the desktop sidebar
  ///
  /// In en, this message translates to:
  /// **'Collapse Menu'**
  String get sidebarCollapseMenu;

  /// Tooltip for expanding the desktop sidebar
  ///
  /// In en, this message translates to:
  /// **'Expand Menu'**
  String get sidebarExpandMenu;

  /// App title shown in the desktop sidebar header
  ///
  /// In en, this message translates to:
  /// **'AI Assistant'**
  String get sidebarAppTitle;

  /// Highlights feature title
  ///
  /// In en, this message translates to:
  /// **'Highlights'**
  String get podcast_highlights_title;

  /// Highlights loading message
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get podcast_highlights_loading;

  /// Highlights empty state message
  ///
  /// In en, this message translates to:
  /// **'No highlights yet'**
  String get podcast_highlights_empty;

  /// Highlights count label
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 highlight} other{{count} highlights}}'**
  String podcast_highlights_items(int count);

  /// Highlight insight label
  ///
  /// In en, this message translates to:
  /// **'Insight'**
  String get podcast_highlights_insight;

  /// Highlight novelty label
  ///
  /// In en, this message translates to:
  /// **'Novelty'**
  String get podcast_highlights_novelty;

  /// Highlight actionability label
  ///
  /// In en, this message translates to:
  /// **'Actionability'**
  String get podcast_highlights_actionability;

  /// Favorite highlight button
  ///
  /// In en, this message translates to:
  /// **'Favorite'**
  String get podcast_highlights_favorite;

  /// Unfavorite highlight button
  ///
  /// In en, this message translates to:
  /// **'Unfavorite'**
  String get podcast_highlights_unfavorite;

  /// Highlights date selector title
  ///
  /// In en, this message translates to:
  /// **'Select Date'**
  String get podcast_highlights_dates;

  /// No description provided for @podcast_highlights_generated_prefix.
  ///
  /// In en, this message translates to:
  /// **'Generated at'**
  String get podcast_highlights_generated_prefix;

  /// No description provided for @podcast_highlights_original_quote.
  ///
  /// In en, this message translates to:
  /// **'Original Quote'**
  String get podcast_highlights_original_quote;

  /// No description provided for @podcast_highlights_load_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load'**
  String get podcast_highlights_load_failed;

  /// No description provided for @podcast_highlights_cannot_load.
  ///
  /// In en, this message translates to:
  /// **'Cannot load highlights'**
  String get podcast_highlights_cannot_load;

  /// No description provided for @podcast_highlights_retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get podcast_highlights_retry;

  /// No description provided for @podcast_highlights_no_highs.
  ///
  /// In en, this message translates to:
  /// **'No highlights'**
  String get podcast_highlights_no_highs;

  /// No description provided for @podcast_highlights_loading_highlights.
  ///
  /// In en, this message translates to:
  /// **'Loading highlights...'**
  String get podcast_highlights_loading_highlights;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
