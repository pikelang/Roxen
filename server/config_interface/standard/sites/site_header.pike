string module_global_page( RequestID id, Configuration conf )
{
  switch( id->variables->action )
  {
   default:
     return "";
   case "add_module":
     return "";
   case "delete_module":
     return "";
  }
}

string module_page( RequestID id, string conf, string module )
{
  /* return tabs for module ... */
  return replace( #string "module_variables.html", 
                 ({"¤_url¤","¤_config¤", "¤module¤" }), 
                 ({ "", conf, module }) );
}


string parse( RequestID id )
{
  array path = ((id->misc->path_info||"")/"/")-({""});
  
  if( !sizeof( path )  )
    return "Hm?";
  
  object conf = roxen->find_configuration( path[0] );
  id->misc->current_configuration = conf;

  if( sizeof( path ) == 1 )
  {
    /* Global information for the configuration */
  } else {
    switch( path[ 1 ] )
    {
     case "settings":
       return replace( #string "module_variables.html", 
       ({"¤_url¤","¤_config¤", "module=\"¤module¤\"", "module-variables" }), 
       ({ "", path[0], "", "config-variables" }) );
       break;

     case "modules":
       if( sizeof( path ) == 2 )
         return module_global_page( id, path[0] );
       else
         return module_page( id, path[0], path[2] );
    }
  }
}
