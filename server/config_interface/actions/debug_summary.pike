/*
 * $Id$
 */
#include <stat.h>
#include <roxen.h>
//<locale-token project="admin_tasks">LOCALE</locale-token>
#define LOCALE(X,Y)     _DEF_LOCALE("admin_tasks",X,Y)

constant action = "debug_info";

LocaleString name= LOCALE(163,"Debug summary");
LocaleString doc = LOCALE(164,
                    "Shows a text file containing a configuration summary, suitable "
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
  res+=sprintf("  %-30s %s\n", "Roxen version:", roxen_version());
  res+=sprintf("  %-30s %s\n", "Pike version:", version());
  res+=sprintf("  %-30s %s\n", "Logical server directory:", roxenloader.server_dir);
  res+=sprintf("  %-30s %s\n", "Physical working directory:", getcwd());
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
  res += make_headline("Autoconfigured environment settings (local/environment)");
#ifdef __NT__
  res += indent(Stdio.read_file("../local/environment.ini")||"", 1);
#else
  res += indent(Stdio.read_file("../local/environment")||"", 1);
#endif

  res += "\n";
  res += make_headline("Local environment settings (local/environment2)");
#ifdef __NT__
  res += indent(Stdio.read_file("../local/environment2.ini")||"", 1);
#else
  res += indent(Stdio.read_file("../local/environment2")||"", 1);
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
                     make_headline(module->module_identifier() || "?"),
                     make_variables_summary(module->getvars()),
                     indent(make_extra_module_info(module),1));
  return res;
}

string make_global_summary()
{
  string res = make_headline("Global Variables");
  res += make_variables_summary(roxen->getvars());
  return res + "\n";
}

string make_summary()
{
  string res = make_environment_summary()+"\n";

//    res +=make_headline("CVS file versions");
//    res +=indent(get_cvs_versions(getcwd()), 1);

  res += make_global_summary();

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
  string debuglog = roxen_path("$LOGFILE");

  if (id->variables->download &&
      id->variables->download == "summary") {
    res = make_headline(LOCALE(163,"Debug summary"))+"\n";
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

  res = "<cf-title>"+LOCALE(163,"Debug summary")+"</cf-title>";
  res += "<link-gbutton href='debug_summary.pike?download=summary&amp;&usr.set-wiz-id;'>"+
         LOCALE(41,"Download") +
         "</link-gbutton>";

  if (file_stat(debuglog)) {
    res += "<link-gbutton href='debug_summary.pike?download=debuglog&amp;&usr.set-wiz-id;'>"+
           LOCALE(153,"Download Debug Log")+
           "</link-gbutton>";
  }

  res +=
    "<hr class='section'>"
    "<div class='scrollable pre margin-top'>"+
    Roxen.html_encode_string(make_summary())+
    "</div>"
    "<br />"
    "<cf-ok/>";

  return res;
}
