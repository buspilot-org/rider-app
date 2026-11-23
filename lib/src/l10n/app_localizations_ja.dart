// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'Buspilot';

  @override
  String get languageTitle => '言語を選んでください';

  @override
  String get languageFollowPhone => '端末の設定に合わせる';

  @override
  String get continueButton => '次へ';

  @override
  String get joinTitle => 'バスサービスに参加';

  @override
  String get joinIntro =>
      '学校・クラブ・ホテルから受け取った招待コードを入力するか、QRコードを読み取ってください。名前・メールアドレス・電話番号は不要です。';

  @override
  String get inviteCodeLabel => '招待コード';

  @override
  String get joinButton => '参加する';

  @override
  String get scanQrButton => 'QRコードを読み取る';

  @override
  String get scanHint => '招待QRコードにカメラを向けてください。';

  @override
  String get scanNotInvite => 'このQRコードはBuspilotの招待ではありません。';

  @override
  String get cameraUnavailable =>
      'カメラを使用できません。端末の設定でカメラへのアクセスを許可するか、コードを入力してください。';

  @override
  String joinJoined(String operator) {
    return '$operator に参加しました';
  }

  @override
  String joinAlreadyMember(String operator) {
    return '$operator にはすでに参加しています';
  }

  @override
  String get joinInvalid => 'このコードは無効です。確認してもう一度お試しください。';

  @override
  String get joinRevoked => '事業者によりアクセスが終了されました。新しい招待を依頼してください。';

  @override
  String get joinRateLimited => '試行回数が多すぎます。1時間後にもう一度お試しください。';

  @override
  String get offlineError => '接続できません。オンラインになってからもう一度お試しください。';

  @override
  String get genericError => 'エラーが発生しました。もう一度お試しください。';

  @override
  String get myStops => '今日のマイ停留所';

  @override
  String get routesHeader => '路線';

  @override
  String get addService => 'サービスを追加';

  @override
  String get homeEmptyTitle => 'まだバスサービスがありません';

  @override
  String get homeEmptyBody => '学校・クラブ・ホテルの招待コードで参加すると、バスの到着時刻がわかります。';

  @override
  String get homeNoStopsTitle => '停留所をフォロー';

  @override
  String get homeNoStopsBody => '下の路線を開いて停留所をタップすると、次の到着がここに表示されます。';

  @override
  String asOf(String time) {
    return '$time 時点';
  }

  @override
  String offlineAsOf(String time) {
    return 'オフライン · $time 時点';
  }

  @override
  String notUpdatedAsOf(String time) {
    return '更新できません · $time 時点';
  }

  @override
  String arrivalScheduled(String time) {
    return '$time · 予定';
  }

  @override
  String arrivalInMinutes(int minutes, String time) {
    return '$time · あと$minutes分';
  }

  @override
  String arrivalDue(String time) {
    return '$time · まもなく';
  }

  @override
  String arrivalDelayed(int minutes, String time) {
    return '約$minutes分遅れ · $time';
  }

  @override
  String get arrivalAtStop => '停留所に到着';

  @override
  String arrivalPassed(String time) {
    return '$time 通過';
  }

  @override
  String arrivalCancelled(String time) {
    return '運休（$time）';
  }

  @override
  String get arrivalNoBusToday => '本日の運行はありません';

  @override
  String delayedBy(int minutes) {
    return '約$minutes分遅れ';
  }

  @override
  String get phaseNotStarted => '運行前';

  @override
  String get phaseOnTheWay => '運行中';

  @override
  String get phaseFinished => '運行終了';

  @override
  String get phaseCancelled => '運休';

  @override
  String tripAt(String time) {
    return '$time 発の便';
  }

  @override
  String get liveTrip => '臨時便';

  @override
  String positionUnknownSince(String time) {
    return '$time からバスの位置が不明です';
  }

  @override
  String get routeGone => 'この路線は利用できなくなりました。';

  @override
  String get mapUnavailable => '地図は利用できません';

  @override
  String get stopPassed => '通過';

  @override
  String get stopAtStop => '停車中';

  @override
  String get stopNext => '次';

  @override
  String get stopUpcoming => 'これから';

  @override
  String get followStop => 'この停留所をフォロー';

  @override
  String get followSaved => '停留所をフォローしました';

  @override
  String get alertSaved => '通知設定を保存しました';

  @override
  String get alertSettings => '通知設定';

  @override
  String get alertWhen => 'バスが次の状態になったら知らせる';

  @override
  String get alertByMinutes => '到着の何分前';

  @override
  String get alertByStops => '何停留所前';

  @override
  String alertMinutesAway(int count) {
    return '$count分前';
  }

  @override
  String alertStopsAway(int count) {
    return '$count停留所前';
  }

  @override
  String get alertNotifyPassed => 'バスが停留所を通過したときも知らせる';

  @override
  String get alertPause => '通知を一時停止';

  @override
  String get alertPauseOff => '停止しない';

  @override
  String get alertPauseToday => '今日';

  @override
  String get alertPauseUntilDate => '日付を指定…';

  @override
  String alertPausedThrough(String date) {
    return '$date まで停止中';
  }

  @override
  String get pushNotReady => 'プッシュ通知は今後のバージョンで対応します。通知設定は保存され、そのときに使われます。';

  @override
  String get pushAskTitle => 'この停留所の通知を受け取りますか？';

  @override
  String get pushAskBody =>
      'バスがあと数分で到着するときや、遅れ・運休をお知らせします。このあと、通知の許可を端末が確認します。';

  @override
  String get notNow => '後で';

  @override
  String get save => '保存';

  @override
  String get unfollow => 'フォローをやめる';

  @override
  String get newsTitle => 'お知らせ';

  @override
  String get newsEmpty => 'お知らせはありません';

  @override
  String get linksHeader => 'リンク・連絡先';

  @override
  String get notInYourLanguage => '選択した言語では提供されていません。';

  @override
  String get calendarTitle => '運行カレンダー';

  @override
  String get calendarServiceDay => '運行日';

  @override
  String get calendarNoService => '運行なし';

  @override
  String get calendarExtraDay => '臨時運行日';

  @override
  String get calendarChanges => '変更';

  @override
  String get calendarHolidaysNote => '祝日はまだ表示されません。祝日は通常運休です。';

  @override
  String get previousMonth => '前の月';

  @override
  String get nextMonth => '次の月';

  @override
  String get settingsTitle => '設定';

  @override
  String get settingsLanguage => '言語';

  @override
  String get settingsOperators => 'バスサービス';

  @override
  String get leave => '退出';

  @override
  String leaveConfirmTitle(String operator) {
    return '$operator から退出しますか？';
  }

  @override
  String get leaveConfirmBody => '路線と通知がこの端末から消えます。再度参加するには招待コードが必要です。';

  @override
  String get cancel => 'キャンセル';

  @override
  String get delete => '削除';

  @override
  String get settingsPrivacy => 'プライバシー';

  @override
  String get privacyText =>
      'Buspilotにアカウントは必要ありません。サーバーに保存されるのは、この端末の匿名ID、言語、プッシュトークン（通知を有効にした場合）、フォローしている停留所だけです。名前・メールアドレス・電話番号・位置情報は保存しません。最後にアプリを開いてから90日後にすべて削除されます。下のボタンでバスサービス・停留所・プッシュトークンをすぐに削除できます（匿名ID自体は90日以内に削除されます）。';

  @override
  String get deleteData => 'データを削除';

  @override
  String get deleteConfirmTitle => 'データを削除しますか？';

  @override
  String get deleteConfirmBody =>
      'バスサービス、フォロー中の停留所、通知設定をサーバーとこの端末から削除します。再度参加するには招待コードが必要です。';

  @override
  String get settingsAbout => 'このアプリについて';

  @override
  String get sourceCode => 'ソースコード（AGPL-3.0）';

  @override
  String get licenses => 'オープンソースライセンス';

  @override
  String get startOfflineTitle => '接続できません';

  @override
  String get startOfflineBody => '初回起動時にはインターネット接続が必要です。';

  @override
  String get retry => '再試行';
}
