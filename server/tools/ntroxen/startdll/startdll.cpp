// startdll.cpp : Implementation of WinMain
//
// $Id$
//


// Note: Proxy/Stub Information
//      To build a separate proxy/stub DLL, 
//      run nmake -f startdllps.mk in the project directory.

#include "stdafx.h"
#include "resource.h"
#include <initguid.h>
#include "startdll.h"

#include "startdll_i.c"


#include <stdio.h>
#include <io.h>
#include <fcntl.h>
#include <process.h>

#include "cmdline.h"
#include "enumproc.h"
#include "roxenmsg.h"

#define BUILD_DLL

#ifdef BUILD_DLL
static HINSTANCE hInstance = NULL;
#endif

CServiceModule _Module;

BEGIN_OBJECT_MAP(ObjectMap)
END_OBJECT_MAP()


LPCTSTR FindOneOf(LPCTSTR p1, LPCTSTR p2)
{
    while (p1 != NULL && *p1 != NULL)
    {
        LPCTSTR p = p2;
        while (p != NULL && *p != NULL)
        {
            if (*p1 == *p)
                return CharNext(p1);
            p = CharNext(p);
        }
        p1 = CharNext(p1);
    }
    return NULL;
}


CServiceModule::CServiceModule()
{
  //m_once = 0;
  m_pendingLaunch = 0;
}


// Although some of these functions are big they are declared inline since they are only used once

inline HRESULT CServiceModule::RegisterServer(BOOL bRegTypeLib, BOOL bService)
{
    HRESULT hr = CoInitialize(NULL);
    if (FAILED(hr))
        return hr;

    if (!bService) {
      // Uninstall any previous service, since we won't run in service mode.
      Uninstall();
    }

    // Add service entries
    UpdateRegistryFromResource(IDR_Startdll, TRUE);

    // Adjust the AppID for Local Server or Service
    CRegKey keyAppID;
    LONG lRes = keyAppID.Open(HKEY_CLASSES_ROOT, _T("AppID"), KEY_WRITE);
    if (lRes != ERROR_SUCCESS)
        return lRes;

    CRegKey key;
    lRes = key.Open(keyAppID, _T("{EE755A27-6EEA-4AD7-AB21-BCE00C6CFF1A}"), KEY_WRITE);
    if (lRes != ERROR_SUCCESS)
        return lRes;
    key.DeleteValue(_T("LocalService"));
    
    if (bService)
    {
        key.SetValue(_T("ntstart"), _T("LocalService"));
        key.SetValue(_T("-Service"), _T("ServiceParameters"));
        // Create service
        Install();
    }

    // Add object entries
    hr = CComModule::RegisterServer(bRegTypeLib);

    CoUninitialize();
    return hr;
}

inline HRESULT CServiceModule::UnregisterServer()
{
    HRESULT hr = CoInitialize(NULL);
    if (FAILED(hr))
        return hr;

    // Remove service entries
    UpdateRegistryFromResource(IDR_Startdll, FALSE);
    // Remove service
    Uninstall();
    // Remove object entries
    CComModule::UnregisterServer(TRUE);
    CoUninitialize();
    return S_OK;
}

inline void CServiceModule::Init(_ATL_OBJMAP_ENTRY* p, HINSTANCE h, UINT nServiceNameID, UINT nServiceDescID, const GUID* plibid)
{
    CComModule::Init(p, hInstance, plibid);

    m_bService = TRUE;

    LoadString(h, nServiceNameID, m_szServiceName, sizeof(m_szServiceName) / sizeof(TCHAR));
    LoadString(h, nServiceDescID, m_szServiceDesc, sizeof(m_szServiceDesc) / sizeof(TCHAR));

    // set up the initial service status 
    m_hServiceStatus = NULL;
    m_status.dwServiceType = SERVICE_WIN32_OWN_PROCESS;
    m_status.dwCurrentState = SERVICE_STOPPED;
    m_status.dwControlsAccepted = SERVICE_ACCEPT_STOP;
    m_status.dwWin32ExitCode = 0;
    m_status.dwServiceSpecificExitCode = 0;
    m_status.dwCheckPoint = 0;
    m_status.dwWaitHint = 0;
}

