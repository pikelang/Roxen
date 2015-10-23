// This is a roxen module. Copyright © 2000 - 2009, Roxen IS.

inherit "module";

constant cvs_version= "$Id$";

// The Filesystem.Tar module is not threadsafe.
constant thread_safe=0;

//<locale-token project="mod_tarfs">_</locale-token>
#define _(X,Y)	_DEF_LOCALE("mod_tarfs",X,Y)
// end of the locale related stuff
#include <module.h>

constant module_type = MODULE_LOCATION;
LocaleString module_name = _(1,"File systems: Tar File");
LocaleString module_doc =
_(2,"This is a file system module that makes it possible to mount a "
 "directory structure from a tar-file directly on the site. gzip compressed "
 "tar-files are not supported");
constant module_unique = 0;

void create()
{
  defvar( "mountpoint", "/", 
          _(3,"Mount point"), TYPE_LOCATION|VAR_INITIAL,
          _(4,"Where the module will be mounted in the site's virtual file "
          "system.") );

  defvar("tarfile", "docs.tar", 
         _(5,"Tar file and root path"), TYPE_FILE|VAR_INITIAL,
	 _(6,"The tarfile, and an optional root path (syntax: /tar/file.tar:/"
	   "root/dir/)") );
}

string mp;

Filesystem.Tar tar;

string query_name()
{
  return query("mountpoint")+" from "+query("tarfile");
}

void start()
{
  string path = "", tf = query( "tarfile" );
  mp = query("mountpoint");
  sscanf( tf, "%s:%s", tf, path );
  tar = 0;
  if( catch(tar = Filesystem.Tar( tf )) )
  {
    report_error( "Failed to open tar-file "+tf+"!\n" );
    tar = 0;
  }
  else if( strlen( path ) )
    tar->cd( path );
}


string query_location()
{
  return mp;
}

Stat stat_file( string f, RequestID id )
{
  if(!tar) return 0;
  object s = tar->stat( f );
  if( s )
    return ({ s->mode, s->size, s->atime, s->mtime, s->ctime, s->uid, s->gid });
}

string real_file( string f, RequestID id )
{
  return 0;
}

array find_dir( string f, RequestID id )
{
  if(!tar) return 0;
  return tar->get_dir( f );
}

mixed find_file( string f, RequestID id )
{
  if(!tar) return 0;
  object s = tar->stat( f );
  if( !s ) return 0;
  if( s->isdir() ) return -1;
  return StringFile( tar->open( f, "r" )->read(), 
		     stat_file( f, id ));
}
