<div align="center">
  <img src="../assets/app/key-mouse-remapper-assistant.png" width="112" alt="Logo de l’Assistant de remappage clavier et souris">

  <p><a href="../README.md">简体中文</a> · <a href="./README.zh-HK.md">繁體中文（香港）</a> · <a href="./README.zh-TW.md">繁體中文（台灣）</a> · <a href="./README.en.md">English</a> · <a href="./README.ja.md">日本語</a> · <a href="./README.vi.md">Tiếng Việt</a> · <a href="./README.ko.md">한국어</a> · <a href="./README.es.md">Español</a> · <strong>Français</strong> · <a href="./README.pt-BR.md">Português</a> · <a href="./README.ru.md">Русский</a> · <a href="./README.de.md">Deutsch</a> · <a href="./README.it.md">Italiano</a></p>

  <h1>Assistant de remappage clavier et souris</h1>
  <p><strong>Enregistrez, écrivez et gérez des remappages adaptés à votre façon de travailler</strong></p>

  <p><a href="https://github.com/realSilasYang/key-mouse-remapper-assistant/releases/latest"><img src="https://img.shields.io/github/v/release/realSilasYang/key-mouse-remapper-assistant?style=flat-square&amp;label=version" alt="Dernière version"></a> <a href="https://github.com/realSilasYang/key-mouse-remapper-assistant/releases"><img src="https://img.shields.io/github/downloads/realSilasYang/key-mouse-remapper-assistant/total?style=flat-square&amp;label=downloads" alt="Téléchargements"></a> <a href="../LICENSE"><img src="https://img.shields.io/github/license/realSilasYang/key-mouse-remapper-assistant?style=flat-square" alt="Licence"></a> <img src="https://img.shields.io/badge/Windows-10%20%7C%2011-0078D4?style=flat-square" alt="Windows 10 et 11"> <img src="https://img.shields.io/badge/AutoHotkey-v2-334455?style=flat-square" alt="AutoHotkey v2"></p>

  <p><a href="#aperçu-de-linterface">Interface</a> · <a href="#guide-dutilisation">Guide</a> · <a href="#4-blocs-de-règles-scripts-gérés-et-ia">Types de règle</a> · <a href="https://github.com/realSilasYang/key-mouse-remapper-assistant/releases">Versions</a> · <a href="./CHANGELOG.en.md">Historique</a> · <a href="https://github.com/realSilasYang/key-mouse-remapper-assistant/issues/new">Retours</a> · <a href="#guide-de-développement">Développement</a></p>
</div>

L’Assistant de remappage clavier et souris est un outil AutoHotkey v2 pour Windows 10 et 11 x64. Il réunit l’enregistrement des entrées, la gestion des règles, l’édition de code, la génération et l’optimisation par IA, la validation locale et l’état d’exécution. La version 1.0.2 contient 18 règles modifiables : 13 blocs de règles et 5 scripts gérés.

Les règles sont enregistrées dans la zone commentée `@mapping`, lisible et sauvegardable. Aucun pilote ni service Windows n’est installé ; les remappages ne fonctionnent que pendant l’exécution de l’assistant. Les paquets officiels n’intègrent jamais l’adresse IA, la clé API, le modèle, les invites personnalisées ou les réglages personnels de la machine de compilation.

# Aperçu de l’interface

<p align="center">
  <img src="images/key-mouse-remapper-assistant-overview.png" alt="Fenêtre principale sombre" width="100%">
</p>
<p align="center">
  <img src="images/key-mouse-remapper-assistant-overview-light.png" alt="Fenêtre principale claire" width="100%">
</p>

La barre supérieure ajoute, suspend／reprend par lot et supprime les règles. La liste affiche l’ordre, le nom, l’entrée source, le résultat, la portée et l’état. La zone inférieure enregistre directement la source et la cible. La sélection multiple, le glisser groupé, le tri visuel temporaire, les infobulles de texte tronqué, les pastilles colorées et la sélection arrondie sont pris en charge.

## Points forts