LONG CServiceModule::Unlock()
{
    LONG l = CComModule::Unlock();
    if (l == 0 && !m_bService)
        PostThreadMessage(dwThreadID, WM_QUIT, 0, 0);
    return l;
}

BOOL CServiceModule::IsInstalled()
{
    BOOL bResult = FALSE;

    SC_HANDLE hSCM = ::OpenSCManager(NULL, NULL, SC_MANAGER_ALL_ACCESS);

    if (hSCM != NULL)
    {
        SC_HANDLE hService = ::OpenService(hSCM, m_szServiceName, SERVICE_QUERY_CONFIG);
        if (hService != NULL)
        {
            bResult = TRUE;
            ::CloseServiceHandle(hService);
        }
        ::CloseServiceHandle(hSCM);
    }
    return bResult;
}

inline BOOL CServiceModule::Install()
{
    SC_HANDLE hSCM = ::OpenSCManager(NULL, NULL, SC_MANAGER_ALL_ACCESS);
    if (hSCM == NULL)
    {
        MessageBox(NULL, _T("Couldn't open service manager"), m_szServiceName, MB_OK);
        return FALSE;
    }

    // Get the executable file path
    TCHAR szFilePath[_MAX_PATH];
    ::GetModuleFileName(NULL, szFilePath, _MAX_PATH);

    SC_HANDLE hService = ::OpenService(hSCM, m_szServiceName, SERVICE_QUERY_CONFIG|SERVICE_CHANGE_CONFIG);
    if (hService) {
      // Update a previously installed entry.
      if (!::ChangeServiceConfig(hService, SERVICE_WIN32_OWN_PROCESS,
          SERVICE_AUTO_START, SERVICE_ERROR_NORMAL,
          szFilePath, NULL, NULL, _T("RPCSS\0"), NULL, NULL,
          m_szServiceName)) {
	long err = GetLastError();
	::CloseServiceHandle(hService);
	::CloseServiceHandle(hSCM);
	switch(err) {
	case ERROR_ACCESS_DENIED:
	  MessageBox(NULL, _T("Couldn't change service (Access Denied)"), m_szServiceName, MB_OK);
	  break;
	case ERROR_CIRCULAR_DEPENDENCY:
	  MessageBox(NULL, _T("Couldn't change service (Circular Dependency)"), m_szServiceName, MB_OK);
	  break;
	case ERROR_DUPLICATE_SERVICE_NAME:
	  MessageBox(NULL, _T("Couldn't change service (Duplicate Service Name)"), m_szServiceName, MB_OK);
	  break;
	case ERROR_INVALID_HANDLE:
	  MessageBox(NULL, _T("Couldn't change service (Invalid Handle)"), m_szServiceName, MB_OK);
	  break;
	case ERROR_INVALID_PARAMETER:
	  MessageBox(NULL, _T("Couldn't change service (Invalid Parameter)"), m_szServiceName, MB_OK);
	  break;
	case ERROR_INVALID_SERVICE_ACCOUNT:
	  MessageBox(NULL, _T("Couldn't change service (Invalid Service Account)"), m_szServiceName, MB_OK);
	  break;
	case ERROR_SERVICE_MARKED_FOR_DELETE:
	  MessageBox(NULL, _T("Couldn't change service (Service Marked For Delete)"), m_szServiceName, MB_OK);
	  break;
	default:
	  MessageBox(NULL, _T("Couldn't change service"), m_szServiceName, MB_OK);
	  break;
	}
        return FALSE;
      }
    } else {
      hService = ::CreateService(
          hSCM, m_szServiceName, m_szServiceName,
          SERVICE_ALL_ACCESS, SERVICE_WIN32_OWN_PROCESS,
          SERVICE_AUTO_START, SERVICE_ERROR_NORMAL,
          szFilePath, NULL, NULL, _T("RPCSS\0"), NULL, NULL);
      if (hService == NULL)
      {
        ::CloseServiceHandle(hSCM);
        MessageBox(NULL, _T("Couldn't create service"), m_szServiceName, MB_OK);
        return FALSE;
      }
    }

    SERVICE_DESCRIPTION desc;
    desc.lpDescription = m_szServiceDesc;
    HMODULE hAdvapi32 = GetModuleHandle("Advapi32");
    if (hAdvapi32 != NULL)
    {
      typedef BOOL (__stdcall *tChangeServiceConfig2)(SC_HANDLE hService, DWORD dwInfoLevel, LPVOID lpInfo);

      tChangeServiceConfig2 ChangeServiceConfig2 = (tChangeServiceConfig2)GetProcAddress(hAdvapi32, "ChangeServiceConfig2A");
      if (ChangeServiceConfig2 != NULL)
        ChangeServiceConfig2(hService, SERVICE_CONFIG_DESCRIPTION, &desc);
    }

    ::CloseServiceHandle(hService);
    ::CloseServiceHandle(hSCM);

    // Register an event source
    LONG lRes;
    CRegKey keyEventApp;
    lRes = keyEventApp.Open(HKEY_LOCAL_MACHINE,
      "SYSTEM\\CurrentControlSet\\Services\\EventLog\\Application", KEY_READ);
    if (lRes != ERROR_SUCCESS)
        return FALSE;

    CRegKey keyEventRoxen;
    lRes = keyEventRoxen.Create(keyEventApp, m_szServiceName);
    if (lRes != ERROR_SUCCESS)
        return FALSE;

    ::GetModuleFileName(hInstance, szFilePath, _MAX_PATH);
    keyEventRoxen.SetValue(szFilePath, "EventMessageFile");
    keyEventRoxen.SetValue(EVENTLOG_INFORMATION_TYPE, "TypesSupported");

    return TRUE;
}

