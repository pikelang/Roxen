inherit "../inheritinfo.pike";

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

string find_module_doc( string cn, string mn, object id )
{
  object c = roxen.find_configuration( cn );

  if(!c)
    return "";

  object m = c->find_module( replace(mn,"!","#") );

  if(!m)
    return "";

  return replace( "<p><b><font size=+2>"
                  + translate(m->register_module()[1]) + "</font></b><br>"
                  + translate(m->info()) + "<p>"
                  + translate(m->status()||"") +"<p>"+
                  ( id->misc->config_settings->query( "devel_mode" ) ?
                    "<hr noshade size=1><h2>Developer information</h2>"+
                    translate(m->file_name_and_stuff())
                    + "<dl>"+
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
