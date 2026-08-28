#Requires -Version 5.1
[CmdletBinding()]
param([switch]$NoAdmin)

$ErrorActionPreference = "Stop"

# =============================================================================
# PASO 1: CARGAR MÓDULOS DEL PROYECTO Y WPF
# =============================================================================
$script:RootPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:ScriptsPath = Join-Path $script:RootPath "Scripts"
$script:LogsPath = Join-Path $script:RootPath "Logs"

Add-Type -AssemblyName PresentationFramework

@("Logging.ps1", "Functions.ps1", "Detection.ps1", "Installer.ps1", "Update.ps1") | ForEach-Object {
    . (Join-Path $script:ScriptsPath $_)
}

# =============================================================================
# PASO 2: INICIALIZAR DATOS
# =============================================================================
$configFile = Join-Path $script:RootPath "Config\config.json"
$script:Config = Get-Content $configFile | ConvertFrom-Json
$script:ProgramsPath = [System.IO.Path]::GetFullPath((Join-Path $script:RootPath $script:Config.ProgramsFolder))
$script:CatConfig = Join-Path $script:RootPath "Config\categories.json"

$excluir = @()
if ($script:Config.ExcludeFolders) { $excluir = @($script:Config.ExcludeFolders) }

# Lógica para encontrar los programas si no están en la carpeta local (ej: si se descargó en AppData)
if (-not (Test-Path $script:ProgramsPath) -or (Get-ChildItem $script:ProgramsPath -Recurse -File | Where-Object Extension -in '.exe','.msi').Count -eq 0) {
    # Buscar en todas las unidades la carpeta TechInstaller\Programas
    $unidades = Get-WmiObject Win32_LogicalDisk -Filter "DriveType=3 OR DriveType=2" | Select-Object -ExpandProperty DeviceID
    foreach ($unidad in $unidades) {
        $posibleRuta = Join-Path $unidad "programas utilitarios 2026\TechInstaller\Programas"
        if (Test-Path $posibleRuta) {
            $script:ProgramsPath = $posibleRuta
            break
        }
        $posibleRuta2 = Join-Path $unidad "TechInstaller\Programas"
        if (Test-Path $posibleRuta2) {
            $script:ProgramsPath = $posibleRuta2
            break
        }
    }
}

$script:ListaProgramas = Get-ProgramList -ProgramsFolder $script:ProgramsPath -CategoriesConfig $script:CatConfig -ExcludeFolders $excluir

