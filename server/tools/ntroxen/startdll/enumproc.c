#include <windows.h>

#include "EnumProc.h"
#include <tlhelp32.h>
#include <vdmdbg.h>
#include <stdio.h>
#include <string.h>


//extern FoundProc;
static FoundProc;

#define KillProc    0x8000
#define ProcMask    0x0fff
#define RoxenMysql  0x0001

typedef struct
{
  DWORD          dwPID ;
  PROCENUMPROC   lpProc ;
  DWORD          lParam ;
  BOOL           bEnd ;
} EnumInfoStruct ;

//BOOL WINAPI Enum16( DWORD dwThreadId, WORD hMod16, WORD hTask16,
//  PSZ pszModName, PSZ pszFileName, LPARAM lpUserDefined ) ;

// The EnumProcs function takes a pointer to a callback function
// that will be called once per process in the system providing
// process EXE filename and process ID.
// Callback function definition:
// BOOL CALLBACK Proc( DWORD dw, LPCSTR lpstr, LPARAM lParam ) ;
// 
// lpProc -- Address of callback routine.
// 
// lParam -- A user-defined LPARAM value to be passed to
//           the callback routine.
BOOL WINAPI EnumProcs( PROCENUMPROC lpProc, LPARAM lParam )
{
  OSVERSIONINFO  osver ;
  HINSTANCE      hInstLib ;
  HINSTANCE      hInstLib2 ;
  HANDLE         hSnapShot ;
  PROCESSENTRY32 procentry ;
  BOOL           bFlag ;
  LPDWORD        lpdwPIDs ;
  DWORD          dwSize, dwSize2, dwIndex ;
  HMODULE        hMod ;
  HANDLE         hProcess ;
  char           szFileName[ MAX_PATH ] ;
  EnumInfoStruct sInfo ;

  // ToolHelp Function Pointers.
  HANDLE (WINAPI *lpfCreateToolhelp32Snapshot)(DWORD,DWORD) ;
  BOOL (WINAPI *lpfProcess32First)(HANDLE,LPPROCESSENTRY32) ;
  BOOL (WINAPI *lpfProcess32Next)(HANDLE,LPPROCESSENTRY32) ;

  // PSAPI Function Pointers.
  BOOL (WINAPI *lpfEnumProcesses)( DWORD *, DWORD cb, DWORD * );
  BOOL (WINAPI *lpfEnumProcessModules)( HANDLE, HMODULE *,
     DWORD, LPDWORD );
  DWORD (WINAPI *lpfGetModuleFileNameEx)( HANDLE, HMODULE,
     LPTSTR, DWORD );

  // VDMDBG Function Pointers.
  INT (WINAPI *lpfVDMEnumTaskWOWEx)( DWORD,
     TASKENUMPROCEX  fp, LPARAM );


  // Check to see if were running under Windows95 or
  // Windows NT.
  osver.dwOSVersionInfoSize = sizeof( osver ) ;
  if( !GetVersionEx( &osver ) )
  {
     return FALSE ;
  }

  // If Windows NT:
  if( osver.dwPlatformId == VER_PLATFORM_WIN32_NT )
  {

     // Load library and get the procedures explicitly. We do
     // this so that we don't have to worry about modules using
     // this code failing to load under Windows 95, because
     // it can't resolve references to the PSAPI.DLL.
     hInstLib = LoadLibraryA( "PSAPI.DLL" ) ;
     if( hInstLib == NULL )
        return FALSE ;

     hInstLib2 = LoadLibraryA( "VDMDBG.DLL" ) ;
     if( hInstLib2 == NULL )
        return FALSE ;

     // Get procedure addresses.
     lpfEnumProcesses = (BOOL(WINAPI *)(DWORD *,DWORD,DWORD*))
        GetProcAddress( hInstLib, "EnumProcesses" ) ;
     lpfEnumProcessModules = (BOOL(WINAPI *)(HANDLE, HMODULE *,
        DWORD, LPDWORD)) GetProcAddress( hInstLib,
        "EnumProcessModules" ) ;
     lpfGetModuleFileNameEx =(DWORD (WINAPI *)(HANDLE, HMODULE,
        LPTSTR, DWORD )) GetProcAddress( hInstLib,
        "GetModuleFileNameExA" ) ;
     lpfVDMEnumTaskWOWEx =(INT(WINAPI *)( DWORD, TASKENUMPROCEX,
        LPARAM))GetProcAddress( hInstLib2, "VDMEnumTaskWOWEx" );
     if( lpfEnumProcesses == NULL ||
        lpfEnumProcessModules == NULL ||
        lpfGetModuleFileNameEx == NULL ||
        lpfVDMEnumTaskWOWEx == NULL)
        {
           FreeLibrary( hInstLib ) ;
           FreeLibrary( hInstLib2 ) ;
           return FALSE ;
        }

     // Call the PSAPI function EnumProcesses to get all of the
     // ProcID's currently in the system.
     // NOTE: In the documentation, the third parameter of
     // EnumProcesses is named cbNeeded, which implies that you
     // can call the function once to find out how much space to
     // allocate for a buffer and again to fill the buffer.
     // This is not the case. The cbNeeded parameter returns
     // the number of PIDs returned, so if your buffer size is
     // zero cbNeeded returns zero.
     // NOTE: The "HeapAlloc" loop here ensures that we
     // actually allocate a buffer large enough for all the
     // PIDs in the system.
     dwSize2 = 256 * sizeof( DWORD ) ;
     lpdwPIDs = NULL ;
     do
     {
        if( lpdwPIDs )
        {
           HeapFree( GetProcessHeap(), 0, lpdwPIDs ) ;
           dwSize2 *= 2 ;
        }
        lpdwPIDs = (unsigned long *)HeapAlloc( GetProcessHeap(), 0, dwSize2 );
        if( lpdwPIDs == NULL )
        {
           FreeLibrary( hInstLib ) ;
           FreeLibrary( hInstLib2 ) ;
           return FALSE ;
        }
        if( !lpfEnumProcesses( lpdwPIDs, dwSize2, &dwSize ) )
        {
           HeapFree( GetProcessHeap(), 0, lpdwPIDs ) ;
           FreeLibrary( hInstLib ) ;
           FreeLibrary( hInstLib2 ) ;
           return FALSE ;
        }
     }while( dwSize == dwSize2 ) ;

     // How many ProcID's did we get?
     dwSize /= sizeof( DWORD ) ;

     // Loop through each ProcID.
     for( dwIndex = 0 ; dwIndex < dwSize ; dwIndex++ )
     {
        szFileName[0] = 0 ;
        // Open the process (if we can... security does not
        // permit every process in the system).
        hProcess = OpenProcess(
           PROCESS_QUERY_INFORMATION | PROCESS_VM_READ,
           FALSE, lpdwPIDs[ dwIndex ] ) ;
        if( hProcess != NULL )
        {
           // Here we call EnumProcessModules to get only the
           // first module in the process this is important,
           // because this will be the .EXE module for which we
           // will retrieve the full path name in a second.
           if( lpfEnumProcessModules( hProcess, &hMod,
              sizeof( hMod ), &dwSize2 ) )
           {
              // Get Full pathname:
              if( !lpfGetModuleFileNameEx( hProcess, hMod,
                 szFileName, sizeof( szFileName ) ) )
              {
                 szFileName[0] = 0 ;
                }
           }
           CloseHandle( hProcess ) ;
        }
        // Regardless of OpenProcess success or failure, we
        // still call the enum func with the ProcID.
        if(!lpProc( lpdwPIDs[dwIndex], 0, szFileName, lParam))
           break ;

        // Did we just bump into an NTVDM?
        if( _stricmp( szFileName+(strlen(szFileName)-9),
           "NTVDM.EXE")==0)
        {
           // Fill in some info for the 16-bit enum proc.
           sInfo.dwPID = lpdwPIDs[dwIndex] ;
           sInfo.lpProc = lpProc ;
           sInfo.lParam = lParam ;
           sInfo.bEnd = FALSE ;
           // Enum the 16-bit stuff.
           lpfVDMEnumTaskWOWEx( lpdwPIDs[dwIndex],
              (TASKENUMPROCEX) Enum16,
              (LPARAM) &sInfo);

           // Did our main enum func say quit?
           if(sInfo.bEnd)
              break ;
        }
     }

     HeapFree( GetProcessHeap(), 0, lpdwPIDs ) ;
     FreeLibrary( hInstLib2 ) ;

  // If Windows 95:
  }else if( osver.dwPlatformId == VER_PLATFORM_WIN32_WINDOWS )
  {


     hInstLib = LoadLibraryA( "Kernel32.DLL" ) ;
     if( hInstLib == NULL )
        return FALSE ;

     // Get procedure addresses.
     // We are linking to these functions of Kernel32
     // explicitly, because otherwise a module using
     // this code would fail to load under Windows NT,
     // which does not have the Toolhelp32
     // functions in the Kernel 32.
     lpfCreateToolhelp32Snapshot=
        (HANDLE(WINAPI *)(DWORD,DWORD))
        GetProcAddress( hInstLib,
        "CreateToolhelp32Snapshot" ) ;
     lpfProcess32First=
        (BOOL(WINAPI *)(HANDLE,LPPROCESSENTRY32))
        GetProcAddress( hInstLib, "Process32First" ) ;
     lpfProcess32Next=
        (BOOL(WINAPI *)(HANDLE,LPPROCESSENTRY32))
        GetProcAddress( hInstLib, "Process32Next" ) ;
     if( lpfProcess32Next == NULL ||
        lpfProcess32First == NULL ||
        lpfCreateToolhelp32Snapshot == NULL )
     {
        FreeLibrary( hInstLib ) ;
        return FALSE ;
     }

     // Get a handle to a Toolhelp snapshot of the systems
     // processes.
     hSnapShot = lpfCreateToolhelp32Snapshot(
        TH32CS_SNAPPROCESS, 0 ) ;
     if( hSnapShot == INVALID_HANDLE_VALUE )
     {
        FreeLibrary( hInstLib ) ;
        return FALSE ;
     }

     // Get the first process' information.
     procentry.dwSize = sizeof(PROCESSENTRY32) ;
     bFlag = lpfProcess32First( hSnapShot, &procentry ) ;

     // While there are processes, keep looping.
     while( bFlag )
     {
        // Call the enum func with the filename and ProcID.
        if(lpProc( procentry.th32ProcessID, 0,
           procentry.szExeFile, lParam ))
        {
           procentry.dwSize = sizeof(PROCESSENTRY32) ;
           bFlag = lpfProcess32Next( hSnapShot, &procentry );
        }else
           bFlag = FALSE ;
     }


  }else
     return FALSE ;

  // Free the library.
  FreeLibrary( hInstLib ) ;

  return TRUE ;
}

