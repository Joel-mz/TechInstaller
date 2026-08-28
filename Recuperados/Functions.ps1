# =============================================================================
# Tech Installer 2026 - Scripts/Functions.ps1
# Funciones utilitarias generales de la herramienta
# =============================================================================

# -----------------------------------------------------------------------------
# Funcin: Get-SystemInfo
# Descripcin: Recopila informacin del sistema local (no se enva a ningn servidor)
# Devuelve: Hashtable con datos del equipo
# -----------------------------------------------------------------------------
function Get-SystemInfo {
    $info = @{}

    try {
        # Informacin bsica del sistema
        $info.NombreEquipo   = $env:COMPUTERNAME
        $info.Usuario        = $env:USERNAME
        $info.Dominio        = $env:USERDOMAIN

        # Informacin del sistema operativo
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
        if ($os) {
            $info.WindowsVersion  = $os.Caption
            $info.Build           = $os.BuildNumber
            $info.Arquitectura    = $os.OSArchitecture
            $info.InstallDate     = $os.InstallDate
            # Memoria RAM total en GB
            $ramGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
            $info.RAM_GB          = "$ramGB GB"
        } else {
            $info.WindowsVersion = "No disponible"
            $info.Arquitectura   = "No disponible"
            $info.RAM_GB         = "No disponible"
        }

        # Versin de PowerShell
        $info.PowerShellVersion = $PSVersionTable.PSVersion.ToString()

        # Fabricante y modelo del equipo
        $cs = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue
        if ($cs) {
            $info.Fabricante = $cs.Manufacturer
            $info.Modelo     = $cs.Model
            $info.RAM_Total  = "$([math]::Round($cs.TotalPhysicalMemory / 1GB, 2)) GB"
        } else {
            $info.Fabricante = "No disponible"
            $info.Modelo     = "No disponible"
        }

        # Espacio en disco del sistema
        $disco = Get-PSDrive -Name C -ErrorAction SilentlyContinue
        if ($disco) {
            $usado     = [math]::Round(($disco.Used) / 1GB, 1)
            $libre     = [math]::Round(($disco.Free) / 1GB, 1)
            $total     = $usado + $libre
            $info.DiscoTotal  = "$total GB"
            $info.DiscoUsado  = "$usado GB"
            $info.DiscoLibre  = "$libre GB"
        } else {
            $info.DiscoLibre = "No disponible"
        }

        # Informacin de red bsica
        $ip = (Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
               Where-Object { $_.InterfaceAlias -notlike "*Loopback*" -and $_.IPAddress -ne "127.0.0.1" } |
               Select-Object -First 1).IPAddress
        $info.DireccionIP = if ($ip) { $ip } else { "No disponible" }

    } catch {
        # Si algn dato falla, continuamos con el resto
        Write-Log "Advertencia al obtener informacin del sistema: $_" "WARNING"
    }

    return $info
}

