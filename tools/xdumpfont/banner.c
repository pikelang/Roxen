#include <stdio.h>
#include "readfont.h"

void print_char(unsigned char c, Font *mf)
{
  int x, y, w, h;
  w = mf->c[c].width;
  h = mf->height;

  if(c==' ')
  {
    putchar('\n');
    putchar('\n');
    return;
  }
  for(x=0; x<w; x++)
  {
    for(y=h-1; y>=0; y--)
    {
      int col;
      col = mf->c[c].data[ y*w + x ];
      if(col < 16) {
	putchar('Ø'); putchar('ß');
      } else if(col < 64) {
	putchar('#'); putchar('*');
      }	else if(col < 96) {
	putchar('*'); putchar('x');
      }	else if(col < 128) {
	putchar('x'); putchar('+');
      }	else if(col < 196) {
	putchar('+'); putchar('×');
      }	else if(col < 230) {
	putchar('×'); putchar('·');
      }	else if(col < 255) {
	putchar('·'); putchar('·');
      }	else {
	putchar(' '); putchar(' ');
      }
    }
    putchar('\n');
  }
}

void main(int argc, char **argv)
{
  int i, j, w, h;
  Font *mf;

  mf = OpenFont("font");
  for(i=1; i<argc; i++)
  {
    for(j=0; j<strlen(argv[i]); j++)
      print_char(argv[i][j], mf);
    print_char(' ', mf);
  }
  CloseFont( mf );
}
