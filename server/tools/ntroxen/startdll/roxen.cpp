// roxen.cpp: implementation of the CRoxen class.
//
// $Id$
//
//////////////////////////////////////////////////////////////////////

#include "stdafx.h"

#include <direct.h>
#include <time.h>

#include <fstream>

#include "roxen.h"


#define LOCATION_COOKIE "(#*&)@(*&$Server Location Cookie:"
#define DEFAULT_LOCATION "C:\\Program Files\\Roxen Internet Software\\Roxen CMS\\server"
#define DEFAULT_PIKE_JRE_JVMDLL "java/jre/bin/hotspot/jvm.dll"

char server_location[_MAX_PATH * 2] = LOCATION_COOKIE DEFAULT_LOCATION;

//////////////////////////////////////////////////////////////////////
// Construction/Destruction
//////////////////////////////////////////////////////////////////////

CRoxen::CRoxen(int console)
{
  console_mode = console;
  hProcess = 0;
}

CRoxen::~CRoxen()
{

}

void CRoxen::ErrorMsg (int show_last_err, const TCHAR *fmt, ...)
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

  _Module.LogEvent("%s", buf);
}


void CRoxen::PrintVersion()
{
  /*
    if [ -f base_server/roxen.pike ]; then
      echo "Roxen WebServer `roxen_version`"
      exit 0
    else
      echo 'base_server/roxen.pike not found!'
      exit 1
    fi
  */
  char version[100];
  char build[100];
  char rel[100];
  version[0] = '\0';
  build[0]   = '\0';
  rel[0]     = '\0';

  if (GetFileAttributes("base_server/roxen.pike") != -1)
  {
    FILE *f = fopen("etc/include/version.h", "rb");
    if (f != NULL)
    {
      char line[200];
      BOOL ver_done = FALSE;
      BOOL build_done = FALSE;
      BOOL rel_done = FALSE;
      while (!ver_done || !build_done || !rel_done)
      {
        if (!fgets(line, sizeof(line), f))
          break;

	if (!ver_done && strstr(line, "roxen_ver") != NULL)
        {
          char *p = line;
          char *v = version;
          while(!isdigit(*p)) *p++;
          while(isdigit(*p)) *v++ = *p++;
          if (*p == '.')
            *v++ = *p++;
          while(isdigit(*p)) *v++ = *p++;
          *v = '\0';
          ver_done = TRUE;
        }

	if (!build_done && strstr(line, "roxen_build") != NULL)
        {
          char *p = line;
          char *b = build;
          while(!isdigit(*p)) *p++;
          while(isdigit(*p)) *b++ = *p++;
          *b = '\0';
          build_done = TRUE;
        }

        if (!rel_done && strstr(line, "roxen_release") != NULL && strchr(line, '=') != NULL)
        {
          char *p = line;
          char *b = rel;
          while(*p && *p != '"') p++;
          *p && p++;
          while(*p && *p != '"') *b++ = *p++;
          *b = '\0';
          rel_done = TRUE;
        }

      }

      fclose(f);

      f = fopen("RELEASE", "rb");
      if (f != NULL)
      {
        if (fgets(line, sizeof(line), f))
          strcpy(rel, line);
        fclose(f);
      }

      printf("Roxen CMS %s.%s%s NT", version, build, rel);
    }
    else
      printf("etc\\include\\version.h not found!");
  }
  else
  {
    printf("base_server\\roxen.pike not found!");
  }
}


