// start1st.cpp : Defines the entry point for the console application.
//

#include "stdafx.h"
#include <windows.h>
#include <tchar.h>
#include <stdlib.h>
#include <direct.h>

#define CONFIGDIR "configurations"
#define SERVERVERSION "server_version"
#define DLLNAME "startdll.dll"

typedef int (*roxenMain_t)(int, char **, int *, char *);

struct tSearch {
  char * dir;
  char * file;
};

static char version[] = STR(NTSTART_MAJOR_VERSION) "." STR(NTSTART_MINOR_VERSION) "." STR(NTSTART_BUILD_VERSION);
static char progname[] = "Roxen starter";
static BOOL have_console;

#if DEBUGLEVEL > 0
#define DEBUG_MSG1 ErrorMsg
#else
#define DEBUG_MSG1 dummyMsg
#endif

#if DEBUGLEVEL > 1
#define DEBUG_MSG2 ErrorMsg
#else
#define DEBUG_MSG2 dummyMsg
#endif


/////////////////
//
inline void dummyMsg(int show_last_err, const TCHAR *fmt, ...)
{
}

/////////////////
//
void ErrorMsg (int show_last_err, const TCHAR *fmt, ...)
{
  va_list args;
  TCHAR *sep = fmt[0] ? TEXT(": ") : TEXT("");
  TCHAR buf[4098];
  size_t n;
  DWORD ExitCode = 0;

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

  if (have_console)
    puts(buf);
  else
    MessageBoxEx(0, buf, progname, MB_SERVICE_NOTIFICATION, NULL);
}

/////////////////
//
BOOL GetServerDir(char * path, int maxlen)
{
  int len;
  FILE *fd;
  TCHAR cwd[_MAX_PATH];
  cwd[0] = 0;
  _tgetcwd (cwd, _MAX_PATH);

  tSearch cfgSearch[] = {
    { ".", CONFIGDIR "\\" SERVERVERSION },
    { "..", CONFIGDIR "\\" SERVERVERSION },
#ifdef _DEBUG
    { "..\\..", CONFIGDIR "\\" SERVERVERSION },
#endif
    { NULL, NULL }
  };

  path[0] = '\0';
  int i;
  for (i=0; cfgSearch[i].dir != NULL; i++)
  {
    if (_chdir (cfgSearch[i].dir))
    {
      ErrorMsg (TRUE, TEXT("Could not change to the directory %s\\.."), cwd);
      continue;
    }
    if (!(fd = fopen (cfgSearch[i].file, "r"))) {
      continue;
    }
    
    cwd[0] = 0;
    _tgetcwd (cwd, _MAX_PATH);

    if (!(len = fread (path, 1, maxlen, fd))) {
      ErrorMsg (TRUE, TEXT("Could not read %s\\%s"), cwd, cfgSearch[i].file);
      return FALSE;
    }
    fclose (fd);
    if (len >= _MAX_PATH) {
      ErrorMsg (FALSE, TEXT("Exceedingly long server version "
        "in %s\\%s"), cwd, cfgSearch[i].file);
      return FALSE;
    }
    if (memchr (path, 0, len)) {
      ErrorMsg (FALSE, TEXT("%s\\%s contains a null character"), cwd, cfgSearch[i].file);
      return FALSE;
    }
    
	int j;
    for (j = len - 1; j && isspace (path[j]); j--) {}
    len = j + 1;
    path[len] = 0;

    return TRUE;
  }

  //restore current directory
  _chdir(cwd);

  // Fallback to "server" 
  strcpy(path, "server");
  return TRUE;
}


BOOL StartRoxenService(char * szServiceName)
{
    BOOL bResult = FALSE;

    SC_HANDLE hSCM = ::OpenSCManager(NULL, NULL, SC_MANAGER_ALL_ACCESS);

    if (hSCM != NULL)
    {
        SC_HANDLE hService = ::OpenService(hSCM, szServiceName, SERVICE_START);
        if (hService != NULL)
        {
            if (!StartService(hService, 0, NULL))
              DEBUG_MSG1(TRUE, "StartService failed NULL");

            bResult = TRUE;
            ::CloseServiceHandle(hService);
        }
        else
          DEBUG_MSG1(TRUE, "OpenService returned NULL");
        ::CloseServiceHandle(hSCM);
    }
    else
        DEBUG_MSG1(TRUE, "OpenSCManager returned NULL");

    return bResult;
}


