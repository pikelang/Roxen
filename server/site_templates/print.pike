// $Id: print.pike,v 1.1 2006/11/16 13:37:20 simon Exp $

#include <module.h>
#include <roxen.h>

inherit "standard";
constant site_template = 1;

constant name = "Print";
constant group = "150|Roxen CMS";
constant doc  = "A Roxen Print site.";
constant locked = 1;

#define VAR_INITIAL     0x800
#define LOCALE(X,Y)	_STR_LOCALE("roxen_config",X,Y)

constant silent_modules = ({ 
  "footer-component",
  "rxmlparse",
  "insert-component",
  "search_utils",
  "href-component",
  "vform",
  "url_rectifier",
  "search_query",
  "menu-component",
  "obox",
  "emit_timerange",
  "indexfiles",
  "search_sb_interface",
  "cimg",
  "preferred_language",
  "filesystem",
  "header-component",
  "sbtags_2.0",
  "file-component",
  "translation_mod",
  "check_spelling",
  "xsltransform",
  "insite_editor",
  "table-component",
  "picture-component",
  "print-component",
});

constant modules =
({
  "sitebuilder",
  "feed-import",
  "print-db",
});

array(string) _print_modules_display = ({ // Information purposes only
  "Print: DB module",
  "Feed import: Main module"
});

int unlocked(License.Key license)
{
  return license->is_module_unlocked("print");
}

void init_modules(Configuration c, RequestID id)
{
  // FIXME
  if( RoxenModule m = c->find_module( "acauth_cookie" ) )
    m->set( "redirect", "/login.html" );
}

array default_sites;

array(mapping) get_default_sites(RequestID id)
{
  if(!default_sites)
  {
    RoxenModule mod = id->misc->new_configuration->find_module( "sitebuilder" );
    default_sites = mod->get_default_sites();
  }
  return default_sites;
}

string get_form_default_site(RequestID id)
{
  foreach(get_default_sites(id)->name, string name)
  {
    if(id->variables[name+".x"])
      return name;
  }
}

mapping get_default_site(string name, RequestID id)
{
  foreach(get_default_sites(id), mapping default_site)
  {
    if(default_site->name == name)
      return default_site;
  }
}

string format_input(string title, string form, string doc, string hint)
{
  return
    "<tr>"
    "  <td width='50'></td><td width='20%'><b>"+title+"</b></td>"
    "  <td>"+form+"</td>"
    "</tr>"
    "<tr>"
    "  <td></td>"
    "  <td colspan=2>"+doc+"<p>"+hint+"</td>"
    "</tr>";
}

string page_0(RequestID id, mixed pre_res)
{
  return pre_res +
    "<input type='hidden' name='page' value='1' />"
    "<div align='right'><cf-next /></div>";
}

string page_1(RequestID id, mixed pre_res)
{
  RoxenModule mod = id->misc->new_configuration->find_module( "sitebuilder" );
  if(Stdio.is_dir(mod->query("storage")))
    return page_3(id, pre_res);

  array buttons =
    map(get_default_sites(id),
	lambda(mapping m)
	{
	  return "<cset variable='var.url'>"
	    "<gbutton-url width='400' "
	    "             icon_src='&usr.next;' "
	    "             align_icon='right'>"
	    + Roxen.html_encode_string(m->title) +
	    "</gbutton-url></cset>"
	    "<input border='0' type='image' src='&var.url;' name='"+m->name+"'>\n"
	    "<blockquote>"+m->doc+"</blockquote>";
	});
  
  string ret = 
    "<input type='hidden' name='page' value='2' />"
    "<h2>Roxen Print settings</h2>"
    "Please observe that you need to visit the settings for "
    "the below listed Print modules when the site "
    "has been created and set the SiteBuilder/Work area property.<br><br>"
    "You also need to create the necessary databases and tables for the Print "
    "system to function properly. This is done under the Print: DB module status page.";
  foreach( _print_modules_display, string module )
    ret += "<p><b>" + module + "</b>";

  ret += "<div align='right'><cf-next /></div>";
  return ret;
}

