' -*- vhdl-mode -*-
'
' $Id: Win32Installer.vbs,v 1.3 2004/11/30 17:13:14 grubba Exp $
'
' Companion file to RoxenUI.wxs with custom actions.
'
' 2004-11-29 Henrik Grubbström
'

' At call time the CustomActionData proprty has been set to [SERVERDIR].
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
