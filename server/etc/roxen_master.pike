#define UNDEFINED (([])[0])
#if efun(version)
#define VERSION		version()
#else
#if efun(__version)
#define VERSION		__version()
#else
#define VERSION		"Pike v0.4pl2"
#endif /* __version */
#endif /* version */

string describe_backtrace(mixed *trace);

string cvs_version = "$Id: roxen_master.pike,v 1.18 1997/01/29 04:59:39 per Exp $";
string pike_library_path;
object stdout, stdin;
mapping names=([]);
int unique_id=time();

/* This function is called when an error occurs that is not caught
 * with catch(). It's argument consists of:
 * ({ error_string, backtrace }) where backtrace is the output from the
 * backtrace() efun.
 */
void handle_error(mixed *trace)
{
  predef::trace(0);
  catch{werror(describe_backtrace(trace));};
}

object new(mixed prog, mixed ... args)
{
  return ((program)prog)(@args);
}

/* Note that create is called before add_precompiled_program
 */
void create()
{
  /* make ourselves known */
  add_constant("_master",this_object());
  add_constant("master",lambda() { return this_object(); });
  add_constant("describe_backtrace",describe_backtrace);
  add_constant("version",lambda() { return VERSION + " Roxen Challenger master"; });
  add_constant("mkmultiset",lambda(mixed *a) { return aggregate_multiset(@a); });
  add_constant("strlen",sizeof);
  add_constant("new",new);
  add_constant("clone",new);

  random_seed(time() + (getpid() * 0x11111111));
}

mapping (string:program) programs=([]);

string program_name(program p)
{
  return search(programs, p);
}

#define capitalize(X)	(upper_case((X)[..0])+(X)[1..])

/* This function is called whenever a module has built a clonable program
 * with functions written in C and wants to notify the Pike part about
 * this. It also supplies a suggested name for the program.
 */
void add_precompiled_program(string name, program p)
{
  programs[name]=p;

  if(sscanf(name,"/precompiled/%s",name)) {
    string const="";
    foreach(reverse(name/"/"), string s) {
      const = capitalize(s) + const;
      add_constant(const, p);
    }
  }
}

/* This function is called when the driver wants to cast a string
 * to a program, this might be because of an explicit cast, an inherit
 * or a implict cast. In the future it might receive more arguments,
 * to aid the master finding the right program.
 */
program cast_to_program(string pname)
{
  program ret;
  string d=getcwd(),p=pname;

  if(ret=programs[pname]) return ret;

  if(pname[sizeof(pname)-3..sizeof(pname)]==".pike")
    pname=pname[0..sizeof(pname)-5];

  if(ret=programs[pname]) return ret;
  
  if(file_stat(pname))
    ret=compile_file(pname);
  else if(file_stat(combine_path(d+"/base_server/",p+".pike"))) // ROXEN
    ret=compile_file(combine_path(d+"/base_server/",p+".pike"));
  else
    ret=compile_file(pname+".pike");
  return programs[pname]=ret;
}

/*
 * This function is called whenever a inherit is called for.
 * It is supposed to return the program to inherit.
 * The first argument is the argument given to inherit, and the second
 * is the file name of the program currently compiling. Note that the
 * file name can be changed with #line, or set by compile_string, so
 * it can not be 100% trusted to be a filename.
 * previous_object(), can be virtually anything in this function, as it
 * is called from the compiler.
 */
program handle_inherit(string pname, string current_file)
{
  program p;
  string *tmp;
  p=cast_to_program(pname);
  if(p) return p;
  tmp=current_file/"/";
  tmp[-1]=pname;
  return cast_to_program(tmp*"/");
}

mapping (string:object) objects=(["/master.pike":this_object()]);

/* This function is called when the drivers wants to cast a string
 * to an object because of an implict or explicit cast. This function
 * may also receive more arguments in the future.
 */
object cast_to_object(string oname)
{
  object ret;

  if(oname[0]=='/')
    oname=combine_path(getcwd(),oname);

  if(oname[sizeof(oname)-3..sizeof(oname)]==".pike")
    oname=oname[0..sizeof(oname)-4];

  if(ret=objects[oname]) return ret;

  return objects[oname]=cast_to_program(oname)();
}

mapping (string:string) environment=([]);

varargs mixed getenv(string s)
{
  if(!s) return environment;
  return environment[s];
}

void putenv(string var, string val)
{
  environment[var]=val;
}