/////////////////
//
int main(int argc, char* argv[])
{
  BOOL stop = FALSE;
  BOOL bVer = FALSE;
  BOOL bPassHelp = FALSE;

  for (int i=1; i<argc; i++)
  {
    if (strcmp(argv[i], "--program") == 0)
    {
      bPassHelp = TRUE;
    }
    if (!bPassHelp && strcmp(argv[i], "--version") == 0)
    {
      bVer = TRUE;
    }
  }

  if (bVer)
    printf("\n%s version %s\n", progname, version);

  have_console = FALSE;
  if (GetStdHandle(STD_ERROR_HANDLE) != 0)
    have_console = TRUE;

  DEBUG_MSG2(FALSE, "stdin: %d\nstdout: %d\nstderr: %d",
    GetStdHandle(STD_INPUT_HANDLE),
    GetStdHandle(STD_OUTPUT_HANDLE),
    GetStdHandle(STD_ERROR_HANDLE));

  TCHAR startdir[MAX_PATH];
  GetCurrentDirectory(sizeof(startdir), startdir);
  DEBUG_MSG1(FALSE, startdir);

#ifndef _DEBUG_WITH_DLL
  GetModuleFileName(0, startdir, MAX_PATH);
  char * p = strrchr(startdir, '\\');
  if (p != 0)
    *p = '\0';
  SetCurrentDirectory(startdir);
  DEBUG_MSG1(FALSE, startdir);
#endif

  while (!stop)
  {
    char serverdir[MAX_PATH];
    char dllpath[MAX_PATH];

    GetServerDir(serverdir, MAX_PATH);

    // Create the path to the DLL
    strncpy(dllpath, serverdir, MAX_PATH);
    dllpath[MAX_PATH-1] = '\0';
    int pathlen = strlen(dllpath);
    if (pathlen > 0 && dllpath[pathlen-1] != '\\')
      strcat(dllpath, "\\");
    strcat(dllpath, DLLNAME);

    DEBUG_MSG1(FALSE, "%s: Loading roxenMain from '%s'\n", progname, dllpath);

#ifdef _DEBUG_WITH_DLL
    strcpy(dllpath, startdir);
    strcat(dllpath, "\\");
    strcat(dllpath, "startdll\\Debug\\");
    strcat(dllpath, DLLNAME);
    printf("%s: DEBUG OVERRIDE Loading roxenMain from '%s'\n", progname, dllpath);
#endif

    // Load the version specific roxen starter dll
    HMODULE hServer = LoadLibraryEx(dllpath, NULL, LOAD_WITH_ALTERED_SEARCH_PATH);
    if (hServer == 0)
    {
      ErrorMsg(FALSE, "Failed to load '%s'\n", dllpath);
      return 0x1001;
    }
    
    roxenMain_t roxenMain = (roxenMain_t)GetProcAddress(hServer, "roxenMain");
    if (roxenMain == 0)
    {
      ErrorMsg(FALSE, "roxenMain not found: '%s' is corrupt\n", dllpath);
      return 0x1002;
    }

    SetCurrentDirectory(serverdir);

    // Transfer control to the roxen starter
    int restart = FALSE;
    char szServiceName[256];
    int ret = roxenMain(argc, argv, &restart, szServiceName);
    if (restart)
    {
      DEBUG_MSG1(FALSE, "Restarting ...");
      if (strlen(szServiceName) > 0)
      {
        DEBUG_MSG1(FALSE, "Service %s", szServiceName);
        Sleep(500);
        int ret = StartRoxenService(szServiceName);
        if (!ret)
        {
          ErrorMsg(TRUE, "Restart of the RoxenService FAILED!");
        }
        stop = TRUE;
      }
    }
    else
    {
      DEBUG_MSG1(FALSE, "Stopping ...");
      stop = TRUE;
    }
      
    SetCurrentDirectory(startdir);

    if (FreeLibrary(hServer) == NULL)
    {
      ErrorMsg(TRUE, "Failed to unload '%s'", dllpath);
      return 0x1003;
    }

    hServer = NULL;
    roxenMain = NULL;
  }

	return 0;
}

