/*
 * $Id: upgrade.pike,v 1.10 1997/08/21 11:31:24 per Exp $
 */

inherit "wizard";


int is_older(string v1, string v2)
{
  int def;
  array a1,a2;
  if(sizeof(a1=v1/".") == sizeof(a2=v2/"."))
    return v1<v2;
  if(sizeof(a1)<sizeof(a2))
    def=1;
  for(int i=0; i<(def?sizeof(a1):sizeof(a2)); i++)
    if((int)a1[i]!=(int)a2[i])
      return a1[i]<a2[i];
  return def;
}



constant name= "Maintenance//Upgrade components from roxen.com...";
constant doc = "Selectively upgrade Roxen components from roxen.com.";

mapping modules;


mapping extract_module_info(array from)
{
  string fname, version;
  mapping m = ([]);
  sscanf(from[1], "%*s<b>Loaded from:</b> %s<", fname);
  sscanf(from[1], "%*s<b>CVS Version: </b>%s<", version);
  m->fname = fname;
  if(version)
    sscanf(version, "%s ", version);
  else
  {
    if(fname)
    {
      string mod = Stdio.read_bytes(fname);
      if(mod)
      {
	sscanf(mod, "%*s$Id: %*s.pike,v %s ", version);
	werror("Version: " + version + "\n");
      }
    }
  }
  m->version = version;
  m->name = from[0];
  m->type = from[2];
  return m;
}

void find_modules(int mode)
{
  if(mode)
  {
    roxen->rescan_modules();
    modules = copy_value(roxen->allmodules);
  } else {
    modules = ([]);
    foreach(roxen->configurations, object c)
    {
      mapping tmpm = c->modules;
      foreach(indices(tmpm), string mod)
	modules[mod] =
	  ({  tmpm[mod]->name, 
	      (tmpm[mod]->master?tmpm[mod]->master->file_name_and_stuff():
	       tmpm[mod]["program"]()->file_name_and_stuff()),
	      tmpm[mod]->type });
    }
  }

  mapping rm = ([]);
  foreach(indices(modules), string mod)
  {
    mapping m = extract_module_info(modules[mod]);
    if(!m->version) m->version="0.0 (Unknown)";
    rm[mod] = m;
  }
  modules = rm;
}


string page_0(object id)
{
  return
    ("<font size=+1>What components do you want to upgrade?</font><br>\n"
     "</tr><tr><td colspan=2>\n"
     "<var type=radio name=how value=1> All installed modules (all modules in your module path)<br>\n"
     "<var type=radio name=how default=1 value=0> Only currently "
     "enabled modules (from all virtual servers) <br>\n"
     "<var type=checkbox name='how2'> Also search for new (previously "
     "uninstalled) modules<br>\n"
     "<var type=checkbox name='how3' default=1> Also search for actions "
     "and server templates ");
}

string upgrade_module(string m, object rpc)
{
  array rm = rpc->get_module(m,roxen->real_version);
  string res="";
  object privs = ((program)"privs")("Upgrading modules", "root");
  if(!rm) return "Failed to fetch the module '"+m+"'.";
  if(!modules) find_modules(1);
  if(modules[m])
  {
    mkdir("old_modules");
    if(mv(modules[m]->fname, "old_modules/"+m+":"+modules[m]->version))
      res+="Moved "+modules[m]->fname+" to old_modules/"+m+":"+
	modules[m]->version+"<br>";
    else
      res+="Failed to move "+modules[m]->fname+"<br>";
  }

  if(Stdio.file_size("modules/"+rm[0])>0)
  {
    mkdir("old_modules");
    if(mv("modules/"+rm[0], "old_modules/"+m+".pike"))
      res+="Moved modules/"+rm[0]+" to old_modules/"+m+".pike<br>\n";
    else
      res+="Failed to move modules/"+rm[0]+" to old_modules/"+m+".pike<br>\n";
  }
  mkdirhier("modules/"+rm[0]);
  object o = open("modules/"+rm[0], "wct");
  if(!o) res += "Failed to open "+"modules/"+rm[0]+" for writing.<br>";
  else {
    o->write(rm[1]);
    res+="Fetched modules/"+rm[0]+", "+strlen(rm[1])+" bytes.<br>";
    report_notice("Upgraded "+rm[0]+".");
  }
  m_delete(roxen->allmodules, m);
  cache_remove("modules", m);


  foreach(roxen->configurations, object c)
  {
    if(c->modules[m])
    {
      if(!c->load_module(m))
      {
	report_error("The newly upgraded module could not be reloaded!");
      } else {
	foreach(indices(c->modules[m]->copies||({"foo"})), int n)
	  if(!c->disable_module(name+"#"+n))
	    report_error("Failed to disable the module "+name+"#"+n);
	  else if(!(c->enable_module(name+"#"+n)))
	    error("Failed to enable module "+name+"#"+n+".\n");
      }
      object co = roxen->configuration_interface();
      object node = co->root;
      node = node->descend(c->name);
      node->clear();
      call_out(co->build_configuration,0,node);
    }
  }
  
  return res+"<p>\n\n\n";
}