BOOL WINAPI Enum16( DWORD dwThreadId, WORD hMod16, WORD hTask16,
  PSZ pszModName, PSZ pszFileName, LPARAM lpUserDefined )
{
  BOOL bRet ;

  EnumInfoStruct *psInfo = (EnumInfoStruct *)lpUserDefined ;

  bRet = psInfo->lpProc( psInfo->dwPID, hTask16, pszFileName,
     psInfo->lParam ) ;

  if(!bRet)
  {
     psInfo->bEnd = TRUE ;
  }

  return !bRet;
} 
   
BOOL CALLBACK Proc( DWORD dw, WORD w16, /*LPCSTR*/ LPSTR lpstr, LPARAM lParam )
{
	int iKill = 0, iRoxenMysql = 0;
	HANDLE hProc;
	
	if(lParam & KillProc)
	{
		iKill = 1;
	}

    switch (lParam & ProcMask)
    {
    case RoxenMysql:
      iRoxenMysql = 1;
      break;
      
    default:
      return FALSE;
    }


    // convert the process path/name to lowercase
    _strlwr(lpstr);

	if(iRoxenMysql && (strstr(lpstr, "roxen_mysql.exe") != NULL))
	{
		FoundProc = 1;
		if(iKill)
		{
			hProc = OpenProcess(SYNCHRONIZE|PROCESS_TERMINATE, FALSE, dw);
			if(hProc != NULL)
				TerminateProcess(hProc, 0);
			CloseHandle(hProc);
		}
	}

	return TRUE;
}

