inherit "roxenlib";
#include <stat.h>


string get_id(string from)
{
  catch {
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
  string file = search(master()->programs,  what );
  string name = (file-(getcwd()+"/"));
  string color = "black";


  if( !file_stat( file ) )
    color = "red";
  else if( file_stat( file + ".o" ) )
  {
    color = "darkgreen";
    if( file_stat( file + ".o" )[ ST_MTIME ] < file_stat( file  )[ ST_MTIME ] )
      color = "red";
  }
  return "<font color="+color+">"+name+" "+get_id( file )+"</font>";
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

string parse( object id )
{
  object module = find_module( id->misc->path_info );
  if( !module ) module = roxen;
  return "<dl>"+
         rec_print_tree( Program.inherit_tree( object_program(module) ) )+
         "</dl>";
}
