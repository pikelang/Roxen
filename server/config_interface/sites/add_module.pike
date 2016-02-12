// $Id$

#include <config_interface.h>
#include <module.h>
#include <module_constants.h>
#include <roxen.h>

int no_reload()
{
  if( sizeof( already_added ) )
    return 1; // Reloading this script now would destroy state.
}

//<locale-token project="roxen_config">LOCALE</locale-token>
#define LOCALE(X,Y)	_STR_LOCALE("roxen_config",X,Y)

// Class is the name of the directory.
array(string) class_description( string d, RequestID id )
{
  string name, doc;
  while(!(< "", "/" >)[d] && !Stdio.is_file( d+"/INFO" ))
    d = dirname(d);
  if((< "", "/" >)[d])
    return ({"Local modules", "" });

  string n = Stdio.read_bytes( d+"/INFO" );
  sscanf( n, "<"+id->misc->config_locale+">%s"
          "</"+id->misc->config_locale+">", n );
  sscanf( n, "%*s<name>%s</name>", name  );
  sscanf( n, "%*s<doc>%s</doc>", doc  );
  if( search(n, "<noshow/>" ) != -1 )
    return ({ "", "" });

  if(!name)
    return ({"Local modules", "" });

  if(!doc)
    doc ="";

  return ({ name, doc });
}

array(string) module_class( object m, RequestID id )
{
  return class_description( m->filename, id );
}

object module_nomore(string name, object modinfo, object conf)
{
  mapping module;
  object o;

  if(!modinfo)
    return 0;

  if(!modinfo->multiple_copies && (module = conf->modules[name]) &&
     sizeof(module->copies) )
    return modinfo;

  if(((modinfo->type & MODULE_DIRECTORIES) && (o=conf->dir_module))
     || ((modinfo->type & MODULE_AUTH)  && (o=conf->auth_module))
     || ((modinfo->type & MODULE_TYPES) && (o=conf->types_module)))
    return roxen.find_module( conf->otomod[o] );
}

// To redirect to when done with module addition
string site_url( RequestID id, string site )
{
  return "/sites/site.html/"+site+"/";
}

string get_method(RequestID id)
{
  //  There really is no difference between Normal and Fast
  string method =
    id->variables->method ||
    replace(config_setting( "addmodulemethod" ), " ", "_");
  if (has_value(method, "\0"))
    method = (method / "\0")[0];
  if (method == "fast")
    method = "normal";
  id->variables->method = method;
  return method;
}

string page_base( RequestID id, string content, int|void noform,
		  int|void show_search_form)
{
  string method = get_method(id);

  string search_form =
    "<script language='javascript' src='find_module.js'></script>"
    "<script language='javascript'>"
    "  query_config = '&form.config;';\n"
    "  query_method = '" + method + "';\n"
    "</script>"
    "<table cellspacing='2' cellpadding='0' border='0'>"
    "<tr><td>Find:&nbsp;</td>"
    "<td>"
    "<form style='margin: 0' onsubmit='return false'>"
    "<roxen-wizard-id-variable />"
    "<input type='search' size='30' name='mod_query' id='mod_query' "
    "       onkeydown='return query_update_results(event);'"
    "       onkeypress='return query_update_results(event);'>"
    "</form>"
    "</td>"
    "<td><img src='/internal-roxen-spinner-white'"
    "         id='mod_spinner' style='visibility: hidden'></td>"
    "</tr>"
    "</table>";

  return sprintf( "<use file='/template' />"
                  "<tmpl title=' %s'%s>"
                  "<topmenu base='/' selected='sites'/>"
                  "<content><cv-split>"
                  "<subtablist width='100%%'>"
                  "<st-tabs></st-tabs>"
                  "<st-page>"
		  "<h2>Site: '&form.config;'</h2>"
                  "<if not='1' variable='form.initial'>"
		  "<table width='100%%' border='0' cellspacing='4' "
		  "       cellpadding='0'>"
		  "<tr><td nowrap='nowrap'>%s:</td><td>"
		  "<form action='' style='margin: 0'>"
		  "<input type='hidden' name='config' value='&form.config;'>"
		  "<default variable='form.method' value='%s'>"
		  "<select name='method' onchange='submit()'>"
		  "<option value='normal'>%s</option>"
		  //  "<option value='fast'>%s</option>"
		  "<option value='faster'>%s</option>"
		  "<option value='compact'>%s</option>"
		  "<option value='really_compact'>%s</option>"
		  "</select>"
		  "</default>"
		  "</form>"
		  "</td>"
		  "<td>&nbsp;&nbsp;</td>"
		  "<td width='100%%' nowrap='nowrap'>%s</td>"  // search form
		  "<td>&nbsp;&nbsp;</td>"
		  "<td align='right'>"
                  "<gbutton href='add_module.pike?config=&form.config:http;"
                  "&amp;reload_module_list=yes&amp;method=%s&amp;&usr.set-wiz-id;' "
		  "> %s </gbutton>"
		  "</td><td>"
                  "<gbutton href='site.html/&form.config;/' "
		  "> %s </gbutton>"
		  "</td></tr></table>"
                  "<p>\n</if>%s\n</p>\n"
                  "</st-page></subtablist></td></tr></table>"
                  "</cv-split></content></tmpl>", 
		  LOCALE(251,"Add Module"),
		  noform?" noform='noform'":"",
		  LOCALE(421, "List Type"),
		  method,
		  LOCALE(280, "Normal"),
		  //  LOCALE(0, "Fast"),
		  LOCALE(284, "Faster"),
		  LOCALE(286, "Compact"),
		  LOCALE(531, "Really Compact"),
		  (show_search_form && search_form) || "",
		  method,
                  LOCALE(272,"Reload Module List"),
		  LOCALE(202,"Cancel"),
		  content);
}



