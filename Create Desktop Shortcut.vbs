' Create Desktop Shortcut.vbs
' Run this ONCE after unzipping OSmaster to a permanent location (e.g.
' C:\Tools\OSmaster). It creates a real Desktop icon with a custom icon,
' pointing back to OSmaster.vbs (the silent launcher) wherever this
' folder ends up. After running this, use the Desktop icon like any
' normal app -- you won't need to open this folder again.

Set objFSO = CreateObject("Scripting.FileSystemObject")
strFolder = objFSO.GetParentFolderName(WScript.ScriptFullName)

Set objShell = CreateObject("WScript.Shell")
strDesktop = objShell.SpecialFolders("Desktop")

Set objLink = objShell.CreateShortcut(strDesktop & "\OSmaster.lnk")
objLink.TargetPath = strFolder & "\OSmaster.vbs"
objLink.WorkingDirectory = strFolder
objLink.IconLocation = strFolder & "\icon.ico"
objLink.Description = "OSmaster - OS deployment and console recovery toolkit"
objLink.Save

MsgBox "Desktop shortcut created." & vbCrLf & vbCrLf & _
       "You can now launch OSmaster from your Desktop like any other app." & vbCrLf & vbCrLf & _
       "Note: if you move this folder later, run this script again from its new location to fix the shortcut.", _
       vbInformation, "OSmaster Setup"
