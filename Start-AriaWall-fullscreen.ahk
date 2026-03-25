#Requires AutoHotkey v2.0
#SingleInstance Force

; =========================================================
; CONFIG
; =========================================================

TopLeftUrl := "https://aria.infra.wetechs.priv/vcf-operations/ui/inventory;mode=tree;ts=vSphere%20Hosts%20and%20Clusters-VMWARE-vSphere%20World;resourceId=3ec613a6-04f1-42ee-b5c5-de0b91915f80;tab=summary"
TopRightUrl := "https://aria.infra.wetechs.priv/vcf-operations/ui/inventory;mode=tree;ts=vSphere%20Hosts%20and%20Clusters-VMWARE-vSphere%20World;resourceId=cc0eac06-8245-4449-b36b-238eeabaa5a8;tab=summary"
BottomLeftUrl := "https://aria.infra.wetechs.priv/vcf-operations/ui/operations/dashboards;tabId=338e22d0-6d15-4145-872b-4cad1982c222"
BottomRightUrl := "https://ws-wb1-i-wug01.infra.wetechs.priv/NmConsole/#v=Wug_view_nocviewer_NocViewer/p=%7B%22isMainView%22%3Atrue%2C%22DeckId%22%3A1%7D"

InitialDelayMs := 5000
BetweenLaunchMs := 400
DetectWindowTimeoutMs := 12000
FullscreenDelayMs := 300

; =========================================================
; HOOK/MOD:
; attesa configurazione monitor stabile
; =========================================================
RequiredMonitorCount := 4
MonitorPollIntervalMs := 2000
MonitorWaitTimeoutMs := 90000
StablePollsRequired := 2

; =========================================================
; HOOK/MOD:
; esclude i monitor piccoli.
; 0.70 = considero wall solo i monitor con area >= 70% del più grande
; Se il monitor piccolo dovesse ancora rientrare, alza a 0.75 o 0.80
; =========================================================
WallMonitorMinAreaRatio := 0.70

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

wall := SelectWallMonitors(monitors)
if (!wall) {
    MsgBox "Impossibile identificare correttamente i 4 monitor grandi del wall."
    ExitApp
}

; 1) Apro solo la finestra in alto a sinistra
global HwndTL := OpenEdgeOnMonitor(edgePath, TopLeftUrl, wall.TopLeft, DetectWindowTimeoutMs, FullscreenDelayMs, BetweenLaunchMs, ProfileSwitch)
if (!HwndTL) {
    MsgBox "Non sono riuscito ad aprire la finestra iniziale (alto sinistra)."
    ExitApp
}

; 2) Popup sul monitor in alto a destra, senza rubare il focus
ShowConfirmOnMonitor(wall.TopRight, HwndTL, wall.TopLeft)

; 3) Dopo OK apro le altre 3 finestre
global HwndTR := OpenEdgeOnMonitor(edgePath, TopRightUrl, wall.TopRight, DetectWindowTimeoutMs, FullscreenDelayMs, BetweenLaunchMs, ProfileSwitch)
global HwndBL := OpenEdgeOnMonitor(edgePath, BottomLeftUrl, wall.BottomLeft, DetectWindowTimeoutMs, FullscreenDelayMs, BetweenLaunchMs, ProfileSwitch)
global HwndBR := OpenEdgeOnMonitor(edgePath, BottomRightUrl, wall.BottomRight, DetectWindowTimeoutMs, FullscreenDelayMs, BetweenLaunchMs, ProfileSwitch)

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

GetLargestArea(monitors) {
    maxArea := 0
    for _, m in monitors {
        if (m.Area > maxArea)
            maxArea := m.Area
    }
    return maxArea
}

GetBigWallCandidates(monitors) {
    global WallMonitorMinAreaRatio

    maxArea := GetLargestArea(monitors)
    minArea := Floor(maxArea * WallMonitorMinAreaRatio)

    result := []
    for _, m in monitors {
        if (m.Area >= minArea)
            result.Push(m)
    }

    return result
}

GetLargestMonitors(monitors, howMany) {
    sorted := SortMonitors(monitors, "Area", true)
    result := []

    limit := Min(howMany, sorted.Length)
    Loop limit {
        result.Push(sorted[A_Index])
    }

    return result
}