string module_name_from_file( string file )
{
  string data, name;

  catch(data = Stdio.read_bytes( file ));
  
  if( data
      && sscanf( data, "%*smodule_name%*s=%[^;];", name )
      && sscanf( name, "%*[^\"]\"%s\"", name ) )
    return Roxen.html_encode_string(name);
  return Roxen.html_encode_string(((file/"/")[-1]/".")[0]);
}

string pafeaw( string errors, string warnings, array(ModuleInfo) locked_modules)
// Parse And Format Errors And Warnings (and locked modules).
// Your ordinary prettyprinting function.
{
  mapping by_module = ([]);
  int cnt = 0;
  foreach( (errors+warnings)/"\n", string e )
  {
    string file;
    int row;
    string type, error;
    sscanf( e, "%s:%d%s", file, row, error );
    if( error )
    {
      sscanf( error, "%*[ \t]%s", error );
      sscanf( error, "%s: %s", type, error );
      if( by_module[ file ] )
        by_module[ file ] += ({ ({ row*10000 + cnt++, row, type, error }) });
      else
        by_module[ file ] = ({ ({ row*10000 + cnt++, row, type, error }) });
    }
  }


  string da_string = "";

  int header_added;
  foreach( sort((array)by_module), [string module, array errors] )
  {
    array res = ({ });
    int remove_suspicious = 0;
    sort( errors );
    foreach( errors, array e )
    { 
      if( e[2]  == "Error" )
      {
        remove_suspicious = 1;
        switch( e[3] )
        {
         case "Must return a value for a non-void function.":
         case "Class definition failed.":
         case "Illegal program pointer.":
         case "Illegal program identifier":
           continue;
        }
      }
      res += ({ e });
    }
    if( sizeof( res ) )
    {
      string he( string what )
      {
        if( what == "Error" )
          return "<font color='&usr.warncolor;'>"+what+"</font>";
        return what;
      };

      string hc( string what )
      {
        return what;
      };

      string trim_name( string what )
      {
        array q = (what / "/");
        return q[sizeof(q)-2..]*"/";
      };

#define RELOAD(X) sprintf("<gbutton "                                         \
			  "img-align='middle' "                               \
                          "href='add_module.pike?config=&form.config:http;"   \
                          "&amp;method=&form.method;"			      \
                          "&amp;random=%d&amp;only=%s"			      \
			  "&amp;reload_module_list=yes"			      \
			  "&amp;&usr.set-wiz-id;"			      \
			  "#errors_and_warnings'> %s </gbutton>",   	      \
                          random(4711111),                                    \
                          (X),                                                \
                          LOCALE(253, "Reload"))

      if( !header_added++ )
        da_string += 
                  "<p><a name='errors_and_warnings'></a><br />"
                  "<font size='+2'><b><font color='&usr.warncolor;'>"
                  "Compile errors and warnings</font></b><br />"
                  "<table width=100% cellpadding='3' cellspacing='0' border='0'>";

      da_string += "<tr><td></td>"
                "<td colspan='3' bgcolor='&usr.content-titlebg;'>"
                + "<b><font color='&usr.content-titlefg;' size='+1'>"
                + module_name_from_file(module)+"</font></b></td>"
                + "<td align='right' bgcolor='&usr.content-titlebg;'>"
                "<font color='&usr.content-titlefg;' size='+1'>"
                + trim_name(module)
                + "</font>&nbsp;"+RELOAD(module)+"</td><td></td></tr>";

      foreach( res, array e )
        da_string += 
                  "<tr valign='top'><td></td><td><img src='/internal-roxen-unit' width='30' height='1' alt='' />"
                  "</td><td align='right'>"
                  "<tt>"+e[1]+":</tt></td><td align='right'><tt>"+
                  he(e[2])+":</tt></td><td><tt>"+hc(e[3])+"</tt></td></tr>\n";
      da_string += "<tr valign='top'><td colspan='5'>&nbsp;</td><td></td></tr>\n";

    }
  }
  if( strlen( da_string ) )
    da_string += "</table>";
