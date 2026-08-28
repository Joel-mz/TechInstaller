# =============================================================================
# Tech Installer 2026 - Scripts/Logging.ps1
# Mdulo de registro de eventos y actividades
# =============================================================================

# Nivel de log actual (se establece desde la configuracin)
$script:LogLevel = "INFO"
$script:LogFile = $null

# -----------------------------------------------------------------------------
# Funcin: Initialize-Log
# Descripcin: Inicializa el sistema de logs creando el archivo del da actual
# -----------------------------------------------------------------------------
function Initialize-Log {
    param (
        [string]$LogsFolder,
        [string]$Level = "INFO"
    )

    try {
        $script:LogLevel = $Level

        # Crear directorio de logs si no existe
        if (-not (Test-Path $LogsFolder)) {
            New-Item -ItemType Directory -Path $LogsFolder -Force | Out-Null
        }

        # Nombre del archivo basado en la fecha actual
        $fecha = Get-Date -Format "yyyy-MM-dd"
        $script:LogFile = Join-Path $LogsFolder "TechInstaller_$fecha.log"

        # Crear archivo si no existe y escribir encabezado de sesin
        $encabezado = @"
================================================================================
  TECH INSTALLER 2026 - Sesin iniciada: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
  Usuario: $env:USERNAME
  Equipo:  $env:COMPUTERNAME
================================================================================
"@
        Add-Content -Path $script:LogFile -Value $encabezado -Encoding UTF8

        Write-Log "Sistema de logs iniciado correctamente." "INFO"

    } catch {
        Write-Warning "No se pudo inicializar el sistema de logs: $_"
    }
}

# -----------------------------------------------------------------------------
# Funcin: Write-Log
# Descripcin: Escribe una entrada en el archivo de log con timestamp
# Parmetros:
#   $Message  - Mensaje a registrar
#   $Level    - Nivel: INFO, WARNING, ERROR, SUCCESS, ACTION
# -----------------------------------------------------------------------------
function Write-Log {
    param (
        [string]$Message,
        [ValidateSet("INFO", "WARNING", "ERROR", "SUCCESS", "ACTION", "UPDATE")]
        [string]$Level = "INFO"
    )

    try {
        if ($null -eq $script:LogFile) { return }

        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $lineaLog  = "[$timestamp] [$Level] $Message"

        Add-Content -Path $script:LogFile -Value $lineaLog -Encoding UTF8

    } catch {
        # No propagamos el error de log para no interrumpir la aplicacin
    }
}

# -----------------------------------------------------------------------------
# Funcin: Write-LogSeparator
# Descripcin: Escribe una lnea separadora para organizar el log
# -----------------------------------------------------------------------------
function Write-LogSeparator {
    param ([string]$Title = "")

    try {
        if ($null -eq $script:LogFile) { return }

        if ($Title) {
            $linea = "--- $Title ---"
        } else {
            $linea = "--------------------------------------------------------------------------------"
        }

        Add-Content -Path $script:LogFile -Value $linea -Encoding UTF8

    } catch { }
}

# -----------------------------------------------------------------------------
# Funcin: Write-LogInstall
# Descripcin: Registra el inicio y fin de una instalacin con detalles
# Parmetros:
#   $Programa    - Nombre del programa
#   $Archivo     - Ruta del instalador
#   $ExitCode    - Cdigo de salida del proceso
#   $Error       - Mensaje de error (opcional)
# -----------------------------------------------------------------------------
function Write-LogInstall {
    param (
        [string]$Programa,
        [string]$Archivo,
        [int]$ExitCode = -1,
        [string]$Error  = ""
    )

    Write-LogSeparator "INSTALACIN"
    Write-Log "Programa  : $Programa" "ACTION"
    Write-Log "Archivo   : $Archivo"  "ACTION"

    if ($ExitCode -ge 0) {
        Write-Log "Cdigo de salida: $ExitCode" "INFO"

        if ($ExitCode -eq 0) {
            Write-Log "Resultado: EXITOSO" "SUCCESS"
        } else {
            Write-Log "Resultado: FINALIZADO CON CDIGO $ExitCode" "WARNING"
        }
    }

    if ($Error) {
        Write-Log "Error: $Error" "ERROR"
    }

    Write-LogSeparator
}

# -----------------------------------------------------------------------------
# Funcin: Get-LogContent
# Descripcin: Devuelve el contenido del log actual como texto
# -----------------------------------------------------------------------------
function Get-LogContent {
    try {
        if ($null -eq $script:LogFile -or -not (Test-Path $script:LogFile)) {
            return "No hay log disponible."
        }
        return Get-Content -Path $script:LogFile -Raw -Encoding UTF8
    } catch {
        return "Error al leer el log: $_"
    }
}

# -----------------------------------------------------------------------------
# Funcin: Get-LogPath
# Descripcin: Devuelve la ruta del archivo de log actual
# -----------------------------------------------------------------------------
function Get-LogPath {
    return $script:LogFile
}
