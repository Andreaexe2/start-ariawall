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
BetweenLaunchMs := 300
DetectWindowTimeoutMs := 5000
FullscreenDelayMs := 200

; =========================================================
; HOOK/MOD:
; attesa monitor reali all'avvio
; =========================================================
RequiredMonitorCount := 4
MonitorPollIntervalMs := 2000
MonitorWaitTimeoutMs := 60000   ; aspetta fino a 60 secondi

; HOOK/MOD:
; se vuoi cambiare profilo Edge, modifica solo questa riga
ProfileSwitch := '--user-data-dir="C:\Users\ServiceDesk\Desktop\start-ariawall\EdgeProfile"'

; HOOK/MOD:
; false = finestra Edge normale
; true  = usa --app
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

monitors := WaitForRequiredMonitors(RequiredMonitorCount, MonitorWaitTimeoutMs, MonitorPollIntervalMs)

if (monitors.Length < RequiredMonitorCount) {
    MsgBox "Dopo l'attesa Windows vede ancora solo " monitors.Length " monitor. Procedo comunque, ma il posizionamento potrebbe essere errato."
}

wall := SelectWallMonitors(monitors)

; 1) Apro solo la finestra in alto a sinistra
global HwndTL := OpenEdgeOnMonitor(edgePath, TopLeftUrl, wall.TopLeft, DetectWindowTimeoutMs, FullscreenDelayMs, BetweenLaunchMs, ProfileSwitch)
if (!HwndTL) {
    MsgBox "Non sono riuscito ad aprire la finestra iniziale (alto sinistra)."
    ExitApp
}

; 2) Mostro il popup sul monitor a destra per dare tempo al login
ShowConfirmOnMonitor(wall.TopRight)

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

WaitForRequiredMonitors(requiredCount, timeoutMs, pollIntervalMs) {
    start := A_TickCount
    lastList := GetMonitorList()

    while ((A_TickCount - start) < timeoutMs) {
        lastList := GetMonitorList()

        if (lastList.Length >= requiredCount)
            return lastList

        Sleep pollIntervalMs
    }

    return lastList
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

    ; fallback: se ci sono meno di 4 monitor, usa quelli disponibili
    if (sortedByX.Length < 4) {
        m1 := sortedByX.Length >= 1 ? sortedByX[1] : {Left: 0, Top: 0, Width: 1920, Height: 1080}
        m2 := sortedByX.Length >= 2 ? sortedByX[2] : m1
        m3 := sortedByX.Length >= 3 ? sortedByX[3] : m1

        return {
            TopLeft: m1,
            TopRight: m2,
            BottomLeft: m3,
            BottomRight: m2
        }
    }

    ; prende i 4 monitor piu' a destra
    startIdx := sortedByX.Length - 3
    rightCluster := []

    Loop 4 {
        rightCluster.Push(sortedByX[startIdx + A_Index - 1])
    }

    ; divide in alto/basso
    sortedByY := SortMonitors(rightCluster, "Top")
    topTwo := [sortedByY[1], sortedByY[2]]
    bottomTwo := [sortedByY[3], sortedByY[4]]

    ; divide in sinistra/destra
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

    Run runCmd

    hwnd := WaitForNewEdgeWindow(existing, detectTimeoutMs)
    if (!hwnd)
        return 0

    WinRestore "ahk_id " hwnd
    Sleep 150

    WinMove monitor.Left, monitor.Top, monitor.Width, monitor.Height, "ahk_id " hwnd
    Sleep 250

    WinActivate "ahk_id " hwnd
    WinWaitActive "ahk_id " hwnd, , 2
    Sleep 150

    WinMaximize "ahk_id " hwnd
    Sleep fullscreenDelayMs

    WinActivate "ahk_id " hwnd
    Sleep 150
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

        Sleep 200
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
    myGui.AddText("w560 Center", "Completa il login nella finestra in alto a sinistra, poi premi OK per aprire automaticamente le altre tre finestre.")

    okBtn := myGui.AddButton("w160 h50 Default", "OK")
    okBtn.OnEvent("Click", (*) => myGui.Destroy())

    myGui.Show("AutoSize Hide")

    xOut := 0, yOut := 0, wOut := 0, hOut := 0
    myGui.GetPos(&xOut, &yOut, &wOut, &hOut)

    xPos := monitor.Left + Floor((monitor.Width - wOut) / 2)
    yPos := monitor.Top + Floor((monitor.Height - hOut) / 2)

    ; mostra il popup senza rubare il focus alla finestra Edge
    myGui.Show(Format("x{} y{} NoActivate", xPos, yPos))

    WinWaitClose("ahk_id " myGui.Hwnd)
    return true
}