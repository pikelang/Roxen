#!/usr/local/bin/pike

#include <process.h>
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
    int a, b, pid, more=1,j, tl=in->stat()[1];
    string s;
    werror("Copying "+file+".main to "+file+".names.\n");
    popen("cp "+file+".main "+file+".names");
    werror("Converting "+file+" and "+file+".times\nto "+file+".db.\n");
    werror("You may remove "+file+"{,.times}\nafter this process ");
    werror("is finished.\n");
    while(more)
    {
      if(!((j++)%(tl/200+1)))werror((j*100)/(tl/4)+"%\r");
      a = (int)("0x"+(s=in->read(8)));  if(!strlen(s)||s==0) more=0;
      b = (int)("0x"+(s=in2->read(8)));  if(!strlen(s)||s==0) more=0;
      out->write(sprintf("%4c%4c", a, b));
    }
    werror("Done.\n");
  }
}