// "<pre>"+Roxen.html_encode_string( sprintf( "%O", by_module ) )+"</pre>";
  
  return da_string + format_locked_modules(locked_modules);
}

string format_locked_modules(array(ModuleInfo) locked_modules)
{
  if(!sizeof(locked_modules))
    return "";
  
  return
    "<font size='+1'>Locked modules</font><br />\n"
    "These modules are locked and can not be enabled because they are "
    "not part of the license key for this configuration.<br />\n"
    "<blockquote><font color='darkred'>"+
    (((array(string))locked_modules->get_name())*"<br />\n")+"</font></blockquote>";
}

array(string) get_module_list( function describe_module,
                               function class_visible,
                               RequestID id )
{
  object conf = roxen.find_configuration( id->variables->config );
  object ec = roxenloader.LowErrorContainer();
  int do_reload;
  master()->set_inhibit_compile_errors( ec );

  if( id->variables->reload_module_list )
    roxen->clear_all_modules_cache();

  array(ModuleInfo) mods;
  roxenloader.push_compile_error_handler( ec );
  mods = roxen->all_modules();
  roxenloader.pop_compile_error_handler();

  foreach( mods, ModuleInfo m )
    if( module_nomore( m->sname, m, conf ) )
      mods -= ({ m });

  string res = "";
  string doubles="", already="";
  array w = map(mods, module_class, id);

  mapping classes = ([]);
  sort(w,mods);
  for(int i=0; i<sizeof(w); i++)
  {
    mixed r = w[i];
    if(!classes[r[0]])
      classes[r[0]] = ([ "doc":r[1], "modules":({}) ]);
    classes[r[0]]->modules += ({ mods[i] });
  }

  multiset(ModuleInfo) search_modules;
  if (string mod_query = id->variables->mod_query) {
    array(string) mod_query_words = (lower_case(mod_query) / " ") - ({ "" });
    search_modules = (< >);
    foreach(mods, ModuleInfo m) {
      string compare =
	lower_case(((string) m->get_name() || "") + "\0" +
		   m->sname + "\0" +
		   m->filename + "\0" +
		   Roxen.html_decode_string((string) m->get_description() ||
					    LOCALE(1023, "Undocumented")));
    search_miss:
      {
	foreach(mod_query_words, string w)
	  if (!has_value(compare, w))
	    break search_miss;
	search_modules[m] = 1;
      }
    }
  }

  License.Key license_key = conf->getvar("license")->get_key();
  array(RoxenModule) locked_modules = ({});
  
  foreach( sort(indices(classes)), string c )
  {
    mixed r;
    if( c == "" )
      continue;
    if( (r = class_visible( c, classes[c]->doc, sizeof(classes[c]->modules), id )) &&
	r[0] &&
	(!search_modules ||
	 sizeof(classes[c]->modules & indices(search_modules))))
    {
      res += r[1];
      array m = classes[c]->modules;
      array q = m->get_name();
      sort( q, m );
      foreach(m, object q)
      {
        if( q->get_description() == "Undocumented" &&
            q->type == 0 )
          continue;
	if (search_modules && !search_modules[q])
	  continue;
        object b = module_nomore(q->sname, q, conf);
	if( !b && q->locked &&
	    (!license_key || !q->unlocked(license_key, conf)) )
	{
	  locked_modules += ({ q });
	  continue;
	}
        res += describe_module( q, b );
      }
    } else {
      if (!search_modules)
	res += r[1];
    }
  }
  master()->set_inhibit_compile_errors( 0 );
  return ({ res, pafeaw( ec->get(), ec->get_warnings(), locked_modules) });
}

