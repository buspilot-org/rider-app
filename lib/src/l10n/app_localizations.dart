import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
    Locale('de'),
    Locale('en'),
    Locale('ja'),
  ];

  /// App name; not translated.
  ///
  /// In en, this message translates to:
  /// **'Buspilot'**
  String get appTitle;

  /// No description provided for @languageTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your language'**
  String get languageTitle;

  /// No description provided for @languageFollowPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone setting'**
  String get languageFollowPhone;

  /// No description provided for @continueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// No description provided for @joinTitle.
  ///
  /// In en, this message translates to:
  /// **'Join a bus service'**
  String get joinTitle;

  /// No description provided for @joinIntro.
  ///
  /// In en, this message translates to:
  /// **'Enter the invite code from your school, club or hotel, or scan its QR code. No name, email or phone number needed.'**
  String get joinIntro;

  /// No description provided for @inviteCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Invite code'**
  String get inviteCodeLabel;

  /// No description provided for @joinButton.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get joinButton;

  /// No description provided for @scanQrButton.
  ///
  /// In en, this message translates to:
  /// **'Scan QR code'**
  String get scanQrButton;

  /// No description provided for @scanHint.
  ///
  /// In en, this message translates to:
  /// **'Point the camera at the invite QR code.'**
  String get scanHint;

  /// No description provided for @scanNotInvite.
  ///
  /// In en, this message translates to:
  /// **'This QR code is not a Buspilot invite.'**
  String get scanNotInvite;

  /// No description provided for @cameraUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The camera is not available. Allow camera access in the phone settings, or type the code instead.'**
  String get cameraUnavailable;

  /// No description provided for @joinJoined.
  ///
  /// In en, this message translates to:
  /// **'Joined {operator}'**
  String joinJoined(String operator);

  /// No description provided for @joinAlreadyMember.
  ///
  /// In en, this message translates to:
  /// **'You already follow {operator}'**
  String joinAlreadyMember(String operator);

  /// No description provided for @joinInvalid.
  ///
  /// In en, this message translates to:
  /// **'This code is not valid. Check it and try again.'**
  String get joinInvalid;

  /// No description provided for @joinRevoked.
  ///
  /// In en, this message translates to:
  /// **'Your access was ended by the operator. Ask them for a new invitation.'**
  String get joinRevoked;

  /// No description provided for @joinRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please try again in an hour.'**
  String get joinRateLimited;

  /// No description provided for @offlineError.
  ///
  /// In en, this message translates to:
  /// **'No connection. Try again when you are online.'**
  String get offlineError;

  /// No description provided for @genericError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get genericError;

  /// No description provided for @myStops.
  ///
  /// In en, this message translates to:
  /// **'My stops today'**
  String get myStops;

  /// No description provided for @routesHeader.
  ///
  /// In en, this message translates to:
  /// **'Routes'**
  String get routesHeader;

  /// No description provided for @addService.
  ///
  /// In en, this message translates to:
  /// **'Add service'**
  String get addService;

  /// No description provided for @homeEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No bus services yet'**
  String get homeEmptyTitle;

  /// No description provided for @homeEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Join with the invite code from your school, club or hotel to see when your bus comes.'**
  String get homeEmptyBody;

  /// No description provided for @homeNoStopsTitle.
  ///
  /// In en, this message translates to:
  /// **'Follow your stop'**
  String get homeNoStopsTitle;

  /// No description provided for @homeNoStopsBody.
  ///
  /// In en, this message translates to:
  /// **'Open a route below and tap your stop. Its next arrival then appears here.'**
  String get homeNoStopsBody;

  /// No description provided for @asOf.
  ///
  /// In en, this message translates to:
  /// **'As of {time}'**
  String asOf(String time);

  /// No description provided for @offlineAsOf.
  ///
  /// In en, this message translates to:
  /// **'Offline · as of {time}'**
  String offlineAsOf(String time);

  /// No description provided for @notUpdatedAsOf.
  ///
  /// In en, this message translates to:
  /// **'Not updated · as of {time}'**
  String notUpdatedAsOf(String time);

  /// No description provided for @arrivalScheduled.
  ///
  /// In en, this message translates to:
  /// **'{time} · scheduled'**
  String arrivalScheduled(String time);

  /// No description provided for @arrivalInMinutes.
  ///
  /// In en, this message translates to:
  /// **'{time} · in {minutes} min'**
  String arrivalInMinutes(int minutes, String time);

  /// No description provided for @arrivalDue.
  ///
  /// In en, this message translates to:
  /// **'{time} · now'**
  String arrivalDue(String time);

  /// No description provided for @arrivalDelayed.
  ///
  /// In en, this message translates to:
  /// **'Delayed ~{minutes} min · {time}'**
  String arrivalDelayed(int minutes, String time);

  /// No description provided for @arrivalAtStop.
  ///
  /// In en, this message translates to:
  /// **'At your stop'**
  String get arrivalAtStop;

  /// No description provided for @arrivalPassed.
  ///
  /// In en, this message translates to:
  /// **'Passed {time}'**
  String arrivalPassed(String time);

  /// No description provided for @arrivalCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled ({time})'**
  String arrivalCancelled(String time);

  /// No description provided for @arrivalNoBusToday.
  ///
  /// In en, this message translates to:
  /// **'No bus today'**
  String get arrivalNoBusToday;

  /// No description provided for @delayedBy.
  ///
  /// In en, this message translates to:
  /// **'~{minutes} min late'**
  String delayedBy(int minutes);

  /// No description provided for @phaseNotStarted.
  ///
  /// In en, this message translates to:
  /// **'Not started'**
  String get phaseNotStarted;

  /// No description provided for @phaseOnTheWay.
  ///
  /// In en, this message translates to:
  /// **'On the way'**
  String get phaseOnTheWay;

  /// No description provided for @phaseFinished.
  ///
  /// In en, this message translates to:
  /// **'Finished'**
  String get phaseFinished;

  /// No description provided for @phaseCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get phaseCancelled;

  /// No description provided for @tripAt.
  ///
  /// In en, this message translates to:
  /// **'{time} trip'**
  String tripAt(String time);

  /// No description provided for @liveTrip.
  ///
  /// In en, this message translates to:
  /// **'Extra trip'**
  String get liveTrip;

  /// No description provided for @positionUnknownSince.
  ///
  /// In en, this message translates to:
  /// **'We are checking where the bus is (since {time}). Please wait a moment.'**
  String positionUnknownSince(String time);

  /// No description provided for @routeGone.
  ///
  /// In en, this message translates to:
  /// **'This route is no longer available.'**
  String get routeGone;

  /// No description provided for @mapUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Map not available'**
  String get mapUnavailable;

  /// No description provided for @stopPassed.
  ///
  /// In en, this message translates to:
  /// **'Passed'**
  String get stopPassed;

  /// No description provided for @stopAtStop.
  ///
  /// In en, this message translates to:
  /// **'Bus at stop'**
  String get stopAtStop;

  /// No description provided for @stopNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get stopNext;

  /// No description provided for @stopUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get stopUpcoming;

  /// No description provided for @followStop.
  ///
  /// In en, this message translates to:
  /// **'Follow this stop'**
  String get followStop;

  /// No description provided for @followSaved.
  ///
  /// In en, this message translates to:
  /// **'Stop followed'**
  String get followSaved;

  /// No description provided for @alertSaved.
  ///
  /// In en, this message translates to:
  /// **'Alerts saved'**
  String get alertSaved;

  /// No description provided for @alertSettings.
  ///
  /// In en, this message translates to:
  /// **'Alert settings'**
  String get alertSettings;

  /// No description provided for @alertWhen.
  ///
  /// In en, this message translates to:
  /// **'Tell me when the bus is …'**
  String get alertWhen;

  /// No description provided for @alertByMinutes.
  ///
  /// In en, this message translates to:
  /// **'Minutes away'**
  String get alertByMinutes;

  /// No description provided for @alertByStops.
  ///
  /// In en, this message translates to:
  /// **'Stops away'**
  String get alertByStops;

  /// No description provided for @alertMinutesAway.
  ///
  /// In en, this message translates to:
  /// **'{count} min away'**
  String alertMinutesAway(int count);

  /// No description provided for @alertStopsAway.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 stop away} other{{count} stops away}}'**
  String alertStopsAway(int count);

  /// No description provided for @alertNotifyPassed.
  ///
  /// In en, this message translates to:
  /// **'Also tell me when the bus has passed my stop'**
  String get alertNotifyPassed;

  /// No description provided for @alertPause.
  ///
  /// In en, this message translates to:
  /// **'Pause alerts'**
  String get alertPause;

  /// No description provided for @alertPauseOff.
  ///
  /// In en, this message translates to:
  /// **'Not paused'**
  String get alertPauseOff;

  /// No description provided for @alertPauseToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get alertPauseToday;

  /// No description provided for @alertPauseUntilDate.
  ///
  /// In en, this message translates to:
  /// **'Until a date …'**
  String get alertPauseUntilDate;

  /// No description provided for @alertPausedThrough.
  ///
  /// In en, this message translates to:
  /// **'Paused through {date}'**
  String alertPausedThrough(String date);

  /// No description provided for @pushNotReady.
  ///
  /// In en, this message translates to:
  /// **'Push notifications come in a later version. Your alert settings are saved and will be used then.'**
  String get pushNotReady;

  /// No description provided for @pushAskTitle.
  ///
  /// In en, this message translates to:
  /// **'Get alerts for this stop?'**
  String get pushAskTitle;

  /// No description provided for @pushAskBody.
  ///
  /// In en, this message translates to:
  /// **'Buspilot can tell you when the bus is a few minutes away, and about delays and cancellations. Your phone asks next whether Buspilot may send notifications.'**
  String get pushAskBody;

  /// No description provided for @notNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notNow;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @unfollow.
  ///
  /// In en, this message translates to:
  /// **'Stop following'**
  String get unfollow;

  /// No description provided for @newsTitle.
  ///
  /// In en, this message translates to:
  /// **'News'**
  String get newsTitle;

  /// No description provided for @newsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No announcements'**
  String get newsEmpty;

  /// No description provided for @linksHeader.
  ///
  /// In en, this message translates to:
  /// **'Links and contact'**
  String get linksHeader;

  /// No description provided for @notInYourLanguage.
  ///
  /// In en, this message translates to:
  /// **'Not available in your language.'**
  String get notInYourLanguage;

  /// No description provided for @calendarTitle.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get calendarTitle;

  /// No description provided for @calendarServiceDay.
  ///
  /// In en, this message translates to:
  /// **'Bus runs'**
  String get calendarServiceDay;

  /// No description provided for @calendarNoService.
  ///
  /// In en, this message translates to:
  /// **'No bus'**
  String get calendarNoService;

  /// No description provided for @calendarExtraDay.
  ///
  /// In en, this message translates to:
  /// **'Extra service day'**
  String get calendarExtraDay;

  /// No description provided for @calendarChanges.
  ///
  /// In en, this message translates to:
  /// **'Changes'**
  String get calendarChanges;

  /// No description provided for @calendarHolidaysNote.
  ///
  /// In en, this message translates to:
  /// **'No bus on national holidays unless it is listed as an extra day.'**
  String get calendarHolidaysNote;

  /// No description provided for @previousMonth.
  ///
  /// In en, this message translates to:
  /// **'Previous month'**
  String get previousMonth;

  /// No description provided for @nextMonth.
  ///
  /// In en, this message translates to:
  /// **'Next month'**
  String get nextMonth;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsOperators.
  ///
  /// In en, this message translates to:
  /// **'Bus services'**
  String get settingsOperators;

  /// No description provided for @leave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leave;

  /// No description provided for @leaveConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave {operator}?'**
  String leaveConfirmTitle(String operator);

  /// No description provided for @leaveConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Its routes and alerts disappear from this phone. To join again you need an invite code.'**
  String get leaveConfirmBody;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @settingsPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get settingsPrivacy;

  /// No description provided for @privacyText.
  ///
  /// In en, this message translates to:
  /// **'Buspilot needs no account. The server stores only an anonymous ID for this phone, its language, a push token (once notifications are on) and the stops you follow. It never stores your name, email, phone number or location. Everything is deleted 90 days after you last opened the app. The button below deletes all of it from the server and from this phone right away.'**
  String get privacyText;

  /// No description provided for @deleteData.
  ///
  /// In en, this message translates to:
  /// **'Delete my data'**
  String get deleteData;

  /// No description provided for @deleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete your data?'**
  String get deleteConfirmTitle;

  /// No description provided for @deleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This removes this phone\'s anonymous ID, your bus services, followed stops and alert settings from the server and from this phone. You will need the invite codes again to rejoin.'**
  String get deleteConfirmBody;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @sourceCode.
  ///
  /// In en, this message translates to:
  /// **'Source code (AGPL-3.0)'**
  String get sourceCode;

  /// No description provided for @licenses.
  ///
  /// In en, this message translates to:
  /// **'Open source licences'**
  String get licenses;

  /// No description provided for @startOfflineTitle.
  ///
  /// In en, this message translates to:
  /// **'No connection'**
  String get startOfflineTitle;

  /// No description provided for @startOfflineBody.
  ///
  /// In en, this message translates to:
  /// **'Buspilot needs a connection the first time it starts.'**
  String get startOfflineBody;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retry;

  /// No description provided for @channelArrivalAlerts.
  ///
  /// In en, this message translates to:
  /// **'Arrival alerts'**
  String get channelArrivalAlerts;

  /// No description provided for @channelTripChanges.
  ///
  /// In en, this message translates to:
  /// **'Delays and cancellations'**
  String get channelTripChanges;

  /// No description provided for @alertShow.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get alertShow;

  /// No description provided for @postCategoryCancellation.
  ///
  /// In en, this message translates to:
  /// **'Cancellation'**
  String get postCategoryCancellation;

  /// No description provided for @postCategoryDelay.
  ///
  /// In en, this message translates to:
  /// **'Delay'**
  String get postCategoryDelay;

  /// No description provided for @postCategoryGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get postCategoryGeneral;

  /// No description provided for @postCategoryEvent.
  ///
  /// In en, this message translates to:
  /// **'Event'**
  String get postCategoryEvent;

  /// No description provided for @newsCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get newsCategories;

  /// No description provided for @newsCategoriesNote.
  ///
  /// In en, this message translates to:
  /// **'Choose which announcements to show. This applies to the list on this phone only.'**
  String get newsCategoriesNote;

  /// No description provided for @newsHidden.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 announcement hidden} other{{count} announcements hidden}}'**
  String newsHidden(int count);

  /// No description provided for @calendarHolidaysHeader.
  ///
  /// In en, this message translates to:
  /// **'National holidays'**
  String get calendarHolidaysHeader;

  /// No description provided for @miniMapFollowHint.
  ///
  /// In en, this message translates to:
  /// **'Stops you follow can show on a small map, at most two per bus service.'**
  String get miniMapFollowHint;

  /// No description provided for @miniMapLimit.
  ///
  /// In en, this message translates to:
  /// **'No map for this stop. A small map shows at most two stops you follow per bus service; a place stays taken for 30 days after you unfollow a stop.'**
  String get miniMapLimit;

  /// No description provided for @liveTripsHeader.
  ///
  /// In en, this message translates to:
  /// **'Extra trips'**
  String get liveTripsHeader;

  /// No description provided for @liveTripVisibleUntil.
  ///
  /// In en, this message translates to:
  /// **'Shown until {time}'**
  String liveTripVisibleUntil(String time);

  /// No description provided for @liveTripNextStop.
  ///
  /// In en, this message translates to:
  /// **'Next: {stop}'**
  String liveTripNextStop(String stop);

  /// No description provided for @liveTripNoAlerts.
  ///
  /// In en, this message translates to:
  /// **'Alerts for extra trips are not sent yet. The stop shows on your home screen with its arrival time.'**
  String get liveTripNoAlerts;

  /// No description provided for @liveTripEnded.
  ///
  /// In en, this message translates to:
  /// **'An extra trip you followed is no longer shown'**
  String get liveTripEnded;

  /// No description provided for @liveTripGone.
  ///
  /// In en, this message translates to:
  /// **'This trip is no longer shown.'**
  String get liveTripGone;

  /// No description provided for @statusOnTime.
  ///
  /// In en, this message translates to:
  /// **'On time'**
  String get statusOnTime;

  /// No description provided for @statusDelayed.
  ///
  /// In en, this message translates to:
  /// **'A little late'**
  String get statusDelayed;

  /// No description provided for @statusArriving.
  ///
  /// In en, this message translates to:
  /// **'Arriving soon'**
  String get statusArriving;

  /// No description provided for @statusAtStop.
  ///
  /// In en, this message translates to:
  /// **'At the stop'**
  String get statusAtStop;

  /// No description provided for @statusUnknown.
  ///
  /// In en, this message translates to:
  /// **'Position unknown'**
  String get statusUnknown;

  /// No description provided for @statusNotStarted.
  ///
  /// In en, this message translates to:
  /// **'Not started'**
  String get statusNotStarted;

  /// No description provided for @etaInMinutes.
  ///
  /// In en, this message translates to:
  /// **'in {minutes} min'**
  String etaInMinutes(int minutes);

  /// No description provided for @etaDue.
  ///
  /// In en, this message translates to:
  /// **'Arriving now'**
  String get etaDue;

  /// No description provided for @etaArrivesAt.
  ///
  /// In en, this message translates to:
  /// **'Arrives at {stop} at {time}'**
  String etaArrivesAt(String stop, String time);

  /// No description provided for @etaArrivesAround.
  ///
  /// In en, this message translates to:
  /// **'Should reach {stop} around {time} (about {minutes} min late)'**
  String etaArrivesAround(String stop, String time, int minutes);
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
      <String>['de', 'en', 'ja'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
