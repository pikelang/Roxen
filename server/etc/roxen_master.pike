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

string cvs_version = "$Id: roxen_master.pike,v 1.16.2.5 1997/02/11 13:57:40 grubba Exp $";
string pike_library_path;
object stdout, stdin;
mapping names=([]);
int unique_id=time();

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

/* NEW in Pike 0.4pl9
 *
 *
 */
static program findprog(string pname)
{
  program ret;

  if(ret=programs[pname]) return ret;

  if(file_stat(pname)) {
    ret=compile_file(pname);
  } else if(file_stat(pname+".pike")) {
    ret=compile_file(pname+".pike");
  }
#if efun(load_module)
  else if(file_stat(pname+".so")) {
    /* Bug in pike 0.4 */
    mixed foo=load_module(pname+".so");
    ret = foo;
  }
#endif /* load_module */
  if (ret) {
    programs[pname]=ret;
    return(ret);
  } else {
    return UNDEFINED;
  }
}

/* This function is called whenever a module has built a clonable program
 * with functions written in C and wants to notify the Pike part about
 * this. It also supplies a suggested name for the program.
 *
 * OBSOLETE in Pike 0.4pl9
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
  string d=getcwd();

  if(pname[sizeof(pname)-3..sizeof(pname)]==".pike")
    pname=pname[0..sizeof(pname)-5];

  if(ret=programs[pname]) return ret;

  if(pname[0]=='/') {
    return findprog(pname);
  } else {
    /*
      if(search(pname,"/")==- 1) {
      */
      string path;
      if(string path=getenv("PIKE_INCLUDE_PATH")) {
	foreach(path/":", path)
	  if(program ret=findprog(combine_path(getcwd(),
					       combine_path(path,pname))))
	    return ret;
	/*
	  }
	  */
    }
    return findprog(combine_path(getcwd(),pname));
  }
}
 
#if 0
{ 
  if(file_stat(pname))
    ret=compile_file(pname);
  else if(file_stat(combine_path(d+"/base_server/",pname+".pike"))) // ROXEN
    ret=compile_file(combine_path(d+"/base_server/",pname+".pike"));
  else if (file_stat(pname + ".pike"))
    ret=compile_file(pname+".pike");
  else if (pname[sizeof(pname)-3..sizeof(pname)]==".pmod") {
    /* Old versions of pike used .pre */
    return(cast_to_program(pname[0..sizeof(pname)-5]+".pre"));
  } else
    throw(({ sprintf("No such program \"%s\"\n", pname), backtrace() }));

  return programs[pname]=ret;
}

#endif /* 0 */

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

mapping (string:object) objects=(["/master":this_object()]);

/* This function is called when the drivers wants to cast a string
 * to an object because of an implict or explicit cast. This function
 * may also receive more arguments in the future.
 */
object cast_to_object(string oname)
{
  object ret;
  program p;

  if(oname[0]=='/')
    oname=combine_path(getcwd(),oname);

  if(oname[sizeof(oname)-3..sizeof(oname)]==".pike")
    oname=oname[0..sizeof(oname)-4];

  if(ret=objects[oname]) return ret;

