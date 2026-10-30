$ErrorActionPreference = 'Stop'
$source = Get-Content (Join-Path $PSScriptRoot '..\native\main.cpp') -Raw
$checks = [ordered]@{
    appearance_config = ($source.Contains('\"theme\"') -and $source.Contains('\"opacity\"') -and $source.Contains('\"accent\"'))
    three_themes = ($source -match '青雾' -and $source -match '深海' -and $source -match '月白')
    app_owned_prompts = ($source -notmatch 'MessageBoxW' -and $source -match 'DrawPrompt')
    modal_keyboard_actions = ($source -match 'WM_KEYDOWN' -and $source -match 'VK_ESCAPE' -and $source -match 'VK_RETURN')
    registry_editor_action = $source.Contains('regedit.exe')
    current_user_start_menu_link = ($source -match 'IShellLinkW' -and $source -match 'FOLDERID_Programs')
    process_and_startup_checks = ($source -match 'DrawCheckbox' -and $source -match 'g_selectedProcesses')
    run_once_and_registry_views = ($source -match 'RunOnce' -and $source -match 'KEY_WOW64_32KEY' -and $source -match 'KEY_WOW64_64KEY')
    quarter_second_240_point_chart = ($source -match 'array<float,\s*240>' -and $source -match 'SetTimer\(h,1,250')
    computer_config_card = ($source -match 'DrawComputerInfoCard' -and $source -match 'LoadComputerInfo\(\)' -and $source -match 'ComputerPanelRect')
    window_and_taskbar_icon = ($source -match 'IDI_NOVAMEMORY' -and $source -match 'WM_SETICON' -and $source -match 'wc\.hIcon' -and (Test-Path (Join-Path $PSScriptRoot '..\native\NovaMemory.ico')) -and (Test-Path (Join-Path $PSScriptRoot '..\native\app.rc')))
    config_copy_action = ($source -match 'CopyConfigButtonRect' -and $source -match 'OpenClipboard' -and $source -match 'CF_UNICODETEXT' -and $source -match 'ComputerInfoReport')
    config_usage_meters = ($source -match 'void DrawMeter' -and $source -match 'meterRow' -and $source -match 'g_cpuPercent' -and $source -match 'FormatUptime')
    config_live_refresh = (($source -match 'SetTimer\(g_window,6,1000') -and ($source -match 'w==6') -and ($source -match 'RefreshComputerUsage'))
    tray_icon_and_menu = ($source -match 'Shell_NotifyIconW' -and $source -match 'NOTIFYICONDATAW' -and $source -match 'TrackPopupMenu' -and $source -match 'TRAY_EXIT' -and $source -match 'HideToTray')
    visual_verification_harness = (Test-Path (Join-Path $PSScriptRoot '..\tools\verify-window.ps1')) -and (Test-Path (Join-Path $PSScriptRoot 'ui_visual.ps1'))
}
$failed = @($checks.GetEnumerator() | Where-Object { -not $_.Value } | ForEach-Object { $_.Key })
if ($failed.Count) {
    Write-Output ('FAIL: ' + ($failed -join ', '))
    exit 1
}
Write-Output 'PASS: appearance, in-app prompts, shortcut, maintenance rows, startup scope, memory chart, computer config card, and window icon contracts.'
