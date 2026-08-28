# Tech Installer 2026

<div align="center">

```
  ╔══════════════════════════════════════════════════════════╗
  ║          TECH INSTALLER 2026                            ║
  ║       Herramienta profesional para técnicos             ║
  ╚══════════════════════════════════════════════════════════╝
```

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue?style=flat-square&logo=powershell)](https://docs.microsoft.com/en-us/powershell/)
[![Windows](https://img.shields.io/badge/Windows-10%2F11-blue?style=flat-square&logo=windows)](https://www.microsoft.com/windows)
[![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)](LICENSE)

</div>

---

## 📋 Tabla de contenidos

1. [¿Qué es TechInstaller?](#1--qué-es-techinstaller)
2. [Requisitos](#2--requisitos)
3. [Instalación y uso local](#3--instalación-y-uso-local)
4. [Uso desde GitHub (comando remoto)](#4--uso-desde-github-comando-remoto)
5. [Cómo agregar programas](#5--cómo-agregar-programas)
6. [Cómo configurar argumentos de instalación](#6--cómo-configurar-argumentos-de-instalación)
7. [Cómo crear una nueva categoría](#7--cómo-crear-una-nueva-categoría)
8. [Cómo actualizar la herramienta](#8--cómo-actualizar-la-herramienta)
9. [Cómo subir cambios a GitHub](#9--cómo-subir-cambios-a-github)
10. [Seguridad](#10--seguridad)
11. [Licencias de software de terceros](#11--licencias-de-software-de-terceros)
12. [Estructura del proyecto](#12--estructura-del-proyecto)

---

## 1. 🚀 ¿Qué es TechInstaller?

**Tech Installer 2026** es una herramienta profesional desarrollada en **PowerShell** con interfaz gráfica (Windows Forms) diseñada para **técnicos de soporte informático**.

Permite:
- 📦 Detectar y ejecutar instaladores automáticamente desde una carpeta
- 🗂️ Organizar programas por categorías (Office, Navegadores, PDF, etc.)
- 🔍 Buscar programas fácilmente
- ⚡ Instalar múltiples programas seleccionados en secuencia
- 🖥️ Consultar información del sistema del equipo
- 🌐 Usar herramientas de diagnóstico de red
- 📋 Registrar todas las operaciones en logs
- 🔄 Actualizarse automáticamente desde GitHub

**Funciona desde:**
- Carpeta local en cualquier unidad
- Disco USB o disco externo
- Proyecto descargado o clonado desde GitHub
- Cualquier equipo Windows 10/11

---

## 2. ✅ Requisitos

| Requisito | Versión mínima |
|-----------|---------------|
| Sistema operativo | Windows 10 / Windows 11 |
| PowerShell | 5.1 o superior (incluido en Windows 10/11) |
| .NET Framework | 4.5+ (incluido en Windows 10/11) |
| Conexión a Internet | Solo para Bootstrap y actualizaciones |
| Permisos de administrador | Solo para la instalación de programas |

---

## 3. 💻 Instalación y uso local

### Opción A: Desde una copia local

1. Descarga o clona el proyecto:
   ```bash
   git clone https://github.com/Joel-mz/TechInstaller.git
   ```

2. Navega a la carpeta:
   ```
   cd TechInstaller
   ```

3. Ejecuta el launcher:
   ```powershell
   powershell.exe -ExecutionPolicy Bypass -File ".\Launcher.ps1"
   ```

### Opción B: Doble clic (sin abrir PowerShell manualmente)

Crea un archivo `Iniciar.bat` con este contenido:
```bat
@echo off
powershell.exe -ExecutionPolicy Bypass -WindowStyle Normal -File "%~dp0Launcher.ps1"
pause
```

---

## 4. 🌐 Uso desde GitHub (comando remoto)

Una vez que hayas subido el proyecto a GitHub, cualquier técnico puede ejecutar:

```powershell
irm https://raw.githubusercontent.com/Joel-mz/TechInstaller/main/Bootstrap.ps1 | iex
```

### ¿Qué hace el Bootstrap?

1. ✅ Verifica que el sistema sea Windows con PowerShell 5.1+
2. ✅ Verifica la conexión a Internet
3. ✅ Compara la versión instalada con la versión remota en GitHub
4. ✅ Si es necesario, descarga el repositorio ZIP desde GitHub
5. ✅ Extrae los archivos en `%LOCALAPPDATA%\TechInstaller2026`
6. ✅ Ejecuta el `Launcher.ps1` **local** (no código remoto en memoria)

> **Seguridad:** El Bootstrap descarga el código, lo guarda localmente y **luego** lo ejecuta. Nunca ejecuta código remoto sin descargarlo primero. Puedes inspeccionar la carpeta `%LOCALAPPDATA%\TechInstaller2026` para ver exactamente qué se descargó.

### Parámetros avanzados del Bootstrap:

```powershell
# Especificar usuario y repositorio (útil si tienes un fork)
irm https://raw.githubusercontent.com/Joel-mz/TechInstaller/main/Bootstrap.ps1 | iex

# O descargarlo y ejecutarlo con parámetros:
$url = "https://raw.githubusercontent.com/Joel-mz/TechInstaller/main/Bootstrap.ps1"
$script = Invoke-WebRequest $url -UseBasicParsing | Select-Object -ExpandProperty Content
& ([scriptblock]::Create($script)) -GitHubUser "Joel-mz" -Branch "main"
```

---

## 5. 📦 Cómo agregar programas

**No es necesario editar ningún script.**

Simplemente copia el instalador en la subcarpeta correspondiente dentro de `Programas/`:

```
TechInstaller/
└── Programas/
    ├── Office/
    │   └── OfficeSetup.exe        ← Aquí
    ├── Navegadores/
    │   └── ChromeSetup.exe        ← Aquí
    ├── PDF/
    │   └── AdobeReader.exe        ← Aquí
    ├── Utilidades/
    │   └── 7zip.exe               ← Aquí
    └── Drivers/
        └── IntelDriver.exe        ← Aquí
```

Luego, en la aplicación, haz clic en **"↻ Actualizar lista"** y el programa aparecerá automáticamente.

**Formatos soportados:**
- `.exe` - Instaladores ejecutables
- `.msi` - Paquetes de instalación de Windows
- `.bat` - Scripts de instalación por lotes
- `.cmd` - Scripts de comandos

---

## 6. ⚙️ Cómo configurar argumentos de instalación

Edita el archivo `Config/categories.json` para añadir argumentos silenciosos a tus programas:

```json
{
  "ProgramConfigs": [
    {
      "Name": "7-Zip",
      "File": "7z*.exe",
      "Category": "Compresores",
      "Arguments": "/S",
      "Version": "23.01",
      "OfficialURL": "https://www.7-zip.org/",
      "Notes": "/S para instalación silenciosa oficial de 7-Zip"
    },
    {
      "Name": "Mi Programa",
      "File": "MiPrograma_v2.exe",
      "Category": "Utilidades",
      "Arguments": "/quiet /norestart",
      "Version": "2.0",
      "OfficialURL": "",
      "Notes": ""
    }
  ]
}
```

**Notas importantes:**
- El campo `File` soporta wildcards (`*`) para matchear versiones
- Si el programa no está en `ProgramConfigs`, se ejecuta sin argumentos
- Los argumentos solo se usan en **Modo silencioso (⚡)**
- No inventes argumentos: cada instalador tiene los suyos propios

---

## 7. 🗂️ Cómo crear una nueva categoría

1. Crea la carpeta dentro de `Programas/`:
   ```
   Programas/
   └── MiCategoria/
       └── MiPrograma.exe
   ```

2. La categoría se detecta automáticamente por el nombre de la carpeta.

3. Opcionalmente, agrégala en `Config/categories.json` para que aparezca en la barra lateral con un ícono personalizado:
   ```json
   {
     "Name": "MiCategoria",
     "FolderName": "MiCategoria",
     "Icon": "🔧",
     "Color": "#3498DB",
     "Description": "Descripción de la categoría"
   }
   ```

4. Haz clic en **"↻ Actualizar lista"**.

---

## 8. 🔄 Cómo actualizar la herramienta

### Desde la aplicación:
1. Ve a **"🔄 Actualizaciones"** en el menú lateral
2. Haz clic en **"🔍 Buscar actualizaciones"**
3. Si hay una versión nueva, haz clic en **"⬇ Descargar actualización"**

### Manualmente:
```bash
git pull origin main
```

### Publicar una nueva versión:
1. Actualiza `version.json`:
   ```json
   {
     "version": "1.1.0",
     "releaseDate": "2026-09-01",
     "releaseNotes": "Nueva funcionalidad X añadida."
   }
   ```
2. Sube los cambios a GitHub (ver sección siguiente)

---

## 9. 📤 Cómo subir cambios a GitHub

### Primera vez (inicialización):
```bash
cd TechInstaller

git init
git add .
git commit -m "feat: versión inicial de Tech Installer 2026"
git branch -M main
git remote add origin https://github.com/Joel-mz/TechInstaller.git
git push -u origin main
```

### Actualizaciones posteriores:
```bash
git add .
git commit -m "feat: descripción de los cambios"
git push
```

> **Nota:** Los instaladores `.exe` y `.msi` están excluidos del `.gitignore` por defecto. Solo se sube la estructura del proyecto. Así el repositorio es ligero y no redistribuyes software de terceros.

---

## 10. 🔒 Seguridad

Este proyecto está diseñado con principios de seguridad explícitos:

| ✅ Lo que SÍ hace | ❌ Lo que NO hace |
|-------------------|------------------|
| Solicita UAC estándar de Windows | Desactivar Windows Defender |
| Descarga código y lo ejecuta localmente | Desactivar el Firewall |
| Registra todas las operaciones en logs | Bypass de UAC |
| Permite inspeccionar el código fuente | Ejecutar código remoto sin descargarlo |
| Usa rutas locales relativas | Robar credenciales |
| Solo instala lo que tú decides | Incluir activadores o cracks |

**Política de software de terceros:**
- No se incluyen instaladores en el repositorio
- No se distribuye software sin licencia
- Cada técnico debe tener sus propios instaladores con licencias válidas

---

## 11. 📜 Licencias de software de terceros

Este proyecto (Tech Installer 2026) está bajo licencia **MIT**.

> **IMPORTANTE:** Tech Installer 2026 es únicamente una herramienta de gestión y ejecución. No incluye, ni redistribuye, ningún software de terceros. Cada programa que agregues en la carpeta `Programas/` es responsabilidad del técnico que lo instala, quien debe contar con las licencias correspondientes.

Ejemplos de licencias de software común:
- Microsoft Office: Requiere licencia válida de Microsoft
- Adobe Reader: Gratuito para uso personal, ver términos en adobe.com
- 7-Zip: Licencia GNU LGPL (libre y gratuita)
- Google Chrome: Consultar términos en google.com/chrome/
- VLC: Licencia GNU GPL (libre y gratuita)

---

## 12. 📁 Estructura del proyecto

```
TechInstaller/
│
├── Bootstrap.ps1          → Punto de entrada remoto (GitHub)
├── Launcher.ps1           → Aplicación principal con GUI
├── version.json           → Control de versiones
├── README.md              → Esta documentación
├── LICENSE                → Licencia MIT
├── .gitignore             → Exclusiones de Git
│
├── Config/
│   ├── config.json        → Configuración general
│   └── categories.json    → Categorías y argumentos de instaladores
│
├── Scripts/
│   ├── Functions.ps1      → Funciones utilitarias (sistema, config)
│   ├── Installer.ps1      → Lógica de instalación (EXE, MSI, BAT)
│   ├── Detection.ps1      → Detección automática de instaladores
│   ├── Update.ps1         → Sistema de actualizaciones
│   └── Logging.ps1        → Sistema de logs
│
├── Programas/
│   ├── Office/            → Instaladores de Office (añadir aquí)
│   ├── Navegadores/       → Instaladores de navegadores
│   ├── PDF/               → Lectores y editores PDF
│   ├── Compresores/       → 7-Zip, WinRAR, etc.
│   ├── Multimedia/        → VLC, reproductores, etc.
│   ├── Utilidades/        → Herramientas del sistema
│   ├── AccesoRemoto/      → TeamViewer, AnyDesk, etc.
│   └── Drivers/           → Controladores de dispositivos
│
├── Assets/
│   ├── logo.png           → Logo de la herramienta
│   └── icons/             → Iconos adicionales
│
└── Logs/                  → Registros de actividad (ignorado por Git)
    └── TechInstaller_YYYY-MM-DD.log
```

---

<div align="center">

**Tech Installer 2026** — Desarrollado con PowerShell 💙

*Herramienta profesional para técnicos de soporte*

</div>

