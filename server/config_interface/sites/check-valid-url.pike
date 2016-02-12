#include <config_interface.h>
// return <false> if the url _is_ valid 
mixed parse( RequestID id )
{
  array(string) path = ((id->misc->path_info||"")/"/")-({""});

  if(!sizeof(path)) 
    return Roxen.http_string_answer("<redirect to='/sites/'/><true/>");

  Configuration conf = roxen->find_configuration( path[0] );

  if( conf && !conf->inited )
    conf->enable_all_modules();
  
  // error_log[0] is true for non-completely added sites.
  if(!conf || conf->error_log[0])
    // /site.html/<site>/[<mgroup>/[<module>/]] -> /
    if( search( path[0], "%20" ) != -1 )
      return Roxen.http_string_answer("<redirect to='"+
                                ("../"*sizeof(path))+
                                http_decode_string( path[0] )+"'/><true/>");
    else
      return Roxen.http_string_answer("<redirect to='../"+
                                ("../"*sizeof(path))+"'/><true/>");
  
  if( sizeof( path ) > 2 && path[2] != "settings" )
    // /site.html/<site>/[<module>/] -> /
    if(!conf->find_module( replace( path[2], "!", "#" ) ) )
      return Roxen.http_string_answer("<redirect to='../'/><true/>");

  if( conf && ( !config_perm( "Site:"+conf->name ) ) )
    return Roxen.http_string_answer("<redirect to='../'/><true/>");

  return Roxen.http_string_answer("<false/>");
}