string module_image( int type )
{
  return "";
}

string strip_leading( LocaleString what )
{
  if( !what ) return 0;
  sscanf( (string)what, "%*s:%*[ \t]%s", what );
  return what;
}


function describe_module_normal( int image )
{
  return lambda( object module, object block)
  {
    if(!block)
    {
      return sprintf(
	#"
  <tr>
   <td colspan='2'>
     <table width='100%%'>
      <tr>
       <td><font size='+2'>%s</font></td>
       <td align='right'><span class='dimtext'>(%s)</span> %s</td>
      </tr>
     </table>
     </td>
   </tr>
   <tr>
     <td valign='top'>
       <form method='post' action='add_module.pike' 
	     style='margin: 0 10px 0 0'>
         <roxen-automatic-charset-variable/>
         <roxen-wizard-id-variable />
         <input type='hidden' name='module_to_add' value='%s'>
         <input type='hidden' name='config' value='&form.config;'>
         <submit-gbutton preparse='1'>%s</submit-gbutton>
       </form>
     </td>
     <td valign='top'>
       %s
       <p class='dimtext'>%s</p>
    </td>
  </tr>
",
	//Roxen.html_encode_string(strip_leading(module->get_name())),
	Roxen.html_encode_string(module->get_name()),
	Roxen.html_encode_string (module->sname),
	(image?module_image(module->type):""),
	module->sname,
	LOCALE(251, "Add Module"),
	module->get_description() || LOCALE(1023, "Undocumented"),
	LOCALE(266, "Will be loaded from: ")+module->filename
);
    } else {
      if( block == module )
        return "";
      return "";
    }
  };
}

array(int|string) class_visible_normal( string c, string d, int size,
					RequestID id )
{
  int x;
  string method = get_method(id);
  string header = ("<tr><td colspan='2'><table width='100%' "
                   "cellspacing='0' border='0' cellpadding='3' "
                   "bgcolor='&usr.content-titlebg;'><tr><td valign='top'>");

  if (id->variables->mod_query) {
    x = 1;
  } else if( id->variables->unfolded == c) {
    header+=("<a name='"+Roxen.html_encode_string(c)+
	     "'></a><gbutton hspace='5' vspace='5' "
	     "href='add_module.pike?config=&form.config;"
	     "&amp;method=" + method + "&amp;&usr.set-wiz-id;#"+
	     Roxen.http_encode_url(c)+"' > "+
	     LOCALE(168, "Hide")+" </gbutton>");
    x=1;
  } else {
    header+=("<a name='"+Roxen.html_encode_string(c)+
	     "'></a><gbutton hspace='5' vspace='5' "
	     "href='add_module.pike?config=&form.config;"
	     "&amp;method=" + method +
	     "&amp;unfolded="+Roxen.http_encode_url(c)+
	     "&amp;&usr.set-wiz-id;#"+Roxen.http_encode_url(c)+"' > "+
	     LOCALE(267, "View")+" </gbutton>");
  }

  header+=("</td><td width='100%'>"
	   "<font color='&usr.content-titlefg;' size='+2'>"+c+"</font>"
	   "<br />"+d+"</td></tr></table></td></tr>\n");

  return ({ x, header });
}


string page_normal_low(RequestID id, int|void noimage)
{
  string desc, err;
  [desc,err] = get_module_list( describe_module_normal(!noimage),
                                class_visible_normal, id );
  return
    "<table cellspacing='3' cellpadding='0' border='0' width='100%'>" +
    desc +
    "</table>" +
    err;
}

string page_normal_search(RequestID id, int|void noimage)
{
  return
    "<use file='/template-insert' />\n"
    "<tmpl>" +
    page_normal_low(id, noimage) +
    "</tmpl>";
}

string page_normal( RequestID id, int|void noimage )
{
  string content =
    "<div id='mod_results' style='display: none'>"
    "</div>"
    "<div id='mod_default'>" +
    page_normal_low(id, noimage) +
    "</div>";
  return page_base( id, content, 1, 1);
}

string page_fast( RequestID id )
{
  return page_normal( id, 1 );
}

