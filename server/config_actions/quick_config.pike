/*
 * $Id: quick_config.pike,v 1.6 1998/06/04 12:20:22 grubba Exp $
 */

inherit "wizard";

string name="Maintenance//Quick Config...";
string doc = "You can here automate the most common configuration and maintenance tasks.";


constant features = ([
  "&lt;GText&gt;":([ "module":"graphic_text", "depend":"htmlparse",
		     "help":"The RXML graphical text tag &lt;gtext&gt;."]),
  "RXML":([ "module":"htmlparse",
	    "help":"If removed, all RXML parsing will be disabled."]),
  "CGI":([
    "module":"cgi",
    "help":"Support for CGI scripts.",
    "settings":([
      
    ]),
  ]),
  "Pike":([ "module":"pikescript","help":"Support for pike scripts.", ]),
  "&lt;Pike&gt;":([ "module":"lpctag","depend":"htmlparse",
		    "help":"Support for the pike tag.",]),
  "IP-VHM":([ "module":"ip-less_hosts",
	      "help":"IP less virtual server master<br>Select this option"
	      "in the configuration that has open ports you want to use "
	      "for ip-less virtual hosting."]),
  "&lt;OBox&gt;":([ "module":"obox", "depend":"htmlparse",]),
  "Imagemaps":([ "module":"ismap", ]),
  "&lt;Tablify&gt;":([ "module":"tablify", "depend":"htmlparse" ]),
  "Userfs":([
    "module":"userfs", "depend":"userdb",
    "help":"Enable user directories."
  ]),
]);

string config_name(object c)
{
  if(strlen(c->query("name"))) return c->query("name");
  return c->name;
}


array not_tags(array q)
{
  return Array.filter(q,lambda(string q){ return q[0]!='&'; });
}

array tags(array q)
{
  return q - not_tags(q);
}

string page_0(object id)
{
  array tbl = ({ });
  string q,pre="<font size=+1>Specific features</font><p>";
  foreach(sort(not_tags(indices(features))), string s)
    if(q=features[s]->help)
      pre += "<help><dl><dt><b>"+s+"</b><dd>"+q+"</dl><p></help>";
  foreach(roxen->configurations, object c)
  {
    array tblr = ({ config_name(c) });
    foreach(sort(not_tags(indices(features))), string f)
      if(c->modules[features[f]->module])
	tblr += ({ "<font size=+2><var type=checkbox name='"+c->name+"/"+f+"' default=1></font>" });
      else
	tblr += ({ "<font size=+2><var type=checkbox name='"+c->name+"/"+f+"' default=0></font>" });
    tbl += ({ tblr });
  }
  return pre+html_table( ({ "Server" })  + sort(not_tags(indices(features))),
  tbl );
}


string page_1(object id)
{
  array tbl = ({ });
  int num;
  string q,pre="<font size=+1>RXML tags</font><p>";
  foreach(sort(tags(indices(features))), string s)
    if(q=features[s]->help)
      pre += "<help><dl><dt><b>"+s+"</b><dd>"+q+"</dl><p></help>";
  foreach(roxen->configurations, object c)
  {
    if((id->variables[c->name+"/RXML"]!="0"))
    {
      num++;
      array tblr = ({ config_name(c) });
      foreach(sort(tags(indices(features))), string f)
	if(c->modules[features[f]->module])
	  tblr += ({ "<font size=+2><var type=checkbox name='"+
		       c->name+"/"+f+"' default=1></font>" });
	else
	  tblr += ({ "<font size=+2><var type=checkbox name='"+
		       c->name+"/"+f+"' default=0></font>" });
      tbl += ({ tblr });
    }
  }
  if(num)
    return pre+html_table( ({ "Server" })+sort(tags(indices(features))),tbl );
}

object find_config(string n)
{
  foreach(roxen->configurations, object c) if (c->name==n) return c;
}

array actions;

void enable_module(object c, string m, string d)
{
  c->enable_module(m);
  if(d && !c->modules[d]) c->enable_module(d);
}

void disable_module(object c, string m)
{
  c->disable_module(m);
}

string page_2(object id)
{
  actions = ({});
  foreach(sort(indices(id->variables)), string i)
  {
    string conf, mod;
    if(sscanf(i, "%s/%s", conf, mod)==2)
    {
//      werror("conf: "+conf+" mod: "+mod+"\n");
      mod = html_encode_string(mod);
      int to_enable = (id->variables[i] != "0");
      object config = find_config(conf);
      string m = features[mod]->module;
      string d = features[mod]->depend;
      if(config && (to_enable==!config->modules[m]))
	if(to_enable)
	  actions += ({({"Enable the module "+m+" in the configuration "+
			  config_name(config),
			  enable_module, config, m, d })});
        else
	  actions += ({({"Disable the module "+m+" in the configuration "+
			  config_name(config),
			  disable_module, config, m })});
    }
  }

  if (sizeof(actions)) {
    return ("<font size=+1>Summary</font><p><ul><li>"+
	    column(actions,0)*"\n<li>"+"</ul>");
  } else {
    return ("<font size=+1>Summary</font><p>\n"
	    "<ul>No changes will be made.</ul>");
  }
}


void wizard_done(object id)
{
  foreach(actions, array action) action[1](@action[2..]);
  if (roxen->->unload_configuration_interface) {
    /* Fool the type-checker of in old Roxen's */
    mixed foo = roxen->unload_configuration_interface;
    foo();
  } else {
    /* Some backward compatibility */
    roxen->configuration_interface_obj=0;
    roxen->loading_config_interface=0;
    roxen->enabling_configurations=0;
    roxen->build_root=0;
    catch{roxen->root->dest();};
    roxen->root=0;
  }
}


string handle(object id){ return wizard_for( id , 0 ); }