class dirnode
{
  string dirname;
  void create(string name) { dirname=name; }
  object|program `[](string index)
  {
    index=dirname+"/"+index;
    return
      ((object)"/master")->findmodule(index) || (program) index;
  }
};

object findmodule(string fullname)
{
  mixed *stat;
  if(mixed *stat=file_stat(fullname))
  {
    if(stat[1]==-2) return dirnode(fullname);
  }
  program p;
  catch {
    if(p=(program)(fullname+".pmod"))
      return (object)(fullname+".pmod");
  };
  return UNDEFINED;
}

mixed resolv(string identifier, string current_file)
{
  mixed ret;
  string *tmp,path;

  tmp=current_file/"/";
  tmp[-1]=identifier;
  path=combine_path(getcwd(), tmp*"/");
  if(ret=findmodule(path)) return tmp;

  if(path=getenv("PIKE_MODULE_PATH"))
  {
    foreach(path/":", path)
      {
	path=combine_path(path,identifier);
	if(ret=findmodule(path)) return ret;
      }
  }

  path=combine_path(pike_library_path+"/modules",identifier);
  return findmodule(path);
}

/* This function is called when all the driver is done with all setup
 * of modules, efuns, tables etc. etc. and is ready to start executing
 * _real_ programs. It receives the arguments not meant for the driver
 * and an array containing the environment variables on the same form as
 * a C program receives them.
 */
void _main(string *argv, string *env)
{
  int i;
  object script;
  object tmp;
  string a,b;
  string *q;

  foreach(env,a) if(sscanf(a,"%s=%s",a,b)) environment[a]=b;
  add_constant("getenv",getenv);
  add_constant("environment",environment);
  add_constant("putenv",putenv);
  add_constant("error",lambda(string s, mixed ... args) {
    if(sizeof(args)) s=sprintf(s, @args);
    throw(({ s, backtrace()[1..] }));
  });
  add_constant("write",cast_to_program("/precompiled/file")("stdout")->write);
  add_constant("stdin",cast_to_program("/precompiled/file")("stdin"));
  add_constant("stdout",cast_to_program("/precompiled/file")("stdout"));
  add_constant("stderr",cast_to_program("/precompiled/file")("stderr"));

  a=backtrace()[-1][0];
  q=a/"/";
  pike_library_path = q[0..sizeof(q)-2] * "/";

//  clone(compile_file(pike_library_path+"/simulate.pike"));

  tmp=new(pike_library_path+"/include/getopt.pre.pike");

  foreach(tmp->find_all_options(argv,({
    ({"version",tmp->NO_ARG,({"-v","--version"})}),
      ({"ignore",tmp->HAS_ARG,"-ms"}),
	({"ignore",tmp->MAY_HAVE_ARG,"-Ddatp",0,1})}),1),
	  mixed *opts)
    {
      switch(opts[0])
      {
      case "version":
	werror(VERSION + " Copyright (C) 1994-1997 Fredrik Hübinette\n");
	werror("Pike comes with ABSOLUTELY NO WARRANTY; This is free software and you are\n");
	werror("welcome to redistribute it under certain conditions; Read the files\n");
	werror("COPYING and DISCLAIMER in the Pike distribution for more details.\n");
	exit(0);
      case "ignore":
	break;
      }
    }

  argv=tmp->get_args(argv,1)[1..];
  destruct(tmp);

   if(!sizeof(argv))
  {
    werror("Usage: pike [-driver options] script [script arguments]\n");
    exit(1);
  }
  script=(object)argv[0];

  if(!script->main)
  {
    werror("Error: "+argv[0]+" has no main().\n");
    exit(1);
  }

  i=script->main(sizeof(argv),argv,env);
  if(i >=0) exit(i);
}

mixed inhibit_compile_errors;

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

/* This function is called whenever an #include directive is encountered
 * it receives the argument for #include and should return the file name
 * of the file to include
 * Note that previous_object cannot be trusted in ths function, because
 * the compiler calls this function.
 */
string handle_include(string f,
		      string current_file,
		      int local_include)
{
  string *tmp, path;

  if(local_include)
  {
    tmp=current_file/"/";
    tmp[-1]=f;
    path=combine_path(getcwd(),tmp*"/");
    if(!file_stat(path))
    {
      path = f;
      if(!file_stat(path))
	return 0;
    }
  }
  else
  {
    if(path=getenv("PIKE_INCLUDE_PATH"))
    {
      foreach(path/":", path)
      {
	path=combine_path(path,f);
	if(file_stat(path))
	  break;
	else
	  path=0;
      }
    }
    
    if(!path)
    {
      path=combine_path(pike_library_path+"/include",f);
      if(!file_stat(path)) path=0;
    }
  }

  if(path)
  {
    /* Handle preload */

    if(path[-1]=='h' && path[-2]=='.' &&
       file_stat(path[0..sizeof(path)-2]+"pre.pike"))
    {
      cast_to_object(path[0..sizeof(path)-2]+"pre.pike");
    }
  }

  return path;
}

/* It is possible that this should be a real efun,
 * it is currently used by handle_error to convert a backtrace to a
 * readable message.
 */
string describe_backtrace(mixed *trace)
{
  int e;
  string ret;
  string wd = getcwd();

  if(arrayp(trace) && sizeof(trace)==2 && stringp(trace[0]))
  {
    ret=trace[0];
    trace=trace[1];
  }else{
    ret="";
  }

  if(!arrayp(trace))
  {
    ret+="No backtrace.\n";
  }else{
    for(e=sizeof(trace)-1;e>=0;e--)
    {
      mixed tmp;
      string row;

      tmp=trace[e];
      if(stringp(tmp))
      {
	row=tmp;
      }
      else if(arrayp(tmp))
      {
	row="";
	if(sizeof(tmp)>=3 && functionp(tmp[2]))
	{
	  row=function_name(tmp[2])+" in ";
	}

	if(sizeof(tmp)>=2 && stringp(tmp[0]) && intp(tmp[1]))
	{
	  row+="line "+tmp[1]+" in "+((tmp[0]-(wd+"/"))-"base_server/");
	}else{
	  row+="Unknown program";
	}
      }
      else
      {
	row="Destructed object";
      }
      ret+=row+"\n";
    }
  }

  return ret;
}

