# Vorschau zu jeder Version

Ab Version 0.8 wird jede Veröffentlichung mit einem neuen Screenshot aus dem tatsächlichen Godot-Build gezeigt. Die Bilder liegen unverändert in versionsbezogenen Ordnern, zum Beispiel `previews/v0.8.0/battle.png`. Frühere Vorschauen bleiben erhalten. Die Abschlussantwort bettet die aktuelle Spielvorschau direkt ein und verlinkt den dazugehörigen Download.

## Reproduzieren

Unter Linux mit Godot und einem vorhandenen Display oder Xorg-Dummy-Treiber:

```sh
./tools/preview.sh
```

Das Skript verwendet eigene temporäre Nutzerdaten, importiert Ressourcen, startet bei Bedarf einen Dummy-X-Server, rendert die aktuelle Versionsnummer und prüft Ausgabeauflösung und Metadaten. Es beendet nur den von ihm gestarteten X-Server. Fehler beim Rendern oder Schreiben führen zu einem Fehlerstatus.

Mit vorhandenem grafischem Display kann der Godot-Teil direkt gestartet werden:

```sh
godot --path . --rendering-method gl_compatibility --script res://tools/capture_release.gd
```

Bei geänderten Turmmodellen können die neun Bau-/Upgrade-Portraits im selben Display neu gerendert werden:

```sh
MARINE_CAPTURE_PORTRAITS=1 ./tools/preview.sh
```

Die erzeugte Aufnahme muss anschließend visuell angesehen werden; Dateiprüfungen allein bestätigen keine gute Darstellung.

## Aufnahmen

- `battle.png`: Gesamtansicht mit Baukarten.
- `inspector.png`: derselbe Aufbau mit ausgewähltem Turm.
- `closeup.png`: nähere Kamerasicht.
- `menu.png`: sichtbare Version und Menü.
- `gallery.png`: aktuelle Asset-Auswahl.
- `towers.png`, `monsters.png`: eigene Galerieansichten der Kampfmodelle (ab 0.9).
- `capture.json`: Version, Auflösung, Karten-Seed, Renderer, Engine und Asset-Anzahl.

Die Aufnahmen nutzen eine arrangierte Testsituation mit festen Türmen, Gegnern und Geldständen. Sie werden vom Spielrenderer erzeugt und zeigen keinen dokumentierten Spielerfolg. Auflösung: 1440 × 900. Windows-Darstellung und Windows-Leistung benötigen eigene Tests.
