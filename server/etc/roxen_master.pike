/*
 * Roxen master
 */

string cvs_version = "$Id: roxen_master.pike,v 1.32 1997/04/14 02:03:54 per Exp $";

object stdout, stdin;
mapping names=([]);
int unique_id=time();

object mm = (object)"/master";

inherit "/master";

string program_name(program p)
{
  return search(programs, p);
}

mapping saved_names = ([]);
 
void name_program(program foo, string name)
{
  programs[name] = foo;
  saved_names[foo] = name;
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
  if(objectp(fo) && search(objects, fo))
    return search(objects, fo);

  if(programp(fo))
    return search(programs, fo);

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
		  
  throw(({"nameof: unknown thingie.\n",backtrace()}));
}

array|string nameof(mixed foo)
{
  // werror(sprintf("Nameof %O...\m", foo));
  return saved_names[foo] ||  (saved_names[foo] = low_nameof( foo ));
}

program programof(string foo)
{
  return saved_names[foo] || programs[foo] || (program) foo ;
}

/* This function is called when an error occurs that is not caught
 * with catch(). It's argument consists of:
 * ({ error_string, backtrace }) where backtrace is the output from the
 * backtrace() efun.
 */
void handle_error(mixed *trace)
{
  predef::trace(0);
  catch(werror(describe_backtrace(trace)));
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
  werror(sprintf("Functionof %O\n", f));
  if(sizeof(f) != 3) return 0;
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

mixed handle_inherit(mixed ... args)
{
  catch {
    return ::handle_inherit(@args);
  };
}

void create()
{
  /* Copy variables from the original master */
  foreach(indices(mm), string varname) {
    catch(this_object()[varname] = mm[varname]);
    /* Ignore errors when copying functions */
  }
  programs["/master"] = object_program(this_object());
  objects[object_program(this_object())] = this_object();
  /* make ourselves known */
  add_constant("_master",this_object());
  add_constant("master",lambda() { return this_object(); });
  add_constant("version",lambda() { return version() + " Roxen Challenger master"; } );


  add_constant("persistent_variables", persistent_variables);
  add_constant("name_program", name_program);
  add_constant("objectof", objectof);
  add_constant("nameof", nameof);
}


string errors;
string set_inhibit_compile_errors(mixed f)
{
  mixed fr = errors||"";
  inhibit_compile_errors=f;
  errors="";
  return fr;
}

/*
 * This function is called whenever a compiling error occurs,
 * Nothing strange about it.
 * Note that previous_object cannot be trusted in this function, because
 * the compiler calls this function.
 */

void compile_error(string file,int line,string err)
{
  if(stringp(inhibit_compile_errors))
    errors+=sprintf("%s:%d:%s\n",file,line,err);
  else
    ::compile_error(file,line,err);
}

/* This function is called when the driver wants to cast a string
 * to a program, this might be because of an explicit cast, an inherit
 * or a implict cast. In the future it might receive more arguments,
 * to aid the master finding the right program.
 */
program cast_to_program(string pname, string current_file)
{
  string ext;
  string nname;

  if(program ret=findprog(pname,""))
    return ret;

  if(sscanf(reverse(pname),"%s.%s",ext, nname) && search(ext, "/") == -1)
  {
    ext="."+reverse(ext);
    pname=reverse(nname);
  }else{
    ext="";
  }
  if(pname[0]=='/')
  {
    pname=combine_path("/",pname);
    return findprog(pname,ext);
  }else{
    string cwd;
    if(current_file)
    {
      string *tmp=current_file/"/";
      cwd=tmp[..sizeof(tmp)-2]*"/";

      if(program ret=findprog(combine_path(cwd,pname),ext))
	return ret;

    }else{
      if(program ret=findprog(pname,ext))
	return ret;
    }

    foreach(pike_include_path, string path)
      if(program ret=findprog(combine_path(path,pname),ext))
	return ret;

    return 0;
  }
}