# =============================================================================
# PASO 3: DISEÑO XAML (WPF)
# =============================================================================
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="PowerShell Program Launcher" Height="850" Width="1350" WindowStartupLocation="CenterScreen"
        Background="#0F172A" FontFamily="Segoe UI">
    
    <Window.Resources>
        <!-- Estilos de botones base -->
        <Style TargetType="Button">
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}" CornerRadius="6" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Opacity" Value="0.8"/>
                </Trigger>
            </Style.Triggers>
        </Style>
    </Window.Resources>

    <Grid>
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="250" />
            <ColumnDefinition Width="*" />
            <ColumnDefinition Width="280" />
        </Grid.ColumnDefinitions>

        <!-- SIDEBAR IZQUIERDO -->
        <Border Grid.Column="0" Background="#1E293B">
            <StackPanel>
                <!-- Header Logo -->
                <StackPanel Orientation="Horizontal" Margin="20,25,20,20">
                    <TextBlock Text="▶" Foreground="#3B82F6" FontSize="26" FontWeight="Black" Margin="0,0,10,0"/>
                    <StackPanel>
                        <TextBlock Text="PowerShell" FontSize="16" FontWeight="Bold" Foreground="White" />
                        <TextBlock Text="Program Launcher" FontSize="12" Foreground="#94A3B8" />
                    </StackPanel>
                </StackPanel>
                
                <TextBlock Text="MENÚ PRINCIPAL" Foreground="#64748B" FontSize="11" FontWeight="Bold" Margin="20,10,20,10" />
                
                <ListBox x:Name="MenuCategories" Background="Transparent" BorderThickness="0" Foreground="White" Margin="10,0">
                    <ListBox.ItemContainerStyle>
                        <Style TargetType="ListBoxItem">
                            <Setter Property="Padding" Value="15,12" />
                            <Setter Property="Margin" Value="0,2" />
                            <Setter Property="Foreground" Value="#CBD5E1" />
                            <Setter Property="Cursor" Value="Hand" />
                            <Setter Property="Template">
                                <Setter.Value>
                                    <ControlTemplate TargetType="ListBoxItem">
                                        <Border Name="Border" Background="Transparent" CornerRadius="6" Margin="0">
                                            <ContentPresenter Margin="{TemplateBinding Padding}" />
                                        </Border>
                                        <ControlTemplate.Triggers>
                                            <Trigger Property="IsMouseOver" Value="True">
                                                <Setter TargetName="Border" Property="Background" Value="#334155"/>
                                            </Trigger>
                                            <Trigger Property="IsSelected" Value="True">
                                                <Setter TargetName="Border" Property="Background" Value="#1E40AF"/>
                                                <Setter Property="Foreground" Value="White" />
                                                <Setter Property="FontWeight" Value="SemiBold" />
                                            </Trigger>
                                        </ControlTemplate.Triggers>
                                    </ControlTemplate>
                                </Setter.Value>
                            </Setter>
                        </Style>
                    </ListBox.ItemContainerStyle>
                </ListBox>
            </StackPanel>
        </Border>

        <!-- CONTENIDO CENTRAL -->
        <Grid Grid.Column="1" Margin="30,20,30,20">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto" />
                <RowDefinition Height="*" />
            </Grid.RowDefinitions>

            <!-- Categorías (Tarjetas) -->
            <StackPanel Grid.Row="0">
                <TextBlock Text="CATEGORÍAS" Foreground="#94A3B8" FontSize="12" FontWeight="Bold" Margin="0,0,0,15" />
                <ScrollViewer HorizontalScrollBarVisibility="Auto" VerticalScrollBarVisibility="Disabled">
                    <StackPanel x:Name="TopCategoriesPanel" Orientation="Horizontal" />
                </ScrollViewer>
                
                <Grid Margin="0,30,0,15">
                    <TextBlock Text="PROGRAMAS DISPONIBLES" Foreground="#94A3B8" FontSize="12" FontWeight="Bold" VerticalAlignment="Center" />
                    <TextBox x:Name="TxtSearch" Width="250" Height="35" HorizontalAlignment="Right" VerticalAlignment="Center" Background="#1E293B" Foreground="White" BorderThickness="1" BorderBrush="#334155" Padding="10,6" />
                </Grid>
            </StackPanel>

            <!-- Lista de Programas (WrapPanel) -->
            <ListBox x:Name="ProgramList" Grid.Row="1" Background="Transparent" BorderThickness="0" ScrollViewer.HorizontalScrollBarVisibility="Disabled" SelectionMode="Multiple">
                <ListBox.ItemContainerStyle>
                    <Style TargetType="ListBoxItem">
                        <Setter Property="Template">
                            <Setter.Value>
                                <ControlTemplate TargetType="ListBoxItem">
                                    <Border Name="Bd" Background="#1E293B" CornerRadius="10" Margin="8" Width="160" Height="210" BorderBrush="#334155" BorderThickness="1">
                                        <Grid>
                                            <!-- Sombra y Layout -->
                                            <CheckBox Name="ChkSelect" IsChecked="{Binding Path=IsSelected, RelativeSource={RelativeSource TemplatedParent}}" Margin="10" HorizontalAlignment="Right" VerticalAlignment="Top" />
                                            <StackPanel Margin="10,25,10,10">
                                                <Image Source="{Binding IconPath}" Height="50" Width="50" Margin="0,0,0,15" />
                                                <!-- Fallback if no image -->
                                                <TextBlock Name="FallbackIcon" Text="[PKG]" FontSize="36" HorizontalAlignment="Center" Margin="0,0,0,15" Visibility="Collapsed" />
                                                
                                                <TextBlock Text="{Binding Nombre}" Foreground="White" TextAlignment="Center" TextWrapping="Wrap" Height="36" FontWeight="SemiBold" FontSize="13" />
                                                
                                                <Grid Margin="0,15,0,0">
                                                    <Grid.ColumnDefinitions>
                                                        <ColumnDefinition Width="*" />
                                                        <ColumnDefinition Width="35" />
                                                    </Grid.ColumnDefinitions>
                                                    <Button Name="BtnEjecutarItem" Grid.Column="0" Content="▶ Ejecutar" Background="#0284C7" Height="32" Margin="0,0,5,0" />
                                                    <Button Grid.Column="1" Content="i" Background="#334155" Height="32" CornerRadius="16" />
                                                </Grid>
                                            </StackPanel>
                                        </Grid>
                                    </Border>
                                    <ControlTemplate.Triggers>
                                        <DataTrigger Binding="{Binding IconPath}" Value="{x:Null}">
                                            <Setter TargetName="FallbackIcon" Property="Visibility" Value="Visible"/>
                                        </DataTrigger>
                                        <DataTrigger Binding="{Binding IconPath}" Value="">
                                            <Setter TargetName="FallbackIcon" Property="Visibility" Value="Visible"/>
                                        </DataTrigger>
                                        <Trigger Property="IsMouseOver" Value="True">
                                            <Setter TargetName="Bd" Property="Background" Value="#334155"/>
                                        </Trigger>
                                        <Trigger Property="IsSelected" Value="True">
                                            <Setter TargetName="Bd" Property="BorderBrush" Value="#38BDF8"/>
                                            <Setter TargetName="Bd" Property="BorderThickness" Value="2"/>
                                            <Setter TargetName="Bd" Property="Background" Value="#1E293B"/>
                                        </Trigger>
                                    </ControlTemplate.Triggers>
                                </ControlTemplate>
                            </Setter.Value>
                        </Setter>
                    </Style>
                </ListBox.ItemContainerStyle>
                <ListBox.ItemsPanel>
                    <ItemsPanelTemplate>
                        <WrapPanel />
                    </ItemsPanelTemplate>
                </ListBox.ItemsPanel>
            </ListBox>
        </Grid>

        <!-- SIDEBAR DERECHO -->
        <Border Grid.Column="2" Background="#111827" BorderThickness="1,0,0,0" BorderBrush="#1E293B">
            <StackPanel Margin="25">
                <TextBlock Text="ACCIÓN RÁPIDA" Foreground="#94A3B8" FontSize="12" FontWeight="Bold" Margin="0,0,0,20" />
                <Button x:Name="BtnEjecutarSel" Content="▶ Ejecutar Seleccionado" Background="#16A34A" Height="45" Margin="0,0,0,12" />
                <Button x:Name="BtnEjecutarTodo" Content="▶ Ejecutar Todo" Background="#2563EB" Height="45" Margin="0,0,0,12" />
                <Button x:Name="BtnActualizar" Content="↻ Actualizar Lista" Background="#9333EA" Height="45" Margin="0,0,0,12" />
                <Button x:Name="BtnAbrirCarpeta" Content="📁 Abrir Carpeta de Programas" Background="#EA580C" Height="45" Margin="0,0,0,30" />
                
                <TextBlock Text="INFORMACIÓN" Foreground="#94A3B8" FontSize="12" FontWeight="Bold" Margin="0,15,0,20" />
                
                <Grid Margin="0,0,0,15">
                    <TextBlock Text="Total de programas:" Foreground="#CBD5E1" />
                    <TextBlock x:Name="LblTotal" Text="0" Foreground="White" FontWeight="Bold" HorizontalAlignment="Right" />
                </Grid>
                <Grid Margin="0,0,0,15">
                    <TextBlock Text="Scripts disponibles:" Foreground="#CBD5E1" />
                    <TextBlock x:Name="LblScripts" Text="0" Foreground="White" FontWeight="Bold" HorizontalAlignment="Right" />
                </Grid>
                <Grid Margin="0,0,0,15">
                    <TextBlock Text="Última actualización:" Foreground="#CBD5E1" />
                    <TextBlock x:Name="LblUltimaAct" Text="-" Foreground="White" FontWeight="Bold" HorizontalAlignment="Right" />
                </Grid>
                <Grid Margin="0,0,0,15">
                    <TextBlock Text="Estado:" Foreground="#CBD5E1" />
                    <TextBlock Text="Listo" Foreground="#22C55E" FontWeight="Bold" HorizontalAlignment="Right" />
                </Grid>
            </StackPanel>
        </Border>
    </Grid>
