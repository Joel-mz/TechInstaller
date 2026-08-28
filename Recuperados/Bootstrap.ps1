# =============================================================================
# Tech Installer 2026 - Bootstrap.ps1
# Punto de entrada REMOTO. Se ejecuta mediante:
#   irm https://raw.githubusercontent.com/TU_USUARIO/TechInstaller/main/Bootstrap.ps1 | iex
#
# IMPORTANTE DE SEGURIDAD:
#   Este script NO ejecuta cdigo remoto a ciegas.
#   1. Descarga el repositorio completo como ZIP desde GitHub.
#   2. Lo extrae en una carpeta controlada del usuario.
#   3. Ejecuta el archivo Launcher.ps1 LOCAL descargado.
#   El usuario puede inspeccionar todos los archivos antes de que se ejecuten.
# =============================================================================

#Requires -Version 5.1

[CmdletBinding()]
param(
    [string]$GitHubUser = "TU_USUARIO_GITHUB",
    [string]$Repository = "TechInstaller",
    [string]$Branch     = "main",
    [string]$InstallDir = ""
)

# =============================================================================
# CONFIGURACIN
# =============================================================================
$GITHUB_USER   = $GitHubUser
$GITHUB_REPO   = $Repository
$GITHUB_BRANCH = $Branch

# Directorio de instalacin (por defecto en AppData del usuario para no requerir admin)
if ([string]::IsNullOrEmpty($InstallDir)) {
    $INSTALL_DIR = Join-Path $env:LOCALAPPDATA "TechInstaller2026"
} else {
    $INSTALL_DIR = $InstallDir
}

# URLs
$ZIP_URL        = "https://github.com/$GITHUB_USER/$GITHUB_REPO/archive/refs/heads/$GITHUB_BRANCH.zip"
$VERSION_URL    = "https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/$GITHUB_BRANCH/version.json"
$LAUNCHER_REL   = "$GITHUB_REPO-$GITHUB_BRANCH\Launcher.ps1"