inline BOOL CServiceModule::Uninstall()
{
    if (!IsInstalled())
        return TRUE;

    LONG lRes;
    CRegKey keyEventApp;
    lRes = keyEventApp.Open(HKEY_LOCAL_MACHINE,
      "SYSTEM\\CurrentControlSet\\Services\\EventLog\\Application", KEY_READ);
    if (lRes == ERROR_SUCCESS)
    {
      keyEventApp.DeleteSubKey(m_szServiceName);
    }

    SC_HANDLE hSCM = ::OpenSCManager(NULL, NULL, SC_MANAGER_ALL_ACCESS);

    if (hSCM == NULL)
    {
        MessageBox(NULL, _T("Couldn't open service manager"), m_szServiceName, MB_OK);
        return FALSE;
    }

    SC_HANDLE hService = ::OpenService(hSCM, m_szServiceName, SERVICE_STOP | DELETE);

    if (hService == NULL)
    {
        ::CloseServiceHandle(hSCM);
        MessageBox(NULL, _T("Couldn't open service"), m_szServiceName, MB_OK);
        return FALSE;
    }
    SERVICE_STATUS status;
    ::ControlService(hService, SERVICE_CONTROL_STOP, &status);

    BOOL bDelete = ::DeleteService(hService);
    ::CloseServiceHandle(hService);
    ::CloseServiceHandle(hSCM);

    if (bDelete)
        return TRUE;

    MessageBox(NULL, _T("Service could not be deleted"), m_szServiceName, MB_OK);
    return FALSE;
}

///////////////////////////////////////////////////////////////////////////////////////
// Logging functions
void CServiceModule::LogEvent(LPCTSTR pFormat, ...)
{
    TCHAR    chMsg[4098];
    HANDLE  hEventSource;
    LPTSTR  lpszStrings[1];
    va_list pArg;

    va_start(pArg, pFormat);
    _vsntprintf(chMsg, sizeof(chMsg), pFormat, pArg);
    va_end(pArg);

    chMsg[4097] = 0;

    lpszStrings[0] = chMsg;

    if (m_bService)
    {
        /* Get a handle to use with ReportEvent(). */
        hEventSource = RegisterEventSource(NULL, m_szServiceName);
        if (hEventSource != NULL)
        {
            /* Write to event log. */
            ReportEvent(hEventSource, EVENTLOG_INFORMATION_TYPE, 0, MSG_GENERIC, NULL, 1, 0, (LPCTSTR*) &lpszStrings[0], NULL);
            DeregisterEventSource(hEventSource);
        }
    }
    else
    {
        // As we are not running as a service, just write the error to the console.
        _putts(chMsg);
        fflush(stdout);
    }
}

