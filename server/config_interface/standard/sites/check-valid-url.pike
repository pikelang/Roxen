
// return <false> if the url _is_ valid 
mixed parse( RequestID id )
{
  array(string) path = ((id->misc->path_info||"")/"/")-({""});

  if(!sizeof(path)) 
    return Roxen.http_string_answer("<redirect to=''/><true/>");

  Configuration conf = roxen->find_configuration( path[0] );
  
  if(!conf) // /site.html/<site>/[<module>/] -> /
    if( search( path[0], "%20" ) != -1 )
      return Roxen.http_string_answer("<redirect to='"+
                                ("../"*sizeof(path))+
                                http_decode_string( path[0] )+"'/><true/>");
    else
      return Roxen.http_string_answer("<redirect to='../"+
                                ("../"*sizeof(path))+"'/><true/>");
  
  if( sizeof( path ) > 1 && path[1] != "settings" )
    // /site.html/<site>/[<module>/] -> /
    if(!conf->find_module( replace( path[1], "!", "#" ) ) )
      return Roxen.http_string_answer("<redirect to='../'/><true/>");

  return Roxen.http_string_answer("<false/>");
}