void Kill(DWORD id)
{
  HANDLE hProc;

  hProc = OpenProcess(SYNCHRONIZE|PROCESS_TERMINATE, FALSE, id);
  if(hProc != NULL)
				TerminateProcess(hProc, 0);
  CloseHandle(hProc);
}


BOOL GetMySQLBinaryPath(char *inProgramName, char *outPath,
			unsigned int maxlen);

BOOL KillMySql(const char *confdir)
{
  char pidfile[MAX_PATH];
  char spid[20];
  int pid = 0;
  HANDLE hPid;
  DWORD cpid;

/*
  // Try to shutdown nicely
  system("mysql\\bin\\mysqladmin --user=rw --pipe shutdown >NUL: 2>&1");

  Sleep(500);

  // Is any roxen_mysql.exe around?
  FoundProc = 0;
  EnumProcs(&Proc, RoxenMysql);
  if(!FoundProc)
    return TRUE;
  
  Sleep(500);

  // Try to shutdown nicely (again!)
  // mysqladmin fails to connect but makes the process go away!!
  system("mysql\\bin\\mysqladmin --user=rw --pipe shutdown >NUL: 2>&1");

  // Is any roxen_mysql.exe around?
  FoundProc = 0;
  EnumProcs(&Proc, RoxenMysql);
  if(!FoundProc)
    return TRUE;
*/


  //  First choice is to kill via mysqladmin since that will avoid table
  //  corruption. However, it relies on finding the binary at a given
  //  path relative to the server so we'll preserve the brutal process
  //  termination for situations where this isn't valid.
  char short_pipe_path[_MAX_PATH];
  TCHAR long_pipe_path[_MAX_PATH];
  strcpy(short_pipe_path, confdir);
  strcat(short_pipe_path, "\\_mysql\\pipe");
  if (GetFullPathName(short_pipe_path, _MAX_PATH, long_pipe_path, NULL)) {
    char cmd[4000];
    char mysqladmin_path[_MAX_PATH];
    
    //  Convert full path into a valid MySQL pipe identifier on the form
    //  "C_\path\to\configurations\_mysql\pipe".
    if (long_pipe_path[1] == ':')
      long_pipe_path[1] = '_';
    
    if (GetMySQLBinaryPath("mysqladmin", mysqladmin_path, _MAX_PATH)) {
      sprintf(cmd, "\"%s\" "
		   "-u rw "
		   "--pipe "
		   "--socket=\"%s\" "
		   "shutdown "
	      /*">NUL: 2>&1"*/,
	      mysqladmin_path,
	      long_pipe_path);
      {
	TCHAR cwd[_MAX_PATH];
	STARTUPINFO info;
	PROCESS_INFORMATION proc;
	int ret;
	
	cwd[0] = 0;
	GetCurrentDirectory(_MAX_PATH, cwd);
	GetStartupInfo(&info);
	/* info.wShowWindow = SW_HIDE; */
	info.dwFlags |= STARTF_USESHOWWINDOW;
	ret = CreateProcess(NULL,
			    cmd,
			    NULL,  /* process security attribute */
			    NULL,  /* thread security attribute */
			    1,     /* inherithandles */
			    0,     /* create flags */
			    NULL,  /* environment */
			    cwd,   /* current dir */
			    &info,
			    &proc);
	if (ret) {
	  WaitForSingleObject(proc.hProcess, INFINITE);
	  CloseHandle(proc.hThread);
	  CloseHandle(proc.hProcess);
	}
      }
    }
  }
  
  Sleep(1000);

  strcpy(pidfile, confdir);
  strcat(pidfile, "\\_mysql\\mysql_pid");
  hPid = CreateFile(pidfile,
    GENERIC_READ,
    FILE_SHARE_READ|FILE_SHARE_WRITE,
    NULL,
    OPEN_EXISTING,
    FILE_ATTRIBUTE_NORMAL,
    NULL);
  if (hPid == INVALID_HANDLE_VALUE)
    return TRUE;

  if (ReadFile(hPid, spid, sizeof(spid)-1, &cpid, NULL) == 0)
  {
    CloseHandle(hPid);
    return TRUE;
  }
  CloseHandle(hPid);
  spid[cpid] = 0;
  pid = atoi(spid);
  if (pid > 0)
    Kill(pid);

  DeleteFile(pidfile);

/*
  // Is any roxen_mysql.exe around? If Yes KILL!
  FoundProc = 0;
  EnumProcs(&Proc, RoxenMysql | KillProc);
  if(FoundProc)
    return FALSE;
*/  

  return TRUE;
}


