import Array;

#include <module.h>

#ifndef IN_INSTALL
inherit "newdecode";
string cvs_version = "$Id: read_config.pike,v 1.18 1998/02/04 16:10:39 per Exp $";

#else
import spider;
# define error(X) do{array Y=backtrace();throw(({(X),Y[..sizeof(Y)-2]}));}while(0)
# include "newdecode.pike"
#endif

import Array;
import Stdio;

mapping (string:mapping) configs = ([ ]);

string configuration_dir; // Set by Roxen.

#ifdef MODULE_DEBUG
int debug_compare_vars(mixed a, mixed b)
{
  if (a == b) {
    switch(sprintf("%t:%t", a, b)) {
    case "int:int":
    case "float:float":
    case "string:string":
    case "program:program":
      break;
    case "object:object":
      write(sprintf("Warning! object in configs!\n"));
      break;
    case "function:function":
      write(sprintf("Warning! function in configs!\n"));
      break;
    case "array:array":
      if (sizeof(a)) {
	write(sprintf("Arrays don't differ! %O\n", a));
	return(0);
      }
      break;
    case "multiset:multiset":
      write(sprintf("Multisets don't differ! %O\n", a));
      return(0);
      break;
    case "mapping:mapping":
      write(sprintf("Mappings don't differ! %O\n", a));
      return(0);
      break;
    default:
      write(sprintf("Type mismatch: %O (%t) != %O (%t)\n", a, a, b, b));
      return(0);
      break;
    }
  } else {
    switch(sprintf("%t:%t", a, b)) {
    case "int:int":
    case "float:float":
    case "string:string":
    case "program:program":
      write(sprintf("Error! %O (%t) differs from %O (%t)!\n", a, a, b, b));
      return(0);
      break;
    case "object:object":
      write(sprintf("Error! objects in configs differ!\n"));
      return(0);
      break;
    case "function:function":
      write(sprintf("Error! functions in configs differ!\n"));
      return(0);
      break;
    case "array:array":
      if (sizeof(a) != sizeof(b)) {
	write(sprintf("Error! Array sizes differ! %O (%d) != %O (%d)\n",
		      a, sizeof(a), b, sizeof(b)));
	return(0);
      }
      foreach(indices(a), int i) {
	if (!debug_compare_vars(a[i], b[i])) {
	  return(0);
	}
      }
      break;
    case "multiset:multiset":
      if (sizeof(a) != sizeof(b)) {
	write(sprintf("Error! Multiset sizes differ! %O (%d) != %O (%d)\n",
		      a, sizeof(a), b, sizeof(b)));
	return(0);
      }
      foreach(indices(a), mixed i) {
	if (!b[i]) {
	  write(sprintf("Error! Multiset contents differ! %O != %O (%O not in latter)\n",
			a, b, i));
	  return(0);
	}
      }
      break;
    case "mapping:mapping":
      if (sizeof(a) != sizeof(b)) {
	write(sprintf("Error! Mapping sizes differ! %O (%d) != %O (%d)\n",
		      a, sizeof(a), b, sizeof(b)));
	return(0);
      }
      foreach(indices(a), mixed i) {
	if (zero_type(b[i])) {
	  write(sprintf("Error! Mapping indices differ! %O != %O (%O not in latter)\n",
			a, b, i));
	  return(0);
	}
	if (!debug_compare_vars(a[i], b[i])) {
	  return(0);
	}
      }
      break;
    default:
      write(sprintf("Type mismatch: %O (%t) != %O (%t)\n", a, a, b, b));
      return(0);
      break;
    }
  }
  return(1);
} 
#endif /* MODULE_DEBUG */


mapping copy_configuration(string from, string to)
{
  if(!configs[from])
    return 0;
#ifdef DEBUG
  write(sprintf("Copying configuration \"%s\" to \"%s\"\n",
		from, to));
#endif /* DEBUG */
  configs[to] = copy_value(configs[from]);
#ifdef MODULE_DEBUG
  if (!debug_compare_vars(configs[from], configs[to])) {
    write(sprintf("Copies don't differ!\n"));
  }
#endif /* MODULE_DEBUG */
  return configs[to];
}

array (string) list_all_configurations()
{
  array (string) fii;
  fii=get_dir(configuration_dir);
  if(!fii)
  {
    mkdirhier(configuration_dir+"test"); // removes the last element..
    fii=get_dir(configuration_dir);
    if(!fii)
    {
      werror("I cannot read from the configurations directory ("+
	     combine_path(getcwd(), configuration_dir)+")\n");
      exit(-1);	// Restart.
    }
    return ({});
  }
  return map(filter(fii, lambda(string s){
    if(s=="CVS" || s=="Global_Variables" || s=="Global Variables"
       || s=="global_variables" || s=="global variables" )
      return 0;
    return (s[-1]!='~' && s[0]!='#' && s[0]!='.');
  }), lambda(string s) { return replace(s, "_", " "); });
}

