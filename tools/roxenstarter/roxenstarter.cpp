/*  Roxenstarter
  $Id: roxenstarter.cpp,v 1.3 1998/04/26 21:46:41 js Exp $
*/
#include <windows.h> 
#include <string.h>
#include <stdio.h>
#include <time.h>
#include <process.h>
#include "resource.h"
#include "roxenstarter.h"

static HMENU hMenu,hVirtualMenu;
HWND hWnd;

char *log_location = NULL, *server_location = NULL, *pike_location = NULL;
char config_url[4096];
HANDLE roxen_fd_handle, hRoxen_process;
TCHAR *key="aaaaaaaa";
char *server_urls[256];

void check_registry(void)
{
  HKEY k;
  unsigned char buffer[4096];
  DWORD len=sizeof(buffer)-1,type=REG_SZ;
  
  if(pike_location) free(pike_location);
  if(server_location) free(server_location);
  if(log_location) free(log_location);
  pike_location=server_location=log_location=NULL;
  
  if(RegOpenKeyEx(HKEY_CURRENT_USER,
                  (LPCTSTR)"SOFTWARE\\Idonex\\Pike\\0.6",
                  0,KEY_READ,&k)==ERROR_SUCCESS ||
     RegOpenKeyEx(HKEY_LOCAL_MACHINE,
                  (LPCTSTR)"SOFTWARE\\Idonex\\Pike\\0.6",
                  0,KEY_READ,&k)==ERROR_SUCCESS)
  {
    if(RegQueryValueEx(k,
		       "PIKE_MASTER",
		       0,
		       &type,
		       buffer,
		       &len)==ERROR_SUCCESS)
    {
      pike_location=strdup((char*)buffer);
      pike_location[strlen(pike_location)-20]=0;
      strcat(pike_location,"bin/pike.exe");
    }
    RegCloseKey(k);
  }

  len = sizeof(buffer)-1;

  if(RegOpenKeyEx(HKEY_CURRENT_USER,
                  (LPCTSTR)"SOFTWARE\\Idonex\\Roxen\\1.3",
                  0,KEY_READ,&k)==ERROR_SUCCESS ||
     RegOpenKeyEx(HKEY_LOCAL_MACHINE,
                  (LPCTSTR)"SOFTWARE\\Idonex\\Roxen\\1.3",
                  0,KEY_READ,&k)==ERROR_SUCCESS)
  {
    if(RegQueryValueEx(k,
		       "installation_directory",
		       0,
		       &type,
		       buffer,
		       &len)==ERROR_SUCCESS)
      server_location=strdup((char*)buffer);
    len = sizeof(buffer)-1;
    if(RegQueryValueEx(k,
		       "log_directory",
		       0,
		       &type,
		       buffer,
		       &len)==ERROR_SUCCESS)
      log_location=strdup((char*)buffer);
    RegCloseKey(k);
  }
}

void start_roxen(void)
{
  check_registry();

  STARTUPINFO info;
  PROCESS_INFORMATION proc;
  TCHAR *filename=" ntroxenloader.pike", cmd[4000];
  srand(time(0));
  for(int i=0;i<8;i++)
    key[i]=65+32+((unsigned int)rand())%24;
  strcpy(cmd, pike_location);
  strcat(cmd, filename);
  strcat(cmd," +");
  strcat(cmd,key);
	
  void *env=NULL;
  GetStartupInfo(&info);
	info.wShowWindow=SW_HIDE;
  info.dwFlags|=STARTF_USESHOWWINDOW;
  int ret;
  ret=CreateProcess(pike_location,
		    cmd,
                    NULL,  /* process security attribute */
                    NULL,  /* thread security attribute */
                    1,     /* inherithandles */
                    0,     /* create flags */
                    env,   /* environment */
                    server_location,   /* current dir */
                    &info,
                    &proc);
  hRoxen_process=proc.hProcess;
}

