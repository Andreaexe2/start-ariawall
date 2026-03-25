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

UseAmazingAutoRefresh := true
AmazingShortcut := "^!r"
AmazingPopupShortcut := "^!a"
AmazingIntervalSeconds := 420
AmazingSetIntervalOnStartup := true
AmazingStartupDelayMs := 10000
AmazingBetweenWindowsMs := 1200

EnableLegacyKeepAlive := false
KeepAliveIntervalMs := 300000
RefreshInKeepAlive := false
WugKeepAliveIntervalMs := 180000
WugRefreshEveryNTicks := 10

InitialDelayMs := 3000
BetweenLaunchMs := 700
DetectWindowTimeoutMs := 15000
FullscreenDelayMs := 300

; FUTURE: dedicated Edge profile -> set ProfileSwitch below and keep it constant across all windows.
ProfileSwitch := '--user-data-dir="C:\MonitorWall\EdgeProfile"'
OpenInAppMode := false ; false = finestra Edge normale, true = app mode (--app)

; Handle global finestra
HwndTL := 0
HwndTR := 0
HwndBL := 0
HwndBR := 0

; =========================================================
; MAIN
; =========================================================

Sleep InitialDelayMs

edgePath := GetEdgePath()
if (!edgePath) {
    MsgBox "Microsoft Edge non è stato trovato nei percorsi previsti."
    ExitApp
}

monitors := GetMonitorList()
wall := SelectWallMonitors(monitors)

if (!wall) {
    MsgBox "Non sono riuscito a determinare i 4 monitor principali del wall."
    ExitApp
}

; FUTURE: chiusura preventiva di eventuali vecchie finestre del wall -> inserire qui una funzione dedicata.

; Open only the first window so the user can log in once.
HwndTL := OpenEdgeOnMonitor(edgePath, TopLeftUrl, wall.TopLeft, DetectWindowTimeoutMs, FullscreenDelayMs, BetweenLaunchMs, ProfileSwitch)
if (!HwndTL) {
    MsgBox "Non sono riuscito ad aprire la finestra iniziale (alto sinistra)."
    ExitApp
}

ShowConfirmOnMonitor(wall.TopRight)

HwndTR := OpenEdgeOnMonitor(edgePath, TopRightUrl, wall.TopRight, DetectWindowTimeoutMs, FullscreenDelayMs, BetweenLaunchMs, ProfileSwitch)
HwndBL := OpenEdgeOnMonitor(edgePath, BottomLeftUrl, wall.BottomLeft, DetectWindowTimeoutMs, FullscreenDelayMs, BetweenLaunchMs, ProfileSwitch)
HwndBR := OpenEdgeOnMonitor(edgePath, BottomRightUrl, wall.BottomRight, DetectWindowTimeoutMs, FullscreenDelayMs, BetweenLaunchMs, ProfileSwitch)

if (UseAmazingAutoRefresh) {
    ApplyAmazingAutoRefresh(
        [HwndTL, HwndTR, HwndBL, HwndBR],
        AmazingShortcut,
        AmazingPopupShortcut,
        AmazingIntervalSeconds,
        AmazingSetIntervalOnStartup,
        AmazingStartupDelayMs,
        AmazingBetweenWindowsMs
    )
}

; Fallback opzionale se Amazing Auto Refresh non e' disponibile o non configurato.
if (EnableLegacyKeepAlive) {
    SetTimer KeepAliveTick, KeepAliveIntervalMs
    SetTimer KeepAliveWugTick, WugKeepAliveIntervalMs
}

return

KeepAliveTick() {
    global RefreshInKeepAlive, HwndTL, HwndTR, HwndBL
    
    ; Array che contiene SOLO le schede di vRealize / Aria.
    ; Ignoriamo HwndBR (WUG) perché l'invio di comandi blocca il suo carousel o lo disconnette.
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
    
    ; Dopo il ciclo, volendo si può rimettere il focus all'ultima pagina (WUG), ma
    ; in assenza di iterazione manuale il wall resta visibile indipendentemente dal focus.
}

KeepAliveWugTick() {
    global HwndBR, WugRefreshEveryNTicks
    static tick := 0

    if !(HwndBR && WinExist("ahk_id " HwndBR))
        return

    tick += 1

    ; Keepalive leggero su WUG senza cambiare focus della finestra.
    try {
        ControlSend "{F15}",, "ahk_id " HwndBR
    }

    ; Refresh raro opzionale per evitare timeout lato server molto aggressivi.
    if (WugRefreshEveryNTicks > 0 && Mod(tick, WugRefreshEveryNTicks) = 0) {
        try {
            ControlSend "{F5}",, "ahk_id " HwndBR
        }
    }
}

ApplyAmazingAutoRefresh(hwndList, shortcut, popupShortcut, intervalSeconds, setIntervalOnStartup, startupDelayMs, betweenWindowsMs) {
    if (shortcut = "" && popupShortcut = "")
        return false

    ; Aspetta che i contenuti web siano realmente pronti prima di inviare la scorciatoia.
    Sleep startupDelayMs

    for _, hwnd in hwndList {
        if (hwnd && WinExist("ahk_id " hwnd)) {
            try {
                WinActivate "ahk_id " hwnd
                WinWaitActive "ahk_id " hwnd, , 2
                Sleep 150

                ; Opzionale: apre il popup dell'estensione e imposta il timer in secondi.
                if (setIntervalOnStartup && popupShortcut != "") {
                    Send popupShortcut
                    Sleep 300
                    Send "^a"
                    Sleep 50
                    Send intervalSeconds
                    Sleep 50
                    Send "{Enter}"
                    Sleep 400
                }

                ; Avvio esplicito del refresh automatico nella pagina corrente.
                if (shortcut != "") {
                    Send shortcut
                }

                Sleep betweenWindowsMs
            }
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
    copy := arr.Clone()

    len := copy.Length
    if (len <= 1)
        return copy

    ; Simple bubble sort to avoid method issues on older runtimes
    Loop len - 1 {
        outerIndex := A_Index
        swapped := false

        Loop len - outerIndex {
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

    ; FUTURE: verifica raggiungibilita' della pagina prima di aprire -> inserire check qui (HTTP ping) e gestire fallback.
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