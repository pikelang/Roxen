#!bin/pike -m lib/pike/master.pike

/*
 * name = "Roxen Install Script ";
 * doc = "Main part of the installscript that is run upon installation of roxen";
 */

string cvs_version = "$Id: install.pike,v 1.28 1997/12/15 20:05:14 peter Exp $";

#include <simulate.h>
#include <roxen.h>

#undef DEBUG
#undef DEBUG_LEVEL

string version = "1.0";

object stderr = files.file("stderr");

void roxen_perror(string format,mixed ... args)
{
  string s;
  if(sizeof(args)) format=sprintf(format,@args);
  if (format=="") return;
  stderr->write(format);
}


void report_error(string s)
{
  werror(s);
}

object roxenp()
{
  return this_object();
}

object|void open(string filename, string mode, int|void perm)
{
  object o;
  o=File();
  if(o->open(filename, mode, perm || 0666)) {
#ifdef DEBUG
    perror("Opened fd "+o->query_fd()+"\n");
#endif /* DEBUG */
    return o;
  }
  destruct(o);
}

void mkdirhier(string from, int|void mode)
{
  string a, b;
  array f;

  f=(from/"/");
  b="";

  foreach(f[0..sizeof(f)-2], a)
  {
    mkdir(b+a);
#if constant(chmod)
    if (mode) {
      catch { chmod(b+a, mode); };
    }
#endif /* constant(chmod) */
    b+=a+"/";
  }
}

mapping(string:mixed) variables = ([ "audit":0 ]);

// We never need to change priviliges...
mixed Privs(mixed ... args) { return 0; }

#define VAR_VALUE 0
#define IN_INSTALL 1
#include "../base_server/read_config.pike"

void setglobvar(string var, mixed value)
{
  mapping v;
  v = retrieve("Variables", 0);
  v[var] = value;
  store("Variables", v, 1, 0);
}


varargs int run(string file,string ... foo)
{
  string path;
  if(search(file,"/") != -1)
    return exece(combine_path(getcwd(),file),foo);

  path=getenv("PATH");

  foreach(path/":",path)
    if(file_stat(path=combine_path(path,file)))
      return exece(path, foo);

  return 69;
}

int verify_port(int try)
{
  int ret;
  object p;
  p = files.port();
  ret = p->bind(try);
  destruct(p);
  return ret;  
}

int getport()
{
  object p;
  int port;
  int tries;

  p = files.port();

  for (tries = 8192; tries--;) {
    if (p->bind(port = 10000 + random(10000))) {
      destruct(p);
      return(port);
    }
  }
  write("Failed to find a free port (tried 8192 different)\n"
	"Pike's socket-implementation might be broken on this architecture.\n"
	"Please run \"make verify\" in the build-tree to check pike.\n");
  destruct(p);
  return(0);
}

string gets(void|int sp)
{
#if efun(readline)
  return readline("");
#else
  string s="", tmp;
  
  while((tmp = stdin -> read(1)))
    switch(tmp)
    {
     case "\010":
      s = s[0..strlen(s) - 2];
      break;

     case " ":  case "\t": 
      if(!sp)
	while((stdin -> read(1)) != "\n") 
	  ;
      else {
	s += tmp;
	break;
      }
     case "\n": case "\r":
      return s;
	
     default:
      s += tmp;
    }
#endif
}

private string get_domain(int|void l)
{
  array f;
  string t, s;

//  ConfigurationURL is set by the 'install' script.
#if efun(gethostbyname) && efun(gethostname)
    f = gethostbyname(gethostname()); /* First try.. */
    if(f)
      foreach(f, f)
	if(arrayp(f))
	{
	  foreach(f, t)
	    if(search(t, ".") != -1 && !(int)t)
	      if(!s || strlen(s) < strlen(t))
		s=t;
	} else
	  if(search((t=(string)f), ".") != -1 && !(int)t)
	    if(!s || strlen(s) < strlen(t))
	      s=t;
#endif
    if(!s)
    {
      t = read_bytes("/etc/resolv.conf");
      if(t) 
      {
	if(sscanf(t, "%*sdomain%*[ \t]%s\n", s)!=3)
	  if(sscanf(t, "%*ssearch%*[ \t]%[^ ]", s)!=3)
	    s="nowhere";
      } else {
	s="nowhere";
      }
      s = "host."+s;
    }

  sscanf(s, "%*s.%s", s);
  if(s && strlen(s))
  {
    if(s[-1] == '.') s=s[..strlen(s)-2];
    if(s[0] == '.') s=s[1..];
  } else {
    s="unknown"; 
  }
  return s;
}

