/*
 * Roxen master
 */

string cvs_version = "$Id: roxen_master.pike,v 1.49 1998/11/18 04:54:06 per Exp $";

/*
 * name = "Roxen Master";
 * doc = "Roxen's customized master.";
 */

object mm=(object)"/master";
inherit "/master": old_master;

mapping handled = ([]);

string program_name(program p)
{
//werror(sprintf("Program name %O = %O\n", p, search(programs,p)));
  return search(programs, p);
}

mapping saved_names = ([]);
 
void name_program(program foo, string name)
{
  programs[name] = foo;
  saved_names[foo] = name;
  saved_names[(program)foo] = name;
}

mapping module_names = ([]);

mixed resolv(string identifier, string|void current_file)
{
  mixed ret = ::resolv(identifier, current_file);

  if (ret) {
    module_names[ret] = identifier;
  }
  return(ret);
}

private static int mid = 0;

mapping _vars = ([]);
array persistent_variables(program p, object o)
{
  if(_vars[p]) return _vars[p];

  mixed b;
  array res = ({});
  foreach(indices(o), string a)
  {
    b=o[a];
    if(!catch { o[a]=b; } ) // It can be assigned. Its a variable!
      res += ({ a });
  }
  return _vars[p]=res;
}

array|string low_nameof(object|program|function fo)
{
  if(objectp(fo))
    if(mixed x=search(objects,fo)) return x; else return 0;  

  if(programp(fo))
    if(mixed x=search(programs,fo)) return x; else return 0;  
  string p,post="";
  object foo ;

  if(functionp(fo))
  {
    array a;
    post=sprintf("%O", function_object( fo ));
    if(a=search(objects, function_object( fo )))
      return ({ a[0], a[1], post });
  } else
    foo = fo;
  
  if(p=search(programs, object_program(foo)))
    return ({ p, (functionp(foo->name)?foo->name():
		  (stringp(foo->name)?foo->name:time(1)+":"+mid++)),post})-({"",0});
#ifdef DEBUG		  
  throw(({"nameof: unknown thingie.\n",backtrace()}));
#else
  return 0;
#endif
}

array|string nameof(mixed foo) {
  return saved_names[foo] ||  (saved_names[foo] = low_nameof( foo ));
}

program programof(string foo) {
  return saved_names[foo] || programs[foo] || (program) foo ;
}

object objectof(array foo)
{
  object o;
  program p;

  array err;
  
  if(!arrayp(foo)) return 0;
  
  if(saved_names[foo[0..1]*"\0"]) return saved_names[foo[0..1]*"\0"];

  if(!(p = programof(foo[0]))) {
    werror("objectof(): Failed to restore object (programof("+foo[0]+
	   ") failed).\n");
    return 0;
  }
  err = catch {
    o = p();
    
    saved_names[ foo[0..1]*"\0" ] = o;

    saved_names[ o ] = foo;
    o->persist && o->persist( foo );
    return o;
  };
  werror("objectof(): Failed to restore object"
	 " from existing program "+foo*"/"+"\n"+
	 describe_backtrace( err ));
  return 0;
}

function functionof(array f)
{
  object o;
//  werror(sprintf("Functionof %O\n", f));
  if(!arrayp(f) || sizeof(f) != 3)
  return 0;
  o = objectof( f[..1] );
  if(!o)
  {
    werror("functionof(): objectof() failed.\n");
    return 0;
  }
  if(!functionp(o[f[-1]]))
  {
    werror("functionof(): "+f*"."+" is not a function.\n");
    destruct(o);
    return 0;
  }
  return o[f[-1]];
}

void create()
{
  object o = this_object();
  /* Copy variables from the original master */
  foreach(indices(mm), string varname) {
    catch(o[varname] = mm[varname]);
    /* Ignore errors when copying functions */
  }
  programs["/master"] = object_program(o);
  objects[object_program(o)] = o;
//   add_constant("_master",o);
  /* Move the old efuns to the new object. */
  if (master_efuns) {
    foreach(master_efuns, string e)
      add_constant(e, o[e]);
  } else {
    ::create();
  }
  add_constant("persistent_variables", persistent_variables);
  add_constant("name_program", name_program);
  add_constant("objectof", objectof);
  add_constant("nameof", nameof);
}

// string errors = "";
// void set_inhibit_compile_errors(mixed f)
// {
//   ::set_inhibit_compile_errors(f);
//   errors="";
// }

// /*
//  * This function is called whenever a compiling error occurs,
//  * Nothing strange about it.
//  * Note that previous_object cannot be trusted in this function, because
//  * the compiler calls this function.
//  */

// void compile_error(string file,int line,string err)
// {
//   if(stringp(inhibit_compile_errors))
//     errors += sprintf("%s:%d:%s\n",trim_file_name(file),line,err);
//   else
//     ::compile_error(file,line,err);
// }
