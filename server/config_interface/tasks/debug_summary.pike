/*
 * $Id: debug_summary.pike,v 1.9 2002/06/13 00:18:09 nilsson Exp $
 */
#include <stat.h>

constant task = "debug_info";
constant name = "Debug Summary";
constant doc  = ("Shows a text file containing a configuration summary, suitable "
		 "for support purposes.");

int creation_date = time();

int no_reload()
{
  return creation_date > file_stat( __FILE__ )[ST_MTIME];
}

string get_cvs_versions(string dir)
{
  string res="";
  foreach(sort(get_dir(dir)), string fn)
  {
    if(file_stat(dir+"/"+fn)->isdir && fn!="CVS")
      res+=get_cvs_versions(dir+"/"+fn);
    else
      res+=replace(dir+"/"+fn,
		   ({"//", "\\\\"}),
		   ({"/", "\\"}))+"\n";
  }
  return res;
}

string indent(string text, int level)
{
  array a=text/"\n";
  for(int i=0; i<sizeof(a); i++)
    if(sizeof(a[i]))
      a[i]="  "*level+a[i];
  return a*"\n";
}

string decomment(string text) {
  text -= "\r";
  while( sscanf(text, "%s#%*s\n%s", string a, string b)==3 )
    text = a + b;
  return text;
}

string describe_var_low(mixed value)
{
  if(arrayp(value))
    return "{"+map(value, describe_var_low)*", "+"}";
  else 
    return sprintf("%O", value);
}

string describe_var(mixed var)
{
  if(var->type=="Password" || var->type=="VerifiedPassword")
    return "***** (censored)";
  else
    return describe_var_low(var->query());
}

string make_headline(string title)
{
  return sprintf("%s:\n%s\n", title, "-"*(sizeof(title)+1));
}

string make_environment_summary()
{
  string res = make_headline("Environment");
  res+=sprintf("  %-30s %s\n", "Pike:", version());
  res+=sprintf("  %-30s %s\n", "Version:", roxen_version());
  res+=sprintf("  %-30s %s", "Time:", ctime(time()));
  res+=sprintf("  %-30s %s\n", "Host:", gethostname());
#ifdef __NT__
  res+=sprintf("  %-30s %s\n", "Platform:", "NT");
#else
  res+=sprintf("  %-30s %s %s %s\n", "Platform:",
	       uname()->sysname||"",
	       uname()->release||"",
	       uname()->machine);
#endif

  res += "\n";
  res += make_headline("Local environment variables");
#ifdef __NT__
  res += indent(decomment(Stdio.read_file("../local/environment.ini")||""), 1);
#else
  res += indent(decomment(Stdio.read_file("../local/environment")||""), 1);
#endif

  res += "\n";
  res += make_headline("System environment variables");
  foreach(sort(indices(getenv())), string envvar)
    res+=sprintf("  %-30s %s\n", envvar+":", getenv(envvar));
  
  return res;
}

string make_variables_summary(mapping vars)
{
  string res="";
  foreach(sort(indices(vars)), string varname)
    res+=sprintf("%s%-30s %s\n",
		 vars[varname]->is_defaulted()?"  ":" *",
		 varname+":",
		 describe_var(vars[varname]));
  return res;
}

string make_extra_module_info(RoxenModule module)
{
  if(module->debug_summary && functionp(module->debug_summary))
  {
    string res="\n"+make_headline("Extra info");
    mixed err=catch(res += indent(module->debug_summary(), 1));
    if(err)
      res+=describe_backtrace(err);
    return res;
  }
  return "";
}

string make_configuration_summary(string configuration)
{
  mixed c=roxen->find_configuration(configuration);
  mapping vars = c->getvars();
  string res = make_headline("Globals");
  res += make_variables_summary(c->getvars())+"\n\n";
  foreach(values(c->modules), mixed modulecopies)
    foreach(values(modulecopies->copies), RoxenModule module)
      res += sprintf("%s%s%s\n\n",
		     make_headline(module->module_identifier()),
		     make_variables_summary(module->getvars()),
		     indent(make_extra_module_info(module),1));
  return res;
}

string make_summary()
{
  string res = make_environment_summary()+"\n";

//    res +=make_headline("CVS file versions");
//    res +=indent(get_cvs_versions(getcwd()), 1);

  foreach(roxen->list_all_configurations(), string configuration)
  {
    res+=make_headline("Configuration: "+configuration)+"\n";
    res+=indent(make_configuration_summary(configuration),1);
  }
  return res;
}

mixed parse( RequestID id )
{
  string res;
  string debuglog = roxen_path("$LOGDIR/debug/default.1");

  if (id->variables->download &&
      id->variables->download == "summary") {
    res = make_headline("Debug summary")+"\n";
    res += make_summary();
    mapping ret = Roxen.http_string_answer(res, "application/octet-stream");
    ret["extra_heads"] = ([]);
    Roxen.add_http_header(ret["extra_heads"], "Content-Disposition",
			  "attachment; filename=debug-summary.txt");
    return ret;
  }
  else if (id->variables->download &&
	   id->variables->download == "debuglog") {
    string res = "---";
    object st = file_stat(debuglog);
    if (st && st->isreg)
      res = Stdio.read_file(debuglog);
    mapping ret = Roxen.http_string_answer(res, "application/octet-stream");
    ret["extra_heads"] = ([]);
    Roxen.add_http_header(ret["extra_heads"], "Content-Disposition",
			  "attachment; filename="+((debuglog/"/")[-1]));
    return ret;
  }
  
  res = "<h1>Debug summary</h1>\n";
  res += "<link-gbutton href='debug_summary.pike?download=summary'>Download"
    "</link-gbutton>";
  if (file_stat(debuglog))
    res += "<link-gbutton href='debug_summary.pike?download=debuglog'>"
      "Download debug log"
    "</link-gbutton>";

  res += "<pre>"+Roxen.html_encode_string(make_summary())+"</pre>";

  return res;
}
