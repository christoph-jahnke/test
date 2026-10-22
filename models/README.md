# Asset-Packs 01–02 — 32 originale GLB-Modelle

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
| 21 | Versorgungskiste | Verschlüsse, Tragegurte, Materialnummer |
| 22 | Munitionslager | Offenes Granatenrack |
| 23 | Hilfsgenerator | Lüftung, Abgasrohr, Schalttafel |
| 24 | Funkmast | Verstrebungen, Antennen, Beacon |
| 25 | Flutlicht | Doppel-Scheinwerfer mit Schutzkäfig |
| 26 | Rohrverteiler | Ventile, Flansche und Rohrbrücken |
| 27 | Einschlagkrater | Flache Rußmulde und gebrochene Randstücke |
| 28 | Trümmerfeld | Flache Schuttplatten und freiliegende Bewehrung |
| 29 | Rover-Wrack | Verbrannter Wagen, verbogene Haube und beschädigte Scheibe |
| 30 | Feldlazarett | Sanitätsunterkunft mit Kreuz und Trägern |
| 31 | Habitat-Ruine | Offene Gebäudeseite und gebrochene Dachkante |
| 32 | Kontrolltor | Quarantäne-Bogen und Signalleuchten |

## Bearbeiten / reproduzieren

Blender 4.3.2 wurde für den Export verwendet:

```sh
blender -b --threads 4 --python tools/build_models.py
# Nur einzelne Modelle aktualisieren:
blender -b --threads 4 --python tools/build_models.py -- --only=5,10,11,12,13
```

Das Skript überschreibt die gewählten generierten GLBs. Eigene GLB-Änderungen vorher sichern. Ein vollständiger Export erzeugt alle 32 Dateien. Die Grundmaterialien sind eingebettet, mit Grundfarbe, Metallanteil, Rauheit und ausgewählten Emissionsflächen. Ab 0.8 ergänzt der Asset-Katalog gemeinsam verwendete, prozedurale Lack- und Rauheitstexturen mit Kratzern und Pitting. Leuchtflächen bleiben ausgespart. Die mattere Oberflächenbehandlung verändert auch die bisherigen 20 Modelle. Kanten sind abgeschrägt und Normalen gewichtet. Modellteile sind nach Material und beweglichem Bauteil zusammengefasst.

Godot erzeugt beim Import automatisch LODs und Schatten-Meshes. Die 32 Modelle haben zusammen knapp 200.000 Dreiecke im höchsten Detailgrad. Instanzen im Spiel vervielfachen die tatsächlich sichtbare Geometrie; diese Zahl ist kein Performance-Nachweis für große Horden.

## Integration

`game/asset_catalog.gd` registriert alle Assets. Neun Turmkombinationen verwenden neun verschiedene Waffenmodelle. Gegner werden nach Typ gewählt. Straßenvarianten wechseln zwischen Abschnitten der Seed-Route; sie verändern bislang die Optik, nicht die Bewegungsgeschwindigkeit. Bunker, Reaktoren und Barrikaden stehen in der Kolonie.

Benannte `Head`- und `Rotor`-Knoten ermöglichen Zielen und Gatling-Rotation. Gegner besitzen `LegL`, `LegR`, `ArmL` und `ArmR` für einfache Laufbewegungen. Dies ist eine einfache Teilhierarchie, keine vollständig geskinte Charakteranimation.

Die Baukarten zeigen kleine, direkt aus den GLBs gerenderte Portraits. `tools/capture_portraits.gd` erzeugt sie mit einer grafischen Godot-Instanz erneut.

Im Spielmenü öffnet **Modellgalerie / 32 Assets** die Nahansicht mit Zoom, Einzelwahl und Gesamtansicht. Vor dem Wechsel wird ein laufender Run gespeichert. GLBs können auch direkt in Godot oder Blender geöffnet werden.

Die Modelle sind ein erster stilisierter Produktionsschritt. Handgemalte/gebakte Texturen, hochwertige Skinning-Animationen und gründliche Windows-Performance-Tests bleiben ausstehend.

## Überarbeitung 0.9

Die neun Türme und vier Monster wurden neu exportiert. Turmfamilien besitzen unterschiedliche Hull-Farben und Standfüße; Waffen und Kühltechnik wurden weiter ausgearbeitet. Die vier Gegner haben durchgehende Brustkorb-Meshes, verletzte Körper, kleinere Köpfe und zusätzliche Gelenke `Body`, `ShinL/R` und `ForearmL/R`. Die Laufanimation und die Kampfreaktionen werden im Spielcontroller gesteuert. Alle bisherigen Asset-IDs bleiben erhalten.

Die Galerie zeigt über **T** die neun Waffenplattformen und über **M** die vier Gegnertypen. Die neun Turmportraits sind echte Godot-Renderings der jeweiligen GLBs in 160 × 160 Pixeln.

Nur die Kampfmodelle neu bauen:

```sh
blender -b --threads 4 --python tools/build_models.py -- --only=1,2,3,4,5,6,7,8,9,10,11,12,13
MARINE_CAPTURE_PORTRAITS=1 ./tools/preview.sh
```
