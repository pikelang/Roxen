// Pipe using sendfile, if possible.
// by Francesco Chemolli, based upon work by Per Hedbor and others.
// Copyright © 1999 - 2000, Roxen IS.

constant cvs_version="$Id$";

private array(string) headers=({});
private Stdio.File file;
private int flen=-1;
private int sent=0;
private function done_callback;
private array(mixed) callback_args;

//API functions
int bytes_sent() 
{
  return sent;
}

private void sendfile_done(int written, function callback, array(mixed) args) 
{
  sent=written;
  headers=({});
  file=0;
  flen=-1;
  // NB: Throwing of errors from sendfile-done callbacks should
  //     be avoided, due to a bug in the pike backend. [WS-545]
  mixed err = catch {
      if( done_callback ) done_callback(@callback_args);
    };
  done_callback=0; callback_args=0;
  if (err) {
    master()->handle_error(err);
  }
}

void output (Stdio.File fd)
{
  // FIXME: timeout handling!
//   werror( "%O\n", ({strlen(headers[0]),file,-1,flen,0,fd,sendfile_done}) );
  Stdio.sendfile(headers,file,-1,flen,0,fd,sendfile_done);
}

void input (Stdio.File what, int len)
{
  if (file)
    error("HTTP-fastpipe: Multiple result files are not supported!\n");
  file=what;
  flen=len||-1;
}

void write(string what)
{
  headers+=({what});
}

void set_done_callback(function|void f, void|mixed ... args)
{
  done_callback=f;
  callback_args=args;
}

