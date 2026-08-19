<div align="center">
  <img src="../assets/app/key-mouse-remapper-assistant.png" width="112" alt="키보드·마우스 리매핑 도우미 로고">

  <p><a href="../README.md">简体中文</a> · <a href="./README.zh-HK.md">繁體中文（香港）</a> · <a href="./README.zh-TW.md">繁體中文（台灣）</a> · <a href="./README.en.md">English</a> · <a href="./README.ja.md">日本語</a> · <a href="./README.vi.md">Tiếng Việt</a> · <strong>한국어</strong> · <a href="./README.es.md">Español</a> · <a href="./README.fr.md">Français</a> · <a href="./README.pt-BR.md">Português</a> · <a href="./README.ru.md">Русский</a> · <a href="./README.de.md">Deutsch</a> · <a href="./README.it.md">Italiano</a></p>

  <h1>키보드·마우스 리매핑 도우미</h1>
  <p><strong>내 작업 흐름에 맞는 키보드와 마우스 매핑을 기록하고 작성하고 관리합니다</strong></p>

  <p><a href="https://github.com/realSilasYang/key-mouse-remapper-assistant/releases/latest"><img src="https://img.shields.io/github/v/release/realSilasYang/key-mouse-remapper-assistant?style=flat-square&amp;label=version" alt="최신 버전"></a> <a href="https://github.com/realSilasYang/key-mouse-remapper-assistant/releases"><img src="https://img.shields.io/github/downloads/realSilasYang/key-mouse-remapper-assistant/total?style=flat-square&amp;label=downloads" alt="다운로드"></a> <a href="../LICENSE"><img src="https://img.shields.io/github/license/realSilasYang/key-mouse-remapper-assistant?style=flat-square" alt="라이선스"></a> <img src="https://img.shields.io/badge/Windows-10%20%7C%2011-0078D4?style=flat-square" alt="Windows 10 및 11"> <img src="https://img.shields.io/badge/AutoHotkey-v2-334455?style=flat-square" alt="AutoHotkey v2"></p>

  <p><a href="#인터페이스-개요">인터페이스</a> · <a href="#사용자-안내서">사용자 안내서</a> · <a href="#4-규칙-블록과-관리형-스크립트">규칙 형식</a> · <a href="https://github.com/realSilasYang/key-mouse-remapper-assistant/releases">릴리스</a> · <a href="./CHANGELOG.en.md">변경 기록</a> · <a href="https://github.com/realSilasYang/key-mouse-remapper-assistant/issues/new">피드백</a> · <a href="#개발자-안내서">개발자 안내서</a></p>
</div>

키보드·마우스 리매핑 도우미는 Windows 10／11 x64용 AutoHotkey v2 데스크톱 도구입니다. 입력 기록, 규칙 관리, 코드 편집, AI 생성·최적화, 로컬 검증과 실행 상태를 한 인터페이스에 제공합니다. 1.0.2에는 규칙 블록 13개와 관리형 스크립트 5개, 총 18개의 편집 가능한 내장 규칙이 포함됩니다.

규칙은 읽고 백업할 수 있는 `@mapping` 주석 영역에 저장됩니다. 드라이버나 Windows 서비스를 설치하지 않으며 도우미가 실행 중일 때만 매핑이 작동합니다. 공식 패키지는 빌드 컴퓨터의 AI 주소, API 키, 모델, 사용자 프롬프트 또는 개인 설정을 포함하지 않습니다.

# 인터페이스 개요

<p align="center">
  <img src="images/key-mouse-remapper-assistant-overview.png" alt="키보드·마우스 리매핑 도우미 어두운 기본 창" width="100%">
</p>
<p align="center">
  <img src="images/key-mouse-remapper-assistant-overview-light.png" alt="키보드·마우스 리매핑 도우미 밝은 기본 창" width="100%">
</p>

위 명령 모음에서 규칙을 추가하고 여러 규칙을 일시 중지／재개하거나 삭제합니다. 목록은 순서, 이름, 원본 입력, 매핑 결과, 범위와 상태를 표시하고, 아래 영역에서 원본과 대상을 직접 기록합니다. 다중 선택, 묶음 끌기, 임시 열 정렬, 잘린 내용 도움말, 색상 순번 점과 둥근 선택 배경을 지원합니다.

## 주요 기능

