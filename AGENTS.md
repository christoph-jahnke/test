# Marine Outpost

Godot 4.6, Windows-Zielplattform, Top-down-3D. Die bestehenden freien Baupositionen, zufälligen Run-Routen, Kontext-UI und lokalen Fortschrittsdaten bei Änderungen erhalten.

## Jede neue Version liefert eine echte Vorschau

Der Nutzer möchte mit **jeder Version einen Screenshot** sehen.

- Versionsnummer in `project.godot` und sichtbarer Oberfläche synchron halten.
- Den aktuellen Build mit Grafikdarstellung starten und `tools/capture_release.gd` ausführen. Dafür eine eigene XDG-Datenablage verwenden.
- Aktuelle Spielansicht unter `docs/previews/v<VERSION>/battle.png` speichern; `capture.json` beschreibt Version, Auflösung und arrangierte Testsituation. Vorhandene Screenshots früherer Versionen erhalten.
- Die Vorschau tatsächlich ansehen und UI, Lesbarkeit, Modelle und Platzierung prüfen. Probleme vor Veröffentlichung korrigieren.
- Im Abschluss die neue Spielvorschau als Markdown-Bild einbetten und den Download der zugehörigen Git-Revision verlinken. Eine Galerie kann zusätzlich verlinkt werden.
- Grafik-, Windows- und Performanceprüfungen jeweils nur im tatsächlich ausgeführten Umfang beschreiben.

## Entwicklung und Assets

`tools/build_models.py` erzeugt die GLBs mit Blender. Blender ist für das Spielen nicht erforderlich. Bei neuen Assets die Registrierung, Galerie und Modelltests aktualisieren. Nicht abgesicherte Nutzeränderungen an generierten GLBs erhalten.

Passende vorhandene Prüfungen aus `game/smoke_*.gd` mit getrennten Nutzerdaten ausführen. Neue Checks sollen relevante Spielzustände und Regressionen prüfen.

Die Cloud-Aufgabe hat bereits einen isolierten Checkout; keine zusätzlichen Worktrees anlegen, sofern nicht gewünscht.
