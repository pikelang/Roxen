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
    if(sscanf(id, "%*s$"+"Id: %[0-9a-f] $", id) == 2)
      return " (sha: "+id[..7]+")";
  };
  return "";
}

RoxenModule|Configuration find_module( string foo )
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
  [string file, int line] = roxen.filename_2 (what);
  string warning="";
  Stat fs;

  if (!file)
    return "(unknown program)";

  if( !(fs = file_stat( file )) )
    warning="(<i>Source file not found</i>)";

#ifdef ENABLE_DUMPING
  else {
    string ofile;
    catch
    {
      if( file )
	ofile = master()->make_ofilename( master()->program_name( what ) );
    };
    mapping ofs;
    if (ofile) {
      array q = connect_to_my_mysql( 1, "local" )
	->query( "select mtime from precompiled_files where id=%s", ofile );
      if( !sizeof( q ) )
	ofs = 0;
      else
	ofs = ([ "mtime":(int)q[0]->mtime ]);
    }

    if( ofs  )
    {
      if( ofs->mtime < fs->mtime  )
	warning = "(<i>Precompiled file out of date</i>)";
    } else
      warning = "(<i>No precompiled file available</i>)";
  }
#endif

  int load_time = master()->loaded_at( what );
  if( (fs && load_time && (fs->mtime > load_time)) )
    warning = "(<i>Needs reloading</i>)";
  return file + (line ? ":" + line : "") +" "+get_id( file )+" "+warning;
}

string program_info( RoxenModule m )
{
  if( m->get_program_info )
    return m->get_program_info( ) || "";
  return "";
}

string rec_print_tree( array q )
{
  string res ="";
  for( int i = 0; i<sizeof( q ); i++ )
    if( programp( q[i] ) ) {
      string desc = program_info( q[i] );
      if (desc != "") desc = "<br />\n" + desc;
      desc = program_name_version( q[i] ) + desc;
      res += "<li>" + desc + "</li>\n";
    }
    else
      res += "<ul style='padding-left: 2ex; list-style-type: disc'>" +
	rec_print_tree( q[i] ) + "</ul>\n";
  return res;
}

string inherit_tree( RoxenModule m )
{
  mixed err = catch { // won't work for programs in other programs.
    if( m->get_inherit_tree )
      return m->get_inherit_tree( );
    return "<ul style='padding-left: 2ex; list-style-type: disc'>" +
      rec_print_tree( Program.inherit_tree( object_program(m) ) ) +
      "</ul>";
  };
  report_debug("Failed to generated inherit tree:\n"
	       "%s\n",
	       describe_backtrace(err));
  return "";
}
