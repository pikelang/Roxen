#include <stdio.h>
#include "readfont.h"

int x, y;
int c;

void main()
{
  Font *mf;
  mf = OpenFont("font");
  for(c=0; c<256; c++)
  {
    int w;
/*    fprintf(stderr, "%d: <%d,%d> (%x)\n", c, mf->c[c].width, mf->c[c].height,
	    mf->c[c].data);*/
    w = mf->c[c].width;
    for(y=0; y<mf->height; y++)
    {
      char empty;
      if(y==mf->baseline)
	empty = '_';
      else
	empty = ' ';
      for(x=0; x<w; x++)
      {
	int col;
	col = mf->c[c].data[ y*w + x ];
	if(col < 32)
	{
	  putchar('#');
	  putchar('#');
	}
	else if(col < 64)
	{
	  putchar('*');
	  putchar('*');
	}
	else if(col < 96)
	{
	  if(empty == '_')
	  {
	    putchar('±');
	    putchar('±');
	  } else {
	    putchar('+');
	    putchar('+');
	  }
	}
	else if(col < 255)
	{
	  if(empty == '_')
	  {
	    putchar('_');
	    putchar('_');
	  } else {
	    putchar('·');
	    putchar('·');
	  }
	}
	else 
	{
	  putchar(empty);
	  putchar(empty);
	}
      }
      putchar('\n');
    }
  }
  CloseFont(mf);
  fflush(stdout);
}

