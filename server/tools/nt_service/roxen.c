/* Program to start Roxen as a service or in console mode on NT.
 *
 * Based on the service example code from Microsoft.
 *
 * $Id: roxen.c,v 1.8 2004/06/02 13:22:02 grubba Exp $
 */

// THIS CODE AND INFORMATION IS PROVIDED "AS IS" WITHOUT WARRANTY OF
// ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO
// THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A
// PARTICULAR PURPOSE.
//
// Copyright (C) 1993-1996  Microsoft Corporation.  All Rights Reserved.

#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <process.h>
#include <tchar.h>

#include "roxen_service.h"


//external nuzzle
extern HANDLE hTread;
// internal variables
SERVICE_STATUS          ssStatus;       // current status of the service
SERVICE_STATUS_HANDLE   sshStatusHandle;
DWORD                   dwErr = 0;
TCHAR                   szErr[256];

int console_mode = 0, run_once = 0;

// internal function prototypes
VOID WINAPI service_ctrl(DWORD dwCtrlCode);
VOID WINAPI service_main(DWORD dwArgc, LPTSTR *lpszArgv);
VOID CmdInstallService();
VOID CmdRemoveService (int ignore_missing);
VOID CmdConsoleService();
BOOL WINAPI ControlHandler ( DWORD dwCtrlType );
LPTSTR GetLastErrorText( LPTSTR lpszBuf, DWORD dwSize );

//
//  FUNCTION: main
//
//  PURPOSE: entrypoint for service
//
//  PARAMETERS:
//    argc - number of command line arguments
//    argv - array of command line arguments
//
//  RETURN VALUE:
//    none
//
//  COMMENTS:
//    main() either performs the command line task, or
//    call StartServiceCtrlDispatcher to register the
//    main service thread.  When the this call returns,
//    the service has stopped, so exit.
//
void _CRTAPI1 main(int argc, char **argv)
{
    SERVICE_TABLE_ENTRY dispatchTable[] =
    {
	{ TEXT(SZSERVICENAME), (LPSERVICE_MAIN_FUNCTION)service_main },
	{ NULL, NULL }
    };

    if ( (argc > 1) &&
	 ((*argv[1] == '-') || (*argv[1] == '/')) )
    {
	if ( _stricmp( "install", argv[1]+1 ) == 0 )
	{
	  //CmdRemoveService (1);
	    CmdInstallService();
	}
	else if ( _stricmp( "remove", argv[1]+1 ) == 0 )
	{
	    CmdRemoveService (0);
	}
	else if ( _stricmp( "console", argv[1]+1 ) == 0 )
	{
	    console_mode = 1;
	    CmdConsoleService();
	}
	else if ( _stricmp( "once", argv[1]+1 ) == 0 )
	{
	    console_mode = run_once = 1;
	    CmdConsoleService();
	}
	else
	{
	    goto dispatch;
	}
	exit(ExitCode);
    }

    // if it doesn't match any of the above parameters
    // the service control manager may be starting the service
    // so we must call StartServiceCtrlDispatcher
    dispatch:
	// this is just to be friendly
	printf( "%s -install          to install the service\n", SZAPPNAME );
	printf( "%s -remove           to remove the service\n", SZAPPNAME );
	printf( "%s -console <params> to run as a console app for debugging\n", SZAPPNAME );
	printf( "%s -once <params>    like -console, but never restart\n", SZAPPNAME );
	printf( "\nStartServiceCtrlDispatcher being called.\n" );
	printf( "This may take several seconds.  Please wait.\n" );

	if (!StartServiceCtrlDispatcher(dispatchTable))
	    AddToMessageLog(TEXT("StartServiceCtrlDispatcher failed."));
}



//
//  FUNCTION: service_main
//
//  PURPOSE: To perform actual initialization of the service
//
//  PARAMETERS:
//    dwArgc   - number of command line arguments
//    lpszArgv - array of command line arguments
//
//  RETURN VALUE:
//    none
//
//  COMMENTS:
//    This routine performs the service initialization and then calls
//    the user defined ServiceStart() routine to perform majority
//    of the work.
//
void WINAPI service_main(DWORD dwArgc, LPTSTR *lpszArgv)
{

    // register our service control handler:
    //
    sshStatusHandle = RegisterServiceCtrlHandler( TEXT(SZSERVICENAME), service_ctrl);

    if (!sshStatusHandle) return;

    // SERVICE_STATUS members that don't change in example
    //
    ssStatus.dwServiceType = SERVICE_WIN32_OWN_PROCESS;
    ssStatus.dwServiceSpecificExitCode = 0;


    // report the status to the service control manager.
    //
    if (!ReportStatusToSCMgr(
	SERVICE_START_PENDING,	// service state
	NO_ERROR, 0,		// exit code
	3000)) {		// wait hint
      (VOID)ReportStatusToSCMgr(
	SERVICE_STOPPED,
	dwErr, 0,
	0);
    }

    ServiceStart();

    return;
}



