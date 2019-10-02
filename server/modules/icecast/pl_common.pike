#!NO MODULE

// This file is part of Roxen WebServer. Copyright © 2001 - 2009, Roxen IS.
protected array md_callbacks = ({});
protected mapping md; // ID3 etc.

string codec   = "null";
string decoder = "null";

#include <module.h>
#include <roxen.h>
//<locale-token project="mod_icecast">LOCALE</locale-token>
#define _(X,Y)	_DEF_LOCALE("mod_icecast",X,Y)

Stdio.File recode( Stdio.File fd, int bitrate )
{
#ifndef __NT__
  Stdio.File devnull = Stdio.File("/dev/null", "r" );
#else
  Stdio.File devnull = Stdio.File("NL:", "r" );
#endif
  if( codec == "null" )
    return fd;

  array args;
  switch( decoder )
  {
    case "mpg123":
      args = ({ decoder,  "-s",  "-" });
      break;
    case "amp":
      args = ({ decoder,  "-c",  "-", "-" });
      break;
    case "null":
      args = 0;
  }

  if( args )
  {
    Stdio.File in = Stdio.File(), in2 = in->pipe();
    Process.Process( args,  ([ "stdin":fd, "stdout":in2,
			       "stderr":devnull, ]) );
    destruct( in2 );
    destruct( fd );
    fd = in;
  }

  args = 0;
  switch( codec )
  {
    case "null":
      break;

    case "gogo":
      args = ({codec,"-b",(string)bitrate,"-m","j","stdin",});
      break;

    case "bladeenc":
      array mono = ({});
      if( bitrate < 128 ) mono = ({ "-mono" });
      args = ({ codec, "-"+(string)bitrate, "-progress=0", @mono,
		"STDIN","STDOUT" });
      break;
  }

  if( args )
  {
    Stdio.File out = Stdio.File(), out2 = out->pipe();
    Process.Process( args ,(["stdin":fd,"stdout":out2,
			     "stderr":devnull, ]));
    destruct( out2 );
    destruct( fd );
    fd = out;
  }
  return fd;
}

mapping metadata()
{
  return md;
}

string query_provides()
{
  return "icecast:playlist";
}

void add_md_callback( function f )
{
  md_callbacks += ({ f });
}

void remove_md_callback( function f )
{
  md_callbacks -= ({ f });
}


void init_codec( function query )
{
  codec = query("codec");
  decoder = query("decoder");
}

void codec_vars(function defvar)
{
  defvar("codec", "null", _(0,"Encoder"), TYPE_STRING_LIST,
	 _(0,"The codec program to use to encode MPEG. Please note that "
	  "winamp does not support variable bitrate, thus, if your mpeg "
	   "files does not all have the correct bitrate, use the encoder "
	   "and decoders to enforce a bitrate. This will cause slightly lower"
	   "sound quality."),
	 ({ "null", "bladeenc" }) );
  defvar("decoder", "null", _(0,"Decoder"), TYPE_STRING_LIST,
	 _(0,"The decoder program to use to decode MPEG"),
	 ({ "null", "mpg123", "amp" }) );
  defvar("bitrate", 128, _(0,"Bitrate"), TYPE_INT_LIST,
	 _(0,"The bitrate to use when recoding"),
	({
	  320,  256,  224,  192,   160,   128,   112,
	  96,   80,   64,    56,   48,    40,    32
	}));
};

void call_md_callbacks( )
{
  foreach( md_callbacks, function f )
    if( catch( f( md ) ) )
      md_callbacks -= ({f});
}

void fix_metadata( string path,
		   Stdio.File fd )
{
  md = ([]);
  if( path ) md->path = path;
  // FIXME
  call_md_callbacks(  );
}
