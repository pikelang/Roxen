#define error(X) throw( ({ (X), backtrace() }) )
constant cvs_version = "$Id: lisp.pike,v 1.1 1998/01/29 14:21:41 per Exp $";

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
  
  defvar("bootcode", 
"(progn\n"
"  (defmacro (cddr x)\n"
"    (list (quote cdr) (list (quote cdr) x)))\n"
"  (defmacro (cadr x)\n"
"    (list (quote car) (list (quote cdr) x)))\n"
"  (defmacro (cdar x)\n"
"    (list (quote cdr) (list (quote car) x)))\n"
"  (defmacro (caar x)\n"
"    (list (quote car) (list (quote car) x)))\n"
"\n"
"  (defmacro (defun name arguments . body) (cons (quote define) (cons (cons name arguments) body)))\n"
"\n"
"  (defmacro (when cond . body)\n"
"    (list (quote if) cond\n"
"	  (cons (quote progn) body)))\n"
"  \n"
"  (define (mapcar fun list)\n"
"    (if list (cons (fun (car list))\n"
"		   (mapcar fun (cdr list)))\n"
"      nil))\n"
"\n"
"  (defmacro (let decl . body)\n"
"    (cons (cons (quote lambda)\n"
"		(cons (mapcar car decl) body))\n"
"	  (mapcar cadr decl))))",
	 "Boot code for the lisp interpreter",
	 TYPE_TEXT);
}

object parse(string s);

void start()
{
  boot_code = parse( query("bootcode") );
}

void init_for(object e);

mapping environs = ([]);
program E = this_object()->Environment;
object find_environment(string f)
{
  if(environs[f]) return environs[f];
  environs[f] = E();
  init_for( environs[f] );
  return environs[f];
}

string tag_lisp(string t, mapping m, string c, 
		object id, object f, mapping defines)
{
  object lisp = parse( "(progn\n"+c+")" );
  object e = find_environment(m->context||id->not_query);
  id->misc->lisp_result="";
  e->id = id;
  e->eval_limit = query("max-eval-time");
  lisp->eval( e, e );
  return (id->misc->lisp_result);
}

mapping query_container_callers()
{
  return ([ "lisp":tag_lisp, ]);
}




class lisp_types
{
  /* Data shared between all Lisp objects */
  mapping symbol_table = ([ ]);
  object Nil = NilSymbol(symbol_table);
  object True = ConstantSymbol("t", symbol_table);


  class LObject 
  {
  }

  class SelfEvaluating 
  {
    inherit LObject;
    object eval(object env, object globals)
    {
      return this_object();
    }
  }

  class Cons 
  {
    inherit LObject;
  
    object car;
    object cdr;

    void create(object a, object d)
    {
      car = a; cdr = d;
    }

    object mapcar(string|function fun, mixed ...extra)
    {
      object new_car, new_cdr;
      new_car = stringp(fun)? car[fun](@extra) : fun(car, @extra);
      if (!new_car)
      {
	error("No car");
      }
    
      object new_cdr = (!cdr->is_nil) ? cdr->mapcar(fun, @extra)
	: cdr;
      if (cdr) 
	return object_program(this_object())(new_car, new_cdr);
      else
      {
	error("No cdr");
      }
    }
  
    object map(string|function fun, mixed ...extra)
    {
      /* Do this as a special case to allow tail recursion */
      if (!cdr || cdr->is_nil) 
      {
	if (stringp(fun))
	  return car[fun](@extra);
	else
	  return fun(car, @extra);
      }
      if (stringp(fun) ? car[fun](@extra) : fun(car, @extra))
	return cdr->map(fun, @extra);
      else
	error("Unknown function");

    }
  
    string print()
    {
      string s = "(";
      object p = this_object();
      while (!p->is_nil)
      {
	if (!p->car)
	{ /* Not a cons cell */
	  s += " . " + p->print();
	  break;
	}
	s += " " + p->car->print();
	p = p->cdr;
      }
      s += " )";
      return s;
    }
  
