/*
 * Roxen master
 */

string cvs_version = "$Id: roxen_master.pike,v 1.16.2.9 1997/03/11 04:26:01 grubba Exp $";

object stdout, stdin;
mapping names=([]);
int unique_id=time();

object mm = (object)"/master";

inherit "/master";

string program_name(program p)
{
  return search(programs, p);
}

#define capitalize(X)	(upper_case((X)[..0])+(X)[1..])

/* This function is called whenever a module has built a clonable program
 * with functions written in C and wants to notify the Pike part about
 * this. It also supplies a suggested name for the program.
 *
 * OBSOLETE in Pike 0.4pl9
 */
void add_precompiled_program(string name, program p)
{
  if (p) {
    programs[name]=p;

    if(sscanf(name,"/precompiled/%s",name)) {
      string const="";
      foreach(reverse(name/"/"), string s) {
	const = capitalize(s) + const;
	add_constant(const, p);
      }
    }
  } else {
    throw(({ sprintf("add_precompiled_program(): Attempt to add NULL program \"%s\"\n",
		     name), backtrace() }));
  }
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

/* Note that create is called before add_precompiled_program
 */
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
 * Note that previous_object cannot be trusted in ths function, because
 * the compiler calls this function.
 */

void compile_error(string file,int line,string err)
{
  if(!inhibit_compile_errors)
  {
    werror(sprintf("%s:%d:%s\n",file,line,err));
  }
  else if(functionp(inhibit_compile_errors))
  {
    inhibit_compile_errors(file,line,err);
  } else
    errors+=sprintf("%s:%d:%s\n",file,line,err);
}
