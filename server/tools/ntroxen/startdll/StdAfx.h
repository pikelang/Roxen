// stdafx.h : include file for standard system include files,
//      or project specific include files that are used frequently,
//      but are changed infrequently
//
// $Id$
//

#if !defined(AFX_STDAFX_H__E0590E86_A99B_4C9D_85F9_0FB1752360D0__INCLUDED_)
#define AFX_STDAFX_H__E0590E86_A99B_4C9D_85F9_0FB1752360D0__INCLUDED_

#if _MSC_VER > 1000
#pragma once
#endif // _MSC_VER > 1000

#define STRICT
#ifndef _WIN32_WINNT
#define _WIN32_WINNT 0x0400
#endif
#define _ATL_APARTMENT_THREADED

#include <atlbase.h>

#include "../version.h"
#include "roxen.h"
#include "cmdline.h"

//You may derive a class from CComModule and use it if you want to override
//something, but do not change the name of _Module

class CServiceModule : public CComModule
{
public:
  enum ELaunchType {
    launchMark,
      launchIfPending,
      launchLaunch,
  };

  CServiceModule();

  HRESULT RegisterServer(BOOL bRegTypeLib, BOOL bService);
  HRESULT UnregisterServer();
  void Init(_ATL_OBJMAP_ENTRY* p, HINSTANCE h, UINT nServiceNameID, UINT nServiceDescID, const GUID* plibid = NULL);
  void Start();
  void Stop(BOOL write_stop_file);
  void ServiceMain(DWORD dwArgc, LPTSTR* lpszArgv);
  void Handler(DWORD dwOpcode);
  BOOL WINAPI ControlHandler( DWORD dwCtrlType );
  void Run();
  BOOL IsInstalled();
  BOOL Install();
  BOOL Uninstall();
  LONG Unlock();
  void LogEvent(LPCTSTR pszFormat, ...);
  void SetServiceStatus(DWORD dwState);
  BOOL IsStopping();
  void SetupAsLocalServer();
  BOOL GetRestartFlag() { return m_pendingLaunch; }
  void SetRestartFlag(BOOL value) { m_pendingLaunch = value; }
  CCmdLine & GetCmdLine(BOOL finish=TRUE) { if (finish) m_Cmdline.ParseFinish(); return m_Cmdline; }
  
  //Implementation
private:
  static void WINAPI _ServiceMain(DWORD dwArgc, LPTSTR* lpszArgv);
  static void WINAPI _Handler(DWORD dwOpcode);
  static BOOL WINAPI _ControlHandler( DWORD dwCtrlType );

protected:
  int MessageLoop (HANDLE* lphObjects, int cObjects);
  void MsgLoopCallback(int index);
  
  // data members
public:
  TCHAR m_szServiceName[256];
  TCHAR m_szServiceDesc[256];
  SERVICE_STATUS_HANDLE m_hServiceStatus;
  SERVICE_STATUS m_status;
  DWORD dwThreadID;
  BOOL m_bService;

private:
  CRoxen *m_roxen;
  BOOL m_pendingLaunch;
  CCmdLine m_Cmdline;
};

extern CServiceModule _Module;
#include <atlcom.h>

//{{AFX_INSERT_LOCATION}}
// Microsoft Visual C++ will insert additional declarations immediately before the previous line.

#endif // !defined(AFX_STDAFX_H__E0590E86_A99B_4C9D_85F9_0FB1752360D0__INCLUDED)
