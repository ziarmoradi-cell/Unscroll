# Prototyp 0.2 – Implementierungsstand

Stand: 5. September 2026. Browser-Vorschau lokal funktionsgeprüft. Der native Swift-Code ist nicht kompiliert; GitHub hat das Hochladen mit HTTP 403 „Resource not accessible by integration“ verweigert. Die Verbindung zeigt keine GitHub-App-Installation. Das Repository wurde nicht verändert. Kein Codemagic-Build gestartet. Siehe [TEST-RESULTS.md](TEST-RESULTS.md).

| Funktion | Umsetzung | Noch zu prüfen / begrenzt |
|---|---|---|
| Gemeinsames Zeitkonto | Lokales Guthaben, App-Auswahl, Screen-Time-Monitor, Sperren | Echtes iPhone und Apple-Berechtigungen erforderlich |
| Kameraübungen | Vision für Liegestütze, Squats, Plank, Sit-ups; lokale Gelenkwinkel-Auswertung | Experimentell; keine trainierte Betrugserkennung; Aufnahme, Ausrichtung und Bewegungserkennung auf Gerät prüfen |
| Personalisierung | Vorname, Geburtstag, Ziele, Umrechnung, Tageshinweise | Regelbasierter Assistent, kein freier KI-Chat |
| Wochenbericht | Übungswerte, freigegebene und iOS-bestätigte Zeit, Ausnahmen, Rekorde | iOS-Rückmeldungen können verzögert oder unvollständig sein; keine App-Einzelstatistik |
| Emergency | Fünf Minuten Ausnahme, nach erfolgreichem Start gezählt | Keine Ausnahme während aktiver Sitzung |
| Freunde / Anmeldung | Game-Center-Anmeldung, Freunde-Einladung, Ranglistenansicht, ausdrückliches Teilen der Trainingswerte | Apple-Portal-Konfiguration und Mehrgerätetest fehlen |
| Challenges | Lokale Sieben-Tage-Challenge, Game-Center-Dashboard | Eigene geteilte Challenges mit gemeinsamem Start und Ende noch offen |
| Abendbegleitung | Wiederkehrende Abend- und Wochenhinweise, True-Tone-Anleitung | Keine automatische Änderung von True Tone |
| Wecker | AlarmKit ab iOS 26, täglich, eigener sanfter Ton, ausschaltbar | Auf Gerät noch nicht geprüft, kein Snooze |
| Cloud-Build | Codemagic-Prüf- und Ad-hoc-Workflows; GitHub-Prüfung | Codemagic-Konto und Signierung noch nicht verbunden |
| Browser-Vorschau | Bedienbare lokale Simulation, neun bestandene Kontologik-Tests und automatisierter Browser-Durchlauf | Keine echten App-Sperren, Kamera- oder Kontoverbindungen |

## Zeitkonto-Regeln dieses Prototyps

Übungen buchen Minuten in die Bank. Eine Freigabe reserviert bis zu 30 Minuten gemeinsam für alle ausgewählten Apps. Während der Sitzung verdiente neue Minuten bleiben in der Bank für die nächste Freigabe. Ein iOS-Ereignis pro Minute aktualisiert den Messstand. Nach vollständigem Verbrauch aktiviert die Erweiterung die Sperre. Eine Sitzung endet spätestens nach 23 Stunden. Bei Abbruch oder Ablauf werden nicht verwendete reservierte Minuten nicht zurückerstattet, weil ein verspäteter Messstand sonst eine falsche Rückbuchung ermöglichen könnte. Diese vorläufige Regel ist in der App sichtbar; ein nahtloses, exakt abgerechnetes Dauer-Zeitkonto ist noch nicht fertig.

## Offene Voraussetzungen für eine iPhone-Installation

Der Nutzer hat noch keine Apple-Developer-Mitgliedschaft. Der signierte Codemagic-Build kann daher noch nicht eingerichtet und ausgeführt werden. Er benötigt App- und Erweiterungs-IDs, App Group, passende Family-Controls-Freigaben, Ad-hoc-Profile einschließlich der registrierten iPhone-UDID und ein Zertifikat. Für TestFlight gelten entsprechende Distributionsvoraussetzungen. Zugangsdaten gehören in Codemagic, nicht ins Repository oder in den Chat.

## Daten

Geburtsdatum, Übungen und Zeitkonto bleiben in der lokalen App Group. Die Kamera wird lokal ausgewertet und zeichnet keine Videos auf. Game Center bekommt Trainingswerte erst nach Zustimmung und Betätigung des Übertragen-Knopfs. Es erhält weder Geburtstag noch Screen-Time-Daten. Es gibt noch keinen Cloud-Backup- oder Kontolöschungsprozess; Game Center verwaltet seine eigenen Konten.

## Gerätetest vor Freigabe

1. Kamera erlauben/ablehnen, unterbrechen, App in den Hintergrund schicken; keine Gutschrift bei Trackingverlust.
2. Mindestens zehn echte Durchgänge jeder Übung bei unterschiedlichen Lichtverhältnissen und Körperpositionen prüfen. Fehlzählungen protokollieren.
3. Zwei Social-Media-Apps sperren, Zeit verdienen, zwischen beiden wechseln. Home-Bildschirm und andere Apps dürfen nicht zählen.
4. Verbrauch, erneutes Freigeben, Emergency, App-Neustart, Geräteneustart, Tages- und Zeitzonenwechsel prüfen.
5. Erzwungenen Speicher-/Monitoringfehler prüfen; die App darf keine erfolgreiche Freigabe vortäuschen.
6. Wecker in wenigen Minuten ausprobieren, mit Lautlosmodus und Fokus; Ton und Ausschalten prüfen.
7. Game-Center-Anmeldung, Einladen und Ranglisten mit zwei echten Konten testen.

## Quellen

- [Apple Screen Time](https://developer.apple.com/documentation/deviceactivity/deviceactivityevent)
- [Apple Family Controls](https://developer.apple.com/documentation/familycontrols/requesting-the-family-controls-entitlement)
- [Apple Vision](https://developer.apple.com/documentation/vision/detecting-human-body-poses-in-images)
- [Apple AlarmKit](https://developer.apple.com/videos/play/wwdc2025/230/)
- [Apple Game Center](https://developer.apple.com/documentation/gamekit/gkleaderboard)
- [Codemagic iOS-Signierung](https://docs.codemagic.io/yaml-code-signing/signing-ios/)
