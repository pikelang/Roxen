#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/Xos.h>
#include <X11/Xatom.h>
#include <stdio.h>
#include <math.h>
#include <sys/types.h>
#include <netinet/in.h>

static Display *display;
static Window win;
static Pixmap me;
static XFontStruct *font;
static GC gc;
static GC gc2;

static int height, baseline;

static void init_x(int argc, char *argv[])
{
  /* Open window etc. */
  char *window_name = "XFontDump";
  char *icon_name = "XFontDump, do _not_ iconify!";
  XSizeHints size_hints;
  XEvent report;
  Colormap colormap;
  XGCValues GCvalues;

  char *fname;

  unsigned long valuemask;
  int screen_num;
  int i, odepth;

  if(argc < 2)
  {
    fprintf(stderr, "No font specified.\n");
    exit(0);
  } else
    fname = argv[1];

  display = XOpenDisplay(NULL);
  screen_num = DefaultScreen(display);
  
  if(!display)
  { 
    fprintf(stderr, "Cannot open display.\n");
    exit(1);
  }
  

#if 0
  win = XCreateSimpleWindow(display, RootWindow(display, screen_num),
			   0,0,400,400,0,0,0);
#endif
  me = XCreatePixmap(display, RootWindow(display, screen_num), 400, 400, 8);
  font = XLoadQueryFont(display, fname);

  if(!font)
  {
    fprintf(stderr, "Cannot load font.\n");
    exit(1);
  }
  height = font->ascent + font->descent;
  baseline = font->ascent / 3;
  

  valuemask = GCForeground|GCFont|GCBackground;
  GCvalues.foreground = 1;
  GCvalues.background = 0;
  GCvalues.font = font->fid;
  gc = XCreateGC(display, me, valuemask, &GCvalues);
  GCvalues.foreground = 1;
  GCvalues.background = 0;
  GCvalues.font = font->fid;
  gc2 = XCreateGC(display, me, valuemask, &GCvalues);
#if 0
  {
    XWMHints wm_hints;
    XTextProperty windowName, iconName;

    size_hints.flags = PPosition | PSize | PMinSize;
    size_hints.min_width = 100;
    size_hints.min_height = 100;

    XStringListToTextProperty(&window_name, 1, &windowName);
    XStringListToTextProperty(&icon_name, 1, &iconName);
    
    wm_hints.initial_state = NormalState;
    wm_hints.input = True;
    wm_hints.flags = StateHint | InputHint;

    XSetWMProperties(display, me, &windowName, &iconName, argv, argc,
		     &size_hints, &wm_hints, NULL);
    XSelectInput(display, me, ExposureMask);

    XMapWindow(display, me);
  }
#endif
  XFlush(display);
}

struct char_t {
  ulong width;
  ulong spacing;
  char data; /* width x height bytes (grey, 255=full color). */
};


void save_pgm_char(unsigned char c, struct char_t *cid)
{
  FILE *f;
  char name[4];
  sprintf(name, "%03d%c", c, 0);
  unlink(name);
  if(cid)
  {
    f = fopen(name, "w");
    fprintf(stderr, "%s(%dx%d)", name, cid->width, height);
    fprintf(f, "P5\n# CREATOR: XDumpFont\n%d %d\n%d\n", cid->width, height, 255);
    fwrite(&(cid->data), cid->width*height, 1, f);
    fflush(f);
    fclose(f);
  }
  fputs("\n", stderr);
}

#define MAX(x,y) ((x)<(y)?(y):(x))
#define MIN(x,y) ((x)>(y)?(y):(x))
#define ABS(x)   ((x)<(0)?-(x):(x))

static inline int MSB_8_GetPixel(XImage *im, int x, int y)
{
#if 0
  if(im->format != ZPixmap && im->bits_per_pixel != 8)
    perror("InvalidFormat");
#endif
  if(y>im->height || x>im->width || y<0 || x<0) return 0;
  return ((unsigned char *)im->data)[y * im->bytes_per_line + x];
}

#undef COMPAT

#ifdef COMPAT
#define GetPixel(i,x,y) (0!=XGetPixel(i,x,y))
#else
#define GetPixel(i,x,y) (0!=MSB_8_GetPixel(i,x,y))
#endif

