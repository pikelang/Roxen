'
' $Id: Win32Installer.vbs,v 1.10 2004/12/07 17:27:09 grubba Exp $
'
' Companion file to RoxenUI.wxs with custom actions.
'
' 2004-11-29 Henrik Grubbström
'

' At call time the CustomActionData property has been set to [TARGETDIR].
'
' Remove any previously installed service.
Function RemoveOldService()
  Dim WshShell, serverdir

  targetdir = Session.Property("CustomActionData")

  Set WshShell = CreateObject("WScript.Shell")
  WshShell.CurrentDirectory = targetdir

  WshShell.Run """" & targetdir & "ntstart"" --remove", 0, True

  RemoveOldService = 1
End Function

' At call time the CustomActionData property has been set to [SERVERDIR].
'
' Creates "[SERVERDIR]pikelocation.txt" with the
' content "[SERVERDIR]pike\bin\pike"
Function CreatePikeLocation()
  Dim fso, tf, serverdir
  Set fso = CreateObject("Scripting.FileSystemObject")

  serverdir = Session.Property("CustomActionData")

  Set tf = fso.CreateTextFile(serverdir & "pikelocation.txt", True)
  tf.WriteLine(serverdir & "pike\bin\pike")
  tf.Close

  CreatePikeLocation = 1
End Function

' At call time the CustomActionData property has been set to
' [SERVERDIR];[SERVER_NAME];[SERVER_PROTOCOL];[SERVER_PORT];[ADM_USER];[ADM_PASS1]
'
' Create a new configinterface.
Function CreateConfigInterface()
  Dim re, matches, match, WshShell, serverdir
  Set re = New RegExp
  re.Pattern = "[^;]*"
  re.Global = False
  Set matches = re.Execute(Session.Property("CustomActionData"))
  For Each match in matches
    serverdir = match.Value
  Next

  Set WshShell = CreateObject("WScript.Shell")
  WshShell.Run """" & serverdir & "pike\bin\pike"" """ & serverdir &_
    "bin\create_configif.pike"" --batch __semicolon_separated__ """ &_
    Session.Property("CustomActionData") & """ ok y update n", 0, True

  CreateConfigInterface = 1
End Function
