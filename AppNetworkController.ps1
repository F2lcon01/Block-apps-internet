#Requires -Version 5.1
# ============================================================================
#  App Network Controller v2.5 - Production GUI
#  Controls which applications can access the network via Windows Firewall.
#  Requires: PowerShell 5.1+, Administrator privileges, Windows 10/11.
# ============================================================================

# === ADMIN ELEVATION (UAC prompt) ===
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell -ArgumentList @('-NoProfile','-STA','-ExecutionPolicy','Bypass','-WindowStyle','Hidden','-File',$PSCommandPath) -Verb RunAs
    exit
}

# === ENSURE STA MODE (required for WPF) ===
if ([Threading.Thread]::CurrentThread.GetApartmentState() -ne 'STA') {
    Start-Process powershell -ArgumentList @('-NoProfile','-STA','-ExecutionPolicy','Bypass','-WindowStyle','Hidden','-File',$PSCommandPath)
    exit
}

# === LOAD ASSEMBLIES ===
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

# === GLOBAL CONFIG ===
$script:RulePrefix       = "AppBlocker_"
$script:BaseDir          = "$env:LOCALAPPDATA\AppNetworkController"
$script:LogFile          = "$script:BaseDir\log.txt"
$script:FwPolicy         = New-Object -ComObject HNetCfg.FwPolicy2

$script:SystemWhitelist = @(
    'explorer','svchost','winlogon','services','lsass','csrss',
    'smss','wininit','dwm','conhost','System','Idle','Registry',
    'fontdrvhost','sihost','taskhostw','RuntimeBroker','SearchHost',
    'ShellExperienceHost','StartMenuExperienceHost','ctfmon',
    'SecurityHealthSystray','TextInputHost','dllhost','msiexec'
)

if (-not (Test-Path $script:BaseDir)) {
    New-Item -Path $script:BaseDir -ItemType Directory -Force | Out-Null
}

# ============================================================================
#                          CORE ENGINE FUNCTIONS
# ============================================================================

function Write-AppLog {
    param([string]$Message)
    try {
        $entry = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message"
        Add-Content -Path $script:LogFile -Value $entry -Encoding UTF8
    } catch { }
}

function Test-SystemProcess {
    param([string]$Name)
    try {
        $base = [System.IO.Path]::GetFileNameWithoutExtension($Name)
        return ($script:SystemWhitelist -contains $base)
    } catch { return $false }
}

function Get-BlockedNamesSet {
    $set = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    try {
        foreach ($rule in $script:FwPolicy.Rules) {
            if ($rule.Name -like "$($script:RulePrefix)*") {
                $name = ($rule.Name -replace [regex]::Escape($script:RulePrefix),'') -replace '_(IN|OUT)$',''
                if ($name) { $set.Add($name) | Out-Null }
            }
        }
    } catch {
        Write-AppLog "Get-BlockedNamesSet error: $_"
    }
    return $set
}

function Test-AppBlocked {
    param([string]$ProcessName)
    try {
        $base = [System.IO.Path]::GetFileNameWithoutExtension($ProcessName)
        $targetName = "$($script:RulePrefix)${base}_OUT"
        foreach ($rule in $script:FwPolicy.Rules) {
            if ($rule.Name -eq $targetName) { return $true }
        }
        return $false
    } catch { return $false }
}

function Get-RunningUserApps {
    try {
        $blockedSet = Get-BlockedNamesSet
        if ($null -eq $blockedSet) { $blockedSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase) }
        $procs = Get-Process | Where-Object {
            $_.Path -and
            $_.Path -ne '' -and
            $_.Path -notmatch '\\Windows\\System32\\' -and
            $_.Path -notmatch '\\Windows\\WinSxS\\' -and
            $_.Path -notmatch '\\Windows\\SystemApps\\' -and
            -not (Test-SystemProcess $_.ProcessName)
        } | Sort-Object ProcessName -Unique

        $list = [System.Collections.ArrayList]::new()
        foreach ($p in $procs) {
            [void]$list.Add([PSCustomObject]@{
                Name   = $p.ProcessName
                Path   = $p.Path
                Status = if ($blockedSet.Contains($p.ProcessName)) { "Blocked" } else { "Allowed" }
            })
        }
        return @($list)
    } catch {
        Write-AppLog "Get-RunningUserApps error: $_"
        return @()
    }
}

function Get-InstalledApps {
    try {
        $blockedSet = Get-BlockedNamesSet
        if ($null -eq $blockedSet) { $blockedSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase) }
        $regPaths = @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
            'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
        )
        $seen = @{}
        $list = [System.Collections.ArrayList]::new()
        foreach ($rp in $regPaths) {
            $entries = Get-ItemProperty -Path $rp -ErrorAction SilentlyContinue
            foreach ($e in $entries) {
                if (-not $e.DisplayName) { continue }
                $exePath = $null

                if ($e.DisplayIcon) {
                    $iconPath = ($e.DisplayIcon -split ',')[0].Trim().Trim('"')
                    if ($iconPath -match '\.exe$' -and (Test-Path $iconPath -ErrorAction SilentlyContinue)) {
                        $exePath = $iconPath
                    }
                }
                if (-not $exePath -and $e.InstallLocation) {
                    $dir = $e.InstallLocation.Trim().Trim('"')
                    if ($dir -and (Test-Path $dir -ErrorAction SilentlyContinue)) {
                        $exe = Get-ChildItem $dir -Filter '*.exe' -Depth 1 -File -ErrorAction SilentlyContinue | Select-Object -First 1
                        if ($exe) { $exePath = $exe.FullName }
                    }
                }
                if (-not $exePath) { continue }

                $key = $exePath.ToLower()
                if ($seen.ContainsKey($key)) { continue }
                $seen[$key] = $true

                $procName = [System.IO.Path]::GetFileNameWithoutExtension($exePath)
                [void]$list.Add([PSCustomObject]@{
                    Name      = $e.DisplayName
                    Path      = $exePath
                    Publisher = if ($e.Publisher) { $e.Publisher } else { "Unknown" }
                    Status    = if ($blockedSet.Contains($procName)) { "Blocked" } else { "Allowed" }
                })
            }
        }
        return @($list)
    } catch {
        Write-AppLog "Get-InstalledApps error: $_"
        return @()
    }
}

