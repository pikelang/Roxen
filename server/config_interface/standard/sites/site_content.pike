inherit "roxenlib";
inherit "../inheritinfo.pike";
inherit "../logutil.pike";
#include <module.h>

string module_global_page( RequestID id, Configuration conf )
{
  switch( id->variables->action )
  {
   default:
     return "<insert file=global_module_page.inc nocache>\n";
   case "add_module":
     return "<insert file=add_module.inc nocache>\n";
   case "delete_module":
     return "<insert file=delete_module.inc nocache>\n";
  }
}

#define translate( X ) _translate( (X), id )

string _translate( mixed what, object id )
{
  if( mappingp( what ) )
    if( what[ id->misc->cf_locale ] )
      return what[ id->misc->cf_locale ];
    else
      return what->standard;
  return what;
}

string describe_exts( object m, string func )
{
  return String.implode_nicely( m[func]() );
}

string describe_location( object m )
{
  return m->query_location();
}

string make_if( string q )
{
  return "<if "+q+"=?></if>";
}

string describe_tags( object m )
{
  return html_encode_string(String.implode_nicely( map(indices(m->query_tag_callers()),make_tag,([]))+
                            map(indices(m->query_container_callers()),
                                make_container,([]),"")+
                            map(indices(m->query_if_callers()),make_if)));
}

string describe_provides( object m )
{
  if( arrayp( m->query_provides() ) )
    return String.implode_nicely( m->query_provides() );
  return m->query_provides();
}

string describe_type( object m, int t )
{
  string res = "";

#define T(X,Y,Z)                                                        \
do                                                                      \
{                                                                       \
   if(t&X)                                                              \
     if( Y )                                                            \
       res += ("<table border=0 cellspacing=2 cellpadding=0><tr><td valign=top>|<b>" + #X + "</b>(</td>"     \
               "<td valign=top>"+Y(m,Z)+"  )</td></tr></table><br>");   \
     else                                                               \
       res += "|<b>" + #X + "</b><br>";                                 \
} while(0)

  T(MODULE_EXTENSION,      describe_exts,       "query_extensions");
  T(MODULE_LOCATION,   describe_location,                        0);
  T(MODULE_URL,                        0,                        0);
  T(MODULE_FILE_EXTENSION, describe_exts,  "query_file_extensions");
  T(MODULE_PARSER,         describe_tags,                        0);
  T(MODULE_LAST,                       0,                        0);
  T(MODULE_FIRST,                      0,                        0);
  T(MODULE_AUTH,                       0,                        0);
  T(MODULE_TYPES,                      0,                        0);
  T(MODULE_DIRECTORIES,                0,                        0);
  T(MODULE_PROXY,                      0,                        0);
  T(MODULE_LOGGER,                     0,                        0);
  T(MODULE_FILTER,                     0,                        0);
  T(MODULE_PROVIDER,   describe_provides,                        0);
  T(MODULE_PROTOCOL,                   0,                        0);
  T(MODULE_CONFIG,                     0,                        0);
  T(MODULE_SECURITY,                   0,                        0);
  T(MODULE_EXPERIMENTAL,               0,                        0);

  return res;
}

string devel_buttons( object c, string mn, object id )
{
  object mod = c->find_module( replace( mn,"!","#" ) );
  if( sizeof( glob( "*.x", indices( id->variables ) ) ) )
  {
    string a = glob( "*.x", indices( id->variables ) )[0]-".x";
    if( a == parse_rxml( "<cf-locale get=reload>",id ) )
      c->reload_module( replace(mn,"!","#" ) );
    else if( a == parse_rxml( "<cf-locale get=clear_log>",id ) )
    {
      mod->error_log = ([
        "2,Event log cleared by "+id->misc->config_user->real_name+
        " ("+id->misc->config_user->name+") from "+
        id->misc->config_settings->host:({ time() }),
      ]);
    }
  }
  return "<input type=hidden name=section value='"+id->variables->section+"'>"
         "<submit-gbutton preparse><cf-locale get=reload></submit-gbutton>"+
         (sizeof( mod->error_log ) ?
         "<submit-gbutton preparse><cf-locale get=clear_log></submit-gbutton>":
          "");
;
}

string get_eventlog( object o, RequestID id )
{
  mapping log = o->error_log;
  if(!sizeof(log)) return "";

  array report = indices(log), r2;

  last_time=0;
  r2 = map(values(log),lambda(array a){
     return id->variables->reversed?-a[-1]:a[0];
  });
  sort(r2,report);
  for(int i=0;i<sizeof(report);i++) 
     report[i] = describe_error(report[i], log[report[i]]);
  return "<h2><cf-locale get=eventlog></h2>"+(report*"");
}

