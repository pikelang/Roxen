inherit "module";
constant cvs_version="$Id: dir_playlist.pike,v 1.1 2001/04/10 01:20:47 per Exp $";
constant thread_safe=1;

#include <module.h>
#include <roxen.h>
#include <stat.h>
#include <request_trace.h>

//<locale-token project="mod_icecast">LOCALE</locale-token>
#define _(X,Y)	_DEF_LOCALE("mod_icecast",X,Y)


constant     module_type = MODULE_PROVIDER;
LocaleString module_name = _(0,"Icecast: MPEG-directory playlist");
LocaleString  module_doc = _(0,"Provides a directory as a playlist. "
			       "The files are played in random order");
constant   module_unique = 0;

inherit "pl_common";

array list = ({});

string pl_name()
{
  return ("dir:"+query( "dir" )+" ("+sizeof(list)+" files)");
}

Stdio.File next_file()
{
  Stdio.File fd;
  while( 1 )
  {
    string f = list[0];
    list = list[1..] + ({ f });

    fd = Stdio.File();
    if( fd->open( f, "r" ) )
    {
      fix_metadata( f,fd );
      return fd;
    }
  }
}

void start()
{
  list = ({});
  void recursively_add( string d )
  {
    foreach( get_dir( d ) || ({}), string f )
    {
      Stat s = file_stat( d+"/"+f );
      if( s )
      {
	if( s->isdir )
	  recursively_add( d+"/"+f );
	else
	{
	  switch( (f/".") [-1] )
	  {
	    case "mpg":
	    case "mp3":
	    case "mp2":
	    case "mp1":
	      list += ({ combine_path( d+"/",f) });
	  }
	}
      }
    }
  };
  recursively_add( query("dir") );
  for( int i = 0; i<10; i++ )
    list = Array.shuffle( list );
}

void create()
{
  defvar("dir", "NONE", _(0,"Directory"), TYPE_DIR|VAR_INITIAL,
	 _(0,"The directory that contains the mpeg-files."));
}
