// roxen.h: interface for the CRoxen class.
//
// $Id: roxen.h,v 1.1 2001/05/29 14:35:41 tomas Exp $
//
//////////////////////////////////////////////////////////////////////

#if !defined(AFX_ROXEN_H__687F3297_9A48_455D_A41E_C6306A59F0CB__INCLUDED_)
#define AFX_ROXEN_H__687F3297_9A48_455D_A41E_C6306A59F0CB__INCLUDED_

#if _MSC_VER > 1000
#pragma once
#endif // _MSC_VER > 1000

#include <string>
#include "cmdline.h"


class CRoxen  
{
public:
  CRoxen(int console);
  virtual ~CRoxen();
  int Start(int first_time);
  int Stop(BOOL write_stop_file);
  HANDLE GetProcess() { return hProcess; }
  HANDLE *GetProcessList() { return &hProcess; }
  int GetProcessCount() { return 1; }

  static void PrintVersion();

  //impl
private:
  void ErrorMsg (int show_last_err, const TCHAR *fmt, ...);
  std::string FindPike();
  BOOL CreatePikeCmd(char *cmd, std::string pikeloc, CCmdLine &cmdline, char *key);

  //data
private:
  int m_initDone;
  char key[9];
  int console_mode;  
  HANDLE hProcess;
};

#endif // !defined(AFX_ROXEN_H__687F3297_9A48_455D_A41E_C6306A59F0CB__INCLUDED_)