string find_arg(array argv, array|string shortform, 
		array|string|void longform, 
		array|string|void envvars, 
		string|void def)
{
  string value;
  int i;

  for(i=1; i<sizeof(argv); i++)
  {
    if(argv[i] && strlen(argv[i]) > 1)
    {
      if(argv[i][0] == '-')
      {
	if(argv[i][1] == '-')
	{
	  string tmp;
	  int nf;
	  if(!sscanf(argv[i], "%s=%s", tmp, value))
	  {
	    if(i < sizeof(argv)-1)
	      value = argv[i+1];
	    else
	      value = argv[i];
	    tmp = argv[i];
	    nf=1;
	  }
	  if(arrayp(longform) && search(longform, tmp[2..1000]) != -1)
	  {
	    argv[i] = 0;
	    if(i < sizeof(argv)-1)
	      argv[i+nf] = 0;
	    return value;
	  } else if(longform && longform == tmp[2..10000]) {
	    argv[i] = 0;
	    if(i < sizeof(argv)-1)
	      argv[i+nf] = 0;
	    return value;
	  }
	}
	if((arrayp(shortform) && ((search(shortform, argv[i][1..1]) != -1)))
	   || (stringp(shortform) && (shortform == argv[i][1..1])))
	{
	  if(strlen(argv[i]) == 2)
	  {
	    if(i < sizeof(argv)-1)
	      value =argv[i+1];
	    argv[i] = argv[i+1] = 0;
	    return value;
	  } else {
	    value=argv[i][2..100000];
	    argv[i]=0;
	    return value;
	  }
	}
      }
    }
  }

  if(arrayp(envvars))
    foreach(envvars, value)
      if(getenv(value))
	return getenv(value);
  
  if(stringp(envvars))
    if(getenv(envvars))
      return getenv(envvars);

  return def;
}

