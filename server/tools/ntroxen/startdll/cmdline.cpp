// cmdline.cpp: implementation of the CCmdLine class.
//
// $Id$
//
//////////////////////////////////////////////////////////////////////

#include "stdafx.h"
#include "startdll.h"
#include "cmdline.h"
#include "roxen.h"
#include "enumproc.h"

#ifdef _DEBUG
#undef THIS_FILE
static char THIS_FILE[]=__FILE__;
//#define new DEBUG_NEW
#endif

static char *defPikeArgs[] = {

  // List terminator
  NULL
};

static char *defPikeDefines[] = {
  "-DRAM_CACHE",
  "-DENABLE_THREADS",
  "-DHTTP_COMPRESSION",

  // List terminator
  NULL
};

static char *defRoxenArgs[] = {

  // List terminator
  NULL
};


////////////////////////
//
// CArgList class
//
#define ARG_ALLOC 1
#define ARG_THRESH 1

//////////////////////////////////////////////////////////////////////
// Construction/Destruction
//////////////////////////////////////////////////////////////////////

CArgList::CArgList()
{
  m_Count = 0;
  m_Size = 0;
  m_pData = NULL;

  // Allocate an empty array
  ReSize(1);
}

CArgList::~CArgList()
{
  if (m_pData == NULL)
    return;

  for (int i=0; i<m_Count; i++)
  {
    delete (m_pData)[i];
  }

  delete [] m_pData;
}

BOOL CArgList::CopyData(tData *p, int size)
{
  int i;
  int copySize = min(m_Size, size);

  // copy
  for (i=0; i<copySize; i++)
    p[i] = m_pData[i];

  // clear
  if (copySize < size)
    for (i=copySize; i<size; i++)
      p[i] = 0;

  return TRUE;
}

BOOL CArgList::ReSize(int diff)
{
  if (diff > 0)
  {
    int need = m_Count + diff;
    // Grow the data array if necessary
    if (need > m_Size)
    {
      // Allocate new array and make sure that an extra NULL entry always exists
      tData *p = new tData[need + ARG_ALLOC + 1];
      CopyData(p, need+ARG_ALLOC+1);
      if (m_pData)
        delete m_pData;
      m_pData = p;
      m_Size = need + ARG_ALLOC;
    }
  }
  else
  {
    // Trim the size of the data array
    // if diff is 0 shrink the array if there is more than
    // ARG_THRESH entries free
    // if diff is negative use the absolute value as the thresh hold value
    int thresh = ARG_THRESH;
    if (diff < 0)
      thresh = -diff;
    if (m_Count + thresh < m_Size)
    {
      // Allocate new array and make sure that an extra NULL entry always exists
      tData *p = new tData[m_Count + thresh + 1];
      CopyData(p, m_Count + thresh + 1);
      if (m_pData)
        delete m_pData;
      m_pData = p;
      m_Size = m_Count + thresh;
    }
  }

  return TRUE;
}


BOOL CArgList::Exists(const char *item)
{
  int ret = FALSE;
  int i;

  for (i=0; i<m_Count; i++)
  {
    if (strcmp(m_pData[i], item) == 0)
    {
      ret = TRUE;
      break;
    }
  }

  return ret;
}


BOOL CArgList::Add(const char *item)
{
  ReSize(1);

  int len = strlen(item);
  char *p = new char[len+1];

  strcpy(p, item);
  m_pData[m_Count++] = p;

  return TRUE;
}


BOOL CArgList::AddIfNew(const char *item)
{
  if (Exists(item))
    return TRUE;

  return Add(item);
}


BOOL CArgList::Remove(const char *item)
{
  int ret = FALSE;
  int i;

  for (i=0; i<m_Count; i++)
  {
    if (strcmp(m_pData[i], item) == 0)
    {
      delete m_pData[i];

      // Move the extra NULL entry also
      for (int j=i+1; j<=m_Count; j++)
        m_pData[j-1] = m_pData[j];

      m_Count--;
      
      ret = TRUE;
      break;
    }
  }

  ReSize(0);

  return ret;
}


////////////////////////
//
// CCmdLine class
//

//////////////////////////////////////////////////////////////////////
// Construction/Destruction
//////////////////////////////////////////////////////////////////////

CCmdLine::CCmdLine()
: m_SelfTestDir("etc\\test"), m_LogDir("..\\logs"),
  m_ConfigDir("..\\configurations")
{
  m_bPreloaded      = FALSE;
  m_bParseFinished  = FALSE;

  m_bInstall    = FALSE;
  m_bRemove     = FALSE;
  m_bOnce       = FALSE;
  m_bHelp       = FALSE;
  m_bVersion    = FALSE;
  m_bPassHelp   = FALSE;
  m_bKeepMysql  = FALSE;
  m_bMsdev      = FALSE;
  m_bCheckVersion = TRUE;

  m_iVerbose    = 1;

  m_iDebug      = -1;

}

CCmdLine::~CCmdLine()
{
}


/* Check if the string s[0..len[ matches the glob m[0..mlen[ */
static BOOL does_match(char *s, char *p)
{
  for (; *p; p++)
  {
    switch (*p)
    {
    case '?':
      if(!*s++) return 0;
      break;
      
    case '*': 
      p++;
      if (!*p) return 1;	//* slut /
      
      for (; *s; s++)
        if (does_match(s, p))
          return 1;
        
        return 0;
        
    default: 
      if(!*s ||
        *p != *s) return 0;
      s++;
    }
  }

  return *s==0;
}

