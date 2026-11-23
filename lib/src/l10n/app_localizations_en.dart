// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Buspilot';

  @override
  String get languageTitle => 'Choose your language';

  @override
  String get languageFollowPhone => 'Phone setting';

  @override
  String get continueButton => 'Continue';

  @override
  String get joinTitle => 'Join a bus service';

  @override
  String get joinIntro =>
      'Enter the invite code from your school, club or hotel, or scan its QR code. No name, email or phone number needed.';

  @override
  String get inviteCodeLabel => 'Invite code';

  @override
  String get joinButton => 'Join';

  @override
  String get scanQrButton => 'Scan QR code';

  @override
  String get scanHint => 'Point the camera at the invite QR code.';

  @override
  String get scanNotInvite => 'This QR code is not a Buspilot invite.';

  @override
  String get cameraUnavailable =>
      'The camera is not available. Allow camera access in the phone settings, or type the code instead.';

  @override
  String joinJoined(String operator) {
    return 'Joined $operator';
  }

  @override
  String joinAlreadyMember(String operator) {
    return 'You already follow $operator';
  }

  @override
  String get joinInvalid => 'This code is not valid. Check it and try again.';

  @override
  String get joinRevoked =>
      'Your access was ended by the operator. Ask them for a new invitation.';

  @override
  String get joinRateLimited =>
      'Too many attempts. Please try again in an hour.';

  @override
  String get offlineError => 'No connection. Try again when you are online.';

  @override
  String get genericError => 'Something went wrong. Please try again.';

  @override
  String get myStops => 'My stops today';

  @override
  String get routesHeader => 'Routes';

  @override
  String get addService => 'Add service';

  @override
  String get homeEmptyTitle => 'No bus services yet';

  @override
  String get homeEmptyBody =>
      'Join with the invite code from your school, club or hotel to see when your bus comes.';

  @override
  String get homeNoStopsTitle => 'Follow your stop';

  @override
  String get homeNoStopsBody =>
      'Open a route below and tap your stop. Its next arrival then appears here.';

  @override
  String asOf(String time) {
    return 'As of $time';
  }

  @override
  String offlineAsOf(String time) {
    return 'Offline · as of $time';
  }

  @override
  String arrivalScheduled(String time) {
    return '$time · scheduled';
  }

  @override
  String arrivalInMinutes(int minutes, String time) {
    return '$time · in $minutes min';
  }

  @override
  String arrivalDue(String time) {
    return '$time · now';
  }

  @override
  String arrivalDelayed(int minutes, String time) {
    return 'Delayed ~$minutes min · $time';
  }

  @override
  String get arrivalAtStop => 'At your stop';

  @override
  String arrivalPassed(String time) {
    return 'Passed $time';
  }

  @override
  String arrivalCancelled(String time) {
    return 'Cancelled ($time)';
  }

  @override
  String get arrivalNoBusToday => 'No bus today';

  @override
  String delayedBy(int minutes) {
    return '~$minutes min late';
  }

  @override
  String get phaseNotStarted => 'Not started';

  @override
  String get phaseOnTheWay => 'On the way';

  @override
  String get phaseFinished => 'Finished';

  @override
  String get phaseCancelled => 'Cancelled';

  @override
  String tripAt(String time) {
    return '$time trip';
  }

  @override
  String get liveTrip => 'Extra trip';

  @override
  String positionUnknownSince(String time) {
    return 'Bus position unknown since $time';
  }

  @override
  String get routeGone => 'This route is no longer available.';

  @override
  String get mapUnavailable => 'Map not available';

  @override
  String get stopPassed => 'Passed';

  @override
  String get stopAtStop => 'Bus at stop';

  @override
  String get stopNext => 'Next';

  @override
  String get stopUpcoming => 'Upcoming';

  @override
  String get followStop => 'Follow this stop';

  @override
  String get followSaved => 'Stop followed';

  @override
  String get alertSaved => 'Alerts saved';

  @override
  String get alertSettings => 'Alert settings';

  @override
  String get alertWhen => 'Tell me when the bus is …';

  @override
  String get alertByMinutes => 'Minutes away';

  @override
  String get alertByStops => 'Stops away';

  @override
  String alertMinutesAway(int count) {
    return '$count min away';
  }

  @override
  String alertStopsAway(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stops away',
      one: '1 stop away',
    );
    return '$_temp0';
  }

  @override
  String get alertNotifyPassed =>
      'Also tell me when the bus has passed my stop';

  @override
  String get alertPause => 'Pause alerts';

  @override
  String get alertPauseOff => 'Not paused';

  @override
  String get alertPauseToday => 'Today';

  @override
  String get alertPauseUntilDate => 'Until a date …';

  @override
  String alertPausedThrough(String date) {
    return 'Paused through $date';
  }

  @override
  String get pushNotReady =>
      'Push notifications come in a later version. Your alert settings are saved and will be used then.';

  @override
  String get save => 'Save';

  @override
  String get unfollow => 'Stop following';

  @override
  String get newsTitle => 'News';

  @override
  String get newsEmpty => 'No announcements';

  @override
  String get linksHeader => 'Links and contact';

  @override
  String get notInYourLanguage => 'Not available in your language.';

  @override
  String get calendarTitle => 'Calendar';

  @override
  String get calendarServiceDay => 'Bus runs';

  @override
  String get calendarNoService => 'No bus';

  @override
  String get calendarExtraDay => 'Extra service day';

  @override
  String get calendarChanges => 'Changes';

  @override
  String get calendarHolidaysNote =>
      'National holidays are not marked yet; on those days there is usually no bus.';

  @override
  String get previousMonth => 'Previous month';

  @override
  String get nextMonth => 'Next month';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsOperators => 'Bus services';

  @override
  String get leave => 'Leave';

  @override
  String leaveConfirmTitle(String operator) {
    return 'Leave $operator?';
  }

  @override
  String get leaveConfirmBody =>
      'Its routes and alerts disappear from this phone. To join again you need a new invite code.';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get settingsPrivacy => 'Privacy';

  @override
  String get privacyText =>
      'Buspilot needs no account. The server stores only an anonymous ID for this phone, its language, a push token (once notifications are on) and the stops you follow. It never stores your name, email, phone number or location. Everything is deleted 90 days after you last opened the app, or now with the button below.';

  @override
  String get deleteData => 'Delete my data';

  @override
  String get deleteConfirmTitle => 'Delete your data?';

  @override
  String get deleteConfirmBody =>
      'This removes your bus services, followed stops and alert settings from the server and from this phone. You will need the invite codes again to rejoin.';

  @override
  String get settingsAbout => 'About';

  @override
  String get sourceCode => 'Source code (AGPL-3.0)';

  @override
  String get licenses => 'Open source licences';

  @override
  String get startOfflineTitle => 'No connection';

  @override
  String get startOfflineBody =>
      'Buspilot needs a connection the first time it starts.';

  @override
  String get retry => 'Try again';
}
