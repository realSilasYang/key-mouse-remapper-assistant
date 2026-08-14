<div align="center">
  <img src="../assets/app/key-mouse-remapper-assistant.png" width="112" alt="Logo des Tastatur- und Maus-Neuzuordnungsassistenten">

  <p><a href="../README.md">简体中文</a> · <a href="./README.zh-HK.md">繁體中文（香港）</a> · <a href="./README.zh-TW.md">繁體中文（台灣）</a> · <a href="./README.en.md">English</a> · <a href="./README.ja.md">日本語</a> · <a href="./README.vi.md">Tiếng Việt</a> · <a href="./README.ko.md">한국어</a> · <a href="./README.es.md">Español</a> · <a href="./README.fr.md">Français</a> · <a href="./README.pt-BR.md">Português</a> · <a href="./README.ru.md">Русский</a> · <strong>Deutsch</strong> · <a href="./README.it.md">Italiano</a></p>

  <h1>Tastatur- und Maus-Neuzuordnungsassistent</h1>
  <p><strong>Tastatur- und Mauszuordnungen für den eigenen Arbeitsablauf aufnehmen, schreiben und verwalten</strong></p>

  <p><a href="https://github.com/realSilasYang/key-mouse-remapper-assistant/releases/latest"><img src="https://img.shields.io/github/v/release/realSilasYang/key-mouse-remapper-assistant?style=flat-square&amp;label=version" alt="Neueste Version"></a> <a href="https://github.com/realSilasYang/key-mouse-remapper-assistant/releases"><img src="https://img.shields.io/github/downloads/realSilasYang/key-mouse-remapper-assistant/total?style=flat-square&amp;label=downloads" alt="Downloads"></a> <a href="../LICENSE"><img src="https://img.shields.io/github/license/realSilasYang/key-mouse-remapper-assistant?style=flat-square" alt="Lizenz"></a> <img src="https://img.shields.io/badge/Windows-10%20%7C%2011-0078D4?style=flat-square" alt="Windows 10 und 11"> <img src="https://img.shields.io/badge/AutoHotkey-v2-334455?style=flat-square" alt="AutoHotkey v2"></p>

  <p><a href="#oberflächenübersicht">Oberfläche</a> · <a href="#benutzerhandbuch">Handbuch</a> · <a href="#4-regelblöcke-verwaltete-skripte-und-ki">Regelformen</a> · <a href="https://github.com/realSilasYang/key-mouse-remapper-assistant/releases">Versionen</a> · <a href="./CHANGELOG.en.md">Änderungen</a> · <a href="https://github.com/realSilasYang/key-mouse-remapper-assistant/issues/new">Rückmeldung</a> · <a href="#entwicklerhandbuch">Entwicklung</a></p>
</div>

Der Tastatur- und Maus-Neuzuordnungsassistent ist ein AutoHotkey-v2-Werkzeug für Windows 10 und 11 x64. Eingabeaufnahme, Regelverwaltung, Codebearbeitung, KI-Erzeugung und -Optimierung, lokale Prüfung und Laufzeitstatus befinden sich in einer Oberfläche. Version 1.0.0 liefert 18 bearbeitbare Regeln: 13 Regelblöcke und 5 verwaltete Skripte.

Regeln liegen im les- und sicherbaren `@mapping`-Kommentarbereich. Es werden weder Treiber noch Windows-Dienste installiert; Zuordnungen wirken nur, solange der Assistent läuft. Offizielle Pakete enthalten niemals KI-Adresse, API-Schlüssel, Modell, eigene Prompts oder andere persönliche Einstellungen des Build-Rechners.

# Oberflächenübersicht

<p align="center"><img src="images/key-mouse-remapper-assistant-overview.png" alt="Hauptfenster" width="100%"></p>

Die obere Leiste fügt Regeln hinzu, pausiert／setzt mehrere fort und löscht sie. Die Liste zeigt Reihenfolge, Name, Quelleingabe, Ergebnis, Geltungsbereich und Status. Unten werden Quelle und Ziel direkt aufgenommen. Mehrfachauswahl, gruppiertes Ziehen, temporäre Ansichtssortierung, Hinweise für gekürzten Text, farbige Nummernpunkte und stabile abgerundete Auswahl werden unterstützt.

## Hauptfunktionen

