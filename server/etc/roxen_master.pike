/*
 * Roxen master
 */
string cvs_version = "$Id: roxen_master.pike,v 1.52 1999/11/23 11:03:11 per Exp $";

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
    if(mixed x=search(objects,fo)) return x;

  if(programp(fo))
    if(mixed x=search(programs,fo)) return x;

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


string describe_backtrace(mixed trace, void|int linewidth)
{
  int e;
  string ret;
  linewidth=999999;

  if((arrayp(trace) && sizeof(trace)==2 && stringp(trace[0])) ||
     (objectp(trace) && trace->is_generic_error))
  {
    if (catch {
      ret = trace[0];
      trace = trace[1];
    }) {
      return "Error indexing backtrace!\n";
    }
  }else{
    ret="";
  }

  if(!arrayp(trace))
  {
    ret+="No backtrace.\n";
  }else{
    for(e = sizeof(trace)-1; e>=0; e--)
    {
      mixed tmp;
      string row;

      if (mixed err=catch 
      {
	tmp = trace[e];
	if(stringp(tmp))
	{
	  row=tmp;
	}
	else if(arrayp(tmp))
	{
	  string pos;
	  if(sizeof(tmp)>=2 && stringp(tmp[0]) && intp(tmp[1]))
	  {
	    pos=trim_file_name(tmp[0])+":"+tmp[1];
	  }else{
	    mixed desc="Unknown program";
	    if(sizeof(tmp)>=3 && functionp(tmp[2]))
	    {
	      catch {
		if(mixed tmp=function_object(tmp[2]))
		  if(tmp=object_program(tmp))
		    if(tmp=describe_program(tmp))
		      desc=tmp;
	      };
	    }
	    pos=desc;
	  }
	  
	  string data;
	  
	  if(sizeof(tmp)>=3)
	  {
	    if(functionp(tmp[2]))
	      data = function_name(tmp[2]);
	    else if (stringp(tmp[2])) {
	      data= tmp[2];
	    } else
	      data ="unknown function";
	    
	    data+="("+
	      stupid_describe_comma_list(tmp[3..], 99999999)+
	    ")";

	    if(sizeof(pos)+sizeof(data) < linewidth-4)
	    {
	      row=sprintf("%s: %s",pos,data);
	    }else{
	      row=sprintf("%s:\n%s",pos,sprintf("    %*-/s",linewidth-6,data));
	    }
	  }
	}
	else
	{
	  row="Destructed object";
	}
      }) {
	row += sprintf("Error indexing backtrace line %d (%O)!", e, err[1]);
      }
      ret += row + "\n";
    }
  }

  return ret;
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
  /* Move the old efuns to the new object. */
  if (master_efuns) {
    foreach(master_efuns, string e)
      add_constant(e, o[e]);
  } else {
    ::create();
  }
  add_constant("describe_backtrace", describe_backtrace );
  add_constant("persistent_variables", persistent_variables);
  add_constant("name_program", name_program);
  add_constant("objectof", objectof);
  add_constant("nameof", nameof);
//   autoreload_on=1;
}
