// $Id: print.pike,v 1.15 2007/05/11 07:43:27 tor Exp $

inherit "standard";
constant site_template = 1;

constant name = "Print";
constant group = "150|Roxen CMS";       //  1xx is a sort key
constant doc  = "A Roxen Print site.";
constant locked = 1;

// Stolen from module.h
#define VAR_INITIAL     0x800

constant modules =
({
  "sitebuilder",
  "print-db",
});

constant silent_modules =
({
  "url_rectifier",
  "indexfiles",
  "cimg",
  "html_wash",
  "vform",
  "preferred_language",
  "search_sb_interface",
  "search_utils",
  "feed-import",
  "rxmlparse",
  "pathinfo",
  "emit_timerange",
});

array(string) _print_modules_display = ({ // Information purposes only
  "Print: DB module",
  "Feed import: Main module"
});

void init_modules(Configuration c, RequestID id)
{
  // FIXME: Add search engine configuration
  if( RoxenModule m = c->find_module( "acauth_cookie" ) )
    m->set( "redirect", "/login.html" );

  if( RoxenModule m = c->find_module( "sqltag" ) )
    m->set( "charset", "unicode" );

  if( RoxenModule m = c->find_module( "print-db" ) )
    m->set( "sitebuilder", c->name );
  
  if( RoxenModule m = c->find_module( "feed-import" ) ) 
    if (RoxenModule sb_module = c->find_module("sitebuilder")) 
      m->set( "workarea", c->name + "/" );
  
  if (RoxenModule sb_module = c->find_module("sitebuilder")) {
    sb_module->set("load-insite-editor", 1);
    sb_module->set("site-create-version", roxen_version());
  }
  if( RoxenModule m = c->find_module( "rxmlparse" ) )
    m->set( "logerrorsp", 1 );
}

int unlocked(License.Key license)
{
  return license->is_module_unlocked("print");
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

Sql.Sql get_db()
{
  return DBManager.get( "mysql" );
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

string upper_tr(int num, string text) {
  return "<tr><td style=\"font-size: 10px; font-style: italic;\">" + num + ".</td><td style=\"font-size: 12px; font-weight: bold;\">" + text + "</td></tr>";
}

string lower_tr(string text) {
  return "<tr><td style=\"font-size: 10px; font-style: italic;\">&nbsp;</td><td style=\"font-size: 10px; font-style: italic;\">" + text + "</td></tr>";
}

string page_db_notice(RequestID id, mixed pre_res, string version)
{
  
  return
    "<input type='hidden' name='page' value='0' />"
    "<h1><font color='#FF0000'>Warning: Old MySQL version (" + version + ")</font></h1>"
    "You are running version " + version + " of MySQL. "
    "It's recommended that you upgrade to version 4.1 before continuing. "
    "Press Cancel to exit the site installation process or Next to continue anyway. "
    "<h2>Upgrade instructions MySQL 4.0 -> 4.1</h2>"
    "<table border=0>" + 
    upper_tr( 1, "Shutdown Roxen server." ) + 
    lower_tr( "Tasks -> Maintenance -> Restart or shutdown" ) + 
    upper_tr( 2, "Download the latest 4.1 distribution available from http://dev.mysql.com/downloads/mysql/4.1.html" ) + 
    upper_tr( 3, "Extract the downloaded file." ) + 
    lower_tr( "tar xzf mysql-YYY.tar.gz" ) + 

    upper_tr( 4, "Move the extracted directory into the appropriate Roxen server directory." ) + 
    lower_tr( "mv mysql-YYY roxen/server-XXX/mysql-4.1" ) + 

    upper_tr( 5, "Move the default mysql directory to a backup directory. (*)" ) + 
    lower_tr( "mv mysql mysql.dist" ) + 

    upper_tr( 6, "Create a symbolic link from the mysql 4.1 directory to mysql. (*)" ) + 
    lower_tr( "ln -s mysql-4.1 mysql" ) + 

    upper_tr( 7, "Move the default roxen_mysql binary file to a backup copy. (*)" ) + 
    lower_tr( "mv bin/roxen_mysql bin/roxen_mysql.dist" ) + 

    upper_tr( 8, "Create a hard link to the new mysqld file and place it in the bin directory under the name roxen_mysql. (*)" ) + 
    lower_tr( "ln mysql/bin/mysqld bin/roxen_mysql" ) + 
    
    upper_tr( 9, "Append the option -DENABLE_MYSQL_UNICODE_MODE to the DEFINES variable to the roxen/local/environment2 file. (**)" ) + 
    lower_tr( "echo \"DEFINES=\\\"$DEFINES -DENABLE_MYSQL_UNICODE_MODE\\\"\" >> local/environment2" ) + 
    lower_tr( "echo \"export DEFINES\" >> local/environment2" ) + 
    
    upper_tr( 10, "Start the server." ) + 
    "<tr><td>&nbsp</td><td></td></tr>" +
    lower_tr( "* To be performed in the roxen/server-XXX directory" ) +
    lower_tr( "** To be performed in the roxen/ directory" ) +
    "</table>"
    "<div align='right'><cf-cancel href='./'/><cf-next /></div>";
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

  string ret =
    "<input type='hidden' name='page' value='2' />"
    "<h2>Roxen Print settings</h2>"
    "Please observe that you need to visit the settings for "
    "the below listed Print modules when the site "
    "has been created and set the appropriate settings.<br><br>"
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
    "<p>An initial administrators account will be set up with a predefined username and password listed below. "
    "This username and/or password can later be changed from the insite editor under Access Control. "
    "It's recommended that you change this password as soon as possible.</p>"
    "<p>Username: <b>roxen</b></p>"
    "<p>Password: <b>roxen</b></p>"
    
    "<p>Watch out for any messages in the event log under the 'Status' tab.";

  res += "</table>";
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

  if(id->variables["page"] == "0")
    return page_0(id, res);

  Sql.Sql db = get_db();
  string version = db->query( "SELECT VERSION() AS v" )[0]->v;
  if( (float)version < 4.1 ) 
    return page_db_notice(id, res, version);

  return page_0(id, res);
}
