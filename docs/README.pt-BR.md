<div align="center">
  <img src="../assets/app/key-mouse-remapper-assistant.png" width="112" alt="Logotipo do Assistente de remapeamento de teclado e mouse">

  <p><a href="../README.md">简体中文</a> · <a href="./README.zh-HK.md">繁體中文（香港）</a> · <a href="./README.zh-TW.md">繁體中文（台灣）</a> · <a href="./README.en.md">English</a> · <a href="./README.ja.md">日本語</a> · <a href="./README.vi.md">Tiếng Việt</a> · <a href="./README.ko.md">한국어</a> · <a href="./README.es.md">Español</a> · <a href="./README.fr.md">Français</a> · <strong>Português</strong> · <a href="./README.ru.md">Русский</a> · <a href="./README.de.md">Deutsch</a> · <a href="./README.it.md">Italiano</a></p>

  <h1>Assistente de remapeamento de teclado e mouse</h1>
  <p><strong>Grave, escreva e gerencie mapeamentos adequados ao seu fluxo de trabalho</strong></p>

  <p><a href="https://github.com/realSilasYang/key-mouse-remapper-assistant/releases/latest"><img src="https://img.shields.io/github/v/release/realSilasYang/key-mouse-remapper-assistant?style=flat-square&amp;label=version" alt="Versão mais recente"></a> <a href="https://github.com/realSilasYang/key-mouse-remapper-assistant/releases"><img src="https://img.shields.io/github/downloads/realSilasYang/key-mouse-remapper-assistant/total?style=flat-square&amp;label=downloads" alt="Downloads"></a> <a href="../LICENSE"><img src="https://img.shields.io/github/license/realSilasYang/key-mouse-remapper-assistant?style=flat-square" alt="Licença"></a> <img src="https://img.shields.io/badge/Windows-10%20%7C%2011-0078D4?style=flat-square" alt="Windows 10 e 11"> <img src="https://img.shields.io/badge/AutoHotkey-v2-334455?style=flat-square" alt="AutoHotkey v2"></p>

  <p><a href="#visão-geral-da-interface">Interface</a> · <a href="#guia-do-usuário">Guia</a> · <a href="#4-blocos-de-regras-scripts-gerenciados-e-ia">Formas de regra</a> · <a href="https://github.com/realSilasYang/key-mouse-remapper-assistant/releases">Versões</a> · <a href="./CHANGELOG.en.md">Alterações</a> · <a href="https://github.com/realSilasYang/key-mouse-remapper-assistant/issues/new">Feedback</a> · <a href="#guia-do-desenvolvedor">Desenvolvimento</a></p>
</div>

O Assistente de remapeamento de teclado e mouse é uma ferramenta AutoHotkey v2 para Windows 10 e 11 x64. Ele reúne captura de entrada, gerenciamento de regras, edição de código, geração e otimização por IA, validação local e estado de execução. A versão 1.0.2 inclui 18 regras editáveis: 13 blocos de regras e 5 scripts gerenciados.

As regras ficam na região comentada `@mapping`, que pode ser lida e copiada. Nenhum driver ou serviço do Windows é instalado; os mapeamentos só funcionam enquanto o assistente está em execução. Os pacotes oficiais nunca incluem endereço de IA, chave de API, modelo, prompts personalizados ou outras configurações pessoais da máquina de compilação.

# Visão geral da interface

<p align="center">
  <img src="images/key-mouse-remapper-assistant-overview.png" alt="Janela principal escura" width="100%">
</p>
<p align="center">
  <img src="images/key-mouse-remapper-assistant-overview-light.png" alt="Janela principal clara" width="100%">
</p>

A barra superior adiciona, pausa／retoma em lote e exclui regras. A lista exibe ordem, nome, entrada de origem, resultado, escopo e estado. A área inferior grava origem e destino diretamente. Há seleção múltipla, arraste em lote, ordenação visual temporária, dicas para texto cortado, pontos coloridos e seleção arredondada estável.

## Principais recursos

