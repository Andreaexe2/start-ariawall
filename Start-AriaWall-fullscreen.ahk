#Requires AutoHotkey v2.0
#SingleInstance Force

; =========================================================
; CONFIG
; =========================================================

TopLeftUrl := "https://aria.infra.wetechs.priv/vcf-operations/ui/operations/dashboards;tabId=bac7c74c-a29f-4f9b-bee0-773be10ad6a3"
TopRightUrl := "https://aria.infra.wetechs.priv/vcf-operations/ui/operations/dashboards;tabId=f81793bd-5c5e-440f-9d76-46d7532dd06d"
BottomLeftUrl := "https://aria.infra.wetechs.priv/vcf-operations/ui/operations/dashboards;tabId=2e1e59eb-4cc8-4ae0-a0ca-cb44358fab5b"
BottomRightUrl := "https://ws-wb1-i-wug01.infra.wetechs.priv/NmConsole/#v=Wug_view_nocviewer_NocViewer/p=%7B%22isMainView%22%3Atrue%2C%22DeckId%22%3A1%7D"

InitialDelayMs := 5000
BetweenLaunchMs := 400
DetectWindowTimeoutMs := 12000
FullscreenDelayMs := 500

; =========================================================
; HOOK/MOD:
; attesa configurazione monitor stabile
; =========================================================
RequiredMonitorCount := 5
MonitorPollIntervalMs := 2000
MonitorWaitTimeoutMs := 90000
StablePollsRequired := 2

; =========================================================
; HOOK/MOD:
; mapping monitor fisso del wall
; schermo 1 NON usato
; =========================================================
TopLeftMonitorIndex := 3
TopRightMonitorIndex := 2
BottomLeftMonitorIndex := 5
BottomRightMonitorIndex := 4
ExcludedMonitorIndex := 1

; =========================================================
; HOOK/MOD:
; se vuoi cambiare profilo Edge, modifica solo questa riga
; =========================================================
ProfileSwitch := '--user-data-dir="C:\Users\ServiceDesk\Desktop\start-ariawall\EdgeProfile"'

; =========================================================
; HOOK/MOD:
; false = finestra Edge normale
; true  = usa --app
; =========================================================
OpenInAppMode := false

; =========================================================
; MAIN
; =========================================================

Sleep InitialDelayMs

edgePath := GetEdgePath()
if (edgePath = "") {
    MsgBox "Microsoft Edge non trovato."
    ExitApp
}

monitors := WaitForStableMonitorTopology(RequiredMonitorCount, MonitorWaitTimeoutMs, MonitorPollIntervalMs, StablePollsRequired)

if (monitors.Length < RequiredMonitorCount) {
    MsgBox "Windows non ha rilevato almeno " RequiredMonitorCount " monitor in modo stabile. Rilevati: " monitors.Length
    ExitApp
}

wall := BuildFixedWallLayout(monitors)
if (!wall) {
    MsgBox "Impossibile costruire il layout monitor fisso.`nControlla che siano presenti i monitor 2, 3, 4 e 5 e che il monitor 1 non venga usato."
    ExitApp
}

; 1) Apro solo la finestra in alto a sinistra (schermo 3)
global HwndTL := OpenEdgeOnMonitor(edgePath, TopLeftUrl, wall.TopLeft, DetectWindowTimeoutMs, FullscreenDelayMs, BetweenLaunchMs, ProfileSwitch)
if (!HwndTL) {
    MsgBox "Non sono riuscito ad aprire la finestra iniziale (alto sinistra / schermo 3)."
    ExitApp
}

; 2) Popup sul monitor in alto a destra (schermo 2), senza rubare il focus
ShowConfirmOnMonitor(wall.TopRight)

Sleep 300

; 3) Dopo OK apro le altre 3 finestre
global HwndTR := OpenEdgeOnMonitor(edgePath, TopRightUrl, wall.TopRight, DetectWindowTimeoutMs, FullscreenDelayMs, BetweenLaunchMs, ProfileSwitch)
global HwndBL := OpenEdgeOnMonitor(edgePath, BottomLeftUrl, wall.BottomLeft, DetectWindowTimeoutMs, FullscreenDelayMs, BetweenLaunchMs, ProfileSwitch)
global HwndBR := OpenEdgeOnMonitor(edgePath, BottomRightUrl, wall.BottomRight, DetectWindowTimeoutMs, FullscreenDelayMs, BetweenLaunchMs, ProfileSwitch)

; 4) Tolgo il focus dall'ultima finestra aperta per evitare evidenziazioni blu
DefocusBrowserWindows()

ExitApp

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

WaitForStableMonitorTopology(requiredCount, timeoutMs, pollIntervalMs, stablePollsRequired) {
    start := A_TickCount
    lastList := GetMonitorList()
    lastSig := ""
    stableCount := 0

    while ((A_TickCount - start) < timeoutMs) {
        lastList := GetMonitorList()

        if (lastList.Length >= requiredCount) {
            sig := BuildMonitorSignature(lastList)

            if (sig != "" && sig = lastSig) {
                stableCount += 1
            } else {
                stableCount := 1
                lastSig := sig
            }

            if (stableCount >= stablePollsRequired)
                return lastList
        }

        Sleep pollIntervalMs
    }

    return lastList
}

BuildMonitorSignature(monitors) {
    sig := ""

    for _, m in monitors {
        sig .= m.Left "|" m.Top "|" m.Width "|" m.Height ";"
    }

    return sig
}

GetMonitorList() {
    count := MonitorGetCount()
    list := []

    Loop count {
        idx := A_Index
        MonitorGet idx, &left, &top, &right, &bottom

        width := right - left
        height := bottom - top

        list.Push({
            Index: idx,
            Left: left,
            Top: top,
            Right: right,
            Bottom: bottom,
            Width: width,
            Height: height,
            Area: width * height,
            CenterX: left + Floor(width / 2),
            CenterY: top + Floor(height / 2)
        })
    }

    return list
}