- 키보드, 마우스 버튼, 휠, 브라우저／미디어／실행 키를 기록하고 좌우 보조 키를 구분합니다.
- 누름, 뗌, 반복, 짧게 누름, 길게 누름, 동시 키와 앱·창·입력기·세션 조건을 지원합니다.
- 규칙 블록은 기본 프로세스에 즉시 적용하고 완전한 AHK v2 스크립트는 독립 관리 프로세스에서 실행합니다.
- AI가 하나의 생성 입구에서 형식을 선택하며 결과는 정규화, RuleSpec 검증, AHK v2 구문／시작 검증을 거칩니다.
- 구문 강조, 변경 행 강조, 실행 취소, 다시 실행, 행 삭제, 고정 2행 스크롤 편집기를 제공합니다.
- 13개 언어, 시스템／라이트／다크 테마, 관리자 실행, 로그인 시작, 자동 업데이트를 지원합니다.

## 범위와 제한

- Windows 10／11 x64만 지원합니다.
- 커널 드라이버를 설치하지 않으므로 보안 데스크톱, `Ctrl+Alt+Delete`, 사용자 모드 훅을 차단하는 소프트웨어는 처리할 수 없습니다.
- 기본 관리자 모드는 규칙 블록과 하위 관리형 스크립트를 함께 상승시켜 관리자 앱에도 동작하게 합니다.
- 로컬 검증을 통과한 AI 결과도 검토해야 하며, 파일·네트워크·프로세스·시스템 작업을 수행하는 스크립트는 특히 주의해야 합니다.

---