void create_virtual_servers_menu(void *foo)
{
  hVirtualMenu = CreatePopupMenu();
  ModifyMenu(hMenu,1,MF_ENABLED|MF_BYPOSITION|MF_POPUP,(unsigned int)hVirtualMenu,"Virtual servers");	char buf[4096];
  strcpy(buf,log_location);
  strcat(buf,"\\");
  strcat(buf,"status");
  while(1)
  {
    for(int i=0;i<256;i++)
      if(server_urls[i])
      {
	DeleteMenu(hVirtualMenu,i,MF_BYPOSITION);
	free(server_urls[i]);
	server_urls[i]=NULL;
      }
    FILE *file=fopen(buf,"r");
    if(file)
    {
      int i=0;
      char server_url[4096], server_name[200];
      if(!fgets(config_url,sizeof(config_url)-1,file))
	goto foo;
      config_url[strlen(config_url)-1]=0;
      while(fgets(server_name, sizeof(server_name)-1, file))
      {
	if(!fgets(server_url, sizeof(server_url)-1, file))
	  goto foo;
	server_name[strlen(server_name)-1]=0;
	server_url[strlen(server_url)-1]=0;
	if(!AppendMenu( hVirtualMenu,MF_ENABLED,IDM_VIRTUALSERVERS+i,server_name)) goto foo;
	server_urls[i]=strdup(server_url);
	i++;
      }
    foo:
      Sleep(30000);
    }
  }
}

unsigned long kill_roxen(void *foo)
{
  Sleep(5000);
  TerminateProcess(hRoxen_process,0);
  return NULL;
}

void shutdown_roxen(void)
{
  char buf[4096];
  strcpy(buf,log_location);
  strcat(buf,"\\");
  strcat(buf,key);
  fopen(buf,"wc");
//	WriteFile(roxen_fd_handle,"die",3,&len,NULL);
//	_beginthread((void (__cdecl *)(void *))kill_roxen,32768,0);
}

void open_url(char *url)
{
  ShellExecute(hWnd,"open",url,NULL,NULL,0);
}

int APIENTRY WinMain(HINSTANCE hInstance,HINSTANCE hPrevInstance,
		     LPSTR lpCmdLine, int nCmdShow)
{
  MSG msg;                       
  if(!InitApplication(hInstance))
    return (FALSE);     
  if (!InitInstance(hInstance, nCmdShow))
    return (FALSE);
  hMenu = CreatePopupMenu();
  if(!AppendMenu( hMenu,MF_ENABLED,IDM_CONFIG,"Configuration interface")) return FALSE;
  if(!AppendMenu( hMenu,MF_ENABLED|MF_POPUP,(int)hVirtualMenu,"Virtual servers")) return FALSE;
  if(!AppendMenu( hMenu,MF_SEPARATOR,0,NULL)) return FALSE;
  if(!AppendMenu( hMenu,MF_ENABLED,IDM_RESTART,"Restart")) return FALSE;
  if(!AppendMenu( hMenu,MF_ENABLED,IDM_SHUTDOWN,"Shut down")) return FALSE;
  _beginthread((void (__cdecl *)(void *))create_virtual_servers_menu,32768,0);
  while (GetMessage(&msg,NULL,0,0))                
  {
    TranslateMessage(&msg);
    DispatchMessage(&msg); 
  }
  return (msg.wParam);  
}


BOOL InitApplication(HANDLE hInstance)       
{
  WNDCLASS  wcShellfun;
  wcShellfun.style = 0;                     
  wcShellfun.lpfnWndProc = (WNDPROC)MainWndProc; 
  wcShellfun.cbClsExtra = 0;              
  wcShellfun.cbWndExtra = 0;              
  wcShellfun.hInstance = hInstance;       
  wcShellfun.hIcon = LoadIcon(hInstance, MAKEINTRESOURCE(ROXEN_ICON));
  wcShellfun.hCursor = LoadCursor(NULL, IDC_ARROW);
  wcShellfun.hbrBackground = GetStockObject(WHITE_BRUSH); 
  wcShellfun.lpszClassName = "RoxenstarterWClass";

  return RegisterClass(&wcShellfun); 
}