string page_2(object id)
{
  object rpc;
  catch {
    rpc=RoxenRPC.Client("skuld.infovav.se",23,"upgrade");
  };
  if(!rpc)return "Failed to connect to update server at skuld.infovav.se:23.\n";
//  if((int)id->variables["how:3"]) return handle_components(id,rpc);
}

string page_3(object id)
{
  object rpc;
  catch {
    rpc=RoxenRPC.Client("skuld.infovav.se",23,"upgrade");
  };
  if(!rpc)return "Failed to connect to update server at skuld.infovav.se:23.\n";

//  if((int)id->variables["how:2"])
//    return new_form(id,rpc);
}

string page_1(object id)
{
  int num;
  object rpc;
  string res=
    ("<font size=+2>Modules that have a newer version available.</font><p>"
     "Select the box to add the module to the list of modules to "
     "be updated</b></td></tr>\n");
  catch {
    rpc=RoxenRPC.Client("skuld.infovav.se",23,"upgrade");
  };
  if(!rpc)
    return "Failed to connect to update server at skuld.infovav.se:23.\n";

  find_modules((int)id->variables->how);
  mapping mv = rpc->module_versions( modules, roxen->real_version );
  array tbl = ({});
  foreach(sort(indices(modules)), string m)
  {
    if(mv[m] && (is_older(modules[m]->version, mv[m])))
    {
      num++;
      tbl += ({({"<var type=checkbox name=M_"+m+">",
		 modules[m]->name,modules[m]->fname,modules[m]->version,
		 (mv[m]?mv[m]:"?")})});
    }
  }
  if(num)
    return res + html_table ( ({ "", "Module", "File", "Available Version",
				   "Installed Version"}), tbl );
  else
    return "There are no new versions of any of your modules available";

}

string handle_upgrade(object id, object rpc)
{
  string res = "<h1>Retrieving new modules...</h1><br>";
  int num;
  int st = time();
  foreach(indices(id->variables), string m)
    if(sscanf(m,"M_%s",m))
    {
      res += upgrade_module(m,rpc);
      num++;
    }

  if(num) roxen->rescan_modules();
  return (res+"<p><br><b><a href=/Actions/>Done in "+
	  (time()-st)+" seconds.</a></b><form><input type=hidden name=action value=upgrade.pike><input type=submit value=\" Ok \"></form>");
}


