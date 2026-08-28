# =============================================================================
# Tech Installer 2026 - Launcher.ps1
# Punto de entrada principal de la aplicacin. Carga la GUI y todos los mdulos.
# =============================================================================
#
# USO:
#   powershell.exe -ExecutionPolicy Bypass -File ".\Launcher.ps1"
#
# COMPATIBILIDAD:
#   Windows 10 / Windows 11 - PowerShell 5.1+
#
# SEGURIDAD:
#   Este script solicita UAC estndar para operaciones que lo requieren.
#   No desactiva defensas de Windows ni evade protecciones del sistema.
# =============================================================================

#Requires -Version 5.1

[CmdletBinding()]
param(
    [switch]$NoAdmin     # Omite la verificacin de administrador (solo para pruebas)
)

# Configurar manejo de errores
$ErrorActionPreference = "Stop"

# =============================================================================
# PASO 1: Determinar la ruta raz del proyecto (funciona desde cualquier ubicacin)
# =============================================================================
try {
    # $PSScriptRoot contiene la carpeta donde est el script que se est ejecutando.
    # Funciona correctamente independientemente de desde dnde se llame.
    $script:RootPath = $PSScriptRoot

    if ([string]::IsNullOrEmpty($script:RootPath)) {
        # Fallback: usar la ubicacin del script desde la invocacin
        $script:RootPath = Split-Path -Parent $MyInvocation.MyCommand.Path
    }

    if ([string]::IsNullOrEmpty($script:RootPath)) {
        throw "No se pudo determinar la ruta raz del proyecto."
    }

} catch {
    [System.Windows.Forms.MessageBox]::Show(
        "Error crtico: No se pudo determinar la ruta de instalacin.`n$_",
        "Tech Installer 2026 - Error",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
    exit 1
}

# =============================================================================
# PASO 2: Cargar ensamblados de Windows Forms
# =============================================================================
try {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    [System.Windows.Forms.Application]::EnableVisualStyles()
    [System.Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false)
} catch {
    Write-Error "Error al cargar Windows Forms: $_"
    exit 1
}

# =============================================================================
# PASO 3: Cargar mdulos del proyecto
# =============================================================================
$script:ScriptsPath = Join-Path $script:RootPath "Scripts"
$modulosRequeridos  = @("Logging.ps1", "Functions.ps1", "Detection.ps1", "Installer.ps1", "Update.ps1")

foreach ($modulo in $modulosRequeridos) {
    $rutaModulo = Join-Path $script:ScriptsPath $modulo
    if (Test-Path $rutaModulo) {
        . $rutaModulo
    } else {
        [System.Windows.Forms.MessageBox]::Show(
            "Error: No se encontr el mdulo requerido:`n$rutaModulo`n`nVerifique la integridad del proyecto.",
            "Tech Installer 2026 - Mdulo Faltante",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
        exit 1
    }
}

# =============================================================================
# PASO 4: Inicializar logs y configuracin
# =============================================================================
$script:LogsPath = Join-Path $script:RootPath "Logs"
Initialize-Log -LogsFolder $script:LogsPath

Write-Log "=== Tech Installer 2026 iniciando ===" "INFO"
Write-Log "Ruta del proyecto: $script:RootPath" "INFO"

# Leer configuracin
$script:ConfigPath      = Join-Path $script:RootPath "Config\config.json"
$script:CatConfigPath   = Join-Path $script:RootPath "Config\categories.json"
$script:VersionPath     = Join-Path $script:RootPath "version.json"

try {
    $script:Config       = Read-Config -ConfigPath $script:ConfigPath
    $script:CatConfig    = Read-CategoriesConfig -CategoriesPath $script:CatConfigPath
    Write-Log "Configuracin cargada correctamente." "SUCCESS"
} catch {
    Write-Log "Error al cargar configuracin: $_" "ERROR"
    [System.Windows.Forms.MessageBox]::Show(
        "Error al cargar la configuracin:`n$_",
        "Tech Installer 2026",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    ) | Out-Null
    # Usar configuracin por defecto
    $script:Config = [PSCustomObject]@{
        ApplicationName     = "Tech Installer 2026"
        GitHubUser          = "TU_USUARIO_GITHUB"
        GitHubRepository    = "TU_USUARIO_GITHUB/TechInstaller"
        Branch              = "main"
        ProgramsFolder      = "Programas"
        LogsFolder          = "Logs"
    }
    $script:CatConfig = [PSCustomObject]@{ Categories = @(); ProgramConfigs = @() }
}

# Ruta de la carpeta de programas (siempre relativa al proyecto)
$script:ProgramsPath = Join-Path $script:RootPath $script:Config.ProgramsFolder

Write-Log "Carpeta de programas: $script:ProgramsPath" "INFO"

# Lista global de programas detectados
$script:ListaProgramas = @()
$script:FiltroCategoria = "Todos"
$script:FiltroBusqueda  = ""

# =============================================================================
# PASO 5: DEFINICIN DE COLORES Y ESTILOS
# =============================================================================
# Paleta de colores - Tema oscuro profesional
$colores = @{
    Fondo           = [System.Drawing.Color]::FromArgb(18, 22, 36)       # Azul muy oscuro
    FondoPanel      = [System.Drawing.Color]::FromArgb(25, 31, 52)       # Panel oscuro
    FondoSidebar    = [System.Drawing.Color]::FromArgb(15, 18, 30)       # Sidebar ms oscuro
    FondoCard       = [System.Drawing.Color]::FromArgb(32, 40, 65)       # Tarjeta
    FondoInput      = [System.Drawing.Color]::FromArgb(22, 28, 45)       # Input
    FondoHeader     = [System.Drawing.Color]::FromArgb(10, 14, 25)       # Header
    Acento          = [System.Drawing.Color]::FromArgb(0, 122, 255)      # Azul acento
    AcentoVerde     = [System.Drawing.Color]::FromArgb(48, 209, 88)      # Verde xito
    AcentoAmarillo  = [System.Drawing.Color]::FromArgb(255, 214, 10)     # Amarillo advertencia
    AcentoRojo      = [System.Drawing.Color]::FromArgb(255, 69, 58)      # Rojo error
    AcentoNaranja   = [System.Drawing.Color]::FromArgb(255, 159, 10)     # Naranja
    AcentoPurpura   = [System.Drawing.Color]::FromArgb(191, 90, 242)     # Prpura
    TextoPrimario   = [System.Drawing.Color]::FromArgb(240, 245, 255)    # Texto principal
    TextoSecundario = [System.Drawing.Color]::FromArgb(140, 155, 190)    # Texto secundario
    TextoMuted      = [System.Drawing.Color]::FromArgb(90, 105, 140)     # Texto apagado
    Borde           = [System.Drawing.Color]::FromArgb(40, 52, 85)       # Borde sutil
    SidebarActivo   = [System.Drawing.Color]::FromArgb(0, 122, 255)      # Botn activo sidebar
    BotonPrimario   = [System.Drawing.Color]::FromArgb(0, 122, 255)      # Botn primario
    BotonVerde      = [System.Drawing.Color]::FromArgb(48, 175, 80)      # Botn verde
    BotonRojo       = [System.Drawing.Color]::FromArgb(200, 50, 50)      # Botn rojo
}

$fuentes = @{
    Titulo       = New-Object System.Drawing.Font("Segoe UI", 22, [System.Drawing.FontStyle]::Bold)
    Subtitulo    = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Regular)
    Normal       = New-Object System.Drawing.Font("Segoe UI", 9,  [System.Drawing.FontStyle]::Regular)
    Negrita      = New-Object System.Drawing.Font("Segoe UI", 9,  [System.Drawing.FontStyle]::Bold)
    Pequena      = New-Object System.Drawing.Font("Segoe UI", 8,  [System.Drawing.FontStyle]::Regular)
    Sidebar      = New-Object System.Drawing.Font("Segoe UI", 9,  [System.Drawing.FontStyle]::Regular)
    SidebarBold  = New-Object System.Drawing.Font("Segoe UI", 9,  [System.Drawing.FontStyle]::Bold)
    Codigo       = New-Object System.Drawing.Font("Consolas",  8,  [System.Drawing.FontStyle]::Regular)
    Log          = New-Object System.Drawing.Font("Consolas",  8,  [System.Drawing.FontStyle]::Regular)
    BtnGrande    = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    Header       = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
}

# =============================================================================
# PASO 6: FUNCIONES DE CREACIN DE CONTROLES UI
# =============================================================================

function New-StyledButton {
    param(
        [string]$Text,
        [int]$X, [int]$Y, [int]$Width, [int]$Height,
        [System.Drawing.Color]$BackColor,
        [System.Drawing.Color]$ForeColor,
        [System.Drawing.Font]$Font,
        [string]$Name = ""
    )
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text            = $Text
    $btn.Location        = New-Object System.Drawing.Point($X, $Y)
    $btn.Size            = New-Object System.Drawing.Size($Width, $Height)
    $btn.BackColor       = $BackColor
    $btn.ForeColor       = $ForeColor
    $btn.Font            = $Font
    $btn.FlatStyle       = [System.Windows.Forms.FlatStyle]::Flat
    $btn.FlatAppearance.BorderSize  = 0
    $btn.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(
        [Math]::Min($BackColor.R + 30, 255),
        [Math]::Min($BackColor.G + 30, 255),
        [Math]::Min($BackColor.B + 30, 255)
    )
    $btn.Cursor = [System.Windows.Forms.Cursors]::Hand
    if ($Name) { $btn.Name = $Name }
    return $btn
}

function New-SidebarButton {
    param(
        [string]$Text,
        [int]$Y,
        [bool]$IsHeader = $false
    )

    $btn = New-Object System.Windows.Forms.Button
    $btn.Text      = $Text
    $btn.Location  = New-Object System.Drawing.Point(0, $Y)
    $alturaSidebar = if ($IsHeader) { 28 } else { 38 }
    $btn.Size      = New-Object System.Drawing.Size(180, $alturaSidebar)
    $btn.BackColor = $colores.FondoSidebar
    $btn.ForeColor = if ($IsHeader) { $colores.TextoMuted } else { $colores.TextoSecundario }
    $btn.Font      = if ($IsHeader) { $fuentes.Pequena } else { $fuentes.Sidebar }
    $btn.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btn.FlatAppearance.BorderSize = 0
    $btn.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $btn.Padding   = New-Object System.Windows.Forms.Padding(12, 0, 0, 0)
    if (-not $IsHeader) {
        $btn.Cursor = [System.Windows.Forms.Cursors]::Hand
        $btn.FlatAppearance.MouseOverBackColor = $colores.FondoCard
    }
    return $btn
}

function Update-SidebarButtonState {
    param([System.Windows.Forms.Button]$ActiveBtn)
    # Restablece todos los botones del sidebar a su estado normal
    foreach ($ctrl in $panelSidebar.Controls) {
        if ($ctrl -is [System.Windows.Forms.Button] -and $ctrl.Tag -eq "navbtn") {
            $ctrl.BackColor = $colores.FondoSidebar
            $ctrl.ForeColor = $colores.TextoSecundario
            $ctrl.Font      = $fuentes.Sidebar
        }
    }
    # Activa el botn seleccionado
    if ($ActiveBtn) {
        $ActiveBtn.BackColor = $colores.FondoCard
        $ActiveBtn.ForeColor = $colores.TextoPrimario
        $ActiveBtn.Font      = $fuentes.SidebarBold
    }
}

# =============================================================================
# PASO 7: CONSTRUCCIN DE LA VENTANA PRINCIPAL
# =============================================================================

$ventana = New-Object System.Windows.Forms.Form
$ventana.Text            = "Tech Installer 2026"
$ventana.Size            = New-Object System.Drawing.Size(1150, 780)
$ventana.MinimumSize     = New-Object System.Drawing.Size(900, 600)
$ventana.StartPosition   = [System.Windows.Forms.FormStartPosition]::CenterScreen
$ventana.BackColor       = $colores.Fondo
$ventana.ForeColor       = $colores.TextoPrimario
$ventana.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::Sizable

$ventana.Icon            = [System.Drawing.SystemIcons]::Application

# ---------------------------------------------------------------
# HEADER / BARRA SUPERIOR
# ---------------------------------------------------------------
$panelHeader = New-Object System.Windows.Forms.Panel
$panelHeader.Dock      = [System.Windows.Forms.DockStyle]::Top
$panelHeader.Height    = 75
$panelHeader.BackColor = $colores.FondoHeader

# Icono PowerShell (emulado con texto)
$lblIcono = New-Object System.Windows.Forms.Label
$lblIcono.Text      = "[!]"
$lblIcono.Font      = New-Object System.Drawing.Font("Segoe UI Emoji", 22)
$lblIcono.ForeColor = $colores.Acento
$lblIcono.Location  = New-Object System.Drawing.Point(20, 12)
$lblIcono.Size      = New-Object System.Drawing.Size(50, 50)
$panelHeader.Controls.Add($lblIcono)

# Ttulo principal
$lblTitulo = New-Object System.Windows.Forms.Label
$lblTitulo.Text      = "TECH INSTALLER 2026"
$lblTitulo.Font      = $fuentes.Titulo
$lblTitulo.ForeColor = $colores.TextoPrimario
$lblTitulo.Location  = New-Object System.Drawing.Point(75, 10)
$lblTitulo.Size      = New-Object System.Drawing.Size(500, 35)
$panelHeader.Controls.Add($lblTitulo)

# Subttulo
$lblSubtitulo = New-Object System.Windows.Forms.Label
$lblSubtitulo.Text      = "Herramienta profesional para tcnicos de soporte"
$lblSubtitulo.Font      = $fuentes.Subtitulo
$lblSubtitulo.ForeColor = $colores.TextoSecundario
$lblSubtitulo.Location  = New-Object System.Drawing.Point(78, 44)
$lblSubtitulo.Size      = New-Object System.Drawing.Size(450, 20)
$panelHeader.Controls.Add($lblSubtitulo)

# Versin en el header (derecha)
$lblVersion = New-Object System.Windows.Forms.Label
try { $v = Get-LocalVersion -VersionFilePath $script:VersionPath } catch { $v = "1.0.0" }
$lblVersion.Text      = "v$v"
$lblVersion.Font      = $fuentes.Normal
$lblVersion.ForeColor = $colores.AcentoVerde
$lblVersion.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
$lblVersion.Anchor    = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right
$lblVersion.Location  = New-Object System.Drawing.Point(950, 27)
$lblVersion.Size      = New-Object System.Drawing.Size(150, 20)
$panelHeader.Controls.Add($lblVersion)

$ventana.Controls.Add($panelHeader)

# ---------------------------------------------------------------
# PANEL CONTENEDOR PRINCIPAL (debajo del header)
# ---------------------------------------------------------------
$panelMain = New-Object System.Windows.Forms.Panel
$panelMain.Dock      = [System.Windows.Forms.DockStyle]::Fill
$panelMain.BackColor = $colores.Fondo
$ventana.Controls.Add($panelMain)

# ---------------------------------------------------------------
# SIDEBAR IZQUIERDO
# ---------------------------------------------------------------
$panelSidebar = New-Object System.Windows.Forms.Panel
$panelSidebar.Dock      = [System.Windows.Forms.DockStyle]::Left
$panelSidebar.Width     = 180
$panelSidebar.BackColor = $colores.FondoSidebar
$panelMain.Controls.Add($panelSidebar)

# Funcin para agregar botn al sidebar
$script:SidebarY = 10

function Add-SidebarItem {
    param([string]$Text, [bool]$IsHeader = $false, [string]$Tag = "")
    $btn = New-SidebarButton -Text $Text -Y $script:SidebarY -IsHeader $IsHeader
    if (-not $IsHeader) { $btn.Tag = "navbtn" }
    if ($Tag) { $btn.Name = $Tag }
    $panelSidebar.Controls.Add($btn)
    $script:SidebarY += if ($IsHeader) { 28 } else { 38 }
    return $btn
}

$null = Add-SidebarItem "  NAVEGACIN"         $true
$btnNavProgramas = Add-SidebarItem "  [PKG]  Programas"      $false "nav_programas"
$btnNavSistema   = Add-SidebarItem "  [SYS]  Sistema"        $false "nav_sistema"
$btnNavRed       = Add-SidebarItem "  [NET]  Red"            $false "nav_red"
$btnNavLogs      = Add-SidebarItem "  [LOG]  Logs"           $false "nav_logs"
$script:SidebarY += 10
$null = Add-SidebarItem "  CATEGORAS"         $true
$btnCatTodos     = Add-SidebarItem "  [*]  Todos"          $false "cat_todos"
$btnCatOffice    = Add-SidebarItem "  [DOC]  Office"         $false "cat_office"
$btnCatNav       = Add-SidebarItem "  [NET]  Navegadores"    $false "cat_navegadores"
$btnCatPDF       = Add-SidebarItem "  [LOG]  PDF"            $false "cat_pdf"
$btnCatComp      = Add-SidebarItem "  [ZIP]  Compresores"    $false "cat_compresores"
$btnCatMedia     = Add-SidebarItem "  [MED]  Multimedia"     $false "cat_multimedia"
$btnCatUtil      = Add-SidebarItem "  [TLS]  Utilidades"     $false "cat_utilidades"
$btnCatAcceso    = Add-SidebarItem "  [SYS]  Acceso Remoto"  $false "cat_acceso"
$btnCatDriv      = Add-SidebarItem "  [DRV]  Drivers"        $false "cat_drivers"
$script:SidebarY += 10
$headerNav3      = Add-SidebarItem "  HERRAMIENTAS"       $true
$btnNavUpdate    = Add-SidebarItem "  [UPD]  Actualizaciones" $false "nav_update"

# ---------------------------------------------------------------
# PANEL CENTRAL (rea de contenido principal)
# ---------------------------------------------------------------
$panelContenido = New-Object System.Windows.Forms.Panel
$panelContenido.Dock      = [System.Windows.Forms.DockStyle]::Fill
$panelContenido.BackColor = $colores.Fondo
$panelContenido.Padding   = New-Object System.Windows.Forms.Padding(15)
$panelMain.Controls.Add($panelContenido)

# =============================================================================
# PANEL: PROGRAMAS (Vista Principal)
# =============================================================================
$panelPrograms = New-Object System.Windows.Forms.Panel
$panelPrograms.Dock      = [System.Windows.Forms.DockStyle]::Fill
$panelPrograms.BackColor = $colores.Fondo
$panelPrograms.Visible   = $true
$panelContenido.Controls.Add($panelPrograms)

# --- Barra de herramientas superior ---
$panelToolbar = New-Object System.Windows.Forms.Panel
$panelToolbar.Height    = 50
$panelToolbar.Dock      = [System.Windows.Forms.DockStyle]::Top
$panelToolbar.BackColor = $colores.FondoPanel
$panelPrograms.Controls.Add($panelToolbar)

# Bsqueda
$lblBuscar = New-Object System.Windows.Forms.Label
$lblBuscar.Text      = "[?]"
$lblBuscar.Font      = New-Object System.Drawing.Font("Segoe UI Emoji", 11)
$lblBuscar.ForeColor = $colores.TextoSecundario
$lblBuscar.Location  = New-Object System.Drawing.Point(10, 12)
$lblBuscar.Size      = New-Object System.Drawing.Size(30, 28)
$panelToolbar.Controls.Add($lblBuscar)

$txtBuscar = New-Object System.Windows.Forms.TextBox
$txtBuscar.Location    = New-Object System.Drawing.Point(42, 12)
$txtBuscar.Size        = New-Object System.Drawing.Size(280, 28)
$txtBuscar.BackColor   = $colores.FondoInput
$txtBuscar.ForeColor   = $colores.TextoPrimario
$txtBuscar.Font        = $fuentes.Normal
$txtBuscar.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$txtBuscar.Text        = "Buscar programa..."
$txtBuscar.ForeColor   = $colores.TextoMuted
$panelToolbar.Controls.Add($txtBuscar)

# Botones de accin toolbar
$btnActualizar = New-StyledButton -Text "Actualizar  Actualizar lista" -X 340 -Y 10 -Width 150 -Height 32 `
    -BackColor $colores.FondoCard -ForeColor $colores.TextoPrimario -Font $fuentes.Normal -Name "btn_refresh"
$panelToolbar.Controls.Add($btnActualizar)

$btnInstalarSel = New-StyledButton -Text ">  Instalar seleccionados" -X 500 -Y 10 -Width 190 -Height 32 `
    -BackColor $colores.BotonVerde -ForeColor $colores.TextoPrimario -Font $fuentes.Negrita -Name "btn_install_sel"
$panelToolbar.Controls.Add($btnInstalarSel)

$btnInstalarSilencioso = New-StyledButton -Text "[!]  Modo silencioso" -X 700 -Y 10 -Width 150 -Height 32 `
    -BackColor $colores.AcentoPurpura -ForeColor $colores.TextoPrimario -Font $fuentes.Normal -Name "btn_silent"
$panelToolbar.Controls.Add($btnInstalarSilencioso)

# --- Panel de lista de programas ---
$panelListaPrograms = New-Object System.Windows.Forms.Panel
$panelListaPrograms.Dock      = [System.Windows.Forms.DockStyle]::Fill
$panelListaPrograms.BackColor = $colores.Fondo
$panelPrograms.Controls.Add($panelListaPrograms)

# ListView de programas
$listView = New-Object System.Windows.Forms.ListView
$listView.Dock             = [System.Windows.Forms.DockStyle]::Fill
$listView.View             = [System.Windows.Forms.View]::Details
$listView.BackColor        = $colores.FondoPanel
$listView.ForeColor        = $colores.TextoPrimario
$listView.Font             = $fuentes.Normal
$listView.FullRowSelect    = $true
$listView.CheckBoxes       = $true
$listView.GridLines        = $false
$listView.BorderStyle      = [System.Windows.Forms.BorderStyle]::None
$listView.MultiSelect      = $true
$listView.OwnerDraw        = $false
$listView.HeaderStyle      = [System.Windows.Forms.ColumnHeaderStyle]::Nonclickable

# Columnas
$listView.Columns.Add("Nombre",     250) | Out-Null
$listView.Columns.Add("Categora",  110) | Out-Null
$listView.Columns.Add("Archivo",    200) | Out-Null
$listView.Columns.Add("Tamao",      80) | Out-Null
$listView.Columns.Add("Fecha",      130) | Out-Null
$listView.Columns.Add("Tipo",        60) | Out-Null
$panelListaPrograms.Controls.Add($listView)

# --- Panel inferior: Progreso y logs ---
$panelInferior = New-Object System.Windows.Forms.Panel
$panelInferior.Height    = 165
$panelInferior.Dock      = [System.Windows.Forms.DockStyle]::Bottom
$panelInferior.BackColor = $colores.FondoPanel
$panelPrograms.Controls.Add($panelInferior)

# Barra de progreso
$lblProgreso = New-Object System.Windows.Forms.Label
$lblProgreso.Text      = "PROGRESO"
$lblProgreso.Font      = $fuentes.Pequena
$lblProgreso.ForeColor = $colores.TextoMuted
$lblProgreso.Location  = New-Object System.Drawing.Point(10, 8)
$lblProgreso.Size      = New-Object System.Drawing.Size(200, 15)
$panelInferior.Controls.Add($lblProgreso)

$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location  = New-Object System.Drawing.Point(10, 26)
$progressBar.Size      = New-Object System.Drawing.Size(500, 18)
$progressBar.Style     = [System.Windows.Forms.ProgressBarStyle]::Continuous
$progressBar.BackColor = $colores.FondoCard
$progressBar.ForeColor = $colores.Acento
$progressBar.Minimum   = 0
$progressBar.Maximum   = 100
$progressBar.Value     = 0
$panelInferior.Controls.Add($progressBar)

$lblEstadoInstal = New-Object System.Windows.Forms.Label
$lblEstadoInstal.Text      = "Listo"
$lblEstadoInstal.Font      = $fuentes.Normal
$lblEstadoInstal.ForeColor = $colores.AcentoVerde
$lblEstadoInstal.Location  = New-Object System.Drawing.Point(520, 28)
$lblEstadoInstal.Size      = New-Object System.Drawing.Size(350, 18)
$panelInferior.Controls.Add($lblEstadoInstal)

# rea de logs inline
$lblLogTitle = New-Object System.Windows.Forms.Label
$lblLogTitle.Text      = "REGISTRO DE ACTIVIDAD"
$lblLogTitle.Font      = $fuentes.Pequena
$lblLogTitle.ForeColor = $colores.TextoMuted
$lblLogTitle.Location  = New-Object System.Drawing.Point(10, 52)
$lblLogTitle.Size      = New-Object System.Drawing.Size(200, 15)
$panelInferior.Controls.Add($lblLogTitle)

$txtLogInline = New-Object System.Windows.Forms.RichTextBox
$txtLogInline.Location      = New-Object System.Drawing.Point(10, 70)
$txtLogInline.Size          = New-Object System.Drawing.Size(900, 85)
$txtLogInline.BackColor     = $colores.FondoHeader
$txtLogInline.ForeColor     = $colores.AcentoVerde
$txtLogInline.Font          = $fuentes.Log
$txtLogInline.ReadOnly      = $true
$txtLogInline.BorderStyle   = [System.Windows.Forms.BorderStyle]::None
$txtLogInline.ScrollBars    = [System.Windows.Forms.RichTextBoxScrollBars]::Vertical
$txtLogInline.Anchor        = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$panelInferior.Controls.Add($txtLogInline)

function Add-LogLine {
    param([string]$Mensaje, [string]$Nivel = "INFO")
    $ts    = Get-Date -Format "HH:mm:ss"
    $color = switch ($Nivel) {
        "SUCCESS" { [System.Drawing.Color]::FromArgb(48, 209, 88)  }
        "ERROR"   { [System.Drawing.Color]::FromArgb(255, 69, 58)  }
        "WARNING" { [System.Drawing.Color]::FromArgb(255, 214, 10) }
        "ACTION"  { [System.Drawing.Color]::FromArgb(0, 200, 255)  }
        default   { [System.Drawing.Color]::FromArgb(140, 155, 190) }
    }

    $txtLogInline.SelectionStart  = $txtLogInline.TextLength
    $txtLogInline.SelectionLength = 0
    $txtLogInline.SelectionColor  = $color
    $txtLogInline.AppendText("[$ts][$Nivel] $Mensaje`n")
    $txtLogInline.ScrollToCaret()
}

