# =============================================================================
# Tech Installer 2026 - Scripts/Installer.ps1
# Mdulo de ejecucin e instalacin de programas
# =============================================================================

# -----------------------------------------------------------------------------
# Funcin: Start-Installer
# Descripcin: Ejecuta o instala un programa de forma correcta segn su tipo.
#              Usa Start-Process para EXE/BAT/CMD y msiexec para MSI.
#              Solicita UAC de manera estndar si el proceso lo requiere.
# Parmetros:
#   $Programa    - Objeto PSCustomObject con datos del programa
#   $Silencioso  - Si $true, usa los argumentos del config.json si existen
#   $Esperar     - Si $true, espera a que termine el proceso antes de continuar
# Devuelve: PSCustomObject con ExitCode, Exito (bool) y Mensaje
# -----------------------------------------------------------------------------
function Start-Installer {
    param (
        [PSCustomObject]$Programa,
        [bool]$Silencioso = $false,
        [bool]$Esperar    = $true
    )

    $resultado = [PSCustomObject]@{
        Exito    = $false
        ExitCode = -1
        Mensaje  = ""
    }

    try {
        # Verificar que el archivo existe
        if (-not (Test-Path $Programa.RutaCompleta)) {
            $resultado.Mensaje = "El archivo no existe: $($Programa.RutaCompleta)"
            Write-Log $resultado.Mensaje "ERROR"
            return $resultado
        }

        Write-Log "Iniciando instalacin: $($Programa.Nombre)" "ACTION"
        Write-Log "Archivo: $($Programa.RutaCompleta)" "INFO"

        $extension = $Programa.Extension.ToLower()

        # Determinar argumentos a usar
        $argumentos = ""
        if ($Silencioso -and $Programa.Argumentos) {
            $argumentos = $Programa.Argumentos
            Write-Log "Modo silencioso - Argumentos: $argumentos" "INFO"
        }

        # ---------------------------------------------------------------
        # Ejecutar segn el tipo de archivo
        # ---------------------------------------------------------------
        switch ($extension) {

            ".msi" {
                # Para MSI se usa msiexec.exe
                $msiArgs = "/i `"$($Programa.RutaCompleta)`""
                if ($argumentos) {
                    $msiArgs = "$msiArgs $argumentos"
                }
                Write-Log "Ejecutando MSI: msiexec $msiArgs" "INFO"

                $proceso = Start-Process -FilePath "msiexec.exe" `
                           -ArgumentList $msiArgs `
                           -Verb RunAs `
                           -Wait:$Esperar `
                           -PassThru `
                           -ErrorAction Stop
            }

            { $_ -in @(".exe") } {
                # Para EXE se usa Start-Process con Verb RunAs para solicitar UAC
                $exeArgs = @()
                if ($argumentos) {
                    # Dividir argumentos correctamente
                    $exeArgs = $argumentos -split " (?=(?:[^`"]*`"[^`"]*`")*[^`"]*$)"
                }

                Write-Log "Ejecutando EXE con UAC estndar" "INFO"

                $parametros = @{
                    FilePath    = $Programa.RutaCompleta
                    Verb        = "RunAs"
                    Wait        = $Esperar
                    PassThru    = $true
                    ErrorAction = "Stop"
                }

                if ($exeArgs.Count -gt 0) {
                    $parametros.ArgumentList = $exeArgs
                }

                $proceso = Start-Process @parametros
            }

            { $_ -in @(".bat", ".cmd") } {
                # Para scripts de lote se ejecuta con cmd.exe
                Write-Log "Ejecutando script de lote: $extension" "INFO"

                $cmdArgs = "/c `"$($Programa.RutaCompleta)`""
                if ($argumentos) {
                    $cmdArgs = "$cmdArgs $argumentos"
                }

                $proceso = Start-Process -FilePath "cmd.exe" `
                           -ArgumentList $cmdArgs `
                           -Verb RunAs `
                           -Wait:$Esperar `
                           -PassThru `
                           -ErrorAction Stop
            }

            default {
                $resultado.Mensaje = "Tipo de archivo no soportado: $extension"
                Write-Log $resultado.Mensaje "ERROR"
                return $resultado
            }
        }

        # Capturar cdigo de salida si se esper
        if ($Esperar -and $null -ne $proceso) {
            $resultado.ExitCode = $proceso.ExitCode

            if ($proceso.ExitCode -eq 0) {
                $resultado.Exito   = $true
                $resultado.Mensaje = "Instalacin completada exitosamente."
                Write-Log "Instalacin exitosa. Cdigo de salida: $($proceso.ExitCode)" "SUCCESS"
            } else {
                $resultado.Exito   = ($proceso.ExitCode -eq 0)
                $resultado.Mensaje = "Proceso finalizado con cdigo: $($proceso.ExitCode)"
                Write-Log "Proceso finalizado. Cdigo de salida: $($proceso.ExitCode)" "WARNING"
            }
        } else {
            $resultado.Exito   = $true
            $resultado.Mensaje = "Proceso iniciado (sin esperar resultado)."
        }

        Write-LogInstall -Programa $Programa.Nombre `
                         -Archivo $Programa.RutaCompleta `
                         -ExitCode $resultado.ExitCode

    } catch [System.ComponentModel.Win32Exception] {
        # El usuario cancel el UAC o no tiene permisos
        if ($_.Exception.NativeErrorCode -eq 1223) {
            $resultado.Mensaje = "El usuario cancel la solicitud de permisos de administrador."
            Write-Log $resultado.Mensaje "WARNING"
        } else {
            $resultado.Mensaje = "Error de Windows al ejecutar el proceso: $($_.Exception.Message)"
            Write-Log $resultado.Mensaje "ERROR"
        }
        Write-LogInstall -Programa $Programa.Nombre -Archivo $Programa.RutaCompleta -Error $resultado.Mensaje

    } catch {
        $resultado.Mensaje = "Error al ejecutar el programa: $($_.Exception.Message)"
        Write-Log $resultado.Mensaje "ERROR"
        Write-LogInstall -Programa $Programa.Nombre -Archivo $Programa.RutaCompleta -Error $resultado.Mensaje
    }

    return $resultado
}

# -----------------------------------------------------------------------------
# Funcin: Start-InstallerBatch
# Descripcin: Instala mltiples programas en secuencia
# Parmetros:
#   $Programas       - Array de objetos de programa a instalar
#   $Silencioso      - Si $true, usa argumentos del config
#   $ProgressCallback - ScriptBlock que se llama con (ndice, total, nombre)
# Devuelve: Array de resultados
# -----------------------------------------------------------------------------
function Start-InstallerBatch {
    param (
        [array]$Programas,
        [bool]$Silencioso = $false,
        [scriptblock]$ProgressCallback = $null
    )

    $resultados = @()
    $total      = $Programas.Count
    $indice     = 0

    Write-LogSeparator "INSTALACIN EN LOTE ($total programas)"

    foreach ($programa in $Programas) {
        $indice++

        # Notificar progreso
        if ($ProgressCallback) {
            & $ProgressCallback $indice $total $programa.Nombre
        }

        Write-Log "Instalando $indice/$total: $($programa.Nombre)" "ACTION"

        $resultado = Start-Installer -Programa $programa -Silencioso $Silencioso -Esperar $true
        $resultados += [PSCustomObject]@{
            Programa  = $programa.Nombre
            Resultado = $resultado
        }

        # Pequea pausa entre instalaciones para estabilidad
        Start-Sleep -Milliseconds 500
    }

    Write-LogSeparator "FIN DE INSTALACIN EN LOTE"
    Write-Log "Completados: $($resultados.Count) de $total" "SUCCESS"

    return $resultados
}