//
//  FUNCTION: service_ctrl
//
//  PURPOSE: This function is called by the SCM whenever
//           ControlService() is called on this service.
//
//  PARAMETERS:
//    dwCtrlCode - type of control requested
//
//  RETURN VALUE:
//    none
//
//  COMMENTS:
//
VOID WINAPI service_ctrl(DWORD dwCtrlCode)
{
    // Handle the requested control code.
    //
    switch(dwCtrlCode)
    {
      // Stop the service.
      //
      // SERVICE_STOP_PENDING should be reported before
      // setting the Stop Event - hServerStopEvent - in
      // ServiceStop().  This avoids a race condition
      // which may result in a 1053 - The Service did not respond...
      // error.
      case SERVICE_CONTROL_STOP:
      case SERVICE_CONTROL_SHUTDOWN:
			ReportStatusToSCMgr(SERVICE_STOP_PENDING, NO_ERROR, 0, 0);
			ServiceStop(1);
	  return;

	// Update the service status.
	//
      case SERVICE_CONTROL_INTERROGATE:
	break;

	// invalid control code
	//
      default:
	break;

    }

    ReportStatusToSCMgr(ssStatus.dwCurrentState, NO_ERROR, 0, 0);
}



//
//  FUNCTION: ReportStatusToSCMgr()
//
//  PURPOSE: Sets the current status of the service and
//           reports it to the Service Control Manager
//
//  PARAMETERS:
//    dwCurrentState - the state of the service
//    dwWin32ExitCode - error code to report
//    service_specific_code - service specific error code
//    dwWaitHint - worst case estimate to next checkpoint
//
//  RETURN VALUE:
//    TRUE  - success
//    FALSE - failure
//
//  COMMENTS:
//
BOOL ReportStatusToSCMgr(DWORD dwCurrentState,
			 DWORD dwWin32ExitCode,
			 DWORD service_specific_code,
			 DWORD dwWaitHint)
{
    static DWORD dwCheckPoint = 1;
    BOOL fResult = TRUE;


    if ( !console_mode ) // In console mode we don't report to the SCM
    {
	if (dwCurrentState == SERVICE_START_PENDING ||
	    dwCurrentState == SERVICE_STOPPED)
	    ssStatus.dwControlsAccepted = 0;
	else
	    ssStatus.dwControlsAccepted =
	      SERVICE_ACCEPT_STOP|SERVICE_ACCEPT_SHUTDOWN;

	ssStatus.dwCurrentState = dwCurrentState;
	if (service_specific_code) {
	  ssStatus.dwWin32ExitCode = ERROR_SERVICE_SPECIFIC_ERROR;
	  ssStatus.dwServiceSpecificExitCode = service_specific_code;
	}
	else ssStatus.dwWin32ExitCode = dwWin32ExitCode;
	ssStatus.dwWaitHint = dwWaitHint;

	if ( ( dwCurrentState == SERVICE_RUNNING ) ||
	     ( dwCurrentState == SERVICE_STOPPED ) )
	    ssStatus.dwCheckPoint = 0;
	else
	    ssStatus.dwCheckPoint = dwCheckPoint++;


	// Report the status of the service to the service control manager.
	//
	if (!(fResult = SetServiceStatus( sshStatusHandle, &ssStatus))) {
	    AddToMessageLog(TEXT("SetServiceStatus"));
	}
    }
    return fResult;
}



