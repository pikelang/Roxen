// This is a ChiliMoon module. Copyright © 2000 - 2001, Roxen IS.


constant cvs_version = "$Id: tarfs.pike,v 1.15 2005/02/10 23:12:00 _cvs_dirix Exp $";

// The Filesystem.Tar module is not threadsafe.

#include <module.h>
inherit "module";

constant thread_safe = 0;

constant module_type = MODULE_LOCATION;
constant module_name = "File systems: Tar File";
constant  module_doc =
("This is a file system module that makes it possible to mount a "
 "directory structure from a tar-file directly on the site. gzip compressed "
 "tar-files are not supported");
constant module_unique = 0;

void create()
{
  defvar( "mountpoint", "/", 
          "Mount point", TYPE_LOCATION|VAR_INITIAL,
          "Where the module will be mounted in the site's virtual file system." );

  defvar("tarfile", "docs.tar", 
         "Tar file and root path", TYPE_FILE|VAR_INITIAL,
	 "The tarfile, and an optional root path (syntax: /tar/file.tar:/root/dir/)" );
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
  else if( sizeof( path ) )
    tar->cd( path );
}


string query_location()
{
  return mp;
}

Stat stat_file( string f, RequestID id )
{
  if(!tar) return 0;
  Stdio.Stat s = tar->stat( f );
  if( !s ) return 0;
  return s;
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

int|Stdio.FakeFile find_file( string f, RequestID id )
{
  if(!tar) return 0;
  Stdio.Stat s = tar->stat( f );
  if( !s ) return 0;
  if( s->isdir() ) return -1;
  string content = tar->open( f, "r" )->read();
  Stdio.FakeFile res = Stdio.FakeFile( content , "r" );
  return res;
}