- Tastatur, Maustasten, Rad und Browser／Medien／Starttasten aufnehmen und linke／rechte Modifikatoren unterscheiden.
- Drücken, Loslassen, Wiederholen, kurzes und langes Drücken, gleichzeitige Tasten sowie App-, Fenster-, Eingabequellen- und Sitzungsbedingungen.
- Deklarative Regelblöcke im Hauptprozess sofort anwenden und vollständige AHK-v2-Skripte in getrennten verwalteten Prozessen ausführen.
- Die KI wählt aus einem Einstieg die Form; anschließend folgen Normalisierung, RuleSpec-Prüfung und AHK-v2-Syntax／Startprüfung.
- Editor mit Syntax- und Änderungszeilenhervorhebung, Rückgängig, Wiederholen, Zeile löschen und festem Zwei-Zeilen-Scrollen.
- Hinzufügen, Bearbeiten, Löschen, Pausieren, Importieren und Sortieren lassen sich rückgängig machen und wiederholen.
- 13 Sprachen, System／Hell／Dunkel, erhöhte Ausführung, Anmeldungstart und automatische Aktualisierung.

## Geltungsbereich

- Nur Windows 10／11 x64.
- Ohne Kerneltreiber bleiben sicherer Desktop, `Ctrl+Alt+Delete` und Programme, die User-Mode-Hooks sperren, außer Reichweite.
- Der voreingestellte Administratormodus erhöht Regelblöcke und untergeordnete Skripte für erhöhte Anwendungen.
- KI-Ergebnisse sind auch nach lokaler Prüfung zu kontrollieren, besonders bei Datei-, Netzwerk-, Prozess- oder Systemaktionen.

---

