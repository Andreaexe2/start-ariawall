
param(
    [string]$AhkScriptPath = $(if ($PSScriptRoot) { Join-Path $PSScriptRoot "Start-AriaWall-fullscreen.ahk" } else { "$env:USERPROFILE\Desktop\Start-AriaWall-fullscreen.ahk" })
)

$possibleAhkExe = @(
    "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey64.exe",
    "$env:ProgramFiles\AutoHotkey\AutoHotkey64.exe",
    "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey.exe",
    "$env:ProgramFiles\AutoHotkey\AutoHotkey.exe",
    "${env:ProgramFiles(x86)}\AutoHotkey\v2\AutoHotkey64.exe",
    "${env:ProgramFiles(x86)}\AutoHotkey\AutoHotkey64.exe",
    "${env:ProgramFiles(x86)}\AutoHotkey\v2\AutoHotkey.exe",
    "${env:ProgramFiles(x86)}\AutoHotkey\AutoHotkey.exe"
) | Where-Object { Test-Path $_ }

if (-not (Test-Path $AhkScriptPath)) {
    throw "Script AHK non trovato: $AhkScriptPath"
}

if (-not $possibleAhkExe -or $possibleAhkExe.Count -eq 0) {
    throw "AutoHotkey v2 non trovato. Installa AutoHotkey v2 prima di registrare l'avvio automatico."
}

$ahkExe = $possibleAhkExe[0]
$currentUser = "$env:USERDOMAIN\$env:USERNAME"

$action = New-ScheduledTaskAction `
    -Execute $ahkExe `
    -Argument "`"$AhkScriptPath`""

$trigger = New-ScheduledTaskTrigger -AtLogOn -User $currentUser

$principal = New-ScheduledTaskPrincipal `
    -UserId $currentUser `
    -LogonType Interactive `
    -RunLevel Limited

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable

if (Get-ScheduledTask -TaskName "AriaMonitorWallAHK" -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName "AriaMonitorWallAHK" -Confirm:$false
}

Register-ScheduledTask `
    -TaskName "AriaMonitorWallAHK" `
    -Action $action `
    -Trigger $trigger `
    -Principal $principal `
    -Settings $settings `
    -Description "Avvia automaticamente il monitor wall Aria con AutoHotkey"

Write-Host "Task creato: AriaMonitorWallAHK"
Write-Host "Avvio: al logon utente ($currentUser)"
Write-Host "Eseguibile AHK: $ahkExe"
Write-Host "Script: $AhkScriptPath"