function Get-BlockedAppsList {
    try {
        $results = [System.Collections.ArrayList]::new()
        foreach ($rule in $script:FwPolicy.Rules) {
            if ($rule.Name -like "$($script:RulePrefix)*") {
                $friendly = ($rule.Name -replace [regex]::Escape($script:RulePrefix),'') -replace '_(IN|OUT)$',''
                $dir = if ($rule.Direction -eq 2) { "Outbound" } else { "Inbound" }
                [void]$results.Add([PSCustomObject]@{
                    Name = $friendly; Path = $rule.ApplicationName
                    Direction = $dir; RuleName = $rule.Name
                })
            }
        }
        return @($results)
    } catch {
        Write-AppLog "Get-BlockedAppsList error: $_"
        return @()
    }
}

function Block-Application {
    param([string]$Name, [string]$Path)
    try {
        if (Test-SystemProcess $Name) {
            return [PSCustomObject]@{ Success=$false; Message="'$Name' is a protected system process." }
        }
        $resolved = [System.Environment]::ExpandEnvironmentVariables($Path)
        if (-not (Test-Path $resolved)) {
            return [PSCustomObject]@{ Success=$false; Message="Path not found: $resolved" }
        }
        if ([System.IO.Path]::GetExtension($resolved).ToLower() -ne '.exe') {
            return [PSCustomObject]@{ Success=$false; Message="Only .exe files can be blocked." }
        }
        $base = [System.IO.Path]::GetFileNameWithoutExtension($Name)
        if (Test-AppBlocked $base) {
            return [PSCustomObject]@{ Success=$false; Message="'$base' is already blocked." }
        }
        $full = (Resolve-Path $resolved).Path
        New-NetFirewallRule -DisplayName "$($script:RulePrefix)${base}_OUT" -Direction Outbound -Action Block -Program $full -Profile Any -Enabled True -ErrorAction Stop | Out-Null
        New-NetFirewallRule -DisplayName "$($script:RulePrefix)${base}_IN"  -Direction Inbound  -Action Block -Program $full -Profile Any -Enabled True -ErrorAction Stop | Out-Null
        Write-AppLog "BLOCKED | $base | $full"
        return [PSCustomObject]@{ Success=$true; Message="Blocked '$base' (inbound + outbound)." }
    } catch {
        Write-AppLog "Block-Application error: $_"
        return [PSCustomObject]@{ Success=$false; Message="Failed to block '$Name': $_" }
    }
}

function Unblock-Application {
    param([string]$Name)
    try {
        $base = [System.IO.Path]::GetFileNameWithoutExtension($Name)
        $removed = 0
        try {
            Remove-NetFirewallRule -DisplayName "$($script:RulePrefix)${base}_OUT" -ErrorAction Stop
            $removed++
        } catch { }
        try {
            Remove-NetFirewallRule -DisplayName "$($script:RulePrefix)${base}_IN" -ErrorAction Stop
            $removed++
        } catch { }
        if ($removed -eq 0) {
            return [PSCustomObject]@{ Success=$false; Message="No rules found for '$base'." }
        }
        Write-AppLog "UNBLOCKED | $base | $removed rules"
        return [PSCustomObject]@{ Success=$true; Message="Unblocked '$base' ($removed rules removed)." }
    } catch {
        Write-AppLog "Unblock-Application error: $_"
        return [PSCustomObject]@{ Success=$false; Message="Failed to unblock '$Name': $_" }
    }
}


function Export-FirewallRules {
    param([string]$FilePath)
    try {
        $list = Get-BlockedAppsList
        if ($list.Count -eq 0) {
            return [PSCustomObject]@{ Success=$false; Message="No rules to export." }
        }
        $parentDir = Split-Path $FilePath -Parent
        if ($parentDir -and -not (Test-Path $parentDir)) {
            New-Item $parentDir -ItemType Directory -Force | Out-Null
        }
        @{
            ExportDate = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
            RulePrefix = $script:RulePrefix
            Rules = @($list | ForEach-Object { @{ Name=$_.Name; Path=$_.Path; Direction=$_.Direction; RuleName=$_.RuleName } })
        } | ConvertTo-Json -Depth 4 | Set-Content $FilePath -Encoding UTF8 -Force
        Write-AppLog "EXPORTED | $($list.Count) rules to $FilePath"
        return [PSCustomObject]@{ Success=$true; Message="Exported $($list.Count) rules." }
    } catch {
        Write-AppLog "Export error: $_"
        return [PSCustomObject]@{ Success=$false; Message="Export failed: $_" }
    }
}

function Import-FirewallRules {
    param([string]$FilePath)
    try {
        if (-not (Test-Path $FilePath)) {
            return [PSCustomObject]@{ Success=$false; Message="File not found: $FilePath" }
        }
        $json = Get-Content $FilePath -Raw -Encoding UTF8 | ConvertFrom-Json
        if (-not $json.Rules -or $json.Rules.Count -eq 0) {
            return [PSCustomObject]@{ Success=$false; Message="No rules in file." }
        }
        $apps = @{}
        foreach ($rule in $json.Rules) {
            if (-not $apps.ContainsKey($rule.Name)) { $apps[$rule.Name] = $rule.Path }
        }
        $imported = 0; $skipped = 0
        foreach ($name in $apps.Keys) {
            $path = $apps[$name]
            if (-not $path -or $path -eq 'Unknown' -or -not (Test-Path $path -ErrorAction SilentlyContinue)) { $skipped++; continue }
            if (Test-AppBlocked $name) { $skipped++; continue }
            $r = Block-Application -Name $name -Path $path
            if ($r.Success) { $imported++ } else { $skipped++ }
        }
        Write-AppLog "IMPORTED | $imported apps, $skipped skipped from $FilePath"
        return [PSCustomObject]@{ Success=$true; Message="Imported $imported apps, skipped $skipped." }
    } catch {
        Write-AppLog "Import error: $_"
        return [PSCustomObject]@{ Success=$false; Message="Import failed: $_" }
    }
}

