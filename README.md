# Marine Outpost — 0.8

Sci-Fi-Tower-Defense für Windows in Godot 4.6. Spielbarer Entwicklungsstand mit freiem Turmbau, zufälligen Routen und Forschung zwischen Einsätzen.

## Start

ZIP in einen neuen Ordner entpacken, `project.godot` in Godot 4.6 importieren und **F5** drücken. Im Hauptmenü **Operation starten** wählen.

## Neu in 0.8

- **32 Modelle:** zwölf neue Umgebungsteile ergänzen die bisherigen Türme, Gegner und Straßen. Neue Kisten, Munition, Generatoren, Funkmast, Flutlicht, Rohrverteiler, Krater, Trümmer, Rover-Wrack, Feldlazarett, Ruine und Kontrolltor.
- **Mattere, gebrauchte Oberflächen:** gemeinsame Lack- und Rauheitstexturen mit Kratzern und Pitting; zurückgenommene Reflexionen und überarbeiteter Boden.
- Unterschiedliche Koloniebereiche ersetzen die gleichförmigen Reaktor- und Barrikadenreihen. Straßen erhalten seltener wiederholte Quarantänemuster.
- **Jede neue Version mit eigener Spielvorschau.** `./tools/preview.sh` rendert und prüft Bilder sowie Metadaten; frühere Vorschauordner bleiben erhalten.

![Version 0.8 – arrangierte Spielszene aus dem Build](docs/previews/v0.8.0/battle.png)

[Nähere Spielansicht](docs/previews/v0.8.0/closeup.png) · [Galerie mit 32 Assets](docs/previews/v0.8.0/gallery.png) · [Screenshot-Ablauf](docs/PREVIEWS.md)

Das Menü **Modellgalerie / 32 Assets** zeigt alle Modelle einzeln mit Zoom und als Übersicht. [Asset-Liste und Blender-Quelle](models/README.md).

## Aus Version 0.6

- **Frei platzieren:** keine vorgegebenen Bauplätze, kein Raster. Straßen, Rand und andere Türme bleiben frei. Vorschau mit Reichweite, gültiger/ungültiger Farbe und Begründung.
- **Zufällige Lane pro neuem Einsatz.** Der Seed wird mitgespeichert, die Route ändert sich nicht während eines laufenden Runs.
- **Kontext-UI:** Baukarten beim Bauen; beim Turmklick wechseln sie zu Werten, Upgrades, Spezialisierungen, Zielwahl und Verkauf. Rechtsklick oder Esc hebt die Auswahl auf.
- **Credits springen hoch:** Jeder Abschuss zeigt eine animierte goldene Münze und den tatsächlichen Betrag über dem Gegner.
- Neuer Boden mit prozeduraler Struktur, beleuchtete Straßenränder, weniger Schilder, runde Zombie-Körper und neue Turmsockel. Kulissen stehen außerhalb des Baugebiets.


## Steuerung

| Aktion | Eingabe |
| --- | --- |
| Turm zum Bauen wählen | 1 / 2 / 3 oder Baukarte |
| Frei platzieren | Linksklick neben der Straße |
| Turm auswählen | Linksklick auf Turm |
| Bau/Selektion abbrechen | Rechtsklick / Esc |
| Kamera bewegen / zentrieren | WASD / F |
| Zoom | Mausrad |
| Overdrive | Q |
| Pause / Menü | Leertaste; Esc ohne aktive Auswahl |
| Manuell speichern | F5 im laufenden Spiel oder Menü |
| Vollbild | F11 |

Marine $60, Mörser $110, Kryo $85. Ab MK 3 stehen pro Turm zwei Spezialisierungen zur Wahl. Verkauf erstattet 70 % der Investition. Höchstens 80 Türme pro Einsatz.

Wellen starten automatisch nach zwölf Sekunden Vorbereitung und acht Sekunden Baupause. Sprinter ab Welle 2, Panzer ab Welle 3, Titan alle fünf Wellen. Du hast 30 Leben; Titans kosten bei Durchbruch fünf. Overdrive verdoppelt die Feuerrate acht Sekunden lang.

## Fortschritt und Spielstände

Forschung, Spezialisierungen und Zielprioritäten aus [Version 0.5](docs/VERSION_0_5.md) bleiben erhalten. Autosave alle 20 Sekunden außerhalb der Pause und nach abgewehrten Wellen. Beim nächsten Start **Spielstand fortsetzen** wählen.

0.6 speichert freie Koordinaten und den Karten-Seed in **`run_v2.json`**. Die alten festen Run-Spielstände aus 0.5 (`run_v1.json`) sind nicht kompatibel und werden nicht verändert. **Forschung, Rekorde und Einstellungen bleiben erhalten.** Details: [Version 0.6](docs/VERSION_0_6.md).

## Tests

```sh
godot --headless --path . --script res://game/smoke_test.gd
godot --headless --path . --script res://game/smoke_3d.gd
godot --headless --path . --script res://game/smoke_progression.gd
godot --headless --path . --script res://game/smoke_maps.gd
godot --headless --path . --script res://game/smoke_models.gd
```

Tests schreiben Nutzerdaten. Verwende separate `XDG_DATA_HOME`, `XDG_CONFIG_HOME` und `XDG_CACHE_HOME`. Die Grafik wird zusätzlich mit OpenGL unter Linux geprüft; Windows-Leistung und Audio benötigen eigene Spieltests. Screenshots zeigen arrangierte Situationen im tatsächlichen Build.

Multiplayer und Steam-Anbindung fehlen noch. Siehe [Roadmap](docs/ROADMAP.md) und [Release-Qualitätsziel](docs/RELEASE_TARGET.md). Der alte 2D-Prototyp bleibt als separate Szene `game/main.tscn` erhalten.