# =============================================================================
# PANEL: INFORMACIN DEL SISTEMA
# =============================================================================
$panelSistema = New-Object System.Windows.Forms.Panel
$panelSistema.Dock      = [System.Windows.Forms.DockStyle]::Fill
$panelSistema.BackColor = $colores.Fondo
$panelSistema.Visible   = $false
$panelContenido.Controls.Add($panelSistema)

$lblSisHeader = New-Object System.Windows.Forms.Label
$lblSisHeader.Text      = "[SYS]  Informacin del Sistema"
$lblSisHeader.Font      = $fuentes.Header
$lblSisHeader.ForeColor = $colores.TextoPrimario
$lblSisHeader.Location  = New-Object System.Drawing.Point(10, 15)
$lblSisHeader.Size      = New-Object System.Drawing.Size(500, 30)
$panelSistema.Controls.Add($lblSisHeader)

$lblSisSubtitle = New-Object System.Windows.Forms.Label
$lblSisSubtitle.Text      = "Datos del equipo local. Esta informacin NO se enva a ningn servidor."
$lblSisSubtitle.Font      = $fuentes.Normal
$lblSisSubtitle.ForeColor = $colores.TextoSecundario
$lblSisSubtitle.Location  = New-Object System.Drawing.Point(10, 45)
$lblSisSubtitle.Size      = New-Object System.Drawing.Size(700, 20)
$panelSistema.Controls.Add($lblSisSubtitle)

