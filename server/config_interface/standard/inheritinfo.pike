inherit "roxenlib";


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
  string color = "black";
  array(int) ofs, fs;

  catch 
  {
    if( file )
      ofile = master()->make_ofilename( master()->program_name( what ) );
  };
  if(!ofile)
    ofile = "No .o file!";
  if( !(fs = file_stat( file )) )
  {
    color = "red";
    warning="<blink>Source file gone!</blink>";
  }
  else if( (ofs = file_stat( ofile )) && ofs[ST_SIZE] )
  {
    color = "darkgreen";
    if( ofs[ ST_MTIME ] < fs[ ST_MTIME ] )
    {
      color = "red";
      warning = "(<i>Precompiled file out of date</i>)";
    }
  } else
    warning = "(<i>No precompiled file available</i>)";

  if( fs[ ST_MTIME ] > master()->loaded_at( what ) )
  {
    color = "red";
    warning = "(<i>Needs reloading</i>)";
  }
  return "<font color="+color+">"+name+" "+get_id( file )+"</font> "+warning;
}

string program_info( program what )
{
  return "";
}

string rec_print_tree( array q )
{
  string res ="";
  for( int i = 0; i<sizeof( q ); i++ )
    if( programp( q[i] ) )
      res += ("<dt>"+program_name_version( q[i] ) + "<dd>" +
              program_info( q[i] ));
    else
      res += "<dl> "+rec_print_tree( q[i] )+"</dl>";
  return res;
}