- Enregistrement du clavier, des boutons de souris, de la molette et des touches navigateur／multimédia／lancement, avec distinction des modificateurs gauche et droite.
- Gestion de l’appui, du relâchement, de la répétition, de l’appui court, du maintien, des touches simultanées et des conditions d’application, de fenêtre, de source de saisie et de session.
- Application à chaud des blocs déclaratifs dans le processus principal et exécution des scripts AHK v2 complets dans des processus gérés séparés.
- Choix du format par l’IA depuis une entrée unique, puis normalisation, validation RuleSpec et validation de syntaxe／démarrage AHK v2.
- Éditeur avec coloration syntaxique, surlignage des lignes modifiées, annulation, rétablissement, suppression de ligne et défilement fixe de deux lignes.
- Annulation et rétablissement des ajouts, modifications, suppressions, pauses, imports et réordonnancements.
- Treize langues, thème système／clair／sombre, exécution élevée, démarrage à la connexion et mise à jour automatique.

## Périmètre

- Windows 10／11 x64 uniquement.
- Sans pilote noyau, le bureau sécurisé, `Ctrl+Alt+Delete` et les logiciels bloquant les hooks en mode utilisateur restent hors de portée.
- Le mode administrateur par défaut élève les blocs et les scripts enfants afin d’agir sur les applications élevées.
- Les résultats de l’IA doivent être relus même après validation locale, surtout pour les scripts manipulant fichiers, réseau, processus ou système.

---

