<div align="center">
  <img src="../assets/app/key-mouse-remapper-assistant.png" width="112" alt="Logotipo del Asistente de reasignación de teclado y ratón">

  <p><a href="../README.md">简体中文</a> · <a href="./README.zh-HK.md">繁體中文（香港）</a> · <a href="./README.zh-TW.md">繁體中文（台灣）</a> · <a href="./README.en.md">English</a> · <a href="./README.ja.md">日本語</a> · <a href="./README.vi.md">Tiếng Việt</a> · <a href="./README.ko.md">한국어</a> · <strong>Español</strong> · <a href="./README.fr.md">Français</a> · <a href="./README.pt-BR.md">Português</a> · <a href="./README.ru.md">Русский</a> · <a href="./README.de.md">Deutsch</a> · <a href="./README.it.md">Italiano</a></p>

  <h1>Asistente de reasignación de teclado y ratón</h1>
  <p><strong>Graba, escribe y administra asignaciones adaptadas a tu forma de trabajar</strong></p>

  <p><a href="https://github.com/realSilasYang/key-mouse-remapper-assistant/releases/latest"><img src="https://img.shields.io/github/v/release/realSilasYang/key-mouse-remapper-assistant?style=flat-square&amp;label=version" alt="Última versión"></a> <a href="https://github.com/realSilasYang/key-mouse-remapper-assistant/releases"><img src="https://img.shields.io/github/downloads/realSilasYang/key-mouse-remapper-assistant/total?style=flat-square&amp;label=downloads" alt="Descargas"></a> <a href="../LICENSE"><img src="https://img.shields.io/github/license/realSilasYang/key-mouse-remapper-assistant?style=flat-square" alt="Licencia"></a> <img src="https://img.shields.io/badge/Windows-10%20%7C%2011-0078D4?style=flat-square" alt="Windows 10 y 11"> <img src="https://img.shields.io/badge/AutoHotkey-v2-334455?style=flat-square" alt="AutoHotkey v2"></p>

  <p><a href="#vista-general-de-la-interfaz">Interfaz</a> · <a href="#guía-de-usuario">Guía</a> · <a href="#4-bloques-de-reglas-scripts-administrados-e-ia">Tipos de regla</a> · <a href="https://github.com/realSilasYang/key-mouse-remapper-assistant/releases">Versiones</a> · <a href="./CHANGELOG.en.md">Cambios</a> · <a href="https://github.com/realSilasYang/key-mouse-remapper-assistant/issues/new">Comentarios</a> · <a href="#guía-para-desarrolladores">Desarrollo</a></p>
</div>

El Asistente de reasignación de teclado y ratón es una aplicación AutoHotkey v2 para Windows 10 y 11 x64. Reúne captura de entradas, administración de reglas, edición de código, generación y optimización con IA, validación local y estado de ejecución. Cada versión incluye las reglas editables presentes en su commit de publicación; la cantidad de bloques y scripts administrados puede variar.

Las reglas se guardan en la región comentada `@mapping`, que se puede leer y respaldar. La aplicación no instala controladores ni servicios de Windows; las asignaciones solo funcionan mientras el asistente está abierto. Los paquetes oficiales nunca incluyen la dirección de IA, la clave de API, el modelo, las indicaciones personalizadas ni otros ajustes del equipo de compilación.

# Vista general de la interfaz

<p align="center">
  <img src="images/key-mouse-remapper-assistant-overview.png" alt="Ventana principal oscura" width="100%">
</p>
<p align="center">
  <img src="images/key-mouse-remapper-assistant-overview-light.png" alt="Ventana principal clara" width="100%">
</p>

La barra superior añade, pausa／reanuda por lotes y elimina reglas. La lista muestra orden, nombre, entrada de origen, resultado, ámbito y estado. La zona inferior graba el origen y el destino. Hay selección múltiple, arrastre por lotes, orden visual temporal, ayudas para texto recortado, puntos de color y una selección redondeada estable.

## Funciones principales

