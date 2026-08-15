<div align="center">
  <img src="../assets/app/key-mouse-remapper-assistant.png" width="112" alt="キーボード・マウス再マッピングアシスタントのロゴ">

  <p><a href="../README.md">简体中文</a> · <a href="./README.zh-HK.md">繁體中文（香港）</a> · <a href="./README.zh-TW.md">繁體中文（台灣）</a> · <a href="./README.en.md">English</a> · <strong>日本語</strong> · <a href="./README.vi.md">Tiếng Việt</a> · <a href="./README.ko.md">한국어</a> · <a href="./README.es.md">Español</a> · <a href="./README.fr.md">Français</a> · <a href="./README.pt-BR.md">Português</a> · <a href="./README.ru.md">Русский</a> · <a href="./README.de.md">Deutsch</a> · <a href="./README.it.md">Italiano</a></p>

  <h1>キーボード・マウス再マッピングアシスタント</h1>

  <p><strong>自分の作業に合うキーボードとマウスの割り当てを記録・作成・管理</strong></p>

  <p>
    <a href="https://github.com/realSilasYang/key-mouse-remapper-assistant/releases/latest"><img src="https://img.shields.io/github/v/release/realSilasYang/key-mouse-remapper-assistant?style=flat-square&amp;label=version" alt="最新バージョン"></a>
    <a href="https://github.com/realSilasYang/key-mouse-remapper-assistant/releases"><img src="https://img.shields.io/github/downloads/realSilasYang/key-mouse-remapper-assistant/total?style=flat-square&amp;label=downloads" alt="ダウンロード数"></a>
    <a href="../LICENSE"><img src="https://img.shields.io/github/license/realSilasYang/key-mouse-remapper-assistant?style=flat-square" alt="ライセンス"></a>
    <img src="https://img.shields.io/badge/Windows-10%20%7C%2011-0078D4?style=flat-square" alt="Windows 10 と 11">
    <img src="https://img.shields.io/badge/AutoHotkey-v2-334455?style=flat-square" alt="AutoHotkey v2">
  </p>

  <p><a href="#画面概要">画面概要</a> · <a href="#ユーザーガイド">ユーザーガイド</a> · <a href="#4-ルールブロックと管理スクリプト">ルール形式</a> · <a href="https://github.com/realSilasYang/key-mouse-remapper-assistant/releases">リリース</a> · <a href="./CHANGELOG.en.md">変更履歴</a> · <a href="https://github.com/realSilasYang/key-mouse-remapper-assistant/issues/new">フィードバック</a> · <a href="#開発者ガイド">開発者ガイド</a></p>
</div>

キーボード・マウス再マッピングアシスタントは、Windows 10／11 x64 向けの AutoHotkey v2 デスクトップツールです。入力記録、ルール管理、コード編集、AI による生成と最適化、ローカル検証、実行状態を一つの画面にまとめています。バージョン 1.0.1 には、13 個のルールブロックと 5 個の管理スクリプト、合計 18 個の編集可能な組み込みルールが含まれます。

ルールは読み取り・バックアップ可能な `@mapping` コメント領域に保存されます。ドライバーや Windows サービスは導入せず、マッピングはアシスタントの実行中だけ有効です。公式パッケージに、ビルド環境の AI アドレス、API キー、モデル、独自プロンプト、個人設定が入ることはありません。

# 画面概要

<p align="center"><img src="images/key-mouse-remapper-assistant-overview.png" alt="ダークテーマのメイン画面" width="49%"> <img src="images/key-mouse-remapper-assistant-overview-light.png" alt="ライトテーマのメイン画面" width="49%"></p>

上部でルールの追加、一括停止／再開、削除を行い、中央の一覧で順番、名前、入力元、割り当て先、適用範囲、状態を確認します。下部では入力元と割り当て先を直接記録できます。複数選択、一括ドラッグ、表示だけの並べ替え、省略内容のツールチップ、色付き番号ドット、角丸の選択表示に対応します。