//////////////////////////////////////////////////////////////////////////////////////////////
// Service startup and registration
inline void CServiceModule::Start()
{
    SERVICE_TABLE_ENTRY st[] =
    {
        { m_szServiceName, _ServiceMain },
        { NULL, NULL }
    };
    if (m_bService && !::StartServiceCtrlDispatcher(st))
    {
        m_bService = FALSE;
    }
    if (m_bService == FALSE)
    {
        // Add our ctrl-c and ctrl-break handling routine
        SetConsoleCtrlHandler( _ControlHandler, TRUE );

        Run();

        // Remove the ctrl-c and ctrl-break handling routine
        SetConsoleCtrlHandler( _ControlHandler, FALSE );
    }

}

inline void CServiceModule::ServiceMain(DWORD dwArgc, LPTSTR* lpszArgv)
{
    m_Cmdline.Parse(dwArgc, lpszArgv);

    // Register the control request handler
    m_status.dwCurrentState = SERVICE_START_PENDING;
    m_hServiceStatus = RegisterServiceCtrlHandler(m_szServiceName, _Handler);
    if (m_hServiceStatus == NULL)
    {
        LogEvent(_T("Handler not installed"));
        return;
    }
    SetServiceStatus(SERVICE_START_PENDING);

    m_status.dwWin32ExitCode = S_OK;
    m_status.dwCheckPoint = 0;
    m_status.dwWaitHint = 0;

    // When the Run function returns, the service has stopped.
    Run();

    SetServiceStatus(SERVICE_STOPPED);

    LogEvent(_T("Service stopped"));
}

inline void CServiceModule::Handler(DWORD dwOpcode)
{
    switch (dwOpcode)
    {
    case SERVICE_CONTROL_STOP:
        Stop(TRUE);
        break;
    case SERVICE_CONTROL_PAUSE:
        break;
    case SERVICE_CONTROL_CONTINUE:
        break;
    case SERVICE_CONTROL_INTERROGATE:
        break;
    case SERVICE_CONTROL_SHUTDOWN:
        break;
    default:
        LogEvent(_T("Bad service request"));
    }
}

//////////////////////////////////////////////////////////////////////////////////////////////
//  Handled console control events
BOOL CServiceModule::ControlHandler( DWORD dwCtrlType )
{

  char *ctrlEvent[7] = {
      "CTRL_C_EVENT",       // 0
      "CTRL_BREAK_EVENT",   // 1
      "CTRL_CLOSE_EVENT",   // 2
      "CTRL_3",             // 3 is reserved!
      "CTRL_4",             // 4 is reserved!
      "CTRL_LOGOFF_EVENT",  // 5
      "CTRL_SHUTDOWN_EVENT" // 6
  };

    switch( dwCtrlType )
    {
	case CTRL_BREAK_EVENT:  // Ignore Ctrl+Break (may be used by pike)
        //printf("%s received\n", ctrlEvent[dwCtrlType]);
        return TRUE;

    case CTRL_C_EVENT:      // use Ctrl+C or 'Close Window' button to simulate
    case CTRL_CLOSE_EVENT:  // SERVICE_CONTROL_STOP in debug mode
    case CTRL_LOGOFF_EVENT:
        //printf("%s received\n", ctrlEvent[dwCtrlType]);
        Stop(TRUE);
	    return TRUE;
    default:
        printf("Unknown CTRL event %d received\n", dwCtrlType);
    }
    return FALSE;
}

//////////////////////////////////////////////////////////////////////////////////////////////
//  Static functions used as callbacks
void WINAPI CServiceModule::_ServiceMain(DWORD dwArgc, LPTSTR* lpszArgv)
{
    _Module.ServiceMain(dwArgc, lpszArgv);
}
void WINAPI CServiceModule::_Handler(DWORD dwOpcode)
{
    _Module.Handler(dwOpcode); 
}
BOOL WINAPI CServiceModule::_ControlHandler ( DWORD dwCtrlType )
{
    return _Module.ControlHandler(dwCtrlType); 
}

