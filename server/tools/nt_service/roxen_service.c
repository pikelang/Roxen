/* Program to start Roxen as a service or in console mode on NT.
 *
 * Based on the service example code from Microsoft.
 *
 * $Id: roxen_service.c,v 1.2 2000/06/28 01:39:42 mast Exp $
 */

#include <windows.h>

#include <direct.h>
#include <stdio.h>
#include <stdlib.h>
#include <process.h>
#include <tchar.h>
#include "roxen_service.h"
#include <time.h>
#include <stdarg.h>
#include <ctype.h>

#define LOCATION_COOKIE "(#*&)@(*&$Server Location Cookie:"
#define DEFAULT_LOCATION "C:\\Program Files\\Roxen Internet Software\\WebServer\\server"

char server_location[_MAX_PATH * 2] = LOCATION_COOKIE DEFAULT_LOCATION;

/* this event is signalled when the
   service should end */
HANDLE hServerStopEvent = NULL;
HANDLE hProcess;
DWORD ExitCode = 0;

char key[9];
int stopping = 0;

int start_roxen();

void error_msg (int show_last_err, const TCHAR *fmt, ...)
{
  va_list args;
  TCHAR *sep = fmt[0] ? TEXT(": ") : TEXT("");
  TCHAR buf[4098];
  size_t n;

  va_start (args, fmt);
  n = _vsntprintf (buf, sizeof (buf), fmt, args);

  if (show_last_err && (ExitCode = GetLastError())) {
    LPVOID lpMsgBuf;
    FormatMessage( FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM,
		   NULL,
		   ExitCode,
		   MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT), /* Default language */
		   (LPTSTR) &lpMsgBuf,
		   0,
		   NULL );
    _sntprintf (buf + n, sizeof (buf) - n, "%s%s", sep, lpMsgBuf);
    LocalFree (lpMsgBuf);
  }

  buf[4097] = 0;

  if (console_mode)
    _ftprintf (stderr, "%s\n", buf);
  else
    AddToMessageLog (buf);
}

VOID ServiceStart()
{
    HANDLE hEvents[2] = {NULL, NULL};
    int got_error = 0;

    srand(time(0));

    /* report the status to the service control manager. */
    if (!ReportStatusToSCMgr(
	SERVICE_START_PENDING,	// service state
	NO_ERROR, 0,		// exit code
	3000))			// wait hint
	goto error_cleanup;

    /* create the event object. The control handler function signals
       this event when it receives the "stop" control code. */
    hServerStopEvent = CreateEvent(
	NULL,    /* no security attributes */
	TRUE,    /* manual reset event */
	FALSE,   /* not-signalled */
	NULL);   /* no name */

    if ( hServerStopEvent == NULL)
	goto error_cleanup;

    hEvents[0] = hServerStopEvent;

    /* create the event object object use in overlapped i/o */
    hEvents[1] = CreateEvent(
	NULL,    /* no security attributes */
	TRUE,    /* manual reset event */
	FALSE,   /* not-signalled */
	NULL);   /* no name */

    if ( hEvents[1] == NULL)
	goto error_cleanup;

    /* Start roxen */
    if (!start_roxen())
      goto error_cleanup;

    /* report the status to the service control manager. */
    if (!ReportStatusToSCMgr(
	SERVICE_RUNNING,	/* service state */
	NO_ERROR, 0,		/* exit code */
	0))			/* wait hint */
	goto error_cleanup;

    /* Service is now running, perform work until shutdown */

    while(!stopping)
    {
      if(GetExitCodeProcess( hProcess, &ExitCode ))
      {
	if(ExitCode!=STILL_ACTIVE)
	{
	  if(ExitCode==0)	/* Shutdown */
	  {
	    if(hServerStopEvent)
	      SetEvent(hServerStopEvent);
	    break;
	  }
	  else			/* Restart */
	    if (!start_roxen())
	      goto error_cleanup;
	}
      }
      else error_msg (1, TEXT(""));
      Sleep(1000);    /* 1 sec */
    }

    if (0) {
    error_cleanup:
      got_error = 1;
    }

    if (hServerStopEvent) {
	CloseHandle(hServerStopEvent);
	hServerStopEvent = NULL;
    }

    if (hEvents[1]) /* overlapped i/o event */
	CloseHandle(hEvents[1]);

    if (got_error)
      ReportStatusToSCMgr(
	SERVICE_STOPPED,	/* service state */
	0, ExitCode || GetLastError(), /* exit code */
	0);			/* wait hint */
    else
      ReportStatusToSCMgr(
	SERVICE_STOPPED,	/* service state */
	NO_ERROR, 0,		/* exit code */
	0);			/* wait hint */
}

/* If a ServiceStop procedure is going to
   take longer than 3 seconds to execute,
   it should spawn a thread to execute the
   stop code, and return.  Otherwise, the
   ServiceControlManager will believe that
   the service has stopped responding. */

