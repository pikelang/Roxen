/*
 * $Id: upgrade.pike,v 1.23 1997/09/06 16:09:28 grubba Exp $
 */
constant name= "Maintenance//Upgrade components from roxen.com...";
constant doc = "Selectively upgrade Roxen components from roxen.com.";

inherit "wizard";


int is_older(string v1, string v2)
{
  int def;
  array a1,a2;
  if (!v1) {
    return(v2 != 0);
  }
  if (!v2) {
    return(0);
  }
  if(sizeof(a1=v1/".") == sizeof(a2=v2/"."))
    if(strlen(v1)<strlen(v2))
      return 1;
    else if(strlen(v1)>strlen(v2))
      return 0;
//    else
//      return v1<v2; -> "1.11" < "1.2"...
  if(sizeof(a1) < sizeof(a2))
    def=1;
  for(int i=0; i< (def ? sizeof(a1) : sizeof(a2)); i++)
    if((int)a1[i] < (int)a2[i])
      return 1;
  return def;
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
    if(Stdio.file_size(d+f) > 0)
    {
      string mod = Stdio.read_bytes(d+f+"");
      if(!mod) {
	werror("Failed to read "+d+f+".\n");
      } else {
	string version;
	string doc, name;
	if(sscanf(mod, "%*s$Id: %*s,v %s ", version)==3)
	{
	  if(sscanf(mod, "%*sname%*[ \t]=%s;", name)==3)
	    name = parse_expression(name);
	  if(sscanf(mod, "%*sdoc%*[ \t]=%s;", doc)==3)
	    doc = parse_expression(doc);
	  else if(sscanf(mod, "%*sdesc%*[ \t]=%s;", doc)==3)
	    doc = parse_expression(doc);
	}
	sscanf(f, "%s.pike", f);
	comps[f]=
        ([
	  "fname":d+f,
	  "doc":doc,
	  "name":name,
	  "version":version,
	]);
      }
    }
    else if(Stdio.file_size(d+f)==-2)
    {
      if(f != "CVS")
	recurse_one_dir(d+f+"/");
    }
  }
}

void update_comps()
{
  comps = ([]);
  recurse_one_dir("config_actions/");
  recurse_one_dir("server_templates/");
  recurse_one_dir("bin/");
  recurse_one_dir("etc/");
  recurse_one_dir("languages/");
}


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
#ifdef DEBUG
	werror("Version: " + version + "\n");
#endif
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

/* Ask user for upgrade options */
string page_0(object id)
{
  return
    ("<font size=+1>What components do you want to upgrade?</font><br>\n"
     "</tr><tr><td colspan=2>\n"

     "<var type=radio name=how value=1> All installed components<br>\n"
     "<help><blockquote>"
     "Check for upgrades of all modules in your module path and installed "
     "plugins"
     "</blockquote></help>"

     "<var type=radio name=how default=1 value=0> Only currently "
     "enabled components (from all virtual servers) <br>\n"
     "<help><blockquote>"
     "Check for upgrades of all modules presently used in your Roxen and all "
     "plugins"
     "</blockquote></help>"
     
     "<var type=checkbox name=new> Also search for new components\n");
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
#if constant(chmod)
    catch { chmod("old_modules", 0755); };
#endif /* constant(chmod) */
    if(mv(modules[m]->fname, "old_modules/"+m+":"+modules[m]->version))
      res+="Moved "+modules[m]->fname+" to old_modules/"+m+":"+
	modules[m]->version+"<br>";
    else
      res+="Failed to move "+modules[m]->fname+"<br>";
  }

  if(Stdio.file_size("modules/"+rm[0])>0)
  {
    mkdir("old_modules");
#if constant(chmod)
    catch { chmod("old_modules", 0755); };
#endif /* constant(chmod) */
    if(mv("modules/"+rm[0], "old_modules/"+m+".pike"))
      res+="Moved modules/"+rm[0]+" to old_modules/"+m+".pike<br>\n";
    else
      res+="Failed to move modules/"+rm[0]+" to old_modules/"+m+".pike<br>\n";
  }
  mixed __mkdirhier = mkdirhier;	// Fool pike's type-checker.
  __mkdirhier("modules/"+rm[0], 0755);

  object o = open("modules/"+rm[0], "wct", 0644);
  if(!o) res += "Failed to open "+"modules/"+rm[0]+" for writing.<br>";
  else {
    o->write(rm[1]);
    res+="Fetched modules/"+rm[0]+", "+strlen(rm[1])+" bytes.<br>";
    report_notice("Upgraded "+rm[0]+".");
  }
  m_delete(roxen->allmodules, m);
  cache_remove("modules", m);

  foreach(roxen->configurations, object c)
    if(c->modules[m])
      if(!c->load_module(m))
	report_error("The newly upgraded module could not be reloaded!");
      else
	foreach(indices(c->modules[m]->copies||({"foo"})), int n)
	  if(!c->disable_module(m+"#"+n))
	    report_error("Failed to disable the module "+m+"#"+n);
	  else if(!(c->enable_module(m+"#"+n)))
	    error("Failed to enable module "+m+"#"+n+".\n");

  return res+"<p>\n\n\n";
}