////////////////////////
//
// Match the first string against the pattern in the second
// and optionally splitting the string on a character and
// returning a pointer to the character after the first delim.
//
// The only wildcard character supported in the second string
// is a trailing * which means match all characters to the end
// of the string.
//
BOOL CCmdLine::Match(char *s, char *pattern, char *delim, char **value)
{
  BOOL ret = FALSE;
  if (does_match(s, pattern))
  {
    if (delim && value)
    {
      *value = strpbrk(s, delim);
      if (*value != NULL)
      {
        (*value)++;
        ret = TRUE;
      }
    }
    else
      ret = TRUE;
  }

  return ret;
}


void CCmdLine::OutputLineFmt(HANDLE out, char *pFormat, ...)
{
  TCHAR    chMsg[1024];
  va_list pArg;
  
  va_start(pArg, pFormat);
  _vstprintf(chMsg, pFormat, pArg);
  va_end(pArg);
  
  OutputLine(out, chMsg);
}


void CCmdLine::OutputLine(HANDLE out, char *line)
{
  CONSOLE_SCREEN_BUFFER_INFO csbiInfo; 
  WORD wOldColorAttrs; 
  DWORD cWritten;
  
  if (GetConsoleScreenBufferInfo(out, &csbiInfo)) 
    wOldColorAttrs = csbiInfo.wAttributes; 
  else
    wOldColorAttrs = 0; 
  
  while (line && *line)
  {
    if (*line == '.' && line[1] && line[1] == 'B')
    {
      SetConsoleTextAttribute(out, wOldColorAttrs | FOREGROUND_INTENSITY);
//      SetConsoleTextAttribute(out, FOREGROUND_RED);
      line += 2;
      continue;
    }
    if (*line == 'B' && line[1] && line[1] == '.')
    {
      SetConsoleTextAttribute(out, wOldColorAttrs);
      line += 2;
      continue;
    }

    WriteFile(out, line, 1, &cWritten, NULL);
    line++;
  }

  SetConsoleTextAttribute(out, wOldColorAttrs);
  WriteFile(out, "\r\n", 2, &cWritten, NULL);
}


