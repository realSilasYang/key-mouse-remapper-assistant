<div align="center">
  <img src="../assets/app/key-mouse-remapper-assistant.png" width="112" alt="Logo dell’Assistente di rimappatura tastiera e mouse">

  <p><a href="../README.md">简体中文</a> · <a href="./README.zh-HK.md">繁體中文（香港）</a> · <a href="./README.zh-TW.md">繁體中文（台灣）</a> · <a href="./README.en.md">English</a> · <a href="./README.ja.md">日本語</a> · <a href="./README.vi.md">Tiếng Việt</a> · <a href="./README.ko.md">한국어</a> · <a href="./README.es.md">Español</a> · <a href="./README.fr.md">Français</a> · <a href="./README.pt-BR.md">Português</a> · <a href="./README.ru.md">Русский</a> · <a href="./README.de.md">Deutsch</a> · <strong>Italiano</strong></p>

  <h1>Assistente di rimappatura tastiera e mouse</h1>
  <p><strong>Registra, scrivi e gestisci mappature adatte al tuo flusso di lavoro</strong></p>

  <p><a href="https://github.com/realSilasYang/key-mouse-remapper-assistant/releases/latest"><img src="https://img.shields.io/github/v/release/realSilasYang/key-mouse-remapper-assistant?style=flat-square&amp;label=version" alt="Ultima versione"></a> <a href="https://github.com/realSilasYang/key-mouse-remapper-assistant/releases"><img src="https://img.shields.io/github/downloads/realSilasYang/key-mouse-remapper-assistant/total?style=flat-square&amp;label=downloads" alt="Download"></a> <a href="../LICENSE"><img src="https://img.shields.io/github/license/realSilasYang/key-mouse-remapper-assistant?style=flat-square" alt="Licenza"></a> <img src="https://img.shields.io/badge/Windows-10%20%7C%2011-0078D4?style=flat-square" alt="Windows 10 e 11"> <img src="https://img.shields.io/badge/AutoHotkey-v2-334455?style=flat-square" alt="AutoHotkey v2"></p>

  <p><a href="#panoramica-dellinterfaccia">Interfaccia</a> · <a href="#guida-utente">Guida</a> · <a href="#4-blocchi-di-regole-script-gestiti-e-ia">Forme delle regole</a> · <a href="https://github.com/realSilasYang/key-mouse-remapper-assistant/releases">Versioni</a> · <a href="./CHANGELOG.en.md">Modifiche</a> · <a href="https://github.com/realSilasYang/key-mouse-remapper-assistant/issues/new">Feedback</a> · <a href="#guida-per-sviluppatori">Sviluppo</a></p>
</div>

L’Assistente di rimappatura tastiera e mouse è uno strumento AutoHotkey v2 per Windows 10 e 11 x64. Riunisce acquisizione degli input, gestione delle regole, modifica del codice, generazione e ottimizzazione IA, convalida locale e stato di esecuzione. La versione 1.0.1 include 18 regole modificabili: 13 blocchi di regole e 5 script gestiti.

Le regole sono salvate nell’area commentata `@mapping`, leggibile e copiabile. Non vengono installati driver o servizi Windows; le mappature funzionano solo mentre l’assistente è in esecuzione. I pacchetti ufficiali non includono mai indirizzo IA, chiave API, modello, prompt personalizzati o altre impostazioni personali del computer di compilazione.

# Panoramica dell’interfaccia

<p align="center">
  <img src="images/key-mouse-remapper-assistant-overview.png" alt="Finestra principale scura" width="100%">
</p>
<p align="center">
  <img src="images/key-mouse-remapper-assistant-overview-light.png" alt="Finestra principale chiara" width="100%">
</p>

La barra superiore aggiunge, sospende／riprende in gruppo ed elimina le regole. L’elenco mostra ordine, nome, input origine, risultato, ambito e stato. L’area inferiore registra direttamente origine e destinazione. Sono disponibili selezione multipla, trascinamento in gruppo, ordinamento visivo temporaneo, suggerimenti per testo troncato, punti colorati e selezione arrotondata stabile.

## Funzioni principali