VOID ServiceStop (int write_stop_file)
{
  if (write_stop_file) {
    FILE *f;
    char tmp[8192];
    TCHAR cwd[_MAX_PATH];
    cwd[0] = 0;
    _tgetcwd (cwd, _MAX_PATH);

    _snprintf (tmp, sizeof (tmp), "..\\logs\\%s.run", key);
    if (!(f=fopen(tmp,"wb"))) {
      error_msg (1, TEXT("Roxen will not get the stop signal - "
			 "failed to open stop file %s\\..\\logs\\%hs.run"), cwd, key);
      return;
    }
    fprintf(f,"Kilroy was here.");
    fclose(f);
  }

  stopping=1;
  if ( hServerStopEvent )
    SetEvent(hServerStopEvent);
}

int start_roxen()
{
  STARTUPINFO info;
  PROCESS_INFORMATION proc;
  char pikeloc[_MAX_PATH];
  TCHAR cmd[4000];
  TCHAR *cmdline;
  void *env=NULL;
  int ret, len, i;
  FILE *fd;
  TCHAR cwd[_MAX_PATH];
  cwd[0] = 0;
  _tgetcwd (cwd, _MAX_PATH);

  if (!(fd = fopen ("pikelocation.txt", "r"))) {
    if (_chdir ("..")) {
      error_msg (1, TEXT("Could not change to the directory %s\\.."), cwd);
      return 0;
    }
    if (!(fd = fopen ("pikelocation.txt", "r"))) {
      if (_chdir (server_location + sizeof (LOCATION_COOKIE) - sizeof (""))) {
	error_msg (1, TEXT("Could not change to the Roxen server directory %hs"),
		   server_location + sizeof (LOCATION_COOKIE) - sizeof (""));
	return 0;
      }
      if (!(fd = fopen ("pikelocation.txt", "r"))) {
	error_msg (1, TEXT("Roxen server directory not found - "
			   "failed to open %s\\pikelocation.txt, "
			   "%s\\..\\pikelocation.txt, and "
			   "&hs\\pikelocation.txt"),
		   cwd, cwd, server_location + sizeof (LOCATION_COOKIE) - sizeof (""));
	return 0;
      }
    }
    cwd[0] = 0;
    _tgetcwd (cwd, _MAX_PATH);
  }
  if (!(len = fread (pikeloc, 1, _MAX_PATH, fd))) {
    error_msg (1, TEXT("Could not read %s\\pikelocation.txt"), cwd);
    return 0;
  }
  fclose (fd);
  if (len >= _MAX_PATH) {
    error_msg (0, TEXT("Exceedingly long path to Pike executable "
		       "in %s\\pikelocation.txt"), cwd);
    return 0;
  }
  if (memchr (pikeloc, 0, len)) {
    error_msg (0, TEXT("%s\\pikelocation.txt contains a null character"), cwd);
    return 0;
  }

  for (i = len - 1; i && isspace (pikeloc[i]); i--) {}
  len = i + 1;
  pikeloc[len] = 0;

  for(i = 0; i < sizeof (key) - 1; i++)
    key[i]=65+32+((unsigned char)rand())%24;
  key[sizeof (key) - 1] = 0;

#define CONSOLEARG "-console"
#define CONSOLEARGLEN (sizeof (CONSOLEARG) - sizeof (""))
  cmdline = GetCommandLine();
  for (; *cmdline && isspace (*cmdline); cmdline++) {}
  for (; *cmdline && !isspace (*cmdline); cmdline++) {}
  for (; *cmdline && isspace (*cmdline); cmdline++) {}
  if (!_tcsncmp (cmdline, TEXT(CONSOLEARG), CONSOLEARGLEN) &&
      (!cmdline[CONSOLEARGLEN] || isspace (cmdline[CONSOLEARGLEN]))) {
    cmdline += CONSOLEARGLEN;
    for (; *cmdline && isspace (*cmdline); cmdline++) {}
  }

  _sntprintf (cmd, sizeof (cmd), TEXT("%hs ntroxenloader.pike +../logs/%hs.run %s%s"),
	      pikeloc, key, console_mode ? TEXT("") : TEXT("-silent "), cmdline);
  cmd[sizeof (cmd) - 1] = 0;

  GetStartupInfo(&info);
/*   info.wShowWindow=SW_HIDE; */
  info.dwFlags|=STARTF_USESHOWWINDOW;
  ret=CreateProcess(NULL,
		    cmd,
		    NULL,  /* process security attribute */
		    NULL,  /* thread security attribute */
		    1,     /* inherithandles */
		    0,     /* create flags */
		    env,   /* environment */
		    cwd,   /* current dir */
		    &info,
		    &proc);
  if(!ret) error_msg (1, TEXT("Error starting the main Roxen process"));

  hProcess=proc.hProcess;
  return 1;
}

/*
  CreateProcess
  GetExitCodeProcess
*/
