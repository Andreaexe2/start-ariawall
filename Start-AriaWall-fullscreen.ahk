#Requires AutoHotkey v2.0
#SingleInstance Force

; =========================================================
; CONFIG
; =========================================================

; Core URLs for the 4 tiles of the wall
TopLeftUrl := "https://aria.infra.wetechs.priv/vcf-operations/ui/inventory;mode=tree;ts=vSphere%20Hosts%20and%20Clusters-VMWARE-vSphere%20World;resourceId=3ec613a6-04f1-42ee-b5c5-de0b91915f80;tab=summary"
TopRightUrl := "https://aria.infra.wetechs.priv/vcf-operations/ui/inventory;mode=tree;ts=vSphere%20Hosts%20and%20Clusters-VMWARE-vSphere%20World;resourceId=cc0eac06-8245-4449-b36b-238eeabaa5a8;tab=summary"
BottomLeftUrl := "https://aria.infra.wetechs.priv/vcf-operations/ui/operations/dashboards;tabId=338e22d0-6d15-4145-872b-4cad1982c222"
BottomRightUrl := "https://ws-wb1-i-wug01.infra.wetechs.priv/NmConsole/#v=Wug_view_nocviewer_NocViewer/p=%7B%22isMainView%22%3Atrue%2C%22DeckId%22%3A1%7D"

; =========================================================
; HOOK / MOD: Amazing Auto Refresh
; Lo script apre il popup dell'estensione, imposta il timer,
; tabba fino a START e lo preme su tutte le 4 finestre.
; =========================================================
UseAmazingAutoRefresh := true
AmazingPopupShortcut := "^!a"        ; Edge -> extensions shortcuts -> Open popup
AmazingIntervalSeconds := 420        ; 7 minuti
AmazingSetIntervalOnStartup := true
AmazingStartupDelayMs := 12000
AmazingBetweenWindowsMs := 1500
AmazingPopupOpenDelayMs := 700
AmazingKeyDelayMs := 80
AmazingTabToStartCount := 11         ; se non parte, prova 10 o 12
AmazingReEnterFullscreen := true

; =========================================================
; HOOK / MOD: fallback keepalive
; Tiene viva la sessione anche se l'estensione non parte su una finestra
; =========================================================
EnableLegacyKeepAlive := true
KeepAliveIntervalMs := 240000        ; 4 minuti
RefreshInKeepAlive := false          ; false = F15 leggero, true = F5 pesante
WugKeepAliveIntervalMs := 180000     ; 3 minuti
WugRefreshEveryNTicks := 10          ; ogni 10 tick WUG fa F5

InitialDelayMs := 15000
BetweenLaunchMs := 2000
DetectWindowTimeoutMs := 15000
FullscreenDelayMs := 800

; =========================================================
; HOOK / MOD: profilo Edge dedicato
; Qui vive sessione, cookie, estensioni e stato del wall
; =========================================================
ProfileSwitch := '--user-data-dir="C:\Users\ServiceDesk\Desktop\start-ariawall\EdgeProfile"'
OpenInAppMode := false   ; lasciare false: estensioni piu' compatibili

; =========================================================
; MAIN
; =========================================================

Sleep InitialDelayMs

edgePath := GetEdgePath()
if (edgePath = "") {
    MsgBox "Microsoft Edge non trovato."
    ExitApp
}

monitors := GetMonitorList()
if (monitors.Length < 4) {
    MsgBox "Servono almeno 4 monitor. Rilevati: " monitors.Length
    ExitApp
}

wall := SelectWallMonitors(monitors)
if (!wall) {
    MsgBox "Impossibile identificare i 4 monitor del wall (piu' a destra)."
    ExitApp
}

; HOOK / MOD futuro:
; qui puoi chiudere eventuali vecchie finestre Edge del wall prima di riaprire tutto.

global HwndTL := OpenEdgeOnMonitor(edgePath, TopLeftUrl, wall.TopLeft, DetectWindowTimeoutMs, FullscreenDelayMs, BetweenLaunchMs, ProfileSwitch)
if (!HwndTL) {
    MsgBox "Non sono riuscito ad aprire la finestra iniziale (alto sinistra)."
    ExitApp
}

ShowConfirmOnMonitor(wall.TopRight)