$txtSistema = New-Object System.Windows.Forms.RichTextBox
$txtSistema.Location    = New-Object System.Drawing.Point(10, 80)
$txtSistema.Size        = New-Object System.Drawing.Size(800, 450)
$txtSistema.BackColor   = $colores.FondoPanel
$txtSistema.ForeColor   = $colores.TextoPrimario
$txtSistema.Font        = New-Object System.Drawing.Font("Consolas", 10)
$txtSistema.ReadOnly    = $true
$txtSistema.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$panelSistema.Controls.Add($txtSistema)

$btnRefreshSis = New-StyledButton -Text "Actualizar  Actualizar datos" -X 10 -Y 545 -Width 160 -Height 32 `
    -BackColor $colores.FondoCard -ForeColor $colores.TextoPrimario -Font $fuentes.Normal
$panelSistema.Controls.Add($btnRefreshSis)

function Update-SystemInfo {
    try {
        $txtSistema.Clear()
        $info = Get-SystemInfo

        $lineas = @(
            "===========================================================",
            "   TECH INSTALLER 2026 - Informacin del Equipo",
            "   Generado: $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')",
            "===========================================================",
            "",
            "  EQUIPO",
            "  ---------------------------",
            "  Nombre del equipo   : $($info.NombreEquipo)",
            "  Usuario actual      : $($info.Usuario)",
            "  Dominio/Grupo       : $($info.Dominio)",
            "  Fabricante          : $($info.Fabricante)",
            "  Modelo              : $($info.Modelo)",
            "",
            "  SISTEMA OPERATIVO",
            "  ---------------------------",
            "  Windows             : $($info.WindowsVersion)",
            "  Arquitectura        : $($info.Arquitectura)",
            "  Build               : $($info.Build)",
            "",
            "  HARDWARE",
            "  ---------------------------",
            "  RAM Total           : $($info.RAM_Total)",
            "  Disco C: (Total)    : $($info.DiscoTotal)",
            "  Disco C: (Libre)    : $($info.DiscoLibre)",
            "  Disco C: (Usado)    : $($info.DiscoUsado)",
            "",
            "  SOFTWARE",
            "  ---------------------------",
            "  PowerShell          : $($info.PowerShellVersion)",
            "  Direccin IP        : $($info.DireccionIP)",
            "",
            "==========================================================="
        )

        $txtSistema.Text = $lineas -join "`n"

    } catch {
        $txtSistema.Text = "Error al obtener informacin del sistema: $_"
    }
}