string describe_module_faster( object module, object block)
{
  if(!block)
  {
return sprintf(
   #"
    <tr><td colspan='2'><table width='100%%'>
        <td><font size='+2'>%s</font></td>
        <td align='right'><span class='dimtext'>(%s)</span> %s</td></table>
        </td></tr>
    <tr><td valign='top'><select multiple='multiple' size='1'
                                 name='module_to_add'>
                       <option value='%s'>%s</option></select>
        </td><td valign='top'>%s<p class='dimtext'>%s</p></td>
    </tr>
",
   //Roxen.html_encode_string(strip_leading(module->get_name())),
   Roxen.html_encode_string(module->get_name()),
   Roxen.html_encode_string (module->sname),
   module_image(module->type),
   module->sname,
   //Roxen.html_encode_string(strip_leading(module->get_name())),
   Roxen.html_encode_string(module->get_name()),
   module->get_description() || LOCALE(1023, "Undocumented"),
   LOCALE(266, "Will be loaded from: ")+module->filename
  );
  } else {
    if( block == module )
      return "";
    return "";
  }
}

array(int|string) class_visible_faster( string c, string d, int size,
					RequestID id )
{
  int x;
  string method = get_method(id);
  string header = ("<tr><td colspan='2'><table width='100%' cellspacing='0' "
                   "border='0' cellpadding='3' bgcolor='&usr.content-titlebg;'>"
                   "<tr><td nowrap='nowrap' valign='top'>");

  if (id->variables->mod_query) {
    header+=("<gbutton hspace='5' vspace='5' dim='1'> "+LOCALE(267, "View")+
	     " </gbutton><br>"
	     "<submit-gbutton hspace='5' vspace='2'> "+LOCALE(200, "Add Modules")+
	     " </submit-gbutton>");
    x = 1;
  } else if( id->variables->unfolded == c ) {
    header+=("<a name='"+Roxen.html_encode_string(c)+
	     "'></a><gbutton hspace='5' vspace='5' dim='1'> "+LOCALE(267, "View")+
	     " </gbutton><br>"
	     "<submit-gbutton hspace='5' vspace='2'> "+LOCALE(200, "Add Modules")+
	     " </submit-gbutton>");
    x=1;
  }
  else
    header+=("<a name='"+Roxen.html_encode_string(c)+
	     "'></a><gbutton hspace='5' vspace='5' "
	     "href='add_module.pike?config=&form.config;"
	     "&amp;method=" + method +
	     "&amp;unfolded="+Roxen.http_encode_url(c)+
	     "&amp;&usr.set-wiz-id;#"+Roxen.http_encode_url(c)+"' > "+
	     LOCALE(267, "View")+" </gbutton>");

  header+=("</td><td width='100%'>"
	   "<font color='&usr.content-titlefg;' size='+2'>"+c+"</font>"
	   "<br />"+d+"</td></tr></table></td></tr>\n");

  return ({ x, header });
}

string page_faster_low(RequestID id)
{
  string desc, err;
  [desc,err] = get_module_list( describe_module_faster,
                                class_visible_faster, id );
  return
    "<form method='post' action='add_module.pike'>"
    "<input type='hidden' name='config' value='&form.config;'>"
    "<roxen-wizard-id-variable />"
    "<table cellspacing='3' cellpadding='0' border='0' width='100%'>" +
    desc +
    "</table>"
    "</form>" +
    err;
}

string page_faster_search(RequestID id)
{
  return
    "<use file='/template-insert' />\n"
    "<tmpl>" +
    page_faster_low(id) +
    "</tmpl>";
}

string page_faster( RequestID id )
{
  string content =
    "<div id='mod_results' style='display: none'>"
    "</div>"
    "<div id='mod_default'>" +
    page_faster_low(id) +
    "</div>";
  return page_base( id, content, 0, 1);
}

int first;

array(int|string) class_visible_compact( string c, string d, int size,
					 RequestID id )
{
  string res="";
  if(first++)
    res = "</select><br /><submit-gbutton vspace='3'> "+
      LOCALE(200, "Add Modules")+ " </submit-gbutton> ";
  res += "<p><a name='"+Roxen.html_encode_string(c)+
    "'></a><font size='+2'>"+c+"</font><br />"+d+"<p>"
    "<select size='"+size+"' multiple name='module_to_add' class='add-module-select'>";
  return ({ 1, res });
}