GetRightmostMonitors(monitors, howMany) {
    sorted := SortMonitors(monitors, "Left", true)
    result := []

    limit := Min(howMany, sorted.Length)
    Loop limit {
        result.Push(sorted[A_Index])
    }

    return result
}

SelectWallMonitors(monitors) {
    if (monitors.Length < 4)
        return 0

    ; 1) esclude i monitor piccoli
    wallCandidates := GetBigWallCandidates(monitors)

    ; 2) se per qualche motivo ne trova più di 4, prende i 4 più a destra tra quelli grandi
    if (wallCandidates.Length > 4)
        wallCandidates := GetRightmostMonitors(wallCandidates, 4)

    ; 3) fallback: se ne trova meno di 4, prende comunque i 4 più grandi
    if (wallCandidates.Length < 4)
        wallCandidates := GetLargestMonitors(monitors, 4)

    if (wallCandidates.Length < 4)
        return 0

    ; divide in alto/basso usando il centro verticale
    sortedByCenterY := SortMonitors(wallCandidates, "CenterY", false)

    topTwo := [sortedByCenterY[1], sortedByCenterY[2]]
    bottomTwo := [sortedByCenterY[3], sortedByCenterY[4]]

    ; dentro ogni riga divide sinistra/destra
    topSorted := SortMonitors(topTwo, "CenterX", false)
    bottomSorted := SortMonitors(bottomTwo, "CenterX", false)

    return {
        TopLeft: topSorted[1],
        TopRight: topSorted[2],
        BottomLeft: bottomSorted[1],
        BottomRight: bottomSorted[2]
    }
}

SortMonitors(arr, prop, descending := false) {
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

            leftVal := copy[j].%prop%
            rightVal := copy[j + 1].%prop%

            shouldSwap := false
            if (descending) {
                if (leftVal < rightVal)
                    shouldSwap := true
            } else {
                if (leftVal > rightVal)
                    shouldSwap := true
            }

            if (shouldSwap) {
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

    WinRestore "ahk_id " hwnd
    Sleep 150

    WinMove monitor.Left, monitor.Top, monitor.Width, monitor.Height, "ahk_id " hwnd
    Sleep 250

    WinActivate "ahk_id " hwnd
    WinWaitActive "ahk_id " hwnd, , 3
    Sleep 150

    WinMaximize "ahk_id " hwnd
    Sleep fullscreenDelayMs

    WinActivate "ahk_id " hwnd
    Sleep 150
    SendEvent "{F11}"
    Sleep 350

    WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)

    if (x != monitor.Left || y != monitor.Top || w < monitor.Width || h < monitor.Height) {
        WinRestore "ahk_id " hwnd
        Sleep 150
        WinMove monitor.Left, monitor.Top, monitor.Width, monitor.Height, "ahk_id " hwnd
        Sleep 250
        WinActivate "ahk_id " hwnd
        WinWaitActive "ahk_id " hwnd, , 3
        Sleep 150
        WinMaximize "ahk_id " hwnd
        Sleep fullscreenDelayMs
        SendEvent "{F11}"
        Sleep 350
    }

    Sleep betweenLaunchMs
    return true
}

ArrayContains(arr, value) {
    for _, item in arr {
        if (item = value)
            return true
    }
    return false
}

ShowConfirmOnMonitor(monitor, firstHwnd, firstMonitor) {
    myGui := Gui("+AlwaysOnTop +ToolWindow -SysMenu")
    myGui.SetFont("s16 bold")
    myGui.AddText("w560 Center", "Completa il login nella finestra in alto a sinistra, poi premi OK per aprire automaticamente le altre tre finestre.")

    okBtn := myGui.AddButton("w160 h50 Default", "OK")
    okBtn.OnEvent("Click", (*) => (
        ForceWindowPlacementAndFullscreen(firstHwnd, firstMonitor, 250, 100),
        myGui.Destroy()
    ))

    myGui.Show("AutoSize Hide")

    xOut := 0, yOut := 0, wOut := 0, hOut := 0
    myGui.GetPos(&xOut, &yOut, &wOut, &hOut)

    xPos := monitor.Left + Floor((monitor.Width - wOut) / 2)
    yPos := monitor.Top + Floor((monitor.Height - hOut) / 2)

    myGui.Show(Format("x{} y{} NoActivate", xPos, yPos))

    WinWaitClose("ahk_id " myGui.Hwnd)
    return true
}