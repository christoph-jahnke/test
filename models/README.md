# Asset-Pack 01 — 20 originale GLB-Modelle

Alle Modelle werden aus dem mitgelieferten Blender-Quellskript erzeugt. Keine externen Modelle oder Textur-Downloads. Godot importiert die GLBs direkt; Blender ist zum Spielen nicht erforderlich.

| Nr. | Modell | Gestaltung / Einsatz |
| --- | --- | --- |
| 01 | Sentinel | Marine-Grundturm, Zwillingsläufe, Patronenzufuhr, Optik, gepanzerter Drehkranz |
| 02 | Bulwark | Mörser, Rohr, Rückstoßzylinder, Granatenracks |
| 03 | Prism | Kryoturm, Kühlspiralen, leuchtender Kern, Tanks |
| 04 | Lancer | Scharfschütze, lange Beschleunigerschienen, Mündungsbremse und Scope |
| 05 | Reaper | Sturmgeschütz, sechs Gatling-Läufe, eigener rotierender Rotor, Munitionstrommel |
| 06 | Judgement | Belagerungsgeschütz, schweres erhöhtes Rohr und Recoil-Schild |
| 07 | Hydra | Drei einzelne Granatwerferrohre |
| 08 | Zero | Tiefkälte, Kristallspitzen und Kryo-Emitter |
| 09 | Pulse | Feldkontrolle, Mast, Emitterring und Strahler |
| 10 | Infizierter | Zerrissene Uniform, offene Rippen, Klauen, verletztes Gesicht |
| 11 | Hetzer | Schmaler Körper, Rückendornen, längliche Proportionen |
| 12 | Panzer-Infizierter | Brust- und Schulterpanzer, beschädigter Helm und Visor |
| 13 | Titan | Asymmetrische Muskelmasse, nekrotische Wucherungen, Knochensporne und eingelassene Fesseln |
| 14 | Asphalt | Befestigte Fahrbahn mit Narben und Markierungen |
| 15 | Stahlweg | Drainagegitter und seitliche Leitungen |
| 16 | Quarantäneweg | Warnstreifen, Beacons und Blutspur |
| 17 | Ruinenweg | Risse, abgebrochene Kanten und freiliegende Bewehrung |
| 18 | Kommando-Bunker | Schweres Tor, Lüftung, Stencil und Antenne |
| 19 | Reaktor R-09 | Gestapelte Ringe, Core-Fenster und Kühlrohre |
| 20 | Barrikade | Betonkörper, Hazard-Lackierung und echte Rasierdraht-Geometrie |

## Bearbeiten / reproduzieren

Blender 4.3.2 wurde für den Export verwendet:

```sh
blender -b --threads 4 --python tools/build_models.py
# Nur einzelne Modelle aktualisieren:
blender -b --threads 4 --python tools/build_models.py -- --only=5,10,11,12,13
```

Das Skript überschreibt die gewählten generierten GLBs. Eigene GLB-Änderungen vorher sichern. Ein vollständiger Export erzeugt alle 20 Dateien. Die Materialien sind eingebettet, mit Grundfarbe, Metallanteil, Rauheit und ausgewählten Emissionsflächen. Kanten sind abgeschrägt und Normalen gewichtet. Modellteile sind nach Material und beweglichem Bauteil zusammengefasst.

Godot erzeugt beim Import automatisch LODs und Schatten-Meshes. Die 20 Modelle haben zusammen ungefähr 167.000 Dreiecke im höchsten Detailgrad. Instanzen im Spiel vervielfachen die tatsächlich sichtbare Geometrie; diese Zahl ist kein Performance-Nachweis für große Horden.

## Integration

`game/asset_catalog.gd` registriert alle Assets. Neun Turmkombinationen verwenden neun verschiedene Waffenmodelle. Gegner werden nach Typ gewählt. Straßenvarianten wechseln zwischen Abschnitten der Seed-Route; sie verändern bislang die Optik, nicht die Bewegungsgeschwindigkeit. Bunker, Reaktoren und Barrikaden stehen in der Kolonie.

Benannte `Head`- und `Rotor`-Knoten ermöglichen Zielen und Gatling-Rotation. Gegner besitzen `LegL`, `LegR`, `ArmL` und `ArmR` für einfache Laufbewegungen. Dies ist eine einfache Teilhierarchie, keine vollständig geskinte Charakteranimation.

Die Baukarten zeigen kleine, direkt aus den GLBs gerenderte Portraits. `tools/capture_portraits.gd` erzeugt sie mit einer grafischen Godot-Instanz erneut.

Im Spielmenü öffnet **Modellgalerie / 20 Assets** die Nahansicht mit Zoom, Einzelwahl und Gesamtansicht. Vor dem Wechsel wird ein laufender Run gespeichert. GLBs können auch direkt in Godot oder Blender geöffnet werden.

Die Modelle sind ein erster stilisierter Produktionsschritt. Handgemalte/gebakte Texturen, hochwertige Skinning-Animationen und gründliche Windows-Performance-Tests bleiben ausstehend.