GetMonitorByIndex(monitors, wantedIndex) {
    for _, m in monitors {
        if (m.Index = wantedIndex)
            return m
    }
    return 0
}

BuildFixedWallLayout(monitors) {
    global TopLeftMonitorIndex
    global TopRightMonitorIndex
    global BottomLeftMonitorIndex
    global BottomRightMonitorIndex
    global ExcludedMonitorIndex

    tl := GetMonitorByIndex(monitors, TopLeftMonitorIndex)
    tr := GetMonitorByIndex(monitors, TopRightMonitorIndex)
    bl := GetMonitorByIndex(monitors, BottomLeftMonitorIndex)
    br := GetMonitorByIndex(monitors, BottomRightMonitorIndex)

    if (!tl || !tr || !bl || !br)
        return 0

    used := Map()
    used[tl.Index] := true
    used[tr.Index] := true
    used[bl.Index] := true
    used[br.Index] := true

    if (used.Count != 4)
        return 0

    if (tl.Index = ExcludedMonitorIndex
     || tr.Index = ExcludedMonitorIndex
     || bl.Index = ExcludedMonitorIndex
     || br.Index = ExcludedMonitorIndex)
        return 0

    return {
        TopLeft: tl,
        TopRight: tr,
        BottomLeft: bl,
        BottomRight: br
    }
}

OpenEdgeOnMonitor(edgePath, url, monitor, detectTimeoutMs, fullscreenDelayMs, betweenLaunchMs, profileSwitch) {
    global OpenInAppMode

    existing := WinGetList("ahk_exe msedge.exe")
    pid := 0

    if (OpenInAppMode)
        runCmd := Format('"{1}" {2} --new-window --app="{3}"', edgePath, profileSwitch, url)
    else
        runCmd := Format('"{1}" {2} --new-window "{3}"', edgePath, profileSwitch, url)

    Run runCmd, , , &pid

    hwnd := WaitForEdgeWindow(existing, pid, detectTimeoutMs)
    if (!hwnd)
        return 0

    ForceWindowPlacementAndFullscreen(hwnd, monitor, fullscreenDelayMs, betweenLaunchMs)
    return hwnd
}

WaitForEdgeWindow(existingList, pid, timeoutMs) {
    start := A_TickCount

    while (A_TickCount - start < timeoutMs) {
        if (pid) {
            byPid := WinGetList("ahk_pid " pid)
            for _, hwnd in byPid {
                if (IsUsableEdgeWindow(hwnd))
                    return hwnd
            }
        }

        current := WinGetList("ahk_exe msedge.exe")
        for _, hwnd in current {
            if (!ArrayContains(existingList, hwnd) && IsUsableEdgeWindow(hwnd))
                return hwnd
        }

        Sleep 200
    }

    return 0
}

IsUsableEdgeWindow(hwnd) {
    try {
        class := WinGetClass("ahk_id " hwnd)
        if (class != "Chrome_WidgetWin_1")
            return false

        return true
    } catch {
        return false
    }
}

ForceWindowPlacementAndFullscreen(hwnd, monitor, fullscreenDelayMs, betweenLaunchMs) {
    if !(hwnd && WinExist("ahk_id " hwnd))
        return false

    try WinRestore "ahk_id " hwnd
    Sleep 200

    try WinMove monitor.Left, monitor.Top, monitor.Width, monitor.Height, "ahk_id " hwnd
    Sleep 350

    try WinActivate "ahk_id " hwnd
    try WinWaitActive("ahk_id " hwnd, , 3)
    Sleep 250

    try WinMaximize "ahk_id " hwnd
    Sleep fullscreenDelayMs

    try SendEvent "{F11}"
    Sleep 700

    WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)

    needsRetry := false

    if (x != monitor.Left || y != monitor.Top)
        needsRetry := true

    if (w < monitor.Width - 20 || h < monitor.Height - 20)
        needsRetry := true

    if (needsRetry) {
        try SendEvent "{F11}"
        Sleep 300

        try WinRestore "ahk_id " hwnd
        Sleep 200

        try WinMove monitor.Left, monitor.Top, monitor.Width, monitor.Height, "ahk_id " hwnd
        Sleep 350

        try WinActivate "ahk_id " hwnd
        try WinWaitActive("ahk_id " hwnd, , 3)
        Sleep 250

        try WinMaximize "ahk_id " hwnd
        Sleep fullscreenDelayMs

        try SendEvent "{F11}"
        Sleep 700
    }

    Sleep betweenLaunchMs
    return true
}

DefocusBrowserWindows() {
    try {
        WinActivate "ahk_class Shell_TrayWnd"
    } catch {
        ; ignora
    }
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
    myGui.AddText("w560 Center", "Buongiorno disadattato, fai il login nella finestra in alto a sinistra, successivamente premi OK per aprire automaticamente le altre tre finestre.")

    okBtn := myGui.AddButton("w160 h50 Default", "OK")
    okBtn.OnEvent("Click", (*) => myGui.Destroy())

    myGui.Show("AutoSize Hide")

    xOut := 0, yOut := 0, wOut := 0, hOut := 0
    myGui.GetPos(&xOut, &yOut, &wOut, &hOut)

    xPos := monitor.Left + Floor((monitor.Width - wOut) / 2)
    yPos := monitor.Top + Floor((monitor.Height - hOut) / 2)

    myGui.Show(Format("x{} y{} NoActivate", xPos, yPos))

    WinWaitClose("ahk_id " myGui.Hwnd)
    return true
}