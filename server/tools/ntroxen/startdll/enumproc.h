/*********************
EnumProc.h
*********************/ 

#ifndef __ENUM_PROC__H__
#define __ENUM_PROC__H__

#ifdef __cplusplus
extern "C" {
#endif

typedef BOOL (CALLBACK *PROCENUMPROC)( DWORD, WORD, LPSTR,
  LPARAM ) ;

BOOL WINAPI EnumProcs( PROCENUMPROC lpProc, LPARAM lParam );
BOOL WINAPI Enum16( DWORD dwThreadId, WORD hMod16, WORD hTask16,
  PSZ pszModName, PSZ pszFileName, LPARAM lpUserDefined );
BOOL CALLBACK Proc( DWORD dw, WORD w16, LPSTR lpstr, LPARAM lParam );

BOOL KillMySql(const char *confdir);

#ifdef __cplusplus
}
#endif

#endif
