/*
 * Pipe using sendfile, if possible.
 *
 * by Francesco Chemolli, based upon work by Per Hedbor and others.
 * (C) 1999 Idonex AB
 */

constant cvs_version="$Id: fastpipe.pike,v 1.2 1999/10/10 20:44:18 kinkie Exp $";

#if constant (Stdio.sendfile)

private array(string) headers=({});
private object file;
private int flen=-1;
private int sent=0;
private function done_callback;
private array(mixed) callback_args;

//API functions
int bytes_sent() {
  return sent;
}

private void sendfile_done(int written, function callback, array(mixed) args) {
  sent=written;
  headers=({}); //otherwise it all goes to hell with keep-alive..
  file=0;
  flen=-1;
  callback(@args);
  done_callback=0;
  callback_args=0;
}

void output (object(Stdio.File) fd) {
  // FIXME: timeout handling!
  Stdio.sendfile(headers,file,-1,flen,0,fd,sendfile_done,done_callback,callback_args);
}

void input (object what, int len) {
  if (file)
    error("HTTP-fastpipe: Multiple result files are not supported!\n");
  file=what;
  flen=len||-1;
}

void write(string what) {
  headers+=({what});
}

void set_done_callback(function|void f, void|mixed ... args) {
  done_callback=f;
  callback_args=args;
}

#else
inherit "smartpipe";
#endif
