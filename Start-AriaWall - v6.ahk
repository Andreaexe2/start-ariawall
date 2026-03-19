
#Requires AutoHotkey v2.0
#SingleInstance Force

; =========================================================
; CONFIG
; =========================================================

EdgePath := "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
if !FileExist(EdgePath)
    EdgePath := "C:\Program Files\Microsoft\Edge\Application\msedge.exe"

TopLeftUrl := "https://aria.infra.wetechs.priv/vcf-operations/ui/inventory;mode=tree;ts=vSphere%20Hosts%20and%20Clusters-VMWARE-vSphere%20World;resourceId=3ec613a6-04f1-42ee-b5c5-de0b91915f80;tab=summary"
TopRightUrl := "https://aria.infra.wetechs.priv/vcf-operations/ui/inventory;mode=tree;ts=vSphere%20Hosts%20and%20Clusters-VMWARE-vSphere%20World;resourceId=cc0eac06-8245-4449-b36b-238eeabaa5a8;tab=summary"
BottomLeftUrl := "https://aria.infra.wetechs.priv/vcf-operations/ui/operations/dashboards;tabId=338e22d0-6d15-4145-872b-4cad1982c222"
BottomRightUrl := "https://aria.infra.wetechs.priv/vcf-operations/ui/operations/dashboards;tabId=381d3bc6-492d-4c9f-a802-dbf462b75fb4"

InitialDelayMs := 15000
BetweenLaunchMs := 2500
DetectWindowTimeoutMs := 15000
FullscreenDelayMs := 1000

; =========================================================
; AVVIO
; =========================================================

Sleep InitialDelayMs

if !FileExist(EdgePath) {
    MsgBox "Microsoft Edge non trovato."
    ExitApp
}

monitors := GetMonitorList()

if monitors.Length < 4 {
    MsgBox "Servono almeno 4 monitor. Rilevati: " monitors.Length
    ExitApp
}

wall := GetWallMonitors(monitors)

OpenEdgeOnMonitor(EdgePath, TopLeftUrl, wall.TopLeft)
OpenEdgeOnMonitor(EdgePath, TopRightUrl, wall.TopRight)
OpenEdgeOnMonitor(EdgePath, BottomLeftUrl, wall.BottomLeft)
OpenEdgeOnMonitor(EdgePath, BottomRightUrl, wall.BottomRight)

ExitApp

; =========================================================
; FUNZIONI
; =========================================================

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

GetWallMonitors(monitors) {
    sortedByX := SortMonitors(monitors, "Left")
    rightCluster := [
        sortedByX[sortedByX.Length - 3],
        sortedByX[sortedByX.Length - 2],
        sortedByX[sortedByX.Length - 1],
        sortedByX[sortedByX.Length]
    ]

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
    clone := []
    for _, item in arr
        clone.Push(item)

    len := clone.Length
    if (len <= 1)
        return clone

    Loop len - 1 {
        pass := A_Index
        swapped := false

        Loop len - pass {
            j := A_Index
            if (clone[j].%prop% > clone[j + 1].%prop%) {
                tmp := clone[j]
                clone[j] := clone[j + 1]
                clone[j + 1] := tmp
                swapped := true
            }
        }

        if !swapped
            break
    }

    return clone
}

OpenEdgeOnMonitor(edgePath, url, monitor) {
    existing := WinGetList("ahk_exe msedge.exe")

    ; Qui puoi aggiungere un profilo dedicato Edge se vuoi:
    ; Run '"' edgePath '" --profile-directory="Default" --new-window --app="' url '"'
    Run '"' edgePath '" --new-window --app="' url '"'

    hwnd := WaitForNewEdgeWindow(existing, DetectWindowTimeoutMs)
    if !hwnd {
        MsgBox "Non sono riuscito a rilevare la nuova finestra Edge per:`n" url
        return
    }

    WinRestore "ahk_id " hwnd
    Sleep 300
    WinMove monitor.Left, monitor.Top, monitor.Width, monitor.Height, "ahk_id " hwnd
    Sleep 500
    WinActivate "ahk_id " hwnd
    Sleep 300
    WinMaximize "ahk_id " hwnd
    Sleep FullscreenDelayMs

    ; Fullscreen reale tipo F11
    Send "{F11}"

    Sleep BetweenLaunchMs
}

WaitForNewEdgeWindow(existingList, timeoutMs) {
    start := A_TickCount

    while (A_TickCount - start < timeoutMs) {
        current := WinGetList("ahk_exe msedge.exe")

        for _, hwnd in current {
            if !ArrayContains(existingList, hwnd) {
                try {
                    title := WinGetTitle("ahk_id " hwnd)
                    if (title != "")
                        return hwnd
                }
            }
        }

        Sleep 300
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
