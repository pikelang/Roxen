/*
 * $Id: problems.pike,v 1.13 1998/11/22 17:08:45 per Exp $
 */

inherit "wizard";
inherit "configlocale";

constant name="Maintenance//Check your Roxen configuration for problems...";
constant doc="Perform several sanity-checks of your configuration.";
constant wizard_name="Check configuration";

constant name_svenska="Underhåll//Leta fel i dina roxeninställingar...";
constant doc_svenska="Utför flera olika kontroller av dina roxeninställingar.";
constant wizard_name_svenska = "Kontrollera inställingar";


string page_0(object id)
{
  return LOCALE()->problems_page0();
}

mapping mod_recursed = ([]), mod_problems = ([]), mod_identifiers = ([]);

#define DIR_DONT_EXIST 1
#define MOD_DOUBLE 2

void module_recurse_dir(string dir)
{
  if(mod_recursed[dir]) return;
  mod_recursed[dir]=1;
  array d = get_dir(dir);
  string res="";
  array to_recurse = ({});
  string current_check;
  if(d && (search(d, ".no_modules")!=-1)) return;
  if(!d)
  {
    mod_problems[dir] = DIR_DONT_EXIST;
    return;
  }
  foreach(d, string f)
  {
    string rf = f;
    if(f[-1]=='~' || f[0]=='.' || sscanf(f, "%*s.pmod") || f=="CVS")
      continue;
    if(Stdio.file_size(dir+f) < 0)
      to_recurse += ({ dir+f+"/" });
    else if(sscanf(f, "%s.pike", f) ||
	    sscanf(f, "%s.lpc", f) ||
	    sscanf(f, "%s.so", f))
      if(mod_identifiers[f])
	mod_problems[dir+rf] = ({ MOD_DOUBLE, mod_identifiers[f] });
      else
	mod_identifiers[f] = dir+rf;
  }
  foreach(to_recurse, string f)
    module_recurse_dir(f);
}

// Check modules in module path.
string page_1(object id)
{
  mod_recursed = ([]); mod_identifiers = ([]); mod_problems = ([]);
  foreach(roxen->query("ModuleDirs"), string dir) module_recurse_dir(dir);

  if(mod_problems)
  {
    string res = html_notice(LOCALE()->problem_checking_modules(),id);
    foreach(indices(mod_problems), string n)
    {
      if(mod_problems[n]==DIR_DONT_EXIST)
      {
#if constant(readlink)
	int in_main_path;
	string symlink;
	if(search(roxen->query("ModuleDirs"), n)+1)
	  in_main_path = 1;
	if(array a=file_stat(n, 1))
	  if(a[1]<-1) {
	    symlink = readlink(n);
	  }

	if(symlink)
	  res+=html_error(LOCALE()->problem_symlink(symlink,n,in_main_path)
			  ,id);
	else
#endif /* constant(readlink) */
	  res+=html_error(LOCALE()->problem_nodir(n),id);
      } else {
	res+=html_warning(LOCALE()->problem_double_module(n,mod_problems),id);
      }
    }
    res +=html_notice(LOCALE()->
		      problem_scannedinfo(sizeof(mod_recursed),
					  sizeof(mod_identifiers)),id);
    return res;
  }
  return
    html_notice(LOCALE()->problem_scannedinfo(sizeof(mod_recursed),
					      sizeof(mod_identifiers))+
		LOCALE()->problem_nope(),id);
}

string page_2(object id)
{
  int errs;
  string res="<font size=+1>"+LOCALE()->problem_checking_servers()+"</font><p>";
  foreach(roxen->configurations, object c)
  {
    res+=html_notice("<b>"+LOCALE()->problem_checking()+" "+
		     (strlen(c->query("name"))?
		      c->query("name"):c->name)+"</b>",id);
    if(c->query("Log") && strlen(c->query("LogFile")) && !c->log_function)
    {
      errs++;
      res += html_warning(LOCALE()->problem_nologfile(c), id);
    }
    if(sizeof(c->query("NoLog")) && (search(c->query("NoLog"), "*")!=-1))
    {
      errs++;
      res +=
	html_warning(LOCALE()->problems_logstar(c),id);
    }

    foreach(sort(indices(roxen->retrieve("EnabledModules",c))), string m)
    {
      sscanf(m,"%s#",m);
      if(!c->modules[m])
      {
	errs++;
	res += html_warning(LOCALE()->problem_begone(m,c),id);
      } else {
	// Check the module?
      }
    }
  }
  if(!errs) res+="<p>"+LOCALE()->problems_nope();
  return res;
}


