# Version 0.5 — Forschung und Spezialisierung

## Mehr Entscheidungen im Einsatz

Ab **MK 3** kann jeder Turm einmalig eine von zwei Spezialisierungen erhalten. Kosten: doppelte Grundbaukosten, zusätzlich zu den regulären Upgrades. Die Wahl bleibt bis zum Verkauf bestehen; die Investition zählt beim Verkauf mit.

| Turm | Weg A | Weg B |
| --- | --- | --- |
| Marine | Scharfschütze: 2,2× Schaden, +80 Reichweite, 1,5× Schussintervall | Sturmgeschütz: 0,55× Schussintervall, 0,85× Schaden |
| Mörser | Belagerung: 1,8× Schaden, 1,25× Schussintervall | Streubomben: Radius 115 statt 70, 0,85× Schaden |
| Kryo | Tiefkälte: Gegner auf 25 % Tempo für 3,5 Sekunden | Feldkontrolle: +85 Reichweite, 0,55× Schussintervall |

Das Schussintervall ist die Wartezeit zwischen Schüssen: kleiner bedeutet schneller. Normale MK-Upgrades und Forschung wirken zusätzlich. Über Tooltips lassen sich die Unterschiede im Spiel nachlesen.

Neue Zielprioritäten: **Erster** (am weitesten auf der Route), **Stärkster** (höchste aktuelle HP), **Nächster** (geringste Entfernung). Nur Gegner in Reichweite werden beschossen. Turm-Schilder zeigen Namen und MK-Stufe; spezialisierte Modelle erhalten zusätzliche leuchtende Bauteile. Verlangsamte Gegner erhalten blaue HP-Balken, Titans eine eigene Beschriftung und Schulterpanzer.

## Forschung zwischen Einsätzen

Eine abgewehrte Welle bringt einen Forschungspunkt, eine Titan-Welle drei. Im Pausenmenü öffnet **Forschung** das Kolonie-Labor:

- Ballistik: +5 % Turmschaden je Stufe.
- Logistik: +$25 Startkapital je Stufe.
- Energietechnik: −3 Sekunden Overdrive-Abklingzeit je Stufe.

Jeder Bereich hat fünf Stufen. Käufe kosten 3, 6, 9, 12 und 15 Punkte. Forschung wird lokal gespeichert. Neue Boni gelten für einen neuen Einsatz; ein bereits begonnener oder geladener Run behält seine damaligen Boni. Einmal vergebene Wellenpunkte werden bei erneutem Laden nicht noch einmal vergeben. Dies ist lokale Einzelspieler-Progression, kein manipulationssicheres Online-Profil.

## Speichern und Fortsetzen

- Autosave alle 20 Sekunden außerhalb der Pause und nach abgewehrten Wellen.
- Manuell über **Einsatz speichern** im Menü oder **F5 im laufenden Spiel**.
- Beim Beenden eines begonnenen Einsatzes wird gespeichert.
- Nach Neustart **Spielstand fortsetzen** wählen. Alternativ **Spielstand laden**, anschließend **Einsatz fortsetzen**.
- Gespeichert werden Gegnerpositionen/HP/Status, Türme und Spezialisierungen, Wirtschaft, Welle, Spawnstatus, Forschung im Run, Overdrive und Timer. Kurzlebige grafische Effekte und die Kameraposition werden nicht gespeichert.
- Neue Einsätze ersetzen den aktuellen Spielstand nach Bestätigung. Forschung und Rekorde bleiben bestehen. Nach einer Niederlage wird der Run-Spielstand gelöscht.

Spielstandformat Version 1 mit Kartenkennung, Werteprüfung und vorheriger `.bak`-Datei. Eine beschädigte oder inkompatible Hauptdatei wird nicht in den laufenden Zustand übernommen; eine gültige Sicherung wird als Alternative versucht. Es gibt einen lokalen Run-Slot, keine Steam-Cloud-Synchronisierung.

Windows-Speicherort: `%APPDATA%/Godot/app_userdata/Marine Outpost/`. Dateien: `run_v1.json`, `research_v1.json`, `scores.cfg`, `settings.cfg`. Beim Entpacken einer neuen Projektversion bleiben diese lokalen Nutzerdaten erhalten.

## Validierung und Grenzen

Die vorhandenen Gameplay- und 3D-Tests werden um `game/smoke_progression.gd` ergänzt. Geprüft werden sechs Upgrade-Wege, Forschungskauf und verzögerte Boni, Zielwahl, Speichern/Laden einer laufenden Welle, Wiederherstellung aus Sicherung, Zurückweisen ungültiger Daten, doppelte Forschungsbelohnungen und Autosave-/Niederlagenverhalten.

Weiterhin ein Entwicklungsstand: eine Karte, drei Grundtürme, einfache originale Modelle und Soundeffekte. Neue Systeme benötigen Balance- und Windows-Spieltests. Multiplayer und Steam-Anbindung bleiben ausstehend.