function Get-AppLog {
    try {
        if (-not (Test-Path $script:LogFile)) { return "No log entries yet." }
        $content = Get-Content $script:LogFile -Raw -Encoding UTF8
        if ([string]::IsNullOrWhiteSpace($content)) { return "Log is empty." }
        return $content
    } catch { return "Error reading log: $_" }
}

function Clear-AppLog {
    try {
        if (Test-Path $script:LogFile) {
            Set-Content $script:LogFile -Value "" -Encoding UTF8 -Force
            Write-AppLog "Log cleared by user."
        }
    } catch { }
}

Write-AppLog "=== App Network Controller v2.5 started ==="

# ============================================================================
#                              WPF GUI (XAML)
# ============================================================================

[xml]$xaml = @"
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="App Network Controller v2.5"
    Width="960" Height="680"
    MinWidth="820" MinHeight="600"
    WindowStartupLocation="CenterScreen"
    Background="#1A1A2E"
    Foreground="#E0E0E0">

    <Window.Resources>
        <Style x:Key="BaseButton" TargetType="Button">
            <Setter Property="Background" Value="#0F3460"/>
            <Setter Property="Foreground" Value="#E0E0E0"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="Padding" Value="14,7"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="bd" Background="{TemplateBinding Background}" CornerRadius="5" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="bd" Property="Background" Value="#533483"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="bd" Property="Background" Value="#3A1F6E"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter Property="Opacity" Value="0.45"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="DangerButton" TargetType="Button" BasedOn="{StaticResource BaseButton}">
            <Setter Property="Background" Value="#E53935"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="bd" Background="{TemplateBinding Background}" CornerRadius="5" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="bd" Property="Background" Value="#C62828"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="bd" Property="Background" Value="#B71C1C"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="SuccessButton" TargetType="Button" BasedOn="{StaticResource BaseButton}">
            <Setter Property="Background" Value="#4CAF50"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="bd" Background="{TemplateBinding Background}" CornerRadius="5" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="bd" Property="Background" Value="#388E3C"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="bd" Property="Background" Value="#2E7D32"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="NavButton" TargetType="Button">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Foreground" Value="#9E9E9E"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="Height" Value="45"/>
            <Setter Property="HorizontalContentAlignment" Value="Left"/>
            <Setter Property="Padding" Value="18,0,0,0"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="bd" Background="{TemplateBinding Background}" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Left" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="bd" Property="Background" Value="#0F3460"/>
                                <Setter Property="Foreground" Value="#E0E0E0"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="NavButtonActive" TargetType="Button">
            <Setter Property="Background" Value="#0F3460"/>
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Height" Value="45"/>
            <Setter Property="HorizontalContentAlignment" Value="Left"/>
            <Setter Property="Padding" Value="18,0,0,0"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}" Padding="{TemplateBinding Padding}"
                                BorderBrush="#533483" BorderThickness="3,0,0,0">
                            <ContentPresenter HorizontalAlignment="Left" VerticalAlignment="Center"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="DarkTextBox" TargetType="TextBox">
            <Setter Property="Background" Value="#16213E"/>
            <Setter Property="Foreground" Value="#E0E0E0"/>
            <Setter Property="BorderBrush" Value="#2A2A4A"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="8,5"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="CaretBrush" Value="#E0E0E0"/>
        </Style>

        <Style x:Key="DarkDataGrid" TargetType="DataGrid">
            <Setter Property="Background" Value="#16213E"/>
            <Setter Property="Foreground" Value="#E0E0E0"/>
            <Setter Property="BorderBrush" Value="#2A2A4A"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="RowBackground" Value="#16213E"/>
            <Setter Property="AlternatingRowBackground" Value="#1A1A2E"/>
            <Setter Property="GridLinesVisibility" Value="None"/>
            <Setter Property="HeadersVisibility" Value="Column"/>
            <Setter Property="AutoGenerateColumns" Value="False"/>
            <Setter Property="IsReadOnly" Value="True"/>
            <Setter Property="SelectionMode" Value="Single"/>
            <Setter Property="CanUserAddRows" Value="False"/>
            <Setter Property="CanUserDeleteRows" Value="False"/>
            <Setter Property="FontSize" Value="12.5"/>
            <Setter Property="RowHeight" Value="36"/>
            <Setter Property="ColumnHeaderHeight" Value="38"/>
            <Setter Property="VirtualizingPanel.IsVirtualizing" Value="True"/>
            <Setter Property="VirtualizingPanel.VirtualizationMode" Value="Recycling"/>
            <Setter Property="EnableColumnVirtualization" Value="True"/>
            <Setter Property="EnableRowVirtualization" Value="True"/>
        </Style>

        <Style TargetType="DataGridColumnHeader">
            <Setter Property="Background" Value="#0F3460"/>
            <Setter Property="Foreground" Value="#E0E0E0"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Padding" Value="10,6"/>
            <Setter Property="BorderBrush" Value="#2A2A4A"/>
            <Setter Property="BorderThickness" Value="0,0,1,1"/>
        </Style>

        <Style TargetType="DataGridRow">
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#0F3460"/>
                </Trigger>
                <Trigger Property="IsSelected" Value="True">
                    <Setter Property="Background" Value="#533483"/>
                </Trigger>
            </Style.Triggers>
        </Style>

        <Style TargetType="DataGridCell">
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Padding" Value="8,4"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="DataGridCell">
                        <Border Background="{TemplateBinding Background}" Padding="{TemplateBinding Padding}">
                            <ContentPresenter VerticalAlignment="Center"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
            <Style.Triggers>
                <Trigger Property="IsSelected" Value="True">
                    <Setter Property="Background" Value="Transparent"/>
                    <Setter Property="Foreground" Value="#E0E0E0"/>
                </Trigger>
            </Style.Triggers>
        </Style>
    </Window.Resources>

    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="56"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="32"/>
        </Grid.RowDefinitions>

        <!-- HEADER -->
        <Border Grid.Row="0" Background="#16213E" BorderBrush="#2A2A4A" BorderThickness="0,0,0,1">
            <Grid Margin="16,0">
                <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                    <TextBlock Text="App Network Controller" FontSize="20" FontWeight="Bold" Foreground="#E0E0E0" VerticalAlignment="Center"/>
                    <TextBlock Text="v2.5" FontSize="12" Foreground="#9E9E9E" VerticalAlignment="Center" Margin="10,4,0,0"/>
                </StackPanel>
                <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Center">
                    <Ellipse x:Name="statusDot" Width="10" Height="10" Fill="#4CAF50" Margin="0,0,8,0"/>
                    <TextBlock x:Name="txtHeaderStatus" Text="Ready" FontSize="12" Foreground="#9E9E9E" VerticalAlignment="Center"/>
                </StackPanel>
            </Grid>
        </Border>

        <!-- MAIN -->
        <Grid Grid.Row="1">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="200"/>
                <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>

            <!-- SIDEBAR -->
            <Border Grid.Column="0" Background="#16213E" BorderBrush="#2A2A4A" BorderThickness="0,0,1,0">
                <StackPanel Margin="0,8,0,0">
                    <Button x:Name="navRunning"   Content="Running Apps"   Style="{StaticResource NavButtonActive}"/>
                    <Button x:Name="navInstalled"  Content="Installed Apps" Style="{StaticResource NavButton}"/>
                    <Button x:Name="navBlocked"    Content="Blocked Apps"   Style="{StaticResource NavButton}"/>
                    <Button x:Name="navBlockPath"  Content="Block by Path"  Style="{StaticResource NavButton}"/>
                    <Button x:Name="navLogs"       Content="Logs"           Style="{StaticResource NavButton}"/>
                    <Button x:Name="navSettings"   Content="Settings"       Style="{StaticResource NavButton}"/>
                </StackPanel>
            </Border>

            <!-- CONTENT -->
            <Grid Grid.Column="1" Margin="16,12">

                <!-- TAB 1: RUNNING APPS -->
                <Grid x:Name="panelRunning" Visibility="Visible">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>
                    <StackPanel Orientation="Horizontal" Margin="0,0,0,10">
                        <Button x:Name="btnRefreshRunning" Content="Refresh" Style="{StaticResource BaseButton}" Margin="0,0,10,0"/>
                        <Button x:Name="btnBlockAllNonSystem" Content="Block All Non-System" Style="{StaticResource DangerButton}" Margin="0,0,10,0"/>
                        <TextBox x:Name="txtSearchRunning" Style="{StaticResource DarkTextBox}" Width="260"/>
                        <TextBlock Text="  Type to search..." Foreground="#666" FontSize="12" VerticalAlignment="Center" IsHitTestVisible="False" x:Name="phRunning"/>
                    </StackPanel>
                    <DataGrid x:Name="dgRunning" Grid.Row="1" Style="{StaticResource DarkDataGrid}">
                        <DataGrid.Columns>
                            <DataGridTextColumn Header="Name" Binding="{Binding Name}" Width="180"/>
                            <DataGridTextColumn Header="Path" Binding="{Binding Path}" Width="*"/>
                            <DataGridTextColumn Header="Status" Binding="{Binding Status}" Width="80"/>
                        </DataGrid.Columns>
                    </DataGrid>
                </Grid>

                <!-- TAB 2: INSTALLED APPS -->
                <Grid x:Name="panelInstalled" Visibility="Collapsed">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>
                    <StackPanel Orientation="Horizontal" Margin="0,0,0,10">
                        <Button x:Name="btnScanInstalled" Content="Scan" Style="{StaticResource BaseButton}" Margin="0,0,10,0"/>
                        <TextBox x:Name="txtSearchInstalled" Style="{StaticResource DarkTextBox}" Width="260"/>
                        <TextBlock Text="  Type to search..." Foreground="#666" FontSize="12" VerticalAlignment="Center" IsHitTestVisible="False" x:Name="phInstalled"/>
                    </StackPanel>
                    <DataGrid x:Name="dgInstalled" Grid.Row="1" Style="{StaticResource DarkDataGrid}">
                        <DataGrid.Columns>
                            <DataGridTextColumn Header="Name" Binding="{Binding Name}" Width="200"/>
                            <DataGridTextColumn Header="Path" Binding="{Binding Path}" Width="*"/>
                            <DataGridTextColumn Header="Publisher" Binding="{Binding Publisher}" Width="140"/>
                            <DataGridTextColumn Header="Status" Binding="{Binding Status}" Width="80"/>
                        </DataGrid.Columns>
                    </DataGrid>
                </Grid>

                <!-- TAB 3: BLOCKED APPS -->
                <Grid x:Name="panelBlocked" Visibility="Collapsed">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>
                    <WrapPanel Margin="0,0,0,10">
                        <Button x:Name="btnRefreshBlocked" Content="Refresh" Style="{StaticResource BaseButton}" Margin="0,0,10,4"/>
                        <Button x:Name="btnUnblockAll" Content="Unblock All" Style="{StaticResource SuccessButton}" Margin="0,0,10,4"/>
                        <Button x:Name="btnExportRules" Content="Export" Style="{StaticResource BaseButton}" Margin="0,0,10,4"/>
                        <Button x:Name="btnImportRules" Content="Import" Style="{StaticResource BaseButton}" Margin="0,0,0,4"/>
                    </WrapPanel>
                    <DataGrid x:Name="dgBlocked" Grid.Row="1" Style="{StaticResource DarkDataGrid}">
                        <DataGrid.Columns>
                            <DataGridTextColumn Header="Name" Binding="{Binding Name}" Width="180"/>
                            <DataGridTextColumn Header="Path" Binding="{Binding Path}" Width="*"/>
                            <DataGridTextColumn Header="Direction" Binding="{Binding Direction}" Width="90"/>
                            <DataGridTextColumn Header="Rule" Binding="{Binding RuleName}" Width="180"/>
                        </DataGrid.Columns>
                    </DataGrid>
                </Grid>

                <!-- TAB 4: BLOCK BY PATH -->
                <Grid x:Name="panelBlockPath" Visibility="Collapsed">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>
                    <Border Background="#16213E" CornerRadius="8" Padding="24" Margin="0,20,0,16" HorizontalAlignment="Center" VerticalAlignment="Top" MinWidth="560">
                        <StackPanel>
                            <TextBlock Text="Block Application by Path" FontSize="18" FontWeight="SemiBold" Foreground="#E0E0E0" Margin="0,0,0,16"/>
                            <TextBlock Text="Executable Path:" Foreground="#9E9E9E" FontSize="12" Margin="0,0,0,4"/>
                            <StackPanel Orientation="Horizontal" Margin="0,0,0,12">
                                <TextBox x:Name="txtBlockPath" Style="{StaticResource DarkTextBox}" Width="400" Margin="0,0,10,0"/>
                                <Button x:Name="btnBrowsePath" Content="Browse..." Style="{StaticResource BaseButton}"/>
                            </StackPanel>
                            <TextBlock Text="Detected Name:" Foreground="#9E9E9E" FontSize="12" Margin="0,0,0,4"/>
                            <TextBlock x:Name="txtDetectedName" Text="(select a file)" Foreground="#E0E0E0" FontSize="14" Margin="0,0,0,16"/>
                            <Button x:Name="btnBlockByPath" Content="Block This Application" Style="{StaticResource DangerButton}" FontSize="15" Padding="20,10" HorizontalAlignment="Left"/>
                        </StackPanel>
                    </Border>
                    <StackPanel Grid.Row="1" Margin="0,4,0,0">
                        <TextBlock Text="Recent Blocks" FontSize="14" FontWeight="SemiBold" Foreground="#9E9E9E" Margin="0,0,0,8"/>
                        <DataGrid x:Name="dgRecentBlocks" Style="{StaticResource DarkDataGrid}" MaxHeight="260">
                            <DataGrid.Columns>
                                <DataGridTextColumn Header="Name" Binding="{Binding Name}" Width="*"/>
                                <DataGridTextColumn Header="Path" Binding="{Binding Path}" Width="2*"/>
                            </DataGrid.Columns>
                        </DataGrid>
                    </StackPanel>
                </Grid>

                <!-- TAB 5: LOGS -->
                <Grid x:Name="panelLogs" Visibility="Collapsed">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>
                    <StackPanel Orientation="Horizontal" Margin="0,0,0,10">
                        <Button x:Name="btnRefreshLogs" Content="Refresh Logs" Style="{StaticResource BaseButton}" Margin="0,0,10,0"/>
                        <Button x:Name="btnClearLogs" Content="Clear Log" Style="{StaticResource DangerButton}"/>
                    </StackPanel>
                    <TextBox x:Name="txtLogContent" Grid.Row="1" Style="{StaticResource DarkTextBox}"
                             FontFamily="Consolas" FontSize="12" IsReadOnly="True"
                             VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto"
                             AcceptsReturn="True" TextWrapping="NoWrap"/>
                </Grid>

                <!-- TAB 7: SETTINGS -->
                <Grid x:Name="panelSettings" Visibility="Collapsed">
                    <ScrollViewer VerticalScrollBarVisibility="Auto">
                        <StackPanel Margin="0,4,0,0">
                            <Border Background="#16213E" CornerRadius="8" Padding="20" Margin="0,0,0,16">
                                <StackPanel>
                                    <TextBlock Text="Export / Import Firewall Rules" FontSize="16" FontWeight="SemiBold" Foreground="#E0E0E0" Margin="0,0,0,12"/>
                                    <StackPanel Orientation="Horizontal">
                                        <Button x:Name="btnSettingsExport" Content="Export Rules" Style="{StaticResource BaseButton}" Margin="0,0,10,0"/>
                                        <Button x:Name="btnSettingsImport" Content="Import Rules" Style="{StaticResource BaseButton}"/>
                                    </StackPanel>
                                </StackPanel>
                            </Border>
                            <Border Background="#16213E" CornerRadius="8" Padding="20" Margin="0,0,0,16">
                                <StackPanel>
                                    <TextBlock Text="Protected System Processes" FontSize="16" FontWeight="SemiBold" Foreground="#E0E0E0" Margin="0,0,0,8"/>
                                    <TextBlock Text="These processes cannot be blocked:" Foreground="#9E9E9E" FontSize="12" Margin="0,0,0,8"/>
                                    <TextBox x:Name="txtWhitelist" Style="{StaticResource DarkTextBox}" IsReadOnly="True" AcceptsReturn="True" TextWrapping="Wrap" MaxHeight="160" VerticalScrollBarVisibility="Auto"/>
                                </StackPanel>
                            </Border>
                            <Border Background="#16213E" CornerRadius="8" Padding="20">
                                <StackPanel>
                                    <TextBlock Text="About" FontSize="16" FontWeight="SemiBold" Foreground="#E0E0E0" Margin="0,0,0,8"/>
                                    <TextBlock Foreground="#9E9E9E" FontSize="12" TextWrapping="Wrap">
                                        <Run Text="App Network Controller v2.5" FontWeight="SemiBold" Foreground="#E0E0E0"/><LineBreak/>
                                        <Run Text="Control which applications can access the network via Windows Firewall."/><LineBreak/><LineBreak/>
                                        <Run Text="Features: Block/Unblock apps, installed app scanning, rule export/import, logging."/><LineBreak/>
                                        <Run Text="Requires: PowerShell 5.1+, Administrator privileges, Windows 10/11."/>
                                    </TextBlock>
                                </StackPanel>
                            </Border>
                        </StackPanel>
                    </ScrollViewer>
                </Grid>

            </Grid>
        </Grid>

        <!-- STATUS BAR -->
        <Border Grid.Row="2" Background="#16213E" BorderBrush="#2A2A4A" BorderThickness="0,1,0,0">
            <Grid Margin="12,0">
                <TextBlock x:Name="txtStatusBar" Text="Ready" FontSize="11" Foreground="#9E9E9E" VerticalAlignment="Center"/>
                <TextBlock x:Name="txtStatusTime" Text="" FontSize="11" Foreground="#9E9E9E" VerticalAlignment="Center" HorizontalAlignment="Right"/>
            </Grid>
        </Border>
    </Grid>