//
//  FUNCTION: AddToMessageLog(LPTSTR lpszMsg)
//
//  PURPOSE: Allows any thread to log an error message
//
//  PARAMETERS:
//    lpszMsg - text for message
//
//  RETURN VALUE:
//    none
//
//  COMMENTS:
//
VOID AddToMessageLog(LPTSTR lpszMsg)
{
    TCHAR   szMsg[256];
    HANDLE  hEventSource;
    LPTSTR  lpszStrings[2];


    if ( !console_mode )
    {
	dwErr = GetLastError();

	// Use event logging to log the error.
	//
	hEventSource = RegisterEventSource(NULL, TEXT(SZSERVICENAME));

	_stprintf(szMsg, TEXT("%s error: %d"), TEXT(SZSERVICENAME), dwErr);
	lpszStrings[0] = szMsg;
	lpszStrings[1] = lpszMsg;

	if (hEventSource != NULL) {
	    ReportEvent(hEventSource, // handle of event source
		EVENTLOG_ERROR_TYPE,  // event type
		0,                    // event category
		0,                    // event ID
		NULL,                 // current user's SID
		2,                    // strings in lpszStrings
		0,                    // no bytes of raw data
		lpszStrings,          // array of error strings
		NULL);                // no raw data

	    (VOID) DeregisterEventSource(hEventSource);
	}
    }
}




///////////////////////////////////////////////////////////////////
//
//  The following code handles service installation and removal
//

void stop_service(SC_HANDLE schService)
{
  if ( ControlService( schService, SERVICE_CONTROL_STOP, &ssStatus ) )
  {
    _tprintf(TEXT("Stopping %s."), TEXT(SZSERVICEDISPLAYNAME));
    Sleep( 1000 );

    while( QueryServiceStatus( schService, &ssStatus ) )
    {
      if ( ssStatus.dwCurrentState == SERVICE_STOP_PENDING )
      {
	_tprintf(TEXT("."));
	Sleep( 1000 );
      }
      else
	break;
    }

    if ( ssStatus.dwCurrentState == SERVICE_STOPPED )
      _tprintf(TEXT("\n%s stopped.\n"), TEXT(SZSERVICEDISPLAYNAME) );
    else
      _tprintf(TEXT("\n%s failed to stop.\n"), TEXT(SZSERVICEDISPLAYNAME) );
  }
}

//
//  FUNCTION: CmdInstallService()
//
//  PURPOSE: Installs the service
//
//  PARAMETERS:
//    none
//
//  RETURN VALUE:
//    none
//
//  COMMENTS:
//
void CmdInstallService()
{
    SC_HANDLE   schService;
    SC_HANDLE   schSCManager;

    TCHAR szPath[512];

    if ( GetModuleFileName( NULL, szPath, 512 ) == 0 )
    {
	_tprintf(TEXT("Unable to install %s - %s\n"), TEXT(SZSERVICEDISPLAYNAME), GetLastErrorText(szErr, 256));
	return;
    }

    schSCManager = OpenSCManager(
			NULL,                   // machine (NULL == local)
			NULL,                   // database (NULL == default)
			SC_MANAGER_ALL_ACCESS   // access required
			);
    if ( schSCManager )
    {
      	schService =
	  OpenService(schSCManager, TEXT(SZSERVICENAME), SERVICE_ALL_ACCESS);

	if (schService)
	{
	  BOOL err;
	  // Already installed.
	  // Stop the old server.
	  stop_service(schService);

	  // Update the old entry.
	  err =
	    ChangeServiceConfig(schService,
	      SERVICE_WIN32_OWN_PROCESS,  // service type
	      SERVICE_AUTO_START,         // start type
	      SERVICE_ERROR_NORMAL,       // error control type
	      szPath,                     // service's binary
	      NULL,                       // no load ordering group
	      NULL,                       // no tag identifier
	      TEXT(SZDEPENDENCIES),       // dependencies
	      NULL,                       // LocalSystem account
	      NULL,                       // no password
	      TEXT(SZSERVICEDISPLAYNAME));// name to display
	  if (!err) {
	    _tprintf(TEXT("ChangeServiceConfig failed - %s\n"),
		     GetLastErrorText(szErr, 256));
	  }

	  // FIXME: Do I need to restart the service here?

	  CloseServiceHandle(schService);
	} else {
	  // Fresh install.

	  schService = CreateService(
	    schSCManager,               // SCManager database
	    TEXT(SZSERVICENAME),        // name of service
	    TEXT(SZSERVICEDISPLAYNAME), // name to display
	    SERVICE_ALL_ACCESS,         // desired access
	    SERVICE_WIN32_OWN_PROCESS,  // service type
	    SERVICE_AUTO_START,         // start type
	    SERVICE_ERROR_NORMAL,       // error control type
	    szPath,                     // service's binary
	    NULL,                       // no load ordering group
	    NULL,                       // no tag identifier
	    TEXT(SZDEPENDENCIES),       // dependencies
	    NULL,                       // LocalSystem account
	    NULL);                      // no password

	  if ( schService )
	  {
	    _tprintf(TEXT("%s installed.\n"), TEXT(SZSERVICEDISPLAYNAME) );
	    CloseServiceHandle(schService);
	  }
	  else
	  {
	    _tprintf(TEXT("CreateService failed - %s\n"), GetLastErrorText(szErr, 256));
	  }
	}
	CloseServiceHandle(schSCManager);
    }
    else
	_tprintf(TEXT("OpenSCManager failed - %s\n"), GetLastErrorText(szErr,256));
}