void low_dump_char(unsigned char c, struct char_t *cid)
{
  XImage *char_data;
  int x, y, m, mx=0, my=0, pos=0, width=cid->width;

  if(width<=0 || cid->spacing<=0)
  {
    cid->width=0;
    cid->spacing=0;
    return;
  }

  if(c==32) /* Space, some X-fonts have buggy spaces?? */
  {
    if(width < height/3 || width > 400)
      width = cid->spacing = height / 3;
  }
  
  if(width > 400)
  {
    fprintf(stderr, "Odd width.\n");
    width = cid->width = 0;
    cid->spacing /= 3;
    return;
  }

  char_data = XGetImage(display, me, 0, 0, width+10, height+2, 255, ZPixmap);

  if(!char_data)
  {
    cid->width=0;
    cid->spacing=0;
    return;
  }

  for(y=0; y<height-2; y+=3)
  {
    for(x=0; x<width-2; x+=3)
    {
      int c = GetPixel(char_data,x,y) + GetPixel(char_data,x,y+1)
	+ GetPixel(char_data,x,y+2)   + GetPixel(char_data,x+1,y)
	+ GetPixel(char_data,x+1,y+1) + GetPixel(char_data,x+1,y+2)
	+ GetPixel(char_data,x+2,y)   + GetPixel(char_data,x+2,y+1)
	+ GetPixel(char_data,x+2,y+2);
      (&cid->data)[pos++] = 255 - ((c*255)/9);
    }
    if((x-3)/3 > mx) mx = (x-3)/3;
  }
  cid->width  = mx+1;
  cid->spacing = cid->spacing/3;
  XDestroyImage(char_data);
}


int font_size;
struct char_t *chars[256];

void dump_char(unsigned char c)
{
  int width, asize;
  struct char_t *character;
  char todraw[4];
  todraw[0]=c;
  todraw[1]=' ';
  todraw[2]=' ';
  todraw[3]=0;

/*  XFlush(display);*/
  width = XTextWidth( font, &c, 1 );

  character =
    (struct char_t *)malloc(sizeof(struct char_t)+
			    font->per_char[c].rbearing/2*height/2);
  character->width = font->per_char[c].rbearing;
  character->width *= 1.1;
  character->spacing = width;
#if 0
  fprintf(stderr, "%d (%d, %d) x %d\n", c, character->width, 
	  character->spacing, height);
#endif
/*  character->height = height;*/

  /*  XClearPixmap(display, me); */
  XDrawRectangle(display, me, gc2, 0, 0, 2100, 2100);
  XDrawImageString(display, me, gc, 0, font->ascent, todraw, 3);
  /* XDrawRectangle(display, me, gc, 0, 0, width+1, height+1);*/
  XFlush(display);

  if(c>30)
    fputc(c,stderr);
  else
  {
    fputc('\\',stderr);
    fputc(c/10+'0',stderr);
    fputc(c%10+'0',stderr);
  }
  
  low_dump_char(c, character);
  font_size += 
    ((sizeof(struct char_t)+character->width*(height/3)-1)/4+1)*4;
  chars[ c ] = character;
}


#define FONT_FILE_VERSION 1
void concatenate_and_write_font()
{
  struct font {
    ulong cookie;
    ulong version;
    ulong numchars;
    ulong height;
    ulong baseline;
    ulong offsets[256];
  } *font;
  char *data;
  int pos, clen, c;
  FILE *f;
  pos = sizeof(struct font);
  data = (char *)malloc(font_size + sizeof(struct font));
  font = (struct font *)data;

  font->cookie = htonl(0x464f4e54);
  font->version = htonl(FONT_FILE_VERSION);
  font->height = htonl(height);
  font->baseline = htonl(baseline);
  font->numchars = 256;
  
  for(c=0; c<256; c++)
  {
    clen = ((sizeof(struct char_t)+chars[c]->width*height-1)/4+1)*4;
    font->offsets[c]=htonl(pos);
    chars[c]->width = htonl(chars[c]->width);
    chars[c]->spacing = htonl(chars[c]->spacing);
    memcpy(data+pos, chars[c], clen);
    pos+=clen;
  }
  f = fopen("font", "w");
  fwrite(data, font_size+sizeof(struct font), 1, f);
  fflush(f);
  fclose(f);
}

void main(int argc, char *argv[])
{
  int i;
  XEvent xev;
  init_x(argc,argv);
#if 0
  XNextEvent(display, &xev);
#endif
  for(i=0;i<256;i++)
    dump_char(i);
  height /= 3;
  concatenate_and_write_font();
} 




