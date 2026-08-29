import '../services/settings_controller.dart';

/// Manual zh/en string lookup — the app has too few strings to justify the full
/// `flutter_localizations`/ARB pipeline, so this is a plain table keyed by the resolved
/// [AppLanguage] (never `AppLanguage.system`; callers pass `SettingsController.effectiveLanguage`).
class Strings {
  final AppLanguage language;

  const Strings(this.language);

  bool get _zh => language == AppLanguage.zh;

  String get appTitle => 'MaxUsage';
  String get dashboardTab => _zh ? '仪表盘' : 'Dashboard';
  String get settingsTab => _zh ? '设置' : 'Settings';

  // Pairing screen
  String get pairTitle => _zh ? '与 Mac 配对' : 'Pair with Mac';
  String get pairIntro => _zh
      ? '在 Mac 上打开 MaxUsage：\n设置 → 允许手机同步 → 添加手机…\n然后用下方摄像头扫描它显示的二维码。'
      : 'On your Mac, open MaxUsage:\nSettings → Allow Phone Sync → Add Phone…\nThen scan the code it shows with the camera below.';
  String get pairing => _zh ? '正在配对…' : 'Pairing…';

  // Dashboard
  String get notConnected => _zh ? '未连接' : 'Not connected';
  String get notConnectedBanner =>
      _zh ? '未连接 — 正在显示最近一次获取到的数据。' : 'Not connected — showing the last known data.';
  String get noQuotasYet => _zh
      ? '暂时没有额度数据，等 Mac 完成下一次刷新后再来看看。'
      : 'No quotas yet — check back once your Mac finishes its first refresh.';
  String get noDataYet => _zh ? '暂无数据' : 'No data yet';
  String moreCount(int n) => _zh ? '还有 $n 项 ›' : '+$n more';
  String get showLess => _zh ? '收起' : 'Show less';
  String updated(String relative) => _zh ? '$relative更新' : 'Updated $relative';
  String get justNow => _zh ? '刚刚' : 'just now';
  String secondsAgo(int s) => _zh ? '$s 秒前' : '${s}s ago';
  String minutesAgo(int m) => _zh ? '$m 分钟前' : '${m}m ago';
  String hoursAgo(int h) => _zh ? '$h 小时前' : '${h}h ago';

  // Unpair
  String get unpairTitle => _zh ? '取消与此手机的配对？' : 'Unpair this phone?';
  String get unpairBody => _zh
      ? '取消配对后，你需要在 Mac 上重新生成二维码并扫描才能再次连接。'
      : "You'll need to scan a new QR code from your Mac to reconnect.";
  String get cancel => _zh ? '取消' : 'Cancel';
  String get unpair => _zh ? '取消配对' : 'Unpair';
  String get unpairedFrom => _zh ? '已与以下设备配对' : 'Paired with';

  // Settings — Appearance
  String get appearance => _zh ? '外观' : 'Appearance';
  String get themeSystem => _zh ? '跟随系统' : 'System';
  String get themeLight => _zh ? '日间模式' : 'Light';
  String get themeDark => _zh ? '夜间模式' : 'Dark';

  // Settings — Language
  String get languageSectionTitle => _zh ? '语言' : 'Language';
  String get languageSystem => _zh ? '跟随系统' : 'System';
  String get languageZh => '中文';
  String get languageEn => 'English';

  // Settings — About the data
  String get aboutData => _zh ? '数据说明' : 'About This Data';
  String get aboutDataBody => _zh
      ? '手机每 30 秒向 Mac 请求一次最新数据。\n'
            'Mac 本身每 5 分钟刷新一次各个服务商的用量，所以数据最多有约 5 分钟的延迟。\n'
            '所有数据都直接来自你 Mac 上已登录的 AI 编程订阅服务，通过同一局域网从 Mac 传到手机，不会经过任何服务器中转。'
      : 'This phone asks your Mac for the latest data every 30 seconds.\n'
            "The Mac itself only refreshes each provider's usage every 5 minutes, so data can lag "
            'by up to about 5 minutes.\n'
            'Everything comes straight from the AI coding subscriptions already signed in on your '
            'Mac, sent directly over your local network — never through any server.';
}