std::string CRoxen::FindPike(BOOL setEnv)
{
  char pikeloc[2*_MAX_PATH];
  int len,pathlen;
  char *p;
  int i;
  FILE *fd;
  TCHAR cwd[_MAX_PATH];
  cwd[0] = 0;
  _tgetcwd (cwd, _MAX_PATH);
  static int m_initDone = 0;

  if (!(fd = fopen ("pikelocation.txt", "r"))) {
    if (!m_initDone) {
      if (_chdir ("..")) {
        ErrorMsg (1, TEXT("Could not change to the directory %s\\.."), cwd);
        return "notfound";
      }
      if (!(fd = fopen ("pikelocation.txt", "r"))) {
        if (_chdir (server_location + sizeof (LOCATION_COOKIE) - sizeof (""))) {
          ErrorMsg (1, TEXT("Could not change to the Roxen server directory %hs"),
            server_location + sizeof (LOCATION_COOKIE) - sizeof (""));
          return "notfound";
        }
        if (!(fd = fopen ("pikelocation.txt", "r"))) {
          ErrorMsg (1, TEXT("Roxen server directory not found - "
            "failed to open %s\\pikelocation.txt, "
            "%s\\..\\pikelocation.txt, and "
            "&hs\\pikelocation.txt"),
            cwd, cwd, server_location + sizeof (LOCATION_COOKIE) - sizeof (""));
          return "notfound";
        }
      }
      cwd[0] = 0;
      _tgetcwd (cwd, _MAX_PATH);
    }
    else {
      ErrorMsg (1, TEXT("Failed to open %s\\pikelocation.txt"), cwd);
      return "notfound";
    }
  }
  if (!(len = fread (pikeloc, 1, sizeof(pikeloc)-1, fd))) {
    ErrorMsg (1, TEXT("Could not read %s\\pikelocation.txt"), cwd);
    return "notfound";
  }
  fclose (fd);
  pikeloc[len] = '\0';

  if (memchr (pikeloc, 0, len)) {
    ErrorMsg (0, TEXT("%s\\pikelocation.txt contains a null character"), cwd);
    return "notfound";
  }

  if (p=strtok(pikeloc, "\n"))
  {
    pathlen=strlen(p);
  }
  else
    pathlen = len;

  if (pathlen >= _MAX_PATH) {
    ErrorMsg (0, TEXT("Exceedingly long path to Pike executable "
      "in %s\\pikelocation.txt"), cwd);
    return "notfound";
  }

  for (i = pathlen - 1; i && isspace (pikeloc[i]); i--) {}
  pathlen = i + 1;
  pikeloc[pathlen] = 0;
  
  if (setEnv)
  {
    if (p=strtok(NULL, "\n"))
    {
      while (isspace(*p)) p++;
      for (i = strlen(p) - 1; i && isspace (p[i]); i--) {}
      p[i+1] = 0;
      SetEnvironmentVariable("PIKE_MASTER", p);
    }
    else
    {
      SetEnvironmentVariable("PIKE_MASTER", NULL);
    }
  }

  return pikeloc;
}


std::string CRoxen::FindJvm()
{
  char jvmloc[2*_MAX_PATH];
  int len,pathlen;
  char *p;
  int i;
  FILE *fd;
  TCHAR cwd[_MAX_PATH];
  cwd[0] = 0;
  _tgetcwd (cwd, _MAX_PATH);
  static int m_initDone = 0;

  if (!(fd = fopen ("java/jvmlocation.txt", "r"))) {
    return DEFAULT_PIKE_JRE_JVMDLL;
  }
  if (!(len = fread (jvmloc, 1, sizeof(jvmloc)-1, fd))) {
    ErrorMsg (1, TEXT("Could not read %s\\jvmlocation.txt"), cwd);
    return DEFAULT_PIKE_JRE_JVMDLL;
  }
  fclose (fd);
  jvmloc[len] = '\0';

  if (memchr (jvmloc, 0, len)) {
    ErrorMsg (0, TEXT("%s\\jvmlocation.txt contains a null character"), cwd);
    return DEFAULT_PIKE_JRE_JVMDLL;
  }

  if (p=strtok(jvmloc, "\n"))
  {
    pathlen=strlen(p);
  }
  else
    pathlen = len;

  if (pathlen >= _MAX_PATH) {
    ErrorMsg (0, TEXT("Exceedingly long path to jvm.dll "
      "in %s\\jvmlocation.txt"), cwd);
    return DEFAULT_PIKE_JRE_JVMDLL;
  }

  for (i = pathlen - 1; i && isspace (jvmloc[i]); i--) {}
  pathlen = i + 1;
  jvmloc[pathlen] = 0;

  return jvmloc;
}