//////////////////////////////////////////////////////////////////////////////////////////////
//  Wrapper to set SCManager status
void CServiceModule::SetServiceStatus(DWORD dwState)
{
    m_status.dwCurrentState = dwState;
    ::SetServiceStatus(m_hServiceStatus, &m_status);
}

//////////////////////////////////////////////////////////////////////////////////////////////
//  Wrapper to check status
BOOL CServiceModule::IsStopping()
{
    return (m_status.dwCurrentState == SERVICE_STOP_PENDING);
}

//////////////////////////////////////////////////////////////////////////////////////////////
//  A messageloop that dispatch messages and waits on the specified objects
int CServiceModule::MessageLoop ( 
    HANDLE* lphObjects,  // handles that need to be waited on 
    int     cObjects     // number of handles to wait on 
  )
{ 
    // The message loop lasts until we get a WM_QUIT message,
    // upon which we shall return from the function.
    while (TRUE)
    {
        // block-local variable 
        DWORD result ; 
        MSG msg ; 

        // Read all of the messages in this next loop, 
        // removing each message as we read it.
        while (PeekMessage(&msg, NULL, 0, 0, PM_REMOVE)) 
        { 
            // If it's a quit message, we're out of here.
            if (msg.message == WM_QUIT)  
                return 1; 
            // Otherwise, dispatch the message.
            DispatchMessage(&msg); 
        } // End of PeekMessage while loop.

        // Wait for any message sent or posted to this queue 
        // or for one of the passed handles be set to signaled.
        result = MsgWaitForMultipleObjects(cObjects, lphObjects, 
                 FALSE, INFINITE, QS_ALLINPUT); 

        // The result tells us the type of event we have.
        if (result == (WAIT_OBJECT_0 + cObjects))
        {
            // New messages have arrived. 
            // Continue to the top of the always while loop to 
            // dispatch them and resume waiting.
            continue;
        } 
        else 
        { 
            // One of the handles became signaled. 
            MsgLoopCallback(result - WAIT_OBJECT_0);
        } // End of else clause.
    } // End of the always while loop. 
} // End of function.


//////////////////////////////////////////////////////////////////////////////////////////////
// function called from MessageLoop when one of the handles became signalled
void CServiceModule::MsgLoopCallback(int index)
{
  if (IsStopping())
    return;

  DWORD exitcode = 0;
  GetExitCodeProcess(m_roxen->GetProcess(), &exitcode);

  if (exitcode == STILL_ACTIVE)
  {
    // do nothing
  }
  else if (exitcode == 0)
  {
    //clean shutdown
    if (m_Cmdline.GetVerbose() > 0)
      LogEvent("Roxen CMS shutdown.");

    Stop(FALSE);
  }
  else if (exitcode == 50)
  {
    //clean shutdown
    if (m_Cmdline.GetVerbose() > 0)
      LogEvent("Failed to open any port. Shutdown.");

    m_Cmdline.SetKeepMysql();
    Stop(FALSE);
  }
  else if (exitcode == 100)
  {
    // restart using possibly new version of ourself
    if (m_Cmdline.GetVerbose() > 0)
      LogEvent("Changing Roxen CMS version. Restarting...");
    
    if (!m_Cmdline.IsOnce())
      // restart the new version of the server!!
      SetRestartFlag(TRUE);

    Stop(FALSE);
  }
  else
  {
    if (exitcode < 0)
    {
      if (m_Cmdline.GetVerbose() > 0)
        LogEvent("Roxen CMS died of signal %d. Restarting...", exitcode);
    }
    else // exitcode < 0
    {
      if (m_Cmdline.GetVerbose() > 0)
        LogEvent("Roxen CMS down. Restarting...");
    }
    Sleep(100);
    if (IsStopping())
      return;
    if (m_Cmdline.IsOnce() || !m_roxen->Start(0))
      Stop(FALSE);
  }
}