# =============================================================================
# PANEL: RED Y DIAGNSTICO
# =============================================================================
$panelRed = New-Object System.Windows.Forms.Panel
$panelRed.Dock      = [System.Windows.Forms.DockStyle]::Fill
$panelRed.BackColor = $colores.Fondo
$panelRed.Visible   = $false
$panelContenido.Controls.Add($panelRed)

$lblRedHeader = New-Object System.Windows.Forms.Label
$lblRedHeader.Text      = "[NET]  Herramientas de Red y Diagnstico"
$lblRedHeader.Font      = $fuentes.Header
$lblRedHeader.ForeColor = $colores.TextoPrimario
$lblRedHeader.Location  = New-Object System.Drawing.Point(10, 15)
$lblRedHeader.Size      = New-Object System.Drawing.Size(600, 30)
$panelRed.Controls.Add($lblRedHeader)

# Botones de red
$redBtns = @(
    @{Text = "IPConfig /all";          Cmd = "ipconfig";    Args = "/all"             },
    @{Text = "Liberar IP (Release)";   Cmd = "ipconfig";    Args = "/release"         },
    @{Text = "Renovar IP (Renew)";     Cmd = "ipconfig";    Args = "/renew"           },
    @{Text = "Limpiar DNS (FlushDNS)"; Cmd = "ipconfig";    Args = "/flushdns"        },
    @{Text = "Ping Google";            Cmd = "ping";        Args = "-n 4 8.8.8.8"     },
    @{Text = "Tracert Google";         Cmd = "tracert";     Args = "-d -h 15 8.8.8.8" },
    @{Text = "Netstat";                Cmd = "netstat";     Args = "-an"              },
    @{Text = "NSLookup Google";        Cmd = "nslookup";    Args = "google.com"       }
)

