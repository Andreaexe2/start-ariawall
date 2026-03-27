#Requires AutoHotkey v2.0
#SingleInstance Force

; =========================================================
; CONFIG
; =========================================================

; HOOK/MOD: URLs
TopLeftUrl := "https://aria.infra.wetechs.priv/vcf-operations/ui/operations/dashboards;tabId=bac7c74c-a29f-4f9b-bee0-773be10ad6a3"
TopRightUrl := "https://aria.infra.wetechs.priv/vcf-operations/ui/operations/dashboards;tabId=f81793bd-5c5e-440f-9d76-46d7532dd06d"
BottomLeftUrl := "https://aria.infra.wetechs.priv/vcf-operations/ui/operations/dashboards;tabId=2e1e59eb-4cc8-4ae0-a0ca-cb44358fab5b"
BottomRightUrl := "https://ws-wb1-i-wug01.infra.wetechs.priv/NmConsole/#v=Wug_view_nocviewer_NocViewer/p=%7B%22isMainView%22%3Atrue%2C%22DeckId%22%3A1%7D"

; HOOK/MOD: timing
InitialDelayMs := 5000
BetweenLaunchMs := 400
DetectWindowTimeoutMs := 12000
FullscreenDelayMs := 500
MonitorPollIntervalMs := 2000
MonitorWaitTimeoutMs := 90000
StablePollsRequired := 2

; HOOK/MOD: fixed monitor mapping
; monitor 1 must never be used
FixedMonitorMap := {
    TopLeft: 3,
    TopRight: 2,
    BottomLeft: 5,
    BottomRight: 4
}
ExcludedMonitorIndex := 1
RequiredPresentMonitorIndexes := [2, 3, 4, 5]

; HOOK/MOD: Edge profile path
ProfileSwitch := '--user-data-dir="C:\Users\ServiceDesk\Desktop\start-ariawall\EdgeProfile"'

; =========================================================
; MAIN
; =========================================================

Sleep InitialDelayMs

edgePath := GetEdgePath()
if (edgePath = "") {
    MsgBox "Microsoft Edge non trovato."
    ExitApp
}

configCheck := ValidateFixedMonitorConfig(FixedMonitorMap, ExcludedMonitorIndex, RequiredPresentMonitorIndexes)
if (!configCheck.Ok) {
    MsgBox configCheck.Message
    ExitApp
}

topology := WaitForStableMonitorTopology(FixedMonitorMap, ExcludedMonitorIndex, RequiredPresentMonitorIndexes, MonitorWaitTimeoutMs, MonitorPollIntervalMs, StablePollsRequired)
if (!topology.Ok) {
    MsgBox topology.Message
    ExitApp
}

wall := topology.Wall

; 1) Apro solo la finestra in alto a sinistra (schermo 3)
hwndTopLeft := OpenEdgeOnMonitor(edgePath, TopLeftUrl, wall.TopLeft, DetectWindowTimeoutMs, FullscreenDelayMs, BetweenLaunchMs, ProfileSwitch)
if (!hwndTopLeft) {
    MsgBox "Non sono riuscito ad aprire la finestra iniziale (alto sinistra / schermo 3)."
    ExitApp
}

; 2) Popup sul monitor in alto a destra (schermo 2), senza rubare il focus
ShowConfirmOnMonitor(wall.TopRight)

Sleep 300

; 3) Dopo OK apro le altre 3 finestre
hwndTopRight := OpenEdgeOnMonitor(edgePath, TopRightUrl, wall.TopRight, DetectWindowTimeoutMs, FullscreenDelayMs, BetweenLaunchMs, ProfileSwitch)
if (!hwndTopRight) {
    MsgBox "Non sono riuscito ad aprire la finestra alto destra (schermo 2)."
    ExitApp
}

hwndBottomLeft := OpenEdgeOnMonitor(edgePath, BottomLeftUrl, wall.BottomLeft, DetectWindowTimeoutMs, FullscreenDelayMs, BetweenLaunchMs, ProfileSwitch)
if (!hwndBottomLeft) {
    MsgBox "Non sono riuscito ad aprire la finestra basso sinistra (schermo 5)."
    ExitApp
}