void CCmdLine::PrintHelp()
{
  char * helptext[] =
  {
    "",
    "",
    ".BThis command will start Roxen CMSB..",
    "",
    "The environment variable .BROXEN_ARGSB. can be used to specify",
    "the default arguments.",
    "",
    "   .BArguments:B.",
    "",
    "      .B--versionB.:                  Output version information.",
    "",
    "      .B--help -?B.:                  This information.",
    "",
    "      .B--installB.:                  Register application and install as",
    "                                  an NT service.",
    "",
    "      .B--registerB.:                 Register application.",
    "",
    "      .B--removeB.:                   Remove all registry setting and uninstall",
    "                                  the NT service.",
    "",
    "      .B--offlineB.:                  Indicate that there is no network",
    "                                  connection available. Disables DNS and some",
    "                                  other similar things.",
    "",
    "      .B--remove-dumpedB.:            Remove all dumped code, thus forcing",
    "                                  a recompile.",
    "",
    "      .B--verbose -vB.:               Enable more verbose messages.",
    "",
    "      .B--quiet -qB.:                 Disable most of the messages.",
    "",
/*
    "      .B--log-dir=DIRB.:              Set the log directory. Defaults to .B../logsB..",
    "",
    "      .B--config-dir=DIRB.:           Use an alternate configuration directory.",
    "                                  Defaults to .B../configurationsB..",
    "",
    "      .B--debug-log=FILEB.:           Use an alternate debuglog file.",
    "                                  Defaults to .B../logs/debug/B.configdirname.B.1B..",
    "",
    "      .B--pid-file=FILEB.:            Store the roxen and startscript pids in this",
    "                                  file. Defaults to .B../configurations/_roxen_pidB..",
    "",
    "      .B--silent-startB.:             Inhibits output to stdout. If used,",
    "                                  this argument must be the first one.",
*/
    "",
    "      .B--without-ram-cacheB.:        Do not use an in-RAM cache to speed",
    "                                  things up. Saves RAM at the cost of speed.",
    "",
    "      .B--without-new-ram-cacheB.:    Do not use a the new RAM cache",
    "				  introduced in Roxen 5.0-release4.",
    "",
    "      .B--without-ram-cache-statB.:   Disable the stat that is usually done",
    "                                  for files in the ram cache to ensure that",
    "                                  they are not changed before they are sent.",
    "                                  Improves performance at the cost of constant",
    "                                  aggravation if the site is edited. Useful for",
    "                                  truly static sites.",
    "",
    "      .B--without-http-compressionB.: Disable gzip compression for HTTP requests.",
    "",
    "      .B--with-threadsB.:             If threads are available, use them.",
    "",
    "      .B--without-threadsB.:          Even if threads are enabled by default,",
    "                                  disable them.",
    "",
    "      .B--with-profileB.:             Store runtime profiling information on",
    "                                  a directory basis. This information is",
    "                                  not saved on permanent storage, it is only",
    "                                  available until the next server restart",
    "                                  This will enable a new 'action' in the",
    "                                  administration interface",
    "",
    "      .B--with-file-profileB.:        Like .B--with-profileB., but save information",
    "                                  for each and every file.",
    "",
    "      .B--self-testB.:                Runs a testsuite.",
    "      .B--self-test-verboseB.:        Runs a testsuite, report all tests.",
//    "      .B--self-test-quietB.:          Runs a testsuite, only report errors.",
    "      .B--self-test-dir=DIRB.:        Use this self test directory instead of",
    "                                  the default .Betc/testB. directory.",
    "",
    "      .B--onceB.:                     Run the server only once, in the foreground.",
    "                                  This is very useful when debugging.",
    "                                  Implies --module-debug.",
    "",
    "      .B--keep-mysqlB.:               Don't shut down MySQL process when exiting",
    "                                  the start script. Useful during development",
    "                                  or any other scenario where the start script",
    "                                  is frequently terminated.",
    "",
/*
    "      .B--gdbB.:                      Run the server in gdb. Implies .B--onceB..",
    "",
*/
/*
    "      .B--msdevB.:                    Run the server in Microsoft Developer Studio.",
    "                                  Implies .B--onceB..",
*/
    "",
    "      .B--programB.:                  Start a different program with the roxen",
    "                                  Pike.",
    "",
    "      .B--with-debugB.:               Enable debug",
    "",
    "      .B--without-debugB.:            Disable all debug. This is the default.",
    "",
    "      .B--module-debugB.:             Enable more internal debug checks to",
    "                                  simplify debugging of Roxen modules.",
    "",
    "      .B--fd-debugB.:                 Enable FD debug.",
    "",
    "      .B--dump-debugB.:               Enable dump debug.",
    "",
/*
    "      .B--trussB.:                    (Solaris only). Run the server under",
    "                                  truss, shows .BallB. system calls. This is",
    "                                  extremely noisy, and is not intented for",
    "                                  anything but debug.",
    "",
    "      .B--truss-cB.:                  (Solaris only). Run the server under",
    "                                  truss -c, shows times for all system calls",
    "                                  on exit. This is not intented for anything",
    "                                  but debug. Slows the server down.",
    "",
*/
    "      .B--with-snmp-agentB.:          Enable internal SNMP agent code.",
    "",
    "  .BArguments passed to pike:B.",
    "",
    "       .B-DDEFINEB.:                  Define the symbol .BDEFINEB..",
    "",
    "       .B-d<level>B.:                 Set the runtime Pike debug to level.",
    "                                  This only works if Pike is compiled",
    "                                  with debug (i.e. with --rtl-debug to",
    "                                  configure).",
    "",
    "       .B-rtB.:                       Enable runtime typechecking.",
    "                                  Things will run more slowly, but it is very",
    "                                  useful while developing code.",
    "",
    "                                  Enabled when starting roxen with --debug",
    "",
    "       .B-rTB.:                       Enable strict types.",
    "                                  Same as adding #pragma strict-types",
    "                                  to all files.",
    "",
    "                                  This enables more strict",
    "                                  type-checking, things that are",
    "                                  normally permitted (such as calling",
    "                                  a mixed value, or assigning a typed",
    "                                  object variable with an untyped",
    "                                  object) will generate warnings.",
    "",
    "                                  Useful for module and roxen core",
    "                                  developers, but not so useful for",
    "                                  the occasional pike-script-writer.",
    "",
    "                                  Enabled when starting roxen with --debug",
    "",
    "       .B-s<size>B.:                  Set the stack size.",
    "",
    "       .B-M<path>B.:                  Add the path to the Pike module path.",
    "",
    "       .B-I<path>B.:                  Add the path to the Pike include path.",
    "",
    "       .B-P<path>B.:                  Add the path to the Pike program path.",
    "",
    "       .B-dtB.:                       Turn off tail recursion optimization.",
    "",
    "       .B-tB.:                        Turn on Pike level tracing.",
    "",
    "       .B-t<level>B.:                 Turn on more Pike tracing. This only",
    "                                  works if Pike is compiled with debug",
    "                                  (i.e. with --rtl-debug to configure).",
    "",
    "       .B-a<level>B.:                 Turn on Pike assembler debug. This only",
    "                                  works if Pike is compiled with debug",
    "                                  (i.e. with --rtl-debug to configure).",
    "",
    "       .B-wB.:                        Turn on Pike warnings.",
    "",
    "  .BEnvironment variables:B.",
    "",
    "     .BLANGB.:                        Used to determine the default locale",
    "                                  in the administration interface and logs.",
/*
    "     .BROXEN_CONFIGDIRB.:             Same as .B--config-dir=... B.",
    "     .BROXEN_PID_FILEB.:              Same as .B--pid-file=... B.",
*/
    "     .BROXEN_LANGB.:                  The default language for all language",
    "                                  related tags. Defaults to 'en' for english.",

    // Must be last entry
    NULL
  };

  HANDLE hOut = GetStdHandle(STD_OUTPUT_HANDLE);
  int i = 0;
  while (helptext[i] != NULL)
  {
    OutputLine(hOut, helptext[i]);
    i++;
  }

}



/***
*static void parse_cmdline(cmdstart, argv, args, numargs, numchars)
*
*Purpose:
*       Parses the command line and sets up the argv[] array.
*       On entry, cmdstart should point to the command line,
*       argv should point to memory for the argv array, args
*       points to memory to place the text of the arguments.
*       If these are NULL, then no storing (only coujting)
*       is done.  On exit, *numargs has the number of
*       arguments (plus one for a final NULL argument),
*       and *numchars has the number of bytes used in the buffer
*       pointed to by args.
*
*Entry:
*       _TSCHAR *cmdstart - pointer to command line of the form
*           <progname><nul><args><nul>
*       _TSCHAR **argv - where to build argv array; NULL means don't
*                       build array
*       _TSCHAR *args - where to place argument text; NULL means don't
*                       store text
*
*Exit:
*       no return value
*       int *numargs - returns number of argv entries created
*       int *numchars - number of characters used in args buffer
*
*Exceptions:
*
*******************************************************************************/

#define NULCHAR    _T('\0')
#define SPACECHAR  _T(' ')
#define TABCHAR    _T('\t')
#define DQUOTECHAR _T('\"')
#define SLASHCHAR  _T('\\')