  if (p = cast_to_program(oname)) {
    return objects[oname]=p();
  } else {
    throw(({ sprintf("Can't cast \"%s\" to program\n", oname),
	     backtrace() }));
  }
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

class mergenode
{
  mixed *modules;
  void create(mixed *m) { modules=m; }
  mixed `[](string index)
  {
    foreach(modules, mixed mod)
      if (mixed ret=mod[index]) return ret;
    return UNDEFINED;
  }
};

object findmodule(string fullname)
{
  mixed *stat;
  program p;
  if(!catch(p=(program)(fullname+".pmod")) && p)
    return (object)(fullname+".pmod");
#if constant(load_module)
  if(file_stat(fullname+".so")) {
    return (object)(fullname);
  }
#endif

  /* Hack for pre-install testing */
  if(mixed *stat=file_stat(fullname))
  {
    if(stat[1]==-2)
      return findmodule(fullname+"/module");
  }

  if(mixed *stat=file_stat(fullname+".pmd")) {
    if(stat[1]==-2)
      return dirnode(fullname+".pmd");
  }

  return UNDEFINED;
}

#if constant(_static_modules)
mixed idiresolv(string identifier)
{
  string path=combine_path(pike_library_path+"/modules",identifier);
  array(mixed) err;
  mixed ret = 0;

  if ((err = catch(ret=findmodule(path))) || !ret)
    if (!(ret = _static_modules[identifier]))
      throw(err);
  return(ret);
}
#endif

mixed resolv(string identifier, string current_file)
{
  mixed ret;
  string *tmp,path;
  multiset tested=(<>);
  mixed *modules=({});

  tmp=current_file/"/";
  tmp[-1]=identifier;
  path=combine_path(getcwd(), tmp*"/");
  if(!tested[path]) {
    tested[path]=1;
    if(ret=findmodule(path)) modules+=({ret});
  }

  if(path=getenv("PIKE_MODULE_PATH"))
  {
    foreach(path/":", path) {
      if(!sizeof(path)) continue;
      path=combine_path(path,identifier);
      if(!tested[path]) {
	tested[path]=1;
	if(ret=findmodule(path)) modules+=({ret});
      }
    }
  }
  string path=combine_path(pike_library_path+"/modules",identifier);
  if(!tested[path]) {
    tested[path]=1;
    if(ret=findmodule(path)) modules+=({ret});
  }
#if constant(_static_modules)
  if(ret=_static_modules[identifier]) modules+=({ret});
#endif
  
  switch(sizeof(modules)) {
  default:
    mixed tmp=mergenode(modules);
    werror(sprintf("%O\n",tmp["file"]));
    return tmp;
  case 1:
    return modules[0];
  case 0:
    switch(identifier) {
    case "readline":
      if(!resolv("readlinemod", current_file))
	werror("No readline module.\n");
      return all_constants()->readline;
    }
    return UNDEFINED;
  }
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

  /* pike_library_path must be set before idiresolv is called */
  a=backtrace()[-1][0];
  q=a/"/";
  pike_library_path = q[0..sizeof(q)-2] * "/";

#if constant(_static_modules)
  /* Pike 0.4pl9 */
  add_constant("write", idiresolv("files")->file("stdout")->write);
  add_constant("stdin", idiresolv("files")->file("stdin"));
  add_constant("stdout",idiresolv("files")->file("stdout"));
  add_constant("stderr",idiresolv("files")->file("stderr"));
  /*
   * Backward compatibility
   */
  add_precompiled_program("/precompiled/file", idiresolv("files")->file);
  add_precompiled_program("/precompiled/port", idiresolv("files")->port);
  add_precompiled_program("/precompiled/regexp",
			  object_program(resolv("regexp",
						pike_library_path+"/include/modules/")));
  add_precompiled_program("/precompiled/pipe",
			    object_program(resolv("pipe",
						  pike_library_path+"/include/modules/")));

#else
  add_constant("write",cast_to_program("/precompiled/file")("stdout")->write);
  add_constant("stdin",cast_to_program("/precompiled/file")("stdin"));
  add_constant("stdout",cast_to_program("/precompiled/file")("stdout"));
  add_constant("stderr",cast_to_program("/precompiled/file")("stderr"));
#endif

//  clone(compile_file(pike_library_path+"/simulate.pike"));

#if efun(version) || efun(__version)
  /* In Pike 0.4pl2 and later the full command-line is passed 
   * to the master.
   *
   * The above test should work for everybody except those who
   * have Pike 0.4pl2 without __version (probably nobody).
   */

#if constant(_static_modules)
  tmp=idiresolv("getopt");
#else
  tmp=new(pike_library_path+"/include/getopt.pre.pike");
#endif /* _static_modules */

  foreach(tmp->find_all_options(argv,({
    ({"version",tmp->NO_ARG,({"-v","--version"})}),
    ({"help",tmp->NO_ARG,({"-h","--help"})}),
    ({"execute",tmp->HAS_ARG,({"-e","--execute"})}),
    ({"modpath",tmp->HAS_ARG,({"-M","--module-path"})}),
    ({"ignore",tmp->HAS_ARG,"-ms"}),
    ({"ignore",tmp->MAY_HAVE_ARG,"-Ddatp",0,1})}),1),
	  mixed *opts)
    {
      switch(opts[0])
      {
      case "version":
	werror(VERSION + " Copyright (C) 1994-1997 Fredrik Hübinette\n"
	       "Pike comes with ABSOLUTELY NO WARRANTY; This is free software and you are\n"
	       "welcome to redistribute it under certain conditions; Read the files\n"
	       "COPYING and DISCLAIMER in the Pike distribution for more details.\n");
	exit(0);
      case "help":
	werror("Usage: pike [-driver options] script [script arguments]\n"
	       "Driver options include:\n"
	       " -e --execute <cmd>   : Run the given command instead of a script.\n"
	       " -h --help            : see this message\n"
	       " -v --version         : See what version of pike you have.\n"
	       " -s#                  : Set stack size\n"
	       " -m <file>            : Use <file> as master object.\n"
	       " -d -d#               : Increase debug (# is how much)\n"
	       " -t -t#               : Increase trace level\n"
	       );
	exit(0);

      case "execute":
	compile_string("#include <simulate.h>\nmixed create(){"+opts[1]+";}")();
	break;
      case "modpath":
	putenv("PIKE_MODULE_PATH",opts[1]+":"+(getenv("PIKE_MODULE_PATH")||""));
	break;
      case "ignore":
	break;
      }
    }

  argv=tmp->get_args(argv,1);
  destruct(tmp);
  
  /*
   * Search base_server also
   */
  string path = getenv("PIKE_INCLUDE_PATH");

  if (path) {
    path = getcwd()+"/base_server/:"+path;
  } else {
    path = getcwd()+"/base_server/";
  }
  putenv("PIKE_INCLUDE_PATH", path);

  if(sizeof(argv) == 1) {
    argv=argv[0]/"/";
    argv[-1]="hilfe";
    argv=({ argv*"/" });
    if(!file_stat(argv[0])) {
      if(file_stat("/usr/local/bin/hilfe"))
	argv[0]="/usr/local/bin/hilfe";
      else if(file_stat("../bin/hilfe"))
	argv[0]="/usr/local/bin/hilfe";
      else {
	werror("Couldn't find hilfe.\n");
	exit(1);
      }
    }
  } else {
    argv=argv[1..];
  }
#endif /* version or __version */

  if (!sizeof(argv))
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
	if(!sizeof(path)) continue;
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