    object eval(object env, object globals)
    {
      object fun = car->eval(env, globals);
      if (fun && fun->is_special)
	return fun->apply(cdr, env, globals);

      object args = cdr->mapcar("eval", env, globals);
      if (args)
	return fun->apply(args, env, globals);
      else
      {
	error("No function to eval");
      }
    }
  }

  object make_list(object ...args)
  {
    object res = Nil;
    for (int i = sizeof(args) - 1; i >= 0; i--)
      res = Cons(args[i], res);
    return res;
  }

  class Symbol 
  {
    inherit LObject;

    string name;

    object eval(object env, object globals)
    {
      if(globals->eval_limit)
      {
	globals->eval_limit--;
	if(globals->eval_limit==0)
	{
	  globals->eval_limit=1;  
	error("Maximum eval-depth reached.");
	}
      }
      object binding =  env->query_binding(this_object())
	|| globals->query_binding(this_object());
      if (!binding)
      {
	error("No binding for this symbol ["+this_object()->print()+"].\n");
      }
      return binding->query();
    }
  
    //  int __hash() { return hash(name); }

    string print()
    {
      return name;
    }
  
    void create(string n, mapping|void table)
    {
      //     werror(sprintf("Creating symbol '%s'\n", n));
      name = n;
      if (table)
	table[name] = this_object();
    }
  }

  class ConstantSymbol 
  {
    inherit Symbol : symbol;
    inherit SelfEvaluating;
  }

  class NilSymbol 
  {
    inherit Cons : cons;
    inherit ConstantSymbol : symbol;

    constant is_nil = 1;
  
    void create(mapping|void table)
    {
      symbol :: create("nil", table);
      cons :: create(this_object(), this_object());;
    }
    object mapcar(mixed ...ignored) { return this_object(); }
    object map(mixed ...ignored) { return this_object(); }
  }

  class String 
  {
    inherit SelfEvaluating;
    string value;

    void create(string s)
    {
      value = s;
    }
  
    string print() { return "\"" + replace(value, ({ "\"", "\n",}),
					   ({ "\\\"", "\\n"}) ) + "\""; }
    string to_string() { return value; }
  }

  class Number 
  {
    inherit SelfEvaluating;
    int|float|object value;

    void create(int|float|object x) { value = x; }

    string print() { return (string) value; }
  }
  
  object make_symbol(string name)
  {
    return symbol_table[name] || Symbol(name, symbol_table);
  }

  class Binding 
  {
    object value;
    object query() { return value; }
    void set(object v) { value = v; }
    void create(object v) { value = v; }
  }
  
  class Environment 
  {
    inherit LObject;
    int eval_limit; // ugly hack..
      
    /* Mapping of symbols and their values.
     * As a binding may exist in several environments, they
     * are accessed indirectly. */
    mapping env = ([ ]);
    object id; // roxen typ ID.

    object query_binding(object symbol)
    {
      return env[symbol];
    }

    void create(mapping|void bindings)
    {
      env = bindings || ([ ]);
    }

    object copy() { return object_program(this_object())(copy_value(env)); };

    object extend(object symbol, object value)
    {
      //     werror(sprintf("Binding '%s'\n", symbol->print()));
      env[symbol] = Binding(value);
    }

    string print() { return sprintf("<Environment: %O>\n",
				    Array.map(indices(env), "print")); }
  }
  
  class Lambda
  {
    inherit LObject;

    object formals; /* May be a dotted list */
    object list; /* expressions */

    void create(object formals_list, object expressions)
    {
      formals = formals_list;
      list = expressions;
    }

    string print() { return "<lambda>"; }

    int build_env1(object env, object symbols, object arglist)
    {
      if (symbols->is_nil)
	return arglist->is_nil;
      if (!symbols->car)
      {
	/* An atom */
	env->extend(symbols, arglist);
	return 1;
      } else {
	return build_env1(env, symbols->car, arglist->car)
	  && build_env1(env, symbols->cdr, arglist->cdr);
      }
    }

    object build_env(object env, object arglist)
    {
      object res = env->copy();
      return build_env1(res, formals, arglist) ? res : 0;
    }