void CCmdLine::SplitCmdline(
  _TSCHAR *cmdstart,
  _TSCHAR **argv,
  _TSCHAR *args,
  int *numargs,
  int *numchars
  )
{
  _TSCHAR *p;
  _TUCHAR c;
  int inquote;                    /* 1 = inside quotes */
  int copychar;                   /* 1 = copy char to *args */
  unsigned numslash;              /* num of backslashes seen */
  
  *numchars = 0;
  *numargs = 1;                   /* the program name at least */
  
  /* first scan the program name, copy it, and count the bytes */
  p = cmdstart;
  if (argv)
    *argv++ = args;
  
#ifdef WILDCARD
    /* To handle later wild card expansion, we prefix each entry by
    it's first character before quote handling.  This is done
  so _[w]cwild() knows whether to expand an entry or not. */
  if (args)
    *args++ = *p;
  ++*numchars;
  
#endif  /* WILDCARD */
  
  /* A quoted program name is handled here. The handling is much
  simpler than for other arguments. Basically, whatever lies
  between the leading double-quote and next one, or a terminal null
  character is simply accepted. Fancier handling is not required
  because the program name must be a legal NTFS/HPFS file name.
  Note that the double-quote characters are not copied, nor do they
  contribute to numchars. */
  if ( *p == DQUOTECHAR ) {
  /* scan from just past the first double-quote through the next
    double-quote, or up to a null, whichever comes first */
    while ( (*(++p) != DQUOTECHAR) && (*p != NULCHAR) ) {
      
#ifdef _MBCS
      if (_ismbblead(*p)) {
        ++*numchars;
        if ( args )
          *args++ = *p++;
      }
#endif  /* _MBCS */
      ++*numchars;
      if ( args )
        *args++ = *p;
    }
    /* append the terminating null */
    ++*numchars;
    if ( args )
      *args++ = NULCHAR;
    
    /* if we stopped on a double-quote (usual case), skip over it */
    if ( *p == DQUOTECHAR )
      p++;
  }
  else {
    /* Not a quoted program name */
    do {
      ++*numchars;
      if (args)
        *args++ = *p;
      
      c = (_TUCHAR) *p++;
#ifdef _MBCS
      if (_ismbblead(c)) {
        ++*numchars;
        if (args)
          *args++ = *p;   /* copy 2nd byte too */
        p++;  /* skip over trail byte */
      }
#endif  /* _MBCS */
      
    } while ( c != SPACECHAR && c != NULCHAR && c != TABCHAR );
    
    if ( c == NULCHAR ) {
      p--;
    } else {
      if (args)
        *(args-1) = NULCHAR;
    }
  }
  
  inquote = 0;
  
  /* loop on each argument */
  for(;;) {
    
    if ( *p ) {
      while (*p == SPACECHAR || *p == TABCHAR)
        ++p;
    }
    
    if (*p == NULCHAR)
      break;              /* end of args */
    
    /* scan an argument */
    if (argv)
      *argv++ = args;     /* store ptr to arg */
    ++*numargs;
    
#ifdef WILDCARD
    /* To handle later wild card expansion, we prefix each entry by
    it's first character before quote handling.  This is done
    so _[w]cwild() knows whether to expand an entry or not. */
    if (args)
      *args++ = *p;
    ++*numchars;
    
#endif  /* WILDCARD */
    
    /* loop through scanning one argument */
    for (;;) {
      copychar = 1;
      /* Rules: 2N backslashes + " ==> N backslashes and begin/end quote
      2N+1 backslashes + " ==> N backslashes + literal "
      N backslashes ==> N backslashes */
      numslash = 0;
      while (*p == SLASHCHAR) {
        /* count number of backslashes for use below */
        ++p;
        ++numslash;
      }
      if (*p == DQUOTECHAR) {
      /* if 2N backslashes before, start/end quote, otherwise
        copy literally */
        if (numslash % 2 == 0) {
          if (inquote) {
            if (p[1] == DQUOTECHAR)
              p++;    /* Double quote inside quoted string */
            else        /* skip first quote char and copy second */
              copychar = 0;
          } else
            copychar = 0;       /* don't copy quote */
          
          inquote = !inquote;
        }
        numslash /= 2;          /* divide numslash by two */
      }
      
      /* copy slashes */
      while (numslash--) {
        if (args)
          *args++ = SLASHCHAR;
        ++*numchars;
      }
      
      /* if at end of arg, break loop */
      if (*p == NULCHAR || (!inquote && (*p == SPACECHAR || *p == TABCHAR)))
        break;
      
      /* copy character into argument */
#ifdef _MBCS
      if (copychar) {
        if (args) {
          if (_ismbblead(*p)) {
            *args++ = *p++;
            ++*numchars;
          }
          *args++ = *p;
        } else {
          if (_ismbblead(*p)) {
            ++p;
            ++*numchars;
          }
        }
        ++*numchars;
      }
      ++p;
#else  /* _MBCS */
      if (copychar) {
        if (args)
          *args++ = *p;
        ++*numchars;
      }
      ++p;
#endif  /* _MBCS */
    }
    
    /* null-terminate the argument */
    
    if (args)
      *args++ = NULCHAR;          /* terminate string */
    ++*numchars;
  }
  
  /* We put one last argument in -- a null ptr */
  if (argv)
    *argv++ = NULL;
  ++*numargs;
}