</Window>
"@

$reader = (New-Object System.Xml.XmlNodeReader ([xml]$xaml))
$window = [System.Windows.Markup.XamlReader]::Load($reader)

# Map UI Controls
$MenuCategories = $window.FindName("MenuCategories")
$ProgramList = $window.FindName("ProgramList")
$TopCategoriesPanel = $window.FindName("TopCategoriesPanel")
$LblTotal = $window.FindName("LblTotal")
$LblScripts = $window.FindName("LblScripts")
$LblUltimaAct = $window.FindName("LblUltimaAct")

$BtnEjecutarSel = $window.FindName("BtnEjecutarSel")
$BtnEjecutarTodo = $window.FindName("BtnEjecutarTodo")
$BtnActualizar = $window.FindName("BtnActualizar")
$BtnAbrirCarpeta = $window.FindName("BtnAbrirCarpeta")
$TxtSearch = $window.FindName("TxtSearch")

# =============================================================================
# LOGICA DE LA APLICACIÓN
# =============================================================================
$script:CategoriaSeleccionada = "Inicio"

function Update-Listado {
    $LblTotal.Text = $script:ListaProgramas.Count.ToString()
    $LblScripts.Text = $script:ListaProgramas.Count.ToString()
    $LblUltimaAct.Text = (Get-Date).ToString("dd/MM/yyyy HH:mm")

    # Mapeo de Categorías
        $categoriasDetectadas = @()
    if ($script:ListaProgramas) {
        $categoriasDetectadas = $script:ListaProgramas | Select-Object -ExpandProperty Categoria -Unique | Sort-Object
    }
    
    $MenuCategories.Items.Clear()
    $null = $MenuCategories.Items.Add("[INI] Inicio")
    $null = $MenuCategories.Items.Add("[PKG] Todos")
    
    $TopCategoriesPanel.Children.Clear()

    foreach ($cat in $categoriasDetectadas) {
        $null = $MenuCategories.Items.Add("[DIR] $cat")
        
        $count = ($script:ListaProgramas | Where-Object Categoria -eq $cat).Count
        
        $cardStr = @"
        <Border xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation' Background='#1E293B' CornerRadius='8' Width='140' Height='100' Margin='0,0,15,0'>
            <StackPanel VerticalAlignment='Center'>
                <TextBlock Text='[DIR]' FontSize='30' HorizontalAlignment='Center' Margin='0,0,0,10' />
                <TextBlock Text='$cat' Foreground='White' FontWeight='SemiBold' HorizontalAlignment='Center' />
                <TextBlock Text='$count programas' Foreground='#94A3B8' FontSize='11' HorizontalAlignment='Center' Margin='0,5,0,0' />
            </StackPanel>
        </Border>
"@
        $card = [System.Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader ([xml]$cardStr)))
        $TopCategoriesPanel.Children.Add($card)
    }

    $MenuCategories.SelectedIndex = 0
}

