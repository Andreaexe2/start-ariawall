#Requires AutoHotkey v2.0
#SingleInstance Force

; =========================================================
; CONFIG
; =========================================================

TopLeftUrl := "https://aria.infra.wetechs.priv/vcf-operations/ui/inventory;mode=tree;ts=vSphere%20Hosts%20and%20Clusters-VMWARE-vSphere%20World;resourceId=3ec613a6-04f1-42ee-b5c5-de0b91915f80;tab=summary"
TopRightUrl := "https://aria.infra.wetechs.priv/vcf-operations/ui/inventory;mode=tree;ts=vSphere%20Hosts%20and%20Clusters-VMWARE-vSphere%20World;resourceId=cc0eac06-8245-4449-b36b-238eeabaa5a8;tab=summary"
BottomLeftUrl := "https://aria.infra.wetechs.priv/vcf-operations/ui/operations/dashboards;tabId=338e22d0-6d15-4145-872b-4cad1982c222"
BottomRightUrl := "https://ws-wb1-i-wug01.infra.wetechs.priv/NmConsole/#v=Wug_view_nocviewer_NocViewer/p=%7B%22isMainView%22%3Atrue%2C%22DeckId%22%3A1%7D"

InitialDelayMs := 15000
BetweenLaunchMs := 2000
DetectWindowTimeoutMs := 15000
FullscreenDelayMs := 800

; HOOK/MOD:
; se vuoi cambiare profilo Edge, modifica solo questa riga
ProfileSwitch := '--user-data-dir="C:\Users\ServiceDesk\Desktop\start-ariawall\EdgeProfile"'

; HOOK/MOD:
; lascia false per usare finestre Edge normali
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

OpenEdgeOnMonitor(edgePath, TopLeftUrl, wall.TopLeft, DetectWindowTimeoutMs, FullscreenDelayMs, BetweenLaunchMs, ProfileSwitch)
OpenEdgeOnMonitor(edgePath, TopRightUrl, wall.TopRight, DetectWindowTimeoutMs, FullscreenDelayMs, BetweenLaunchMs, ProfileSwitch)
OpenEdgeOnMonitor(edgePath, BottomLeftUrl, wall.BottomLeft, DetectWindowTimeoutMs, FullscreenDelayMs, BetweenLaunchMs, ProfileSwitch)
OpenEdgeOnMonitor(edgePath, BottomRightUrl, wall.BottomRight, DetectWindowTimeoutMs, FullscreenDelayMs, BetweenLaunchMs, ProfileSwitch)

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

    ; Prende i 4 monitor piu' a destra
    startIdx := sortedByX.Length - 3
    rightCluster := []

    Loop 4 {
        rightCluster.Push(sortedByX[startIdx + A_Index - 1])
    }

    ; Divide in alto/basso
    sortedByY := SortMonitors(rightCluster, "Top")
    topTwo := [sortedByY[1], sortedByY[2]]
    bottomTwo := [sortedByY[3], sortedByY[4]]

    ; Divide in sinistra/destra
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

    ; HOOK/MOD:
    ; qui puoi cambiare tra finestra normale e app mode
    if (OpenInAppMode)
        runCmd := Format('"{1}" {2} --new-window --app="{3}"', edgePath, profileSwitch, url)
    else
        runCmd := Format('"{1}" {2} --new-window "{3}"', edgePath, profileSwitch, url)

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