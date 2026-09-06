# Unscroll

Neu: [Version 0.3 – Intro, drei Modi und Schritte](UPDATE-0.3.md). Dieser Stand ersetzt die älteren Statusangaben unten.

**Bildschirmzeit, die du dir verdienst.** Nativer iOS-Prototyp mit SwiftUI, Apple Vision und Screen-Time-APIs.

## Ehrlicher Stand

Dies ist ein Entwicklungsprototyp, noch kein auf einem echten iPhone validiertes Produkt. [STATUS.md](STATUS.md) trennt implementierten Quellcode, Simulation und ausstehende Tests. Eine Apple-Developer-Mitgliedschaft fehlt aktuell; deshalb gibt es noch keine installierbare iPhone-Version.

## Enthalten

- Gemeinsames Zeitkonto und App-Sperren, Emergency-Zugang mit Historie.
- Kamera-Auswertung für Liegestütze, Squats, Planks und Sit-ups.
- Persönliches Profil, Ziele, Umrechnung, Streaks, Rekorde und Wochenberichte.
- Persönliche Alltagstipps und Benachrichtigungen.
- Game-Center-Anmeldung und Freundesvergleiche nach Apple-Portal-Einrichtung.
- Lokale Sieben-Tage-Challenge; eigene gemeinsame Challenges noch offen.
- Täglicher AlarmKit-Wecker ab iOS 26 mit eigenem Ton.

## Windows-Vorschau

Die separate Browser-Vorschau im Ordner `preview` bildet die Bedienung als Simulation ab. Sie sperrt keine iPhone-Apps und ersetzt keinen Gerätetest. Sie kann lokal mit `node preview/server.cjs` gestartet werden.

Zusätzlich wird `Unscroll-Vorschau.html` als eigenständige Datei geliefert: im Browser öffnen, ohne Installation oder laufenden Server. Beginne mit einer Übung, simuliere Wiederholungen und buche anschließend die verdienten Minuten auf dein Konto.

## Automatisch bauen

Der vorbereitete GitHub-Workflow soll bei Pull Requests den Swift-Kern prüfen und App und Erweiterung auf einem Mac kompilieren. Das Hochladen wurde bislang durch GitHub mit HTTP 403 verweigert; kein Cloud-Build ist gelaufen. Codemagic kann das Repository nach Freigabe über `codemagic.yaml` bauen:

1. **ios-check**: Tests und Simulator-Build ohne Signierung.
2. **ios-device**: Signierter Ad-hoc-Build, sobald Zertifikat und Profile in Codemagic hinterlegt sind. Benötigt eine aktive Apple-Developer-Mitgliedschaft und eine im Profil registrierte iPhone-UDID.

Die vorbereiteten Kennungen sind `com.ziarmoradicell.unscroll`, `com.ziarmoradicell.unscroll.monitor` und `group.com.ziarmoradicell.unscroll`. Sie sind noch nicht im Apple-Portal registriert. Beide Targets brauchen Family Controls und dieselbe App Group. Das Haupt-Target benötigt zusätzlich Game Center. Die Leaderboard-IDs lauten `unscroll.pushups`, `unscroll.squats`, `unscroll.plank`, `unscroll.situps`, `unscroll.streak` (klassisch, höher ist besser, beste Punktzahl). Eigene Kennungen lassen sich mit `UNSCROLL_BUNDLE_ID` erzeugen; die Codemagic-Signing-ID ist dann ebenfalls anzupassen.

## Lokal auf einem Mac

```sh
swift test
python3 scripts/configure.py
xcodegen generate --spec project.generated.yml
open Unscroll.xcodeproj
```

Voraussetzungen: Xcode 26 oder neuer, XcodeGen, iPhone ab iOS 17.4 (Wecker ab iOS 26). Das Konfigurationsskript erzeugt auch den Alarmton. Für einen Simulator-Build kann die Signierung ausgeschaltet werden; Screen Time und Kamera müssen auf einem echten Gerät geprüft werden.

## Kontoregel im Prototyp

Eine Freigabe reserviert höchstens 30 Minuten. Neu verdientes Guthaben bleibt währenddessen für die nächste Freigabe verfügbar. Bei Abbruch oder nach 23 Stunden verfallen noch ungenutzte reservierte Minuten. Die Bank selbst verfällt nicht. Die App zeigt diese vorläufige Regel sichtbar an.

## Datenschutz

Kamerabilder werden nicht gespeichert oder übertragen. Das Geburtsdatum bleibt lokal. Game Center erhält Trainingswerte ausschließlich nach Zustimmung und aktivem Übertragen. Es gibt keine Hintergrundübertragung von Bildschirmzeit oder Profil an einen eigenen Server.