////////////////////////
//
// Parse current argument (always argv[0]) and
// return the number of parameters used
//
int CCmdLine::ParseArg(int argc, char *argv[], CCmdLine::tArgType & type)
{
  char *value;
  

  /*
  -DRAM_CACHE
  -DENABLE_THREADS
  
  -DRUN_SELF_TEST
  ##
  --remove-dumped
  ##
  */


  //'-install'|'--install')
  //
  if (Match(*argv, "-install", NULL, NULL) ||
      Match(*argv, "--install", NULL, NULL) )
  {
    m_bInstall = TRUE;
    m_bCheckVersion = FALSE;
    type = eArgStart;
    return 1;
  }

  //'-register'|'--register')
  //
  if (Match(*argv, "-register", NULL, NULL) ||
      Match(*argv, "--register", NULL, NULL) )
  {
    m_bRegister = TRUE;
    m_bCheckVersion = FALSE;
    type = eArgStart;
    return 1;
  }

  //'-remove'|'--remove')
  //
  if (Match(*argv, "-remove", NULL, NULL) ||
      Match(*argv, "--remove", NULL, NULL) )
  {
    m_bRemove = TRUE;
    m_bCheckVersion = FALSE;
    type = eArgStart;
    return 1;
  }

  //-D*)
  //DEFINES="$DEFINES $1"
  if (Match(*argv, "-D*", NULL, NULL))
  {
    m_saPikeDefines.Add(*argv);
    type = eArgPike;
    return 1;
  }

  //-l*)
  // ARGS="$ARGS $1"
  if (Match(*argv, "-l*", NULL, NULL))
  {
    m_saPikeArgs.Add(*argv);
    type = eArgPike;
    return 1;
  }

  //--log-dir=*)
  // LOGDIR=`echo $1 | sed -e 's/--log-dir=//'`
  if (Match(*argv, "--log-dir=*", "=", &value))
  {
    //strcpy(logdir, value);
    type = eArgUnsupported;
    return 1;
  }

  //--debug-log=*)
  // DEBUGLOG=`echo $1 | sed -e's/--debug-log=//'`
  if (Match(*argv, "--debug-log=*", "=", &value))
  {
    //strcpy(debuglog, value);
    type = eArgUnsupported;
    return 1;
  }

  //--config-dir=*)
  // DIR=`echo $1 | sed -e 's/--config-dir=//'`
  // FILES=`echo $1 | sed -e's/--config-dir=//' -e's/\.//g' -e's./..g' -e 's.-..g'`
  if (Match(*argv, "--config-dir=*", "=", &value))
  {
    //strcpy(configdir, value);
    type = eArgUnsupported;
    return 1;
  }

  //--pid-file=*)
  // pidfile=`echo $1 | sed -e 's/--pid-file=//'`

  
  //'--with-security'|'--enable-security')
  //  DEFINES="$DEFINES -DSECURITY"
  if (Match(*argv, "--with-security", NULL, NULL) ||
      Match(*argv, "--enable-security", NULL, NULL) )
  {
    m_saPikeDefines.Add("-DSECURITY");
    type = eArgPike;
    return 1;
  }

  //'--with-snmp-agent'|'--enable-snmp-agent')
  //  DEFINES="$DEFINES -DSNMP_AGENT"
  if (Match(*argv, "--with-snmp-agent", NULL, NULL) ||
      Match(*argv, "--enable-snmp-agent", NULL, NULL) )
  {
    m_saPikeDefines.Add("-DSNMP_AGENT");
    type = eArgPike;
    return 1;
  }

  //'--debug'|'--with-debug'|'--enable-debug')
  //  debug=1
  if (Match(*argv, "--debug", NULL, NULL) ||
    Match(*argv, "--with-debug", NULL, NULL) ||
    Match(*argv, "--enable-debug", NULL, NULL) )
  {
    m_iDebug = 1;
    type = eArgDebug;
    return 1;
  }

  //'--without-debug')
  //  debug=-1
  if (Match(*argv, "--without-debug", NULL, NULL))
  {
    m_iDebug = -1;
    type = eArgNoDebug;
    return 1;
  }

  //'--module-debug')
  //  debug=0
  if (Match(*argv, "--module-debug", NULL, NULL) ||
    Match(*argv, "--with-module-debug", NULL, NULL) ||
    Match(*argv, "--enable-module-debug", NULL, NULL) )
  {
    m_iDebug = 0;
    type = eArgDebug;
    return 1;
  }

  //'--fd-debug'|'--with-fd-debug'|'--enable-fd-debug')
  //  DEFINES="-DFD_DEBUG $DEFINES"
  if (Match(*argv, "--fd-debug", NULL, NULL) ||
    Match(*argv, "--with-fd-debug", NULL, NULL) ||
    Match(*argv, "--enable-fd-debug", NULL, NULL) )
  {
    m_saPikeDefines.Add("-DFD_DEBUG");
    type = eArgPike;
    return 1;
  }

  //'--offline')
  //  DEFINES="-DNO_DNS -DOFFLINE $DEFINES"
  if (Match(*argv, "--offline", NULL, NULL) )
  {
    m_saPikeDefines.Add("-DNO_DNS");
    m_saPikeDefines.Add("-DOFFLINE");
    type = eArgPike;
    return 1;
  }

  //'--without-ram-cache'|'--disable-ram-cache')
  //  DEFINES="`echo $DEFINES | sed -e 's/-DRAM_CACHE//g'`"
  if (Match(*argv, "--without-ram-cache", NULL, NULL) ||
    Match(*argv, "--disable-ram-cache", NULL, NULL) )
  {
    m_saPikeDefines.Remove("-DRAM_CACHE");
    type = eArgPike;
    return 1;
  }

  //'--without-http-compression'|'--disable-http-compression')
  //  DEFINES="`echo $DEFINES | sed -e 's/-DHTTP_COMPRESSION//g'`"
  //;;
  if (Match(*argv, "--without-http-compression", NULL, NULL) ||
    Match(*argv, "--disable-http-compression", NULL, NULL) )
  {
    m_saPikeDefines.Remove("-DHTTP_COMPRESSION");
    type = eArgPike;
    return 1;
  }

  //'--without-ram-cache-stat'|'--disable-ram-cache-stat')
  //  DEFINES="`-DRAM_CACHE_ASUME_STATIC_CONTENT`"
  if (Match(*argv, "--without-ram-cache-stat", NULL, NULL) ||
    Match(*argv, "--disable-ram-cache-stat", NULL, NULL) )
  {
    m_saPikeDefines.Add("-DRAM_CACHE_ASUME_STATIC_CONTENT");
    type = eArgPike;
    return 1;
  }

  //'--dump-debug'|'--with-dump-debug'|'--enable-dump-debug')
  //  DEFINES="-DDUMP_DEBUG $DEFINES"
  if (Match(*argv, "--dump-debug", NULL, NULL) ||
    Match(*argv, "--with-dump-debug", NULL, NULL) ||
    Match(*argv, "--enable-dump-debug", NULL, NULL) )
  {
    m_saPikeDefines.Add("-DDUMP_DEBUG");
    type = eArgPike;
    return 1;
  }

  //'--threads'|'--with-threads'|'--enable-threads')
  //  DEFINES="-DENABLE_THREADS $DEFINES"
  if (Match(*argv, "--threads", NULL, NULL) ||
    Match(*argv, "--with-threads", NULL, NULL) ||
    Match(*argv, "--enable-threads", NULL, NULL) )
  {
    m_saPikeDefines.Add("-DENABLE_THREADS");
    type = eArgPike;
    return 1;
  }

  //'--no-threads'|'--without-threads'|'--disable-threads')
  //  DEFINES="`echo $DEFINES | sed -e 's/-DENABLE_THREADS//g'`"
  if (Match(*argv, "--no-threads", NULL, NULL) ||
    Match(*argv, "--without-threads", NULL, NULL) ||
    Match(*argv, "--disable-threads", NULL, NULL) )
  {
    OutputLine(hOut, "Thread support not optional -- ignoring " + *argv);
    type = eArgPike;
    return 1;
  }

  //'--with-profile'|'--profile')
  //  DEFINES="-DPROFILE $DEFINES"
  if (Match(*argv, "--profile", NULL, NULL) ||
    Match(*argv, "--with-profile", NULL, NULL) )
  {
    m_saPikeDefines.Add("-DPROFILE");
    type = eArgPike;
    return 1;
  }

  //'--with-file-profile'|'--file-profile')
  //  DEFINES="-DPROFILE -DFILE_PROFILE $DEFINES"
  if (Match(*argv, "--file-profile", NULL, NULL) ||
    Match(*argv, "--with-file-profile", NULL, NULL) )
  {
    m_saPikeDefines.Add("-DFILE_PROFILE");
    type = eArgPike;
    return 1;
  }

  //'--quiet'|'-q')
  //  verbose=0
  if (Match(*argv, "-q", NULL, NULL) ||
      Match(*argv, "--quiet", NULL, NULL) )
  {
    m_iVerbose = 0;
    m_saRoxenArgs.Add("--quiet");
    type = eArgStart;
    return 1;
  }

  //'--verbose'|'-v')
  //  verbose=2
  //  debug=1
  if (Match(*argv, "-v", NULL, NULL) ||
      Match(*argv, "--verbose", NULL, NULL) )
  {
    m_iVerbose = 2;
    m_iDebug = 1;
    type = eArgStart;
    return 1;
  }

  //'--remove-dumped')
  //   remove_dumped=1;
  if (Match(*argv, "--remove-dumped", NULL, NULL) )
  {
    m_saRoxenArgs.Add(*argv);
    type = eArgRoxen;
    return 1;
  }

  //'--once')
  //  once=1
  if (Match(*argv, "--once", NULL, NULL) )
  {
    m_bOnce = TRUE;
    m_iDebug = max(m_iDebug, 0);
    type = eArgStart;
    return 1;
  }

//# Misspelling --once might give undesirable results, so let's accept
//# some "creative" spellings...  :-)
  //'--onve'|'--onec'|'--onev')
  //  once=1
  if (Match(*argv, "--onve", NULL, NULL) ||
      Match(*argv, "--onec", NULL, NULL) ||
      Match(*argv, "--onev", NULL, NULL) )
  {
    m_bOnce = TRUE;
    m_iDebug = max(m_iDebug, 0);
    type = eArgStart;
    return 1;
  }

  //'--keep-mysql')
  //  keep_mysql=1
  if (Match(*argv, "--keep-mysql", NULL, NULL) )
  {
    m_bKeepMysql = TRUE;
    type = eArgStart;
    return 1;
  }

  //'--gdb')
  //  gdb=gdb
  //  once=1
/*
  if (Match(*argv, "--msdev", NULL, NULL) )
  {
    m_bOnce = TRUE;
    m_bMsdev = TRUE;
    type = eArgStart;
    return 1;
  }
*/

  //'--program')
  //  program="$2"
  //  once=1
  //  passhelp=1
  if (Match(*argv, "--program", NULL, NULL) )
  {
    if (argc > 1)
    {
      int count;
      for (count=0; count<argc; count++)
        m_saRoxenArgs.Add(argv[count]);
      m_bOnce = TRUE;
      m_bPassHelp = TRUE;
      m_bKeepMysql = TRUE;
      m_bCheckVersion = FALSE;
      type = eArgNtLoader;
      return count;
    }
    else
    {
      type = eArgMoreData;
      return 1;
    }
  }

  //'--cd')
  //  cd_to="$2"
  //  # Use the absolute path...
  //  roxendir="`pwd`"
  //  once=1
  //  shift
  if (Match(*argv, "--cd", NULL, NULL) )
  {
    if (argc > 1)
    {
      m_saRoxenArgs.Add(*argv);
      m_saRoxenArgs.Add(argv[1]);
      m_bOnce = TRUE;
      type = eArgNtLoader;
      return 2;
    }
    else
    {
      type = eArgMoreData;
      return 1;
    }
  }

  //--debug-without=*|-r*|-d*|-t*|-l*|-w*|-a*|-p*|--*-debug*)
  //  # Argument passed along to Pike.
  //  ARGS="$ARGS $1"
  if (Match(*argv, "--debug-without=*", NULL, NULL) ||
      Match(*argv, "-r*", NULL, NULL) ||
      Match(*argv, "-d*", NULL, NULL) ||
      Match(*argv, "-t*", NULL, NULL) ||
      Match(*argv, "-l*", NULL, NULL) ||
      Match(*argv, "-w*", NULL, NULL) ||
      Match(*argv, "-p*", NULL, NULL) ||
      Match(*argv, "-a*", NULL, NULL) ||
      Match(*argv, "--*-debug*", NULL, NULL) )
  {
    m_saPikeArgs.Add(*argv);
    type = eArgPike;
    return 1;
  }

  //-D*|-M*|-I*|-P*)
  //  # Argument passed along to Pike.
  //  DEFINES="$DEFINES $1"
  if (Match(*argv, "-D*", NULL, NULL) ||
      Match(*argv, "-M*", NULL, NULL) ||
      Match(*argv, "-I*", NULL, NULL) ||
      Match(*argv, "-P*", NULL, NULL) )
  {
    m_saPikeDefines.Add(*argv);
    type = eArgPike;
    return 1;
  }

  //'--version')
  // if [ "x$passhelp" = "x1" ] ; then
  //   pass="$pass --version"
  // else
  //  if [ -f base_server/roxen.pike ]; then
  //    echo "Roxen WebServer `roxen_version`"
  //    exit 0
  //  else
  //    echo 'base_server/roxen.pike not found!'
  //    exit 1
  //  fi
  // fi
  if (Match(*argv, "--version", NULL, NULL))
  {
    if (m_bPassHelp)
    {
      m_saRoxenArgs.Add(*argv);
      type = eArgRoxen;
    }
    else
    {
      m_bCheckVersion = FALSE;
      m_bVersion = TRUE;
      type = eArgVersion;
    }
    return 1;
  }

  //'--self-test')
  //  setup_for_tests
  if (Match(*argv, "--self-test", NULL, NULL))
  {
    type = eArgSelfTest;
    return 1;
  }

  //'--self-test-quiet')
  //  debug=-1
  //  SILENT_START=y
  //  do_pipe="| grep '  |'"
  //  setup_for_tests
  if (Match(*argv, "--self-test-quiet", NULL, NULL))
  {
    // setup
    //type = eArgSelfTest;
    type = eArgUnsupported;
    return 1;
  }

  //'--self-test-verbose')
  //  pass="$pass --tests-verbose=1"
  //  setup_for_tests
  if (Match(*argv, "--self-test-verbose", NULL, NULL))
  {
    m_saRoxenArgs.Add("--tests-verbose=1");
    type = eArgSelfTest;
    return 1;
  }

  //--self-test-dir=*)
  //  SELF_TEST_DIR=`echo $1 | sed -e's/--self-test-dir=//'`
  if (Match(*argv, "--self-test-dir=*", "=", &value))
  {
    m_SelfTestDir.resize(strlen(value));
    for (int i=0; i<strlen(value); i++)
    {
      if (value[i] == '/')
        m_SelfTestDir[i] = '\\';
      else
        m_SelfTestDir[i] = value[i];
    }
    type = eArgStart;
    return 1;
  }

  //'--help'|'-?')
  if (Match(*argv, "--help", NULL, NULL) ||
      Match(*argv, "-?", NULL, NULL) )
  {
    if (m_bPassHelp)
    {
      m_saRoxenArgs.Add(*argv);
      type = eArgRoxen;
    }
    else
    {
      m_bCheckVersion = FALSE;
      m_bHelp = TRUE;
      type = eArgHelp;
    }
    return 1;
  }


  // Unknown option give it to roxen
  m_saRoxenArgs.Add(*argv);
  type = eArgRoxen;
  return 1;
}



