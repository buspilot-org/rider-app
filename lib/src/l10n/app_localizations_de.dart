// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Buspilot';

  @override
  String get languageTitle => 'Sprache wählen';

  @override
  String get languageFollowPhone => 'Wie auf dem Telefon';

  @override
  String get continueButton => 'Weiter';

  @override
  String get joinTitle => 'Einem Busdienst beitreten';

  @override
  String get joinIntro =>
      'Gib den Einladungscode deiner Schule, deines Vereins oder Hotels ein oder scanne den QR-Code. Name, E-Mail oder Telefonnummer sind nicht nötig.';

  @override
  String get inviteCodeLabel => 'Einladungscode';

  @override
  String get joinButton => 'Beitreten';

  @override
  String get scanQrButton => 'QR-Code scannen';

  @override
  String get scanHint => 'Richte die Kamera auf den Einladungs-QR-Code.';

  @override
  String get scanNotInvite => 'Dieser QR-Code ist keine Buspilot-Einladung.';

  @override
  String get cameraUnavailable =>
      'Die Kamera ist nicht verfügbar. Erlaube den Kamerazugriff in den Telefoneinstellungen oder tippe den Code ein.';

  @override
  String joinJoined(String operator) {
    return '$operator beigetreten';
  }

  @override
  String joinAlreadyMember(String operator) {
    return 'Du folgst $operator bereits';
  }

  @override
  String get joinInvalid =>
      'Dieser Code ist ungültig. Prüfe ihn und versuche es noch einmal.';

  @override
  String get joinRevoked =>
      'Der Betreiber hat deinen Zugang beendet. Bitte ihn um eine neue Einladung.';

  @override
  String get joinRateLimited =>
      'Zu viele Versuche. Bitte versuche es in einer Stunde noch einmal.';

  @override
  String get offlineError =>
      'Keine Verbindung. Versuche es noch einmal, wenn du online bist.';

  @override
  String get genericError =>
      'Etwas ist schiefgegangen. Bitte versuche es noch einmal.';

  @override
  String get myStops => 'Meine Haltestellen heute';

  @override
  String get routesHeader => 'Linien';

  @override
  String get addService => 'Dienst hinzufügen';

  @override
  String get homeEmptyTitle => 'Noch keine Busdienste';

  @override
  String get homeEmptyBody =>
      'Tritt mit dem Einladungscode deiner Schule, deines Vereins oder Hotels bei, um zu sehen, wann dein Bus kommt.';

  @override
  String get homeNoStopsTitle => 'Folge deiner Haltestelle';

  @override
  String get homeNoStopsBody =>
      'Öffne unten eine Linie und tippe auf deine Haltestelle. Die nächste Ankunft erscheint dann hier.';

  @override
  String asOf(String time) {
    return 'Stand $time';
  }

  @override
  String offlineAsOf(String time) {
    return 'Offline · Stand $time';
  }

  @override
  String notUpdatedAsOf(String time) {
    return 'Nicht aktualisiert · Stand $time';
  }

  @override
  String arrivalScheduled(String time) {
    return '$time · planmäßig';
  }

  @override
  String arrivalInMinutes(int minutes, String time) {
    return '$time · in $minutes Min.';
  }

  @override
  String arrivalDue(String time) {
    return '$time · jetzt';
  }

  @override
  String arrivalDelayed(int minutes, String time) {
    return 'Verspätet ~$minutes Min. · $time';
  }

  @override
  String get arrivalAtStop => 'An deiner Haltestelle';

  @override
  String arrivalPassed(String time) {
    return 'Vorbei $time';
  }

  @override
  String arrivalCancelled(String time) {
    return 'Fällt aus ($time)';
  }

  @override
  String get arrivalNoBusToday => 'Heute kein Bus';

  @override
  String delayedBy(int minutes) {
    return '~$minutes Min. verspätet';
  }

  @override
  String get phaseNotStarted => 'Noch nicht gestartet';

  @override
  String get phaseOnTheWay => 'Unterwegs';

  @override
  String get phaseFinished => 'Beendet';

  @override
  String get phaseCancelled => 'Fällt aus';

  @override
  String tripAt(String time) {
    return 'Fahrt um $time';
  }

  @override
  String get liveTrip => 'Zusatzfahrt';

  @override
  String positionUnknownSince(String time) {
    return 'Wir prüfen gerade, wo der Bus ist (seit $time). Bitte warte einen Moment.';
  }

  @override
  String get routeGone => 'Diese Linie ist nicht mehr verfügbar.';

  @override
  String get mapUnavailable => 'Karte nicht verfügbar';

  @override
  String get stopPassed => 'Vorbei';

  @override
  String get stopAtStop => 'Bus an der Haltestelle';

  @override
  String get stopNext => 'Als Nächstes';

  @override
  String get stopUpcoming => 'Später';

  @override
  String get followStop => 'Dieser Haltestelle folgen';

  @override
  String get followSaved => 'Haltestelle gefolgt';

  @override
  String get alertSaved => 'Benachrichtigungen gespeichert';

  @override
  String get alertSettings => 'Benachrichtigungen';

  @override
  String get alertWhen => 'Sag mir Bescheid, wenn der Bus …';

  @override
  String get alertByMinutes => 'Minuten entfernt';

  @override
  String get alertByStops => 'Haltestellen entfernt';

  @override
  String alertMinutesAway(int count) {
    return '$count Min. entfernt ist';
  }

  @override
  String alertStopsAway(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Haltestellen entfernt ist',
      one: '1 Haltestelle entfernt ist',
    );
    return '$_temp0';
  }

  @override
  String get alertNotifyPassed =>
      'Auch Bescheid sagen, wenn der Bus meine Haltestelle passiert hat';

  @override
  String get alertPause => 'Benachrichtigungen pausieren';

  @override
  String get alertPauseOff => 'Nicht pausiert';

  @override
  String get alertPauseToday => 'Heute';

  @override
  String get alertPauseUntilDate => 'Bis zu einem Datum …';

  @override
  String alertPausedThrough(String date) {
    return 'Pausiert bis einschließlich $date';
  }

  @override
  String get pushNotReady =>
      'Push-Benachrichtigungen kommen in einer späteren Version. Deine Einstellungen werden gespeichert und dann verwendet.';

  @override
  String get pushAskTitle => 'Benachrichtigungen für diese Haltestelle?';

  @override
  String get pushAskBody =>
      'Buspilot sagt dir Bescheid, wenn der Bus wenige Minuten entfernt ist, und bei Verspätungen oder Ausfällen. Als Nächstes fragt dein Telefon, ob Buspilot Benachrichtigungen senden darf.';

  @override
  String get notNow => 'Später';

  @override
  String get save => 'Speichern';

  @override
  String get unfollow => 'Nicht mehr folgen';

  @override
  String get newsTitle => 'Neuigkeiten';

  @override
  String get newsEmpty => 'Keine Mitteilungen';

  @override
  String get linksHeader => 'Links und Kontakt';

  @override
  String get notInYourLanguage => 'In deiner Sprache nicht verfügbar.';

  @override
  String get calendarTitle => 'Kalender';

  @override
  String get calendarServiceDay => 'Bus fährt';

  @override
  String get calendarNoService => 'Kein Bus';

  @override
  String get calendarExtraDay => 'Zusätzlicher Fahrtag';

  @override
  String get calendarChanges => 'Änderungen';

  @override
  String get calendarHolidaysNote =>
      'An Feiertagen fährt kein Bus, außer sie stehen als zusätzlicher Betriebstag in der Liste.';

  @override
  String get previousMonth => 'Vorheriger Monat';

  @override
  String get nextMonth => 'Nächster Monat';

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get settingsLanguage => 'Sprache';

  @override
  String get settingsOperators => 'Busdienste';

  @override
  String get leave => 'Verlassen';

  @override
  String leaveConfirmTitle(String operator) {
    return '$operator verlassen?';
  }

  @override
  String get leaveConfirmBody =>
      'Linien und Benachrichtigungen verschwinden von diesem Telefon. Um wieder beizutreten, brauchst du einen Einladungscode.';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get delete => 'Löschen';

  @override
  String get settingsPrivacy => 'Datenschutz';

  @override
  String get privacyText =>
      'Buspilot braucht kein Konto. Der Server speichert nur eine anonyme ID für dieses Telefon, seine Sprache, ein Push-Token (sobald Benachrichtigungen aktiv sind) und die Haltestellen, denen du folgst. Name, E-Mail, Telefonnummer oder Standort werden nie gespeichert. Alles wird 90 Tage nach der letzten Nutzung gelöscht. Die Schaltfläche unten löscht all das sofort vom Server und von diesem Telefon.';

  @override
  String get deleteData => 'Meine Daten löschen';

  @override
  String get deleteConfirmTitle => 'Daten löschen?';

  @override
  String get deleteConfirmBody =>
      'Die anonyme ID dieses Telefons, deine Busdienste, Haltestellen und Benachrichtigungseinstellungen werden vom Server und von diesem Telefon gelöscht. Zum erneuten Beitreten brauchst du wieder die Einladungscodes.';

  @override
  String get settingsAbout => 'Über die App';

  @override
  String get sourceCode => 'Quellcode (AGPL-3.0)';

  @override
  String get licenses => 'Open-Source-Lizenzen';

  @override
  String get startOfflineTitle => 'Keine Verbindung';

  @override
  String get startOfflineBody =>
      'Buspilot braucht beim ersten Start eine Verbindung.';

  @override
  String get retry => 'Erneut versuchen';

  @override
  String get channelArrivalAlerts => 'Ankunftsmeldungen';

  @override
  String get channelTripChanges => 'Verspätungen und Ausfälle';

  @override
  String get alertShow => 'Anzeigen';

  @override
  String get postCategoryCancellation => 'Ausfall';

  @override
  String get postCategoryDelay => 'Verspätung';

  @override
  String get postCategoryGeneral => 'Allgemein';

  @override
  String get postCategoryEvent => 'Veranstaltung';

  @override
  String get newsCategories => 'Kategorien';

  @override
  String get newsCategoriesNote =>
      'Wähle, welche Mitteilungen angezeigt werden. Das gilt nur für die Liste auf diesem Telefon.';

  @override
  String newsHidden(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Mitteilungen ausgeblendet',
      one: '1 Mitteilung ausgeblendet',
    );
    return '$_temp0';
  }

  @override
  String get calendarHolidaysHeader => 'Feiertage';

  @override
  String get miniMapFollowHint =>
      'Haltestellen, denen du folgst, können auf einer kleinen Karte erscheinen, höchstens zwei je Busdienst.';

  @override
  String get miniMapLimit =>
      'Keine Karte für diese Haltestelle. Die kleine Karte zeigt höchstens zwei Haltestellen je Busdienst, denen du folgst; nach dem Entfolgen bleibt ein Platz 30 Tage belegt.';

  @override
  String get liveTripsHeader => 'Sonderfahrten';

  @override
  String liveTripVisibleUntil(String time) {
    return 'Sichtbar bis $time';
  }

  @override
  String liveTripNextStop(String stop) {
    return 'Als Nächstes: $stop';
  }

  @override
  String get liveTripNoAlerts =>
      'Für Sonderfahrten werden noch keine Benachrichtigungen gesendet. Die Haltestelle erscheint mit ihrer Ankunftszeit auf dem Startbildschirm.';

  @override
  String get liveTripEnded =>
      'Eine Sonderfahrt, der du folgst, wird nicht mehr angezeigt';

  @override
  String get liveTripGone => 'Diese Fahrt wird nicht mehr angezeigt.';

  @override
  String get statusOnTime => 'Pünktlich';

  @override
  String get statusDelayed => 'Etwas verspätet';

  @override
  String get statusArriving => 'Kommt gleich';

  @override
  String get statusAtStop => 'An der Haltestelle';

  @override
  String get statusUnknown => 'Position unbekannt';

  @override
  String get statusNotStarted => 'Noch nicht gestartet';

  @override
  String etaInMinutes(int minutes) {
    return 'in $minutes Min.';
  }

  @override
  String get etaDue => 'Kommt jetzt an';

  @override
  String etaArrivesAt(String stop, String time) {
    return 'Erreicht $stop um $time';
  }

  @override
  String etaArrivesAround(String stop, String time, int minutes) {
    return 'Erreicht $stop gegen $time (etwa $minutes Min. später)';
  }
}