//////////////////////////////////////////////////////////////////////////////////////////////
// Do the actual work. The service will exit when this function returns
void CServiceModule::Run()
{
    _Module.dwThreadID = GetCurrentThreadId();

    HRESULT hr = CoInitialize(NULL);
//  If you are running on NT 4.0 or higher you can use the following call
//  instead to make the EXE free threaded.
//  This means that calls come in on a random RPC thread
//  HRESULT hr = CoInitializeEx(NULL, COINIT_MULTITHREADED);

    _ASSERTE(SUCCEEDED(hr));

    // This provides a NULL DACL which will allow access to everyone.
    CSecurityDescriptor sd;
    sd.InitializeFromThreadToken();
    hr = CoInitializeSecurity(sd, -1, NULL, NULL,
        RPC_C_AUTHN_LEVEL_PKT, RPC_C_IMP_LEVEL_IMPERSONATE, NULL, EOAC_NONE, NULL);
    _ASSERTE(SUCCEEDED(hr));

    hr = _Module.RegisterClassObjects(CLSCTX_LOCAL_SERVER | CLSCTX_REMOTE_SERVER, REGCLS_MULTIPLEUSE);
    _ASSERTE(SUCCEEDED(hr));


    if (m_roxen == NULL)
      m_roxen = new CRoxen(m_bService ? FALSE : TRUE);

    if (m_roxen->Start(TRUE))
    {
      if (m_bService || _Module.GetCmdLine().GetVerbose() > 0)
        LogEvent(_T("Service started"));

      if (m_bService)
        SetServiceStatus(SERVICE_RUNNING);
      

      // When the message loop returns we should clean up and exit
      MessageLoop(m_roxen->GetProcessList(), m_roxen->GetProcessCount());
    }

    if (m_roxen != NULL)
    {
      // Wait 15 sec for the pike process to terminate before killing it
      if (WaitForSingleObject(m_roxen->GetProcess(), 15000) == WAIT_TIMEOUT)
        TerminateProcess(m_roxen->GetProcess(), 1000);

      delete m_roxen;
      m_roxen = NULL;
    }
    
    _Module.RevokeClassObjects();

    CoUninitialize();
}

//////////////////////////////////////////////////////////////////////////////////////////////
// Service stop
inline void CServiceModule::Stop(BOOL write_stop_file)
{
    SetServiceStatus(SERVICE_STOP_PENDING);

    if (m_roxen != NULL)
    {
      m_roxen->Stop(write_stop_file);
    }

    PostThreadMessage(dwThreadID, WM_QUIT, 0, 0);
}

