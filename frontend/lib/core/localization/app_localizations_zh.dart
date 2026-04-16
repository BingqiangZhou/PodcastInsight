// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Stella';

  @override
  String get appSlogan => '你关注的一切，交给我。';

  @override
  String get settings => '设置';

  @override
  String get language => '语言';

  @override
  String get languageFollowSystem => '跟随系统';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageChinese => '简体中文';

  @override
  String get about => '关于';

  @override
  String get version => '版本';

  @override
  String get profile => '个人资料';

  @override
  String get preferences => '偏好设置';

  @override
  String get logout => '退出登录';

  @override
  String get cancel => '取消';

  @override
  String get clear => '清空';

  @override
  String get confirm => '确认';

  @override
  String get save => '保存';

  @override
  String get delete => '删除';

  @override
  String get edit => '编辑';

  @override
  String get add => '添加';

  @override
  String get update => '更新';

  @override
  String get search => '搜索';

  @override
  String get filter => '筛选';

  @override
  String get refresh => '刷新';

  @override
  String get loading => '加载中...';

  @override
  String get error => '错误';

  @override
  String get success => '成功';

  @override
  String get retry => '重试';

  @override
  String get close => '关闭';

  @override
  String get ok => '确定';

  @override
  String get no => '否';

  @override
  String get auth_welcome_back => '天快亮了，我们开始吧。';

  @override
  String get auth_sign_in_subtitle => '登录以继续';

  @override
  String get auth_enter_email => '请输入您的邮箱';

  @override
  String get auth_enter_valid_email => '请输入有效的邮箱地址';

  @override
  String get auth_enter_password => '请输入您的密码';

  @override
  String get auth_password_too_short => '密码至少需要8个字符';

  @override
  String get auth_email => '邮箱';

  @override
  String get auth_password => '密码';

  @override
  String get auth_remember_me => '记住我';

  @override
  String get auth_forgot_password => '忘记密码？';

  @override
  String get auth_login => '登录';

  @override
  String get auth_no_account => '还没有账号？';

  @override
  String get auth_sign_up => '注册';

  @override
  String get auth_create_account => '创建账号';

  @override
  String get auth_sign_up_subtitle => '加入我们开始使用';

  @override
  String get auth_full_name => '姓名';

  @override
  String get auth_enter_name => '请输入您的姓名';

  @override
  String get auth_confirm_password => '确认密码';

  @override
  String get auth_passwords_not_match => '两次输入的密码不一致';

  @override
  String get auth_agree_terms => '我同意条款和条件';

  @override
  String get auth_already_have_account => '已有账号？';

  @override
  String get auth_sign_in_link => '登录';

  @override
  String get auth_reset_password => '重置密码';

  @override
  String get auth_reset_password_subtitle => '输入您的邮箱以接收重置说明';

  @override
  String get auth_send_reset_link => '发送重置链接';

  @override
  String get auth_back_to_login => '返回登录';

  @override
  String get auth_reset_email_sent => '密码重置邮件已发送';

  @override
  String get profile_subscriptions => '订阅';

  @override
  String get podcast_episodes => '单集';

  @override
  String get podcast_unknown_author => '未知作者';

  @override
  String get podcast_no_subscriptions => '还没有订阅';

  @override
  String get podcast_play => '播放';

  @override
  String get home => '首页';

  @override
  String get nav_feed => '资料库';

  @override
  String get nav_podcast => '发现';

  @override
  String get nav_profile => '个人资料';

  @override
  String get podcast_feed_page_title => '资料库';

  @override
  String get podcast_add_podcast => '添加播客';

  @override
  String get podcast_bulk_import => '批量导入';

  @override
  String get podcast_failed_to_load_feed => '加载信息流失败';

  @override
  String get podcast_retry => '重试';

  @override
  String get podcast_no_episodes_found => '未找到剧集';

  @override
  String get podcast_daily_report_title => '日报';

  @override
  String get podcast_daily_report_open => '打开日报';

  @override
  String get podcast_daily_report_entry_subtitle => '查看历史并按日期生成日报';

  @override
  String get podcast_daily_report_generate_success => '日报已生成';

  @override
  String get podcast_daily_report_generate_failed => '生成日报失败';

  @override
  String get podcast_daily_report_empty => '暂无可用日报';

  @override
  String get podcast_daily_report_loading => '正在加载日报...';

  @override
  String get podcast_daily_report_dates => '历史日期';

  @override
  String get podcast_daily_report_generated_prefix => '生成于';

  @override
  String podcast_daily_report_items(int count) {
    return '$count条';
  }

  @override
  String get podcast_share_as_image => '分享为图片';

  @override
  String get podcast_save_image_success => '图片已保存';

  @override
  String get podcast_save_image_failed => '保存图片失败';

  @override
  String get podcast_save_image_permission => '需要照片权限才能保存图片';

  @override
  String get podcast_share_all_content => '分享全部';

  @override
  String get podcast_share_selection_required => '请先选择要分享的内容';

  @override
  String get podcast_share_not_supported => '当前平台暂不支持图片分享';

  @override
  String get podcast_share_failed => '图片分享失败';

  @override
  String get podcast_share_preparing_image => '正在生成图片...';

  @override
  String get podcast_share_in_progress => '图片正在生成中，请稍候';

  @override
  String podcast_share_truncated(int max) {
    return '内容已截断为前 $max 个字符';
  }

  @override
  String get podcast_default_podcast => '播客';

  @override
  String get validation_invalid_url => '无效的 URL 格式';

  @override
  String get validation_too_short => '太短';

  @override
  String get unknown_error => '发生未知错误';

  @override
  String get forbidden => '访问被拒绝';

  @override
  String get action_completed => '操作成功完成';

  @override
  String get no_data => '没有可用数据';

  @override
  String get pull_to_refresh => '下拉刷新';

  @override
  String get refreshing => '刷新中...';

  @override
  String get podcast_title => '播客';

  @override
  String get podcast_description => '无描述';

  @override
  String get podcast_player_unknown_episode => '未知剧集';

  @override
  String get podcast_player_no_audio => '无音频链接';

  @override
  String get podcast_coming_soon => '即将推出';

  @override
  String get podcast_filter_all => '全部';

  @override
  String get podcast_filter_unplayed => '未播放';

  @override
  String get podcast_filter_played => '已播放';

  @override
  String get podcast_filter_with_summary => '摘要';

  @override
  String get podcast_mark_all_played => '全部标记为已播放';

  @override
  String get podcast_mark_all_unplayed => '全部标记为未播放';

  @override
  String get podcast_no_episodes => '未找到剧集';

  @override
  String get podcast_no_episodes_with_summary => '没有带摘要的剧集';

  @override
  String get podcast_try_adjusting_filters => '尝试调整您的筛选条件';

  @override
  String get podcast_no_episodes_yet => '该播客可能还没有任何剧集';

  @override
  String get podcast_failed_load_episodes => '加载剧集失败';

  @override
  String get podcast_filter_episodes => '筛选剧集';

  @override
  String get podcast_playback_status => '播放状态：';

  @override
  String get podcast_all_episodes => '全部剧集';

  @override
  String get podcast_unplayed_only => '仅未播放';

  @override
  String get podcast_played_only => '仅已播放';

  @override
  String get podcast_only_with_summary => '仅显示有摘要的剧集';

  @override
  String get podcast_apply => '应用';

  @override
  String get podcast_add_dialog_title => '添加播客';

  @override
  String get podcast_rss_feed_url => 'RSS 订阅源 URL';

  @override
  String get podcast_feed_url_hint => 'https://example.com/feed.xml';

  @override
  String get podcast_enter_url => '请输入 URL';

  @override
  String get podcast_added_successfully => '播客添加成功！';

  @override
  String get podcast_failed_add => '添加播客失败：';

  @override
  String get podcast_need_many => '需要添加多个？';

  @override
  String get podcast_adding => '添加中...';

  @override
  String get profile_guest_user => '访客用户';

  @override
  String get profile_please_login => '请先登录';

  @override
  String get profile_account_settings => '账号设置';

  @override
  String get profile_edit_profile => '编辑个人资料';

  @override
  String get profile_security => '安全设置';

  @override
  String get profile_security_subtitle => '密码、身份验证和隐私';

  @override
  String get profile_notifications => '通知设置';

  @override
  String get profile_notifications_subtitle => '推送通知和邮件提醒';

  @override
  String get profile_auto_sync => '自动同步';

  @override
  String get profile_help_center => '帮助中心';

  @override
  String get profile_help_center_subtitle => '获取帮助和支持';

  @override
  String get profile_clear_cache => '清理缓存';

  @override
  String get profile_cache_management => '缓存管理';

  @override
  String get profile_cache_management_subtitle => '查看并清理图片、音频等缓存数据';

  @override
  String get profile_clear_cache_confirm => '将清理图片、音频以及接口缓存，是否继续？';

  @override
  String get profile_clearing_cache => '正在清理缓存…';

  @override
  String get profile_cache_cleared => '缓存已清理';

  @override
  String profile_cache_clear_failed(String error) {
    return '清理缓存失败：$error';
  }

  @override
  String get profile_cache_manage_title => '存储与缓存';

  @override
  String get profile_cache_manage_total_used => '已使用';

  @override
  String get profile_cache_manage_images => '图片';

  @override
  String get profile_cache_manage_audio => '音频';

  @override
  String get profile_cache_manage_other => '其他';

  @override
  String profile_cache_manage_item_count(int count) {
    return '$count 项';
  }

  @override
  String get profile_cache_manage_details => '详情';

  @override
  String get profile_cache_manage_clean => '清理';

  @override
  String get profile_cache_manage_notice => '清理缓存会删除已下载的图片和临时文件。你的订阅和偏好设置会保留。';

  @override
  String profile_cache_manage_deep_clean_all(String size) {
    return '一键深度清理（$size）';
  }

  @override
  String profile_cache_manage_delete_selected_confirm(int count, String size) {
    return '确定删除所选分类中的 $count 项缓存（$size）吗？';
  }

  @override
  String get profile_about_subtitle => '应用版本和信息';

  @override
  String get profile_name => '姓名';

  @override
  String get profile_email_field => '邮箱';

  @override
  String get profile_bio => '个人简介';

  @override
  String get profile_updated_successfully => '个人资料更新成功';

  @override
  String get profile_change_password => '修改密码';

  @override
  String get profile_biometric_auth => '生物识别认证';

  @override
  String get profile_two_factor_auth => '双因素认证';

  @override
  String get profile_user_guide => '用户指南';

  @override
  String get profile_user_guide_subtitle => '了解如何使用应用';

  @override
  String get profile_video_tutorials => '视频教程';

  @override
  String get profile_video_tutorials_subtitle => '观看分步指南';

  @override
  String get profile_contact_support => '联系客服';

  @override
  String get profile_contact_support_subtitle => '获取我们团队的帮助';

  @override
  String get profile_logout_title => '退出登录';

  @override
  String get profile_logout_message => '确定要退出登录吗？';

  @override
  String get profile_logged_out => '已成功退出登录';

  @override
  String get invalid_navigation_arguments => '导航参数无效';

  @override
  String get invalid_episode_id => '剧集ID无效';

  @override
  String get backend_api_server_config => '后端 API 服务器配置';

  @override
  String get backend_api_url_label => '后端 API URL';

  @override
  String get backend_api_url_hint =>
      'https://api.example.com\\n或 http://192.168.1.10:8080';

  @override
  String get backend_api_description => '说明：此为后端 API 服务器，与 AI 模型 API 无关';

  @override
  String get use_local_url => '本地服务器';

  @override
  String get connection_error_hint => '连接错误';

  @override
  String get connection_status_unverified => '未验证';

  @override
  String get connection_status_verifying => '验证中...';

  @override
  String get connection_status_success => '成功';

  @override
  String get connection_status_failed => '失败';

  @override
  String get server_history_title => '历史记录';

  @override
  String get profile_viewed_title => '查看历史';

  @override
  String get server_history_empty => '暂无历史记录';

  @override
  String save_failed(Object error) {
    return '保存失败: $error';
  }

  @override
  String get restore_defaults_success => '已恢复默认服务器地址';

  @override
  String get profile_server_switch_title => '切换服务器';

  @override
  String get profile_server_switch_message => '切换服务器将清除所有本地数据，您需要重新登录。是否继续？';

  @override
  String get profile_server_switch_success => '服务器切换成功，请重新登录';

  @override
  String get profile_server_switch_clearing => '正在清理数据...';

  @override
  String get drop_files_here => '拖放文件到这里！';

  @override
  String get podcast_enter_select_mode => '选择模式';

  @override
  String get podcast_deselect_all => '取消全选';

  @override
  String podcast_selected_count(int count) {
    return '已选择 $count 个';
  }

  @override
  String get update_check_updates => '检查更新';

  @override
  String get update_auto_check => '自动检查更新';

  @override
  String get update_new_version_available => '发现新版本';

  @override
  String get update_skip_this_version => '跳过此版本';

  @override
  String get update_later => '稍后提醒';

  @override
  String get update_download => '下载';

  @override
  String get update_latest_version => '最新版本';

  @override
  String get update_published_at => '发布时间';

  @override
  String get update_file_size => '大小';

  @override
  String get update_release_notes => '更新说明';

  @override
  String get update_download_failed => '下载失败';

  @override
  String get update_checking => '正在检查更新...';

  @override
  String get update_check_failed => '检查失败';

  @override
  String get update_up_to_date => '已是最新版本';

  @override
  String get update_try_again => '重试';

  @override
  String get update_platform_no_asset => '当前平台暂无可用安装包';

  @override
  String get back_button => '返回';

  @override
  String get feed_no_subscriptions_hint => '去订阅一些你感兴趣的播客吧！';

  @override
  String get podcast_no_shownotes => '暂无节目简介';

  @override
  String get podcast_no_transcript => '暂无转录内容';

  @override
  String get podcast_click_to_transcribe => '点击\\\"开始转录\\\"按钮生成转录文本';

  @override
  String get podcast_transcription_failed => '转录失败';

  @override
  String date_format(int year, String month, String day) {
    return '$year年$month月$day日';
  }

  @override
  String get podcast_discover_title => '发现';

  @override
  String get podcast_discover_top_charts => '热门榜单';

  @override
  String podcast_discover_trending_in(String country) {
    return '$country 热门';
  }

  @override
  String get podcast_discover_see_all => '查看全部';

  @override
  String get podcast_discover_no_chart_data => '暂无榜单数据';

  @override
  String get podcast_discover_browse_by_category => '按分类浏览';

  @override
  String get podcast_country_label => '国家或地区';

  @override
  String get podcast_search_no_results => '未找到结果';

  @override
  String get podcast_search_section_podcasts => '播客';

  @override
  String get podcast_search_section_episodes => '分集';

  @override
  String get podcast_subscribe => '订阅';

  @override
  String get podcast_subscribed => '已订阅';

  @override
  String podcast_subscribe_success(String podcastName) {
    return '已订阅 $podcastName';
  }

  @override
  String podcast_subscribe_failed(String error) {
    return '订阅失败：$error';
  }

  @override
  String get podcast_country_china => '中国';

  @override
  String get podcast_country_usa => '美国';

  @override
  String get podcast_country_japan => '日本';

  @override
  String get podcast_country_uk => '英国';

  @override
  String get podcast_country_germany => '德国';

  @override
  String get podcast_country_france => '法国';

  @override
  String get podcast_country_canada => '加拿大';

  @override
  String get podcast_country_australia => '澳大利亚';

  @override
  String get podcast_country_korea => '韩国';

  @override
  String get podcast_country_taiwan => '台湾';

  @override
  String get podcast_country_hong_kong => '香港';

  @override
  String get podcast_country_india => '印度';

  @override
  String get podcast_country_brazil => '巴西';

  @override
  String get podcast_country_mexico => '墨西哥';

  @override
  String get podcast_country_spain => '西班牙';

  @override
  String get podcast_country_italy => '意大利';

  @override
  String get podcast_reparse_tooltip => '重新解析播客（获取最新分集和链接）';

  @override
  String get podcast_reparsing => '正在重新解析播客...';

  @override
  String get podcast_reparse_completed => '✅ 重新解析完成！';

  @override
  String get podcast_reparse_failed => '❌ 重新解析失败：';

  @override
  String get podcast_player_now_playing => '正在播放';

  @override
  String get podcast_player_collapse => '收起';

  @override
  String get podcast_player_list => '播放列表';

  @override
  String get podcast_player_sleep_mode => '睡眠模式';

  @override
  String get podcast_player_play => '播放';

  @override
  String get podcast_player_pause => '暂停';

  @override
  String get podcast_player_rewind_10 => '后退10秒';

  @override
  String get podcast_player_forward_30 => '前进30秒';

  @override
  String get podcast_play_episode => '播放';

  @override
  String get podcast_play_episode_full => '播放';

  @override
  String get podcast_resume_episode => '继续播放';

  @override
  String get podcast_episode_playing => '正在播放';

  @override
  String get podcast_source => '来源';

  @override
  String get podcast_speed_title => '倍速播放';

  @override
  String get podcast_speed_done => '完成';

  @override
  String get podcast_tab_shownotes => '节目详情';

  @override
  String get podcast_tab_transcript => '文字稿';

  @override
  String get podcast_tab_summary => '摘要';

  @override
  String get podcast_tab_chat => 'AI对话';

  @override
  String get podcast_transcription_processing => '正在转录中...';

  @override
  String get podcast_transcription_auto_starting => '自动开始转录...';

  @override
  String get podcast_conversation_title => 'AI对话';

  @override
  String get podcast_conversation_empty_title => '开始对话';

  @override
  String get podcast_conversation_empty_hint => '向AI提问本集节目的相关问题，基于文字稿获取智能回答。';

  @override
  String get podcast_conversation_history => '对话历史';

  @override
  String get podcast_conversation_delete_title => '删除对话';

  @override
  String get podcast_conversation_delete_confirm => '确定要删除这个对话吗？此操作无法撤销。';

  @override
  String get podcast_conversation_send_hint => '发送消息（Ctrl+Enter）';

  @override
  String get podcast_conversation_no_summary_hint => '对话功能需要先完成转录。请等待转录完成。';

  @override
  String get podcast_conversation_loading_failed => '加载对话历史失败';

  @override
  String get podcast_conversation_user => '你';

  @override
  String get podcast_conversation_assistant => 'AI助手';

  @override
  String get podcast_conversation_reload => '重新加载';

  @override
  String get podcast_conversation_new_chat => '新对话';

  @override
  String get podcast_conversation_new_chat_confirm => '确定要开始新的对话吗？当前的对话将会被清除。';

  @override
  String podcast_conversation_message_count(int count) {
    return '$count条消息';
  }

  @override
  String get podcast_error_loading => '加载内容失败';

  @override
  String get podcast_transcription_delete => '删除';

  @override
  String get podcast_transcription_clear => '清空';

  @override
  String get podcast_episode_not_found => '未找到分集';

  @override
  String get podcast_go_back => '返回';

  @override
  String get podcast_load_failed => '加载失败';

  @override
  String get podcast_summary_empty_hint => '暂无摘要';

  @override
  String get podcast_please_select_time => '请选择时间';

  @override
  String get podcast_please_select_time_and_day => '请选择时间和星期';

  @override
  String podcast_bulk_import_file_error(String error) {
    return '读取文件失败：$error';
  }

  @override
  String get podcast_bulk_import_input_text => '文本';

  @override
  String get podcast_bulk_import_input_file => '文件';

  @override
  String get podcast_bulk_import_no_urls_text => '未找到URL';

  @override
  String podcast_bulk_import_links_found(int total, int valid) {
    return '找到$total个链接，$valid个有效RSS订阅';
  }

  @override
  String get podcast_bulk_import_urls_exist => '所有URL已存在于列表中';

  @override
  String get podcast_bulk_import_edit_url => '编辑RSS URL';

  @override
  String get podcast_bulk_import_save_revalidate => '保存并重新验证';

  @override
  String get podcast_bulk_import_no_urls_file => '文件中未找到URL';

  @override
  String get podcast_bulk_import_no_valid_feeds =>
      '没有有效的RSS订阅可导入。请移除无效URL或等待验证完成。';

  @override
  String podcast_bulk_import_imported_count(int count) {
    return '成功导入$count个RSS订阅';
  }

  @override
  String podcast_bulk_import_failed(String error) {
    return '导入失败：$error';
  }

  @override
  String podcast_bulk_import_valid_count(int count) {
    return '有效 ($count)';
  }

  @override
  String podcast_bulk_import_invalid_count(int count) {
    return '无效 ($count)';
  }

  @override
  String get podcast_unknown_title => '未知标题';

  @override
  String get podcast_copy => '复制';

  @override
  String get podcast_edit_retry => '编辑重试';

  @override
  String get podcast_remove => '移除';

  @override
  String get podcast_bulk_import_drag_drop => '拖放文件到此处或';

  @override
  String get podcast_bulk_import_select_file => '选择文件';

  @override
  String get podcast_rss_list => 'RSS列表';

  @override
  String get podcast_import_all => '全部导入';

  @override
  String get podcast_no_items => '无项目';

  @override
  String get podcast_bulk_import_extract => '提取';

  @override
  String get podcast_bulk_import_click_select => '点击选择文件';

  @override
  String get podcast_bulk_import_or_drag_drop => '或拖放到此处';

  @override
  String get podcast_bulk_import_paste_hint => '在此粘贴URL或OPML内容...';

  @override
  String get podcast_not_valid_rss => '不是有效的RSS订阅';

  @override
  String podcast_copied(String text) {
    return '已复制：$text';
  }

  @override
  String get podcast_bulk_import_hint_text => 'URL';

  @override
  String get podcast_global_rss_settings_title => '全局RSS设置';

  @override
  String podcast_updated_subscriptions(int count) {
    return '已更新$count个订阅';
  }

  @override
  String get podcast_summary_generate_failed => '生成摘要失败';

  @override
  String get podcast_summary_no_summary => '暂无摘要';

  @override
  String get podcast_summary_generate => '生成摘要';

  @override
  String get podcast_summary_transcription_required => '需要转录才能生成AI摘要';

  @override
  String get podcast_advanced_options => '高级选项';

  @override
  String get podcast_regenerate => '重新生成';

  @override
  String get podcast_ai_model => 'AI模型';

  @override
  String get podcast_default_model => '默认';

  @override
  String get podcast_custom_prompt => '自定义提示词（可选）';

  @override
  String get podcast_custom_prompt_hint => '例如：重点关注技术要点...';

  @override
  String get podcast_generating_summary => '正在生成AI摘要...';

  @override
  String get podcast_summary_chars => '字符';

  @override
  String get theme_mode => '主题模式';

  @override
  String get theme_mode_subtitle => '选择您偏好的主题';

  @override
  String get theme_mode_follow_system => '跟随系统';

  @override
  String get theme_mode_light => '浅色';

  @override
  String get theme_mode_dark => '深色';

  @override
  String get theme_mode_select_title => '选择主题模式';

  @override
  String theme_mode_changed(String mode) {
    return '主题模式已更改为 $mode';
  }

  @override
  String get podcast_transcript_search_hint => '搜索转录内容...';

  @override
  String get podcast_transcript_no_match => '未找到匹配内容';

  @override
  String podcast_transcript_match(int index) {
    return '第 $index 个匹配';
  }

  @override
  String get transcription_start_title => '开始转录';

  @override
  String get transcription_start_desc => '为本集生成完整文字转录\n支持多语言和高精度';

  @override
  String get transcription_start_button => '开始转录';

  @override
  String get transcription_auto_hint => '或在设置中启用自动转录';

  @override
  String get transcription_starting => '正在启动转录...';

  @override
  String get transcription_started_success => '✓ 转录已成功启动';

  @override
  String transcription_start_failed(String error) {
    return '✗ 启动失败：$error';
  }

  @override
  String get transcription_pending_title => '等待中';

  @override
  String get transcription_pending_desc => '转录任务已加入队列\n即将开始处理';

  @override
  String get transcription_progress_complete => '完成';

  @override
  String transcription_duration_label(String duration) {
    return '时长：$duration';
  }

  @override
  String transcription_words_label(String count) {
    return '约${count}K字';
  }

  @override
  String get transcription_step_download => '下载';

  @override
  String get transcription_step_convert => '转换';

  @override
  String get transcription_step_split => '分割';

  @override
  String get transcription_step_transcribe => '转录';

  @override
  String get transcription_step_merge => '合并';

  @override
  String get transcription_complete_title => '转录完成';

  @override
  String get transcription_complete_desc => '转录文本已成功生成\n您现在可以阅读和搜索内容';

  @override
  String get transcription_stat_words => '字数';

  @override
  String get transcription_stat_duration => '时长';

  @override
  String get transcription_stat_accuracy => '准确率';

  @override
  String transcription_completed_at(String time) {
    return '完成时间：$time';
  }

  @override
  String get transcription_view_button => '查看转录';

  @override
  String get transcription_failed_title => '转录失败';

  @override
  String get transcription_unknown_error => '未知错误';

  @override
  String get transcription_technical_details => '技术详情';

  @override
  String get transcription_retry_button => '重试';

  @override
  String get transcription_error_already_progress => '转录正在进行中';

  @override
  String get transcription_error_network => '网络连接失败';

  @override
  String get transcription_error_audio_download => '音频下载失败';

  @override
  String get transcription_error_service => '转录服务错误';

  @override
  String get transcription_error_format => '音频格式转换失败';

  @override
  String get transcription_error_server_restart => '服务已重启';

  @override
  String get transcription_error_generic => '转录失败';

  @override
  String get transcription_suggest_network => '请检查您的网络连接后重试';

  @override
  String get transcription_suggest_audio => '音频文件可能暂时不可用，请稍后重试';

  @override
  String get transcription_suggest_service => '转录服务可能正忙，请稍后重试';

  @override
  String get transcription_suggest_format => '该音频格式可能不支持，请尝试其他集数';

  @override
  String get transcription_suggest_restart => '点击重试以启动新的转录任务';

  @override
  String get transcription_suggest_generic => '请尝试点击重试重新开始';

  @override
  String get player_playback_speed_title => '播放倍速';

  @override
  String get player_apply_subscription_only => '仅应用于当前订阅';

  @override
  String get player_apply_subscription_subtitle => '选中：仅当前订阅；未选中：全局默认';

  @override
  String get player_sleep_timer_title => '睡眠定时';

  @override
  String get player_sleep_timer_desc => '设置定时后，播放将在指定时间自动暂停';

  @override
  String get player_stop_after_episode => '播放完本集后停止';

  @override
  String get player_cancel_timer => '取消定时';

  @override
  String player_minutes(int count) {
    return '$count分钟';
  }

  @override
  String player_hours_minutes(int hours, int minutes) {
    return '$hours小时$minutes分钟';
  }

  @override
  String player_hours(int count) {
    return '$count小时';
  }

  @override
  String get global_rss_failed_load => '加载失败';

  @override
  String get global_rss_retry => '重试';

  @override
  String global_rss_affected_count(int count) {
    return '受影响的订阅 ($count)';
  }

  @override
  String get global_rss_no_subscriptions => '暂无RSS订阅';

  @override
  String get global_rss_schedule_title => '所有RSS订阅的更新计划';

  @override
  String global_rss_apply_desc(int count) {
    return '这将应用于所有 $count 个订阅';
  }

  @override
  String get global_rss_update_frequency => '更新频率';

  @override
  String get global_rss_hourly => '每小时';

  @override
  String get global_rss_daily => '每天';

  @override
  String get global_rss_weekly => '每周';

  @override
  String get global_rss_update_time => '更新时间';

  @override
  String get global_rss_select_time => '选择时间';

  @override
  String get global_rss_select_time_button => '选择时间';

  @override
  String get global_rss_day_of_week => '星期';

  @override
  String get global_rss_applying => '正在应用...';

  @override
  String get global_rss_apply_all => '应用到所有订阅';

  @override
  String get global_rss_failed_update => '更新订阅失败';

  @override
  String get page_not_found => '页面未找到';

  @override
  String get page_not_found_subtitle => '请从导航中选择有效的标签页';

  @override
  String error_prefix(String error) {
    return '错误：$error';
  }

  @override
  String get downloading_in_background => '正在后台下载...';

  @override
  String version_label(String version) {
    return '版本：$version';
  }

  @override
  String build_label(String build) {
    return '构建：$build';
  }

  @override
  String get added_to_queue => '已添加到播放队列';

  @override
  String failed_to_add_to_queue(String error) {
    return '添加到队列失败：$error';
  }

  @override
  String error_opening_link(String error) {
    return '打开链接时出错：$error';
  }

  @override
  String get queue_is_empty => '播放队列为空';

  @override
  String get queue_up_next => '接下来';

  @override
  String get queue_now_playing => '正在播放';

  @override
  String get queue_in_queue => '待播';

  @override
  String get queue_remaining_label => '剩余';

  @override
  String get queue_syncing => '正在同步队列';

  @override
  String get queue_saving_order => '正在保存顺序';

  @override
  String get queue_updating => '正在更新队列';

  @override
  String get queue_subtitle_separator => ' · ';

  @override
  String failed_to_load_queue(String error) {
    return '加载队列失败：$error';
  }

  @override
  String failed_to_reorder_queue(String error) {
    return '重新排序队列失败：$error';
  }

  @override
  String failed_to_play_item(String error) {
    return '播放项目失败：$error';
  }

  @override
  String failed_to_remove_item(String error) {
    return '移除项目失败：$error';
  }

  @override
  String get apply_button => '应用';

  @override
  String get auth_verification_title => '身份验证';

  @override
  String get auth_password_requirement_uppercase => '至少包含一个大写字母';

  @override
  String get auth_password_requirement_lowercase => '至少包含一个小写字母';

  @override
  String get auth_password_requirement_number => '至少包含一个数字';

  @override
  String get auth_password_req_uppercase_short => '至少一个大写字母（A-Z）';

  @override
  String get auth_password_req_lowercase_short => '至少一个小写字母（a-z）';

  @override
  String get auth_password_req_number_short => '至少一个数字（0-9）';

  @override
  String get auth_password_requirement_min_length => '至少8个字符';

  @override
  String get auth_password_requirements_title => '密码必须满足：';

  @override
  String get auth_terms_and_conditions => '条款和条件';

  @override
  String get auth_privacy_policy => '隐私政策';

  @override
  String get auth_set_new_password => '设置新密码';

  @override
  String get auth_new_password => '新密码';

  @override
  String get podcast_add_to_queue => '添加到播放队列';

  @override
  String get episode_unknown_title => '未知集数';

  @override
  String get transcription_status_pending => '等待开始';

  @override
  String get transcription_status_downloading => '下载音频中...';

  @override
  String get transcription_status_converting => '转换格式中...';

  @override
  String get transcription_status_transcribing => '转录中...';

  @override
  String get transcription_status_processing => '处理文本中...';

  @override
  String get transcription_status_completed => '转录完成';

  @override
  String get transcription_status_failed => '转录失败';

  @override
  String get profile_ai_summary => 'AI 总结';

  @override
  String get profile_support_section => '支持';

  @override
  String get auth_and => ' 和 ';

  @override
  String get sidebarCollapseMenu => '收起菜单';

  @override
  String get sidebarExpandMenu => '展开菜单';

  @override
  String get sidebarAppTitle => 'AI 助手';

  @override
  String get podcast_highlights_title => '高光观点';

  @override
  String get podcast_highlights_loading => '加载中...';

  @override
  String get podcast_highlights_empty => '暂无高光观点';

  @override
  String podcast_highlights_items(int count) {
    return '$count 条高光';
  }

  @override
  String get podcast_highlights_insight => '洞察力';

  @override
  String get podcast_highlights_novelty => '新颖性';

  @override
  String get podcast_highlights_actionability => '可操作性';

  @override
  String get podcast_highlights_favorite => '收藏';

  @override
  String get podcast_highlights_unfavorite => '取消收藏';

  @override
  String get podcast_highlights_dates => '选择日期';

  @override
  String get podcast_highlights_generated_prefix => '生成于';

  @override
  String get podcast_highlights_original_quote => '原文引用';

  @override
  String get podcast_highlights_load_failed => '加载失败';

  @override
  String get podcast_highlights_cannot_load => '无法加载高光观点';

  @override
  String get podcast_highlights_retry => '重试';

  @override
  String get podcast_highlights_no_highs => '暂无高光';

  @override
  String get podcast_highlights_loading_highlights => '正在加载高光观点';

  @override
  String get podcast_highlights_favorited => '已收藏';

  @override
  String podcast_highlights_overall_score(double score) {
    return '评分: $score';
  }

  @override
  String get podcast_highlights_topic_tags => '主题标签';

  @override
  String podcast_highlights_multiple_count(int count) {
    return '$count 条高光';
  }

  @override
  String get podcast_highlights_extract_hint => '从转录文本中提取关键观点';

  @override
  String get podcast_highlights_extract_action => '提取';

  @override
  String get podcast_highlights_extract_queued => '高光提取已开始，请几分钟后刷新查看';

  @override
  String get podcast_highlights_extract_failed => '启动高光提取失败';

  @override
  String get podcast_transcript_view_full => '全文';

  @override
  String get podcast_transcript_view_highlights => '高亮';

  @override
  String get podcast_highlights_empty_title => '暂无高亮';

  @override
  String get podcast_highlights_empty_subtitle => '从本期播客中提取关键见解';

  @override
  String get auth_brand_name => '个人 AI 工作空间';

  @override
  String get auth_agree_prefix => '我同意 ';

  @override
  String auth_reset_email_sent_to(String email) {
    return '密码重置链接已发送至\n$email';
  }

  @override
  String get auth_check_email_fallback => '请检查您的邮箱并点击链接重置密码';

  @override
  String get auth_resend_email => '没有收到邮件？重新发送';

  @override
  String get auth_invalid_reset_link => '重置链接无效，请重新申请密码重置。';

  @override
  String get auth_password_reset_success => '密码重置成功，您现在可以使用新密码登录。';

  @override
  String get auth_new_password_instruction => '新密码必须与之前使用过的密码不同';

  @override
  String get podcast_report_label => '举报';

  @override
  String get podcast_queue_loading_title => '加载中';

  @override
  String get podcast_queue_loading_subtitle => '请稍候...';

  @override
  String get profile_subscriptions_subtitle => '已订阅的播客';

  @override
  String profile_subscriptions_count(int count) {
    return '$count 个订阅';
  }

  @override
  String podcast_episode_number(int number) {
    return '第 $number 集';
  }

  @override
  String get podcast_summary_task_added => '总结已进入任务列表';

  @override
  String connection_error_prefix(String error) {
    return '连接错误: $error';
  }

  @override
  String get error_occurred => '出了点问题';

  @override
  String get error_network_timeout => '连接超时，请重试。';

  @override
  String get error_network_no_connection => '无网络连接，请检查网络后重试。';

  @override
  String get error_network_generic => '网络异常，请重试。';

  @override
  String get error_server => '服务器错误，请稍后重试。';

  @override
  String get error_auth => '会话已过期，请重新登录。';

  @override
  String get error_forbidden => '无权访问此内容。';

  @override
  String get error_not_found => '未找到请求的内容。';

  @override
  String get error_validation => '输入无效，请检查后重试。';

  @override
  String get session_create_failed => '创建新对话失败';

  @override
  String get session_delete_failed => '删除对话失败';

  @override
  String get download_button_download => '下载';

  @override
  String get download_button_downloading => '下载中';

  @override
  String get download_button_downloaded => '已下载';

  @override
  String get download_button_failed => '下载失败';

  @override
  String get download_button_cancel => '取消下载';

  @override
  String get download_button_delete => '删除下载';

  @override
  String get download_button_retry => '重新下载';

  @override
  String get profile_downloads => '下载管理';

  @override
  String get profile_downloads_subtitle => '管理已下载的剧集';

  @override
  String get downloads_page_title => '下载管理';

  @override
  String get downloads_empty => '暂无下载';

  @override
  String get downloads_empty_subtitle => '下载的剧集将显示在这里';

  @override
  String get downloads_delete_all => '全部删除';

  @override
  String get downloads_delete_confirm => '删除全部下载？';

  @override
  String get downloads_delete_confirm_message => '将移除所有已下载的音频文件，此操作不可撤销。';

  @override
  String get downloads_active_title => '正在下载';

  @override
  String get downloads_completed_title => '已下载';

  @override
  String downloads_items(int count) {
    return '$count 个下载';
  }

  @override
  String get appearance_title => '外观';

  @override
  String get appearance_theme_section => '主题模式';

  @override
  String get appearance_font_section => '字体';

  @override
  String get appearance_font_section_subtitle => '为应用选择字体组合';

  @override
  String get appearance_font_reset => '恢复默认';

  @override
  String get appearance_changed => '外观已更新';

  @override
  String appearance_subtitle(String theme, String font) {
    return '$theme · $font';
  }

  @override
  String get player_expand_player => '展开播放器';

  @override
  String get unknown_podcast => '未知播客';

  @override
  String get sleep_timer_after_episode => '当前剧集结束后';

  @override
  String get onboarding_welcome_title => '欢迎使用 Stella';

  @override
  String get onboarding_welcome_subtitle => '你的 AI 智能播客助手';

  @override
  String get onboarding_welcome_body => '发现、订阅并收听你喜爱的播客——由智能 AI 驱动，让你随时掌握最新动态。';

  @override
  String get onboarding_summary_title => '每日 AI 摘要';

  @override
  String get onboarding_summary_body =>
      '获取个性化的每日播客摘要和剧集要点。几分钟内了解最新动态，无需花数小时收听。';

  @override
  String get onboarding_chat_title => 'AI 对话';

  @override
  String get onboarding_chat_body =>
      '与 AI 聊天讨论任何播客剧集。提出问题、深入探索话题，从你的收听库中获取即时洞察。';

  @override
  String get onboarding_skip => '跳过';

  @override
  String get onboarding_next => '下一步';

  @override
  String get onboarding_get_started => '开始使用';

  @override
  String get terms_of_service_title => '服务条款';

  @override
  String get terms_of_service_last_updated => '最后更新：2026年4月4日';

  @override
  String get terms_section_acceptance => '1. 接受条款';

  @override
  String get terms_section_acceptance_body =>
      '访问和使用 Stella（\"本服务\"）即表示您同意受本服务条款的约束。如果您不同意这些条款，请勿使用本服务。';

  @override
  String get terms_section_use => '2. 服务使用';

  @override
  String get terms_section_use_body =>
      '您可以将本服务用于个人非商业目的。您同意不滥用本服务，包括但不限于试图获取未经授权的访问、干扰其运行，或以任何违反适用法律的方式使用。';

  @override
  String get terms_section_ip => '3. 知识产权';

  @override
  String get terms_section_ip_body =>
      '本服务的所有内容、功能和特性，包括但不限于文本、图形、标识和软件，均为 Stella 的财产，受版权、商标和其他知识产权法的保护。播客内容属于其各自的创作者。';

  @override
  String get terms_section_liability => '4. 责任限制';

  @override
  String get terms_section_liability_body =>
      '本服务按\"原样\"提供，不附带任何形式的保证。我们不对因您使用本服务而产生的任何间接、附带、特殊、后果性或惩罚性损害承担责任。';

  @override
  String get terms_section_changes => '5. 条款变更';

  @override
  String get terms_section_changes_body =>
      '我们保留随时修改这些条款的权利。我们将通知用户重大变更。您在变更后继续使用本服务即表示接受更新后的条款。';

  @override
  String get terms_section_governing_law => '6. 适用法律';

  @override
  String get terms_section_governing_law_body =>
      '本条款应受本服务运营所在司法管辖区的法律管辖并据其解释，不考虑其法律冲突条款。';

  @override
  String get terms_section_contact => '7. 联系我们';

  @override
  String get terms_section_contact_body => '如果您对本服务条款有任何疑问，请通过应用的支持部分与我们联系。';

  @override
  String get privacy_policy_title => '隐私政策';

  @override
  String get privacy_policy_last_updated => '最后更新：2026年4月4日';

  @override
  String get privacy_section_intro => '1. 简介';

  @override
  String get privacy_section_intro_body =>
      'Stella（\"我们\"）致力于保护您的隐私。本隐私政策说明了我们在您使用本服务时如何收集、使用和保护您的个人信息。';

  @override
  String get privacy_section_collection => '2. 我们收集的信息';

  @override
  String get privacy_section_collection_body =>
      '我们收集您直接提供的信息，例如创建账户时的电子邮件地址和显示名称。我们还收集使用数据，包括播客订阅、播放历史和偏好设置，以改善您的使用体验。';

  @override
  String get privacy_section_usage => '3. 我们如何使用您的信息';

  @override
  String get privacy_section_usage_body =>
      '我们使用您的信息来提供和改善服务、处理您的请求、发送有关订阅的通知，以及生成个性化内容，如 AI 摘要和每日报告。';

  @override
  String get privacy_section_storage => '4. 数据存储和安全';

  @override
  String get privacy_section_storage_body =>
      '您的数据使用行业标准加密安全地存储在我们的服务器上。我们实施适当的技术和组织措施来保护您的个人信息免受未经授权的访问或披露。';

  @override
  String get privacy_section_sharing => '5. 信息共享';

  @override
  String get privacy_section_sharing_body =>
      '未经您的同意，我们不会出售、交易或以其他方式将您的个人信息转移给第三方，法律要求或协助运营本服务的受信合作伙伴除外。';

  @override
  String get privacy_section_rights => '6. 您的权利';

  @override
  String get privacy_section_rights_body =>
      '您有权随时通过应用的个人资料设置访问、更新或删除您的个人信息。您也可以请求数据副本或关闭您的账户。';

  @override
  String get privacy_section_children => '7. 儿童隐私';

  @override
  String get privacy_section_children_body =>
      '本服务不面向13岁以下儿童。我们不会故意收集儿童的个人信息。如果您认为我们收集了儿童的信息，请立即与我们联系。';

  @override
  String get privacy_section_changes => '8. 政策变更';

  @override
  String get privacy_section_changes_body =>
      '我们可能会不时更新本隐私政策。我们将通过在此页面上发布新政策并更新\"最后更新\"日期来通知您任何变更。';

  @override
  String get privacy_section_contact => '9. 联系我们';

  @override
  String get privacy_section_contact_body => '如果您对本隐私政策有任何疑问，请通过应用的支持部分与我们联系。';

  @override
  String get profile_history_subtitle => '继续收听并回顾最近播放的内容。';

  @override
  String profile_history_episode_count(int count) {
    return '$count 条最近播放记录';
  }

  @override
  String get profile_terms_of_service => '服务条款';

  @override
  String get profile_terms_subtitle => '查看我们的服务条款';

  @override
  String get profile_privacy_policy => '隐私政策';

  @override
  String get profile_privacy_subtitle => '查看我们的隐私政策';

  @override
  String get profile_coming_soon => '即将推出';

  @override
  String get profile_edit_coming_soon_subtitle => '个人资料编辑功能将在未来版本中提供。';

  @override
  String get profile_password_change_title => '修改密码';

  @override
  String get profile_current_password => '当前密码';

  @override
  String get profile_new_password => '新密码';

  @override
  String get profile_confirm_new_password => '确认新密码';

  @override
  String get profile_password_required => '请输入密码';

  @override
  String get profile_password_min_length => '密码至少需要8个字符';

  @override
  String get profile_password_mismatch => '两次输入的密码不一致';

  @override
  String get profile_password_same_as_old => '新密码不能与当前密码相同';

  @override
  String get profile_password_changing => '正在修改密码...';

  @override
  String get profile_password_reset_email_sent => '密码重置链接已发送到您的邮箱，请查收。';

  @override
  String get profile_password_change_failed => '修改密码失败，请重试。';

  @override
  String get profile_two_factor_coming_soon => '双因素认证将在未来版本中提供。';

  @override
  String get profile_biometric_coming_soon => '生物识别认证将在未来版本中提供。';

  @override
  String get profile_send_reset_link => '发送重置链接';

  @override
  String get profile_biometric_not_available => '暂不可用';

  @override
  String get nav_ai => 'AI';

  @override
  String get ai_tab_eyebrow => 'AI 助手';

  @override
  String get ai_tab_subtitle => '日报、 高光观点和更多';

  @override
  String get ai_tab_daily_report_subtitle => '查看你的个性化每日摘要';

  @override
  String get ai_tab_highlights_subtitle => '从收听历史中获取关键见解';

  @override
  String get ai_tab_chat_title => 'AI 助手';

  @override
  String get ai_tab_chat_subtitle => '与 AI 聊聊你的播客';

  @override
  String get ai_summary_available => 'AI 摘要可用';

  @override
  String get calendar_month_format => '月';
}
