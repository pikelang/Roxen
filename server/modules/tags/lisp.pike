#define error(X) throw( ({ (X), backtrace() }) )
constant cvs_version = "$Id: lisp.pike,v 1.7 1998/02/11 01:31:30 nisse Exp $";

#include <module.h>
inherit "module";

constant thread_safe=1;

array register_module()
{
  return ({ MODULE_PARSER, "Lisp tag module", 
	    "This module defines a new tag, "
	    "&lt;lisp [context=foo]&gt;&lt;/lisp&gt;", 0, ({}) });
}

void create()
{
  defvar("max-eval-time", 10000, "Max eval time", TYPE_INT);
  
  defvar("bootcode", "(begin)", 
	 "Lisp code executed to initialize the top-level environments.",
	 TYPE_TEXT);

  defvar("enable_context", 1, "Enable the context attribute.",
	 TYPE_FLAG);
}

import Languages.PLIS;

class RoxenEnv
{
  import Languages.PLIS;

  inherit Environment;

  int once_done;
}

/* This contains request specific data */
class RoxenId
{
  import Languages.PLIS;

  object lisp_env;
  int limit;
  
  object roxen_id;
  mapping defines;
  string lisp_result;
    
  int limit_apply()
    {
      if (!limit)
	return 1;
      limit--;
      return 0;
    }

  object query_binding(object symbol) { return lisp_env->query_binding(symbol); }
  
  object copy() { return lisp_env->copy(); }
  
  object extend(object symbol, object value)
    {
      return lisp_env->extend(symbol, value);
    }

  string print(int display)
    // { return "Global roxen environment"; }
    { return lisp_env->print(display); }

  void create(object env, object id, mapping defs)
    {
      lisp_env = env;
      roxen_id = id;
      defines = defs;
      lisp_result = "";
    }
}

class API_Function
{
  import Languages.PLIS;
  
  inherit LObject;
  function fun;
  array types;
  
  string print(int display) { return sprintf("API_Function %O", fun); }

  object to_lisp(mixed o)
    {
      if(stringp(o)) 
	return String( o );

      if(intp(o) && !zero_type(o)) 
	return Number(o);

      if(arrayp(o) || multisetp(o))
      {
	object res = Lempty;
	int m = 0;
	if(multisetp(o)) { m = 1; o = indices( o ); }
	for(int i=sizeof(o)-1; i>=0; i--)
	{
	  object t;
	  if(m && stringp(o[i]))
	    t =  make_symbol( o[i] );
	  else
	    t =  to_lisp(o[i]);
	  res = Cons( t , res );
	}
	return res;
      }
      return Lfalse;
    }

  object apply(object arglist, object env, object globals)
    {
      object id;
      
      if (!globals->roxen_id)
	return 0;

      array args = ({ });
      int i = 0;
      int optional;
      
      while(arglist != Lempty)
      {
	if (i == sizeof(types))
	{
	  if (!optional)
	    return 0;
	  else
	    break;
	}
	
	switch(types[i])
	{
	case 0: /* Any arguments left are optional */
	  optional = 1;
	  i++;
	  break;
	case "string":
	  if (!arglist->car->is_string)
	    return 0;
	  args += ({ arglist->car->value });
	  arglist = arglist->cdr;
	  break;
	case "int":
	  if (!arglist->car->is_number)
	    return 0;
	  args += ({ (int) arglist->car->value });
	  arglist = arglist->cdr;
	  break;
	default:
	  error(sprintf("API_Function: Unexpected type '%s'\n", types[i]));
	}
	i++;
      }

      return to_lisp(fun(globals->roxen_id, @args));
    }
  
  void create(array a)
    {
      [ fun, types ] = a;
    }
}

mapping environments;
mapping(string:object) lisp_code;
object boot_code;

void start()
{
  werror("Lisp: starting...\n");
  boot_code = Parser( query("bootcode") )->read();
  werror(sprintf("Read boot_code: %s\n",
		 boot_code ? boot_code->print(1) : "<error>"));
  environments = ([]);
  lisp_code = ([]);
}

void init_environment(object e, object conf)
{
  init_specials(e);
  init_functions(e);
  
  init_roxen_functions(e, conf);
  default_boot_code->eval(e, e);
  boot_code->eval(e,e);
}

object find_environment(string f, object conf)
{
  if(environments[f]) 
  {
    return environments[f];
  }

  environments[f] = RoxenEnv();
  init_environment( environments[f], conf );
  return environments[f];
}

object lisp_compile(string s)
{
  object o = lisp_code[s];
  if (o)
    return o;
  o = Parser("(begin\n" + s + " )")->read();
  lisp_code[s] = o;
  return o;
}

string tag_lisp(string t, mapping m, string c, 
		object id, object f, mapping defines)
{
  string context = (query("enable_context") && m->context)
    || id->not_query;
  object e = find_environment(context, id->conf);
  // werror(sprintf("Environment: %s\n", e->print(1)));
  if(m->once && e->once_done) return "";

  object lisp = lisp_compile(c);
  if (!lisp)
    return "<!-- syntax error in lisp code -->\n";
  
  object globals = RoxenId(e, id, defines);

  globals->limit = query("max-eval-time");
  lisp->eval( e, globals );

