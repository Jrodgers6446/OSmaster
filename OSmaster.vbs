' OSmaster.vbs
' Double-click this to launch OSmaster with no console/PowerShell window
' visible -- just the app window itself. You'll still see the standard
' Windows UAC elevation prompt once (that's required by Windows for any
' admin-rights app and can't be skipped or hidden), but after approving
' it, only the OSmaster window appears.

Set objFSO = CreateObject("Scripting.FileSystemObject")
strFolder = objFSO.GetParentFolderName(WScript.ScriptFullName)
strScript = strFolder & "\OSmaster-GUI.ps1"

Set objShell = CreateObject("Shell.Application")
objShell.ShellExecute "powershell.exe", _
    "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File """ & strScript & """", _
    "", "runas", 0
