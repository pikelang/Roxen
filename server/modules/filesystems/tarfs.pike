inherit "module";

constant cvs_version= "$Id: tarfs.pike,v 1.1 2000/09/13 14:15:19 per Exp $";

// The Filesystem.Tar module is not threadsafe.
constant thread_safe=0;

#include <module.h>

constant module_type = MODULE_LOCATION;
constant module_name = "Tarfile system";
constant module_doc =
("This is a file system module that makes it possible to mount a "
 "directory structure from a tar-file directly on the site. gzip compressed "
 "tar-files are not supported");
constant module_unique = 0;

void create()
{
  defvar( "mountpoint", "/standard/docs/", 
          "Mount point", TYPE_LOCATION|VAR_INITIAL,
          "Where the module will be mounted in the site's virtual file "
          "system." );

  defvar("tarfile", "docs.tar", "Tar file and root path", TYPE_FILE|VAR_INITIAL,
	 "The tarfile, and an optional root path (syntax: /tar/file.tar:/"
         "root/dir/)" );
}

string mp, error_msg;
Filesystem.Tar tar;

void start()
{
  string path = "", tf = query( "tarfile" );
  mp = query("mountpoint");
  sscanf( tf, "%s:%s", tf, path );
  tar = 0;
  if( catch(tar = Filesystem.Tar( tf )) )
  {
    report_error( "Failed to open tar-file "+tf+"!" );
    tar = 0;
  }
  else if( strlen( path ) )
    tar->cd( path );
}


string query_location()
{
  return mp;
}

array|Stat stat_file( string f, RequestID id )
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
  return id->conf->StringFile( tar->open( f, "r" )->read(), 
                               stat_file( f, id ));
}