- Captura teclado, botões do mouse, roda e teclas de navegador／mídia／inicialização, distinguindo modificadores esquerdo e direito.
- Oferece pressionar, soltar, repetir, toque, retenção, teclas simultâneas e condições de aplicativo, janela, fonte de entrada e sessão.
- Aplica blocos declarativos no processo principal e executa scripts AHK v2 completos em processos gerenciados separados.
- A IA escolhe o formato por uma única entrada; o resultado passa por normalização, validação RuleSpec e validação de sintaxe／inicialização AHK v2.
- Editor com realce de sintaxe e linhas alteradas, desfazer, refazer, excluir linha e rolagem fixa de duas linhas.
- Alterações, edições, exclusões, pausas, importações e reordenações podem ser desfeitas e refeitas.
- Treze idiomas, tema do sistema／claro／escuro, execução elevada, início com login e atualização automática.

## Escopo

- Somente Windows 10／11 x64.
- Sem driver de kernel, a área de trabalho segura, `Ctrl+Alt+Delete` e programas que bloqueiam hooks em modo usuário ficam fora do alcance.
- O modo administrador padrão eleva os blocos e scripts filhos para atuar em aplicativos elevados.
- Revise resultados de IA mesmo após a validação local, principalmente scripts com operações de arquivo, rede, processo ou sistema.

---

