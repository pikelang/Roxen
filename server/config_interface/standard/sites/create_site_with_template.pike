inherit "roxenlib";
#include <config_interface.h>

constant base = #"
<use file='/standard/template'>
<tmpl>
<topmenu base='../' selected=sites>
<content><cv-split><subtablist><st-page>
 <input type=hidden name=name value='&form.name;'>
 <input type=hidden name=site_template value='&form.site_template;'>
 %s
</st-page></subtablist></cv-split></content></tmpl>
";

string decode_site_name( string what )
{
  if( (int)what ) return (string)((array(int))(what/","-({""})));
  return what;
}

string encode_site_name( string what )
{
  return map( (array(int))what, 
              lambda( int i ) {
                return ((string)i)+",";
              } ) * "";
}

mixed parse( RequestID id )
{
  if( !config_perm( "Create Site" ) )
    error("No permission, dude!\n"); // This should not happen, really.
  if( !id->variables->name )
    error("No name for the site!\n"); // This should not happen either.


  id->variables->name = decode_site_name( id->variables->name );

  foreach( glob( SITE_TEMPLATES "*.x",
                 indices(id->variables) ), string t )
    id->variables->site_template = t-".x";

  if( id->variables->site_template &&
      search(id->variables->site_template, "site_templates")!=-1 )
  {
    object c = roxen.find_configuration( id->variables->name );
    if( !c ) c = roxen.enable_configuration( id->variables->name );
    id->misc->new_configuration = c;
    object b = ((program)id->variables->site_template)();
    string q = b->parse( id );
    if(!stringp( q ) ) q = "<done/>";

    if( lower_case(q-" ") == "<done/>" )
    {
      if( arrayp(id->misc->modules_to_add) &&
          sizeof(id->misc->modules_to_add) )
      {
        q = ("add_module.pike?encoded=1&config="+
             encode_site_name(id->variables->name));
        foreach( id->misc->modules_to_add, string mod )
          q += "&module_to_add="+http_encode_string(mod);
	if (id->misc->module_initial_vars) {
	  q += "&mod_init_vars=1";
	  foreach (id->misc->module_initial_vars || ({}), string var)
	    q += "&init_var=" + http_encode_string (replace (var, "#", "!"));
	}
        call_out( c->save, 1, 1 );
        return http_redirect( q, id );
      }
      else
      {
        call_out( c->save, 1, 1 );
        return http_redirect("site.html/"+
                             http_encode_string(id->variables->name)+"/",id);
      }
    }
    return sprintf(base,q);
  }

  object e = roxenloader.ErrorContainer( );
  master()->set_inhibit_compile_errors( e );
  string res = "";
  array sts = ({});
  foreach( glob( "*.pike", get_dir( SITE_TEMPLATES )), string st )
  {
    st = SITE_TEMPLATES+st;
    catch
    {
      object q = ((program)st)();
      if( q->site_template )
      {
        string name, doc;
        if( q[ "name_"+id->misc->cf_locale ] )
          name = q[ "name_"+id->misc->cf_locale ];
        else
          name = q->name;

        if( q[ "doc_"+id->misc->cf_locale ] )
          doc = q[ "doc_"+id->misc->cf_locale ];
        else
          doc = q->doc;

        sts += ({({ name,
                    "<cset variable='var.url'>"
                    "<gbutton-url width=400 "
                    "             icon_src=/internal-roxen-next "
                    "             align_icon=right>"
                    + html_encode_string(name) +
                    "</gbutton-url></cset>"
                    "<input border=0 type=image src='&var.url;' name='"+st+"'>\n"
                    "<blockquote>"+doc+"</blockquote>" })});
      }
    };
  }

  sort( sts );
  foreach( sts, array q ) res += q[1]+"\n\n\n";

  if( strlen( e->get() ) )
    res += ("Compile errors:<pre>"+
            html_encode_string(e->get())+
            "</pre>");
  master()->set_inhibit_compile_errors( 0 );
  return sprintf(base,res);
}