string new_form(object id, object rpc)
{
  string res=""
    "<form>\n"
    "<input type=hidden name=action value="+id->variables->action+">\n"
    "<table cellpadding=2 cellspacing=0 border=0><tr bgcolor=lightblue><td colspan=3><b>"
    "New modules that are available<br> "
    "Select the box to add the module to the list of modules to "
    "be updated</b></td></tr>\n"
    "<tr bgcolor=lightblue>"
    "<td>Module name</td><td>Filename</td>"
    "<td>Version</td></tr>\n";

  find_modules(1);

  mapping rm = rpc->all_modules(roxen->real_version);
  int num;
  foreach(sort(indices(rm)), string s)
    if(!modules[s])
    {
/*      if(Stdio.file_size(rm[s]->filename) > 0)
	werror("Module "+s+" present, but won't load.\n");
      else { */
	num++;
	res += ("<tr bgcolor=#f0f0ff><td><b><font size=+1><input type=checkbox name=M_"+s+"> "+
		rm[s]->name+"</font></b></td><td><b><font size=+1>"+rm[s]->filename+"</font></b></td><td><b><font size=+1>"+
		rm[s]->version+"</font></b></td><td></tr><tr><td colspan=3><font size=-1>"+
		rm[s]->doc+"</font><br><p><br></td></tr>\n");
    }
  if(num)
    res += "</table>";
  else
    return "<a href=/Actions/?action=upgrade.pike>There are no new modules available.</a><form><input type=hidden name=action value=upgrade.pike><input type=submit value=\" Ok \"></form>";

  res += "<table width=100%><tr><td><input type=submit name=go value=\" Install \">"
    "</form>\n</td><td align=right>"
    "<form><input type=hidden name=action value="+
    id->variables->action+">"
    "<td><input type=submit name=cancel value=\" Cancel \"></table></form>\n";
  return res;
}




// Scan dirs to find currently installed components
mapping comps=([]);

mixed parse_expression(string expr)
{
  catch {return compile_string("mixed e="+expr+";")()->e;};
}

void recurse_one_dir(string d)
{
  foreach(get_dir(d), string f)
  {
    if(search(f, "#")!=-1) continue;
    if(search(f, "~")!=-1) continue;
    if(sscanf(f, "%s.pike", f))
    {
      string mod = Stdio.read_bytes(d+f+".pike");
      if(!mod) {
	werror("Failed to read "+d+f+".pike.\n");
      } else {
	string version;
	string doc, name;
	if(sscanf(mod, "%*s$Id: %*s.pike,v %s ", version)==3)
	{
	  if(sscanf(mod, "%*sname%*[ \t]=%s;", name)==3)
	    name = parse_expression(name);
	  if(sscanf(mod, "%*sdoc%*[ \t]=%s;", doc)==3)
	    doc = parse_expression(doc);
	  else if(sscanf(mod, "%*sdesc%*[ \t]=%s;", doc)==3)
	    doc = parse_expression(doc);
	}
	comps[f]=([
	  "fname":d+f,
	   "doc":doc,
	   "name":name,
	   "version":version,
	]);
      }
    }
#if 0
    else if(Stdio.file_size(d+f)==-2) {
      recurse_one_dir(d+f+"/");
    }
#endif
  }
}

void update_comps()
{
  comps = ([]);
  recurse_one_dir("config_actions/");
  recurse_one_dir("server_templates/");
  recurse_one_dir("bin/");
  recurse_one_dir("languages/");
}


string upgrade_component(string m, object rpc)
{
  array rm = rpc->get_component(m,roxen->real_version);
  string res="";
  object privs = ((program)"privs")("root","Upgrading components");
  if(!rm) return "Failed to fetch the component '"+m+"'.";

  if(Stdio.file_size(rm[0])>0)
  {
    mkdir("old_components");
    if(mv(rm[0], "old_components/"+m+".pike"))
      res+="Moved "+rm[0]+" to old_components/"+m+".pike<br>\n";
    else
      res+="Failed to move "+rm[0]+" to old_components/"+m+".pike<br>\n";
  }
  object o = open(rm[0], "wct");
  if(!o) res += "Failed to open "+rm[0]+" for writing.<br>";
  else
  {
    o->write(rm[1]);
    res+="Fetched "+rm[0]+", "+strlen(rm[1])+" bytes.<br>";
    report_notice("Upgraded the component "+rm[0]+".");
  }
  return res+"<p>\n\n\n";
}

string upgrade_components(object id, object rpc)
{
  string res = "<h1>Retrieving new components...</h1><br>";
  int num;
  int st = time();
  foreach(indices(id->variables), string m)
    if(sscanf(m,"M_%s",m))
    {
      res += upgrade_component(m,rpc);
      num++;
    }
  roxen->configuration_interface()->actions=([]);
  
  return (res+"<p><br><b><a href=/Actions/>Done in "+
	  (time()-st)+" seconds.</a></b><form><input type=hidden name=action value=upgrade.pike><input type=submit value=\" Ok \"></form>");
}