void CCmdLine::ParseFinish()
{
  // Take care of some special argument handling

  //case "x$debug" in
  //  "x")
  //    DEBUG="-DMODULE_DEBUG "
  //    ARGS="$ARGS -w"
  //    ;;
  //  "x-1")
  //    DEBUG=""
  //    ;;
  //  "x1")
  //    DEBUG="-DDEBUG -DMODULE_DEBUG"
  //    ARGS="$ARGS -w"
  //    ;;
  //esac

  if (m_bParseFinished)
    return;

  // This must be before CheckVersionChange
  m_bParseFinished = TRUE;

  if (m_iDebug == 0)
  {
    m_saPikeDefines.AddIfNew("-DMODULE_DEBUG");
    m_saPikeArgs.AddIfNew("-w");
  }
  else if (m_iDebug == -1)
  {
  }
  else if (m_iDebug == 1)
  {
    m_saPikeDefines.AddIfNew("-DDEBUG");
    m_saPikeDefines.AddIfNew("-DMODULE_DEBUG");
    m_saPikeArgs.AddIfNew("-w");
  }

  // This must be after anything that changes the PikeDefines
  if (m_bCheckVersion)
  {
    if (CRoxen::CheckVersionChange())
    {
      m_saRoxenArgs.AddIfNew("--remove-dumped");
      HANDLE hOut = GetStdHandle(STD_OUTPUT_HANDLE);
      if (m_iVerbose >= 1)
        OutputLine(hOut, "                    : Removing old precompiled files (defines or pike version changed)");
    }
  }
}