## 主な機能

- キーボード、マウスボタン、ホイール、ブラウザー／メディア／起動キーを記録し、左右の修飾キーを区別。
- 押下、解放、リピート、短押し、長押し、同時押しと、アプリ、ウィンドウ、入力方式、セッション条件に対応。
- ルールブロックはメインプロセスへ即時適用し、完全な AHK v2 スクリプトは独立した管理プロセスで実行。
- AI は一つの入口から適切な形式を判断し、結果を正規化、RuleSpec 検証、AHK v2 構文／起動検証。
- 構文強調、差分行強調、元に戻す、やり直し、行削除、2 行固定スクロールを備えたエディター。
- 追加、編集、削除、停止／再開、ルールパッケージのインポート、ドラッグ順序を元に戻す／やり直す。
- 13 言語、システム連動／ライト／ダークテーマ、管理者実行、サインイン時起動、自動更新。

## 対応範囲と制限

- Windows 10／11 x64 専用です。
- カーネルドライバーを使わないため、安全なデスクトップ、`Ctrl+Alt+Delete`、ユーザーモードフックを意図的に遮断するソフトウェアは対象外です。
- マッピングは同等以下の整合性レベルのプロセスに作用します。既定の管理者モードでは、ルールブロックと子の管理スクリプトも昇格します。
- AI 結果はローカル検証後も確認してください。特にファイル、ネットワーク、プロセス、システム操作を行う管理スクリプトには注意が必要です。

---

