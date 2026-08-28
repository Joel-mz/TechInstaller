# =============================================================================
# Tech Installer 2026 - Scripts/Detection.ps1
# Mdulo de deteccin automtica de instaladores en la carpeta Programas
# =============================================================================

# Extensiones vlidas que se detectarn como instaladores
$script:ExtensionesValidas = @('.exe', '.msi', '.cmd', '.bat')

# Patrones a ignorar (archivos que no son instaladores)
$script:PatronesIgnorar = @(
    'uninstall*',
    'uninst*',
    '*unins*',
    'helper*',
    'updater*',
    'crash*',
    'report*'
)

# -----------------------------------------------------------------------------
# Funcin: Get-ProgramList
# Descripcin: Escanea recursivamente la carpeta Programas y devuelve
#              una lista de objetos con info de cada instalador encontrado.
# Parmetros:
#   $ProgramsFolder     - Ruta raz de la carpeta Programas
#   $CategoriesConfig   - Configuracin de categoras (de categories.json)
# Devuelve: Array de PSCustomObject con datos del programa
# -----------------------------------------------------------------------------
function Get-ProgramList {
    param (
        [string]$ProgramsFolder,
        [object]$CategoriesConfig = $null,
        [string[]]$ExcludeFolders = @()
    )

    $listaProgramas = @()
    $rootForAssets = Split-Path $ProgramsFolder -Parent
    $logosFolder = Join-Path $rootForAssets "Assets\logos"

    try {
        # Verificar que existe la carpeta
        if (-not (Test-Path $ProgramsFolder)) {
            Write-Log "La carpeta de programas no existe: $ProgramsFolder" "WARNING"
            return $listaProgramas
        }

        # Buscar todos los archivos recursivamente con extensiones vlidas
        $archivos = Get-ChildItem -Path $ProgramsFolder -Recurse -File -ErrorAction SilentlyContinue |
                    Where-Object { $script:ExtensionesValidas -contains $_.Extension.ToLower() }

        foreach ($archivo in $archivos) {
            try {
                # -- Comprobar si el archivo esta dentro de una carpeta excluida --
                $carpetaRaiz = $archivo.FullName.Replace($ProgramsFolder, "").TrimStart('\','/') -split '[\\/]' | Select-Object -First 1
                if ($ExcludeFolders -contains $carpetaRaiz) {
                    continue
                }

                # Comprobar si el archivo debe ignorarse
                $debeIgnorar = $false
                foreach ($patron in $script:PatronesIgnorar) {
                    if ($archivo.Name -like $patron) {
                        $debeIgnorar = $true
                        break
                    }
                }

                if ($debeIgnorar) {
                    Write-Log "Ignorando archivo: $($archivo.Name)" "INFO"
                    continue
                }

                # Determinar la categora basndose en la subcarpeta relativa
                $categoria = Get-FileCategory -FilePath $archivo.FullName -ProgramsFolder $ProgramsFolder

                # Buscar configuracin personalizada para este archivo en categories.json
                $configPrograma = Get-ProgramConfig -FileName $archivo.Name -Category $categoria -CategoriesConfig $CategoriesConfig

                # Obtener nombre amigable
                $nombrePrograma = if ($configPrograma -and $configPrograma.Name) {
                    $configPrograma.Name
                } else {
                    # Usar el nombre del archivo sin extensin como fallback
                    [System.IO.Path]::GetFileNameWithoutExtension($archivo.Name)
                }

                # Construir el objeto del programa
                $programa = $iconPath = $null
                $baseName = [System.IO.Path]::GetFileNameWithoutExtension($archivo.Name)
                $possibleAssetPng = Join-Path $logosFolder "$baseName.png"
                $possibleAssetIco = Join-Path $logosFolder "$baseName.ico"
                $possibleIconPng = [System.IO.Path]::ChangeExtension($archivo.FullName, ".png")
                $possibleIconIco = [System.IO.Path]::ChangeExtension($archivo.FullName, ".ico")
                if (Test-Path $possibleAssetPng) { $iconPath = $possibleAssetPng }
                elseif (Test-Path $possibleAssetIco) { $iconPath = $possibleAssetIco }
                elseif (Test-Path $possibleIconPng) { $iconPath = $possibleIconPng }
                elseif (Test-Path $possibleIconIco) { $iconPath = $possibleIconIco }

                $programa = [PSCustomObject]@{

                    IconPath = $iconPath
                    Nombre      = $nombrePrograma
                    Archivo     = $archivo.Name
                    RutaCompleta = $archivo.FullName
                    Extension   = $archivo.Extension.ToLower()
                    Categoria   = $categoria
                    Tamano      = $archivo.Length
                    TamanoTexto = Format-FileSize -Bytes $archivo.Length
                    Fecha       = $archivo.LastWriteTime
                    FechaTexto  = $archivo.LastWriteTime.ToString("dd/MM/yyyy HH:mm")
                    Argumentos  = if ($configPrograma) { $configPrograma.Arguments } else { "" }
                    Version     = if ($configPrograma) { $configPrograma.Version   } else { "" }
                    URLOficial  = if ($configPrograma) { $configPrograma.OfficialURL } else { "" }
                    Notas       = if ($configPrograma) { $configPrograma.Notes     } else { "" }
                    Seleccionado = $false
                }

                $listaProgramas += $programa

                Write-Log "Programa detectado: $nombrePrograma ($categoria) - $($archivo.Name)" "INFO"

            } catch {
                Write-Log "Error al procesar archivo $($archivo.Name): $_" "WARNING"
                continue
            }
        }

        Write-Log "Deteccin completada. Total de programas encontrados: $($listaProgramas.Count)" "SUCCESS"

    } catch {
        Write-Log "Error crtico durante la deteccin de programas: $_" "ERROR"
    }

    return $listaProgramas
}

# -----------------------------------------------------------------------------
# Funcin: Get-FileCategory
# Descripcin: Determina la categora de un archivo basndose en la subcarpeta
#              dentro de la carpeta Programas donde se encuentra.
# Parmetros:
#   $FilePath       - Ruta completa del archivo
#   $ProgramsFolder - Ruta raz de la carpeta Programas
# Devuelve: Nombre de la categora (String)
# -----------------------------------------------------------------------------
function Get-FileCategory {
    param (
        [string]$FilePath,
        [string]$ProgramsFolder
    )

    try {
        # Obtener la ruta relativa del archivo respecto a la carpeta Programas
        $rutaRelativa = $FilePath.Replace($ProgramsFolder, "").TrimStart('\', '/')

        # Obtener el primer segmento (la subcarpeta inmediata de Programas)
        $partes = $rutaRelativa -split '[\\/]'

        if ($partes.Count -ge 2) {
            # La categora es la primera subcarpeta
            return $partes[0]
        } elseif ($partes.Count -eq 1) {
            # Archivo directamente en Programas (sin subcategora)
            return "General"
        }

    } catch {
        Write-Log "Error al determinar categora de $FilePath`: $_" "WARNING"
    }

    return "General"
}

# -----------------------------------------------------------------------------
# Funcin: Get-ProgramConfig
# Descripcin: Busca la configuracin especfica de un programa en categories.json
# Parmetros:
#   $FileName         - Nombre del archivo del instalador
#   $Category         - Categora del programa
#   $CategoriesConfig - Objeto con la configuracin de categories.json
# Devuelve: PSCustomObject de configuracin, o $null si no se encuentra
# -----------------------------------------------------------------------------
function Get-ProgramConfig {
    param (
        [string]$FileName,
        [string]$Category,
        [object]$CategoriesConfig
    )

    if ($null -eq $CategoriesConfig) { return $null }

    try {
        $configs = $CategoriesConfig.ProgramConfigs
        if ($null -eq $configs) { return $null }

        foreach ($config in $configs) {
            # Comparar usando el nombre del archivo (con soporte de wildcards)
            if ($FileName -like $config.File) {
                return $config
            }
        }

    } catch {
        Write-Log "Error al buscar configuracin para $FileName`: $_" "WARNING"
    }

    return $null
}

# -----------------------------------------------------------------------------
# Funcin: Get-CategoryList
# Descripcin: Devuelve la lista de categoras nicas encontradas en los programas
# Parmetros:
#   $ProgramList - Lista de programas detectados
# Devuelve: Array de strings con nombres de categoras
# -----------------------------------------------------------------------------
function Get-CategoryList {
    param ([array]$ProgramList)

    $categorias = $ProgramList | Select-Object -ExpandProperty Categoria -Unique | Sort-Object
    return $categorias
}




