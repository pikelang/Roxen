// This is a roxen module. Copyright © 1996 - 2009, Roxen IS.

// This module handles all normal extension to content type
// mapping. Given the file 'foo.html', it will per default
// set the contenttype to 'text/html'

inherit "module";
#include <module.h>

constant cvs_version = "$Id$";
constant thread_safe = 1;
constant module_type = MODULE_TYPES;
constant module_name = "Content types";
constant module_doc  = #"This module handles all normal extension to content type mapping.
Given the file 'foo.html', it will normally set the content type to 'text/html'.";

mapping (string:string) extensions=([]), encodings=([]);
mapping  (string:int) accessed=([]);

void create()
{
  defvar("exts", Variable.Text(#"# This will include the defaults from a file.
# Feel free to add to this, but do it after the #include
# line if you want to override any defaults

#include <etc/extensions>", VAR_NOT_CFIF, "Extensions",
#"This is file extension to content type mapping. The format is as
follows: <table><tr><th>extension</th><th>type</th><th>encoding</th></tr>
<tr><td>gif</td><td>image/gif</td></tr>
<tr><td>gz</td> <td>STRIP</td><td>application/gnuzip</td></tr></table>
For a list of types, see <a
href='http://www.iana.org/assignments/media-types'
>http://www.iana.org/assignments/media-types</a>"));

  defvar("default", 
         Variable.String("application/octet-stream", VAR_NOT_CFIF,
                         "Default content type",
                         "This is the default content type which is "
                         "used if a file lacks extension or if the "
                         "extension is unknown.\n"));
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
	if(catch(s=lopen(file,"r")->read()))
          report_warning( "Failed to include "+file+"\n");
        else
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
  parse_ext_string(query("exts"));
}

array(string|int) type_from_extension(string ext)
//! Return an array <tt>({ content_type, content_encoding })</tt>
//! devised from the file extension `ext'. When `ext' equals
//! "default", roxen wants to know a default type/encoding. If the
//! content-type returned is the string <tt>"strip"</tt>, the
//! content-encoding returned will be kept, and another call be made
//! for the last-but-one file extension to get the content type (eg
//! for <tt>".tar.gz"</tt> to resolve correctly).
{
  accessed[ ext ]++;
  if(ext == "default")
    return ({ query("default"), 0 });
  if(extensions[ ext ])
    return ({ extensions[ ext ], encodings[ ext ] });
}