**[ユーザーガイド](#ユーザーガイド)**<br>
[インストール](#1-インストールと初回起動) · [管理](#2-項目の追加と管理) · [記録](#3-記録状態イベント) · [ルールと AI](#4-ルールブロック管理スクリプトと-ai) · [設定](#5-設定) · [プライバシー](#6-イベント診断プライバシー)

**[開発者ガイド](#開発者ガイド)**<br>
[ディレクトリ](#1-ディレクトリと責務) · [境界](#2-正しさの境界) · [検証](#3-検証コマンド) · [リリース](#4-リリースと貢献)

# プロジェクトを支援

日常の操作に役立った場合は、以下の QR コードから開発を支援できます。

<p align="center"><img src="../assets/donate/微信个人收款码.png" width="220" alt="WeChat Pay QR コード">&nbsp;&nbsp;&nbsp;&nbsp;<img src="../assets/donate/支付宝个人收款码.png" width="220" alt="Alipay QR コード"></p>

# ユーザーガイド

## 1. インストールと初回起動

[Releases](https://github.com/realSilasYang/key-mouse-remapper-assistant/releases) から完全ポータブル ZIP または完全ソース ZIP を取得し、書き込み可能なフォルダーへすべて展開してください。ポータブル版は `键鼠重映射小助手.exe` を実行し、固定 AutoHotkey v2 x64 ランタイムを内蔵します。ソース版は AutoHotkey v2 x64 をインストールして `键鼠重映射小助手.ahk` を実行します。

初回起動では既定で管理者権限を要求します。メイン画面を閉じてもトレイに隠れるだけです。すべてのマッピングを停止するにはトレイから終了してください。ポータブル版は単一ファイルではないため、移動やバックアップではフォルダー全体を保持します。

## 2. 項目の追加と管理

「追加」は完全な `@mapping` エディターまたは AI 生成を開きます。ダブルクリック、F2、右クリックで編集できます。複数選択して停止、再開、削除、一括ドラッグ、番号ドット設定が可能です。ヘッダーの並べ替えは表示だけを変えます。メイン一覧では `Ctrl+Z` で元に戻し、`Ctrl+Shift+Z` でやり直します。

## 3. 記録、状態、イベント

入力元と割り当て先を順に記録し、名前を入力して保存します。必要なら左右の修飾キーを区別します。記録中は既存のマッピングを停止し、専用入力ガードを起動します。すべての物理キーが解放されてから再開するため、既存ルールやデスクトップショートカットとの競合を抑えます。

## 4. ルールブロック、管理スクリプトと AI

| 形式 | 適した用途 | 実行方式 |
| --- | --- | --- |
| ルールブロック | 一つのトリガー、修飾キー、短押し／長押し／解放、条件、標準アクション | コメント化 JSON を解析してメインプロセスへ即時適用 |
| 管理スクリプト | 複数ホットキー、共有状態、ループ、タイマー、独自関数、外部呼び出し、任意の AHK v2 | 独立 AutoHotkey プロセスをアシスタントが開始、停止、再開、終了 |

管理スクリプトは任意コードを実行できるため、作成とインポート時に明示確認します。ホストが注入するディレクティブを重複させず、`#SingleInstance Force`、無条件 `ExitApp`、`Reload` で管理ライフサイクルを壊さないでください。

### AI による生成と最適化

設定で API アドレス、キー、モデルを入力し、接続をテストします。生成入口は一つで、AI が完全な能力境界からルールブロックか管理スクリプトを選びます。生成結果はエディターへ直接入り、最適化では構文と差分行を強調した確認画面を先に表示します。

ローカル処理は余分な囲みを除去し、既知のフィールドを正規化し、キー名と RuleSpec を検証して、AHK v2 構文または起動検証を行います。失敗、拒否、キャンセル時は元ルールを上書きせず、前回の入力を保持します。AI データはユーザーが明示的に操作したときだけ、設定済み第三者サービスへ送信されます。

## 5. 設定

表示言語、フォント、テーマ、ショートカット、スケジュール起動、管理者モード、起動時更新確認、AI 接続、ルールパッケージ、イベント容量を設定できます。イベントビューアーは入力、照合、条件拒否、アクション、保存、システムイベントを絞り込み、JSONL に書き出します。共有前に機密情報を確認してください。

## 6. イベント、診断、プライバシー

ルールは実行フォルダーの `键鼠重映射小助手.ahk`、AI・表示・起動設定は `%APPDATA%\KeyMouseRemapperAssistant` にあります。両方をバックアップしてください。公式パッケージは現在の 18 ルールを含みますが、`settings.ini`、`runtime.ini`、`rule-appearance.json`、`window-layout.ini`、ローカル AI パラメーターを除外します。テレメトリや自動アップロードはありません。

# Star History

[![Star History Chart](https://api.star-history.com/svg?repos=realSilasYang/key-mouse-remapper-assistant&type=Date)](https://star-history.com/#realSilasYang/key-mouse-remapper-assistant&Date)

# 開発者ガイド

## 1. ディレクトリと責務

`app/` はアプリと画面、`src/Core/` はルール・実行・AI・履歴・パッケージ・更新、`src/Input/` は観測と記録、`src/Localization/` は 13 言語、`src/Platform/` と `src/UI/` は Windows 統合と UI、`tests/` と `tools/` は検証とリリースを担当します。

## 2. 正しさの境界

ルールブロックはメインプロセスの `Hotkey()`、管理スクリプトは停止・一時停止・準備完了信号を持つ別プロセスで動きます。記録時だけ一時入力ガードを使います。ルール書き込みはプロセス間ロック、スナップショット比較、アトミック置換を使います。安全なデスクトップと安全注意シーケンスは対象外です。

## 3. 検証コマンド

```powershell
.\tools\bootstrap-toolchain.ps1
.\tests\verify.ps1 -AutoHotkeyPath .\.tools\autoHotkey-2.0.26\AutoHotkey64.exe -IncludeGui
.\tools\build-release.ps1
```

## 4. リリースと貢献

ビルドは完全ポータブル ZIP と完全ソース ZIP を生成し、個人状態やローカル AI パラメーターを拒否して決定論的 ZIP を作成します。規約は[変更履歴テンプレート](changelog-template.md)と[リリース手順](release-process.md)を参照してください。

### ライセンス

本プロジェクトは [MIT License](../LICENSE) です。第三者コンポーネントは [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md) を参照してください。
