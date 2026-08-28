# =============================================================================
# Tech Installer 2026 - Scripts/Update.ps1
# Mdulo de verificacin y gestin de actualizaciones desde GitHub
# =============================================================================

# -----------------------------------------------------------------------------
# Funcin: Get-LocalVersion
# Descripcin: Lee la versin actual desde el archivo version.json local
# Parmetros:
#   $VersionFilePath - Ruta al archivo version.json local
# Devuelve: String con la versin (ej: "1.0.0") o $null si hay error
# -----------------------------------------------------------------------------
function Get-LocalVersion {
    param ([string]$VersionFilePath)

    try {
        if (-not (Test-Path $VersionFilePath)) {
            Write-Log "Archivo version.json no encontrado: $VersionFilePath" "WARNING"
            return "0.0.0"
        }

        $contenido = Get-Content -Path $VersionFilePath -Raw -Encoding UTF8
        $versionObj = $contenido | ConvertFrom-Json
        return $versionObj.version

    } catch {
        Write-Log "Error al leer versin local: $_" "ERROR"
        return "0.0.0"
    }
}

# -----------------------------------------------------------------------------
# Funcin: Get-RemoteVersion
# Descripcin: Descarga version.json desde GitHub y devuelve la versin disponible
# Parmetros:
#   $GitHubUser - Usuario de GitHub
#   $Repository - Nombre del repositorio
#   $Branch     - Rama del repositorio (por defecto "main")
# Devuelve: PSCustomObject con Version, ReleaseNotes, o $null si hay error
# -----------------------------------------------------------------------------
function Get-RemoteVersion {
    param (
        [string]$GitHubUser,
        [string]$Repository,
        [string]$Branch = "main"
    )

    try {
        # Validar que no sea el valor por defecto sin configurar
        if ($GitHubUser -eq "TU_USUARIO_GITHUB" -or [string]::IsNullOrEmpty($GitHubUser)) {
            Write-Log "GitHubUser no configurado. Omitiendo verificacin de actualizaciones." "WARNING"
            return $null
        }

        $url = "https://raw.githubusercontent.com/$GitHubUser/$Repository/$Branch/version.json"
        Write-Log "Verificando actualizaciones en: $url" "INFO"

        # Descargar con timeout de 10 segundos
        $webClient            = New-Object System.Net.WebClient
        $webClient.Encoding   = [System.Text.Encoding]::UTF8
        $webClient.Headers.Add("User-Agent", "TechInstaller2026/1.0")

        $contenidoRemoto = $webClient.DownloadString($url)
        $versionRemota   = $contenidoRemoto | ConvertFrom-Json

        Write-Log "Versin remota obtenida: $($versionRemota.version)" "INFO"
        return $versionRemota

    } catch {
        Write-Log "No se pudo obtener la versin remota: $_" "WARNING"
        return $null
    }
}

# -----------------------------------------------------------------------------
# Funcin: Compare-Versions
# Descripcin: Compara dos versiones semnticas (mayor.menor.patch)
# Parmetros:
#   $Local  - Versin local como string (ej: "1.0.0")
#   $Remote - Versin remota como string (ej: "1.1.0")
# Devuelve:
#   -1 si local < remota (hay actualizacin disponible)
#    0 si son iguales
#    1 si local > remota
# -----------------------------------------------------------------------------
function Compare-Versions {
    param (
        [string]$Local,
        [string]$Remote
    )

    try {
        $verLocal  = [Version]$Local
        $verRemota = [Version]$Remote
        return $verLocal.CompareTo($verRemota)
    } catch {
        Write-Log "Error al comparar versiones ($Local vs $Remote): $_" "WARNING"
        return 0
    }
}

