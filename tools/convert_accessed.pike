#!/usr/local/bin/pike

#include <stdio.h>

void main(int argc, array (string) argv)
{
  object in, in2, out;

  in=FILE();  // Buffered Input
  in2=FILE(); // Buffered Input
  out=File(); // Non-Buffered Output
  
  foreach(argv[1..], string file)
  {
    if(!in->open(file, "r"))
    {
      werror("Cannot open "+file+" for reading.\n");
      exit(2);
    }
    if(!in2->open(file+".times", "r"))
    {
      werror("Cannot open "+file+".times for reading.\n");
      exit(2);
    }
    if(!out->open(file+".db", "wc"))
    {
      werror("Cannot open "+file+".db for writing.\n");
      exit(2);
    }
    int a, b, more=1,j, tl=in->stat()[1];
    string s;
    werror("Converting "+file+" and "+file+".times\nto "+file+".db.\n");
    werror("You may remove "+file+"{,.times}\nafter this process ");
    werror("is finished.\n");
    while(more)
    {
      if(!((j++)%(tl/200+1)))werror((j*100)/(tl/4)+"%\r");
      a = (int)("0x"+(s=in->read(4)));  if(!strlen(s)||s==0) more=0;
      b = (int)("0x"+(s=in2->read(4)));  if(!strlen(s)||s==0) more=0;
      out->write(sprintf("%4c%4c", a, b));
    }
    werror("Done.\n");
  }
}
