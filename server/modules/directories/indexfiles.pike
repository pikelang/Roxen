#include <module.h>
inherit "module";
inherit "roxenlib";

/************** Generic module stuff ***************/

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

mapping parse_directory(object id)
{
  string file;

  if(id->not_query[-1] == '.' && id->not_query[-2]=='/')
    return http_redirect(id->not_query[..strlen(id->not_query)-2], id);

  if(id->not_query[-1] != '/')
    return http_redirect(id->not_query+"/", id);
  
  string oq = id->not_query;
  mapping result;
  foreach(query("indexfiles"), file)
  {
    id->not_query = oq+file;
    if(result=roxen->get_file(id))
    {
      id->not_query = oq;
      return result;
    }
  }
  id->not_query = oq;
  return 0;
}