Refrescar-Listado

$MenuCategories.Add_SelectionChanged({
    if ($MenuCategories.SelectedItem) {
        $sel = $MenuCategories.SelectedItem.ToString().Substring(3)
        $script:CategoriaSeleccionada = $sel
        
        if ($sel -eq "Inicio" -or $sel -eq "Todos") {
            $ProgramList.ItemsSource = $script:ListaProgramas
        } else {
            $filtrados = $script:ListaProgramas | Where-Object Categoria -eq $sel
            $ProgramList.ItemsSource = $filtrados
        }
    }
})

$BtnEjecutarSel.Add_Click({
    $seleccionados = @($ProgramList.SelectedItems)
    if ($seleccionados.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Selecciona al menos un programa.")
        return
    }
    
    $confirm = [System.Windows.Forms.MessageBox]::Show("¿Instalar $($seleccionados.Count) programa(s)?", "Confirmar", 4, 32)
    if ($confirm -eq "Yes") {
        $window.Hide()
        Start-InstallSequence -ProgramList $seleccionados -Silencioso $false -NoAdmin $NoAdmin -LogsFolder $script:LogsPath
        $window.ShowDialog() | Out-Null
    }
})

$BtnEjecutarTodo.Add_Click({
    $seleccionados = @($ProgramList.Items)
    if ($seleccionados.Count -eq 0) {
        return
    }
    
    $confirm = [System.Windows.Forms.MessageBox]::Show("¿Instalar TODOS los $($seleccionados.Count) programa(s)?", "Confirmar", 4, 32)
    if ($confirm -eq "Yes") {
        $window.Hide()
        Start-InstallSequence -ProgramList $seleccionados -Silencioso $false -NoAdmin $NoAdmin -LogsFolder $script:LogsPath
        $window.ShowDialog() | Out-Null
    }
})

$BtnActualizar.Add_Click({
    $script:ListaProgramas = Get-ProgramList -ProgramsFolder $script:ProgramsPath -CategoriesConfig $script:CatConfig -ExcludeFolders $excluir
    Update-Listado
    $ProgramList.ItemsSource = $script:ListaProgramas
})

$TxtSearch.Add_TextChanged({
    $texto = $TxtSearch.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($texto)) {
        $ProgramList.ItemsSource = $script:ListaProgramas
    } else {
        $filtrados = $script:ListaProgramas | Where-Object { $_.Nombre -match $texto }
        $ProgramList.ItemsSource = $filtrados
    }
})

$BtnAbrirCarpeta.Add_Click({
    Start-Process $script:ProgramsPath
})

$window.ShowDialog() | Out-Null