global HwndTR := OpenEdgeOnMonitor(edgePath, TopRightUrl, wall.TopRight, DetectWindowTimeoutMs, FullscreenDelayMs, BetweenLaunchMs, ProfileSwitch)
global HwndBL := OpenEdgeOnMonitor(edgePath, BottomLeftUrl, wall.BottomLeft, DetectWindowTimeoutMs, FullscreenDelayMs, BetweenLaunchMs, ProfileSwitch)
global HwndBR := OpenEdgeOnMonitor(edgePath, BottomRightUrl, wall.BottomRight, DetectWindowTimeoutMs, FullscreenDelayMs, BetweenLaunchMs, ProfileSwitch)

if (UseAmazingAutoRefresh) {
    ApplyAmazingAutoRefresh(
        [HwndTL, HwndTR, HwndBL, HwndBR],
        AmazingPopupShortcut,
        AmazingIntervalSeconds,
        AmazingSetIntervalOnStartup,
        AmazingStartupDelayMs,
        AmazingBetweenWindowsMs,
        AmazingPopupOpenDelayMs,
        AmazingKeyDelayMs,
        AmazingTabToStartCount,
        AmazingReEnterFullscreen
    )
}

if (EnableLegacyKeepAlive) {
    SetTimer KeepAliveTick, KeepAliveIntervalMs
    SetTimer KeepAliveWugTick, WugKeepAliveIntervalMs
}

Persistent()

; =========================================================
; KEEPALIVE
; =========================================================

KeepAliveTick() {
    global RefreshInKeepAlive, HwndTL, HwndTR, HwndBL

    ariaWindows := [HwndTL, HwndTR, HwndBL]

    for _, hwnd in ariaWindows {
        if (hwnd && WinExist("ahk_id " hwnd)) {
            try {
                if (RefreshInKeepAlive)
                    ControlSend "{F5}",, "ahk_id " hwnd
                else
                    ControlSend "{F15}",, "ahk_id " hwnd
                Sleep 200
            }
        }
    }
}

KeepAliveWugTick() {
    global HwndBR, WugRefreshEveryNTicks
    static tick := 0

    if !(HwndBR && WinExist("ahk_id " HwndBR))
        return

    tick += 1

    try {
        ControlSend "{F15}",, "ahk_id " HwndBR
    }

    if (WugRefreshEveryNTicks > 0 && Mod(tick, WugRefreshEveryNTicks) = 0) {
        try {
            ControlSend "{F5}",, "ahk_id " HwndBR
        }
    }
}

; =========================================================
; AMAZING AUTO REFRESH AUTOMATION
; =========================================================

ApplyAmazingAutoRefresh(hwndList, popupShortcut, intervalSeconds, setIntervalOnStartup, startupDelayMs, betweenWindowsMs, popupOpenDelayMs, keyDelayMs, tabToStartCount, reEnterFullscreen) {
    if (popupShortcut = "")
        return false

    Sleep startupDelayMs
    SetKeyDelay keyDelayMs, keyDelayMs

    for _, hwnd in hwndList {
        if !(hwnd && WinExist("ahk_id " hwnd))
            continue

        try {
            ; Esce temporaneamente da F11
            WinActivate "ahk_id " hwnd
            WinWaitActive "ahk_id " hwnd, , 2
            Sleep 250
            SendEvent "{F11}"
            Sleep 500

            ; Riattiva la finestra
            WinActivate "ahk_id " hwnd
            WinWaitActive "ahk_id " hwnd, , 2
            Sleep 250

            ; Apre il popup dell'estensione
            SendEvent popupShortcut
            Sleep popupOpenDelayMs

            ; Prova a sovrascrivere il valore del timer
            if (setIntervalOnStartup) {
                SendEvent "^a"
                Sleep 120
                SendText intervalSeconds
                Sleep 120
            }

            ; Va sul bottone START
            Loop tabToStartCount {
                SendEvent "{Tab}"
                Sleep 70
            }

            ; Preme START
            SendEvent "{Space}"
            Sleep 500

            ; Chiude il popup
            SendEvent "{Esc}"
            Sleep 250

            ; Torna in fullscreen
            if (reEnterFullscreen) {
                WinActivate "ahk_id " hwnd
                WinWaitActive "ahk_id " hwnd, , 2
                Sleep 150
                SendEvent "{F11}"
                Sleep 400
            }

            Sleep betweenWindowsMs
        }
    }

    return true
}

; =========================================================
; FUNCTIONS
; =========================================================

GetEdgePath() {
    candidates := [
        "C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe",
        "C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe"
    ]

    for _, path in candidates {
        if FileExist(path)
            return path
    }

    return ""
}

