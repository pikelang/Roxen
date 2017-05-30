// This is a roxen module. Copyright © 1996 - 2009, Roxen IS.

inherit "module";

constant cvs_version= "$Id$";

#include <module.h>
#include <roxen.h>
#include <stat.h>

constant thread_safe=1;

//<locale-token project="mod_sqlfs">_</locale-token>
#define _(X,Y)	_DEF_LOCALE("mod_sqlfs",X,Y)
// end of the locale related stuff


constant module_type = MODULE_LOCATION;
constant module_unique = 0;

LocaleString module_name = _(57,"File systems: SQL File system");
LocaleString module_doc = _(58,"Access files stored in a SQL database");

string table, charset, path_encoding;
int disabled;

void create()
{
  defvar("location", "/", _(15,"Mount point"),
	 TYPE_LOCATION|VAR_INITIAL|VAR_NO_DEFAULT,
	 _(16,"Where the module will be mounted in the site's virtual "
	   "file system."));

  defvar("db", Variable.DatabaseChoice( "docs", 0,
				      _(59,"Filesystem database"),
				      _(60,"The database to use")) )
    ->set_configuration_pointer( my_configuration );
  
  defvar("table", Variable.TableChoice( "docs", 0,
				 _(61,"Filesystem table"),
				 _(62,"The table that contains the files."
				  " The table should contain at least the "
				  "columns 'name' and 'contents'. Optionally "
				  "you can also have the fields 'mtime', "
				   "'uid' and 'gid'."),
					 getvar("db") ) );

  defvar("charset", "iso-8859-1", _(39,"File contents charset"),
	 TYPE_STRING,
	 _(40,"The charset of the contents of the files on this file "
	   "system. This variable makes it possible for Roxen to use "
	   "any text file, no matter what charset it is written in. If"
	   " necessary, Roxen will convert the file to Unicode before "
	   "processing the file."));

  defvar("path_encoding", "iso-8859-1", _(41,"Filename charset"),
	 TYPE_STRING,
	 _(42,"The charset of the file names of the files on this file "
	   "system. Unlike the <i>File contents charset</i> variable, "
	   "this might not work for all charsets simply because not "
	   "all browsers support anything except ISO-8859-1 "
	   "in URLs."));
}

void start( )
{
  set_my_db( query( "db" ) );
  table = query("table");
  charset = query("charset");
  path_encoding = query("path_encoding");
  Sql.Sql sql = get_my_sql();
  if (!sql) {
    report_error ("Database %O does not exist - module disabled.\n", query ("db"));
    disabled = 1;
  }
  else if (catch (sql_query ("SELECT name FROM " + table + " LIMIT 1"))) {
    report_error ("The table %O in database %O does not exist "
		  "or got no \"name\" column "
		  "- module disabled.\n", table, query ("db"));
    disabled = 1;
  }
  else
    disabled = 0;
}
  


private mapping last_file;
#ifdef THREADS
private Thread.Mutex lfm = Thread.Mutex();
#endif

protected string decode_path( string p )
{
  if( path_encoding != "iso-8859-1" )
    p = Charset.encoder( path_encoding )->feed( p )->drain();

  if( String.width( p ) != 8 )
    p = string_to_utf8( p );

  return p;
}

protected array low_stat_file( string f, RequestID id )
{
  if (disabled)
    return 0;

  if( f == "/" )
    return dir_stat;
  if( has_value( f, "%" ) )
    return 0;
#ifdef THREADS
  Thread.MutexKey k = lfm->lock();
#endif
  if( !last_file || last_file->name != f )
  {
    // FIXME: It's not very efficient to suck in the whole content
    // here if we only want a stat. :P /mast
    array r = sql_query( "SELECT * FROM "+table+" WHERE name=%s", f );
    if( sizeof( r ) )
    {
      last_file = r[0];
      if( charset != "iso-8859-1" )
      {
	if( id->set_output_charset )
	  id->set_output_charset( charset, 2 );
        id->misc->input_charset = charset;
      }
    }
  }
  if( last_file && last_file->name == f )
    return
      ({
	({
	  0777,
	  strlen(last_file->contents||""),
	  time(),
	  ((int)last_file->mtime)+1,
	  ((int)last_file->mtime)+1,
	  (int)last_file->uid,
	  (int)last_file->gid,
	}),
	last_file
      });

  if( f[-1] != '/' ) f+= "/";
  if( sizeof( sql_query( "SELECT name FROM  "+
			 table+" WHERE name LIKE %s  LIMIT 1",
			 f+"%" ) ) )
    return ({ dir_stat, 0 });
  return ({ 0, 0 });
}

constant dir_stat = ({	0777|S_IFDIR, -1, 10, 10, 10, 0, 0 });

//  --- MODULE_LOCATION API

Stat stat_file( string f, RequestID id )
{
  array s = low_stat_file( decode_path( "/"+f ), id );
  return s && s[0];
}

int|object find_file(  string f, RequestID id )
{
  if (disabled)
    return 0;

  if( !strlen( f ) )
    return -1;
  f = decode_path( "/"+f );
  [array st,mapping d] = low_stat_file( f, id );
  if( !st )            return 0;
  if( st[1] == -1 )    return -1;
  id->misc->stat = st;
  return StringFile( d->contents||"" );
}

array(string) find_dir( string f, RequestID id )
{
  if (disabled)
    return 0;

  f = decode_path( "/"+f );

  if(  f[-1] != '/' )
    f += "/";

  multiset dir = (<>);

  foreach( sql_query( "SELECT name FROM "+table+" WHERE name LIKE %s",f+"%")
	   ->name, string p )
    dir[ (p[ strlen(f) .. ] / "/")[0] ] = 1;

  return (array)dir;
}
