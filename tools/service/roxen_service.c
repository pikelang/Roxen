/* Roxen Windows NT Service
   Based on sample code from MSDN */

#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <process.h>
#include <tchar.h>
#include "service.h"
#include <time.h>

/* this event is signalled when the
   service should end */
HANDLE hServerStopEvent = NULL;
HANDLE hProcess;
DWORD ExitCode;
LPVOID lpMsgBuf;
void start_roxen(void);
void check_registry(void);

TCHAR *log_location = NULL, *pike_location, *server_location;
TCHAR *key="aaaaaaaa";

VOID ServiceStart (DWORD dwArgc, LPTSTR *lpszArgv)
{
    HANDLE                  hEvents[2] = {NULL, NULL};
 
    /* report the status to the service control manager. */
    if (!ReportStatusToSCMgr(
        SERVICE_START_PENDING, // service state
        NO_ERROR,              // exit code
        3000))                 // wait hint
        goto cleanup;

    /* create the event object. The control handler function signals
       this event when it receives the "stop" control code. */
    hServerStopEvent = CreateEvent(
        NULL,    /* no security attributes */
        TRUE,    /* manual reset event */
        FALSE,   /* not-signalled */
        NULL);   /* no name */

    if ( hServerStopEvent == NULL)
        goto cleanup;

    hEvents[0] = hServerStopEvent;

    /* report the status to the service control manager. */
    if (!ReportStatusToSCMgr(
        SERVICE_START_PENDING, /* service state */
        NO_ERROR,              /* exit code */
        3000))                 /* wait hint */
        goto cleanup;

    /* create the event object object use in overlapped i/o */
    hEvents[1] = CreateEvent(
        NULL,    /* no security attributes */
	TRUE,    /* manual reset event */
	FALSE,   /* not-signalled */
	NULL);   /* no name */

    if ( hEvents[1] == NULL)
        goto cleanup;

    /* report the status to the service control manager. */
    if (!ReportStatusToSCMgr(
        SERVICE_START_PENDING, /* service state */
        NO_ERROR,              /* exit code */
        3000))                 /* wait hint */
        goto cleanup;


    /* report the status to the service control manager. */
    if (!ReportStatusToSCMgr(
        SERVICE_START_PENDING, /* service state */
        NO_ERROR,              /* exit code */
        3000))                 /* wait hint */
        goto cleanup;

    /* Start roxen */
    start_roxen();

    /* report the status to the service control manager. */
    if (!ReportStatusToSCMgr(
        SERVICE_RUNNING,       /* service state */
        NO_ERROR,              /* exit code */
        0))                    /* wait hint */
        goto cleanup;

    /* Service is now running, perform work until shutdown */

    while(1)
    {
      if(GetExitCodeProcess( hProcess, &ExitCode ))
      {
	    if(ExitCode!=STILL_ACTIVE)
		{
	      if(ExitCode==0) 
		  {
            if(hServerStopEvent)             /* Shutdown */
              SetEvent(hServerStopEvent);
			break;
		  }
	      else 
	        start_roxen();  /* Restart */
		}
      }
      else
      {
	    FormatMessage( FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM,
		       NULL,
		       GetLastError(),
		       MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT), /* Default language */
		       (LPTSTR) &lpMsgBuf,
		       0,
		       NULL );
	    MessageBox( NULL, lpMsgBuf, "GetLastError", MB_OK|MB_ICONINFORMATION );
        LocalFree( lpMsgBuf );
      }
      Sleep(50);    /* 50 ms */
    }

  cleanup:

    if (hServerStopEvent)
        CloseHandle(hServerStopEvent);

    if (hEvents[1]) /* overlapped i/o event */
        CloseHandle(hEvents[1]);
}

/* If a ServiceStop procedure is going to
   take longer than 3 seconds to execute,
   it should spawn a thread to execute the
   stop code, and return.  Otherwise, the
   ServiceControlManager will believe that
   the service has stopped responding. */

