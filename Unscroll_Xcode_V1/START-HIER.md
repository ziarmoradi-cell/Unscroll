# Unscroll auf deinem iPhone testen

1. ZIP entpacken und `Unscroll_Xcode_V1/Unscroll.xcodeproj` per Doppelklick öffnen.
2. Oben das Schema **Unscroll** und dein per Kabel verbundenes iPhone auswählen.
3. Unter **Signing & Capabilities** bei **Unscroll** und **UnscrollMonitor** dein Team
   prüfen. **App Groups** (`group.com.ziar.unscroll`) und **Family Controls** müssen bei
   beiden Targets eingerichtet sein. Team und Bundle-ID sind aus deinem Projekt übernommen.
4. Auf ▶ drücken. Auf dem iPhone den Kamerazugriff erlauben und zuerst eine Übung testen.

Kamera: Handy aufrecht abstellen, seitlich trainieren, ganzer Körper im Bild.
Plank: Zeit läuft nur bei erkannter Haltung; 10 Sekunden ergeben eine Minute Guthaben.
Ein Haltungsabbruch pausiert die Gesamtzeit und beendet die aktuelle PR-Haltung.
Liegestütze/Kniebeugen: komplette Bewegung; standardmäßig 30 Sekunden Guthaben pro Wiederholung.

Bildschirmzeit: In Unscroll erlauben, Apps auswählen, dann Guthaben einlösen.
Die neue Sperrfunktion braucht zusätzliche Apple-Berechtigungen. Für TestFlight/App Store
muss Family Controls für App und Erweiterung zur Distribution freigegeben sein.

Version 1.1, Build 2. Noch nicht in App Store Connect hochgeladen. Vor dem Upload auf dem
realen iPhone prüfen: Zählung, PRs nach Neustart und erneute App-Sperre nach Zeitverbrauch.
Wenn Xcode eine Signierungsfehlermeldung zeigt, einen Screenshot der Meldung schicken.