**[Guia do usuário](#guia-do-usuário)**<br>
[Instalação](#1-instalação-e-primeira-execução) · [Gerenciamento](#2-adição-e-gerenciamento-de-mapeamentos) · [Gravação](#3-gravação-estado-e-eventos) · [Regras e IA](#4-blocos-de-regras-scripts-gerenciados-e-ia) · [Configurações](#5-configurações) · [Privacidade](#6-eventos-diagnóstico-e-privacidade)

**[Guia do desenvolvedor](#guia-do-desenvolvedor)**<br>
[Diretórios](#1-diretórios-e-responsabilidades) · [Limites](#2-limites-de-correção) · [Verificação](#3-comandos-de-verificação) · [Publicação](#4-publicação-e-contribuição)

# Apoie o projeto

Se o assistente melhora seu trabalho diário, você pode apoiar o desenvolvimento pelos códigos QR abaixo:

<p align="center"><img src="../assets/donate/微信个人收款码.png" width="220" alt="Código QR do WeChat Pay">&nbsp;&nbsp;&nbsp;&nbsp;<img src="../assets/donate/支付宝个人收款码.png" width="220" alt="Código QR do Alipay"></p>

# Guia do usuário

## 1. Instalação e primeira execução

Baixe o ZIP portátil completo ou o ZIP de código-fonte completo em [Releases](https://github.com/realSilasYang/key-mouse-remapper-assistant/releases) e extraia tudo para uma pasta gravável. A edição portátil executa `键鼠重映射小助手.exe` e inclui um ambiente AutoHotkey v2 x64 fixo. A edição de código-fonte requer AutoHotkey v2 x64 para executar `键鼠重映射小助手.ahk`.

Nenhum dos dois ZIPs do programa contém fontes. O `fonts.zip` opcional fornece fontes Noto alternativas; instale no Windows as fontes desejadas antes de usá-las. O assistente enumera apenas fontes instaladas no Windows e nunca carrega fontes de forma privada do ZIP ou da pasta do aplicativo. As fontes não são necessárias para executar o programa.

A primeira execução solicita privilégios de administrador por padrão. Fechar a janela apenas a oculta na bandeja; use Sair na bandeja para parar todos os mapeamentos. A edição portátil não é um aplicativo de arquivo único: preserve toda a pasta ao mover ou fazer backup.

### Versões e formas de execução

A versão portátil vem do EXE e usa o ambiente incluído. A versão de código-fonte vem de `VERSION` e usa o interpretador instalado. As duas guardam regras no arquivo AHK editável da pasta de execução.

## 2. Adição e gerenciamento de mapeamentos

Adicionar abre o editor `@mapping` completo ou a geração por IA. Edite com clique duplo, F2 ou menu de contexto. Uma seleção múltipla pode ser pausada, retomada, excluída, arrastada em lote ou marcada com pontos de cor. A ordenação do cabeçalho muda apenas a exibição. Na lista principal, `Ctrl+Z` desfaz e `Ctrl+Shift+Z` refaz.

## 3. Gravação, estado e eventos

Grave a origem e o destino, informe um nome, escolha se deseja distinguir modificadores e salve. Durante a captura, o assistente pausa os mapeamentos e ativa uma proteção de entrada dedicada; ele só retoma após todas as teclas físicas serem liberadas. O estado da linha indica se a regra está ativa ou pausada e a barra inferior descreve o último resultado.

## 4. Blocos de regras, scripts gerenciados e IA

| Formato | Uso adequado | Execução |
| --- | --- | --- |
| Bloco de regras | Um gatilho, acordes, ramos de toque／retenção／soltura, condições e ações padrão | Analisa JSON comentado e aplica no processo principal |
| Script gerenciado | Vários atalhos, estado compartilhado, loops, temporizadores, funções, chamadas externas ou AHK v2 arbitrário | O assistente inicia, pausa, retoma e encerra um processo AutoHotkey separado |

A geração tem uma única entrada e a IA escolhe o formato com base nos limites reais. O resultado gerado vai direto ao editor; a otimização mostra primeiro uma revisão com sintaxe e linhas alteradas destacadas. A etapa local remove invólucros, normaliza campos, valida teclas e RuleSpec e executa validação AHK v2. Falha ou cancelamento não substitui a regra original e mantém a última solicitação.

Scripts gerenciados executam código arbitrário e exigem confirmação. Não duplique diretivas injetadas nem use `#SingleInstance Force`, `ExitApp` incondicional ou `Reload` para interromper o ciclo gerenciado.

## 5. Configurações

As configurações controlam idioma, fonte, tema, atalhos, tarefa de inicialização, modo administrador, verificação de atualização, conexão de IA, pacotes de regras e capacidade de eventos. A atualização verifica uma Release oficial, preserva a região `@mapping` e configurações não gerenciadas e restaura arquivos antigos se a substituição falhar.

## 6. Eventos, diagnóstico e privacidade

O visualizador filtra entradas, correspondências, condições rejeitadas, ações, repositório e eventos do sistema, e exporta JSONL. Revise dados de aplicativos, janelas e teclas antes de compartilhar.

As regras ficam em `键鼠重映射小助手.ahk`; configurações de IA, exibição e inicialização ficam em `%APPDATA%\KeyMouseRemapperAssistant`. Faça backup dos dois. Pacotes oficiais contêm as 18 regras atuais, mas excluem `settings.ini`, `runtime.ini`, `rule-appearance.json`, `window-layout.ini` e todos os parâmetros de IA locais. Não há telemetria nem upload automático; dados de IA só vão ao provedor configurado quando o usuário inicia uma solicitação.

# Star History

[![Star History Chart](https://api.star-history.com/svg?repos=realSilasYang/key-mouse-remapper-assistant&type=Date)](https://star-history.com/#realSilasYang/key-mouse-remapper-assistant&Date)

# Guia do desenvolvedor

## 1. Diretórios e responsabilidades

`app/` contém aplicativo e janelas; `src/Core/`, regras, execução, IA, histórico, pacotes e atualizações; `src/Input/`, observação e captura; `src/Localization/`, 13 idiomas; `src/Platform/` e `src/UI/`, integração Windows e interface; `tests/` e `tools/`, verificação e publicação.

## 2. Limites de correção

Blocos usam `Hotkey()` no processo principal; scripts usam processos separados com sinais de parada, pausa e prontidão. A captura usa uma proteção temporária. As gravações usam bloqueio entre processos, comparação de instantâneos e substituição atômica. Sequências da área de trabalho segura ficam fora do alcance.

## 3. Comandos de verificação

```powershell
.\tools\bootstrap-toolchain.ps1
.\tests\verify.ps1 -AutoHotkeyPath .\.tools\autoHotkey-2.0.26\AutoHotkey64.exe -IncludeGui
```

Dois testes que bloqueiam entrada física não fazem parte da execução autônoma padrão.

## 4. Publicação e contribuição

Execute `.\tools\build-release.ps1` para criar o ZIP portátil completo, o ZIP de código-fonte completo e o `fonts.zip` opcional. Os dois pacotes do programa não contêm fontes; o pacote de fontes deve ser instalado no Windows. O empacotamento rejeita estado pessoal e parâmetros de IA e produz arquivos determinísticos. Siga o [modelo de changelog](changelog-template.md) e o [processo de publicação](release-process.md). O projeto usa a [licença MIT](../LICENSE); consulte [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md).
