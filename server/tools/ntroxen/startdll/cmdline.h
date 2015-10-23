// cmdline.h: interface for the CCmdLine class.
//
// $Id$
//
//////////////////////////////////////////////////////////////////////

#if !defined(AFX_CMDLINE_H__F6894D74_C532_40F7_8873_2A23BACE2581__INCLUDED_)
#define AFX_CMDLINE_H__F6894D74_C532_40F7_8873_2A23BACE2581__INCLUDED_

#if _MSC_VER > 1000
#pragma once
#endif // _MSC_VER > 1000

#include <string>

////////////////////////
//
//
class CArgList
{
  typedef char *(tData);

public:
  CArgList();
  virtual ~CArgList();

  BOOL Add(const char *item);
  BOOL AddIfNew(const char *item);
  BOOL Remove(const char *item);
  BOOL Exists(const char *item);

  tData * GetList() { return m_pData; }

private:
  // Functions
  BOOL CopyData(tData *p, int size);
  BOOL ReSize(int diff);

  //Data
  int m_Count;
  int m_Size;
  tData *m_pData;
};


////////////////////////
//
//
class CCmdLine  
{
  enum tArgType {
    eArgStart,
    eArgNtLoader,
    eArgPike,
    eArgRoxen,
    eArgDebug,
    eArgNoDebug,
    eArgVersion,
    eArgSelfTest,
    eArgHelp,
    eArgMoreData,

    eArgUnsupported
  };

public:
  CCmdLine();
  virtual ~CCmdLine();

  BOOL Parse(int argc, char *argv[]);
  BOOL Parse(char *cmdline);
  void ParseFinish();

  void PrintHelp();

  BOOL IsInstall()    { return m_bInstall; }
  BOOL IsRegister()   { return m_bRegister; }
  BOOL IsRemove()     { return m_bRemove; }
  BOOL IsOnce()       { return m_bOnce; }
  BOOL IsHelp()       { return m_bHelp; }
  BOOL IsVersion()    { return m_bVersion; }
  BOOL IsPassHelp()   { return m_bPassHelp; }
  BOOL IsKeepMysql()  { return m_bKeepMysql; }
  BOOL IsMsdev()      { return m_bMsdev; }
  BOOL IsCheckVersion() { return m_bCheckVersion; }

  int GetVerbose()    { return m_iVerbose; }
  int GetDebug()      { return m_iDebug; }

  std::string GetLogDir()     { return m_LogDir; }
  std::string GetConfigDir()  { return m_ConfigDir; }

  CArgList & GetNtstartArgs() { return m_saNtstartArgs; }
  CArgList & GetPikeArgs()    { return m_saPikeArgs; }
  CArgList & GetPikeDefines() { return m_saPikeDefines; }
  CArgList & GetRoxenArgs()   { return m_saRoxenArgs; }

  void SetKeepMysql(BOOL flag = TRUE) { m_bKeepMysql = flag; }

  static void OutputLine(HANDLE out, char *line);
  static void OutputLineFmt(HANDLE out, char *pFormat, ...);

protected:

private:
  void SplitCmdline(_TSCHAR *cmdstart, _TSCHAR **argv, _TSCHAR *args, int *numargs, int *numchars);
  int ParseArg(int argc, char *argv[], CCmdLine::tArgType & type);
  BOOL Match(char *s, char *pattern, char *delim, char **value);


  CArgList m_saNtstartArgs;
  CArgList m_saPikeArgs;
  CArgList m_saPikeDefines;
  CArgList m_saRoxenArgs;

  BOOL m_bPreloaded;
  BOOL m_bParseFinished;

  BOOL m_bInstall;
  BOOL m_bRegister;
  BOOL m_bRemove;
  BOOL m_bOnce;
  BOOL m_bHelp;
  BOOL m_bVersion;
  BOOL m_bPassHelp;
  BOOL m_bKeepMysql;
  BOOL m_bMsdev;
  BOOL m_bCheckVersion;

  int  m_iVerbose;
  int  m_iDebug;

  std::string m_SelfTestDir;
  std::string m_LogDir;
  std::string m_ConfigDir;
};

#endif // !defined(AFX_CMDLINE_H__F6894D74_C532_40F7_8873_2A23BACE2581__INCLUDED_)
