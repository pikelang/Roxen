#include <config.h>

string get_id(string from)
{
  catch
  {
    Stdio.File f = open(from,"r");
    string id;
    id = f->read(800);
    if(sscanf(id, "%*s$"+"Id: %*s,v %s ", id) == 3)
      return " (version "+id+")";
  };
  return "";
}

RoxenModule find_module( string foo )
{
  string mod;
  Configuration cfg;

  if( !foo || !strlen(foo))
    return 0;
  if( foo[0] == '/' ) foo = foo[1..];
  sscanf( foo, "%[^/]/%s", foo, mod );

  cfg = roxen->find_configuration( foo );

  if( !mod  || !cfg )
    return cfg;

  return cfg->find_module( replace( mod, "!", "#" ) );
}
string program_name_version( program what )
{
  string file = roxen.filename( what );
  string ofile;
  string name = file, warning="";
  Stat fs;
  mapping ofs;

  catch
  {
    if( file )
      ofile = master()->make_ofilename( master()->program_name( what ) );
  };
  array q = connect_to_my_mysql( 1, "local" )
        ->query( "select mtime from precompiled_files where id=%s", ofile );
  if( !sizeof( q ) )
    ofs = 0;
  else
    ofs = ([ "mtime":(int)q[0]->mtime ]);

  if( !(fs = file_stat( file )) )
    warning="<i>Source file gone!</i>";
  else if( ofs  )
  {
    if( ofs->mtime < fs->mtime  )
      warning = "(<i>Precompiled file out of date</i>)";
  } else
    warning = "(<i>No precompiled file available</i>)";

  if( (fs && (fs->mtime > master()->loaded_at( what ) )) )
    warning = "(<i>Needs reloading</i>)";
  return name+" "+get_id( file )+" "+warning;
}

string program_info( RoxenModule m )
{
  if( m->get_program_info )
    return m->get_program_info( );
  return "";
}

string rec_print_tree( array q )
{
  string res ="";
  for( int i = 0; i<sizeof( q ); i++ )
    if( programp( q[i] ) )
      res += ("<dt>"+program_name_version( q[i] ) + "</dt><dd>" +
              program_info( q[i] ) + "</dd>");
    else
      res += "<dl> "+rec_print_tree( q[i] )+"</dl>";
  return res;
}

string inherit_tree( RoxenModule m )
{
  catch{ // won't work for programs in other programs.
    if( m->get_inherit_tree )
      return m->get_inherit_tree( );
    return rec_print_tree( Program.inherit_tree( object_program(m) ) );
  };
  return "";
}