</Window>
"@

# ============================================================================
#                          CREATE WINDOW + FIND CONTROLS
# ============================================================================

$reader = [System.Xml.XmlNodeReader]::new($xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

# Navigation
$navRunning   = $window.FindName('navRunning')
$navInstalled = $window.FindName('navInstalled')
$navBlocked   = $window.FindName('navBlocked')
$navBlockPath = $window.FindName('navBlockPath')
$navLogs      = $window.FindName('navLogs')
$navSettings  = $window.FindName('navSettings')

# Panels
$panelRunning   = $window.FindName('panelRunning')
$panelInstalled = $window.FindName('panelInstalled')
$panelBlocked   = $window.FindName('panelBlocked')
$panelBlockPath = $window.FindName('panelBlockPath')
$panelLogs      = $window.FindName('panelLogs')
$panelSettings  = $window.FindName('panelSettings')

# Controls
$btnRefreshRunning    = $window.FindName('btnRefreshRunning')
$btnBlockAllNonSystem = $window.FindName('btnBlockAllNonSystem')
$txtSearchRunning     = $window.FindName('txtSearchRunning')
$phRunning            = $window.FindName('phRunning')
$dgRunning            = $window.FindName('dgRunning')

$btnScanInstalled   = $window.FindName('btnScanInstalled')
$txtSearchInstalled = $window.FindName('txtSearchInstalled')
$phInstalled        = $window.FindName('phInstalled')
$dgInstalled        = $window.FindName('dgInstalled')

$btnRefreshBlocked  = $window.FindName('btnRefreshBlocked')
$btnUnblockAll      = $window.FindName('btnUnblockAll')
$btnExportRules     = $window.FindName('btnExportRules')
$btnImportRules     = $window.FindName('btnImportRules')
$dgBlocked          = $window.FindName('dgBlocked')

$txtBlockPath       = $window.FindName('txtBlockPath')
$btnBrowsePath      = $window.FindName('btnBrowsePath')
$txtDetectedName    = $window.FindName('txtDetectedName')
$btnBlockByPath     = $window.FindName('btnBlockByPath')
$dgRecentBlocks     = $window.FindName('dgRecentBlocks')

$btnRefreshLogs     = $window.FindName('btnRefreshLogs')
$btnClearLogs       = $window.FindName('btnClearLogs')
$txtLogContent      = $window.FindName('txtLogContent')

$btnSettingsExport  = $window.FindName('btnSettingsExport')
$btnSettingsImport  = $window.FindName('btnSettingsImport')
$txtWhitelist       = $window.FindName('txtWhitelist')

$txtStatusBar       = $window.FindName('txtStatusBar')
$txtStatusTime      = $window.FindName('txtStatusTime')
$txtHeaderStatus    = $window.FindName('txtHeaderStatus')
$statusDot          = $window.FindName('statusDot')

# ============================================================================
#                          GUI STATE + HELPERS
# ============================================================================

$script:allRunningApps   = @()
$script:allInstalledApps = @()
$script:recentBlocks     = [System.Collections.ArrayList]::new()

function Update-StatusBar {
    param([string]$Message)
    $txtStatusBar.Text    = $Message
    $txtStatusTime.Text   = (Get-Date -Format 'HH:mm:ss')
    $txtHeaderStatus.Text = $Message
}

function Set-ActiveNav {
    param([System.Windows.Controls.Button]$Active)
    $navs   = @($navRunning,$navInstalled,$navBlocked,$navBlockPath,$navLogs,$navSettings)
    $panels = @($panelRunning,$panelInstalled,$panelBlocked,$panelBlockPath,$panelLogs,$panelSettings)
    $activeS  = $window.FindResource('NavButtonActive')
    $defaultS = $window.FindResource('NavButton')
    for ($i = 0; $i -lt $navs.Count; $i++) {
        if ($navs[$i] -eq $Active) {
            $navs[$i].Style = $activeS
            $panels[$i].Visibility = 'Visible'
        } else {
            $navs[$i].Style = $defaultS
            $panels[$i].Visibility = 'Collapsed'
        }
    }
}

function Refresh-RunningApps {
    Update-StatusBar "Loading running apps..."
    $script:allRunningApps = @(Get-RunningUserApps)
    $dgRunning.ItemsSource = $script:allRunningApps
    Update-StatusBar "Running apps: $($script:allRunningApps.Count) found"
}

function Refresh-InstalledApps {
    Update-StatusBar "Scanning installed apps (may take a moment)..."
    $window.Cursor = [System.Windows.Input.Cursors]::Wait
    $btnScanInstalled.IsEnabled = $false
    try {
        $script:allInstalledApps = @(Get-InstalledApps)
        $dgInstalled.ItemsSource = $script:allInstalledApps
        Update-StatusBar "Installed apps: $($script:allInstalledApps.Count) found"
    } finally {
        $window.Cursor = $null
        $btnScanInstalled.IsEnabled = $true
    }
}

function Refresh-BlockedApps {
    $list = @(Get-BlockedAppsList)
    $dgBlocked.ItemsSource = $list
    Update-StatusBar "Blocked rules: $($list.Count)"
}

function Filter-DataGrid {
    param([string]$Text, [array]$Source, [System.Windows.Controls.DataGrid]$Grid)
    if ([string]::IsNullOrWhiteSpace($Text)) {
        $Grid.ItemsSource = $Source
    } else {
        $escaped = [regex]::Escape($Text)
        $Grid.ItemsSource = @($Source | Where-Object { $_.Name -match $escaped -or $_.Path -match $escaped })
    }
}

function Show-ExportDialog {
    $dlg = New-Object System.Windows.Forms.SaveFileDialog
    $dlg.Filter   = 'JSON Files (*.json)|*.json'
    $dlg.Title    = 'Export Firewall Rules'
    $dlg.FileName = "firewall-rules-$(Get-Date -Format 'yyyyMMdd').json"
    if ($dlg.ShowDialog() -eq 'OK') {
        $r = Export-FirewallRules -FilePath $dlg.FileName
        Update-StatusBar $r.Message
    }
}

function Show-ImportDialog {
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Filter = 'JSON Files (*.json)|*.json'
    $dlg.Title  = 'Import Firewall Rules'
    if ($dlg.ShowDialog() -eq 'OK') {
        $r = Import-FirewallRules -FilePath $dlg.FileName
        Update-StatusBar $r.Message
        Refresh-BlockedApps
    }
}

function Handle-ToggleApp {
    param($App, [string]$RefreshType)
    if ($null -eq $App) { return }
    if ($App.Status -eq 'Blocked') {
        $r = Unblock-Application -Name $App.Name
    } else {
        $r = Block-Application -Name $App.Name -Path $App.Path
    }
    if ($r.Success) {
        Update-StatusBar $r.Message
    } else {
        Update-StatusBar "Failed: $($r.Message)"
        [System.Windows.MessageBox]::Show($r.Message, 'Operation Failed', 'OK', 'Warning')
    }
    switch ($RefreshType) {
        'running'   { Refresh-RunningApps }
        'installed' { Refresh-InstalledApps }
        'blocked'   { Refresh-BlockedApps }
    }
}

# ============================================================================
#                            EVENT HANDLERS
# ============================================================================

# --- Navigation ---
$navRunning.Add_Click({   Set-ActiveNav $navRunning;   Refresh-RunningApps })
$navInstalled.Add_Click({ Set-ActiveNav $navInstalled; if ($script:allInstalledApps.Count -eq 0) { Refresh-InstalledApps } })
$navBlocked.Add_Click({   Set-ActiveNav $navBlocked;   Refresh-BlockedApps })
$navBlockPath.Add_Click({ Set-ActiveNav $navBlockPath })
$navLogs.Add_Click({
    Set-ActiveNav $navLogs
    $txtLogContent.Text = Get-AppLog
    $txtLogContent.ScrollToEnd()
    Update-StatusBar 'Logs loaded'
})
$navSettings.Add_Click({
    Set-ActiveNav $navSettings
    $txtWhitelist.Text = ($script:SystemWhitelist | Sort-Object) -join "`r`n"
})

# --- Running Apps ---
$btnRefreshRunning.Add_Click({ Refresh-RunningApps })

$btnBlockAllNonSystem.Add_Click({
    $apps = @($script:allRunningApps | Where-Object { $_.Status -eq 'Allowed' })
    if ($apps.Count -eq 0) {
        [System.Windows.MessageBox]::Show('No non-system apps to block (all are already blocked or none found).','Nothing to Block','OK','Information')
        return
    }
    $ans = [System.Windows.MessageBox]::Show("Block all $($apps.Count) non-system running application(s)?`nThis will create firewall rules for each one.",'Confirm Block All',[System.Windows.MessageBoxButton]::YesNo,[System.Windows.MessageBoxImage]::Warning)
    if ($ans -eq 'Yes') {
        $window.Cursor = [System.Windows.Input.Cursors]::Wait
        $btnBlockAllNonSystem.IsEnabled = $false
        try {
            $blocked = 0; $failed = 0
            foreach ($app in $apps) {
                $r = Block-Application -Name $app.Name -Path $app.Path
                if ($r.Success) { $blocked++ } else { $failed++ }
            }
            Update-StatusBar "Blocked $blocked app(s), $failed failed"
            Refresh-RunningApps
        } finally {
            $window.Cursor = $null
            $btnBlockAllNonSystem.IsEnabled = $true
        }
    }
})

$txtSearchRunning.Add_TextChanged({
    $phRunning.Visibility = if ($txtSearchRunning.Text.Length -gt 0) { 'Collapsed' } else { 'Visible' }
    Filter-DataGrid -Text $txtSearchRunning.Text -Source $script:allRunningApps -Grid $dgRunning
})

$dgRunning.Add_MouseDoubleClick({
    param($s, $e)
    $item = $dgRunning.SelectedItem
    if ($item) {
        $action = if ($item.Status -eq 'Blocked') { 'Unblock' } else { 'Block' }
        $ans = [System.Windows.MessageBox]::Show("$action '$($item.Name)'?",'Confirm',[System.Windows.MessageBoxButton]::YesNo,[System.Windows.MessageBoxImage]::Question)
        if ($ans -eq 'Yes') { Handle-ToggleApp -App $item -RefreshType 'running' }
    }
})

# Context menu for running apps DataGrid
$cmRunning = New-Object System.Windows.Controls.ContextMenu
$cmRunning.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#16213E')
$cmRunning.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#E0E0E0')
$miBlockToggle = New-Object System.Windows.Controls.MenuItem
$miBlockToggle.Header = "Block / Unblock"
$miBlockToggle.Add_Click({ Handle-ToggleApp -App $dgRunning.SelectedItem -RefreshType 'running' })
$cmRunning.Items.Add($miBlockToggle) | Out-Null
$dgRunning.ContextMenu = $cmRunning

# --- Installed Apps ---
$btnScanInstalled.Add_Click({ Refresh-InstalledApps })

$txtSearchInstalled.Add_TextChanged({
    $phInstalled.Visibility = if ($txtSearchInstalled.Text.Length -gt 0) { 'Collapsed' } else { 'Visible' }
    Filter-DataGrid -Text $txtSearchInstalled.Text -Source $script:allInstalledApps -Grid $dgInstalled
})

$dgInstalled.Add_MouseDoubleClick({
    param($s, $e)
    $item = $dgInstalled.SelectedItem
    if ($item) {
        $action = if ($item.Status -eq 'Blocked') { 'Unblock' } else { 'Block' }
        $ans = [System.Windows.MessageBox]::Show("$action '$($item.Name)'?",'Confirm',[System.Windows.MessageBoxButton]::YesNo,[System.Windows.MessageBoxImage]::Question)
        if ($ans -eq 'Yes') { Handle-ToggleApp -App $item -RefreshType 'installed' }
    }
})

$cmInstalled = New-Object System.Windows.Controls.ContextMenu
$cmInstalled.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#16213E')
$cmInstalled.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#E0E0E0')
$miInstToggle = New-Object System.Windows.Controls.MenuItem
$miInstToggle.Header = "Block / Unblock"
$miInstToggle.Add_Click({ Handle-ToggleApp -App $dgInstalled.SelectedItem -RefreshType 'installed' })
$cmInstalled.Items.Add($miInstToggle) | Out-Null
$dgInstalled.ContextMenu = $cmInstalled

# --- Blocked Apps ---
$btnRefreshBlocked.Add_Click({ Refresh-BlockedApps })

$btnUnblockAll.Add_Click({
    $ans = [System.Windows.MessageBox]::Show('Unblock ALL applications?','Confirm',[System.Windows.MessageBoxButton]::YesNo,[System.Windows.MessageBoxImage]::Warning)
    if ($ans -eq 'Yes') {
        $blocked = @(Get-BlockedAppsList)
        $names = @($blocked | Select-Object -ExpandProperty Name -Unique)
        $count = 0
        foreach ($n in $names) {
            $r = Unblock-Application -Name $n
            if ($r.Success) { $count++ }
        }
        Update-StatusBar "Unblocked $count application(s)"
        Refresh-BlockedApps
    }
})

$btnExportRules.Add_Click({ Show-ExportDialog })
$btnImportRules.Add_Click({ Show-ImportDialog })

$dgBlocked.Add_MouseDoubleClick({
    param($s, $e)
    $item = $dgBlocked.SelectedItem
    if ($item) {
        $ans = [System.Windows.MessageBox]::Show("Unblock '$($item.Name)'?",'Confirm',[System.Windows.MessageBoxButton]::YesNo,[System.Windows.MessageBoxImage]::Question)
        if ($ans -eq 'Yes') {
            $r = Unblock-Application -Name $item.Name
            Update-StatusBar $r.Message
            Refresh-BlockedApps
        }
    }
})

# --- Block by Path ---
$btnBrowsePath.Add_Click({
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Filter = 'Executables (*.exe)|*.exe'
    $dlg.Title  = 'Select Application to Block'
    if ($dlg.ShowDialog() -eq 'OK') {
        $txtBlockPath.Text    = $dlg.FileName
        $txtDetectedName.Text = [System.IO.Path]::GetFileNameWithoutExtension($dlg.FileName)
    }
})

$txtBlockPath.Add_TextChanged({
    $p = $txtBlockPath.Text.Trim()
    if ($p -and $p.EndsWith('.exe')) {
        $txtDetectedName.Text = [System.IO.Path]::GetFileNameWithoutExtension($p)
    } elseif ([string]::IsNullOrWhiteSpace($p)) {
        $txtDetectedName.Text = '(select a file)'
    }
})

$btnBlockByPath.Add_Click({
    $path = $txtBlockPath.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($path)) {
        [System.Windows.MessageBox]::Show('Enter or browse for an executable path.','No Path','OK','Warning')
        return
    }
    if (-not (Test-Path $path)) {
        [System.Windows.MessageBox]::Show("File not found: $path",'Error','OK','Error')
        return
    }
    $name = [System.IO.Path]::GetFileNameWithoutExtension($path)
    $r = Block-Application -Name $name -Path $path
    if ($r.Success) {
        Update-StatusBar $r.Message
        $script:recentBlocks.Insert(0, [PSCustomObject]@{ Name=$name; Path=$path })
        if ($script:recentBlocks.Count -gt 20) { $script:recentBlocks.RemoveAt(20) }
        $dgRecentBlocks.ItemsSource = $null
        $dgRecentBlocks.ItemsSource = @($script:recentBlocks)
        $txtBlockPath.Text    = ''
        $txtDetectedName.Text = '(select a file)'
    } else {
        Update-StatusBar "Failed: $($r.Message)"
    }
})

# --- Logs ---
$btnRefreshLogs.Add_Click({
    $txtLogContent.Text = Get-AppLog
    $txtLogContent.ScrollToEnd()
    Update-StatusBar 'Logs refreshed'
})

$btnClearLogs.Add_Click({
    $ans = [System.Windows.MessageBox]::Show('Clear the entire log?','Confirm',[System.Windows.MessageBoxButton]::YesNo,[System.Windows.MessageBoxImage]::Question)
    if ($ans -eq 'Yes') {
        Clear-AppLog
        $txtLogContent.Text = ''
        Update-StatusBar 'Log cleared'
    }
})

# --- Settings ---
$btnSettingsExport.Add_Click({ Show-ExportDialog })
$btnSettingsImport.Add_Click({ Show-ImportDialog })

# ============================================================================
#                              INITIAL LOAD + RUN
# ============================================================================

$window.Add_Loaded({
    Update-StatusBar 'Loading...'
    Refresh-RunningApps
    $txtWhitelist.Text = ($script:SystemWhitelist | Sort-Object) -join "`r`n"
})

$window.Add_Closing({
    Write-AppLog "=== App Network Controller v2.5 closed ==="
})

$null = $window.ShowDialog()