$redX = 10
$redY = 55
foreach ($item in $redBtns) {
    $capturedItem = $item
    $redBtn = New-StyledButton -Text $capturedItem.Text -X $redX -Y $redY -Width 170 -Height 34 `
        -BackColor $colores.FondoCard -ForeColor $colores.TextoPrimario -Font $fuentes.Normal
    $redBtn.Add_Click({
        $txtRedOutput.Text = "Ejecutando: $($capturedItem.Cmd) $($capturedItem.Args)...`r`n"
        $ventana.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        try {
            $out = & cmd /c "$($capturedItem.Cmd) $($capturedItem.Args) 2>&1"
            $txtRedOutput.Text = ($out -join "`r`n")
        } catch {
            $txtRedOutput.Text = "Error: $_"
        }
        $ventana.Cursor = [System.Windows.Forms.Cursors]::Default
    }.GetNewClosure())

    $panelRed.Controls.Add($redBtn)
    $redX += 180
    if ($redX -gt 750) { $redX = 10; $redY += 44 }
}

# rea de salida
$txtRedOutput = New-Object System.Windows.Forms.RichTextBox
$txtRedOutput.Location    = New-Object System.Drawing.Point(10, 145)
$txtRedOutput.Size        = New-Object System.Drawing.Size(850, 400)
$txtRedOutput.BackColor   = $colores.FondoHeader
$txtRedOutput.ForeColor   = $colores.AcentoVerde
$txtRedOutput.Font        = $fuentes.Codigo
$txtRedOutput.ReadOnly    = $true
$txtRedOutput.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$txtRedOutput.Text        = "Seleccione una herramienta de red..."
$panelRed.Controls.Add($txtRedOutput)

# =============================================================================
# PANEL: LOGS COMPLETOS
# =============================================================================
$panelLogs = New-Object System.Windows.Forms.Panel
$panelLogs.Dock      = [System.Windows.Forms.DockStyle]::Fill
$panelLogs.BackColor = $colores.Fondo
$panelLogs.Visible   = $false
$panelContenido.Controls.Add($panelLogs)

$lblLogsHeader = New-Object System.Windows.Forms.Label
$lblLogsHeader.Text      = "[LOG]  Registro de Actividad"
$lblLogsHeader.Font      = $fuentes.Header
$lblLogsHeader.ForeColor = $colores.TextoPrimario
$lblLogsHeader.Location  = New-Object System.Drawing.Point(10, 15)
$lblLogsHeader.Size      = New-Object System.Drawing.Size(400, 30)
$panelLogs.Controls.Add($lblLogsHeader)

$btnAbrirLog = New-StyledButton -Text "[DIR]  Abrir carpeta" -X 10 -Y 55 -Width 150 -Height 32 `
    -BackColor $colores.FondoCard -ForeColor $colores.TextoPrimario -Font $fuentes.Normal
$panelLogs.Controls.Add($btnAbrirLog)

$btnRefreshLog = New-StyledButton -Text "Actualizar  Recargar" -X 170 -Y 55 -Width 120 -Height 32 `
    -BackColor $colores.FondoCard -ForeColor $colores.TextoPrimario -Font $fuentes.Normal
$panelLogs.Controls.Add($btnRefreshLog)

$txtLogsCompletos = New-Object System.Windows.Forms.RichTextBox
$txtLogsCompletos.Location    = New-Object System.Drawing.Point(10, 100)
$txtLogsCompletos.Size        = New-Object System.Drawing.Size(900, 500)
$txtLogsCompletos.BackColor   = $colores.FondoHeader
$txtLogsCompletos.ForeColor   = $colores.AcentoVerde
$txtLogsCompletos.Font        = $fuentes.Log
$txtLogsCompletos.ReadOnly    = $true
$txtLogsCompletos.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$txtLogsCompletos.ScrollBars  = [System.Windows.Forms.RichTextBoxScrollBars]::Both
$panelLogs.Controls.Add($txtLogsCompletos)

# =============================================================================
# PANEL: ACTUALIZACIONES
# =============================================================================
$panelUpdate = New-Object System.Windows.Forms.Panel
$panelUpdate.Dock      = [System.Windows.Forms.DockStyle]::Fill
$panelUpdate.BackColor = $colores.Fondo
$panelUpdate.Visible   = $false
$panelContenido.Controls.Add($panelUpdate)

$lblUpdateHeader = New-Object System.Windows.Forms.Label
$lblUpdateHeader.Text      = "[UPD]  Actualizaciones"
$lblUpdateHeader.Font      = $fuentes.Header
$lblUpdateHeader.ForeColor = $colores.TextoPrimario
$lblUpdateHeader.Location  = New-Object System.Drawing.Point(10, 15)
$lblUpdateHeader.Size      = New-Object System.Drawing.Size(400, 30)
$panelUpdate.Controls.Add($lblUpdateHeader)

$lblVerLocal  = New-Object System.Windows.Forms.Label
$lblVerLocal.Location = New-Object System.Drawing.Point(10, 65)
$lblVerLocal.Size     = New-Object System.Drawing.Size(500, 22)
$lblVerLocal.Font     = $fuentes.Normal
$lblVerLocal.ForeColor = $colores.TextoSecundario
try { $verLocal = Get-LocalVersion -VersionFilePath $script:VersionPath } catch { $verLocal = "1.0.0" }
$lblVerLocal.Text     = "Versin instalada: $verLocal"
$panelUpdate.Controls.Add($lblVerLocal)

$lblVerRemota = New-Object System.Windows.Forms.Label
$lblVerRemota.Location  = New-Object System.Drawing.Point(10, 90)
$lblVerRemota.Size      = New-Object System.Drawing.Size(500, 22)
$lblVerRemota.Font      = $fuentes.Normal
$lblVerRemota.ForeColor = $colores.TextoSecundario
$lblVerRemota.Text      = "Versin disponible: -"
$panelUpdate.Controls.Add($lblVerRemota)

$lblUpdateStatus = New-Object System.Windows.Forms.Label
$lblUpdateStatus.Location  = New-Object System.Drawing.Point(10, 120)
$lblUpdateStatus.Size      = New-Object System.Drawing.Size(600, 24)
$lblUpdateStatus.Font      = $fuentes.Negrita
$lblUpdateStatus.ForeColor = $colores.TextoSecundario
$lblUpdateStatus.Text      = "Haz clic en 'Buscar actualizaciones' para comprobar."
$panelUpdate.Controls.Add($lblUpdateStatus)

$btnCheckUpdate = New-StyledButton -Text "[?]  Buscar actualizaciones" -X 10 -Y 160 -Width 220 -Height 38 `
    -BackColor $colores.Acento -ForeColor $colores.TextoPrimario -Font $fuentes.Negrita
$panelUpdate.Controls.Add($btnCheckUpdate)

$btnDoUpdate = New-StyledButton -Text "Descargar  Descargar actualizacin" -X 245 -Y 160 -Width 230 -Height 38 `
    -BackColor $colores.BotonVerde -ForeColor $colores.TextoPrimario -Font $fuentes.Negrita
$btnDoUpdate.Enabled = $false
$panelUpdate.Controls.Add($btnDoUpdate)

$txtUpdateLog = New-Object System.Windows.Forms.RichTextBox
$txtUpdateLog.Location    = New-Object System.Drawing.Point(10, 215)
$txtUpdateLog.Size        = New-Object System.Drawing.Size(800, 350)
$txtUpdateLog.BackColor   = $colores.FondoHeader
$txtUpdateLog.ForeColor   = $colores.TextoSecundario
$txtUpdateLog.Font        = $fuentes.Log
$txtUpdateLog.ReadOnly    = $true
$txtUpdateLog.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$txtUpdateLog.Text        = "Registro de actualizaciones...`r`n"
$panelUpdate.Controls.Add($txtUpdateLog)

# =============================================================================
# PASO 8: LGICA DE NAVEGACIN
# =============================================================================
function Show-Panel {
    param([string]$PanelName)

    $panelPrograms.Visible = $false
    $panelSistema.Visible  = $false
    $panelRed.Visible      = $false
    $panelLogs.Visible     = $false
    $panelUpdate.Visible   = $false

    switch ($PanelName) {
        "Programas"    { $panelPrograms.Visible = $true }
        "Sistema"      {
            $panelSistema.Visible  = $true
            Update-SystemInfo
        }
        "Red"          { $panelRed.Visible      = $true }
        "Logs"         {
            $panelLogs.Visible = $true
            $contenidoLog = Get-LogContent
            $txtLogsCompletos.Text = if ($contenidoLog) { $contenidoLog } else { "No hay registros." }
            $txtLogsCompletos.SelectionStart = $txtLogsCompletos.Text.Length
            $txtLogsCompletos.ScrollToCaret()
        }
        "Actualizaciones" { $panelUpdate.Visible = $true }
    }
}

# =============================================================================
# PASO 9: LGICA DE CARGA Y FILTRADO DE PROGRAMAS
# =============================================================================
function Update-ProgramList {
    param([string]$Categoria = "Todos", [string]$Busqueda = "")

    try {
        $listView.Items.Clear()
        Add-LogLine "Escaneando carpeta de programas..." "INFO"
        Write-Log "Actualizando lista de programas. Categora: $Categoria | Bsqueda: '$Busqueda'" "INFO"

        $excluir = @()
        if ($script:Config.ExcludeFolders) { $excluir = @($script:Config.ExcludeFolders) }
        $script:ListaProgramas = Get-ProgramList -ProgramsFolder $script:ProgramsPath `n                                                  -CategoriesConfig $script:CatConfig `n                                                  -ExcludeFolders $excluir

        # Aplicar filtros
        $programasFiltrados = $script:ListaProgramas

        if ($Categoria -ne "Todos" -and $Categoria -ne "") {
            $programasFiltrados = $programasFiltrados | Where-Object { $_.Categoria -eq $Categoria }
        }

        if (-not [string]::IsNullOrWhiteSpace($Busqueda) -and $Busqueda -ne "Buscar programa...") {
            $programasFiltrados = $programasFiltrados | Where-Object {
                $_.Nombre -like "*$Busqueda*" -or $_.Archivo -like "*$Busqueda*"
            }
        }

        # Poblar el ListView
        foreach ($prog in $programasFiltrados) {
            $item = New-Object System.Windows.Forms.ListViewItem($prog.Nombre)
            $item.SubItems.Add($prog.Categoria)  | Out-Null
            $item.SubItems.Add($prog.Archivo)     | Out-Null
            $item.SubItems.Add($prog.TamanoTexto) | Out-Null
            $item.SubItems.Add($prog.FechaTexto)  | Out-Null
            $item.SubItems.Add($prog.Extension.ToUpper()) | Out-Null
            $item.Tag = $prog  # Guardar referencia al objeto programa

            # Color de fila alternado
            if ($listView.Items.Count % 2 -eq 0) {
                $item.BackColor = $colores.FondoPanel
            } else {
                $item.BackColor = $colores.FondoCard
            }
            $item.ForeColor = $colores.TextoPrimario

            $listView.Items.Add($item) | Out-Null
        }

        $total = $script:ListaProgramas.Count
        $mostrando = $programasFiltrados.Count

        if ($Categoria -eq "Todos" -and [string]::IsNullOrWhiteSpace($Busqueda)) {
            $categoriasDetectadas = Get-CategoryList -ProgramList $script:ListaProgramas
            Update-SidebarCategories -Categorias $categoriasDetectadas
        }

        if ($total -eq 0) {
            Add-LogLine "No se encontraron programas en: $script:ProgramsPath" "WARNING"
            Add-LogLine "Agrega archivos .exe, .msi, .bat o .cmd en las subcarpetas de 'Programas/'" "INFO"
        } else {
            Add-LogLine "Encontrados: $total programas. Mostrando: $mostrando" "SUCCESS"
        }

    } catch {
        Add-LogLine "Error al cargar programas: $_" "ERROR"
        Write-Log "Error al cargar lista de programas: $_" "ERROR"
    }
}

# =============================================================================
# PASO 10: LGICA DE INSTALACIN
# =============================================================================
function Start-SelectedPrograms {
    param([bool]$Silencioso = $false)

    # Obtener programas seleccionados (con checkbox marcado)
    $seleccionados = @($listView.CheckedItems | ForEach-Object { $_.Tag })

    # Si ninguno est chequeado pero hay uno seleccionado (azul), usar ese
    if ($seleccionados.Count -eq 0 -and $listView.SelectedItems.Count -gt 0) {
        $seleccionados = @($listView.SelectedItems | ForEach-Object { $_.Tag })
    }

    if ($seleccionados.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show(
            "Selecciona al menos un programa para instalar.`n`nMarca las casillas de los programas deseados.",
            "Sin seleccin",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
        return
    }

    $modoTexto = if ($Silencioso) { "SILENCIOSO" } else { "NORMAL" }
    $confirm = [System.Windows.Forms.MessageBox]::Show(
        "Instalar $($seleccionados.Count) programa(s) en modo $modoTexto?`n`n[!] Se solicitarn permisos de administrador (UAC) para cada instalador.",
        "Confirmar instalacin",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )

    if ($confirm -ne [System.Windows.Forms.DialogResult]::Yes) { return }

    $total = $seleccionados.Count
    $completados = 0
    $errores = 0

    $progressBar.Value   = 0
    $progressBar.Maximum = $total

    foreach ($prog in $seleccionados) {
        try {
            $lblEstadoInstal.ForeColor = $colores.AcentoAmarillo
            $lblEstadoInstal.Text      = "Instalando: $($prog.Nombre)..."
            Add-LogLine "Iniciando: $($prog.Nombre)" "ACTION"
            $ventana.Refresh()

            $resultado = Start-Installer -Programa $prog -Silencioso $Silencioso -Esperar $true

            $completados++
            $progressBar.Value = $completados

            if ($resultado.Exito -or $resultado.ExitCode -eq 0) {
                Add-LogLine "[OK] $($prog.Nombre) - $($resultado.Mensaje)" "SUCCESS"
                $lblEstadoInstal.ForeColor = $colores.AcentoVerde
                $lblEstadoInstal.Text      = "[OK] $($prog.Nombre) completado"
            } else {
                Add-LogLine "[!] $($prog.Nombre) - $($resultado.Mensaje)" "WARNING"
                $lblEstadoInstal.ForeColor = $colores.AcentoAmarillo
                $lblEstadoInstal.Text      = "[!] $($prog.Nombre): $($resultado.Mensaje)"
                $errores++
            }

        } catch {
            $errores++
            Add-LogLine "[X] Error en $($prog.Nombre): $_" "ERROR"
            $lblEstadoInstal.ForeColor = $colores.AcentoRojo
            $lblEstadoInstal.Text      = "[X] Error: $($prog.Nombre)"
            Write-Log "Error instalando $($prog.Nombre): $_" "ERROR"
        }

        $ventana.Refresh()
    }

    # Resultado final
    if ($errores -eq 0) {
        $lblEstadoInstal.ForeColor = $colores.AcentoVerde
        $lblEstadoInstal.Text      = "[OK] Instalacin completada ($completados/$total exitosos)"
        Add-LogLine "Proceso completado: $completados/$total instalados correctamente." "SUCCESS"
    } else {
        $lblEstadoInstal.ForeColor = $colores.AcentoAmarillo
        $lblEstadoInstal.Text      = "[!] Completado con advertencias ($errores errores de $total)"
        Add-LogLine "Proceso completado con $errores error(es)." "WARNING"
    }

    $progressBar.Value = $total
}

# =============================================================================
# PASO 11: ASIGNACIN DE EVENTOS
# =============================================================================

# --- Navegacin principal ---
$btnNavProgramas.Add_Click({
    Show-Panel "Programas"
    Update-SidebarButtonState $btnNavProgramas
})

$btnNavSistema.Add_Click({
    Show-Panel "Sistema"
    Update-SidebarButtonState $btnNavSistema
})

$btnNavRed.Add_Click({
    Show-Panel "Red"
    Update-SidebarButtonState $btnNavRed
})

$btnNavLogs.Add_Click({
    Show-Panel "Logs"
    Update-SidebarButtonState $btnNavLogs
})

$btnNavUpdate.Add_Click({
    Show-Panel "Actualizaciones"
    Update-SidebarButtonState $btnNavUpdate
})

# --- Filtros por categora ---
$btnCatTodos.Add_Click({
    $script:FiltroCategoria = "Todos"
    Update-ProgramList -Categoria "Todos" -Busqueda $script:FiltroBusqueda
    Update-SidebarButtonState $btnCatTodos
})

$btnCatOffice.Add_Click({
    $script:FiltroCategoria = "Office"
    Update-ProgramList -Categoria "Office" -Busqueda $script:FiltroBusqueda
    Update-SidebarButtonState $btnCatOffice
})
$btnCatNav.Add_Click({
    $script:FiltroCategoria = "Navegadores"
    Update-ProgramList -Categoria "Navegadores" -Busqueda $script:FiltroBusqueda
    Update-SidebarButtonState $btnCatNav
})
$btnCatPDF.Add_Click({
    $script:FiltroCategoria = "PDF"
    Update-ProgramList -Categoria "PDF" -Busqueda $script:FiltroBusqueda
    Update-SidebarButtonState $btnCatPDF
})
$btnCatComp.Add_Click({
    $script:FiltroCategoria = "Compresores"
    Update-ProgramList -Categoria "Compresores" -Busqueda $script:FiltroBusqueda
    Update-SidebarButtonState $btnCatComp
})
$btnCatMedia.Add_Click({
    $script:FiltroCategoria = "Multimedia"
    Update-ProgramList -Categoria "Multimedia" -Busqueda $script:FiltroBusqueda
    Update-SidebarButtonState $btnCatMedia
})
$btnCatUtil.Add_Click({
    $script:FiltroCategoria = "Utilidades"
    Update-ProgramList -Categoria "Utilidades" -Busqueda $script:FiltroBusqueda
    Update-SidebarButtonState $btnCatUtil
})
$btnCatAcceso.Add_Click({
    $script:FiltroCategoria = "AccesoRemoto"
    Update-ProgramList -Categoria "AccesoRemoto" -Busqueda $script:FiltroBusqueda
    Update-SidebarButtonState $btnCatAcceso
})
$btnCatDriv.Add_Click({
    $script:FiltroCategoria = "Drivers"
    Update-ProgramList -Categoria "Drivers" -Busqueda $script:FiltroBusqueda
    Update-SidebarButtonState $btnCatDriv
})

# --- Bsqueda ---
$txtBuscar.Add_GotFocus({
    if ($txtBuscar.Text -eq "Buscar programa...") {
        $txtBuscar.Text      = ""
        $txtBuscar.ForeColor = $colores.TextoPrimario
    }
})

$txtBuscar.Add_LostFocus({
    if ([string]::IsNullOrWhiteSpace($txtBuscar.Text)) {
        $txtBuscar.Text      = "Buscar programa..."
        $txtBuscar.ForeColor = $colores.TextoMuted
    }
})

$txtBuscar.Add_TextChanged({
    $busqueda = $txtBuscar.Text
    if ($busqueda -ne "Buscar programa...") {
        $script:FiltroBusqueda = $busqueda
        Update-ProgramList -Categoria $script:FiltroCategoria -Busqueda $busqueda
    }
})

# --- Acciones de instalacin ---
$btnActualizar.Add_Click({
    Update-ProgramList -Categoria $script:FiltroCategoria -Busqueda $script:FiltroBusqueda
})

$btnInstalarSel.Add_Click({ Start-SelectedPrograms -Silencioso $false })
$btnInstalarSilencioso.Add_Click({ Start-SelectedPrograms -Silencioso $true })

# Doble clic en programa: ejecutar directamente
$listView.Add_DoubleClick({
    if ($listView.SelectedItems.Count -gt 0) {
        $prog = $listView.SelectedItems[0].Tag
        if ($null -ne $prog) {
            $confirm = [System.Windows.Forms.MessageBox]::Show(
                "Ejecutar: $($prog.Nombre)?`n`nArchivo: $($prog.Archivo)`nSe solicitarn permisos de administrador si es necesario.",
                "Ejecutar programa",
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Question
            )

            if ($confirm -eq [System.Windows.Forms.DialogResult]::Yes) {
                $resultado = Start-Installer -Programa $prog -Silencioso $false -Esperar $false
                if ($resultado.Exito) {
                    Add-LogLine "Ejecutado: $($prog.Nombre)" "SUCCESS"
                    $lblEstadoInstal.Text      = "Ejecutando: $($prog.Nombre)"
                    $lblEstadoInstal.ForeColor = $colores.AcentoVerde
                } else {
                    Add-LogLine "Error al ejecutar $($prog.Nombre): $($resultado.Mensaje)" "ERROR"
                    [System.Windows.Forms.MessageBox]::Show(
                        "No se pudo ejecutar el programa.`n`n$($resultado.Mensaje)",
                        "Error de ejecucin",
                        [System.Windows.Forms.MessageBoxButtons]::OK,
                        [System.Windows.Forms.MessageBoxIcon]::Error
                    ) | Out-Null
                }
            }
        }
    }
})

