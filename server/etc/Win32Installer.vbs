'
' $Id: Win32Installer.vbs,v 1.2 2004/11/29 17:43:09 grubba Exp $
'
' Companion file to RoxenUI.wxs with custom actions.
'
' 2004-11-29 Henrik Grubbström
'

' Creates "[SERVERDIR]pikelocation.txt" with the
' content "[SERVERDIR]pike\bin\pike"

Function CreatePikeLocation()
    Dim fso, tf, serverdir
    Set fso = CreateObject("Scripting.FileSystemObject")

    serverdir = Session.Property("SERVERDIR")

    Set tf = fso.CreateTextFile(serverdir & "pikelocation.txt", True)
    tf.WriteLine(serverdir & "pike\bin\pike")
    tf.Close

    CreatePikeLocation = 1
End Function