**[Guide d’utilisation](#guide-dutilisation)**<br>
[Installation](#1-installation-et-premier-démarrage) · [Gestion](#2-ajout-et-gestion-des-remappages) · [Enregistrement](#3-enregistrement-état-et-événements) · [Règles et IA](#4-blocs-de-règles-scripts-gérés-et-ia) · [Réglages](#5-réglages) · [Confidentialité](#6-événements-diagnostic-et-confidentialité)

**[Guide de développement](#guide-de-développement)**<br>
[Dossiers](#1-dossiers-et-responsabilités) · [Limites](#2-limites-de-correction) · [Vérification](#3-commandes-de-vérification) · [Publication](#4-publication-et-contribution)

# Soutenir le projet

Si l’assistant améliore votre travail quotidien, vous pouvez soutenir son développement avec les codes QR ci-dessous :

<p align="center"><img src="../assets/donate/微信个人收款码.png" width="220" alt="Code QR WeChat Pay">&nbsp;&nbsp;&nbsp;&nbsp;<img src="../assets/donate/支付宝个人收款码.png" width="220" alt="Code QR Alipay"></p>

# Guide d’utilisation

## 1. Installation et premier démarrage

Téléchargez le ZIP portable complet ou le ZIP source complet depuis [Releases](https://github.com/realSilasYang/key-mouse-remapper-assistant/releases), puis extrayez-le entièrement dans un dossier accessible en écriture. L’édition portable exécute `键鼠重映射小助手.exe` et inclut un environnement AutoHotkey v2 x64 figé. L’édition source nécessite AutoHotkey v2 x64 pour exécuter `键鼠重映射小助手.ahk`.

Les deux ZIP du programme sont dépourvus de polices. Le fichier facultatif `fonts.zip` fournit des polices Noto de secours ; installez dans Windows celles dont vous avez besoin. L’assistant répertorie uniquement les polices installées dans Windows et ne charge jamais de police privée depuis le ZIP ou le dossier de l’application. Les polices ne sont pas nécessaires au fonctionnement.

Le premier lancement demande par défaut les droits administrateur. Fermer la fenêtre la masque seulement dans la zone de notification ; utilisez Quitter dans ce menu pour arrêter tous les remappages. L’édition portable n’est pas une application monofichier : conservez tout le dossier lors d’un déplacement ou d’une sauvegarde.

### Versions et modes d’exécution

La version portable provient de l’EXE et utilise l’environnement inclus. La version source provient de `VERSION` et utilise l’interpréteur installé. Les deux conservent les règles dans le fichier AHK modifiable du dossier d’exécution.

## 2. Ajout et gestion des remappages

Ajouter ouvre l’éditeur `@mapping` complet ou la génération IA. Modifiez par double-clic, F2 ou le menu contextuel. Une sélection multiple peut être suspendue, reprise, supprimée, déplacée en groupe ou marquée par des pastilles. Le tri des en-têtes ne change que l’affichage. Dans la liste principale, `Ctrl+Z` annule et `Ctrl+Shift+Z` rétablit.

## 3. Enregistrement, état et événements

Enregistrez la source puis la cible, saisissez un nom, choisissez si les modificateurs doivent être distingués et enregistrez. Pendant la capture, l’assistant suspend les règles et active une protection dédiée ; il ne reprend qu’après le relâchement de toutes les touches physiques. L’état de chaque ligne indique si la règle est active ou suspendue et la barre inférieure explique le dernier résultat.

## 4. Blocs de règles, scripts gérés et IA

| Format | Usage adapté | Exécution |
| --- | --- | --- |
| Bloc de règles | Un déclencheur, accords, branches appui court／maintien／relâchement, conditions et actions standard | Analyse le JSON commenté et s’applique à chaud dans le processus principal |
| Script géré | Plusieurs raccourcis, état partagé, boucles, minuteurs, fonctions, appels externes ou AHK v2 arbitraire | L’assistant démarre, suspend, reprend et arrête un processus AutoHotkey distinct |

La génération n’a qu’une entrée et l’IA choisit le format selon les limites réelles de l’application. Le résultat généré va directement dans l’éditeur ; l’optimisation présente d’abord une revue avec coloration syntaxique et lignes modifiées. Le traitement local retire les enveloppes, normalise les champs, valide les touches et RuleSpec puis exécute la validation AHK v2. Un échec ou une annulation ne remplace pas la règle originale et conserve la dernière demande.

Les scripts gérés exécutent du code arbitraire et exigent une confirmation. Ne dupliquez pas les directives injectées et n’utilisez pas `#SingleInstance Force`, un `ExitApp` inconditionnel ou `Reload` pour casser leur cycle de vie.

## 5. Réglages

Les réglages contrôlent langue, police, thème, raccourcis, tâche de démarrage, mode administrateur, vérification des mises à jour, connexion IA, paquets de règles et capacité d’événements. La mise à jour vérifie une Release officielle, préserve la zone `@mapping` et les réglages non gérés, puis restaure les anciens fichiers en cas d’échec.

## 6. Événements, diagnostic et confidentialité

Le visualiseur filtre les entrées, correspondances, conditions refusées, actions, événements de dépôt et système, puis exporte en JSONL. Vérifiez les informations d’application, de fenêtre et de touches avant partage.

Les règles se trouvent dans `键鼠重映射小助手.ahk` ; les réglages IA, d’affichage et de démarrage sont dans `%APPDATA%\KeyMouseRemapperAssistant`. Sauvegardez les deux. Les paquets officiels contiennent les 18 règles actuelles mais excluent `settings.ini`, `runtime.ini`, `rule-appearance.json`, `window-layout.ini` et tous les paramètres IA locaux. Il n’existe ni télémétrie ni envoi automatique ; les données IA ne partent vers le fournisseur configuré que sur action explicite.

# Star History

[![Star History Chart](https://api.star-history.com/svg?repos=realSilasYang/key-mouse-remapper-assistant&type=Date)](https://star-history.com/#realSilasYang/key-mouse-remapper-assistant&Date)

# Guide de développement

## 1. Dossiers et responsabilités

`app/` contient l’application et les fenêtres ; `src/Core/`, les règles, l’exécution, l’IA, l’historique, les paquets et mises à jour ; `src/Input/`, l’observation et la capture ; `src/Localization/`, les 13 langues ; `src/Platform/` et `src/UI/`, l’intégration Windows et l’interface ; `tests/` et `tools/`, la vérification et la publication.

## 2. Limites de correction

Les blocs s’exécutent via `Hotkey()` dans le processus principal ; les scripts utilisent des processus distincts avec signaux d’arrêt, pause et disponibilité. La capture utilise une protection temporaire. Les écritures emploient verrou interprocessus, comparaison d’instantanés et remplacement atomique. Les séquences du bureau sécurisé restent hors de portée.

## 3. Commandes de vérification

```powershell
.\tools\bootstrap-toolchain.ps1
.\tests\verify.ps1 -AutoHotkeyPath .\.tools\autoHotkey-2.0.26\AutoHotkey64.exe -IncludeGui
```

Deux tests bloquant réellement l’entrée physique sont exclus de l’exécution automatisée par défaut.

## 4. Publication et contribution

Exécutez `.\tools\build-release.ps1` pour créer le ZIP portable complet, le ZIP source complet et le fichier facultatif `fonts.zip`. Les deux paquets du programme excluent les polices ; le paquet de polices sert à leur installation dans Windows. L’empaquetage refuse les états personnels et paramètres IA et produit des archives déterministes. Suivez le [modèle de changelog](changelog-template.md) et le [processus de publication](release-process.md). Le projet utilise la [licence MIT](../LICENSE) ; voir [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md).