# =============================================================================
# FUNCIONES AUXILIARES DEL BOOTSTRAP
# =============================================================================
function Write-Header {
    Clear-Host
    Write-Host ""
    Write-Host "  +==========================================================+" -ForegroundColor Cyan
    Write-Host "  |          TECH INSTALLER 2026 - Bootstrap                |" -ForegroundColor Cyan
    Write-Host "  |       Herramienta profesional para tcnicos             |" -ForegroundColor Cyan
    Write-Host "  +==========================================================+" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Step {
    param([string]$Mensaje, [string]$Tipo = "INFO")
    $color = switch ($Tipo) {
        "OK"      { "Green"   }
        "WARN"    { "Yellow"  }
        "ERROR"   { "Red"     }
        "STEP"    { "Cyan"    }
        default   { "Gray"    }
    }
    $prefijo = switch ($Tipo) {
        "OK"    { "  [[OK]]" }
        "WARN"  { "  [[!]]" }
        "ERROR" { "  [[X]]" }
        "STEP"  { "  []" }
        default { "  []" }
    }
    Write-Host "$prefijo $Mensaje" -ForegroundColor $color
}

function Test-WindowsOS {
    if ($env:OS -ne "Windows_NT") {
        Write-Step "Este script solo es compatible con Windows." "ERROR"
        exit 1
    }
    Write-Step "Sistema operativo: Windows" "OK"
}

function Test-PowerShellVersion {
    $version = $PSVersionTable.PSVersion
    if ($version.Major -lt 5) {
        Write-Step "Se requiere PowerShell 5.1 o superior. Versin actual: $version" "ERROR"
        exit 1
    }
    Write-Step "PowerShell: $($version.ToString())" "OK"
}

function Test-InternetConnection {
    try {
        $null = Invoke-WebRequest -Uri "https://github.com" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
        Write-Step "Conexin a Internet: disponible" "OK"
        return $true
    } catch {
        Write-Step "Sin conexin a Internet. Verifica tu conexin." "ERROR"
        return $false
    }
}

function Get-RemoteVersionInfo {
    try {
        $contenido = Invoke-WebRequest -Uri $VERSION_URL -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
        $version = $contenido.Content | ConvertFrom-Json
        return $version
    } catch {
        return $null
    }
}

function Get-LocalInstallVersion {
    $versionFile = Join-Path $INSTALL_DIR "version.json"
    if (Test-Path $versionFile) {
        try {
            $contenido = Get-Content $versionFile -Raw | ConvertFrom-Json
            return $contenido.version
        } catch { }
    }
    return $null
}

function Download-Repository {
    param([string]$DestPath)

    Write-Step "Descargando repositorio desde GitHub..." "STEP"
    Write-Step "URL: $ZIP_URL" "INFO"

    $zipTemp = Join-Path $env:TEMP "TechInstaller_bootstrap.zip"
    $extTemp = Join-Path $env:TEMP "TechInstaller_bootstrap_ext"

    try {
        # Descargar ZIP
        $webClient = New-Object System.Net.WebClient
        $webClient.Headers.Add("User-Agent", "TechInstaller2026-Bootstrap/1.0")
        $webClient.DownloadFile($ZIP_URL, $zipTemp)
        Write-Step "Descarga completada." "OK"

        # Extraer
        Write-Step "Extrayendo archivos..." "STEP"
        if (Test-Path $extTemp) { Remove-Item $extTemp -Recurse -Force }
        Expand-Archive -Path $zipTemp -DestinationPath $extTemp -Force

        # Mover al destino
        Write-Step "Instalando en: $DestPath" "STEP"
        if (Test-Path $DestPath) { Remove-Item $DestPath -Recurse -Force }

        # El ZIP de GitHub extrae en una subcarpeta con el nombre del repo
        $subcarpeta = Get-ChildItem $extTemp -Directory | Select-Object -First 1
        if ($subcarpeta) {
            Move-Item $subcarpeta.FullName $DestPath
        } else {
            throw "No se encontr la carpeta extrada."
        }

        # Limpiar temporales
        Remove-Item $zipTemp  -Force -ErrorAction SilentlyContinue
        Remove-Item $extTemp  -Recurse -Force -ErrorAction SilentlyContinue

        Write-Step "Instalacin completada en: $DestPath" "OK"
        return $true

    } catch {
        Write-Step "Error durante la descarga: $_" "ERROR"
        Remove-Item $zipTemp -Force -ErrorAction SilentlyContinue
        Remove-Item $extTemp -Recurse -Force -ErrorAction SilentlyContinue
        return $false
    }
}

function Launch-TechInstaller {
    param([string]$InstallPath)

    $launcherPath = Join-Path $InstallPath "Launcher.ps1"

    if (-not (Test-Path $launcherPath)) {
        Write-Step "No se encontr Launcher.ps1 en: $InstallPath" "ERROR"
        Write-Host ""
        Write-Host "  Contenido de la carpeta:" -ForegroundColor Yellow
        Get-ChildItem $InstallPath | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
        exit 1
    }

    Write-Step "Iniciando Tech Installer 2026..." "STEP"
    Write-Step "Ejecutando: $launcherPath" "INFO"
    Write-Host ""

    try {
        # Lanzar el Launcher local en una nueva ventana PowerShell
        $argumentos = "-NoProfile -ExecutionPolicy Bypass -File `"$launcherPath`""
        Start-Process powershell.exe -ArgumentList $argumentos
        Write-Step "Tech Installer 2026 iniciado!" "OK"

    } catch {
        Write-Step "Error al iniciar la aplicacin: $_" "ERROR"
        exit 1
    }
}

# =============================================================================
# EJECUCIN PRINCIPAL DEL BOOTSTRAP
# =============================================================================
Write-Header

# Verificaciones previas
Write-Host "  Verificando requisitos del sistema..." -ForegroundColor Cyan
Write-Host ""

Test-WindowsOS
Test-PowerShellVersion

if (-not (Test-InternetConnection)) {
    # Sin Internet: intentar ejecutar instalacin local si existe
    if (Test-Path (Join-Path $INSTALL_DIR "Launcher.ps1")) {
        Write-Step "Usando instalacin local existente (sin Internet)." "WARN"
        Launch-TechInstaller -InstallPath $INSTALL_DIR
    } else {
        Write-Step "No hay instalacin local ni conexin a Internet. Abortando." "ERROR"
        exit 1
    }
    exit 0
}

Write-Host ""
Write-Host "  Verificando versin disponible..." -ForegroundColor Cyan

# Verificar versiones
$versionRemota = Get-RemoteVersionInfo
$versionLocal  = Get-LocalInstallVersion

$necesitaDescarga = $true

if ($versionRemota -and $versionLocal) {
    Write-Step "Versin local    : $versionLocal" "INFO"
    Write-Step "Versin remota   : $($versionRemota.version)" "INFO"

    try {
        $vLocal  = [Version]$versionLocal
        $vRemota = [Version]$versionRemota.version

        if ($vLocal -ge $vRemota) {
            Write-Step "La instalacin local est actualizada." "OK"
            $necesitaDescarga = $false
        } else {
            Write-Step "Nueva versin disponible. Descargando actualizacin..." "STEP"
        }
    } catch {
        Write-Step "No se pudo comparar versiones. Descargando de nuevo..." "WARN"
    }

} elseif (Test-Path (Join-Path $INSTALL_DIR "Launcher.ps1")) {
    Write-Step "No se pudo verificar la versin remota. Usando instalacin local." "WARN"
    $necesitaDescarga = $false
}

if ($necesitaDescarga) {
    Write-Host ""
    Write-Host "  Descargando Tech Installer 2026..." -ForegroundColor Cyan
    Write-Host ""

    # Verificar/crear directorio de instalacin
    if (-not (Test-Path (Split-Path $INSTALL_DIR -Parent))) {
        New-Item -ItemType Directory -Path (Split-Path $INSTALL_DIR -Parent) -Force | Out-Null
    }

    $descargaExitosa = Download-Repository -DestPath $INSTALL_DIR

    if (-not $descargaExitosa) {
        Write-Host ""
        Write-Step "La descarga fall. Verifica tu conexin a Internet e intntalo de nuevo." "ERROR"
        Write-Host ""
        Write-Host "  Tambin puedes:" -ForegroundColor Yellow
        Write-Host "    1. Descargar el proyecto manualmente desde GitHub" -ForegroundColor Gray
        Write-Host "    2. Ejecutar Launcher.ps1 directamente desde la carpeta descargada" -ForegroundColor Gray
        Write-Host ""
        exit 1
    }
}

Write-Host ""
Write-Host "  -------------------------------" -ForegroundColor DarkGray

# Lanzar la aplicacin
Launch-TechInstaller -InstallPath $INSTALL_DIR

Write-Host ""
Write-Host "  Bootstrap completado. La ventana de Tech Installer 2026 se ha abierto." -ForegroundColor Green
Write-Host "  Instalacin ubicada en: $INSTALL_DIR" -ForegroundColor Gray
Write-Host ""
