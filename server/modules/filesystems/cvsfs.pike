/* cvsfs.pike
 *
 * A location module for accessing files under CVS from Roxen.
 *
 * Written by Niels Möller 1997
 */

static string cvs_version = "$Id: cvsfs.pike,v 1.4 1997/02/07 23:08:45 nisse Exp $";

#include <module.h>
#include <string.h>
#include <roxen.h>

inherit "module";
inherit "roxenlib";

string cvs_module_path = 0; /* Path in CVS repository */

int accesses, dirlists, errors;

object|array run_cvs(string prog, string dir, int with_stderr, string ...args)
{
  object stdin = File();
  object stdout = File();
  object stderr = File();
  int id;
  object|array result;

  werror(sprintf("run_cvs: %s %s\n", prog, args * " ")); 
  
  stdin->open("/dev/null", "r");
  if (with_stderr)
    result = ({ stdout->pipe(), stderr->pipe() });
  else
    {
      stderr->create("stderr");
      result = stdout->pipe();
    }
  return (spawne(prog, args, 0, stdin, stdout, stderr, dir) > 0)
    ? result : 0;
}

mapping parse_modules_file(string modules)
{
  int i;
  array rows = map(replace(modules, "\t", " ") / "\n",
		   lambda (string row) { return (row / " ") - ({""}); } ) - ({ ({}) }) ;
  // werror(sprintf("parse_modules_file: %O\n", rows));
  return mkmapping(map(rows, lambda(array data) { return data[0]; }), rows);
}

string handle_cvs_comments_etc(string data)
{ /* This would be unnecessary if cvs co -c worked */
  int i=0;
  data = replace(data, "\\\n", " ");
  while ((i = search(data, "#", i)) != -1)
    {
      int end = search(data, "\n", i);
      if (end == -1)
	{
	  data = data[..i-1];
	  break;
	}
      else
	data = data[..i-1] + data[end..];
    }
  return data;
}
      	   
string lookup_cvs_module(string prog, string root, string module)
{
  /* cvs checkout -c is not eightbit clean. argh! */
  object f;
  string mods;

  f = run_cvs(prog, 0, 0, "-d", root, "checkout", "-p", "CVSROOT/modules");
  if (!f)
    return 0;

  werror("Reading from cvs\n");
  mods = f->read(1000000);
  
  if (!strlen(mods))
    return 0;
  // werror("cvsmodules: " + mods + "\n");
  string mods = handle_cvs_comments_etc(mods);
  // werror("cvsmodules: " + mods + "\n");
  
  array mod = parse_modules_file(mods)[module];
  
  if (!mod)
    return 0;
  werror(sprintf("Module: %O\n", mod));
  int index=1;
  while (mod[index][0] == '-') /* Skip flags */
    {
      if (sizeof(mod[index]) == 1)
	{ /* Stop processing options */
	  index++;
	  break;
	}
      if ( (<'d', 'i', 'o', 'e', 's', 't', 'u'>)[mod[index][1]] )
	index+=2;
      else
	index++;
    }
  return mod[index];
}

array register_module()
{
  return ({ MODULE_LOCATION,
	      "CVS File system",
	      "Accessing files under CVS control",
	      0, 0 });
}

void create()
{
  /* defvar()'s */
  defvar("location", "/CVS", "Mount point", TYPE_LOCATION,
	 "This is where the module will be inserted in the "
	 "name space of your server.");
  defvar("cvsroot", getenv("CVSROOT") || "/usr/local/cvs",
	 "CVS repository", TYPE_DIR, "Where CVS stores its files.");
  defvar("cvsprogram", "/usr/local/bin/cvs", "The <tt>cvs</tt> program",
	 TYPE_FILE, "The program used for accessing the CVS repository.");
  defvar("cvsmodule", "NONE", "CVS (sub)module", TYPE_STRING,
	 "<tt>module/subdirectory</tt>, where <tt>module</tt> is a module "
	 "defined in the CVS repository, and <tt>subdirectory</tt> "
	 "is a path to a subdirectory of the module.");
}

string|void check_variable(string name, string value)
{
  string path;
  switch(name)
    {
    case "cvsprogram":
      {
	array info = file_stat(value);
	if (! (info && (info[1] > 0) && (info[0] & 0111 )))
	  return "No such program";
	break;
      }
    case "cvsmodule":
      {
	string path =
	  lookup_cvs_module(query("cvsprogram"), query("cvsroot"),
			    (value / "/")[0] );
	if (! (path && strlen(path) ))
	  return "Module not found in CVS";
	if (!file_stat(query("cvsroot") + path))
	  return "No such subdirectory"; 
	break;
      }
    default:
      return 0;
    }
}

void start()
{
  array path = query("cvsmodule") / "/";
  cvs_module_path =
    lookup_cvs_module(query("cvsprogram"), query("cvsroot"), path[0]) +
    "/" + (path[1..] * "/");
  werror(sprintf("start: cvs_module_path ='%s'\n", cvs_module_path));
}

string status()
{
  return "<h2> Accesses to this filesystem</h2>" +
    (accesses ? ("<b>Normal files</b>: " + (string) accesses + "<br>")
     : "No file accesses<br>") +
    (errors ? ("<b>Errors</b>: " + (string) errors + "<br>") : "") +
    (dirlists ? ("<b>Directories</b>: " + (string) dirlists + "<br>") : "");
}

mixed stat_file(string name, object id)
{
  werror(sprintf("file_stat: Looking for '%s'\n", name));
  name = query("cvsroot") + cvs_module_path + "/" + name;
  return file_stat(name + ",v") || file_stat(name);
}

object|mapping|int find_file(string name, object id)
{
  werror(sprintf("find_file: Looking for '%s'\n", name));
  string fname = query("cvsroot") + cvs_module_path + "/" + name;
  if (cvs_module_path)
    {
      if (file_stat(fname + ",v"))
	{
	  object f = run_cvs(query("cvsprogram"), 0, 0,
			     "-d", query("cvsroot"), "checkout", "-p",
			     cvs_module_path + "/" + name);
	  if (f)
	    accesses++;
	  return f;
	}
      else if (file_stat(fname))
	return -1;
    }
  else
    return 0;
}

array find_dir(string name, object id)
{
  array info;
  string fname = query("cvsroot") + cvs_module_path + "/" + name;
  werror(sprintf("find_dir: Looking for '%s'\n", name));

  if (cvs_module_path
      && (info = file_stat(fname))
      && (info[1] == -2))
    {
      array dir = get_dir(fname);
      if (dir)
	dir = map(dir, lambda(string entry) {
	  return (entry[strlen(entry)-2..] == ",v")
	    ? entry[..strlen(entry)-3] : entry;
	});
      return dir - ({ "Attic" });
    }
  return 0;
}
	  
  
