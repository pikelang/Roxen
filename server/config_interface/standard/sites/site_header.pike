string module_global_page( RequestID id, Configuration conf )
{
  return "";
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

  if( id->variables->section )
    sscanf( id->variables->section, "%s\0", id->variables->section );

  if( !sizeof( path )  )
    return "Hm?";

  object conf = roxen->find_configuration( path[0] );
  if( !conf->inited )
    conf->enable_all_modules();
  id->misc->current_configuration = conf;
  if(id->variables->initial)
    return "<tab first last selected>&locale.initial_variables;</tab>";
  if( sizeof( path ) == 1 )
  {
    string res="";
    string q = id->variables->config_page;

    array pages =
    ({
      ({ 0, "status", 0, 0 }),
    });

    foreach ( pages, array page )
    {
      string tpost = "";
      if( page[2] )
      {
        res += "<cf-perm perm='"+page[2]+"'>";
        tpost = "</cf-perm>"+tpost;
      }
      if( page[3] )
      {
        res += "<cf-userwants option='"+page[3]+"'>";
        tpost = "</cf-userwants>"+tpost;
      }

      if( page[0] )
        res += "<tab href='?config_page="+page[0]+"'"+
            (page == pages[0]?" first ":
             (page == pages[-1]?" last ":""))+
            ((page[0] == q)?" selected":"")+">";
      else
        res += "<tab href=''"+((page[0] == q)?" selected":"")+">";
      res += "&locale."+page[1]+";";
      res += "</tab>";
      res += tpost;
    }
    return res;
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