- Captura teclado, botones de ratón, rueda y teclas de navegador／multimedia／inicio, distinguiendo modificadores izquierdos y derechos.
- Admite pulsación, liberación, repetición, toque, retención, teclas simultáneas y condiciones de aplicación, ventana, método de entrada y sesión.
- Aplica bloques declarativos en el proceso principal y ejecuta scripts AHK v2 completos en procesos administrados separados.
- La IA elige el formato desde una única entrada y el resultado pasa por normalización, validación RuleSpec y validación de sintaxis／inicio AHK v2.
- El editor ofrece resaltado de sintaxis y de líneas cambiadas, deshacer, rehacer, borrar línea y desplazamiento fijo de dos líneas.
- Se pueden deshacer y rehacer altas, ediciones, borrados, pausas, importaciones y reordenaciones.
- Incluye 13 idiomas, tema del sistema／claro／oscuro, ejecución elevada, inicio de sesión y actualización automática.

## Ámbito

- Solo admite Windows 10／11 x64.
- No usa un controlador del núcleo, por lo que no controla el escritorio seguro, `Ctrl+Alt+Delete` ni software que bloquee ganchos de modo usuario.
- El modo administrador predeterminado eleva los bloques y los scripts secundarios para que puedan actuar sobre aplicaciones elevadas.
- Debes revisar los resultados de IA incluso después de la validación local, especialmente scripts con operaciones de archivos, red, procesos o sistema.

---