- Acquisizione di tastiera, pulsanti del mouse, rotella e tasti browser／multimediali／avvio, distinguendo i modificatori sinistri e destri.
- Pressione, rilascio, ripetizione, tocco, pressione lunga, tasti simultanei e condizioni di applicazione, finestra, origine input e sessione.
- Applicazione immediata dei blocchi dichiarativi nel processo principale ed esecuzione di script AHK v2 completi in processi gestiti separati.
- L’IA sceglie la forma da un solo ingresso; seguono normalizzazione, convalida RuleSpec e controllo sintassi／avvio AHK v2.
- Editor con evidenziazione di sintassi e righe modificate, annulla, ripristina, elimina riga e scorrimento fisso di due righe.
- Aggiunte, modifiche, eliminazioni, pause, importazioni e riordini possono essere annullati e ripristinati.
- 13 lingue, tema sistema／chiaro／scuro, esecuzione elevata, avvio all’accesso e aggiornamento automatico.

## Ambito

- Solo Windows 10／11 x64.
- Senza driver kernel, desktop sicuro, `Ctrl+Alt+Delete` e programmi che bloccano gli hook utente restano fuori portata.
- La modalità amministratore predefinita eleva blocchi e script figli per agire sulle applicazioni elevate.
- I risultati IA vanno verificati anche dopo il controllo locale, soprattutto per operazioni su file, rete, processi o sistema.

---

