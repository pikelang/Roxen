// This is a roxen module. Copyright © 1996 - 1999, Idonex AB.

// This module handles all normal extension to content type
// mapping. Given the file 'foo.html', it will per default
// set the contenttype to 'text/html'

constant cvs_version = "$Id: contenttypes.pike,v 1.18 2000/02/17 08:42:43 per Exp $";
constant thread_safe=1;

#include <module.h>
inherit "module";

mapping (string:string) extensions=([]), encodings=([]);
mapping  (string:int) accessed=([]);

void create()
{
  defvar("exts", "\n"
	 "# This will include the defaults from a file.\n"
	 "# Feel free to add to this, but do it after the #include line if\n"
	 "# you want to override any defaults\n"
	 "\n"
	 "#include <etc/extensions>\n\n", "Extensions",
	 TYPE_TEXT_FIELD,
	 "This is file extension "
	 "to content type mapping. The format is as follows:\n"
	 "<pre>extension type encoding\ngif image/gif\n"
	 "gz STRIP application/gnuzip\n</pre>"
	 "For a list of types, see <a href=ftp://ftp.isi.edu/in-"
	 "notes/iana/assignments/media-types/media-types>ftp://ftp"
	 ".isi.edu/in-notes/iana/assignments/media-types/media-types</a>");

  defvar("default", "application/octet-stream", "Default content type",
	 TYPE_STRING,
	 "This is the default content type which is used if a file lacks "
	 "extension or if the extension is unknown.\n");
}

string status()
{
  string b=sizeof(extensions) + " extensions, " + sizeof(accessed)+" used.\n"
    "<h3>Accesses per extension</h3>\n\n<table border=1 cellpadding=4 cellspacing=0>";
  foreach(indices(accessed), string a)
    b += "<tr><td>"+a+"</td><td>"+accessed[ a ]+"</td></tr>\n";
  return b+"</table>\n";
}

void parse_ext_string(string exts)
{
  string line;
  array(string) f;

  foreach((exts-"\r")/"\n", line)
  {
    if(!strlen(line))  continue;
    if(line[0]=='#')
    {
      string file;
      if(sscanf(line, "#include <%s>", file))
      {
	string s;
	if(s=Stdio.read_bytes(file))
          parse_ext_string(s);
      }
    } else {
      f = (replace(line, "\t", " ")/" "-({""}));
      if(sizeof(f) >= 2)
      {
	if(sizeof(f) > 2) encodings[lower_case(f[0])] = lower_case(f[2]);
	extensions[lower_case(f[0])] = lower_case(f[1]);
      }
    }
  }
}

void start()
{
  parse_ext_string(QUERY(exts));
}

constant module_type = MODULE_TYPES;
constant module_name = "Content types";
constant module_doc  = "This module handles all normal extension to "
  "content type mapping. Given the file 'foo.html', it will "
  "normally set the content type to 'text/html'.";

array type_from_extension(string ext)
{
  if(ext == "default") {
    accessed[ ext ] ++;
    return ({ QUERY(default), 0 });
  } else if(extensions[ ext ]) {
    accessed[ ext ]++;
    return ({ extensions[ ext ], encodings[ ext ] });
  }
}
