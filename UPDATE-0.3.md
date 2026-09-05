# Unscroll 0.3 – Einstieg, Modi und Schritte

- Erster Start: Willkommen, Vorname, Geburtstag, Modus, Tagesziel. Nach Abschluss bleibt das Profil gespeichert.
- Beginner ×3, Normal ×2, Schwierig ×1. Standard ist Normal.
- Eine Wiederholung (Liegestütze, Squats oder Sit-ups), 30 volle Sekunden Plank oder 1.000 Schritte bringen 3 / 2 / 1 Minuten. Plank-Restsekunden werden pro Einheit abgerundet.
- Der Modus kann im Profil geändert werden. Bestehendes Guthaben und bereits gutgeschriebene Einheiten bleiben unverändert.
- Schritte: aktuelle Tageszahl, Fortschritt zum nächsten Tausender, ausdrückliche Gutschrift und Wochenübersicht. Ein Tausender wird nur einmal eingelöst, auch nach Neustart und Moduswechsel. Restschritte und nicht eingelöste Tagesblöcke werden nicht in den nächsten Tag übertragen.
- Native Schrittzahl: Core Motion, nach Zustimmung zu Bewegung & Fitness; manuell und bei Rückkehr zur Startansicht aktualisiert. Gezählt wird das iPhone, ohne HealthKit oder Apple-Watch-Abgleich. Die bei der ersten Schrittabfrage verwendete Zeitzone bleibt für die Tagesabrechnung fest, damit Reisen keine Doppelgutschriften erzeugen.
- Die Browser-Vorschau simuliert Schritte mit dem Knopf „+500 Schritte“. Kamera, Bildschirmzeit und Freunde bleiben Simulationen.

Die Apple-Developer-Anmeldung ist laut Nutzer noch Pending. TestFlight-Signierung und Gerätetests stehen aus. Der TestFlight-Workflow liegt auf dem Zweig prototype/ios-build und benötigt weiterhin die Apple-Einrichtung.

Prüfung: zwölf Browser-Logiktests sowie automatisierter Ablauf für Intro, Speicherung, Schritte, Moduswechsel, Nutzung und Wochenübersicht erfolgreich. Zehn Layoutprüfungen für 390 und 1440 Pixel Breite ohne horizontalen Überlauf. Neue native Tests prüfen Multiplikatoren, Plank-Grenzen, Schritt-Doppelgutschriften und Migration alter Daten. Ergebnis der iOS-Cloud-Prüfung siehe GitHub Actions.
