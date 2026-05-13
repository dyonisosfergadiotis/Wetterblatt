# Wetterblatt

Wetterblatt ist eine moderne, datenschutzfreundliche Wetter‑App mit Widgets. Sie liefert präzise Vorhersagen, clevere Übersichten und eine klare, deutschsprachige Oberfläche – auf iPhone, iPad und macOS.

![Badge Swift](https://img.shields.io/badge/Swift-6.0-orange)
![Badge Platform](https://img.shields.io/badge/Plattformen-iOS%20%7C%20iPadOS%20%7C%20macOS-blue)
![Badge License](https://img.shields.io/badge/License-MIT-green)

## Inhaltsverzeichnis
- [Features](#features)
- [Screenshots](#screenshots)
- [Tech-Stack](#tech-stack)
- [Voraussetzungen](#voraussetzungen)
- [Installation](#installation)
- [Nutzung](#nutzung)
- [Konfiguration](#konfiguration)
- [Architektur](#architektur)
- [Tests](#tests)
- [Roadmap](#roadmap)
- [Beitragen](#beitragen)
- [Lizenz](#lizenz)
- [Kontakt](#kontakt)

## Features
- Ortssuche und Umkreissuche mit Open‑Meteo Geocoding und System‑Geocoder (Core Location/MapKit)
- Stündliche und tägliche Vorhersagen inkl. Temperaturspanne, Niederschlag, Wind und Luftfeuchte
- Intelligente Labels (z. B. „Jetzt“, „Heute“, „Morgen“) und kompakte Kurzlabels für Widgets
- Widgets mit gemeinsam genutzten Daten (App Group) und anpassbaren Einheiten (°C/°F, km/h/m/s, mm/in)
- Offline‑freundliche Caches für Vorhersagen und Einstellungen (JSON im App‑Container)
- Barrierearme Darstellung mit reduzierbaren Motion‑Effekten und klarer Typografie

## Screenshots
Füge hier 1–3 aussagekräftige Screenshots oder GIFs ein.

<img src="Docs/screenshot1.png" width="320" />
<img src="Docs/screenshot2.png" width="320" />

## Tech-Stack
- Sprache: Swift (Swift Concurrency, Actors)
- Frameworks: SwiftUI, Combine, Core Location, MapKit, WidgetKit
- Datenhaltung: JSON‑Dokumente (Settings, Places, Forecast Cache)
- App Group: `group.DyonisosFergadiotis.Wetterblatt` (Shared Store für Widgets)

## Voraussetzungen
- Xcode 15+ (empfohlen: aktuelle Version)
- iOS/iPadOS 17+ und/oder macOS 14+
- Optional: App Group Capability für Widgets (siehe Konfiguration)

## Installation
Klonen des Repos und öffnen in Xcode:

```bash
git clone <Repo-URL>
cd Wetterblatt