# --- Sistema ---
$btnRefreshSis.Add_Click({ Update-SystemInfo })

# --- Logs ---
$btnAbrirLog.Add_Click({
    try {
        if (Test-Path $script:LogsPath) {
            Start-Process explorer.exe $script:LogsPath
        }
    } catch {
        Add-LogLine "Error al abrir carpeta de logs: $_" "ERROR"
    }
})

$btnRefreshLog.Add_Click({
    $contenidoLog = Get-LogContent
    $txtLogsCompletos.Text = if ($contenidoLog) { $contenidoLog } else { "No hay registros." }
    $txtLogsCompletos.SelectionStart = $txtLogsCompletos.Text.Length
    $txtLogsCompletos.ScrollToCaret()
})

# --- Actualizaciones ---
$script:RemoteVersionData = $null

$btnCheckUpdate.Add_Click({
    try {
        $btnCheckUpdate.Enabled = $false
        $lblUpdateStatus.Text      = "[?] Buscando actualizaciones..."
        $lblUpdateStatus.ForeColor = $colores.AcentoAmarillo
        $txtUpdateLog.AppendText("$(Get-Date -Format 'HH:mm:ss') - Verificando actualizaciones...`r`n")
        $ventana.Refresh()

        $resultadoUpdate = Check-ForUpdates -Config $script:Config -VersionFilePath $script:VersionPath

        $lblVerLocal.Text  = "Versin instalada   : $($resultadoUpdate.LocalVersion)"
        $lblVerRemota.Text = "Versin disponible  : $($resultadoUpdate.RemoteVersion)"

        if ($resultadoUpdate.Error) {
            $lblUpdateStatus.Text      = "[!] $($resultadoUpdate.Error)"
            $lblUpdateStatus.ForeColor = $colores.AcentoAmarillo
            $txtUpdateLog.AppendText("$($resultadoUpdate.Error)`r`n")
        } elseif ($resultadoUpdate.HasUpdate) {
            $lblUpdateStatus.Text      = "[*] Nueva versin disponible: $($resultadoUpdate.RemoteVersion)"
            $lblUpdateStatus.ForeColor = $colores.AcentoVerde
            $btnDoUpdate.Enabled       = $true
            $script:RemoteVersionData  = $resultadoUpdate
            $txtUpdateLog.AppendText("Nueva versin disponible: $($resultadoUpdate.RemoteVersion)`r`n")
            if ($resultadoUpdate.ReleaseNotes) {
                $txtUpdateLog.AppendText("Novedades: $($resultadoUpdate.ReleaseNotes)`r`n")
            }
        } else {
            $lblUpdateStatus.Text      = "[OK] La herramienta est actualizada (v$($resultadoUpdate.LocalVersion))"
            $lblUpdateStatus.ForeColor = $colores.AcentoVerde
            $txtUpdateLog.AppendText("La aplicacin est actualizada.`r`n")
        }

    } catch {
        $lblUpdateStatus.Text      = "[X] Error al verificar: $_"
        $lblUpdateStatus.ForeColor = $colores.AcentoRojo
        $txtUpdateLog.AppendText("Error: $_`r`n")
        Write-Log "Error al verificar actualizaciones: $_" "ERROR"
    } finally {
        $btnCheckUpdate.Enabled = $true
    }
})