string describe_module_compact( object module, object block )
{
  if(!block) {
    //string modname = strip_leading (module->get_name());
    string modname = module->get_name();
    return "<option value='"+module->sname+"'>"+
      Roxen.html_encode_string(modname)
      + "&nbsp;" * max (0, (int) ((49 - sizeof (modname)))) +
      " (" + Roxen.html_encode_string(module->sname) + ")"+
      "</option>\n";
  }
  return "";
}

string page_compact( RequestID id )
{
  first=0;
  string desc, err;
  [desc,err] = get_module_list( describe_module_compact,
                                class_visible_compact, id );
  return page_base(id,
                   "<form action='add_module.pike' method='POST'>"
		   "<roxen-wizard-id-variable />"
                   "<input type='hidden' name='config' value='&form.config;'>"+
                   desc+"</select><br /><submit-gbutton vspace='3'> "
                   +LOCALE(200, "Add Modules")+" </submit-gbutton><p>"
                   +err+"</form>",
                   );
}

string page_really_compact( RequestID id )
{
  first=0;

  object conf = roxen.find_configuration( id->variables->config );
  object ec = roxenloader.LowErrorContainer();
  master()->set_inhibit_compile_errors( ec );

  if( id->variables->reload_module_list )
  {
    if( id->variables->only )
    {
      master()->clear_compilation_failures();
      m_delete( roxen->modules, (((id->variables->only/"/")[-1])/".")[0] );
      roxen->all_modules_cache = 0;
    }
    else
      roxen->clear_all_modules_cache();
  }

  array mods;
  roxenloader.push_compile_error_handler( ec );
  mods = roxen->all_modules();
  roxenloader.pop_compile_error_handler();

  sort(map(mods->get_name(), lambda(LocaleString in) {
			       in = lower_case((string)in);
			       //sscanf(in, "%*s: %s", in);
			       return in;
			     }), mods);
  string res = "";

  mixed r;
  License.Key license_key = conf->getvar("license")->get_key();
  array(RoxenModule) locked_modules = ({});
  
  if( (r = class_visible_compact( LOCALE(200,"Add Modules"),
				  LOCALE(273,"Select one or several modules to add."),
				  sizeof(mods), id )) && r[0] ) {
    res += r[1];
    foreach(mods, object q) {
      if( (!q->get_description() ||
	   (q->get_description() == "Undocumented")) &&
	  q->type == 0 )
	continue;
      object b = module_nomore(q->sname, q, conf);
      if( !b && q->locked &&
	  (!license_key || !q->unlocked(license_key, conf)) )
      {
	locked_modules += ({ q });
	continue;
      }
      res += describe_module_compact( q, b );
    }
  } else {
    res += r[1];
  }

  master()->set_inhibit_compile_errors( 0 );

  return page_base(id,
                   "<form action=\"add_module.pike\" method=\"post\">"
		   "<roxen-wizard-id-variable />"
                   "<input type=\"hidden\" name=\"config\" value=\"&form.config;\" />"+
                   res+"</select><br /><submit-gbutton> "
                   +LOCALE(200, "Add Modules")+" </submit-gbutton><br />"
                   +pafeaw(ec->get(),ec->get_warnings(),
			   locked_modules)+"</form>",
                   );
}

string decode_site_name( string what )
{
  if( (int)what ) 
    return (string)((array(int))(what/","-({""})));
  return what;
}




array initial_form( RequestID id, Configuration conf, array modules )
{
  id->variables->initial = "1";
  id->real_variables->initial = ({ "1" });

  string res = "";
  int num;

  foreach( modules, string mod )
  {
    ModuleInfo mi = roxen.find_module( (mod/"!")[0] );
    RoxenModule moo = conf->find_module( replace(mod,"!","#") );
    foreach( indices(moo->query()), string v )
    {
      if( moo->getvar( v )->get_flags() & VAR_INITIAL )
      {
        num++;
        res += "<tr><td colspan='3'><h2>"
        +LOCALE(1,"Initial variables for ")+
	  //Roxen.html_encode_string(strip_leading(mi->get_name()))
	  Roxen.html_encode_string(mi->get_name())
	  +"</h2></td></tr>"
        "<emit source='module-variables' "
	  " configuration=\""+conf->name+"\""
        " module=\""+mod+#"\"/>
        <emit noset='1' source='module-variables' "
	  " configuration=\""+conf->name+"\""
        " module=\""+mod+#"\">
 <tr>
 <td width='150' valign='top' colspan='2'><b>&_.name;</b></td>
 <td valign='top'><eval>&_.form:none;</eval></td></tr>
 <tr>
<td width='30'><img src='/internal-roxen-unit' width=50 height=1 alt='' /></td>
  <td colspan=2>&_.doc:none;</td></tr>
 <tr><td colspan='3'><img src='/internal-roxen-unit' height='18' /></td></tr>
</emit>";
        break;
      }
    }
  }
  return ({res,num});
}