void CRoxen::SetEnvFromIni()
{
  char *inifile;
  char inifile1[2048];
  char inifile2[2048];
  char envNames[2048];
  char envValue[2048];
  int len,i;
  char *p;
  
  GetCurrentDirectory(sizeof(inifile1), inifile1);
  strcat(inifile1, "/../local/environment.ini");
  GetCurrentDirectory(sizeof(inifile2), inifile2);
  strcat(inifile2, "/../local/environment2.ini");

  inifile = inifile1;

  for(i = 0 ; i < 2; i++) {
    len = GetPrivateProfileString("Environment", NULL, "", envNames, sizeof(envNames), inifile);
    if (len > 2 && len < sizeof(envNames))
      {
	p = envNames;
	while (*p)
	  {
	    len = GetPrivateProfileString("Environment", p, "", envValue, sizeof(envValue), inifile);
	    if (len > 2 && len < sizeof(envValue))
	      {
		if (_Module.GetCmdLine().GetVerbose() > 1)
		  printf("setting %s=%s\n", p, envValue);
		
		SetEnvironmentVariable(p, envValue);
	      }
	    while(*p++);
	  }
      }
    inifile = inifile2;
  }

}


int stracat(char *out, char **arr)
{
  char *p = out;
  int i = 0;
  while (arr[i] != NULL)
  {
    if (strchr(arr[i], ' ') == NULL)
    {
      p += sprintf(p, " %s", arr[i]);
    }
    else
    {
      p += sprintf(p, " \"%s\"", arr[i]);
    }
    i++;
  }

  return p-out; 
}


BOOL CRoxen::CreatePikeCmd(char *cmd, std::string pikeloc, CCmdLine &cmdline, char *key)
{
  char *p = cmd;

  // insert debugger name
  if (cmdline.IsMsdev())
    p += sprintf(p, "msdev ");

  // Copy path to pike
  if (pikeloc[0] == '"')
  {
    strcpy(p, pikeloc.c_str());
    p += pikeloc.length();
  }
  else
    p += sprintf(p, "\"%s\"", pikeloc.c_str());

  // Insert pike defines
  p += stracat(p, cmdline.GetPikeDefines().GetList());

  // Insert pike args
  p += stracat(p, cmdline.GetPikeArgs().GetList());

  // Insert (roxen) program name and stopfile
  p += sprintf(p, " ntroxenloader.pike +../logs/%hs.run", key);

  // Insert silent flag if required (must be first argument after +/../xxxxx.run)
/*
  if (_Module.m_bService || (cmdline.GetVerbose() == 0 && !cmdline.IsPassHelp()))
    p += sprintf(p, " -silent");
*/

  // Insert roxen args
  p += stracat(p, cmdline.GetRoxenArgs().GetList());

  return TRUE;
}


std::string CRoxen::RotateLogs(std::string logdir)
{
  char buf[40];
  CreateDirectory(logdir.c_str(), NULL);
  std::string debugFile = logdir + "\\default.";
  DeleteFile((debugFile + itoa(10, buf, 10) ).c_str());
  for (int i=9; i>0; i--)
  {
    MoveFile((debugFile + itoa(i, buf, 10)).c_str(), (debugFile + itoa(i+1, buf, 10)).c_str());
  }
  return debugFile + itoa(1, buf, 10);
}