/* Check for uninstalled components */
string page_3(object id)
{
  if(id->variables["new"]=="0" || !id->variables["new"])
    return 0;

 object rpc;
  catch {
    rpc=RoxenRPC.Client("skuld.infovav.se",23,"upgrade");
  };
  if(!rpc)
    return "Failed to connect to update server at skuld.infovav.se:23.\n";

  update_comps();
  string res=
    ("<font size=+1>Components that have a newer version available.</font><br>"
     "Select the box to add the component to the list of components to "
     "be updated\n<p>");


  mapping rm = rpc->all_components(roxen->real_version);
  array tbl = ({});
  int num;
  foreach(sort(indices(rm)), string s)
  {
    if(!comps[s] || (is_older(comps[s]->version, rm[s]->version)))
    {
      tbl += ({ ({
	"<input type=checkbox name=C_"+s+"> ",
	  rm[s]->name,
	  rm[s]->fname,
	  rm[s]->version,
	  (comps[s]?comps[s]->version:"New"),
	  ({"<font size=-1>"+doc+"</font>"}),
	  })});
    }
  }
  if(sizeof(tbl))
    return res + html_table(({"","Name","File","Available Version",
				"Your Version", ({"Doc"})}),
			    tbl);

  return "There are no new components available.";
}

/* Check for uninstalled modules */
string page_2(object id)
{
  object rpc;
  if(id->variables["new"]=="0" || !id->variables["new"])
    return 0;
  catch {
    rpc=RoxenRPC.Client("skuld.infovav.se",23,"upgrade");
  };
  if(!rpc)return "Failed to connect to update server at skuld.infovav.se:23.\n";

  string res=""
    "New modules that are available<br> "
    "Select the box to add the module to the list of modules to "
    "be updated</b><p>";

  find_modules(1);

  mapping rm = rpc->all_modules(roxen->real_version);
  int num;
  array tbl = ({});
  foreach(sort(indices(rm)), string s)
    if(!modules[s])
      tbl += ({({ "<font size=+1><var type=checkbox name=M_"+s+"> "+
	      rm[s]->name+"</font>",
		 "<font size=+1>"+rm[s]->filename+"</font>",
		    "<font size=+1>"+rm[s]->version+"</font>",
		    ({"<font size=-1>"+rm[s]->doc+"</font>"})})});
  if(sizeof(tbl))
    return res + html_table( ({"Name", "File", "Available Version",
				 ({ "Doc" })}), tbl );
  return "There are no new modules available";
}

/* Check for new versions of installed modules */
string page_1(object id)
{
  int num;
  object rpc;
  string res=
    ("<font size=+2>Modules that have a newer version available.</font><p>"
     "Select the box to add the module to the list of modules to "
     "be updated<p></b>\n");
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
		 modules[m]->name,
		   modules[m]->fname,		   
		   (mv[m]?mv[m]:"?"),
		   modules[m]->version})});
    }
  }
  if(num)
    return res + html_table ( ({ "", "Module", "File", "Available Version",
				   "Your Version"}), tbl );
  else
    return "There are no new versions of any of your installed modules "
           "available";
}

string upgrade_component(string m, object rpc)
{
  array rthingie = rpc->get_component(m,roxen->real_version);
  string res="";
  object privs = ((program)"privs")("Upgrading components","root");
  string ext="";
  if(!rthingie) return "Failed to fetch the component '"+m+"'.";

  if(Stdio.file_size(rthingie[0])>0)
  {
    mkdir("old_components");

    if( rthingie[0][strlen(rthingie[0])-5..] == ".pike" )
      ext = ".pike";
    
    if(mv(rthingie[0], "old_components/"+m+ext))
      res+="Moved "+rthingie[0]+" to old_components/"+m+ext+"<br>\n";
    else
      res+="Failed to move "+rthingie[0]+" to old_components/"+m+ext+"<br>\n";
  }
  object o = open(rthingie[0], "wct", 0644);
  if(!o) res += "Failed to open "+rthingie[0]+" for writing.<br>";
  else
  {
    o->write(rthingie[1]);
    res+="Fetched "+rthingie[0]+", "+strlen(rthingie[1])+" bytes.<br>";
    report_notice("Upgraded the component "+rthingie[0]+".");
  }
  return res+"<p>\n\n\n";
}


/* Present actions to be taken for the user */
array todo = ({});
string page_4(object id)
{
  filter_checkbox_variables(id->variables);
  todo = ({});
  foreach(sort(indices(id->variables)), string s)
  {
    string module;
    if(sscanf(s, "M_%s", module))
      todo+=({({"Upgrade the module "+module,upgrade_module, module,"RPC" })});
    else if(sscanf(s, "C_%s", module))
      todo+=({({"Upgrade "+module,upgrade_component,module,"RPC"})});
  }

  string res = "<font size=+1>Summary: These actions will be taken:</font><p>"
    "<ul>";
  foreach(todo, array a)
    res += "<li> "+a[0]+"\n";
  res += "</ul>";

  if(sizeof(todo)==0)
    res = "<font size=+1>Summary: No actions will be taken</font><p>";
    
  return res + "</ul>";
}


string wizard_done(object id)
{
  if(sizeof(todo)==0)
    return 0;
  
  object rpc;
  int t = time();
  string res = "<font size=+2>Upgrade report</font><p>";
  catch(rpc=RoxenRPC.Client("skuld.infovav.se",23,"upgrade"));
  if(rpc) foreach(todo, array a) res+=a[1](@replace(a[2..], "RPC", rpc));
  roxen->rescan_modules();
  res += "<p>Done in "+(time()-t)+" seconds.";
  return (html_border(res+
	  "<form action=/Actions/>"
	  "<input type=hidden name=action value=reloadconfiginterface.pike>"
	  "<input type=hidden name=unique value="+time()+">"
	  "<input type=submit value=' OK '>"
	  "</form>",0,5));
}


string handle(object id)
{
  return wizard_for(id,0);
}
