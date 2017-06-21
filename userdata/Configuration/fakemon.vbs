Dim   colItems, DisplayHeight, DisplayWidth, vItem, ItemCount, UserString, colDispConfig, DispType, Nvidstr
strComputer = "."
Set objWMIService = GetObject("winmgmts:\\" & strComputer & "\root\cimv2")
Set colItems=objWMIService.ExecQuery("select * from Win32_DesktopMonitor WHERE ScreenHeight != NULL",,48)
Set colItemsXP=objWMIService.ExecQuery("select * from Win32_DesktopMonitor WHERE DeviceID = 'DeskTopMonitor1' and Availability != 8",,48)
Set colOperatingSystems = objWMIService.ExecQuery("Select * from Win32_OperatingSystem")
Set colDispConfig = objWMIService.ExecQuery("Select * from Win32_DisplayControllerConfiguration")

For Each DispConf in colDispConfig
  DispType = DispConf.Name
  Next
Nvidstr = "GeForce GT 610"

'Set WshShell Variable and WshNetwork Variable
Set WshShell = WScript.CreateObject("WScript.Shell")
Set WshNetwork = WScript.CreateObject("WScript.Network")

'Set UserString Variable
UserString = WshNetwork.UserName

Function arrLength(vArray)
  ItemCount = 0
  For Each vItem in vArray
    ItemCount = ItemCount + 1
  Next
  arrLength = ItemCount
End Function

Function GetOS()
  For Each objOperatingSystem in colOperatingSystems
  'GetOS = objOperatingSystem.Caption & " " & objOperatingSystem.Version
  GetOS = objOperatingSystem.Version
  Next
End Function

Function AddMon()
  'Run Control Panel to open Display Properties
  WshShell.Run("%windir%\system32\control.exe desk.cpl @0,4")
  'Set focus on Display Properties window and wait 1000 milliseconds
  'Due to this script running at login I've set a 10000 ms sleep time
  'so that all other programs will be finished loading so not to interfere
  'with the focus on the "Display Properties" window.
  WScript.Sleep 10000
  WshShell.AppActivate ("Screen Resolution")
  WScript.Sleep 100
  'Send Keys to add display
  WshShell.SendKeys"%"
  WScript.Sleep 10
  WshShell.SendKeys"%"
  WScript.Sleep 10     
  WshShell.SendKeys"{TAB}"
  WScript.Sleep 10
  WshShell.SendKeys"{TAB}"
  WScript.Sleep 10
  WshShell.SendKeys"{TAB}"
  WScript.Sleep 10     
  WshShell.SendKeys"%c"
  WScript.Sleep 30
  WshShell.SendKeys"%s"
  WScript.Sleep 30
  WshShell.SendKeys"{DOWN}"
  WScript.Sleep 30
  WshShell.SendKeys"%m"
  WScript.Sleep 30
  WshShell.SendKeys"{DOWN}"
  WScript.Sleep 30
  WshShell.SendKeys"%a"
  WScript.Sleep 10
  WshShell.SendKeys"^w"
  WScript.Sleep 100
End Function

Function w8AddMon()
  'Run Control Panel to open Display Properties
  WshShell.Run("%windir%\system32\control.exe desk.cpl @0,4")
  'Set focus on Display Properties window and wait 1000 milliseconds
  'Due to this script running at login I've set a 10000 ms sleep time
  'so that all other programs will be finished loading so not to interfere
  'with the focus on the "Display Properties" window.
  WScript.Sleep 10000
  WshShell.AppActivate ("Screen Resolution")
  WScript.Sleep 100
  'Send Keys to add display
  WshShell.SendKeys"%"
  WScript.Sleep 10
  WshShell.SendKeys"%"
  WScript.Sleep 10     
  WshShell.SendKeys"{TAB}"
  WScript.Sleep 10
  WshShell.SendKeys"{TAB}"
  WScript.Sleep 10
  WshShell.SendKeys"{TAB}"
  WScript.Sleep 10     
  WshShell.SendKeys"%c"
  WScript.Sleep 30
  WshShell.SendKeys"%s"
  WScript.Sleep 30
  WshShell.SendKeys"{DOWN}"
  WScript.Sleep 30
  WshShell.SendKeys"%m"
  WScript.Sleep 30
  WshShell.SendKeys"{DOWN}"
  WScript.Sleep 30
  WshShell.SendKeys"%a"
  WScript.Sleep 10
  WshShell.SendKeys"^w"
  WScript.Sleep 100
End Function

Function RemMonXP()
  'Run Control Panel to open Display Properties
  WshShell.Run("%windir%\system32\control.exe desk.cpl @0,3")
  'Set focus on Display Properties window and wait 1000 milliseconds
  'Due to this script running at login I've set a 10000 ms sleep time
  'so that all other programs will be finished loading so not to interfere
  'with the focus on the "Display Properties" window.
  WScript.Sleep 10000
  WshShell.AppActivate ("Display Properties")
  WScript.Sleep 100
  'Send Keys to add display
  WshShell.SendKeys"2"
  WScript.Sleep 10
  WshShell.SendKeys"%u"
  WScript.Sleep 10
  WshShell.SendKeys"1"
  WScript.Sleep 10
  WshShell.SendKeys"%e"
  WScript.Sleep 10 
  WshShell.SendKeys"%a"
  WScript.Sleep 100     
  WshShell.SendKeys"{ESC}"
  WScript.Sleep 10
End Function

Function Main()
  'WScript.Echo("test" & GetOs & "test") 
  OSVer = GetOS()
  OSVer = Left(OSVer,3)
  'WScript.Echo("test" & OSVer & "test") 
  'WScript.Quit
  If OSVer = 6.2 Then
    If Not(DispType =  Nvidstr) Then
      If arrLength(colItems) => 1 Then
        Call w8AddMon
      End If
    End If
  End If
  If ((UserString = "cltbld") Or (StrComp(UserString, "GenericWorker", 1) = 0) Or (InStr(1, UserString, "task_", 1) > 0)) Then
    If OSVer = 10. Then
      WshShell.Run("cmd /c configmymonitor v0 r160")
      WScript.Sleep 100
      'WshShell.Run("displayswitch /internal")
      'WScript.Sleep 10
      WshShell.Run("cmd /c configmymonitor v0 r160")
    End If
    If OSVer = 6.2 Then
      If DispType = Nvidstr Then
        WshShell.Run("cmd /c configmymonitor v0 r160")
        WScript.Sleep 100
        WshShell.Run("cmd /c configmymonitor v0 r160")
      Else
        WshShell.Run("cmd /c configmymonitor v1 r160")
        WScript.Sleep 100
        WshShell.Run("displayswitch /internal")
        WScript.Sleep 10
        WshShell.Run("cmd /c configmymonitor v1 r160")
      End If
    End If
    If OSVer = 6.1 Then
      WshShell.Run("cmd /c configmymonitor v0 r160")
      WScript.Sleep 100
      'WshShell.Run("displayswitch /internal")
      'WScript.Sleep 10
      WshShell.Run("cmd /c configmymonitor v0 r160")
    End If
    If OSVer = 5.1  Then
      WshShell.Run("cmd /c configmymonitor enable v1")
      WScript.Sleep 100
      WshShell.Run("cmd /c configmymonitor v1 r423")
      WScript.Sleep 10
      WshShell.Run("cmd /c configmymonitor disable v0")
      If arrLength(colItemsXP) => 1 then
        Call RemMonXP
      End If
    End If
  End If
End Function

Call Main
WScript.Quit