/////////////////////////////////////////////////////////////////////////////
//
#ifdef BUILD_DLL
extern "C" 
__declspec( dllexport )
int __cdecl roxenMain(int argc, _TCHAR **argv, int * restart, char * szServiceName)
{
    LPTSTR lpCmdLine = GetCommandLine(); //this line necessary for _ATL_MIN_CRT

#else
#ifdef _WINDOWS

extern "C" int WINAPI _tWinMain(HINSTANCE hInstance, 
    HINSTANCE /*hPrevInstance*/, LPTSTR lpCmdLine, int /*nShowCmd*/)
{
    lpCmdLine = GetCommandLine(); //this line necessary for _ATL_MIN_CRT

#else /* _CONSOLE */

extern "C" int __cdecl _tmain(int argc, _TCHAR **argv, _TCHAR **envp)
{
    HINSTANCE hInstance = GetModuleHandle(0);

    LPTSTR lpCmdLine = GetCommandLine(); //this line necessary for _ATL_MIN_CRT
#endif // _WINDOWS
#endif // BUILD_DLL

    _Module.Init(ObjectMap, hInstance, IDS_SERVICENAME, IDS_SERVICEDESC, &LIBID_STARTDLLLib);
    _Module.m_bService = TRUE;

    CCmdLine & cmdline = _Module.GetCmdLine(FALSE);
    
    char inifile1[2048];
    char inifile2[2048];
    char iniArgs[2048];
    int iLen;
    iniArgs[0] = 'x'; // Fake som dummy program name
    iniArgs[1] = ' ';

    GetCurrentDirectory(sizeof(inifile1), inifile1);
    strcat(inifile1, "/../local/environment.ini");
    iLen = GetPrivateProfileString("Parameters", "default", "", iniArgs+2, sizeof(iniArgs)-2, inifile1);
    if (iLen > 0 && iLen < sizeof(iniArgs)-2)
      cmdline.Parse(iniArgs);
    GetCurrentDirectory(sizeof(inifile2), inifile2);
    strcat(inifile2, "/../local/environment2.ini");
    iLen = GetPrivateProfileString("Parameters", "default", "", iniArgs+2, sizeof(iniArgs)-2, inifile2);
    if (iLen > 0 && iLen < sizeof(iniArgs)-2)
      cmdline.Parse(iniArgs);


    char envArgs[2048];
    int len;
    envArgs[0] = 'x'; // Fake som dummy program name
    envArgs[1] = ' ';
    if ((len=GetEnvironmentVariable("ROXEN_ARGS", envArgs+2, sizeof(envArgs)-2)) > 0 && len < sizeof(envArgs)-2)
      cmdline.Parse(envArgs);


    cmdline.Parse(argc, argv);
    

    // The work has already been done above, but the debug printout is better
    // to have _after_ parse_args (consider --help and --version)
    HANDLE hOut = GetStdHandle(STD_OUTPUT_HANDLE);
    if (iLen > 0 && iLen < sizeof(iniArgs)-2 && cmdline.GetVerbose() > 0)
      cmdline.OutputLineFmt(hOut, "Used .B%sB. from .Blocal/environment.iniB..", iniArgs+2);

    if (len > 0 && len < sizeof(envArgs)-2 && cmdline.GetVerbose() > 0)
      cmdline.OutputLineFmt(hOut, "Used .B%sB. from .BROXEN_ARGSB..", envArgs+2);

    if (cmdline.IsHelp())
    {
      cmdline.PrintHelp();
      return S_OK;
    }

    if (cmdline.IsVersion())
    {
      printf("Roxen startdll version %s.%s.%s\n", STR(NTSTART_MAJOR_VERSION),
        STR(NTSTART_MINOR_VERSION), STR(NTSTART_BUILD_VERSION) );
      CRoxen::PrintVersion();
      return S_OK;
    }

    if (cmdline.IsInstall())
      return _Module.RegisterServer(TRUE, TRUE);
    else if (cmdline.IsRegister())
      return _Module.RegisterServer(TRUE, FALSE);

    if (cmdline.IsRemove())
      return _Module.UnregisterServer();

    // Are we Service or Local Server
    CRegKey keyAppID;
    LONG lRes = keyAppID.Open(HKEY_CLASSES_ROOT, _T("AppID"), KEY_READ);
    if (lRes != ERROR_SUCCESS)
        return lRes;

    CRegKey key;
    lRes = key.Open(keyAppID, _T("{EE755A27-6EEA-4AD7-AB21-BCE00C6CFF1A}"), KEY_READ);
    if (lRes != ERROR_SUCCESS)
    {
      printf("Required registry information missing. Run 'ntstart --register' and retry.\n");
      return lRes;
    }

    TCHAR szValue[_MAX_PATH];
    DWORD dwLen = _MAX_PATH;
    lRes = key.QueryValue(szValue, _T("LocalService"), &dwLen);

    _Module.m_bService = FALSE;
    if (lRes == ERROR_SUCCESS)
        _Module.m_bService = TRUE;

    _Module.Start();

    // Signal to the dll loader to perform a restart if requested in the _Module
    *restart = _Module.GetRestartFlag();
    if (_Module.m_bService)
      strcpy(szServiceName, _Module.m_szServiceName);
    else
      strcpy(szServiceName, "");

    // Kill the internal roxen MySql server
    if (!cmdline.IsKeepMysql()) {
	  _Module.LogEvent(_T("Shutting down MySQL."));
      KillMySql(cmdline.GetConfigDir().c_str());
	}

    // When we get here, the service has been stopped
    return _Module.m_status.dwWin32ExitCode;
}

#if 0 // Balancing...
}
}
#endif /* 0 */

#ifdef BUILD_DLL
///////////////
//
__declspec( dllexport )
BOOL WINAPI DllMain(
  HINSTANCE hinstDLL,  // handle to the DLL module
  DWORD fdwReason,     // reason for calling function
  LPVOID lpvReserved   // reserved
)
{
  if (fdwReason == DLL_PROCESS_ATTACH)
    hInstance = hinstDLL;

  return TRUE;
}
#endif