    object new_env(object env, object arglist);
  
    object apply(object arglist, object env, object globals)
    {
      env = new_env(env, arglist); 
      if (env)
	return list->map("eval", env, globals);
      error("Nothing to apply with.");
    }
  }
  
  class Lexical 
  {
    inherit Lambda : l;
    object env;

    void create(object e, object formals_list, object expressions)
    {
      env = e;
      //    werror(sprintf("Building lexical closure, env = %s\n",
      //		   env->print()));
      l :: create(formals_list, expressions);
    }
  
    object new_env(object ignored, object arglist)
    {
      return build_env(env, arglist);
    }
  }

  class Macro 
  {
    inherit Lexical;
    constant is_special = 1;
    object apply(object arglist, object env, object globals)
    {
      return ::apply(arglist, env, globals)->eval(env, globals);
    }
  }

  class Dynamic 
  {
    inherit Lambda;
    object new_env(object env, object arglist)
    {
      return build_env(env, arglist);
    }
  }

  class Builtin 
  {
    inherit LObject;
  
    function apply;

    void create(function f)
    {
      apply = f;
    }

    string print()
    {
      return "<Builtin>";
    }
  }  

  class Special 
  {
    inherit Builtin;
    constant is_special = 1;
    string print()
    {
      return "<Special>";
    }
  }

  /* Parser */

  class Parser 
  {
    object number_re = Regexp("^(-|)([0-9]+)");
    object symbol_re = Regexp("^([^0-9 \t\n(.)\"]+)");
    object space_re = Regexp("^([ \t\n]+)");
    object comment_re = Regexp("^(;[^\n]*\n)");
    object string_re = Regexp("^(\"[^\"]*\")");
  
    string buffer;
    object globals;
  
    void create(string s, object ctx)
    {
      buffer = s;
      globals = ctx;
    }

    object read_list();
  
