#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/Xos.h>
#include <X11/Xatom.h>
#include <stdio.h>
#include <math.h>
#include <sys/types.h>
#include <netinet/in.h>

#define SCALE 8

static Display *display;
static Pixmap me;
static XFontStruct *font;
static GC gc;
static GC gc2;

static int height, baseline;

static void init_x(int argc, char *argv[])
{
  /* Open window etc. */
  XGCValues GCvalues;

  char *fname;

  unsigned long valuemask;
  int screen_num;

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
  
  me = XCreatePixmap(display, RootWindow(display, screen_num), 1200, 1200,
		     DefaultDepth(display, screen_num));
  font = XLoadQueryFont(display, fname);

  if(!font)
  {
    fprintf(stderr, "Cannot load font.\n");
    exit(1);
  }
  height = font->ascent + font->descent;
  baseline = font->ascent / SCALE;
  

  valuemask = GCForeground|GCFont|GCBackground;
  GCvalues.foreground = 1;
  GCvalues.background = 0;
  GCvalues.font = font->fid;
  gc = XCreateGC(display, me, valuemask, &GCvalues);
  GCvalues.foreground = 1;
  GCvalues.background = 0;
  GCvalues.font = font->fid;
  gc2 = XCreateGC(display, me, valuemask, &GCvalues);
  XFlush(display);
}

struct char_t {
  ulong width;
  ulong spacing;
  char data; /* width x height bytes (grey, 255=full color). */
};


#define GetPixel(i,x,y) (0!=XGetPixel(i,x,y))

void low_dump_char(unsigned char c, struct char_t *cid)
{
  XImage *char_data;
  int x, y, pos=0, width=cid->width;

  if(width<=0 || cid->spacing<=0)
  {
    cid->width=0;
    if(cid->spacing < 0)
      cid->spacing=0;
    return;
  }

  char_data = XGetImage(display, me, 0, 0, width+10, height+2, 255, ZPixmap);

  if(!char_data)
  {
    cid->width=0;
    return;
  }

  for(y=0; y<height-SCALE+1; y+=SCALE)
  {
    for(x=0; x<width-SCALE+1; x+=SCALE)
    {
      int xp, yp, c=0;
      for(xp=0; xp<SCALE; xp++)
	for(yp=0; yp<SCALE; yp++)
	  c += GetPixel(char_data,x+xp,y+yp);
      (&cid->data)[pos++] = 255 - ((c*255)/(SCALE*SCALE));
    }
  }
  cid->width  = width/SCALE;
  cid->spacing = cid->spacing/SCALE;
  XDestroyImage(char_data);
}


int font_size;
struct char_t *chars[65536];

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

  if((c>=font->min_char_or_byte2) && (c<=font->max_char_or_byte2))
  {
    int rw = font->per_char[c-font->min_char_or_byte2].rbearing;
    
    character =(struct char_t *)malloc(sizeof(struct char_t) +
				       ((rw+rw/10)/SCALE+1) * (height/SCALE+1));
    if(!character)
    {
      fprintf(stderr,"Malloc %d bytes failed.\n",
	      sizeof(struct char_t)+((rw+rw/10)/SCALE+1)*(height/SCALE+1));
      exit(0);
    }
    character->width = (int)((float)rw*1.1);
    character->spacing = width;
  } else {
    character = (struct char_t *)malloc(sizeof(struct char_t)+4);
    character->width=0;
    character->spacing=width;
  }
    
  XDrawRectangle(display, me, gc2, 0, 0, 2100, 2100);
  XDrawImageString(display, me, gc, 0, font->ascent, todraw, 3);
  XFlush(display);
  
  low_dump_char(c, character);
  font_size+=((sizeof(struct char_t)+character->width*(height/SCALE)-1)/4+1)*4;
  chars[ c ] = character;
}


#define FONT_FILE_VERSION 1
void concatenate_and_write_font(int numchars)
{
  struct font {
    ulong cookie;
    ulong version;
    ulong numchars;
    ulong height;
    ulong baseline;
    ulong offsets[numchars];
  } *font;
  char *data;
  unsigned int pos, clen, c;
  int fd;
  pos = sizeof(struct font);
  /* Scratch buffer. Has to be big enough.. */
  data = (char *)malloc(font_size*2 + sizeof(struct font));
  font = (struct font *)data;

  font->cookie = htonl(0x464f4e54);
  font->version = htonl(FONT_FILE_VERSION);
  font->height = htonl(height/SCALE);
  font->baseline = htonl(baseline);
  font->numchars = htonl(numchars);
  
  for(c=0; c<numchars; c++)
  {
    if(chars[c]->width)
      clen = ((sizeof(struct char_t)+chars[c]->width*height/SCALE-1)/4+1)*4;
    else
      clen = sizeof(struct char_t);
    font->offsets[c]=htonl(pos);
    chars[c]->width = htonl(chars[c]->width);
    chars[c]->spacing = htonl(chars[c]->spacing);
    memcpy(data+pos, chars[c], clen);
    pos+=clen;
  }
  fd = open("font", O_WRONLY|O_CREAT);
  write(fd, data, pos);
  close(fd);
}

void main(int argc, char *argv[])
{
  int i;
  int numchars = 256;
  XEvent xev;
  init_x(argc,argv);
  for(i=0;i<numchars;i++) dump_char(i);
  concatenate_and_write_font(numchars);
} 