void main(int argc, string *argv)
{
  string host, client, log_dir, domain;
  mixed tmp;
  int port, configuration_dir_changed, logdir_changed;
  string prot_prog = "http";
  string prot_spec = "http://";
  string prot_extras = "";

  add_constant("roxen", this_object());
  add_constant("perror", roxen_perror);
  add_constant("roxen_perror", roxen_perror);

  if(find_arg(argv, "?", "help"))
  {
    perror(sprintf("Syntax: %s [-d DIR|--config-dir=DIR] [-l DIR|--log-dir=DIR]\n"
		   "This program will set some initial variables in Roxen.\n"
		   , argv[0]));
    exit(0);
  }

  if(find_arg(argv, "v", "version"))
  {
    perror("Roxen Install version "+cvs_version+"\n");
    exit(0);
  }

  configuration_dir = find_arg(argv, "d", ({ "config-dir",
					       "config",
					       "configurations",
					       "configuration-directory" }),
			       ({ "ROXEN_LOGDIR" }),
			       "../configurations");
  
  log_dir = find_arg(argv, "l", ({ "log-dir",
				     "log-directory", }),
		     ({ "ROXEN_CONFIGDIR", "CONFIGURATIONS" }),
		     "../logs/");

  write(popen("clear"));
  host=gethostname();
  domain = get_domain();
  if(search(host, domain) == -1)
    host += "."+domain;
  if(sscanf(host, "%s.0", tmp))
    host=tmp;

  write("[1m              Roxen Challenger Installation Script\n"
	"              ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^[0m\n"
	"On all questions, press return to use the default value.\n\n"
	"Enter the full hostname of your computer (hostname.domain).\n"
	"[1mFull Hostname [ "+host+" ][0m: ");
  tmp = gets();

  if(strlen(tmp))
    host=tmp;

  while(1)
  {
    port = getport();
    write("[1mConfiguration Interface Port Number [ "+port+" ][0m: ");
    tmp = gets();
    if(strlen(tmp))
      tmp = (int)tmp;
    else
      break;
    
    if(verify_port((int)tmp)) {
      port=tmp;
      break;
    }
    
    if(getuid() != 0 && tmp < 1000)
      write("You need to be superuser to open a port under 1000. ");
    else
      write("That port number is already used or invalid. ");
    write("Choose another one.\n");
  }

  while(1)
  {
    write("[1mConfigurations Directory [ "+configuration_dir+" ][0m: ");
    tmp = gets();
    if(strlen(tmp))
      configuration_dir = tmp;
    if(configuration_dir[-1] != '/')
      configuration_dir += "/";
    if(sizeof(list_all_configurations())) 
      write("Roxen is already installed in that directory! "
	    "Choose another one.\n");
    else 
      break;
  }
  write("[1mLog Directory [ "+log_dir+" ][0m: ");
  tmp = gets();
  if(strlen(tmp))
    log_dir = tmp;
  if(log_dir[-1] != '/')
    log_dir += "/";
      
  if(log_dir != "../logs/")
    logdir_changed = 1;

  if(configuration_dir != "../configurations" && 
     configuration_dir != "../configurations/")
    configuration_dir_changed = 1;

  mkdirhier("../local/modules/");

  int have_gmp = 0;
  catch(have_gmp = sizeof(indices(master()->resolv("Gmp"))));
  int have_crypto = 0;
  catch(have_crypto = sizeof(indices(master()->resolv("_Crypto"))));
  int have_ssl3 = 0;
  have_ssl3 = file_stat("protocols/ssl3.pike") != 0;

  if (have_gmp && have_crypto && have_ssl3) {
    write("[1mUse SSL3 (https://) for the configuration-interface [Y/n][0m? ");
    tmp = gets() - " ";
    if (!strlen(tmp) || lower_case(tmp)[0] != 'n') {
      prot_prog = "ssl3";
      prot_spec = "https://";
      prot_extras = "cert-file demo_certificate.pem";

      write("Using SSL3 with the demo certificate \"demo_certificate.pem\".\n"
	    "It is recommended that you change the certificate to one of your own.\n");
    }
  } else {
    if (have_crypto && have_ssl3) {
      write("[1mNo Gmp-module -- using http for the configuration-interface[0m.\n");
    } else {
      write("[1mExport version -- using http for the configuration-interface[0m.\n");
    }
  }

  write(sprintf("\nStarting Roxen on %s%s:%d/ ...\n\n",
		prot_spec, host, port));
  
  setglobvar("_v",  CONFIGURATION_FILE_LEVEL);
  setglobvar("ConfigPorts", ({ ({ port, prot_prog, "ANY", prot_extras }) }));
  setglobvar("ConfigurationURL",  prot_spec+host+":"+port+"/");
  setglobvar("logdirprefix", log_dir);

  write(popen("./start "
	      +(configuration_dir_changed?"--config-dir="+configuration_dir
		+" ":"")
	      +(logdir_changed?"--log-dir="+log_dir+" ":"")
	      +argv[1..] * " "));
  
  if(configuration_dir_changed || logdir_changed)
    write("\nAs you use non-standard directories for the configuration \n"
	  "and/or the logging, you must remember to start the server using\n"
	  "the correct options. Run './start --help' for more information.\n");
  
  sleep(4);
  
  write("\nRoxen is configured using a forms capable World Wide Web\n"
	"browser. Enter the name of the browser to start, including\n"
	"needed (if any) command line options.\n\n"
	"If you are going to configure remotely, or already have a browser\n"
	"running, just press return.\n\n"
	"[1mWWW Browser: [0m");
  
  tmp = gets(1);
  if(strlen(tmp))
    client = tmp;
  if(client)
  {
    if (prot_prog == "ssl3") {
      write("Waiting for SSL3 to initialize...\n");
      sleep(40);
    } else {
      sleep(10);
    }
    write("Running "+ client +" "+ prot_spec+host+":"+port+"/\n");
    run((client/" ")[0], @(client/" ")[1..100000], 
	prot_spec+host+":"+port+"/");
  } else
    write("\nTune your favourite browser to "+prot_spec+host+":"+port+"/\n");
}
