// CONSTANTS
#define APPBAR_CALLBACK     WM_USER + 100 
#define TRAY_CALLBACK       WM_USER + 101  

#define IDM_CONFIG			401
#define IDM_RESTART			402
#define IDM_SHUTDOWN			403
#define IDM_VIRTUALSERVERS              600


#define IDM_ADD                         32775
#define IDM_EXIT                        32787
#define IDM_ABOUT                       32788

// Globals
HINSTANCE g_hInst;
HICON roxenicon;


// Function prototypes
// procs
LONG APIENTRY MainWndProc(HWND, UINT, UINT, LONG);

//functions
BOOL InitApplication(HANDLE);
BOOL InitInstance(HANDLE, int);
void TrayMessage( HWND hWnd, UINT message);
void TrayCallback( WPARAM wParam, LPARAM lParam);


