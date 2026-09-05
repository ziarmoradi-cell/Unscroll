# Durchgeführte Prüfungen

5. September 2026 · Windows · lokaler Prototyp.

## Bestanden

`node --test preview/model.test.cjs`: **9 Tests bestanden, 0 fehlgeschlagen**.

- Gutschrift pro Einheit, Schutz vor doppeltem Abschluss.
- Gemeinsamer Verbrauch über mehrere Apps, Sperrstatus bei null.
- Während einer Freigabe verdiente Minuten bleiben für die nächste Sitzung.
- Emergency wird einmal gezählt, keine parallelen Freigaben.
- Aktive Sitzung und Historie bleiben nach Neuladen konsistent.
- Plank-Zeiten werden auf vollständige Guthabeneinheiten abgerundet.
- Keine Rückbuchung unklarer Restzeit beim frühen Abbruch.
- Ungültiger gespeicherter Zustand wird zurückgesetzt.
- Ohne ausgewählte Apps wird keine Freigabe angelegt.

Automatisierter Chrome-Durchlauf mit Playwright: **bestanden**, sowohl über den lokalen Server als auch mit der eigenständigen HTML-Datei ohne Server.

Zehn simulierte Liegestütze, Gutschrift, Nutzung über Instagram/TikTok/YouTube, Neuladen einer laufenden Sitzung, Aufbrauchen, erneute Sperre, Emergency, Wochenübersicht, Profilspeicherung, Demo-Freund, sichere Textdarstellung eingegebener Namen und persönliche Challenge. Alle fünf Ansichten bei 390 Pixel Breite ohne horizontalen Überlauf. Keine JavaScript-Laufzeitfehler. Desktop- und Mobilansicht zusätzlich visuell geprüft.

JavaScript-Syntaxprüfung und Parsen des Apple-Datenschutzmanifests: **bestanden**.

## Noch nicht ausgeführt

- `swift test`: Sieben Swift-Kerntests vorbereitet, kein Swift-Compiler in dieser Windows-Sitzung.
- Xcode-/Simulator-Build: Workflow vorbereitet, Hochladen durch GitHub-Zugangsfehler blockiert.
- Codemagic-Build: Konto nicht verbunden; kein Build gestartet.
- iPhone-Installation: Keine Apple-Developer-Mitgliedschaft und keine Signierung vorhanden.
- Reale Kameraerkennung, Screen-Time-Sperren, AlarmKit und Game Center: **nicht auf einem Gerät getestet**.

Die bestandenen Browser-Tests belegen nur die Simulation. Sie sind kein Nachweis für die Funktion der iOS-Systemschnittstellen.