BOOL GetMySQLBinaryPath(char *inProgramName, char *outPath,
			unsigned int maxlen)
{
  FILE *fd;
  char basedir[_MAX_PATH];
  
  outPath[0] = 0;
  basedir[0] = 0;
  if (maxlen < 1)
    return FALSE;
  
  //  We expect current directory to be server-x.y.z. Look for file named
  //  mysql-location.txt which contains data on the following form:
  //
  //    # comments
  //    key1 = value
  //    key2 = value
  //
  //  We're interested in the key "basedir" (from which we can find the
  //  bin\{program name} entry) or a direct key for the program in question.

  if (fd = fopen("mysql-location.txt", "r")) {
    char *key, *val, *p;
    
    while (1) {
      char line[1000];
      if (!fgets(line, sizeof(line), fd))
	break;
      
      key = NULL;
      val = NULL;
      
      //  Look for comment and terminate line
      if (p = strchr(line, '#'))
	*p = 0;
      
      //  Skip leading whitespace
      p = line;
      while (*p == ' ' || *p == '\t')
	p++;
      
      //  Extract key name
      key = p;
      while (*p && !(*p == ' ' || *p == '\t' || *p == '='))
	p++;
      if (!*p)
	continue;
      if (*p == '=') {
	*p++ = 0;
      } else {
	*p++ = 0;
	while (*p == ' ' || *p == '\t')
	  p++;
	if (!*p || *p != '=')
	  continue;
	p++;
      }
      
      //  Extract key value and trim whitespace and optional quotes
      while (*p == ' ' || *p == '\t')
	p++;
      if (*p == '"' || *p == '\'')
	p++;
      val = p;
      p = val + strlen(val) - 1;
      while (p > val) {
	if (*p == ' ' || *p == '\t' || *p == '\n' || *p == '\r')
	  *p = 0;
	else if (*p == '"' || *p == '\'') {
	  *p = 0;
	  break;
	} else {
	  break;
	}
	--p;
      }
      if (!strlen(val))
	continue;
      
      //  Is this the key we are looking for?
      if (_stricmp(key, inProgramName) == 0) {
	//  Yes, direct match!
	if (strlen(val) < maxlen)
	  strcpy(outPath, val);
	break;
      }
      
      //  If base directory is given, save for later in case more specific
      //  key remains to be seen.
      if (_stricmp(key, "basedir") == 0) {
	strcpy(basedir, val);
      }
    }
    fclose(fd);
    
    //  If exact path isn't known, try built it from base directory
    if (!strlen(outPath) && strlen(basedir)) {
      if ((strlen(basedir) + strlen(inProgramName) + 9) < maxlen) {
	strcpy(outPath, basedir);
	strcat(outPath, "\\bin\\");
	strcat(outPath, inProgramName);
	strcat(outPath, ".exe");
      }
    }
    
    return strlen(outPath) ? TRUE : FALSE;
  } else {
    //  Take a guess by assuming default \mysql\bin\ subdirectory
    if ((strlen(inProgramName) + 14) < maxlen) {
      strcpy(outPath, "mysql\\bin\\");
      strcat(outPath, inProgramName);
      strcat(outPath, ".exe");
      return TRUE;
    }
  }
  return FALSE;
}
