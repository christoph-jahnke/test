# 0.6 — Freier Bau, zufällige Lanes und Kontext-UI

## Platzierung

1. Marine, Mörser oder Kryo wählen.
2. Maus über das Schlachtfeld bewegen. Die Vorschau zeigt Position und Reichweite.
3. Grün bedeutet platzierbar; Rot zeigt eine konkrete Einschränkung im Baupanel.
4. Mit Linksklick bauen. Der neue Turm wird anschließend ausgewählt und die UI zeigt seine Aktionen.
5. Rechtsklick oder Esc schließt die Auswahl. Erneut einen Turm wählen, um weiterzubauen.

Es gibt kein Raster und keine vordefinierten Bauplätze. Die Abstandsmessung ist kontinuierlich. Der Straßenmittelpunkt braucht mindestens 56 interne Koordinateneinheiten Abstand; Turmmitten ebenfalls mindestens 56 voneinander. Das Baugebiet reicht von x=25 bis 1345 und y=65 bis 735. Das entspricht der inneren Fläche zwischen den Kulissen. Maximal 80 gleichzeitig gebaute Türme. Verkaufene Positionen blockieren keine versteckten Slots.

## Route

Jeder neue Einsatz erzeugt einen neuen Seed. Fünf abwechselnde vertikale Abschnitte mit zufälligen x-Positionen und Höhen bilden eine durchgängige Route von links nach rechts. Die x-Koordinate läuft nur nach rechts, sodass sich die Lane nicht selbst kreuzt. Die Route bleibt für alle Wellen dieses Einsatzes stabil. Multiplayer-Lanes sind weiterhin nicht implementiert.

Geladene Runs verwenden ihren gespeicherten Seed. Zufallsgenerator und Spielstandschema haben gemeinsam Formatversion 2; eine zukünftige Änderung des Generators muss die alte Generierung erhalten oder eine Migration vorsehen.

## Feedback und UI

Bauansicht und Turminspektor belegen dieselbe Fläche und sind niemals gleichzeitig sichtbar. Im Inspektor stehen tatsächlicher Schaden, Reichweite und Feuerrate, normale Upgrades, Spezialisierungen, Zielwahl und Verkauf. Namen über Türmen erscheinen nur beim ausgewählten Turm. HP-Balken erscheinen bei verletzten Gegnern und Titans.

Tötungen lösen genau eine Münzanimation mit dem tatsächlichen Ertrag aus. Die Münze steigt auf, dreht sich und verschwindet nach 1,4 Spielsekunden. Pause hält sie an. Ein bereits toter Gegner zahlt nicht erneut.

## Grafik

Prozedurales Bodenmaterial ersetzt das große Kachelraster. Die Straße besitzt Randbeleuchtung. Kulissen liegen außerhalb des Baugebiets, Turmsockel entstehen erst beim Bauen. Zombie-Köpfe und Körper verwenden runde Meshes. Die vorhandenen einfachen Modelle bleiben Entwicklungsassets; die Änderungen sind kein fertiger Produktions-Art-Pass.

## Daten

Neue Runs: `run_v2.json` plus `.bak`. Alte 0.5-Runs (`run_v1.json`) bleiben unberührt, können aber in 0.6 nicht fortgesetzt werden. Forschung (`research_v1.json`), Highscores (`scores.cfg`) und Einstellungen (`settings.cfg`) verwenden dieselben bisherigen Dateien. Ein neuer Einsatz ersetzt den aktuellen 0.6-Run nach Bestätigung.

## Checks

- 100 Seeds: unterschiedliche, durchgängige und reproduzierbare Routen, Straßenbau verboten.
- Freie Koordinaten ohne Raster; Kollisionen und Kartenränder verhindern Ausgaben.
- Wiederholter Verkauf/Bau ohne verwaiste Positionslimits.
- Kameraauswahl am tatsächlichen 3D-Körper und exklusiver UI-Wechsel.
- Einmalige Auszahlung, sichtbare Münze, Bewegung, Pause und Entfernung.
- Seed und freie Positionen bleiben nach Speichern/Laden unverändert.
- Bestehende Tests für Wellen, Forschung, Spezialisierungen und Sicherungswiederherstellung.

Weiterhin Windows-Spieltests und Balance nötig. Die Screenshots verwenden arrangierte Truppen und Geldstände zur Darstellung der Funktionen.