int CRoxen::Start(int first_time)
{
  STARTUPINFO info;
  PROCESS_INFORMATION proc;
  TCHAR cmd[4000];
  CCmdLine & cmdline = _Module.GetCmdLine();
  void *env=NULL;
  int i;
  int ret;
  
  //pike loc
  std::string pikeloc = FindPike(TRUE);

  // Insert the pike location in the environment
  if (!SetEnvironmentVariable (TEXT("PIKE"), pikeloc.c_str())) {
    ErrorMsg (1, TEXT("Could not set the PIKE environment variable"));
    return FALSE;
  }

  if (first_time) {
    TCHAR *oldpath = _tgetenv (TEXT("CLASSPATH"));
    TCHAR *newpath = 0;
    TCHAR *tofree = 0;
    WIN32_FIND_DATA dir;
    HANDLE d;
    if(oldpath) {
      tofree = newpath = (TCHAR *)malloc (14*sizeof (TCHAR) + _tcslen (oldpath) * sizeof (TCHAR));
      _stprintf (newpath, TEXT("java/classes;%s"), oldpath);
    } else
      newpath = TEXT("java/classes");
    oldpath = newpath;
    if((d = FindFirstFile(TEXT("java/classes/*.jar"), &dir)) != INVALID_HANDLE_VALUE) {
      do {
        newpath = (TCHAR *)malloc (_tcslen (dir.cFileName) * sizeof(TCHAR) + 15*sizeof (TCHAR) +
          _tcslen (oldpath) * sizeof (TCHAR));
        _stprintf (newpath, TEXT("java/classes/%s;%s"), dir.cFileName, oldpath);
        if(tofree)
          free(tofree);
        oldpath = tofree = newpath;
      } while(FindNextFile(d, &dir));
      FindClose(d);
    }
    if (!SetEnvironmentVariable (TEXT("CLASSPATH"), newpath)) {
      ErrorMsg (1, TEXT("Could not set the CLASSPATH environment variable"));
      if (tofree) free (tofree);
      return FALSE;
    }
    if (tofree) free (tofree);

    // Find the jvm.dll to use
    std::string jvmloc = FindJvm();
    if(jvmloc.length() > 0 &&
        (d = FindFirstFile(jvmloc.c_str(), &dir)) != INVALID_HANDLE_VALUE) {
      FindClose(d);
      if (!SetEnvironmentVariable (TEXT("PIKE_JRE_JVMDLL"), jvmloc.c_str() )) {
        ErrorMsg (1, TEXT("Could not set the PIKE_JRE_JVMDLL environment variable"));
        return FALSE;
      }
    }
    else
      SetEnvironmentVariable(TEXT("PIKE_JRE_JVMDLL"), NULL);

    SetEnvFromIni();
  }
  
  // seed the random number generator
  srand( (unsigned)time( NULL ) );

  for(i = 0; i < sizeof (key) - 1; i++)
    key[i]=65+32+((unsigned char)rand())%24;
  key[sizeof (key) - 1] = 0;
  

  // Create the pike command line
  CreatePikeCmd(cmd, pikeloc, cmdline, key);

  if (cmdline.GetVerbose() > 1)
    ErrorMsg(0, TEXT("Executing '%s'"), cmd);

  TCHAR cwd[_MAX_PATH];
  cwd[0] = 0;
  _tgetcwd (cwd, _MAX_PATH);
  
  GetStartupInfo(&info);
  /*   info.wShowWindow=SW_HIDE; */
  info.dwFlags|=STARTF_USESHOWWINDOW;
  info.dwFlags|=STARTF_USESTDHANDLES;
  info.hStdInput=GetStdHandle(STD_INPUT_HANDLE);
  info.hStdOutput=GetStdHandle(STD_OUTPUT_HANDLE);
  info.hStdError=GetStdHandle(STD_ERROR_HANDLE);
  SetHandleInformation(info.hStdInput, HANDLE_FLAG_INHERIT, 0);
  SetHandleInformation(info.hStdOutput, HANDLE_FLAG_INHERIT, 0);
  SetHandleInformation(info.hStdError, HANDLE_FLAG_INHERIT, 0);

  SECURITY_ATTRIBUTES sa;
  sa.nLength = sizeof(SECURITY_ATTRIBUTES);
  sa.bInheritHandle = TRUE;
  sa.lpSecurityDescriptor = NULL;

  HANDLE hFile = INVALID_HANDLE_VALUE;
  HANDLE hFile2 = INVALID_HANDLE_VALUE;
  HANDLE hFile3 = INVALID_HANDLE_VALUE;
  if (_Module.m_bService || (cmdline.GetVerbose() == 0 && !cmdline.IsPassHelp()))
  {
    CreateDirectory(cmdline.GetLogDir().c_str(), NULL);
    std::string newLogFile = RotateLogs(cmdline.GetLogDir() + "\\debug");
    hFile = CreateFile(newLogFile.c_str(),
      GENERIC_WRITE,          // desired access
      FILE_SHARE_READ,        // share mode
      &sa,                    // security
      OPEN_ALWAYS,            // creation disposition
      FILE_ATTRIBUTE_NORMAL,  // flags and attributes
      NULL);                  // template file
    if (hFile != INVALID_HANDLE_VALUE)
    {
      SetFilePointer(
        hFile,    // handle to file
        0,        // bytes to move pointer
        NULL,     // bytes to move pointer
        FILE_END  // starting point
        );
      info.hStdOutput = hFile;
      if (!DuplicateHandle(GetCurrentProcess(),hFile,
                           GetCurrentProcess(),
                           &hFile3, // Address of new handle.
                           0,TRUE, // Make it inheritable.
                           DUPLICATE_SAME_ACCESS))
           ErrorMsg(1, "DuplicateHandle");
      info.hStdError = hFile3;
    }
    hFile2 = CreateFile("NUL:",
      GENERIC_READ|GENERIC_WRITE,   // desired access
      FILE_SHARE_READ,              // share mode
      &sa,                          // security
      OPEN_ALWAYS,                  // creation disposition
      FILE_ATTRIBUTE_NORMAL,        // flags and attributes
      NULL);                        // template file
    if (hFile2 != INVALID_HANDLE_VALUE)
    {
      info.hStdInput = hFile2;
    }
  }
  
  if (hProcess != 0)
    CloseHandle(hProcess);
  hProcess = 0;
  SetHandleInformation(info.hStdInput, HANDLE_FLAG_INHERIT, HANDLE_FLAG_INHERIT);
  SetHandleInformation(info.hStdOutput, HANDLE_FLAG_INHERIT, HANDLE_FLAG_INHERIT);
  SetHandleInformation(info.hStdError, HANDLE_FLAG_INHERIT, HANDLE_FLAG_INHERIT);
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
  if(!ret)
  {
    ErrorMsg (1, TEXT("Error starting the main Roxen process"));
    CloseHandle(hFile);
    return FALSE;
  }
  
  CloseHandle(hFile);
  CloseHandle(hFile2);
  CloseHandle(hFile3);
  CloseHandle(proc.hThread);
  hProcess=proc.hProcess;
  return TRUE;
}