$btnDoUpdate.Add_Click({
    try {
        $conf = [System.Windows.Forms.MessageBox]::Show(
            "Descargar y aplicar la actualizacin?`n`nSe descargar desde GitHub y se extraer en una carpeta temporal.`nLuego debers cerrar y reabrir la aplicacin.",
            "Actualizar Tech Installer 2026",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question
        )

        if ($conf -ne [System.Windows.Forms.DialogResult]::Yes) { return }

        $btnDoUpdate.Enabled = $false
        $txtUpdateLog.AppendText("Iniciando descarga...`r`n")
        $ventana.Refresh()

        $userParts = $script:Config.GitHubRepository -split '/'
        $ghUser = if ($userParts.Count -ge 1) { $userParts[0] } else { $script:Config.GitHubUser }
        $ghRepo = if ($userParts.Count -ge 2) { $userParts[1] } else { "TechInstaller" }

        $rutaDescarga = Start-UpdateDownload -GitHubUser $ghUser `
                                             -Repository $ghRepo `
                                             -Branch     $script:Config.Branch

        if ($rutaDescarga) {
            $txtUpdateLog.AppendText("Descarga exitosa en: $rutaDescarga`r`n")
            $txtUpdateLog.AppendText("Abre la carpeta extrada y reemplaza los archivos del proyecto.`r`n")
            $lblUpdateStatus.Text      = "[OK] Descarga completada. Revisa la carpeta temporal."
            $lblUpdateStatus.ForeColor = $colores.AcentoVerde
            Start-Process explorer.exe $rutaDescarga
        } else {
            $txtUpdateLog.AppendText("Error al descargar. Verifica tu conexin a Internet.`r`n")
            $lblUpdateStatus.Text      = "[X] Error al descargar actualizacin"
            $lblUpdateStatus.ForeColor = $colores.AcentoRojo
        }

    } catch {
        $txtUpdateLog.AppendText("Error durante la actualizacin: $_`r`n")
        Write-Log "Error durante actualizacin: $_" "ERROR"
    }
})

