// This is a roxen module. (c) Informationsvävarna AB 1996.

// Index files only module, a directory module that will not try to
// generate any directory listings, instead only using index files.

string cvs_version = "$Id: indexfiles.pike,v 1.3 1996/11/27 13:47:58 per Exp $";
#include <module.h>
inherit "module";
inherit "roxenlib";

//************** Generic module stuff ***************

array register_module()
{
  return ({ MODULE_DIRECTORIES, 
	    "Index files only",
	    "You can use this directory module if you do _not_ want "
	    "directory listings.\n",
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
}

// The only important function in this file...
// Given a request ID, try to find a matching index file.
// If one is found, return it, if not, simply return "no such file" (0)
mapping parse_directory(object id)
{
  // Redirect to an url with a '/' at the end, to make relative links
  // work as expected.
  if(id->not_query[-1] != '/') return http_redirect(id->not_query+"/", id);

  string oq = id->not_query;
  string file;
  foreach(query("indexfiles"), file)
  {
    mapping result;
    id->not_query = oq+file;
    if(result=roxen->get_file(id))
      return result; // File found, return it.
  }
  id->not_query = oq;
  return 0;
}


