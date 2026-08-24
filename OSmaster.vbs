' OSmaster.vbs
' Double-click this to launch OSmaster with no console/PowerShell window
' visible -- just the app window. You'll see the standard Windows UAC
' elevation prompt once (required by Windows for any admin-rights app,
' can't be skipped or hidden). The app itself will offer to create a
' Desktop shortcut the first time it opens.

Set objFSO = CreateObject("Scripting.FileSystemObject")
strFolder = objFSO.GetParentFolderName(WScript.ScriptFullName)
strScript = strFolder & "\OSmaster-GUI.ps1"

Set objShell = CreateObject("Shell.Application")
objShell.ShellExecute "powershell.exe", _
    "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File """ & strScript & """", _
    "", "runas", 0
