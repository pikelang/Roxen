// This is a roxen module. Copyright © 2001 - 2009, Roxen IS.

inherit "module";
constant cvs_version="$Id$";
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
	  if(search(query("exts")/"," || ({}), (f/".")[-1]) > -1)
	      list += ({ combine_path( d+"/",f) });
  };
  recursively_add( query("dir") );
  if(query("mode") == "shuffle")
    list = Array.shuffle( list );
  else
    list = Array.sort( list );
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
  defvar("mode", "shuffle", _(0,"Playing mode"), TYPE_STRING_LIST,
         _(0,"The mode used to serve mpeg-files."),
	 ({ "shuffle", "linear" }) );
  defvar("exts", "mpg,mp1,mp2,mp3", _(0,"File extensions"), TYPE_STRING,
         _(0,"Comma separated list of file extensions of mpeg-files."));

  codec_vars(defvar);
}