# -----------------------------------------------------------------------------
# Funcin: Test-IsAdministrator
# Descripcin: Comprueba si el proceso actual tiene privilegios de administrador
# Devuelve: $true si es administrador, $false si no
# -----------------------------------------------------------------------------
function Test-IsAdministrator {
    try {
        $identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = [Security.Principal.WindowsPrincipal]$identity
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch {
        return $false
    }
}

# -----------------------------------------------------------------------------
# Funcin: Request-ElevatedExecution
# Descripcin: Relanza el script actual con privilegios de administrador (UAC estndar)
# Parmetros:
#   $ScriptPath - Ruta del script a relanzar
# -----------------------------------------------------------------------------
function Request-ElevatedExecution {
    param ([string]$ScriptPath)

    try {
        $argumentos = "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""
        Start-Process powershell.exe -ArgumentList $argumentos -Verb RunAs
    } catch {
        Write-Log "No se pudo elevar los permisos: $_" "ERROR"
        throw "No se pudo obtener permisos de administrador: $_"
    }
}

# -----------------------------------------------------------------------------
# Funcin: Read-Config
# Descripcin: Lee y devuelve el archivo de configuracin config.json
# Parmetros:
#   $ConfigPath - Ruta al archivo config.json
# -----------------------------------------------------------------------------
function Read-Config {
    param ([string]$ConfigPath)

    try {
        if (-not (Test-Path $ConfigPath)) {
            throw "No se encontr el archivo de configuracin: $ConfigPath"
        }

        $contenido = Get-Content -Path $ConfigPath -Raw -Encoding UTF8
        $config    = $contenido | ConvertFrom-Json

        return $config

    } catch {
        Write-Log "Error al leer configuracin: $_" "ERROR"
        throw
    }
}

# -----------------------------------------------------------------------------
# Funcin: Read-CategoriesConfig
# Descripcin: Lee y devuelve el archivo categories.json
# Parmetros:
#   $CategoriesPath - Ruta al archivo categories.json
# -----------------------------------------------------------------------------
function Read-CategoriesConfig {
    param ([string]$CategoriesPath)

    try {
        if (-not (Test-Path $CategoriesPath)) {
            return @{
                Categories     = @()
                ProgramConfigs = @()
            }
        }

        $contenido  = Get-Content -Path $CategoriesPath -Raw -Encoding UTF8
        $categorias = $contenido | ConvertFrom-Json
        return $categorias

    } catch {
        Write-Log "Error al leer categoras: $_" "WARNING"
        return @{
            Categories     = @()
            ProgramConfigs = @()
        }
    }
}

# -----------------------------------------------------------------------------
# Funcin: Format-FileSize
# Descripcin: Convierte bytes a texto legible (KB, MB, GB)
# Parmetros:
#   $Bytes - Tamao en bytes
# -----------------------------------------------------------------------------
function Format-FileSize {
    param ([long]$Bytes)

    if ($Bytes -ge 1GB) {
        return "$([math]::Round($Bytes / 1GB, 2)) GB"
    } elseif ($Bytes -ge 1MB) {
        return "$([math]::Round($Bytes / 1MB, 1)) MB"
    } elseif ($Bytes -ge 1KB) {
        return "$([math]::Round($Bytes / 1KB, 0)) KB"
    } else {
        return "$Bytes bytes"
    }
}

# -----------------------------------------------------------------------------
# Funcin: Test-NetworkConnection
# Descripcin: Comprueba si hay conexin a Internet (ping a GitHub)
# Devuelve: $true si hay conexin, $false si no
# -----------------------------------------------------------------------------
function Test-NetworkConnection {
    try {
        $resultado = Test-NetConnection -ComputerName "github.com" -Port 443 -InformationLevel Quiet -WarningAction SilentlyContinue
        return $resultado
    } catch {
        return $false
    }
}

# -----------------------------------------------------------------------------
# Funcin: Invoke-NetworkTool
# Descripcin: Ejecuta herramientas de diagnstico de red como ipconfig, ping, etc.
# Parmetros:
#   $Tool    - Nombre de la herramienta (ipconfig, ping, tracert, etc.)
#   $Args    - Argumentos adicionales
# Devuelve: Salida como texto
# -----------------------------------------------------------------------------
function Invoke-NetworkTool {
    param (
        [string]$Tool,
        [string]$Arguments = ""
    )

    try {
        $resultado = Start-Process -FilePath $Tool -ArgumentList $Arguments `
                     -NoNewWindow -Wait -PassThru `
                     -RedirectStandardOutput "$env:TEMP\netout.txt" `
                     -RedirectStandardError  "$env:TEMP\neterr.txt"

        $salida = ""
        if (Test-Path "$env:TEMP\netout.txt") {
            $salida = Get-Content "$env:TEMP\netout.txt" -Raw -Encoding Default
            Remove-Item "$env:TEMP\netout.txt" -Force -ErrorAction SilentlyContinue
        }
        if (Test-Path "$env:TEMP\neterr.txt") {
            Remove-Item "$env:TEMP\neterr.txt" -Force -ErrorAction SilentlyContinue
        }

        return $salida

    } catch {
        Write-Log "Error al ejecutar herramienta de red '$Tool': $_" "ERROR"
        return "Error: $_"
    }
}
