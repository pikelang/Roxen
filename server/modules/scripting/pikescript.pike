#include <config.h>

// This is a roxen module. (c) Informationsv�varna AB 1996.

// Support for user Pike-scripts, like CGI, but handled internally in
// the server, and thus much faster, but blocking, and somewhat less
// secure.

// This is an extension module.

mapping scripts=([]);

inherit "module";
inherit "roxenlib";
string cvs_version = "$Id: pikescript.pike,v 1.9 1997/03/26 05:54:16 per Exp $";
#include <module.h>

mixed *register_module()
{
  return ({ 
    MODULE_FILE_EXTENSION,
    "Pike script support", 
    "Support for user Pike-scripts, like CGI, but handled internally in the"
    " server, and thus much faster, but blocking, and somewhat less secure."
    });
}

void create()
{
  defvar("exts", ({ "lpc", "ulpc", "�lpc","pike" }), "Extensions", TYPE_STRING_LIST,
	 "The extensions to parse");
  
#if efun(set_max_eval_time)
  defvar("evaltime", 4, "Maximum evaluation time", TYPE_INT,
	 "The maximum time (in seconds) that a script is allowed to run for. "
	 "This might be changed in the script, but it will stop most mistakes "
	 "like i=0; while(i<=0) i--;.. Setting this to 0 is not a good idea.");
#endif
}

string comment()
{
  return query("exts")*" "+": " + sizeof(scripts)+" compiled programs";
}

array (string) query_file_extensions()
{
  return QUERY(exts);
}

mapping locks = ([]);

array|mapping call_script(function fun, object got, object file)
{
  mixed result, err;
  string s;
  object privs;
  if(!functionp(fun))
    return 0;
  array (int) uid, olduid, us;

  if(got->misc->is_user && (us = file_stat(got->misc->is_user)))
    privs = ((program)"privs")("Executing pikescript as non-www user",@us[5..6]);

  if(sizeof(got->variables))
    foreach(indices(got->variables), s)
      got->variables[s] = replace(got->variables[s], "\000", " ");
  
#ifdef THREADS
  if(!locks[fun])
    locks[fun]=Mutex();
  object key = locks[fun]->lock();
#endif

#if efun(set_max_eval_time)
  if(catch {
    set_max_eval_time(query("evaltime"));
#endif
    err=catch(result=fun(got)); 
// The eval-time might be exceeded in here..
#if efun(set_max_eval_time)
    remove_max_eval_time(); // Remove the limit.
  })
    remove_max_eval_time(); // Remove the limit.
#endif

  if(privs) destruct(privs);
  
  if(err)
    return ({ -1, err });

  if(stringp(result))
    return http_string_answer(parse_rxml(result, got, file));

  if(result == -1) return http_pipe_in_progress();

  if(mappingp(result))
  {
    if(!result->type)
      result->type="text/html";
    return result;
  }

  if(objectp(result))
    return result;

  if(!result) return 0;

  return http_string_answer(sprintf("%O", result));
}

void my_error(array err, string|void a, string|void b)
{
  err[0] = ("<font size=+1>"+(b||"Error while executing code in pike script")
	    + "</font><br><p>" +(err[0]||"") + (a||"")
	    + "<br><p>The pike Script will be reloaded automatically.\n");
  throw(err);
}

mapping handle_file_extension(object f, string e, object got)
{
  string file="";
  string s;
  mixed err;
  program p;
  object o;

  if(scripts[got->not_query])
  {
    if(got->pragma["no-cache"])
    {
      // Reload the script from disk, if the script allows it.
      if(!(function_object(scripts[got->not_query])->no_reload
	   && function_object(scripts[got->not_query])->no_reload(got)))
      {
	destruct(function_object(scripts[got->not_query]));
	scripts[got->not_query] = 0;
      }
    }
  }

  if(scripts[ got->not_query ])
  {
    err=call_script(scripts[got->not_query], got, f);
    destruct(f);
    if(arrayp(err))
    {
      destruct(function_object(scripts[got->not_query]));
      scripts[got->not_query] = 0;
      my_error(err[1]); // Will interrupt here.
    }
    return err;
  }
  file=f->read(655565);


  array (function) ban = allocate(5, "function");
  ban[0] = setegid;
  ban[1] = setgid;
  ban[2] = seteuid;
  ban[3] = setuid;

  add_constant("setegid", 0);
  add_constant("seteuid", 0);
  add_constant("setgid", 0);
  add_constant("setuid", 0);

  _master->set_inhibit_compile_errors("");
  err=catch(p=compile_string(file, "Script:"+got->not_query));
  if(strlen(_master->errors)) 
    s=_master->errors + "\n\n" + s;
  _master->set_inhibit_compile_errors(0);

  add_constant("setegid", ban[0]);
  add_constant("seteuid", ban[2]);
  add_constant("setgid", ban[1]);
  add_constant("setuid", ban[3]);
  
  if(err)
  {
    destruct(f);
    my_error(err, got->not_query+":\n"+(s?s+"\n\n":"\n"), 
	     "Error while compiling pike script:<br>\n\n");
  }
  if(!p) 
  {
    destruct(f);
    return http_string_answer("<h1>While compiling pike script</h1>\n"+s);
  }
  o=p();
  scripts[got->not_query]=o->parse;
  err=call_script(o->parse, got, f);
  destruct(f);
  if(arrayp(err))
  {
    destruct(function_object(scripts[got->not_query]));
    scripts[got->not_query] = 0;
    my_error(err[1]); // Will interrupt.
  }
  return err;
}

string status()
{
  string res="", foo;

  if(sizeof(scripts))
  {
    res += "<hr><h1>Loaded scripts</h1><p>";
    foreach(indices(scripts), foo )
      res += foo+"\n";
  } else {
    return "<h1>No loaded scripts</h1>";
  }
  res += "<hr>";

  return ("<pre><font size=+1>" + res + "</font></pre>");
}


void start() {}