string find_module_doc( string cn, string mn, object id )
{
  object c = roxen.find_configuration( cn );

  if(!c)
    return "";

  string dbuttons;
  if( id->misc->config_settings->query( "devel_mode" ) )
    dbuttons = "<h2><cf-locale get=actions></h2>"+devel_buttons( c, mn, id );
  else
    dbuttons="";

  object m = c->find_module( replace(mn,"!","#") );

  if(!m)
    return "";

  roxen.Module mi = roxen.find_module( (mn/"!")[0] );

  string eventlog = get_eventlog( m,id );
  

  return replace( "<br><b><font size=+2>"
                  + translate(m->register_module()[1]) + 
                  "</font></b><br>"
                  + translate(m->info()) + "<p>"
                  + translate(m->status()||"") +"<p>"
                  + eventlog
                  + dbuttons+"<br clear=all>"+
                  ( id->misc->config_settings->query( "devel_mode" ) ?
                    "<h2>Developer information</h2>"+
                    "<b>Identifier:</b> " + mi->sname+" <br>"
                    "<table><tr><td valign=top><b>Type:</b></td><td valign=top>"+describe_type( m,mi->type )+"</td></table><br>"+
                    translate(m->file_name_and_stuff())+ "<dl>"+
                    rec_print_tree( Program.inherit_tree( object_program(m) ) )
                    +"</dl>" : ""),
                  ({ "/image/", }), ({ "/internal-roxen-" }));
}

string module_page( RequestID id, string conf, string module )
{
  while( id->misc->orig )
    id = id->misc->orig;
  if((id->variables->section == "Information") ||
     id->variables->info_section_is_it)
    return "<blockquote>"+find_module_doc( conf, module, id )+"</blockquote>";

  return #"<formoutput quote=\"么">
    <cf-save what=Module>
 <input type=hidden name=section value=\"山ection么">
<table>
  <configif-output source=module-variables configuration=\""+
   conf+"\" section=\"山ection:quote=dtag么" module=\""+module+#"\">
    <tr><td width=20%><b>#name#</b></td><td>#form:quote=none#</td></tr>
    <tr><td colspan=2>#doc:quote=none#<p>#type_hint#</td></tr>
   </configif-output>
  </table>
    <cf-save what=Module>
</formoutput>";
}


string parse( RequestID id )
{
  array path = ((id->misc->path_info||"")/"/")-({""});
  
  if( id->variables->section )
    sscanf( id->variables->section, "%s\0", id->variables->section );

  if( !sizeof( path )  )
    return "Hm?";
  
  object conf = roxen->find_configuration( path[0] );
  id->misc->current_configuration = conf;

  if( sizeof( path ) == 1 )
  {
    switch( id->variables->config_page )
    {
     default: /* Status info */
       string res="<br><blockquote><h1>Urls</h1>";
       foreach( conf->query( "URLs" ), string url )
         res += url+"<br>";

       res +="<h1>Request status</h1>";
       res += conf->status();

       if( id->misc->config_settings->query( "devel_mode" ) )
       {
         res += "<h1>Inherit tree</h1><dl>";
         res += rec_print_tree( Program.inherit_tree( object_program(conf) ) );
         res += "</dl>";
       }

       return res+"<br>";
     case "event_log":
       return "<insert file=log.pike nocache>";
    }
    /* Global information for the configuration */
  } else {
    switch( path[ 1 ] )
    {
     case "settings":
       return   
#"<formoutput quote=\"么">
<configif-output source=config-variables configuration=\""+
path[ 0 ]+#"\" section=\"山ection:quote=dtag么"></configif-output>"+#"
<input type=hidden name=section value=\"山ection么">
<table>
   <cf-save what=Site>
  <configif-output source=config-variables configuration=\""+
path[ 0 ]+#"\" section=\"山ection:quote=dtag么">
    <tr><td width=20%><b>#name#</b></td><td>#form:quote=none#</td></tr>
    <tr><td colspan=2>#doc:quote=none#<p>#type_hint#</td></tr>
   </configif-output>
  </table>
   <cf-save what=Site>
</formoutput>";
       break;

     case "modules":
       if( sizeof( path ) == 2 )
         return module_global_page( id, path[0] );
       else
         return module_page( id, path[0], path[2] );
    }
  }
  return "";
}