hwndBottomRight := OpenEdgeOnMonitor(edgePath, BottomRightUrl, wall.BottomRight, DetectWindowTimeoutMs, FullscreenDelayMs, BetweenLaunchMs, ProfileSwitch)
if (!hwndBottomRight) {
    MsgBox "Non sono riuscito ad aprire la finestra basso destra (schermo 4)."
    ExitApp
}

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

ValidateFixedMonitorConfig(monitorMap, excludedMonitorIndex, requiredPresentIndexes) {
    if (!IsObject(monitorMap))
        return {Ok: false, Message: "Config monitor non valida: struttura mapping mancante."}

    if (!monitorMap.HasOwnProp("TopLeft")
     || !monitorMap.HasOwnProp("TopRight")
     || !monitorMap.HasOwnProp("BottomLeft")
     || !monitorMap.HasOwnProp("BottomRight")) {
        return {Ok: false, Message: "Config monitor non valida: mapping incompleto (TopLeft/TopRight/BottomLeft/BottomRight)."}
    }

    assigned := [monitorMap.TopLeft, monitorMap.TopRight, monitorMap.BottomLeft, monitorMap.BottomRight]
    used := Map()

    for _, idx in assigned {
        if (idx = excludedMonitorIndex)
            return {Ok: false, Message: "Config monitor non valida: il monitor escluso (" excludedMonitorIndex ") e' stato assegnato al wall."}

        if (used.Has(idx))
            return {Ok: false, Message: "Config monitor non valida: un monitor e' assegnato a piu' quadranti."}

        used[idx] := true
    }

    for _, mustExist in requiredPresentIndexes {
        if (!used.Has(mustExist))
            return {Ok: false, Message: "Config monitor non valida: il wall deve usare esplicitamente i monitor 2, 3, 4 e 5."}
    }

    return {Ok: true}
}