GetMonitorList() {
    count := MonitorGetCount()
    list := []

    Loop count {
        idx := A_Index
        MonitorGet idx, &left, &top, &right, &bottom

        list.Push({
            Index: idx,
            Left: left,
            Top: top,
            Right: right,
            Bottom: bottom,
            Width: right - left,
            Height: bottom - top
        })
    }

    return list
}

SelectWallMonitors(monitors) {
    sortedByX := SortMonitors(monitors, "Left")
    if (sortedByX.Length < 4)
        return 0

    startIdx := sortedByX.Length - 3
    rightCluster := []

    Loop 4 {
        rightCluster.Push(sortedByX[startIdx + A_Index - 1])
    }

    sortedByY := SortMonitors(rightCluster, "Top")
    topTwo := [sortedByY[1], sortedByY[2]]
    bottomTwo := [sortedByY[3], sortedByY[4]]

    topSorted := SortMonitors(topTwo, "Left")
    bottomSorted := SortMonitors(bottomTwo, "Left")

    return {
        TopLeft: topSorted[1],
        TopRight: topSorted[2],
        BottomLeft: bottomSorted[1],
        BottomRight: bottomSorted[2]
    }
}

SortMonitors(arr, prop) {
    copy := []

    for _, item in arr
        copy.Push(item)

    len := copy.Length
    if (len <= 1)
        return copy

    Loop len - 1 {
        pass := A_Index
        swapped := false

        Loop len - pass {
            j := A_Index
            if (copy[j].%prop% > copy[j + 1].%prop%) {
                tmp := copy[j]
                copy[j] := copy[j + 1]
                copy[j + 1] := tmp
                swapped := true
            }
        }

        if !swapped
            break
    }

    return copy
}

OpenEdgeOnMonitor(edgePath, url, monitor, detectTimeoutMs, fullscreenDelayMs, betweenLaunchMs, profileSwitch) {
    global OpenInAppMode

    existing := WinGetList("ahk_exe msedge.exe")

    if (OpenInAppMode)
        runCmd := Format('"{1}" {2} --new-window --app="{3}"', edgePath, profileSwitch, url)
    else
        runCmd := Format('"{1}" {2} --new-window "{3}"', edgePath, profileSwitch, url)

    ; HOOK / MOD futuro:
    ; qui puoi aggiungere verifica raggiungibilita' pagina prima dell'apertura
    Run runCmd

    hwnd := WaitForNewEdgeWindow(existing, detectTimeoutMs)
    if (!hwnd)
        return 0

    WinRestore "ahk_id " hwnd
    Sleep 200
    WinMove monitor.Left, monitor.Top, monitor.Width, monitor.Height, "ahk_id " hwnd
    Sleep 400
    WinActivate "ahk_id " hwnd
    Sleep 300
    WinMaximize "ahk_id " hwnd
    Sleep fullscreenDelayMs
    Send "{F11}"
    Sleep betweenLaunchMs

    return hwnd
}

WaitForNewEdgeWindow(existingList, timeoutMs) {
    start := A_TickCount

    while (A_TickCount - start < timeoutMs) {
        current := WinGetList("ahk_exe msedge.exe")

        for _, hwnd in current {
            if !ArrayContains(existingList, hwnd) {
                if (WinGetTitle("ahk_id " hwnd) != "")
                    return hwnd
            }
        }

        Sleep 250
    }

    return 0
}

ArrayContains(arr, value) {
    for _, item in arr {
        if (item = value)
            return true
    }
    return false
}

ShowConfirmOnMonitor(monitor) {
    myGui := Gui("+AlwaysOnTop +ToolWindow -SysMenu")
    myGui.SetFont("s16 bold")
    myGui.AddText("w520 Center", "Completa il login nella finestra in alto a sinistra, poi premi OK per aprire automaticamente le altre tre finestre.")

    okBtn := myGui.AddButton("w160 h50 Default", "OK")
    okBtn.OnEvent("Click", (*) => myGui.Destroy())

    myGui.Show("AutoSize Hide")

    xOut := 0, yOut := 0, wOut := 0, hOut := 0
    myGui.GetPos(&xOut, &yOut, &wOut, &hOut)

    xPos := monitor.Left + Floor((monitor.Width - wOut) / 2)
    yPos := monitor.Top + Floor((monitor.Height - hOut) / 2)
    myGui.Show(Format("x{} y{}", xPos, yPos))

    WinWaitClose("ahk_id " myGui.Hwnd)

    return true
}