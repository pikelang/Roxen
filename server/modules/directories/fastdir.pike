/* This is a roxen module. Copyright © 1996 - 1998, Idonex AB, (c) Idonex AB 1998
 *
 * A fast directory module, without support for the fold/unfold stuff
 * in the normal one.
 */

constant cvs_version = "$Id: fastdir.pike,v 1.12 1998/03/11 19:42:35 neotron Exp $";
int thread_safe=1;

#include <module.h>
inherit "module";
inherit "roxenlib";

/************** Generic module stuff ***************/

array register_module()
{
  return ({ MODULE_DIRECTORIES, 
	    "Fast directory module",
	    "This is a _fast_ directory parsing module. "
	    "Basically, this one just prints the list of files.", 
	    ({ }), 
	    1
         });
}

void create()
{
  defvar("indexfiles", ({ "index.html", "Main.html", "welcome.html", }),
	 "Index files", TYPE_STRING_LIST,
	 "If one of these files is present in a directory, it will "
	 "be returned instead of 'no such file'.");

  defvar("readme", 1, "Include readme files", TYPE_FLAG,
	 "If set, include readme files in directory listings");

  defvar("override", 0, "Allow directory index file overrides", TYPE_FLAG,
	 "If this variable is set, you can get a listing of all files "
	 "in a directory by appending '.' or '/' to the directory name, like "
	 "this: <a href=http://www.roxen.com//>http://www.roxen.com//</a>"
	 ". It is _very_ useful for debugging, but some people regard it as a "
	 "security hole.");
}

/*  Module specific stuff */


#define TYPE_MP  "    Module location"
#define TYPE_DIR "    Directory"


inline string image(string f) 
{ 
  return ("<img border=0 src="+(f)+" alt=>"); 
}

inline string link(string a, string b) 
{ 
  return ("<a href="+replace(b, ({ "//", "#" }), ({ "/", "%23" }))
	  +">"+a+"</a>"); 
}

string find_readme(string path, object id)
{
  string rm, f;
  object n;
  foreach(({ "README.html", "README" }), f)
  {
    rm=roxen->try_get_file(path+f, id);
    if(rm) if(f[-1] == 'l')
      return "<hr noshade>"+rm;
    else
      return "<pre><hr noshade>"+
	replace(rm, ({"<",">","&"}), ({"&lt;","&gt;","&amp;"}))+"</pre>";
  }
  return "";
}

string head(string path,object id)
{
  string rm="";

  if(QUERY(readme)) 
    rm=find_readme(path,id);
  
  return ("<h1>Directory listing of "+path+"</h1>\n<p>"+rm
	  +"<pre>\n<hr noshade>");
}

string describe_dir_entry(string path, string filename, array stat)
{
  string type, icon;
  int len;
  
  if(!stat)
    return "";

  switch(len=stat[1])
  {
   case -3:
    type = TYPE_MP;
    icon = "internal-gopher-menu";
    filename += "/";
    break;
      
   case -2:
    type = TYPE_DIR;
    filename += "/";
    icon = "internal-gopher-menu";
    break;
      
   default:
    array tmp;
    tmp = roxen->type_from_filename(filename, 1);
    if(!tmp)
      tmp=({ "Unknown", 0 });
    type = tmp[0];
    icon = image_from_type(type);
    if(tmp[1])  type += " " + tmp[1];
  }
  
  return sprintf("%s %s %8s %-20s\n", 	
		 link(image(icon), http_encode_string(path + filename)),
		 link(sprintf("%-35s", filename[0..34]), 
		      http_encode_string(path + filename)),
		 sizetostring(len), type);
}

static private string key;

void start()
{
  key="file:"+roxen->current_configuration->name;
}

string new_dir(string path, object id)
{
  int i;
  array files;
  string fname;

  files = roxen->find_dir(path, id);
  if(!files) return "<h1>There is no such directory.</h1>";
  sort(files);

  for(i=0; i<sizeof(files) ; i++)
  {
    fname = replace(path+files[i], "//", "/");
    files[i] = describe_dir_entry(path,files[i],roxen->stat_file(fname, id));
  }
  return files * "";
}

mapping parse_directory(object id)
{
  string f;
  string dir;
  array indexfiles;

  f=id->not_query;

  if(strlen(f) > 1)
  {
    if(!((f[-1] == '/') ||
	 (QUERY(override) && (f[-1] == '.') && (f[-2] == '/'))))
      return http_redirect(id->not_query+"/", id);
  } else {
    if(f != "/" )
      return http_redirect(id->not_query+"/", id);
  }

  // At this point the last character is either
  // a '.' in which case we should give a directory listing,
  // or a '/' in which case we should search for an index-file.
  if(f[-1] == '/') /* Handle indexfiles */
  {
    string file;
    foreach(query("indexfiles") - ({""}), file) {
      if(roxen->stat_file(f+file, id))
      {
	id->not_query = f + file;
	mapping got = roxen->get_file(id);
	if (got) {
	  return(got);
	}
      }
    }
    // Restore the old query.
    id->not_query = f;
  }

  if (f[-1] == '.') {
    // Remove the override '.'.
    f = f[..sizeof(f)-2];
  }
  
  if(id->pragma["no-cache"] || !(dir = cache_lookup(key, f))) {
    cache_set(key, f, dir=new_dir(f, id));
  }
  return http_string_answer(head(f, id) + dir);
}