int CRoxen::Stop(BOOL write_stop_file)
{
  if (write_stop_file) {
    FILE *f;
    char tmp[8192];
    TCHAR cwd[_MAX_PATH];
    cwd[0] = 0;
    _tgetcwd (cwd, _MAX_PATH);

    _snprintf (tmp, sizeof (tmp), "..\\logs\\%s.run", key);
    if (!(f=fopen(tmp,"wb"))) {
      ErrorMsg (1, TEXT("Roxen will not get the stop signal - "
			 "failed to open stop file %s\\..\\logs\\%hs.run"), cwd, key);
      return FALSE;
    }
    fprintf(f,"This is a Roxen stop file generated by the Roxen service.\n"
	    "It is safe to remove.\n");
    fclose(f);
  }

  return TRUE;
}

BOOL CRoxen::RunPike(const char *cmdline, BOOL wait /*=TRUE*/)
{
  char cmd[4000];
  char *p = cmd;
  int ret;

  std::string pikeloc = FindPike(TRUE);

  // Copy path to pike
  if (pikeloc[0] == '"')
  {
    strcpy(p, pikeloc.c_str());
    p += pikeloc.length();
  }
  else
    p += sprintf(p, "\"%s\"", pikeloc.c_str());

  // Add on the pike command line
  p += sprintf(p, " %s", cmdline);


  ////////////
  // Run pike
  TCHAR cwd[_MAX_PATH];
  cwd[0] = 0;
  _tgetcwd (cwd, _MAX_PATH);
  
  STARTUPINFO info;
  PROCESS_INFORMATION proc;
  GetStartupInfo(&info);
  /*   info.wShowWindow=SW_HIDE; */
  info.dwFlags|=STARTF_USESHOWWINDOW;
  ret=CreateProcess(NULL,
    cmd,
    NULL,  /* process security attribute */
    NULL,  /* thread security attribute */
    1,     /* inherithandles */
    0,     /* create flags */
    NULL,   /* environment */
    cwd,   /* current dir */
    &info,
    &proc);
  if(!ret)
  {
    ErrorMsg (1, TEXT("Error running the command '%s'"), cmd);
    return FALSE;
  }

  if (wait)
    WaitForSingleObject(proc.hProcess, INFINITE);

  CloseHandle(proc.hThread);
  CloseHandle(proc.hProcess);
  
  return TRUE;
}