# -----------------------------------------------------------------------------
# Funcin: Start-UpdateDownload
# Descripcin: Descarga la versin ms reciente del repositorio de GitHub
#              como un archivo ZIP y la extrae en una carpeta temporal.
# Parmetros:
#   $GitHubUser  - Usuario de GitHub
#   $Repository  - Nombre del repositorio
#   $Branch      - Rama del repositorio
#   $DestFolder  - Carpeta donde guardar la descarga
# Devuelve: Ruta de la carpeta extrada, o $null si hay error
# -----------------------------------------------------------------------------
function Start-UpdateDownload {
    param (
        [string]$GitHubUser,
        [string]$Repository,
        [string]$Branch     = "main",
        [string]$DestFolder = "$env:TEMP\TechInstallerUpdate"
    )

    try {
        Write-Log "Iniciando descarga de actualizacin desde GitHub..." "UPDATE"

        # URL del archivo ZIP del repositorio
        $zipUrl = "https://github.com/$GitHubUser/$Repository/archive/refs/heads/$Branch.zip"
        $zipPath = Join-Path $DestFolder "TechInstaller_update.zip"

        # Crear carpeta de destino si no existe
        if (-not (Test-Path $DestFolder)) {
            New-Item -ItemType Directory -Path $DestFolder -Force | Out-Null
        }

        Write-Log "Descargando desde: $zipUrl" "INFO"
        Write-Log "Guardando en: $zipPath" "INFO"

        # Descargar el archivo ZIP
        $webClient          = New-Object System.Net.WebClient
        $webClient.Headers.Add("User-Agent", "TechInstaller2026/1.0")
        $webClient.DownloadFile($zipUrl, $zipPath)

        Write-Log "Descarga completada. Extrayendo..." "INFO"

        # Extraer el ZIP
        $extractPath = Join-Path $DestFolder "extracted"
        if (Test-Path $extractPath) {
            Remove-Item $extractPath -Recurse -Force
        }

        Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

        Write-Log "Extraccin completada en: $extractPath" "SUCCESS"

        # Eliminar ZIP temporal
        Remove-Item $zipPath -Force -ErrorAction SilentlyContinue

        return $extractPath

    } catch {
        Write-Log "Error al descargar actualizacin: $_" "ERROR"
        return $null
    }
}

# -----------------------------------------------------------------------------
# Funcin: Check-ForUpdates
# Descripcin: Funcin principal que verifica si hay actualizaciones disponibles.
#              Devuelve un objeto con el estado de la verificacin.
# Parmetros:
#   $Config          - Objeto de configuracin (de config.json)
#   $VersionFilePath - Ruta al version.json local
# Devuelve: PSCustomObject con HasUpdate, LocalVersion, RemoteVersion, ReleaseNotes
# -----------------------------------------------------------------------------
function Check-ForUpdates {
    param (
        [object]$Config,
        [string]$VersionFilePath
    )

    $resultado = [PSCustomObject]@{
        HasUpdate     = $false
        LocalVersion  = "0.0.0"
        RemoteVersion = "0.0.0"
        ReleaseNotes  = ""
        Error         = ""
    }

    try {
        # Obtener versin local
        $resultado.LocalVersion = Get-LocalVersion -VersionFilePath $VersionFilePath

        # Verificar conexin
        if (-not (Test-NetworkConnection)) {
            $resultado.Error = "Sin conexin a Internet. No se puede verificar actualizaciones."
            Write-Log $resultado.Error "WARNING"
            return $resultado
        }

        # Obtener versin remota
        $remota = Get-RemoteVersion -GitHubUser $Config.GitHubUser `
                                    -Repository  $Config.GitHubRepository.Split('/')[1] `
                                    -Branch      $Config.Branch

        if ($null -eq $remota) {
            $resultado.Error = "No se pudo obtener informacin de actualizaciones."
            return $resultado
        }

        $resultado.RemoteVersion = $remota.version
        $resultado.ReleaseNotes  = if ($remota.releaseNotes) { $remota.releaseNotes } else { "" }

        # Comparar versiones
        $comparacion = Compare-Versions -Local $resultado.LocalVersion -Remote $resultado.RemoteVersion

        if ($comparacion -lt 0) {
            $resultado.HasUpdate = $true
            Write-Log "Nueva versin disponible: $($resultado.RemoteVersion) (actual: $($resultado.LocalVersion))" "UPDATE"
        } else {
            Write-Log "La aplicacin est actualizada. Versin: $($resultado.LocalVersion)" "INFO"
        }

    } catch {
        $resultado.Error = "Error al verificar actualizaciones: $_"
        Write-Log $resultado.Error "ERROR"
    }

    return $resultado
}
