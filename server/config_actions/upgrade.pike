/*
 * $Id: upgrade.pike,v 1.36 1998/06/07 21:35:05 peter Exp $
 */
constant name= "Maintenance//Upgrade components...";
constant doc = "Selectively upgrade Roxen components from an upgrade server of your choice.";

inherit "wizard";

#if constant(thread_create)
object rpc_lock = Thread.Mutex();
#endif /* constant(thread_create) */

object _rpc;
string rpc_to;
void clear_rpc()
{
#if constant(thread_create)
  mixed key;
  catch { key = rpc_lock->lock(); };
#endif /* constant(thread_create) */
  destruct(_rpc);
  _rpc = 0;
}

mapping upgrade_servers = ([]);
object connect_to_rpc(object id)
{
#if constant(thread_create)
  mixed key;
  catch { key = rpc_lock->lock(); };
#endif /* constant(thread_create) */
  remove_call_out(clear_rpc);
  call_out(clear_rpc, 20);

  mapping v = id->variables;
  if(_rpc && rpc_to == v->rpc_host)
    if(!catch { _rpc->module_version(([]),"PING"); }) return _rpc;
  catch
  {
    string host,port, rpc_host;
    rpc_host = upgrade_servers[v->rpc_host]||"";
    sscanf(rpc_host, "%s:%d", host, port);
    _rpc=RoxenRPC.Client(host||"skuld.idonex.se",port||23,"upgrade");
    rpc_to = v->rpc_host;
  };
  return _rpc;
}

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
  foreach(get_dir(d)||({}), string f)
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
	if (version) {
	  werror(fname + " Version: " + version + "\n");
	} else {
	  werror("No version info in \"" + fname + "\"\n");
	}
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

string upgrade_server_help="";
array (string) upgrade_server_list()
{
  upgrade_server_help="<b>Upgrade servers</b><dl>";
  array res=({});
  string|array servers = Stdio.read_bytes("etc/upgrade_servers");
  if (servers) {
    servers = Array.filter(servers/"\n", lambda(string l) {
      return sizeof(l) && (l[0] != '#');
    });
  }
  if (servers && sizeof(servers)) {
    foreach(servers, string l) {
      l = ((l/"\t")-({""}))*"\t";
      string server, help, url;
      sscanf(l, "%s\t%s\t%s", server, url, help);
      res += ({ server });
      upgrade_servers[server]=url;
      upgrade_server_help+="<dt compact><b>"+server+"</b><dd>"+help+"\n";
    }
    upgrade_server_help += "</dl>";
  } else {
    return ({ "Official Server" });
  }
  return res;
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
     
     "<var type=checkbox name=new> Also search for new components\n<br>"
     "<p>Use this upgrade server: <var type=select name=rpc_host default='skuld.idonex.se:23' "
     "choices='"+upgrade_server_list()*","+"'><p>"+upgrade_server_help );
}

string upgrade_module(string m, object rpc)
{
  array rm = rpc->get_module(m,roxen->real_version);
  string res="";
  object privs = ((program)"privs")("Upgrading modules");
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

  mixed __open = open;			// Fool pike's type-checker.
  object o = __open("modules/"+rm[0], "wct", 0644);
  if(!o) res += "Failed to open "+"modules/"+rm[0]+" for writing.<br>";
  else {
    o->write(rm[1]);
    res+="Fetched modules/"+rm[0]+", "+strlen(rm[1])+" bytes.<br>";
    report_notice("Upgraded "+rm[0]+".\n");
  }
  if (roxen->allmodules) {
    m_delete(roxen->allmodules, m);
  }
  cache_remove("modules", m);

  foreach(roxen->configurations, object c)
    if(c->modules[m])
      if(!c->load_module(m))
	report_error("The newly upgraded module could not be reloaded!\n");
      else
	foreach(indices(c->modules[m]->copies||({"foo"})), int n)
	  if(!c->disable_module(m+"#"+n))
	    report_error("Failed to disable the module "+m+"#"+n+"\n");
	  else if(!(c->enable_module(m+"#"+n)))
	    error("Failed to enable module "+m+"#"+n+".\n");

  return res+"<p>\n\n\n";
}

/* Check for new versions of installed modules */
string page_1(object id)
{
  int num;
#if constant(thread_create)
  mixed key;
  catch { key = rpc_lock->lock(); };
#endif /* constant(thread_create) */
  object rpc;
  string res=
    ("<font size=+2>Modules that have a newer version available.</font><p>"
     "Select the box to add the module to the list of modules to "
     "be updated<p></b>\n");
  object rpc = connect_to_rpc(id);
  if(!rpc) return "Failed to connect to update server.\n";

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
           "available on this server.";
}

/* Check for uninstalled modules */
string page_2(object id)
{
  if(id->variables["new"]=="0" || !id->variables["new"])
    return 0;
#if constant(thread_create)
  mixed key;
  catch { key = rpc_lock->lock(); };
#endif /* constant(thread_create) */
  object rpc = connect_to_rpc(id);
  if(!rpc) return "Failed to connect to update server.\n";

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

/* Check for uninstalled components */
string page_3(object id)
{
  if(id->variables["new"]=="0" || !id->variables["new"])
    return 0;
#if constant(thread_create)
  mixed key;
  catch { key = rpc_lock->lock(); };
#endif /* constant(thread_create) */

 object rpc = connect_to_rpc(id);
 if(!rpc) return "Failed to connect to update server.\n";


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
	  ({"<font size=-1>"+rm[s]->doc+"</font>"}),
	  })});
    }
  }
  if(sizeof(tbl))
    return res + html_table(({"","Name","File","Available Version",
				"Your Version", ({"Doc"})}),
			    tbl);

  return "There are no new components available.";
}


string upgrade_component(string m, object rpc)
{
  array rthingie = rpc->get_component(m,roxen->real_version);
  string res="";
  object privs = ((program)"privs")("Upgrading components");
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
  mixed __open = open;			// Fool pike's type-checker.
  object o = __open(rthingie[0], "wct", 0644);
  if(!o) res += "Failed to open "+rthingie[0]+" for writing.<br>";
  else
  {
    o->write(rthingie[1]);
    res+="Fetched "+rthingie[0]+", "+strlen(rthingie[1])+" bytes.<br>";
    report_notice("Upgraded the component "+rthingie[0]+".\n");
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
  
#if constant(thread_create)
  mixed key;
  catch { key = rpc_lock->lock(); };
#endif /* constant(thread_create) */
  object rpc;
  int t = time();
  string res = "<font size=+2>Upgrade report</font><p>";
  object rpc = connect_to_rpc(id);
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