VOID ServiceStop()
{	
	FILE *f;
	char tmp[8192];

	strcpy(lpMsgBuf,"ServiceStop()");
    MessageBox( NULL, lpMsgBuf, "GetLastError", MB_OK|MB_ICONINFORMATION );

  
	check_registry();
	strcpy(tmp,log_location);
	strcat(tmp,"\\");
	strcat(tmp,key);
	f=fopen(key,"wcb");
	fprintf(f,"Kilroy was here.");
	fclose(f);

    if ( hServerStopEvent )
        SetEvent(hServerStopEvent);
}



void check_registry(void)
{
  HKEY k;
  unsigned char buffer[4096];
  DWORD len=4095,type=REG_SZ;
  
  if(pike_location) free(pike_location);
  if(server_location) free(server_location);
  pike_location=server_location=NULL;
  
  if(RegOpenKeyEx(HKEY_CURRENT_USER,
                  (LPCTSTR)"SOFTWARE\\Idonex\\Pike\\0.6",
                  0,KEY_READ,&k)==ERROR_SUCCESS ||
     RegOpenKeyEx(HKEY_LOCAL_MACHINE,
                  (LPCTSTR)"SOFTWARE\\Idonex\\Pike\\0.6",
                  0,KEY_READ,&k)==ERROR_SUCCESS)
  {
    if(RegQueryValueEx(k,
		       "PIKE_MASTER",
		       0,
		       &type,
		       buffer,
		       &len)==ERROR_SUCCESS)
    {
      pike_location=strdup((char*)buffer);
      pike_location[strlen(pike_location)-20]=0;
      strcat(pike_location,"bin/pike.exe");
    }
    RegCloseKey(k);
  }

  len = sizeof(buffer)-1;

  if(RegOpenKeyEx(HKEY_CURRENT_USER,
                  (LPCTSTR)"SOFTWARE\\Idonex\\Roxen\\1.3",
                  0,KEY_READ,&k)==ERROR_SUCCESS ||
     RegOpenKeyEx(HKEY_LOCAL_MACHINE,
                  (LPCTSTR)"SOFTWARE\\Idonex\\Roxen\\1.3",
                  0,KEY_READ,&k)==ERROR_SUCCESS)
  {
    if(RegQueryValueEx(k,
		       "installation_directory",
		       0,
		       &type,
		       buffer,
		       &len)==ERROR_SUCCESS)
      server_location=strdup((char*)buffer);
    len = sizeof(buffer)-1;
	if(RegQueryValueEx(k,
		       "log_directory",
		       0,
		       &type,
		       buffer,
		       &len)==ERROR_SUCCESS)
      log_location=strdup((char*)buffer);
    RegCloseKey(k);
  }
}


void start_roxen(void)
{
  STARTUPINFO info;
  PROCESS_INFORMATION proc;
  TCHAR *filename=" ntroxenloader.pike", cmd[4000];
  void *env=NULL;
  int ret,i;

  check_registry();
  if(!pike_location || !server_location)
  {
    // No location found in registry. Do something smart.
    return;
  }

  srand(time(0));
  for(i=0;i<8;i++)
    key[i]=65+32+((unsigned int)rand())%24;
  strcpy(cmd, pike_location);
  strcat(cmd, filename);
  strcat(cmd," +");
  strcat(cmd,key);

  
  GetStartupInfo(&info);
/*   info.wShowWindow=SW_HIDE; */
  info.dwFlags|=STARTF_USESHOWWINDOW;
  ret=CreateProcess(pike_location,
		    cmd,
                    NULL,  /* process security attribute */
                    NULL,  /* thread security attribute */
                    1,     /* inherithandles */
                    0,     /* create flags */
                    env,   /* environment */
                    server_location,   /* current dir */
                    &info,
                    &proc);
  hProcess=proc.hProcess;
}

/*
  CreateProcess
  GetExitCodeProcess
*/