BOOL CCmdLine::Parse(char * cmdline)
{
  int numargs;
  int numchars;

  SplitCmdline((_TSCHAR *)cmdline, NULL, NULL, &numargs, &numchars);

  _TSCHAR *p = new _TSCHAR[numargs * sizeof(_TSCHAR *) + numchars * sizeof(_TSCHAR)];

  SplitCmdline((_TSCHAR *)cmdline, (_TSCHAR **)p, p + numargs * sizeof(char *), &numargs, &numchars);

  int ret = Parse(numargs-1, (char **)p);

  delete p;

  return ret;
}


BOOL CCmdLine::Parse(int argc, char *argv[])
{
  BOOL ret = TRUE;
  tArgType type;
  HANDLE hOut = GetStdHandle(STD_OUTPUT_HANDLE);
  int i;

  if (!m_bPreloaded)
  {
    // Preload the argument lists with default values
    i = 0;
    while (defPikeArgs[i] != NULL)
    {
      m_saPikeArgs.Add(defPikeArgs[i]);
      i++;
    }
    
    i = 0;
    while (defPikeDefines[i] != NULL)
    {
      m_saPikeDefines.Add(defPikeDefines[i]);
      i++;
    }
    
    i = 0;
    while (defRoxenArgs[i] != NULL)
    {
      m_saRoxenArgs.Add(defRoxenArgs[i]);
      i++;
    }
    m_bPreloaded = TRUE;
  }

  // Walk through the argument list
  i = 1; // skip argv[0]
  while (i < argc && ret)
  {
    int numParsed = ParseArg(argc-i, &argv[i], type);

    switch (type)
    {
    case eArgStart:
      // No extra handling here
      //OutputLineFmt(hOut, ".BNtStart argument: %sB.", argv[i]);
      break;

    case eArgNtLoader:
      // No extra handling here
      //OutputLineFmt(hOut, ".BNtRoxenLoader argument: %sB.", argv[i]);
      break;

    case eArgPike:
      // No extra handling here
      //OutputLineFmt(hOut, ".BPike argument: %sB.", argv[i]);
      break;

    case eArgRoxen:
      // No extra handling here
      //OutputLineFmt(hOut, ".BRoxen argument: %sB.", argv[i]);
      break;

    case eArgDebug:
      // No extra handling here
      //OutputLineFmt(hOut, ".BDebug argument: %sB.", argv[i]);
      break;

    case eArgNoDebug:
      // No extra handling here
      //OutputLineFmt(hOut, ".BNoDebug argument: %sB.", argv[i]);
      break;

    case eArgVersion:
      // No extra handling here
      //OutputLineFmt(hOut, ".BVersion argument: %sB.", argv[i]);
      break;

    case eArgSelfTest:
      {
        // Make sure the var directory exists
        CreateDirectory("..\\var", NULL);

        std::string selfTestDirUnx;
        selfTestDirUnx.resize(m_SelfTestDir.length());
        for (int i=0; i<m_SelfTestDir.length(); i++)
        {
          if (m_SelfTestDir[i] == '\\')
            selfTestDirUnx[i] = '/';
          else
            selfTestDirUnx[i] = m_SelfTestDir[i];
        }
        
        //DEFINES="-DRUN_SELF_TEST -DSELF_TEST_DIR=\"$SELF_TEST_DIR\" $DEFINES"
	//DEFINES="$DEFINES \"-M$SELF_TEST_DIR/modules\""
        //rm -rf $VARDIR/test_config*
        //cp -R etc/test/config $VARDIR/test_config
        //cp etc/test/filesystem/test_rxml_package rxml_packages/test_rxml_package
        //DIR=$VARDIR/test_config
        //once=1
        //remove_dumped=1
        m_saPikeArgs.Add("-DRUN_SELF_TEST");
        m_saPikeArgs.Add(("-DSELF_TEST_DIR=\\\"" + selfTestDirUnx + "\\\"").c_str());
	m_saPikeArgs.Add(("\\\"-M" + selfTestDirUnx + "/modules\\\"").c_str());

        m_bOnce = TRUE;
        m_iDebug = max(m_iDebug, 1);
        m_ConfigDir = "../var/test_config";
        m_saRoxenArgs.Add(("--config-dir=" + m_ConfigDir).c_str());
        m_saRoxenArgs.Add("--remove-dumped");
        
        // Make sure that mysql is not running
        KillMySql(m_ConfigDir.c_str());

        SetEnvironmentVariable("COPYCMD", "/Y");
        system("rmdir /Q /S ..\\var\\test_config >NUL:");

        std::string setupCmd = m_SelfTestDir + "\\scripts\\setup.pike";
        DWORD attr = GetFileAttributes(setupCmd.c_str());
        if (attr != -1 && !(attr & FILE_ATTRIBUTE_DIRECTORY))
        {
	  setupCmd += stracat(" ", m_saPikeDefines.GetList());
          setupCmd += " " + selfTestDirUnx + " ../var";
          CRoxen::RunPike(setupCmd.c_str());
        }
        
      }
      //OutputLineFmt(hOut, ".BSelfTest argument: %sB.", argv[i]);
      break;

    case eArgHelp:
      // No extra handling here
      //OutputLineFmt(hOut, ".BHelp argument: %sB.", argv[i]);
      break;


    case eArgMoreData:
      ret = FALSE;
      OutputLineFmt(hOut, ".BArgument requires more data: %sB.", argv[i]);
      break;
      

    case eArgUnsupported:
      OutputLineFmt(hOut, ".BArgument not supported: %sB.", argv[i]);
      break;
      

    default:
      OutputLineFmt(hOut, ".BInternal Error: default case hit with: %sB.", argv[i]);
      break;
      
    }

    i += numParsed;
  }


  return ret;
}

