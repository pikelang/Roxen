// This is a roxen module. Copyright © 2001, Roxen IS.

inherit "module";
constant cvs_version="$Id: dir_playlist.pike,v 1.3 2001/09/03 18:16:56 nilsson Exp $";
constant thread_safe=1;

#include <module.h>
#include <roxen.h>

//<locale-token project="mod_icecast">LOCALE</locale-token>
#define _(X,Y)	_DEF_LOCALE("mod_icecast",X,Y)

constant     module_type = MODULE_PROVIDER;
LocaleString module_name = _(0,"Icecast: MPEG-directory playlist");
LocaleString  module_doc = _(0,"Provides a directory as a playlist. "
			       "The files are played in random order");
constant   module_unique = 0;

inherit "pl_common";

array list = ({});
string current_file;

string pl_name()
{
  return ("dir:"+query( "dir" )+" ("+sizeof(list)+" files)");
}

Stdio.File next_file()
{
  if(!sizeof( list ) )   return 0;

  werror("stream next song\n");

  Stdio.File fd;
  while( string f = list[0] )
  {
    list = list[1..] + ({ f });
    fd = Stdio.File();
    if( fd->open( f, "r" ) )
    {
      current_file = f;
      fix_metadata( f,fd );
      return recode( fd, query( "bitrate" ) );
    }
  }
}

void start()
{
  init_codec( query );
  list = ({});
  void recursively_add( string d )
  {
    foreach( get_dir( d ) || ({}), string f )
      if( Stat s = file_stat( d+"/"+f ) )
	if( s->isdir )
	  recursively_add( d+"/"+f );
	else
	  switch( (f/".") [-1] )
	  {
	    case "mpg":    case "mp3":
	    case "mp2":    case "mp1":
	      list += ({ combine_path( d+"/",f) });
	  }
  };
  recursively_add( query("dir") );
  list = Array.shuffle( list );
}

string peek_next()
{
  return sizeof(list) && list[0];
}

string status()
{
  if( !current_file ) return "Nothing is playing\n";
  return sprintf("Currently playing %s <br />\n"
  		 "Next song is %s\n", current_file[strlen(query("dir"))..],
		 peek_next()[strlen(query("dir"))..] );
}


void create()
{
  defvar("dir", "NONE", _(0,"Directory"), TYPE_DIR|VAR_INITIAL,
	 _(0,"The directory that contains the mpeg-files."));
  codec_vars(defvar);
}