WaitForStableMonitorTopology(monitorMap, excludedMonitorIndex, requiredPresentIndexes, timeoutMs, pollIntervalMs, stablePollsRequired) {
    start := A_TickCount
    requiredStablePolls := Max(2, stablePollsRequired)
    lastList := []
    lastSig := ""
    stableCount := 0

    while ((A_TickCount - start) < timeoutMs) {
        lastList := GetMonitorList()
        layoutAttempt := BuildFixedWallLayout(lastList, monitorMap, excludedMonitorIndex, requiredPresentIndexes)

        if (layoutAttempt.Ok) {
            sig := BuildMonitorSignature(lastList)

            if (sig != "" && sig = lastSig) {
                stableCount += 1
            } else {
                stableCount := 1
                lastSig := sig
            }

            if (stableCount >= requiredStablePolls)
                return {Ok: true, Wall: layoutAttempt.Wall}
        } else {
            stableCount := 0
            lastSig := ""
        }

        Sleep pollIntervalMs
    }

    finalAttempt := BuildFixedWallLayout(lastList, monitorMap, excludedMonitorIndex, requiredPresentIndexes)
    if (!finalAttempt.Ok)
        return {Ok: false, Message: finalAttempt.Message}

    return {Ok: false, Message: "Topologia monitor non stabile entro il timeout (" timeoutMs " ms)."}
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
            Height: height
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

BuildFixedWallLayout(monitors, monitorMap, excludedMonitorIndex, requiredPresentIndexes) {
    byIndex := BuildMonitorIndexMap(monitors)

    for _, mustExist in requiredPresentIndexes {
        if (!byIndex.Has(mustExist)) {
            return {Ok: false, Message: "Layout monitor non valido: manca il monitor " mustExist ". Sono richiesti i monitor 2, 3, 4 e 5."}
        }
    }

    tl := GetMonitorByIndex(monitors, monitorMap.TopLeft)
    tr := GetMonitorByIndex(monitors, monitorMap.TopRight)
    bl := GetMonitorByIndex(monitors, monitorMap.BottomLeft)
    br := GetMonitorByIndex(monitors, monitorMap.BottomRight)

    if (!tl || !tr || !bl || !br)
        return {Ok: false, Message: "Layout monitor non valido: impossibile associare tutti i quadranti del wall."}

    if (tl.Index = excludedMonitorIndex
     || tr.Index = excludedMonitorIndex
     || bl.Index = excludedMonitorIndex
     || br.Index = excludedMonitorIndex) {
        return {Ok: false, Message: "Layout monitor non valido: il monitor " excludedMonitorIndex " e' escluso e non puo' essere usato."}
    }

    return {
        Ok: true,
        Wall: {
            TopLeft: tl,
            TopRight: tr,
            BottomLeft: bl,
            BottomRight: br
        }
    }
}

OpenEdgeOnMonitor(edgePath, url, monitor, detectTimeoutMs, fullscreenDelayMs, betweenLaunchMs, profileSwitch) {
    existingSet := GetWindowHandleSet("ahk_exe msedge.exe")
    pid := 0

    runCmd := Format('"{1}" {2} --new-window "{3}"', edgePath, profileSwitch, url)

    Run runCmd, , , &pid

    hwnd := WaitForEdgeWindow(existingSet, pid, detectTimeoutMs)
    if (!hwnd)
        return 0

    if (!ForceWindowPlacementAndFullscreen(hwnd, monitor, fullscreenDelayMs, betweenLaunchMs))
        return 0

    return hwnd
}

GetWindowHandleSet(winCriteria) {
    result := Map()

    for _, hwnd in WinGetList(winCriteria)
        result[hwnd] := true

    return result
}

WaitForEdgeWindow(existingSet, pid, timeoutMs) {
    start := A_TickCount

    while (A_TickCount - start < timeoutMs) {
        if (pid) {
            byPid := WinGetList("ahk_pid " pid)
            for _, hwnd in byPid {
                if (!existingSet.Has(hwnd) && IsUsableEdgeWindow(hwnd))
                    return hwnd
            }
        }

        current := WinGetList("ahk_exe msedge.exe")
        for _, hwnd in current {
            if (!existingSet.Has(hwnd) && IsUsableEdgeWindow(hwnd))
                return hwnd
        }

        Sleep 200
    }

    return 0
}

IsUsableEdgeWindow(hwnd) {
    try {
        if !WinExist("ahk_id " hwnd)
            return false

        processName := WinGetProcessName("ahk_id " hwnd)
        if (processName != "msedge.exe")
            return false

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

    Loop 2 {
        attempt := A_Index

        if (attempt > 1) {
            ; Se il primo tentativo ha gia' attivato F11, lo disattivo prima di riprovare.
            try SendEvent "{F11}"
            Sleep 300
        }

        ApplyWindowPlacementAndFullscreen(hwnd, monitor, fullscreenDelayMs)

        if (IsWindowPlacementAcceptable(hwnd, monitor)) {
            Sleep betweenLaunchMs
            return true
        }
    }

    Sleep betweenLaunchMs
    return false
}

ApplyWindowPlacementAndFullscreen(hwnd, monitor, fullscreenDelayMs) {
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

IsWindowPlacementAcceptable(hwnd, monitor) {
    if !(hwnd && WinExist("ahk_id " hwnd))
        return false

    WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)

    if (x != monitor.Left || y != monitor.Top)
        return false

    if (w < monitor.Width - 20 || h < monitor.Height - 20)
        return false

    return true
}

DefocusBrowserWindows() {
    try {
        WinActivate "ahk_class Shell_TrayWnd"
    } catch {
        ; ignora
    }
}

BuildMonitorIndexMap(monitors) {
    m := Map()

    for _, mon in monitors
        m[mon.Index] := mon

    return m
}

ShowConfirmOnMonitor(monitor) {
    myGui := Gui("+AlwaysOnTop +ToolWindow -SysMenu")
    myGui.SetFont("s16 bold")
    myGui.AddText("w560 Center", "Buongiorno disadattato, completa il login nella finestra in alto a destra, poi premi OK per aprire automaticamente le altre tre finestre.")

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