BOOL InitInstance(HANDLE  hInstance, int nCmdShow) 
{
  g_hInst = hInstance;

  hWnd = CreateWindow(
    "RoxenstarterWClass",           
    "Roxenstarter", 
    WS_OVERLAPPEDWINDOW,
    CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT,
    NULL, NULL,               
    hInstance,          
    NULL);

  if (!hWnd)
    return (FALSE);

  roxenicon=LoadImage(hInstance, MAKEINTRESOURCE(ROXEN_ICON), IMAGE_ICON, 0, 0, LR_DEFAULTSIZE);

  start_roxen();
  TrayMessage(hWnd, NIM_ADD);
  ShowWindow(hWnd, SW_HIDE);
  UpdateWindow(hWnd);  
  return (TRUE);      
}


LONG APIENTRY MainWndProc(
  HWND hWnd,
  UINT message,
  UINT wParam, 
  LONG lParam) 
{         
  switch (message) 
  {
   case WM_CREATE:
   case TRAY_CALLBACK:
    TrayCallback(wParam, lParam);
    break;

   case WM_COMMAND:
    switch( LOWORD( wParam ))
    {
     case IDM_CONFIG:
      open_url(config_url);
      break;

     case IDM_RESTART:
      shutdown_roxen();
      Sleep(2000);
      start_roxen();
      break;

     case IDM_SHUTDOWN:
     case IDM_EXIT:
      shutdown_roxen();
      SendMessage(hWnd, WM_DESTROY, 0L, 0L);
      break;

     default:
      if(LOWORD(wParam)>=IDM_VIRTUALSERVERS&&LOWORD(wParam)<IDM_VIRTUALSERVERS+256)
      {
	open_url(server_urls[LOWORD(wParam)-IDM_VIRTUALSERVERS]);
	break;
      }
      return (DefWindowProc(hWnd, message, wParam, lParam));
    }
    break;

   case WM_DESTROY: 
    TrayMessage(hWnd, NIM_DELETE);
    PostQuitMessage(0);
    break;

   default:
    return (DefWindowProc(hWnd, message, wParam, lParam));
  }
  return (0);
}


void TrayCallback( WPARAM wParam, LPARAM lParam)
{
  UINT uID;
  UINT uMouseMsg;

  uID = (UINT)wParam;
  uMouseMsg = (UINT) lParam;
  if(uMouseMsg == WM_LBUTTONDBLCLK)
    open_url(config_url);
  else
    if(uMouseMsg == WM_RBUTTONDOWN || uMouseMsg == WM_RBUTTONDBLCLK || uMouseMsg == WM_LBUTTONDOWN)
    {
      POINT point;
      GetCursorPos(&point);
      RECT box;
      box.left=point.x-2;
      box.right=point.x+2;
      box.top=point.y-2;
      box.bottom=point.y+2;

      SetForegroundWindow(hWnd);
      if (uID == (UINT)ROXEN_ICON)
	TrackPopupMenu(hMenu, 0, point.x, point.y, 0, hWnd, &box) ;
    }
}


void TrayMessage( HWND hWnd, UINT message)
{
  NOTIFYICONDATA tnd;
  tnd.uFlags = NIF_MESSAGE|NIF_ICON|NIF_TIP;
  switch (message)
  {
   case NIM_DELETE:
    tnd.uFlags = 0;
    break;
  }
  strcpy(tnd.szTip,"Online, säkert.");
  tnd.uID =(UINT)ROXEN_ICON;
  tnd.cbSize		= sizeof(NOTIFYICONDATA);
  tnd.hWnd		= hWnd;
  tnd.uCallbackMessage = TRAY_CALLBACK;
  tnd.hIcon		= roxenicon;
  Shell_NotifyIcon(message, &tnd);
}
