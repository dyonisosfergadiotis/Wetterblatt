# Codex Build Prompt — Wetterblatt

Baue eine iOS-Wetter-App namens `Wetterblatt` in SwiftUI. Die App soll sich visuell wie ein ruhiges, analoges Wetterjournal anfühlen: cremefarbener Papierhintergrund, feine Borders, serif-basierte Hero-Werte, monospace Labels, subtile Wetterakzente, leichte Grain-Textur. Die App darf nicht generisch oder wie ein SwiftUI-Template aussehen.

Die wichtigste Produktanforderung ist Zeitwahrheit bei gleichzeitigem Offline-Verhalten:

- Die App muss Forecast-Daten lokal persistieren und beim Start zuerst den Cache rendern.
- Wenn neue Daten verfügbar sind, müssen sie inkrementell in den vorhandenen Snapshot gemerged und gespeichert werden.
- `Current weather` und alle Zeitangaben müssen immer relativ zur aktuellen lokalen Zeit des Ortes berechnet werden, nicht relativ zum letzten Fetch.
- Die UI darf nie „in der Vergangenheit hängen“. Die Stundenleiste muss immer ab `jetzt` bzw. dem passenden aktuellen Slot gerendert werden; vergangene Slots dürfen sichtbar sein, aber nicht als aktuell markiert werden.
- Wenn keine frische Beobachtung verfügbar ist, soll die App das aktuelle Panel aus dem passendsten stündlichen Forecast-Slot für `now` ableiten und klar als Cache/Fallback kennzeichnen.
- Sonnenaufgang, Sonnenuntergang und relative Zeitlabels müssen sich auch ohne neuen Network-Call weiter aktualisieren.
- Offline ist ein benutzbarer Zustand: zeige den letzten Snapshot mit Freshness-Hinweis, kein leerer Fehlerbildschirm.

Technische Leitplanken:

- Nutze SwiftUI, Observation, async/await, URLSession, CoreLocation und SwiftData nur dort, wo es sinnvoll ist.
- Verwende einen `WeatherRepository` als Single Source of Truth.
- Implementiere getrennte Bausteine für:
  - `ForecastCacheStore`
  - `SnapshotMerger`
  - `CurrentWeatherResolver`
  - `ForecastTimelineResolver`
  - `WeatherClock` mit minütlichem Tick
  - `RefreshCoordinator`
- Speichere pro Ort einen Forecast-Snapshot inklusive `fetchedAt`, Quell-Zeitzone, UTC-Offset, current/hourly/daily Daten und Freshness-Metadaten.
- Halte UI-IDs stabil, damit ein Refresh nicht Scroll-Positionen oder aktive Chart-Selektion unnötig zurücksetzt.
- Reagiere auf `scenePhase`, App-Start, Pull-to-refresh und sinnvolle Background-Refresh-Trigger.

Views und UX:

- `AppShellView` mit Tabs für `Home`, `Detail`, `Week`, `Places`
- `HomeView` zeigt Hero-Temperatur, Ort, Freshness Stamp, Offline Banner, Hourly Rail und Kernmetriken
- `DetailView` zeigt interaktive Charts mit Scrubbing und Haptik
- `WeekView` zeigt 7- bis 10-Tage Forecast
- `PlacesView` verwaltet Orte und zeigt letzten bekannten Aktualisierungsstand je Ort
- Verwende eine visuelle Sprache wie in den Workmaps: Print/Vintage, nicht glossy, nicht standardmäßig lila oder default iOS-cardy

Wichtige Implementierungsregeln:

- Render zuerst den Cache, dann refresh im Hintergrund
- Mergen nach Zeitstempel-Key statt blind alles zu ersetzen
- Ortszeit immer korrekt behandeln; keine Mischungen zwischen Device-Zeit und Ortszeit
- `now` kommt aus einem laufenden Clock-Service, nicht aus dem API-Response
- Wenn ein neuer Stundenslot beginnt, muss sich die UI automatisch aktualisieren
- Wenn Netz fehlt, weiterhin den aktuellen Slot aus dem vorhandenen Forecast ableiten
- Alle User-Facing Status-Texte müssen ehrlich sein: `Offline`, `Stand 14:08`, `Neue Daten eingetroffen`, `Keine frischen Beobachtungen`

Akzeptanzkriterien:

- App startet mit deaktiviertem Netz und zeigt sofort einen brauchbaren Forecast aus dem Cache
- Hourly Forecast zeigt nach 15:00 nicht weiter 14:00 als aktiven Slot
- `Current weather` wirkt auch offline wie `jetzt`, ohne zu behaupten, live gemessen zu sein
- Nach erfolgreichem Refresh werden nur geänderte Daten aktualisiert und persistiert
- Zeitlabels, Sonnenereignisse und Freshness-Hinweise bleiben korrekt, während die App offen ist
- Der UI-Look entspricht einem absichtlichen, hochwertigen Vintage-Wetterprodukt

Arbeite sauber in Schichten, verwende präzise Typen und liefere eine implementierte, lauffähige App statt nur einer Demo-Struktur.