**[Guía de usuario](#guía-de-usuario)**<br>
[Instalación](#1-instalación-y-primer-inicio) · [Administración](#2-adición-y-administración-de-asignaciones) · [Grabación](#3-grabación-estado-y-eventos) · [Reglas e IA](#4-bloques-de-reglas-scripts-administrados-e-ia) · [Ajustes](#5-ajustes) · [Privacidad](#6-eventos-diagnóstico-y-privacidad)

**[Guía para desarrolladores](#guía-para-desarrolladores)**<br>
[Directorios](#1-directorios-y-responsabilidades) · [Límites](#2-límites-de-corrección) · [Verificación](#3-comandos-de-verificación) · [Publicación](#4-publicación-y-contribución)

# Apoya el proyecto

Si el asistente mejora tu trabajo diario, puedes apoyar su desarrollo con estos códigos QR:

<p align="center"><img src="../assets/donate/微信个人收款码.png" width="220" alt="Código QR de WeChat Pay">&nbsp;&nbsp;&nbsp;&nbsp;<img src="../assets/donate/支付宝个人收款码.png" width="220" alt="Código QR de Alipay"></p>

# Guía de usuario

## 1. Instalación y primer inicio

Descarga el ZIP portátil completo o el ZIP de código fuente completo desde [Releases](https://github.com/realSilasYang/key-mouse-remapper-assistant/releases) y extráelo íntegramente en una carpeta con permisos de escritura. La edición portátil ejecuta `键鼠重映射小助手.exe` e incluye un entorno AutoHotkey v2 x64 fijo. La edición fuente requiere AutoHotkey v2 x64 para ejecutar `键鼠重映射小助手.ahk`.

Ninguno de los dos ZIP del programa incluye fuentes. El `fonts.zip` opcional proporciona fuentes Noto alternativas; instala en Windows las que necesites antes de usarlas. El asistente solo enumera fuentes instaladas en Windows y nunca las carga de forma privada desde el ZIP ni desde la carpeta de la aplicación. Las fuentes no son necesarias para ejecutar el programa.

El primer inicio solicita permisos de administrador de forma predeterminada. Cerrar la ventana solo la oculta en la bandeja; usa Salir en la bandeja para detener todas las asignaciones. La edición portátil no es una aplicación de un solo archivo: conserva la carpeta completa al moverla o respaldarla.

### Versiones y formas de ejecución

La versión portátil obtiene su versión del EXE y usa el entorno incluido. La versión fuente obtiene la versión de `VERSION` y usa el intérprete instalado. Ambas conservan las reglas en el archivo AHK editable del directorio de ejecución.

## 2. Adición y administración de asignaciones

Añadir abre el editor `@mapping` completo o la generación con IA. Edita con doble clic, F2 o el menú contextual. Una selección múltiple se puede pausar, reanudar, eliminar, arrastrar en bloque o marcar con puntos de color. Ordenar por encabezado solo cambia la vista. En la lista principal, `Ctrl+Z` deshace y `Ctrl+Shift+Z` rehace.

## 3. Grabación, estado y eventos

Graba el origen y el destino, escribe un nombre, decide si distingues modificadores y guarda. Durante la grabación, el asistente pausa las asignaciones y activa una protección de entrada dedicada; solo reanuda después de liberar todas las teclas físicas. El estado de cada fila indica si la regla está activa o pausada y la barra inferior explica el último resultado.

## 4. Bloques de reglas, scripts administrados e IA

| Formato | Uso adecuado | Ejecución |
| --- | --- | --- |
| Bloque de reglas | Un disparador, combinaciones, ramas de toque／retención／liberación, condiciones y acciones estándar | Analiza JSON comentado y se aplica en caliente en el proceso principal |
| Script administrado | Varios atajos, estado compartido, bucles, temporizadores, funciones, llamadas externas o AHK v2 arbitrario | El asistente inicia, pausa, reanuda y detiene un proceso AutoHotkey separado |

La generación tiene una sola entrada y la IA decide el formato usando los límites reales de la aplicación. El resultado generado entra directamente al editor; la optimización muestra primero una revisión con sintaxis y líneas cambiadas resaltadas. El proceso local limpia envoltorios, normaliza campos, valida nombres y RuleSpec y ejecuta la validación AHK v2. Un fallo o cancelación no reemplaza la regla original y conserva la última solicitud.

Los scripts administrados ejecutan código arbitrario y requieren confirmación. No dupliques las directivas inyectadas ni uses `#SingleInstance Force`, `ExitApp` incondicional o `Reload` para romper el ciclo administrado.

## 5. Ajustes

Los ajustes controlan idioma, fuente, tema, accesos directos, tarea de inicio, modo administrador, comprobación de actualizaciones, conexión de IA, paquetes de reglas y capacidad de eventos. La actualización verifica una publicación formal, conserva la región `@mapping` y los ajustes no administrados y revierte si falla el reemplazo.

## 6. Eventos, diagnóstico y privacidad

El visor filtra entrada, coincidencias, condiciones rechazadas, acciones, repositorio y eventos del sistema, y exporta JSONL. Revisa datos de aplicaciones, ventanas y teclas antes de compartirlos.

Las reglas están en `键鼠重映射小助手.ahk`; los ajustes de IA, interfaz e inicio están en `%APPDATA%\KeyMouseRemapperAssistant`. Respalda ambos. Los paquetes oficiales contienen las reglas presentes en el commit de publicación, pero excluyen `settings.ini`, `runtime.ini`, `rule-appearance.json`, `window-layout.ini` y todos los parámetros de IA locales. El proyecto no tiene telemetría ni carga automática; los datos de IA solo van al proveedor configurado cuando el usuario inicia una solicitud.

# Star History

[![Star History Chart](https://api.star-history.com/svg?repos=realSilasYang/key-mouse-remapper-assistant&type=Date)](https://star-history.com/#realSilasYang/key-mouse-remapper-assistant&Date)

# Guía para desarrolladores

## 1. Directorios y responsabilidades

`app/` contiene la aplicación y las ventanas; `src/Core/`, las reglas, ejecución, IA, historial, paquetes y actualizaciones; `src/Input/`, observación y captura; `src/Localization/`, 13 idiomas; `src/Platform/` y `src/UI/`, integración Windows e interfaz; `tests/` y `tools/`, verificación y publicación.

## 2. Límites de corrección

Los bloques se ejecutan mediante `Hotkey()` en el proceso principal; los scripts usan procesos separados con señales de detención, pausa y preparación. La captura usa una protección temporal. Las escrituras de reglas emplean bloqueo entre procesos, comparación de instantáneas y reemplazo atómico. Las secuencias del escritorio seguro permanecen fuera del alcance.

## 3. Comandos de verificación

```powershell
.\tools\bootstrap-toolchain.ps1
.\tests\verify.ps1 -AutoHotkeyPath .\.tools\autoHotkey-2.0.26\AutoHotkey64.exe -IncludeGui
```

Dos pruebas que bloquean entrada física no forman parte de la ejecución desatendida predeterminada.

## 4. Publicación y contribución

Ejecuta `.\tools\build-release.ps1` para generar el ZIP portátil completo, el ZIP fuente completo y el `fonts.zip` opcional. Los dos paquetes del programa no contienen fuentes; el paquete de fuentes se instala en Windows. El empaquetado rechaza estado personal y parámetros de IA y produce archivos deterministas. Sigue la [plantilla del registro](changelog-template.md) y el [proceso de publicación](release-process.md). El proyecto usa la [licencia MIT](../LICENSE); consulta [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md).
