#include <roxen.h>

//<locale-token project="roxen_config">LOCALE</locale-token>
#define LOCALE(X,Y)	_STR_LOCALE("roxen_config",X,Y)


string module_global_page( RequestID id, Configuration conf )
{
  return "";
}

string module_page( RequestID id, string conf, string module )
{
  return 
#"<emit source='module-variables-sections'
  configuration='"+conf+#"'
  module='"+module+#"'>
   <tab ::='&_.first; &_.last; &_.selected;'
        href='?section=&_.section;'>&_.sectionname;</tab>
</emit>";
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
  switch( sizeof(path)==1?"settings":path[ 1 ] )
  {
   case "settings":
     return 
#"<emit source='config-variables-sections' add-status=1
  configuration='"+path[0]+#"'>
   <tab ::='&_.first; &_.last; &_.selected;'
        href='?section=&_.section;'>&_.sectionname;</tab>
</emit>";
     break;

   default:
     return module_page( id, path[0], path[1] );
  }
}