string handle_components(object id, object rpc)
{

  if(id->variables->go)
    return upgrade_components(id,rpc);
  
  update_comps();
  string res=""
    "<form>\n"
    "<input type=hidden name=how value=3>"
    "<input type=hidden name=action value="+id->variables->action+">\n"
    "<table cellpadding=2 cellspacing=0 border=0><tr bgcolor=lightblue><td colspan=4><b>"
    "Components that have a newer version available. <br>"
    "Select the box to add the component to the list of components to "
    "be updated</b></td></tr>\n"
    "<tr bgcolor=lightblue>"
    "<td>Component name</td><td>Filename</td>"
    "<td>Version</td><td>Currently installed version</td></tr>\n";

  mapping rm = rpc->all_components(roxen->real_version);
  int num;
  foreach(sort(indices(rm)), string s)
  {
    if(!comps[s] || (is_older(comps[s]->version, rm[s]->version)))
    {
      num++;
      res += ("<tr bgcolor=#f0f0ff><td><b><font size=+1><input type=checkbox name=M_"+s+"> "+
	      rm[s]->name+"</font></b></td><td><b><font size=+1>"+
	      rm[s]->fname+"</font></b></td><td><b><font size=+1>"+
	      rm[s]->version+"</font></b></td><td><b><font size=+1>"+
	      (comps[s]?comps[s]->version:"New")+"</font></b></td><td></tr><tr><td colspan=3><font size=-1>"+
	      rm[s]->doc+"</font><br><p><br></td></tr>\n");
      }
    }
  if(num)
    res += "</table>";
  else
    return "<a href=/Actions/?action=upgrade.pike>There are no new components available.</a><form><input type=hidden name=action value=upgrade.pike><input type=submit value=\" Ok \"></form>";

  res += "<table width=100%><tr><td><input type=submit name=go value=\" Install \">"
    "</form>\n</td><td align=right>"
    "<form><input type=hidden name=action value="+
    id->variables->action+">"
    "<td><input type=submit name=cancel value=\" Cancel \"></table></form>\n";
  return res;
}


string handle(object id)
{
  return wizard_for(id,0);
  string res=""
    "<form>\n"
    "<input type=hidden name=action value="+id->variables->action+">\n"
    "<table cellpadding=2 cellspacing=0 border=0><tr bgcolor=lightblue><td colspan=4><b>"
    "Modules that have a newer version available. <br>"
    "Select the box to add the module to the list of modules to "
    "be updated</b></td></tr>\n"
    "<tr bgcolor=lightblue>"
    "<td>Module name</td><td>Filename</td><td>Your version</td>"
    "<td>Available version</td></tr>\n";
  int num;

  if(id->variables->how || id->variables->go)
  {
    object rpc;
    catch {
      rpc=RoxenRPC.Client("skuld.infovav.se",23,"upgrade");
    };
    if(!rpc)
      return "Failed to connect to update server at skuld.infovav.se:23.\n";

    if((int)id->variables->how==3)
      return handle_components(id,rpc);

    if(id->variables->go) return handle_upgrade(id,rpc);

    if((int)id->variables->how==2)
    {
      return new_form(id,rpc);
    }

    find_modules((int)id->variables->how);
    mapping mv = rpc->module_versions( modules, roxen->real_version );

    foreach(sort(indices(modules)), string m)
    {
      if(mv[m] && (is_older(modules[m]->version, mv[m])))
      {
	num++;
	res += ("<tr><td><input type=checkbox name=M_"+m+"> "+
		modules[m]->name+"</td><td>"+
		modules[m]->fname+"</td><td>"+
		modules[m]->version+"</td><td>"+
		(mv[m]?mv[m]:"?")+"</tr>"
		"\n");
      }
    }
    if(num)
      res += "</table>";
    else
      return "<a href=/Actions/?action=upgrade.pike>There are no upgrades available.</a><form><input type=hidden name=action value=upgrade.pike><input type=submit value=\" Ok \"></form>";

    res += "<table width=100%><tr><td><input type=submit name=go value=\" Upgrade \">"
      "</form>\n</td><td align=right>"
      "<form><input type=hidden name=action value="+
      id->variables->action+">"
      "<td><input type=submit name=cancel value=\" Cancel \"></table></form>\n";
    return res;
  }
}