mapping already_added =  ([]);

mixed do_it_pass_2( array modules, Configuration conf,
                    RequestID id )
{
  id->misc->do_not_goto = 1;  
  foreach( modules, string mod ) 
  {
    if( already_added[mod] )
      mod = already_added[ mod ];
    if( !has_value(mod, "!") || !conf->find_module( replace(mod,"!","#") ) )
    {
      RoxenModule mm = conf->enable_module( mod,0,0,1 );
      if( !mm || !conf->otomod[mm] )
      {
	report_error(LOCALE(382,"Failed to enable %s")+"\n");
	return Roxen.http_redirect( site_url(id,conf->name), id );
      }      
      conf->call_low_start_callbacks( mm, 
                                      roxen.find_module( (mod/"!")[0] ), 
                                      conf->modules[ mod ] );
      modules = replace( modules, mod,
			 (already_added[mod]=(mod/"!")[0]+"!"+
			  (conf->otomod[mm]/"#")[-1]) );
    }
  }

  [string cf_form, int num] = initial_form( id, conf, modules );
  if( !num || id->variables["ok.x"] )
  {
    // set initial variables from form variables...
    if( num ) Roxen.parse_rxml( cf_form, id );
    foreach( modules, string mod )
     conf->call_high_start_callbacks( conf->find_module( replace(mod,"!","#") ),
				      roxen.find_module( (mod/"!")[0] ),
				      1);
    already_added = ([ ]);
    conf->save( ); // save it all in one go
    conf->forcibly_added = ([]);
    return Roxen.http_redirect(
      site_url(id,conf->name)+"-!-/"+modules[-1]+"/" ,
      id);
  }
  return page_base(id,"<table>"+
                   map( modules, lambda( string q ) {
                                   return "<input type='hidden' "
                                          "name='module_to_add' "
                                          "value='"+q+"' />";
                                 } )*"\n" 
                   +"<input type='hidden' name='config' "
		   "value='"+conf->name+"' />"+cf_form+"</table><p><cf-ok />");
}

mixed do_it( RequestID id )
{
  if( id->variables->encoded )
    id->variables->config = decode_site_name( id->variables->config );

  Configuration conf;
  foreach(id->variables->config/"\0", string config) {
    if (conf = roxen.find_configuration( config )) {
      id->variables->config = config;
      break;
    }
  }

  if (!conf) {
    return sprintf(LOCALE(356, "Configuration %O not found."),
		   id->variables->config);
  }

  if( !conf->inited )
    conf->enable_all_modules();

  array modules = (id->variables->module_to_add/"\0")-({""});
  if( !sizeof( modules ) )
    return Roxen.http_redirect( site_url(id,conf->name ), id );
  return do_it_pass_2( modules, conf, id );
}

mixed parse( RequestID id )
{
  if( !config_perm( "Add Module" ) )
    return LOCALE(226, "Permission denied");

  if (!id->variables->config) {
    return Roxen.http_redirect("/sites/", id);
  }

  if( id->variables->module_to_add )
    return do_it( id );

  Configuration conf;
  foreach(id->variables->config/"\0", string config) {
    if (conf = roxen.find_configuration(config)) {
      id->variables->config = config;
      break;
    }
  }

  if( !config_perm( "Site:"+conf->name ) )
    return LOCALE(226,"Permission denied");

  if( !conf->inited )
    conf->enable_all_modules();

  string method = get_method(id);

  if (id->variables->mod_query) {
    //  Force UTF-8 to please some browsers that can't guess charset in
    //  XMLHttpRequest communication.
    id->set_output_charset && id->set_output_charset("UTF-8");
    
    //  This can be invoked from both Normal and Faster methods
    return (method == "faster" ?
	    page_faster_search(id) :
	    page_normal_search(id, 1));
  }
  
  return this_object()["page_" + method]( id );
}
