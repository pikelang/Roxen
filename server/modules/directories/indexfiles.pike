/* This is a roxen module. Copyright © 1996 - 1998, Idonex AB.
 *
 * Index files only module, a directory module that will not try to
 * generate any directory listings, instead only using index files.
 */

constant cvs_version = "$Id: indexfiles.pike,v 1.9 1999/01/14 00:51:37 grubba Exp $";
constant thread_safe=1;

#include <module.h>
inherit "module";
inherit "roxenlib";

//************** Generic module stuff ***************

array register_module()
{
  return ({ MODULE_DIRECTORIES, 
	    "Index files only",
	      "Index files only module, a directory module that will not try "
	      "to generate any directory listings, instead only using the  "
	      "specified index files.<p>"
	      "You can use this directory module if you do not want "
	      "any automatic directory listings at all, but still want \n"
	      "to use index.html with friends",
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
  if(id->not_query[-1] != '/') {
    string new_query = http_encode_string(id->not_query) + "/" +
      (id->query?("?" + id->query):"");
    return http_redirect(new_query, id);
  }

  string oq = id->not_query;
  string file;
  foreach(query("indexfiles"), file)
  {
    mapping result;
    id->not_query = oq+file;
    if(result=id->conf->get_file(id))
      return result; // File found, return it.
  }
  id->not_query = oq;
  return 0;
}