void save_it(string cl)
{
  object fd;
  string f;
#ifdef DEBUG_CONFIG
  perror("CONFIG: Writing configuration file for cl "+cl+"\n");
#endif


  f = configuration_dir + replace(cl, " ", "_");
#ifndef THREADS
  object privs = Privs("Saving config file"); // Change to root user.
#endif
  mv(f, f+"~");
  fd = open(f, "wc");
#if efun(chmod)
  if(geteuid() != getuid()) chmod(f,0660);
#endif
#ifndef THREADS
  privs=0;
#endif
  if(!fd)
  {
    error("Creation of configuration file failed ("+f+") "
#if 0&&efun(strerror)
	  " ("+strerror()+")"
#endif
	  "\n");
    return;
  }
  string data = encode_regions( configs[ cl ] );
  int num;
  catch(num = fd->write(data));
  if(num != strlen(data))
  {
    error("Failed to write all data to configuration file ("+f+") "
#if efun(strerror)
	  " ("+strerror(fd->errno())+")"
#endif
	  "\n");
  }
  catch(fd->close("w"));
  destruct(fd);
}

void fix_config(mapping c);

array fix_array(array c)
{
  int i;
  for(i=0; i<sizeof(c); i++)
    if(arrayp(c[i]))
      fix_array(c[i]);
    else if(mappingp(c[i]))
      fix_config(c[i]);
    else if(stringp(c[i]))
      c[i]=replace(c[i],".lpc#", "#");
}

void fix_config(mixed c)
{
  mixed l;
  if(arrayp(c)) {
    fix_array((array)c);
    return;
  }
  if(!mappingp(c)) return;
  foreach(indices(c), l)
  {
    if(stringp(l) && (search(l, ".lpc") != -1))
    {
      string n = l-".lpc";
      c[n]=c[l];
      m_delete(c,l);
    }
  }
  foreach(values(c),l)
  {
    if(mappingp(l)) fix_config(l);
    else if(arrayp(l)) fix_array(l);
    else if (multisetp(l)) perror("Warning; illegal value of config\n");
  }
}

private static void read_it(string cl)
{
  if(configs[cl]) return;

  object fd;
#ifndef THREADS
  object privs = Privs("Reading config file"); // Change to root user.
#endif

  catch {
    fd = open(configuration_dir + replace(cl, " ", "_"), "r");

    if(!fd)
    {
      fd = open(configuration_dir + cl, "r");
      if(fd) rm(configuration_dir + cl);
    }
  
    if(!fd)
      configs[cl] = ([ ]);
    else
    {
      configs[cl] = decode_config_file( fd->read( 0x7fffffff ));
      fd->close("rw");
      fix_config(configs[cl]);
      destruct(fd);
    }
  };
}


void remove( string reg , object current_configuration) 
{
  string cl;
#ifndef IN_INSTALL
  if(!current_configuration)
#endif
    cl="Global Variables";
#ifndef IN_INSTALL
  else
    cl=current_configuration->name;
#endif
  read_it(cl);

  m_delete(configs[cl], reg);
  save_it(cl);
}

void remove_configuration( string name )
{
  string f;

#ifndef THREADS
  object privs = Privs("Removing config file"); // Change to root user.
#endif

  f = configuration_dir + replace(name, " ", "_");
  if(!file_stat( f ))   f = configuration_dir + name;
  if(!rm(f) && file_stat(f))
  {
    error("Failed to remove configuration file ("+f+")! "+
#if 0&&efun(strerror)
	  strerror()
#endif
	  "\n");
  }
}

void store( string reg, mapping vars, int q, object current_configuration )
{
  string cl;
  mapping m;
#ifndef IN_INSTALL
  if(!current_configuration)
#endif
    cl="Global Variables";
#ifndef IN_INSTALL
  else
    cl=current_configuration->name;
#endif
  read_it(cl);

  if(q)
    configs[cl][reg] = copy_value(vars);
  else
  {
    mixed var;
    m = ([ ]);
    foreach(indices(vars), var)
      m[copy_value(var)] = copy_value( vars[ var ][ VAR_VALUE ] );
    configs[cl][reg] = m;
  }    
  save_it(cl);
}


mapping retrieve(string reg, object current_configuration)
{
  string cl;
#ifndef IN_INSTALL
  if(!current_configuration)
#endif
    cl="Global Variables";
#ifndef IN_INSTALL
  else
    cl=current_configuration->name;
#endif
  
  read_it(cl);

  return configs[cl][reg] || ([ ]);
}