    mixed _read()
    {
      if (!strlen(buffer))
      {
	return 0;
      }
      array a;
      if (a = space_re->split(buffer) || comment_re->split(buffer))
      {
	//	werror(sprintf("Ignoring space and comments: '%s'\n", a[0]));
	buffer = buffer[strlen(a[0])..];
	return _read();
      }
      if (a = number_re->split(buffer))
      {
	//	werror("Scanning number\n");
	string s = `+(@ a);
	buffer = buffer[ strlen(s) ..];
	return Number(Gmp.mpz(s));
      }
      if (a = symbol_re->split(buffer))
      {
	// 	werror("Scanning symbol\n");
	buffer = buffer[strlen(a[0])..];
	return globals->make_symbol(a[0]);
      }
      if (a = string_re->split(buffer))
      {
	//	werror("Scanning string\n");
	buffer = buffer[strlen(a[0])..];
	return String(a[0][1 .. strlen(a[0]) - 2]);
      }
      
      switch(int c = buffer[0])
      {
       case '(':
	 // 	werror("Reading (\n");
	 buffer = buffer[1 ..];
	 return read_list();
       case '.':
       case ')':
	 // 	werror(sprintf("Reading %c\n", c));
	 buffer = buffer[1..];
	 return c;
       default:
      error("Parse error while reading.");
      }
    }

    object read()
    {
      mixed res = _read();
      if (intp(res))
      {
	return 0;
      }
      return res;
    }
  
    object read_list()
    {
      mixed item = _read();
      if (!item)
      {
	return 0;
      }
      if (intp(item))
	switch(item)
	{
	 case ')': return globals->Nil;
	 case '.':
	   object final = _read();
	   if (intp(final) || (_read() != ')'))
	   {
	     return 0;
	   }
	   return final;
	 default:
	   throw( ({ "lisp->parser: internal error\n",
		     backtrace() }) );
	}
      return Cons(item , read_list());
    }
  }
}  



inherit lisp_types;

/* Special forms */
object s_quote(object arglist, object env, object globals)
{
  return arglist->car;
}

object s_setq(object arglist, object env, object globals)
{
//  werror(sprintf("set!, arglist: %s\n", arglist->print() + "\n"));
  object value = arglist->cdr->car->eval(env, globals);
  object binding = env->query_binding(arglist->car)
    || globals->query_binding(arglist->car);
  if (binding)
    {
      binding->set(value);
      return value;
    }
  else
    return 0;
}

object s_define(object arglist, object env, object globals)
{
  object symbol, value;
  if (arglist->car->car)
  { /* Function definition */
    symbol = arglist->car->car;
    value = Lexical(env, arglist->car->cdr, arglist->cdr);
  } else {
    symbol = arglist->car;
    value = arglist->cdr->car->eval(env, globals);
  }
  if (!value)
    return 0;
  env->extend(symbol, value);
  return symbol;
}    

object s_defmacro(object arglist, object env, object globals)
{
  object symbol = arglist->car->car;
  object value = Macro(env, arglist->car->cdr, arglist->cdr);
  if (!value)
    return 0;
  env->extend(symbol, value);
  return symbol;
}
  
object s_if(object arglist, object env, object globals)
{
  if (!arglist->car->eval(env, globals)->is_nil)
    return arglist->cdr->car->eval(env, globals);
  object e = arglist->cdr->cdr;
  return e ? e->car->eval(env, globals) : Nil;
}

object s_or(object arglist, object env, object globals)
{
  object res;
  while(!arglist->cdr->is_nil)
  {
    res = arglist->car->eval(env, globals);
    if (!res || !res->is_nil)
      return res;
    arglist = arglist->cdr;
  }
  return arglist->car->eval(env, globals);
}

object s_progn(object arglist, object env, object globals)
{
  return arglist->map("eval", env, globals);
}

object s_lambda(object arglist, object env, object globals)
{
  return Lexical(env, arglist->car, arglist->cdr);
}

/* In general, errors are signaled by returning 0, and are
 * fatal.
 *
 * The catch special form catches errors, returning nil
 * if an error occured. */
object s_catch(object arglist, object env, object globals)
{
  return s_progn(arglist, env, globals) || Nil;
}

void init_specials(object environment)
{
  environment->extend(make_symbol("quote"), Special(s_quote));
  environment->extend(make_symbol("set!"), Special(s_setq));
  environment->extend(make_symbol("setq"), Special(s_setq));
  environment->extend(make_symbol("define"), Special(s_define));
  environment->extend(make_symbol("defmacro"), Special(s_defmacro));
  environment->extend(make_symbol("lambda"), Special(s_lambda));
  environment->extend(make_symbol("if"), Special(s_if));
  environment->extend(make_symbol("or"), Special(s_or));
  environment->extend(make_symbol("progn"), Special(s_progn));
  environment->extend(make_symbol("catch"), Special(s_catch));
}


object f_car(object arglist, object env, object globals)
{
  return arglist->car->car;
}

object f_cdr(object arglist, object env, object globals)
{
  return arglist->car->cdr;
}

object f_cons(object arglist, object env, object globals)
{
  return Cons(arglist->car, arglist->cdr->car);
}

object f_list(object arglist, object env, object globals)
{
  return arglist;
}

object f_setcar(object arglist, object env, object globals)
{
  return arglist->car->car = arglist->cdr->car;
}

object f_setcdr(object arglist, object env, object globals)
{
  return arglist->car->cdr = arglist->cdr->car;
}


object parse(string s)
{
  object res = Parser(s, this_object())->read();
  return res;
}

object f_read(object arglist, object env, object globals)
{
  function line = arglist->car->to_string;
  if (!line)
    return 0;
  return parse(line());
}

object f_print(object arglist, object env, object globals)
{
  globals->id->misc->lisp_result += arglist->car->print() + "\n";
  return Nil;
}

object f_eval(object arglist, object env, object globals)
{
  if (!arglist->cdr->is_nil)
    env = arglist->cdr->car;
  else env = Environment();
  return arglist->car->eval(env, globals);
}

object f_apply(object arglist, object env, object globals)
{
  return arglist->car->apply(arglist->cdr, env, globals);
}

object f_add(object arglist, object env, object globals)
{
  object sum = Gmp.mpz(0);
  while(!arglist->is_nil)
  {
    sum += arglist->car->value;
    arglist = arglist->cdr;
  }
  return Number(sum);
}

object f_mult(object arglist, object env, object globals)
{
  object product = Gmp.mpz(1);
  while(!arglist->is_nil)
  {
    product *= arglist->car->value;
    arglist = arglist->cdr;
  }
  return Number(product);
}

object f_subtract(object arglist, object env, object globals)
{
  if (arglist->is_nil)
    return Number(Gmp.mpz(0));
  if (arglist->cdr->is_nil)
    return Number(- arglist->car->value);
  object diff = arglist->car->value;
  arglist = arglist->cdr;
  do {
    diff -= arglist->car->value;
  } while( !(arglist = arglist->cdr)->is_nil);
  return Number(diff);
}

object f_equal(object arglist, object env, object globals)
{
  return ( (arglist->car == arglist->cdr->car)
	   || (arglist->car->value == arglist->cdr->car->value)) ? True : Nil;
}

object f_lt(object arglist, object env, object globals)
{
  return (arglist->car->value < arglist->cdr->car->value) ? True : Nil;
}


object f_get(object arglist, object env, object globals)
{
  if(globals->id->variables[arglist->car->value])
    return String( globals->id->variables[arglist->car->value] );
  if(globals->id->misc->defines[arglist->car->value])
    return String( globals->id->misc->defines[arglist->car->value] );
  return Nil;
}

object f_getint(object arglist, object env, object globals)
{
  if(globals->id->variables[arglist->car->value])
    return Number( (int)globals->id->variables[arglist->car->value] );
  if(globals->id->misc->defines[arglist->car->value])
    return Number( (int)globals->id->misc->defines[arglist->car->value] );
  return Nil;
}

object f_output(object arglist, object env, object globals)
{
  int foo = strlen( globals->id->misc->lisp_result );
  do {
    globals->id->misc->lisp_result += (string)arglist->car->value;
  } while( !(arglist = arglist->cdr)->is_nil);
  return Number( strlen(globals->id->misc->lisp_result) - foo );
}

object f_concat(object arglist, object env, object globals)
{
  string res="";
  do {
    res += arglist->car->value;
  } while( !(arglist = arglist->cdr)->is_nil);
  return String( res );
}

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
  

object boot_code;

void init_functions(object environment)
{
  environment->extend(make_symbol("+"), Builtin(f_add));
  environment->extend(make_symbol("*"), Builtin(f_mult));
  environment->extend(make_symbol("-"), Builtin(f_subtract));
  environment->extend(make_symbol("="), Builtin(f_equal));
  environment->extend(make_symbol("<"), Builtin(f_lt));

  environment->extend(make_symbol("concat"), Builtin(f_concat));
  environment->extend(make_symbol("format"), Builtin(f_format));

  environment->extend(make_symbol("get"), Builtin(f_get));
  environment->extend(make_symbol("get-number"), Builtin(f_getint));
  environment->extend(make_symbol("output"), Builtin(f_output));

  environment->extend(make_symbol("read"), Builtin(f_read));
  environment->extend(make_symbol("print"), Builtin(f_print));
  environment->extend(make_symbol("princ"), Builtin(f_print));
  environment->extend(make_symbol("eval"), Builtin(f_eval));
  environment->extend(make_symbol("apply"), Builtin(f_apply));
  environment->extend(make_symbol("global-environment"), environment);
  environment->extend(make_symbol("car"), Builtin(f_car));
  environment->extend(make_symbol("cdr"), Builtin(f_cdr));
  environment->extend(make_symbol("setcar!"), Builtin(f_setcar));
  environment->extend(make_symbol("setcdr!"), Builtin(f_setcdr));
  environment->extend(make_symbol("cons"), Builtin(f_cons));
  environment->extend(make_symbol("list"), Builtin(f_list));
}


void init_for(object e)
{
  init_specials(e);
  init_functions(e);
  boot_code->eval(e,e);
}
