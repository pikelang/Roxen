// This is a roxen module. (c) Informationsvävarna AB 1996.

// This module handles all normal extension to contenttype
// mapping. Given the file 'foo.html', it will per default
// set the contenttype to 'text/html'

string cvs_version = "$Id: contenttypes.pike,v 1.3 1996/11/27 13:48:06 per Exp $";
#include <module.h>
inherit "module";

mapping (string:string) extensions=([]), encodings=([]);
mapping  (string:int) accessed=([]);

void create()
{
  defvar("exts", "\
string cvs_version = "$Id: contenttypes.pike,v 1.3 1996/11/27 13:48:06 per Exp $";
# This will include the defaults from a file.\
string cvs_version = "$Id: contenttypes.pike,v 1.3 1996/11/27 13:48:06 per Exp $";
# Feel free to add to this, but do it after the #include line if\
string cvs_version = "$Id: contenttypes.pike,v 1.3 1996/11/27 13:48:06 per Exp $";
# you want to override any defaults\
\
string cvs_version = "$Id: contenttypes.pike,v 1.3 1996/11/27 13:48:06 per Exp $";
#include <etc/extensions>\
", "Extensions", 
	 TYPE_TEXT_FIELD, 
	 "This is file extension "+
	 "to contenttype mapping. The format is as follows:\n"+
	 "<pre>extension type encoding\ngif image/gif\n"+
	 "gz STRIP application/gnuzip\n</pre>"
	 "For a list of types, see <a href=ftp://ftp.isi.edu/in-"
	 "notes/iana/assignments/media-types/media-types>ftp://ftp"
	 ".isi.edu/in-notes/iana/assignments/media-types/media-types</a>");
}

string status()
{
  string a,b;
  b="<h2>Accesses per extension</h2>\n\n";
  foreach(indices(accessed), a)
    b += a+": "+accessed[ a ]+"<br>\n";
  return b;
}

string comment()
{
  return sizeof(extensions) + " extensions, " + sizeof(accessed)+" used.";
}

void parse_ext_string(string exts)
{
  string line;
  string *f;

  foreach((exts-"\r")/"\n", line)
  {
    if(!strlen(line))  continue;
    if(line[0]=='#')
    {
      string file;
      if(sscanf(line, "#include <%s>", file))
      {
	string s;
	if(s=read_bytes(file)) parse_ext_string(s);
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

array register_module()
{
  return ({ MODULE_TYPES, "Contenttypes",
	    ("This module handles all normal extension to "+
	     "contenttype mapping. Given the file 'foo.html', it will "+
	     "set the contenttype to 'text/html'."), ({}), 1 });
}

array type_from_extension(string ext)
{
  if(extensions[ ext ])
  {
    accessed[ ext ]++;
    return ({ extensions[ ext ], encodings[ ext ] });
  }
}

int may_disable() 
{ 
  return 0; 
}

