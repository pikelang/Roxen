
string get_id(string from)
{
  catch
  {
    object f = open(from,"r");
    string id;
    id = f->read(800);
    if(sscanf(id, "%*s$"+"Id: %*s,v %s ", id) == 3)
      return " (version "+id+")";
  };
  return "";
}

object find_module( string foo )
{
  string mod;
  object cfg;

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
  array(int) ofs, fs;

  catch
  {
    if( file )
      ofile = master()->make_ofilename( master()->program_name( what ) );
  };
  if(!ofile)
    ofile = "No .o file";
  if( !(fs = file_stat( file )) )
    warning="<blink>Source file gone!</blink>";
  else if( (ofs = file_stat( ofile )) && ofs[ST_SIZE] )
  {
    if( ofs[ ST_MTIME ] < fs[ ST_MTIME ] )
      warning = "(<i>Precompiled file out of date</i>)";
  } else
    warning = "(<i>No precompiled file available</i>)";

  if( (fs && (fs[ ST_MTIME ] > master()->loaded_at( what ) )) )
    warning = "(<i>Needs reloading</i>)";
  return name+" "+get_id( file )+" "+warning;
}

string program_info( object m )
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

string inherit_tree( object m )
{
  if( m->get_inherit_tree )
    return m->get_inherit_tree( );
  return rec_print_tree( Program.inherit_tree( object_program(m) ) );
}