**[사용자 안내서](#사용자-안내서)**<br>
[설치](#1-설치와-첫-실행) · [관리](#2-항목-추가와-관리) · [기록](#3-기록-상태와-이벤트) · [규칙과 AI](#4-규칙-블록-관리형-스크립트와-ai) · [설정](#5-설정) · [개인정보](#6-이벤트-진단과-개인정보)

**[개발자 안내서](#개발자-안내서)**<br>
[디렉터리](#1-디렉터리와-책임) · [경계](#2-정확성-경계) · [검증](#3-검증-명령) · [릴리스](#4-릴리스와-기여)

# 프로젝트 후원

도우미가 일상 작업에 도움이 되었다면 아래 QR 코드로 개발을 후원할 수 있습니다.

<p align="center"><img src="../assets/donate/微信个人收款码.png" width="220" alt="WeChat Pay QR 코드">&nbsp;&nbsp;&nbsp;&nbsp;<img src="../assets/donate/支付宝个人收款码.png" width="220" alt="Alipay QR 코드"></p>

# 사용자 안내서

## 1. 설치와 첫 실행

[Releases](https://github.com/realSilasYang/key-mouse-remapper-assistant/releases)에서 전체 포터블 ZIP 또는 전체 소스 ZIP을 받아 쓰기 가능한 폴더에 모두 압축 해제합니다. 포터블판은 고정 AutoHotkey v2 x64 런타임이 포함된 `键鼠重映射小助手.exe`를 실행합니다. 소스판은 AutoHotkey v2 x64를 설치한 뒤 `键鼠重映射小助手.ahk`를 실행합니다.

두 프로그램 ZIP에는 글꼴이 포함되지 않습니다. 선택 사항인 `fonts.zip`은 Noto 대체 글꼴을 제공하므로 필요한 글꼴을 Windows에 먼저 설치하십시오. 도우미는 Windows에 설치된 글꼴만 열거하며 ZIP이나 프로그램 폴더에서 글꼴을 비공개로 불러오지 않습니다. 글꼴은 실행에 필수가 아닙니다.

첫 실행은 기본적으로 관리자 권한을 요청합니다. 기본 창을 닫으면 트레이로 숨겨질 뿐이며 모든 매핑을 멈추려면 트레이에서 종료해야 합니다. 포터블판은 단일 파일 앱이 아니므로 이동하거나 백업할 때 전체 폴더를 유지하십시오.

## 2. 항목 추가와 관리

추가는 완전한 `@mapping` 편집기 또는 AI 생성을 엽니다. 두 번 클릭, F2 또는 오른쪽 클릭으로 편집합니다. 여러 행을 선택해 일시 중지, 재개, 삭제, 묶음 끌기 또는 순번 점 설정을 할 수 있습니다. 열 머리글 정렬은 현재 화면만 바꾸며 원본 순서를 고치지 않습니다. 기본 목록에서 `Ctrl+Z`는 실행 취소, `Ctrl+Shift+Z`는 다시 실행입니다.

## 3. 기록, 상태와 이벤트

원본과 대상을 차례로 기록하고 이름을 입력한 뒤 저장합니다. 필요하면 좌우 보조 키를 구분합니다. 기록 중에는 현재 매핑을 일시 중지하고 전용 입력 보호기를 시작하며, 모든 물리 키가 해제된 뒤에만 매핑을 재개합니다.

## 4. 규칙 블록, 관리형 스크립트와 AI

| 형식 | 적합한 작업 | 실행 방식 |
| --- | --- | --- |
| 규칙 블록 | 단일 트리거, 조합, 짧게／길게／뗄 때 분기, 조건, 표준 동작 | 주석 JSON을 파싱해 기본 프로세스에 즉시 적용 |
| 관리형 스크립트 | 여러 독립 단축키, 공유 상태, 반복문, 타이머, 함수, 외부 호출, 임의 AHK v2 | 별도 AutoHotkey 프로세스를 도우미가 시작·일시 중지·재개·중지 |

관리형 스크립트는 임의 코드를 실행할 수 있어 생성과 가져오기 때 명시적 확인이 필요합니다. 호스트 지시문을 중복하지 말고 `#SingleInstance Force`, 무조건 `ExitApp`, `Reload`로 관리 수명 주기를 깨지 마십시오.

### AI 생성과 최적화

설정에서 API 주소, 키, 모델을 입력하고 연결을 시험합니다. 생성 입구는 하나이며 AI가 전체 기능 경계를 보고 규칙 블록 또는 관리형 스크립트를 선택합니다. 생성 결과는 편집기로 바로 들어가며, 최적화는 구문과 변경 행이 강조된 검토 창을 먼저 보여 줍니다.

로컬 파이프라인은 포장을 제거하고 알려진 필드를 정규화하며 키 이름, RuleSpec 의미와 AHK v2 구문／시작을 검증합니다. 실패, 거절, 취소는 원래 규칙을 덮어쓰지 않고 마지막 입력을 유지합니다. AI 데이터는 사용자가 기능을 직접 실행했을 때만 설정한 외부 서비스로 전송됩니다.

## 5. 설정

언어, 글꼴, 테마, 바로 가기, 예약 시작, 관리자 모드, 시작 업데이트 확인, AI 연결, 규칙 패키지와 이벤트 용량을 설정할 수 있습니다. 이벤트 뷰어는 입력, 일치, 조건 거부, 동작, 저장소와 시스템 이벤트를 필터링하고 JSONL로 내보냅니다. 공유 전 민감 정보를 확인하십시오.

## 6. 이벤트, 진단과 개인정보

규칙은 실행 폴더의 `键鼠重映射小助手.ahk`에 있고 AI·표시·시작 설정은 `%APPDATA%\KeyMouseRemapperAssistant`에 있습니다. 둘 다 백업하십시오. 공식 패키지는 현재 내장 규칙 18개를 포함하지만 `settings.ini`, `runtime.ini`, `rule-appearance.json`, `window-layout.ini`와 로컬 AI 매개변수를 제외합니다. 원격 측정이나 자동 업로드는 없습니다.

# Star History

[![Star History Chart](https://api.star-history.com/svg?repos=realSilasYang/key-mouse-remapper-assistant&type=Date)](https://star-history.com/#realSilasYang/key-mouse-remapper-assistant&Date)

# 개발자 안내서

## 1. 디렉터리와 책임

`app/`은 앱과 창, `src/Core/`는 규칙·실행·AI·기록·패키지·업데이트, `src/Input/`은 관찰과 기록, `src/Localization/`은 13개 언어, `src/Platform/`과 `src/UI/`는 Windows 통합과 UI, `tests/`와 `tools/`는 검증과 릴리스를 담당합니다.

## 2. 정확성 경계

규칙 블록은 기본 프로세스의 `Hotkey()`로 실행되고 관리형 스크립트는 중지·일시 중지·준비 신호가 있는 별도 프로세스를 사용합니다. 기록할 때만 임시 입력 보호기가 동작합니다. 규칙 쓰기는 프로세스 간 잠금, 스냅샷 비교와 원자적 교체를 사용합니다. 보안 데스크톱과 보안 주의 시퀀스는 범위 밖입니다.

## 3. 검증 명령

```powershell
.\tools\bootstrap-toolchain.ps1
.\tests\verify.ps1 -AutoHotkeyPath .\.tools\autoHotkey-2.0.26\AutoHotkey64.exe -IncludeGui
.\tools\build-release.ps1
```

## 4. 릴리스와 기여

빌드는 전체 포터블 ZIP, 전체 소스 ZIP, 선택 사항인 `fonts.zip`을 만듭니다. 두 프로그램 패키지에는 글꼴이 없고 글꼴 ZIP은 Windows 설치용입니다. 개인 상태와 로컬 AI 매개변수를 거부하고 결정론적 ZIP을 기록합니다. [변경 기록 템플릿](changelog-template.md)과 [릴리스 절차](release-process.md)를 따르십시오.

### 라이선스

이 프로젝트는 [MIT License](../LICENSE)를 사용합니다. 제3자 구성 요소는 [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md)를 참조하십시오.