std::string ListFiles(std::string dir, std::string wildcard = "")
{
  std::string ret;
  HANDLE hFind;
  WIN32_FIND_DATA ffd;
  char buf[2048];

  if (wildcard.length() > 0)
    hFind = FindFirstFile((dir + "\\" + wildcard).c_str(), &ffd);
  else
    hFind = FindFirstFile(dir.c_str(), &ffd);

  if (hFind != INVALID_HANDLE_VALUE)
  {
    do
    {
      if (strcmp(ffd.cFileName, ".") == 0 || strcmp(ffd.cFileName, "..") == 0)
        continue;
      
      if (ffd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY)
      {
        if (wildcard.length() > 0)
          ret += ListFiles(dir + "\\" + ffd.cFileName, "*");
        else
          ret += ListFiles(dir, "*");
      }
      else
      {
        // attrib size last-write-time filename
        sprintf(buf, "%08x %08x%08x %08x%08x %s\\%s\n",
          ffd.dwFileAttributes,
          ffd.nFileSizeHigh, ffd.nFileSizeLow,
          ffd.ftLastWriteTime.dwHighDateTime, ffd.ftLastWriteTime.dwLowDateTime, 
          dir.c_str(), ffd.cFileName);

        ret += buf;
        
      }
      
    } while (FindNextFile(hFind, &ffd));
    
    FindClose(hFind);
  }

  return ret;
}


BOOL CRoxen::CheckVersionChange()
{
  std::string ls;
  std::ifstream is;
  std::string old_ls;
  char buf[4096];
  int count;

  // Insert pike defines
  CCmdLine & cmdline = _Module.GetCmdLine();
  stracat(buf, cmdline.GetPikeDefines().GetList());
  ls += buf;
  ls += "\n\n";

  // Insert file listings
  ls += ListFiles(FindPike());
  ls += ListFiles("etc\\modules");
  ls += ListFiles("base_server");

  is.open("..\\var\\old_roxen_defines");
  while (is.good())
  {
    is.read(buf, sizeof(buf));
    count = is.gcount();
    old_ls.append(buf, count);
  }

  is.close();

  if (old_ls == ls)
    return FALSE;

  CreateDirectory("..\\var", NULL);
  std::ofstream os;
  os.open("..\\var\\old_roxen_defines");
  os.write(ls.c_str(), ls.length());
  os.close();

  return TRUE;
}