string page_2(RequestID id, mixed pre_res)
{
  mapping default_site = get_default_site("print", id);
  string res =
    "<h2>Roxen CMS</h2>"
    "<input type='hidden' name='page' value='3' />"
    "<input type='hidden' name='default_site' value='"+default_site->name+"' />"
    "<p>After clicking 'OK' here, Roxen CMS will try to initialize a "
    "new site in the specified directory. That can take some time; please be patient. "
    
    "<p>Watch out for any messages in the event log under the 'Status' tab.";

  if(default_site->variables)
  {
    res += "<h2>Initial variables for the default site of type " +
           default_site->title +
	   "</h2><table>";
    
    //  Find license key for this site
    Configuration conf = id->misc->new_configuration;
    License.Key key = conf && conf->getvar("license")->get_key();
    
    foreach(default_site->variables, mapping variable)
    {
      //  If we're creating a Personal Edition site, don't enable Example
      //  ACDB since that would create too many AC identities.
      if (key && key->type() == "personal" &&
	  variable->name == "example_acdb") {
	res += "<input type='hidden' name='example_acdb' value='no' />";
	continue;
      }
      
      string html;
      switch(variable->type)
      {
	case "text":
	  html = Roxen.make_tag("input",
				([ "type":"text", "name":variable->name, "/":"/" ]));
	  break;
	  
	case "password":
	  html = Roxen.make_tag("input",
				([ "type":"password", "name":variable->name, "/":"/" ]));
	  break;
	  
	case "select":
	  string options =
	    map(variable->options,
		lambda(mapping option)
		{ return Roxen.make_container("option",
					      ([ "value": option->value]),
					      option->title); })*"\n";
	  html =
	    Roxen.make_container("select",
				 ([ "type":"select", "name":variable->name, "/":"/" ]),
				 options);
      }
      res += format_input(variable->title, html, variable->doc, "");

    }
    res += "</table>";
  }
  
  return res + "<div align='right'><cf-ok /></div>";;
}

string page_3(RequestID id, mixed pre_res)
{
  RoxenModule mod = id->misc->new_configuration->find_module( "sitebuilder" );
  return
    "<h2>Roxen CMS</h2>"
    "<input type='hidden' name='page' value='4' />"
    "<p>You have selected an existing Roxen CMS storage \""+mod->query("storage")+"\"."
    "<p>Press 'OK' to create the site using this storage."
    "<div align='right'><cf-ok /></div>";
}

mixed parse (RequestID id)
{
  if( id->variables["ok.x"] && id->variables["page"] == "3")
  {
    mapping default_site = get_default_site(id->variables->default_site, id);
    mapping variables = ([ ]);
    if(default_site->variables)
      foreach(default_site->variables, mapping variable)
	variables[variable->name] = id->variables[variable->name];

    RoxenModule mod = id->misc->new_configuration->find_module( "sitebuilder" );
    mod->set_default_site(default_site->path, variables);
  }

  // Default to http on the first page.
  if(id->variables["initialize_template"]) {
    id->misc->new_configuration->query()["URLs"]->set( ({ "http://*/" }) );

    // Make sure site-news is loaded.
    load_modules(id->misc->new_configuration);

    RoxenModule mod;
    if (mod = id->misc->new_configuration->find_module("site-news")) {
      Variable var = mod->query()["sitebuilder"];
      var->set(id->misc->new_configuration->name);
      var->verify_set(id->misc->new_configuration->name);
      var->set_flags(var->get_flags() & ~VAR_INITIAL);
    }
  }
  
  mixed res = ::parse (id, ([ "no_ok":1 ]));
  if(res == "<done/>") return res;
  
  if(id->variables["page"] == "1" && id->variables["next.x"] && form_is_ok(id))
    return page_1(id, res);
  
  if(id->variables["page"] == "2")
    return page_2(id, res);
  
  return page_0(id, res);
}

