#include <sys/types.h>
#include <sys/stat.h>
#include <sys/fcntl.h>
#include <errno.h>
#include <netinet/in.h>
#include <stdio.h>

#include "readfont.h"

static inline int my_read(int from, char *buf, int towrite)
{
  int res;
  while((res = read(from, buf, towrite)) < 0)
  {
    switch(errno)
    {
     case EAGAIN: case EINTR:
      continue;

     default:
      res = 0;
      return 0;
    }
  }
  return res;
}

static inline int file_size(int fd)
{
  struct stat tmp;
  int res;
  if(!fstat(fd, &tmp)) return res = tmp.st_size;
  return -1;
}


#define HAVE_MMAP

#ifdef HAVE_MMAP
#include <sys/mman.h>
#endif

Font *OpenFont(char *filename)
{
  int fd, c;
  int size;
  char *handle;
  struct offsets {
    ulong cookie;
    ulong version;
    ulong numchars;
    ulong height;
    ulong baseline;
    ulong o;
  } *off;
  Font *newfont;

  struct chead {
    ulong width;
    ulong spacing;
    unsigned char data;
  };

  if((fd = open(filename, O_RDONLY)) > -1)
  {
    size = file_size( fd );
    if(size < 0)
    {
      close(fd);
      return NULL;
    }
#ifdef HAVE_MMAP
    handle = mmap(0,size,PROT_READ,MAP_SHARED,fd,0);
#else
    handle = (char *)malloc(size);
    my_read(fd,handle,size);
#endif
    close(fd);
  } /* Now handle is O.K. */
  
  off = (struct offsets *)handle;
  if(ntohl(off->cookie) != 0x464f4e54)
  {
    fprintf(stderr, "This is not a font file.\n");
    return NULL;
  }
  if(ntohl(off->version) > FONT_FILE_VERSION)
  {
    fprintf(stderr, "Version mismatch.\n");
    return NULL;
  }
  
  newfont = (Font *)malloc(sizeof(Font));
  newfont->numchars = ntohl(off->numchars);
  newfont->c = (Char *)malloc(sizeof(Char)*newfont->numchars);
  newfont->height = ntohl(off->height);
  newfont->baseline = ntohl(off->baseline);
  newfont->size = size;
  newfont->handle = handle;

  for(c=0; c<newfont->numchars; c++)
  {
    struct chead *ch;
    ch = (struct chead *)(handle + ntohl((&off->o)[c]));
    newfont->c[c].width = ntohl(ch->width);
    newfont->c[c].spacing = ntohl(ch->spacing);
    newfont->c[c].data = (((unsigned char *)ch)+(sizeof(ulong)*2));
  }
  return newfont;
}

void CloseFont(Font *font)
{
#ifdef HAVE_MMAP
  munmap(font->handle, font->size);
#else
  free(font->handle);
#endif
  free(font->c);
  free(font);
}
