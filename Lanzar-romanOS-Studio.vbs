' =====================================================================
' romanOS Studio - Lanzador Silencioso Nativo (WScript / VBScript)
' Ejecuta romanOS-Studio.ps1 en segundo plano sin ventana de consola CMD/PowerShell.
' =====================================================================
Option Explicit

Dim WshShell, FSO, strDir, strPS, strScript, strArgs

Set WshShell = CreateObject("WScript.Shell")
Set FSO = CreateObject("Scripting.FileSystemObject")

strDir = FSO.GetParentFolderName(WScript.ScriptFullName)
strPS = WshShell.ExpandEnvironmentStrings("%SystemRoot%") & "\System32\WindowsPowerShell\v1.0\powershell.exe"
strScript = strDir & "\scripts\GUI\romanOS-Studio.ps1"
strArgs = "-WindowStyle Hidden -STA -NoProfile -ExecutionPolicy Bypass -File """ & strScript & """"

' Ejecutar en modo oculto (0 = SW_HIDE) y no esperar a que termine (False)
WshShell.Run """" & strPS & """ " & strArgs, 0, False

Set WshShell = Nothing
Set FSO = Nothing
