#!/usr/local/bin/pike

object open(string f, string m)
{
  object fd = files.file();
  if(fd->open(f,m)) return fd;
  return 0;
}

void main(int args, array (string) files)
{
  program cl;
  string method;

  while(sscanf(files[0], "%*s/%s", files[0])==2);
  switch(files[0][0])
  {
   case 'd':
   case 'u':
    cl = Gz.inflate;
    method="Uncompress";
    break;
   default:
    cl = Gz.deflate;
    method="Compress";
  }
  
  files = files[1..];

  foreach(files, string file)
  {
    object o = open(file, "r");
    if(o)
    {
      mixed nf;
      nf = cl();
      if(nf->inflate) nf = nf->inflate;
      else if(nf->deflate) nf = nf->deflate;
      string comp;
      write(file+": ");
      string d = o->read();
      write(" Original "+strlen(d)+" ... ");
      if(catch {
	comp = nf(d);
	write(method+"ed: "+strlen(comp)+" ("+
	      ((strlen(comp)*100)/strlen(d))+"%)... ");
      })
      {
	write("Failed to "+method+".\n");
	o->close();
	continue;
      }
      o->close();
      if(!(o = open(file,"wct")))
      {
	write("Failed to open outdata-file.\n");
	o->close();
	continue;
      }	
      o->write(comp);
      write("Done.\n");
    } else
      write("Failed to open "+file+" for reading.\n");
  }
}