**[Benutzerhandbuch](#benutzerhandbuch)**<br>
[Installation](#1-installation-und-erster-start) · [Verwaltung](#2-zuordnungen-hinzufügen-und-verwalten) · [Aufnahme](#3-aufnahme-status-und-ereignisse) · [Regeln und KI](#4-regelblöcke-verwaltete-skripte-und-ki) · [Einstellungen](#5-einstellungen) · [Datenschutz](#6-ereignisse-diagnose-und-datenschutz)

**[Entwicklerhandbuch](#entwicklerhandbuch)**<br>
[Verzeichnisse](#1-verzeichnisse-und-zuständigkeiten) · [Grenzen](#2-korrektheitsgrenzen) · [Prüfung](#3-prüfbefehle) · [Veröffentlichung](#4-veröffentlichung-und-mitarbeit)

# Projekt unterstützen

Wenn der Assistent die tägliche Arbeit verbessert, kann die Entwicklung über diese QR-Codes unterstützt werden:

<p align="center"><img src="../assets/donate/微信个人收款码.png" width="220" alt="WeChat-Pay-QR-Code">&nbsp;&nbsp;&nbsp;&nbsp;<img src="../assets/donate/支付宝个人收款码.png" width="220" alt="Alipay-QR-Code"></p>

# Benutzerhandbuch

## 1. Installation und erster Start

Das vollständige portable ZIP oder Quellcode-ZIP von [Releases](https://github.com/realSilasYang/key-mouse-remapper-assistant/releases) herunterladen und vollständig in einen beschreibbaren Ordner entpacken. Die portable Ausgabe startet `键鼠重映射小助手.exe` und enthält eine feste AutoHotkey-v2-x64-Laufzeit. Die Quellcodeausgabe benötigt AutoHotkey v2 x64 für `键鼠重映射小助手.ahk`.

Der erste Start fordert standardmäßig Administratorrechte an. Schließen blendet das Fenster nur in den Infobereich aus; „Beenden“ im Infobereich stoppt alle Zuordnungen. Die portable Ausgabe ist keine Ein-Datei-App: Beim Verschieben und Sichern den gesamten Ordner behalten.

### Versionen und Laufzeitformen

Die portable Versionsangabe stammt aus der EXE und verwendet die mitgelieferte Laufzeit. Die Quellcodeversion stammt aus `VERSION` und verwendet den installierten Interpreter. Beide speichern Regeln in der bearbeitbaren AHK-Datei des Laufzeitordners.

## 2. Zuordnungen hinzufügen und verwalten

„Hinzufügen“ öffnet den vollständigen `@mapping`-Editor oder die KI-Erzeugung. Doppelklick, F2 oder Kontextmenü bearbeiten eine Regel. Mehrere Zeilen können pausiert, fortgesetzt, gelöscht, gruppiert gezogen oder farbig markiert werden. Eine Kopfzeilensortierung ändert nur die Ansicht. In der Hauptliste macht `Ctrl+Z` rückgängig und `Ctrl+Shift+Z` wiederholt.

## 3. Aufnahme, Status und Ereignisse

Quelle und Ziel aufnehmen, einen Namen eingeben, die Unterscheidung der Modifikatorseiten wählen und speichern. Während der Aufnahme pausiert der Assistent Zuordnungen und aktiviert einen eigenen Eingabeschutz; erst nach dem Loslassen aller physischen Tasten wird fortgesetzt. Der Zeilenstatus zeigt aktiv oder pausiert, die untere Leiste das letzte Ergebnis.

## 4. Regelblöcke, verwaltete Skripte und KI

| Form | Geeignet für | Ausführung |
| --- | --- | --- |
| Regelblock | Ein Auslöser, Akkorde, Kurz／Lang／Loslass-Zweige, Bedingungen und Standardaktionen | Kommentiertes JSON parsen und im Hauptprozess sofort anwenden |
| Verwaltetes Skript | Mehrere Hotkeys, gemeinsamer Zustand, Schleifen, Timer, Funktionen, externe Aufrufe oder beliebiges AHK v2 | Assistent startet, pausiert, setzt fort und beendet einen getrennten AutoHotkey-Prozess |

Die Erzeugung hat einen Einstieg; die KI wählt anhand der tatsächlichen Grenzen die Form. Erzeugtes geht direkt in den Editor, die Optimierung zeigt zuerst eine Prüfung mit Syntax- und Änderungszeilenhervorhebung. Lokal werden Umhüllungen entfernt, Felder normalisiert, Tasten und RuleSpec geprüft und die AHK-v2-Prüfung ausgeführt. Fehler oder Abbruch ersetzen die Originalregel nicht und behalten die letzte Anfrage.

Verwaltete Skripte führen beliebigen Code aus und verlangen eine Bestätigung. Eingefügte Direktiven nicht wiederholen und den Lebenszyklus nicht mit `#SingleInstance Force`, bedingungslosem `ExitApp` oder `Reload` brechen.

## 5. Einstellungen

Einstellungen steuern Sprache, Schrift, Thema, Verknüpfungen, Startaufgabe, Administratormodus, Updateprüfung, KI-Verbindung, Regelpakete und Ereigniskapazität. Der Updater prüft eine offizielle Release, erhält `@mapping` und nicht verwaltete Einstellungen und rollt bei Austauschfehlern zurück.

## 6. Ereignisse, Diagnose und Datenschutz

Die Ereignisansicht filtert Eingaben, Treffer, abgelehnte Bedingungen, Aktionen, Speicher- und Systemereignisse und exportiert JSONL. Vor dem Teilen App-, Fenster- und Tasteninformationen prüfen.

Regeln liegen in `键鼠重映射小助手.ahk`; KI-, Anzeige- und Starteinstellungen in `%APPDATA%\KeyMouseRemapperAssistant`. Beides sichern. Offizielle Pakete enthalten die 18 aktuellen Regeln, aber nicht `settings.ini`, `runtime.ini`, `rule-appearance.json`, `window-layout.ini` oder lokale KI-Parameter. Es gibt keine Telemetrie oder automatischen Upload; KI-Daten gehen nur nach ausdrücklicher Aktion an den konfigurierten Anbieter.

# Star History

[![Star History Chart](https://api.star-history.com/svg?repos=realSilasYang/key-mouse-remapper-assistant&type=Date)](https://star-history.com/#realSilasYang/key-mouse-remapper-assistant&Date)

# Entwicklerhandbuch

## 1. Verzeichnisse und Zuständigkeiten

`app/` enthält App und Fenster; `src/Core/` Regeln, Laufzeit, KI, Verlauf, Pakete und Updates; `src/Input/` Beobachtung und Aufnahme; `src/Localization/` 13 Sprachen; `src/Platform/` und `src/UI/` Windows-Integration und Oberfläche; `tests/` und `tools/` Prüfung und Veröffentlichung.

## 2. Korrektheitsgrenzen

Blöcke verwenden `Hotkey()` im Hauptprozess; Skripte getrennte Prozesse mit Stopp-, Pause- und Bereitschaftssignalen. Die Aufnahme nutzt einen temporären Schutz. Regeländerungen verwenden prozessübergreifende Sperre, Snapshot-Vergleich und atomaren Austausch. Sichere Desktopsequenzen bleiben ausgeschlossen.

## 3. Prüfbefehle

```powershell
.\tools\bootstrap-toolchain.ps1
.\tests\verify.ps1 -AutoHotkeyPath .\.tools\autoHotkey-2.0.26\AutoHotkey64.exe -IncludeGui
```

Zwei Tests mit echter Eingabesperre gehören nicht zum unbeaufsichtigten Standardlauf.

## 4. Veröffentlichung und Mitarbeit

`.\tools\build-release.ps1` erzeugt vollständige portable und Quellcode-ZIPs. Das Paketieren lehnt persönlichen Zustand und lokale KI-Parameter ab und erzeugt deterministische Archive. [Changelog-Vorlage](changelog-template.md) und [Veröffentlichungsprozess](release-process.md) beachten. Das Projekt verwendet die [MIT License](../LICENSE); siehe [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md).
