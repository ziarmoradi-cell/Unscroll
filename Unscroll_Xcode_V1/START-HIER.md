# Unscroll 1.2.2 – dein vollständiges Update

Diese ZIP enthält das ganze Xcode-Projekt. Du musst keine einzelnen Code-Dateien in dein altes Projekt kopieren.

1. ZIP auf deinem Mac entpacken. Das alte Projekt vorher schließen.
2. Im entpackten Ordner `Unscroll_Xcode_V1` die Datei **Unscroll.xcodeproj** öffnen.
3. Oben das Schema **Unscroll** und dein angeschlossenes iPhone wählen. Für den neuen Systemwecker Xcode 26 oder neuer verwenden; auf dem iPhone wird iOS 26 benötigt. Die übrige App unterstützt iOS 17.4 und neuer.
4. Bei **Signing & Capabilities** für **Unscroll** und **UnscrollMonitor** dein Team prüfen. Team, Bundle-ID und AppIcon sind übernommen.
5. Auf ▶ drücken. Die App über die vorhandene Installation installieren, damit ihre lokalen Daten erhalten bleiben. Beim Einstieg erscheint das neue Intro. Später unter **Dein Weg → Profil → Intro erneut ansehen** wiederholen.

## Danach ausprobieren

- Intro: Name, optionales Alter, Ziel und Schwierigkeit.
- Bewegen: Liegestütze, Kniebeugen, Plank und Schritte verbinden.
- Heute: Bildschirmzeit erlauben, Apps auswählen, verdientes Guthaben einlösen.
- Fokus: Dauer und Aufgabe wählen; Stille, White Noise, Brown Noise oder Meeresrauschen.
- Abend: Nachtpause, Abendritual, Klänge mit Abschalttimer, Wecker.
- Dein Weg: Detox-Programm, Tipps, Freunde und persönliche Rekorde.

## Belohnungen

- Liegestütz / Kniebeuge: Sanft 15 Sekunden, Ausgewogen 30 Sekunden, Ambitioniert (schwer) 1 Minute pro Wiederholung. Die Schwierigkeit findest du im Profil.
- Plank: 10 gültig erkannte Sekunden ergeben 1 Minute. Unterbrechungen pausieren die Gesamtzeit und beenden die laufende PR-Haltung.
- Schritte: 1.000 Schritte ergeben 1 Minute, maximal 10 Minuten pro Tag. Beim Öffnen werden heutige iPhone-Schritte nachgeladen. Apple-Watch-/Health-Daten werden nicht importiert.
- Tageslimit: begrenzt das Einlösen, nicht das Sammeln. Fokus, Nachtpause und Hardcore-Detox pausieren das Einlösen vollständig.

## Update auf TestFlight / App Store hochladen

1. Version ist **1.2.2**, Build **5**. Wenn Build 5 bereits hochgeladen wurde, bei beiden Targets dieselbe höhere Build-Nummer einstellen.
2. Für beide Targets müssen **App Groups** (`group.com.ziar.unscroll`) und **Family Controls** in den Apple-Profilen freigegeben sein. Distribution benötigt Apples Freigabe für Family Controls. Game Center im bestehenden App-Store-Connect-Eintrag aktivieren, damit Freunde funktionieren.
3. Zuerst auf dem echten iPhone die Punkte aus `VALIDATION.md` prüfen.
4. In Xcode **Any iOS Device (arm64)** wählen → **Product → Archive** → im Organizer **Distribute App → App Store Connect → Upload**.
5. Nach Apples Verarbeitung den neuen Build in TestFlight auswählen. Eine GitHub-Änderung oder diese ZIP allein aktualisiert die installierte App nicht.

Nicht stören, True Tone und Graustufen werden über iOS bedient. Unscroll zeigt dafür Anleitungen. Der Systemwecker ab iOS 26 verwendet AlarmKit; auf älteren Systemen sind nur ausdrücklich als solche bezeichnete Erinnerungen verfügbar. Es gibt keine Schlafphasenmessung.

## Stand dieser Fortsetzung

**Quellcode zur Prüfung:** Den Stand der automatischen Tests und des Simulator-Builds
findest du im zugehörigen GitHub-Actions-Lauf. Ein erfolgreicher Lauf ersetzt keinen
Kameratest auf einem echten iPhone. Bitte vor der Veröffentlichung neu bauen und testen.

Die Kamera sucht passend zur Übung nach den nötigen Körperpunkten. Die neue Erkennung
muss auf einem echten iPhone mit Liegestützen, Kniebeugen und Plank geprüft werden.
Unter „Erkennung prüfen“ lassen sich sichtbare Punkte und Verarbeitungszeit ablesen.
Der Weckton wird innerhalb von 29 Sekunden lauter; ein durchgehender 30-Minuten-Anstieg
ist noch nicht umgesetzt. Die ZIP ist Quellcode, kein bereits hochgeladener TestFlight-Build.