**[Guida utente](#guida-utente)**<br>
[Installazione](#1-installazione-e-primo-avvio) · [Gestione](#2-aggiunta-e-gestione-delle-mappature) · [Registrazione](#3-registrazione-stato-ed-eventi) · [Regole e IA](#4-blocchi-di-regole-script-gestiti-e-ia) · [Impostazioni](#5-impostazioni) · [Privacy](#6-eventi-diagnostica-e-privacy)

**[Guida per sviluppatori](#guida-per-sviluppatori)**<br>
[Directory](#1-directory-e-responsabilità) · [Limiti](#2-limiti-di-correttezza) · [Verifica](#3-comandi-di-verifica) · [Pubblicazione](#4-pubblicazione-e-contributi)

# Sostieni il progetto

Se l’assistente migliora il lavoro quotidiano, puoi sostenere lo sviluppo tramite i codici QR seguenti:

<p align="center"><img src="../assets/donate/微信个人收款码.png" width="220" alt="Codice QR WeChat Pay">&nbsp;&nbsp;&nbsp;&nbsp;<img src="../assets/donate/支付宝个人收款码.png" width="220" alt="Codice QR Alipay"></p>

# Guida utente

## 1. Installazione e primo avvio

Scarica lo ZIP portatile completo o lo ZIP sorgente completo da [Releases](https://github.com/realSilasYang/key-mouse-remapper-assistant/releases) ed estrailo interamente in una cartella scrivibile. L’edizione portatile esegue `键鼠重映射小助手.exe` e include un ambiente AutoHotkey v2 x64 fisso. L’edizione sorgente richiede AutoHotkey v2 x64 per eseguire `键鼠重映射小助手.ahk`.

Il primo avvio richiede per impostazione predefinita i privilegi di amministratore. Chiudere la finestra la nasconde soltanto nell’area di notifica; usa Esci dal menu per fermare tutte le mappature. L’edizione portatile non è un’app a file singolo: conserva l’intera cartella quando la sposti o la salvi.

### Versioni e modalità di esecuzione

La versione portatile deriva dall’EXE e usa l’ambiente incluso. Quella sorgente deriva da `VERSION` e usa l’interprete installato. Entrambe conservano le regole nel file AHK modificabile della directory di esecuzione.

## 2. Aggiunta e gestione delle mappature

Aggiungi apre l’editor `@mapping` completo o la generazione IA. Modifica con doppio clic, F2 o menu contestuale. Una selezione multipla può essere sospesa, ripresa, eliminata, trascinata in gruppo o contrassegnata da punti colorati. L’ordinamento dell’intestazione cambia solo la vista. Nell’elenco principale `Ctrl+Z` annulla e `Ctrl+Shift+Z` ripristina.

## 3. Registrazione, stato ed eventi

Registra origine e destinazione, inserisci un nome, scegli se distinguere i modificatori e salva. Durante la cattura l’assistente sospende le mappature e attiva una protezione dedicata; riprende solo dopo il rilascio di tutti i tasti fisici. Lo stato della riga mostra se la regola è attiva o sospesa e la barra inferiore descrive l’ultimo risultato.

## 4. Blocchi di regole, script gestiti e IA

| Forma | Uso adatto | Esecuzione |
| --- | --- | --- |
| Blocco di regole | Un trigger, accordi, rami tocco／pressione lunga／rilascio, condizioni e azioni standard | Analizza JSON commentato e si applica nel processo principale |
| Script gestito | Più tasti di scelta rapida, stato condiviso, cicli, timer, funzioni, chiamate esterne o AHK v2 arbitrario | L’assistente avvia, sospende, riprende e ferma un processo AutoHotkey separato |

La generazione ha un solo ingresso e l’IA sceglie la forma in base ai limiti reali. Il risultato entra direttamente nell’editor; l’ottimizzazione mostra prima una revisione con sintassi e righe modificate evidenziate. Il flusso locale rimuove involucri, normalizza campi, convalida tasti e RuleSpec ed esegue il controllo AHK v2. Un errore o un annullamento non sostituisce la regola originale e mantiene l’ultima richiesta.

Gli script gestiti eseguono codice arbitrario e richiedono conferma. Non duplicare le direttive inserite e non usare `#SingleInstance Force`, `ExitApp` incondizionato o `Reload` per interrompere il ciclo gestito.

## 5. Impostazioni

Le impostazioni controllano lingua, carattere, tema, collegamenti, attività di avvio, modalità amministratore, controllo aggiornamenti, connessione IA, pacchetti di regole e capacità eventi. L’aggiornamento verifica una Release ufficiale, conserva l’area `@mapping` e le impostazioni non gestite e ripristina i vecchi file se la sostituzione fallisce.

## 6. Eventi, diagnostica e privacy

Il visualizzatore filtra input, corrispondenze, condizioni respinte, azioni, archivio ed eventi di sistema ed esporta JSONL. Verifica le informazioni su applicazioni, finestre e tasti prima di condividerle.

Le regole sono in `键鼠重映射小助手.ahk`; impostazioni IA, visualizzazione e avvio sono in `%APPDATA%\KeyMouseRemapperAssistant`. Salva entrambe. I pacchetti ufficiali contengono le 18 regole attuali ma escludono `settings.ini`, `runtime.ini`, `rule-appearance.json`, `window-layout.ini` e tutti i parametri IA locali. Non ci sono telemetria o caricamenti automatici; i dati IA raggiungono il fornitore configurato solo dopo un’azione esplicita.

# Star History

[![Star History Chart](https://api.star-history.com/svg?repos=realSilasYang/key-mouse-remapper-assistant&type=Date)](https://star-history.com/#realSilasYang/key-mouse-remapper-assistant&Date)

# Guida per sviluppatori

## 1. Directory e responsabilità

`app/` contiene applicazione e finestre; `src/Core/`, regole, esecuzione, IA, cronologia, pacchetti e aggiornamenti; `src/Input/`, osservazione e cattura; `src/Localization/`, 13 lingue; `src/Platform/` e `src/UI/`, integrazione Windows e interfaccia; `tests/` e `tools/`, verifica e pubblicazione.

## 2. Limiti di correttezza

I blocchi usano `Hotkey()` nel processo principale; gli script usano processi separati con segnali di arresto, pausa e disponibilità. La cattura usa una protezione temporanea. Le scritture usano blocco interprocesso, confronto di istantanee e sostituzione atomica. Le sequenze del desktop sicuro restano escluse.

## 3. Comandi di verifica

```powershell
.\tools\bootstrap-toolchain.ps1
.\tests\verify.ps1 -AutoHotkeyPath .\.tools\autoHotkey-2.0.26\AutoHotkey64.exe -IncludeGui
```

Due test che bloccano realmente l’input fisico sono esclusi dall’esecuzione automatica predefinita.

## 4. Pubblicazione e contributi

Esegui `.\tools\build-release.ps1` per creare gli ZIP portatile e sorgente completi. Il packaging rifiuta stato personale e parametri IA locali e produce archivi deterministici. Segui il [modello del changelog](changelog-template.md) e il [processo di rilascio](release-process.md). Il progetto usa la [MIT License](../LICENSE); consulta [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md).