#include <roxen.h>
#include <config.h>
string page_3(object id)
{
  filter_checkbox_variables(id->variables);
  int errs;
  string res="<font size=+1>"+LOCALE()->problem_globals()+"</font><p>";

  if(roxen->query("NumAccept")>16 && sizeof(roxen->configurations)>1)
  {
    errs++;
    res += html_warning(LOCALE()->problem_idinum()+" <var type=select name=\""
			"mod_cvar_G/NumAccept\" choices=1,2,4,8,16,"+
			roxen->query("NumAccept")+" "
			"default="+roxen->query("NumAccept")+"><br>",id);
  }
  
  string user;
  if(strlen(user=roxen->query("User")))
  {
    string u,g;
    if(getuid())      
    {
      res += html_warning(LOCALE()->problem_nouser()+user,id);
    }
    sscanf(user, "%s:%s", u, g);

#if constant(getpwnam)
    array pw;
    if(!(pw = getpwnam(u+"")) && (int)u)
      pw = getpwuid((int)u);

    if(!pw)
      res += html_warning(LOCALE()->problem_reallynouser(user)+
			  "<var name=mod_cvar_G/User size=20,1 default='"+user+
			  "'>",id);
#endif
  }


#ifdef THREADS
  
#endif

  
  if(!errs) res+="<font size=+1>"+LOCALE()->problem_nope()+"</font>";
  return res;
}

void remove_module_dir(string dir)
{
  roxen->set("ModuleDirs", roxen->query("ModuleDirs")-({dir}));
}

array fix_array(array in)
{
  array res = ({});
  foreach(in, string q)
    if(strlen(((replace(q,"\t", " ")-" ")-"\r")-"\n"))
      res += ({ q });
  return res;
}

void modify_variable(string v, string to)
{
  string c;
  sscanf(v, "%s/%s", c, v);
  if(c=="G")
  {
    if(arrayp(roxen->query(v))) roxen->set(v,fix_array(to/"\0"-({""})));
    else if(intp(roxen->query(v))) roxen->set(v,(int)to);
    else if(floatp(roxen->query(v))) roxen->set(v,(float)to);
    else  roxen->set(v,to);
    roxen->store("Variables", roxen->variables, 0, 0);
    return;
  } else {
    foreach(roxen->configurations, object co)
      if(co->name == c)
      {
	if(arrayp(co->query(v))) co->set(v,fix_array(to/"\0"-({""})));
	else if(intp(co->query(v))) co->set(v,(int)to);
	else if(floatp(co->query(v))) co->set(v,(float)to);
	else  co->set(v,to);
	co->save(1);
      }
  }
}

void remove_module(string m)
{
  string c;
  sscanf(m, "%s/%s", c, m);
  foreach(roxen->configurations, object co)
    if(co->name == c)
    {
      mapping en = roxen->retrieve("EnabledModules",co);
      foreach(indices(en), string q)
      {
	if(!search(q,m))
	{
	  roxen->remove(q,co);
	  m_delete(en,q);
	}
      }	
      roxen->store("EnabledModules", en, 1, co);
    }
}

array actions = ({ });
string page_4(object id)
{
  filter_checkbox_variables(id->variables);
  return LOCALE()->problem_summary( id, this_object() );
}

string wizard_done(object id)
{
  if(actions)
  {
    object o = ((program)"privs")("Fixing config");
    mkdir("disabled_modules");
    foreach(actions, array action) action[1](@action[2..]);
  }
}

string handle(object id)
{
  return wizard_for(id,0);
}
