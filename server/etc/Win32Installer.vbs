'
' $Id$
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

' Start the Roxen Service.
'
' This kludge is needed to delay the start of the service until
' after COMMIT, which is needed to allow the side-by-side assemblies
' to complete installation before we try to use them.
'
' Why couldn't MS do the senisible thing and have inodes instead of
' having kludges upon kludges to work around their design bugs?
' Both side-by-side assemblies and their activation after COMMIT
' are kludges around the lack of inodes.
Function StartRoxenService()
  Dim WshShell

  Set WshShell = CreateObject("WScript.Shell")

  WshShell.Run "NET START RoxenService", 0, True

  StartRoxenService = 1
End Function

' At call time the CustomActionData property has been set to
' [SERVERDIR];[MYSQLBASE];[MYSQLDEXE];[MYISAMCHKEXE];[MYSQLADMINEXE].
'
' Creates "[SERVERDIR]mysql-location.txt" with the
' content "basedir=[MYSQLBASE]"
'         "mysqld=[MYSQLDEXE]"
'         "myisamchk=[MYISAMCHKEXE]"
'         "mysqladmin=[MYSQLADMINEXE]"
Function CreateMysqlLocation()
  Dim re, matches, match, fso, tf, serverdir, mysqlbase, mysqld, myisamchk, i
  Dim rest

  serverdir = ""
  mysqlbase = ""
  mysqld = ""
  myisamchk = ""
  mysqladmin = ""

  rest = ""

  Set re = New RegExp
  re.Pattern = "[^;]*"
  re.Global = True
  Set matches = re.Execute(Session.Property("CustomActionData"))
  i = 0
  For Each match in matches
    ' NOTE: For some reason we get an empty match after each true match.
    '       Therefore we only look at the matches where i is even.
    If i = 0 Then
      serverdir = match.Value
    Else
      If i = 2 Then
        mysqlbase = match.Value
      Else
        If i = 4 Then
          mysqld = match.Value
        Else
          If i = 6 Then
            myisamchk = match.Value
	  Else
            If i = 8 Then
              mysqladmin = match.Value
	    Else
	      rest = rest & ";" & match.Value
            End If
          End If
        End If
      End If
    End If
    i = i + 1
  Next

  Set fso = CreateObject("Scripting.FileSystemObject")

  Set tf = fso.CreateTextFile(serverdir & "mysql-location.txt", True)
  tf.writeLine("# Created by $Id$")
  tf.writeLine("# DEBUG: " & Session.Property("CustomActionData"))
  tf.writeLine("# DEBUG: " & rest & ";")
  tf.writeLine("")
  tf.writeLine("# Configuration file for locating the MySQL installation.")
  tf.writeLine("")
  tf.writeLine("# Note that the keys are case-sensitive and must be")
  tf.writeLine("# provided in lower-case.")
  tf.writeLine("")
  tf.writeLine("# basedir is the base directory for the MySQL installation.")
  tf.writeLine("basedir=" & mysqlbase)
  tf.writeLine("# mysqld is the full path to the mysqld binary.")
  If mysqld <> "" Then
    tf.writeLine("mysqld=" & mysqld)
  Else
    tf.writeLine("#mysqld=")
  End If
  tf.writeLine("# myisamchk is the full path to the myisamchk binary.")
  If myisamchk <> "" Then
    tf.writeLine("myisamchk=" & myisamchk)
  Else
    tf.writeLine("#myisamchk=")
  End If
  tf.writeLine("# mysqladmin is the full path to the mysqladmin binary.")
  If mysqladmin <> "" Then
    tf.writeLine("mysqladmin=" & mysqladmin)
  Else
    tf.writeLine("#mysqladmin=")
  End If
  tf.Close

  CreateMysqlLocation = 1
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

Function CreateEnvironment()
  Dim envfile, fso, tf
  Set fso = CreateObject("Scripting.FileSystemObject")

  envfile = Session.Property("CustomActionData")

  If (Not fso.FileExists(envfile)) Then
    Set tf = fso.CreateTextFile(envfile, True)
    tf.WriteLine("[Parameters]")
    tf.WriteLine("default= ")
    tf.WriteLine("[Environment]")
    tf.WriteLine("_JAVA_OPTIONS=-Xmx256M")
    tf.Close
  End If
End Function
