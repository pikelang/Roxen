'
' $Id: Win32Installer.vbs,v 1.1 2004/11/29 16:47:55 grubba Exp $
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

    Set tf = fso.CreateTextFile(serverdir &amp; "pikelocation.txt", True)
    tf.WriteLine(serverdir &amp; "pike\bin\pike")
    tf.Close

    CreatePikeLocation = 1
End Function