# =============================================================================
# PASO 12: EVENTO DE CIERRE
# =============================================================================
$ventana.Add_FormClosing({
    Write-Log "=== Tech Installer 2026 cerrado por el usuario ===" "INFO"
    Write-LogSeparator
})

# =============================================================================
# PASO 13: INICIALIZACIN FINAL Y APERTURA DE VENTANA
# =============================================================================

# Cargar estado inicial de la sidebar
Update-SidebarButtonState $btnNavProgramas
Update-SidebarButtonState $btnCatTodos

# Cargar programas al iniciar
Add-LogLine "Iniciando Tech Installer 2026..." "INFO"
Add-LogLine "Ruta del proyecto: $script:RootPath" "INFO"
Add-LogLine "Carpeta de programas: $script:ProgramsPath" "INFO"
Write-Log "GUI inicializada correctamente." "SUCCESS"

# Cargar lista de programas en segundo plano (despus de mostrar la ventana)
$ventana.Add_Shown({
    Update-ProgramList -Categoria "Todos"
    $btnCatTodos.BackColor = $colores.FondoCard
    $btnCatTodos.ForeColor = $colores.TextoPrimario
    $btnCatTodos.Font      = $fuentes.SidebarBold
})

# Mostrar la ventana principal
[System.Windows.Forms.Application]::Run($ventana)