  if (m->once)
    e->once_done = 1;
  return globals->lisp_result;
}

mapping query_container_callers()
{
  return ([ "lisp":tag_lisp, ]);
}

#if 0
object f_get_id_int(object arglist, object env, object globals)
{
  object id = globals->roxen_id;
  if (id && arglist->car->is_string)
    return Number( (int)globals->id[arglist->car->value] );
  else
    return 0;
}


object f_get_id(object arglist, object env, object globals)
{
  mixed val = globals->id[arglist->car->value];

  if(stringp(val))
     return String( globals->id->variables[arglist->car->value] );
  if(intp(val) && !zero_type(val))
     return Number( globals->id->variables[arglist->car->value] );

  if(arrayp(val) || multisetp(val))
  {
    object res = Nil;
    int m;
    if(multisetp(val)) { m = 1; val = indices( val ); }
    for(int i=sizeof(val)-1; i>=0; i--)
    {
      object t;
      if(m)
	t = make_symbol( (string)val[i] );
      else
	t = stringp(val[i])?String(val[i]):Number((int)val[i]);
      res = Cons( t , res );
    }
    return res;
  }
  return Nil;
}
#endif

/* Returns a string, instead of outputting it directly.
 * Usually, you want to html-quote it before output. */
object f_display(object arglist, object env, object globals)
{
  if (!globals->lisp_result)
    return 0;
  return String(arglist->car->print(1) + "\n");
  return Lfalse;
}


object f_get(object arglist, object env, object globals)
{
  object id = globals->roxen_id;
  werror(sprintf("lisp.pike->f_get %s\n", arglist->print(1)));
  if (!id)
    return 0;
  werror("lisp.pike->f_get: id ok\n");

  if (!arglist->car->to_string)
    return 0;

  string name = arglist->car->to_string();

  if (!name)
    return 0;

  werror(sprintf("lisp.pike->f_get: name '%s'\n", name));

  string res = id->variables[name];
  if (res)
  {
    werror(sprintf("lisp.pike->f_get: variable = '%s'\n", res));
    return String(res);
  }

  res = id->misc->defines[name];
  if (res)
  {
    werror(sprintf("lisp.pike->f_get: define = '%s'\n", res));
    return String(res);
  }

  return Lfalse;
}

object f_getint(object arglist, object env, object globals)
{
  object id = globals->roxen_id;
  if (!id)
    return 0;
  if(id->variables[arglist->car->value])
    return Number( (int)id->variables[arglist->car->value] );
  if(id->misc->defines[arglist->car->value])
    return Number( (int)id->misc->defines[arglist->car->value] );
  return Lfalse;
}

object f_write(object arglist, object env, object globals)
{
  if (!globals->lisp_result)
    return 0;
  
  int len = 0;

  while(arglist != Lempty)
  {
    string s = arglist->car->print(0);
    len += strlen(s);
    globals->lisp_result += s;
    arglist = arglist->cdr;
  }

  return Number( len );
}

#if 0
object f_format(object arglist, object env, object globals)
{
  string f = arglist->car->value;
  array args=({});
  while( !(arglist = arglist->cdr)->is_nil)  
  {
    if(objectp(arglist->car->value))
      args+=({(int)arglist->car->value});
    else
      args+=({arglist->car->value});
  }
  if(!stringp(f)) {
    return 0;
  }
  return String( sprintf(f, @args) );
}

object f_line_break(object arglist, object env, object globals)
{
  string f = arglist->car->print();
  int n = (arglist->cdr && (int)arglist->cdr->car->value) || 75;
  string res = "";
  while(strlen(f))
  {
    res += f[..n-1]+"\n";
    f = f[n..];
  }
  return String( res );
}
#endif

void init_roxen_functions(object environment, object conf)
{
  // environment->extend(make_symbol("format"), Builtin(f_format));

  environment->extend(make_symbol("r-get-string"), Builtin(f_get));
  environment->extend(make_symbol("r-get-int"), Builtin(f_getint));
  environment->extend(make_symbol("write"), Builtin(f_write));
  environment->extend(make_symbol("display"), Builtin(f_display));
  
  // environment->extend(make_symbol("line-break"), Builtin(f_line_break));
  // environment->extend(make_symbol("read"), Builtin(f_read));
  // environment->extend(make_symbol("print"), Builtin(f_print));
  // environment->extend(make_symbol("princ"), Builtin(f_print));
  // environment->extend(make_symbol("eval"), Builtin(f_eval));
  // environment->extend(make_symbol("apply"), Builtin(f_apply));
  // environment->extend(make_symbol("global-environment"), environment);
  // environment->extend(make_symbol("car"), Builtin(f_car));
  // environment->extend(make_symbol("cdr"), Builtin(f_cdr));
  // environment->extend(make_symbol("setcar!"), Builtin(f_setcar));
  // environment->extend(make_symbol("setcdr!"), Builtin(f_setcdr));
  // environment->extend(make_symbol("cons"), Builtin(f_cons));
  // environment->extend(make_symbol("list"), Builtin(f_list));
  
  mapping m = conf->api_functions();
  foreach(indices(m), string f)
    environment->extend(make_symbol("r-" + replace(f, "_", "-")),
			API_Function( m[f] ));
}


