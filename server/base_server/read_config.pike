#include <module.h>

#ifndef IN_INSTALL
inherit "newdecode";
string cvs_version = "$Id: read_config.pike,v 1.7 1997/01/29 04:59:36 per Exp $";
#else
# include "base_server/newdecode.pike"
#endif

private mapping (string:mapping) configs = ([ ]);

string configuration_dir; // Set by Roxen.


mapping copy_configuration(string from, string to)
{
  if(!configs[from])
    return 0;
  configs[to] = copy_value(configs[from]);
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
      exit(0);
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

  object privs = ((program)"privs")("Saving config file"); // Change to root user.

  f = configuration_dir + replace(cl, " ", "_");
  mv(f, f+"~");
  fd = open(f, "wc");
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
#if 0&&efun(strerror)
	  " ("+strerror()+")"
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
  if(arrayp(c)) return (void)fix_array((array)c);
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

  object privs = ((program)"privs")("Reading config file"); // Change to root user.

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

  object privs = ((program)"privs")("Removing config file"); // Change to root user.

  f = configuration_dir + replace(name, " ", "_");
  if(file_size( f )==-1)   f = configuration_dir + name;
  if(!rm(f))
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