//
//  FUNCTION: CmdRemoveService()
//
//  PURPOSE: Stops and removes the service
//
//  PARAMETERS:
//    ignore_missing - set to nonzero to ignore errors due to missing service.
//
//  RETURN VALUE:
//    none
//
//  COMMENTS:
//
void CmdRemoveService (int ignore_missing)
{
    SC_HANDLE   schService;
    SC_HANDLE   schSCManager;

    schSCManager = OpenSCManager(
			NULL,                   // machine (NULL == local)
			NULL,                   // database (NULL == default)
			SC_MANAGER_ALL_ACCESS   // access required
			);
    if ( schSCManager )
    {
	schService = OpenService(schSCManager, TEXT(SZSERVICENAME), SERVICE_ALL_ACCESS);

	if (schService)
	{
	    // try to stop the service
	    stop_service(schService);

	    // now remove the service
	    if( DeleteService(schService) )
		_tprintf(TEXT("%s removed.\n"), TEXT(SZSERVICEDISPLAYNAME) );
	    else
		_tprintf(TEXT("DeleteService failed - %s\n"), GetLastErrorText(szErr,256));


	    CloseServiceHandle(schService);
	}
	else if (!ignore_missing)
	    _tprintf(TEXT("OpenService failed - %s\n"), GetLastErrorText(szErr,256));

	CloseServiceHandle(schSCManager);
    }
    else if (!ignore_missing)
	_tprintf(TEXT("OpenSCManager failed - %s\n"), GetLastErrorText(szErr,256));
}




///////////////////////////////////////////////////////////////////
//
//  The following code is for running the service as a console app
//


//
//  FUNCTION: CmdConsoleService()
//
//  PURPOSE: Runs the service as a console application
//
//  PARAMETERS:
//
//  RETURN VALUE:
//    none
//
//  COMMENTS:
//
void CmdConsoleService()
{
    SetConsoleCtrlHandler( ControlHandler, TRUE );

    ServiceStart();
}


//
//  FUNCTION: ControlHandler ( DWORD dwCtrlType )
//
//  PURPOSE: Handled console control events
//
//  PARAMETERS:
//    dwCtrlType - type of control event
//
//  RETURN VALUE:
//    True - handled
//    False - unhandled
//
//  COMMENTS:
//
BOOL WINAPI ControlHandler ( DWORD dwCtrlType )
{
    switch( dwCtrlType )
    {
	case CTRL_BREAK_EVENT:  // use Ctrl+C or Ctrl+Break to simulate
	case CTRL_C_EVENT:      // SERVICE_CONTROL_STOP in debug mode
	    ThreadServiceStop(0);
	    return TRUE;
	    break;

    }
    return FALSE;
}

//
//  FUNCTION: GetLastErrorText
//
//  PURPOSE: copies error message text to string
//
//  PARAMETERS:
//    lpszBuf - destination buffer
//    dwSize - size of buffer
//
//  RETURN VALUE:
//    destination buffer
//
//  COMMENTS:
//
LPTSTR GetLastErrorText( LPTSTR lpszBuf, DWORD dwSize )
{
    DWORD dwRet;
    LPTSTR lpszTemp = NULL;

    dwRet = FormatMessage( FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM |FORMAT_MESSAGE_ARGUMENT_ARRAY,
			   NULL,
			   GetLastError(),
			   LANG_NEUTRAL,
			   (LPTSTR)&lpszTemp,
			   0,
			   NULL );

    // supplied buffer is not long enough
    if ( !dwRet || ( (long)dwSize < (long)dwRet+14 ) )
	lpszBuf[0] = TEXT('\0');
    else
    {
	lpszTemp[lstrlen(lpszTemp)-2] = TEXT('\0');  //remove cr and newline character
	_stprintf( lpszBuf, TEXT("%s (0x%x)"), lpszTemp, GetLastError() );
    }

    if ( lpszTemp )
	LocalFree((HLOCAL) lpszTemp );

    return lpszBuf;
}
