// This is a Roxen module. Copyright © 1996 - 1999, Idonex AB
//
// Directory listings mark 2
//
// Henrik Grubbström 1997-02-13
// Martin Nilsson 1999-12-27
//
// TODO:
// Filter out body statements and replace them with tables to simulate
// the correct background and fontcolors.
//
// Make sure links work _inside_ unfolded dokuments.

string cvs_version = "$Id: directories.pike,v 1.36 1999/12/28 15:19:45 grubba Exp $";
constant thread_safe=1;

#include <module.h>
inherit "module";
inherit "roxenlib";

array README;
string OUT_FORM;
void start( int num, Configuration conf )
{
  README=query("Readme");
  OUT_FORM="<img border=\"0\" src=\"%s\" alt=\"\"> "
    "<a href=\"%s\">%-40s</a>"+
    (query("size")?"   %11s":"%.0s")+
    (query("date")!="Don't show dates"?"   %s":"%.0s")+
    "   %s\n";

}

array register_module()
{
  return ({ MODULE_DIRECTORIES | MODULE_PARSER,
	    "Enhanced directory listings",
	    "This module is an experimental directory parsing module. "
	    "It pretty prints a list of files much like the ordinary "
	    "directory parsing module. "
	    "The difference is that this one uses the flik-module "
	    "for the fold/unfolding, and uses relative URL's.",
	      0, 1 });
}

void create()
{
  defvar("indexfiles", ({ "index.html", "Main.html", "welcome.html",
			  "index.cgi", "index.lpc", "index.pike" }),
	 "Index files", TYPE_STRING_LIST,
	 "If one of these files is present in a directory, it will "
	 "be returned instead of the directory listing.");

  defvar("Readme", ({ "README.html", "README" }),
	 "Include readme files", TYPE_STRING_LIST,
	 "Include one of these readme files in directory listings");

  defvar("override", 0, "Allow directory index file overrides", TYPE_FLAG,
	 "If this variable is set, you can get a listing of all files "
	 "in a directory by appending '.' or '/' to the directory name, like "
	 "this: <a href=http://www.roxen.com//>http://www.roxen.com//</a>"
	 ". It is _very_ useful for debugging, but some people regard it as a "
	 "security hole.");

  defvar("size", 1, "Include file size", TYPE_FLAG,
	 "If set, include the size of the file in the listing.");

  defvar("spartan", 0, "Spartan listings.", TYPE_FLAG,
	 "Show minimalistic file listings.");

  defvar("date", "Don't show dates", "Dates", TYPE_MULTIPLE_STRING,
	 "Select whether to include the last modification date in directory "
	 "listings, and if so, on what format. `ISO dates' gives dates "
         "like 1999-11-26, while `Text dates' gives dates like `Fri Nov 26, "
         "1999'.",
         ({ "Don't show dates", "Show ISO dates", "Show CTIME dates" }));
}

string tag_directory_insert(string t, mapping m, RequestID id)
{
  if(!m->file) return rxml_error(t, "File not specified.", id);
  if(m->dir) {
    string old_base=id->misc->rel_base||"";
    id->misc->rel_base=old_base+m->file;
    string ret=describe_directory(m->file, id);
    id->misc->rel_base=old_base;
    return ret;
  }
  Stdio.File f;
  if(f=open(fix_relative(m->file, id), "r")) {
    string s=f->read();
    if(s && m->quote=="none") return s;
    if(s) return html_encode_string(s);
  }

  return rxml_error(t, "Couldn't open file \""+m->file+"\".", id);
}

string find_readme(string d, RequestID id)
{
  foreach(query("Readme"), string f) {
    string readme = id->conf->try_get_file(d+f, id);

    if (readme) {
      if (id->conf->type_from_filename(f)!="text/html")
	readme = "<pre>" + html_encode_string(readme) +"</pre>";
      return "<hr noshade>"+readme;
    }
  }
  return "";
}

string spartan_directory(string d, RequestID id)
{
  array(string) path = d/"/" - ({ "","." });
  d = "/"+path*"/" + "/";
  array(string) dir = id->conf->find_dir(d, id)||({});
  if (sizeof(dir)) dir = sort(dir);

  return sprintf("<html><head><title>Directory listing of %s</title></head>\n"
		 "<body><h1>Directory listing of %s</h1>\n"
		 "<pre>%s</pre></body</html>\n",
		 d, d,
		 Array.map(sort(dir),
			   lambda(string f, string d, object r, RequestID id)
			   {
			     array stats = r->stat_file(d+f, id);
			     if(stats && stats[1]<0)
			       return "<a href=\""+f+"/.\">"+f+"/</a>";
			     else
			       return "<a href=\""+f+"\">"+f+"</a>";
			   }, d, id->conf, id)*"\n"+"</pre></body></html>\n");
}

string describe_directory(string d, RequestID id)
{
  array(string) path = d/"/" - ({ "","." });
  d = "/"+path*"/" + "/";
  array(string) dir = id->conf->find_dir(d, id)||({});
  if (sizeof(dir)) dir = sort(dir);

  string result="";
  int toplevel=!id->misc->dir_no_head++;
  if(toplevel)
  {
    result = "<html><head><title>Directory listing of "+d+"</title></head>\n"
	     "<body><debug on>\n<h1>Directory listing of "+d+"</h1>\n<p>";

    if(sizeof(README))
      result += find_readme(d, id);
    result += "<hr noshade><pre>\n";
  }

  if(id->misc->foldlist_exists) result += "<foldlist folded>\n";

  foreach(sort(dir), string file) {
    array stats = id->conf->stat_file(d + file, id);
    string type = "Unknown";
    string icon;
    int len = 0;
    string mtime = "";
    if(stats) {
      len=stats[1];
      switch(query("date")) {
      case "Show CTIME dates":
        mtime=ctime(stats[3]);
        mtime=mtime[0..sizeof(mtime)-2];
	break;
      case "Show ISO dates":
	mapping t=localtime(stats[3]);
	mtime=sprintf("%4d-%02d-%02d %02d:%02d.%02d", t->year+1900, t->mon+1,
		      t->mday, t->hour, t->min, t->sec);
      }
    }

    switch(-len) {
    case 3:
    case 2:
      type = ({ 0,0,"Directory","Module location" })[-stats[1]];

      /* Directory or module */
      file += "/";
      icon = "internal-gopher-menu";

      break;
    default:
      array tmp = id->conf->type_from_filename(file,1);
      if (tmp) type = tmp[0];
      icon = image_from_type(type);
      if (tmp && tmp[1]) type += " " + tmp[1];

      break;
    }
    if(id->misc->foldlist_exists) result+="<ft>";
    result += sprintf(OUT_FORM, icon, id->misc->rel_base+file, file,
		      sizetostring(len), mtime, type);

    array(string) split_type = type/"/"+({"",""});
    string extras = "No support for this file type.";

    switch(split_type[0]) {
    case "text":
      switch(split_type[1]) {
      case "html":
	extras = "</pre>\n<directory-insert quote=none file=\""+d+file+"\"><pre>";
	break;
      default:
	extras = "<directory-insert file=\""+d+file+"\">";
	break;
      }
      break;
    case "application":
      switch(split_type[1]) {
      case "x-include-file":
      case "x-c-code":
	extras = "<directory-insert file=\""+d+file+"\">";
	break;
      }
      break;
    case "image":
      extras = "<img src=\""+ replace( d, "//", "/" ) + file +"\" border=\"0\">";
      break;
    case "Directory":
    case "Module location":
      extras = "<directory-insert nocache file=\""+d+file+"\" dir>";
      break;
    case "Unknown":
      switch(lower_case(file)) {
      case ".cvsignore":
      case "configure":
      case "configure.in":
      case "bugs":
      case "copying":
      case "copyright":
      case "changelog":
      case "disclaimer":
      case "makefile":
      case "makefile.in":
      case "readme":
	extras = "<directory-insert file=\""+d+file+"\">";
	break;
      }
      break;
    }
    if(id->misc->foldlist_exists) result += "<fd>"+extras+"</fd></ft>\n";
  }
  if(id->misc->foldlist_exists) result += "</foldlist>\n";
  if (toplevel) {
    result +="</pre></body></html>\n";
  }

  return result;
}

string|mapping parse_directory(RequestID id)
{
  string f = id->not_query;

  // First fix the URL
  //
  // It must end with "/" or "/."

  if(strlen(f) > 1)
  {
    if(f[-1]!='/' && f[-1]!='.') return http_redirect(f+"/", id);
    if(!QUERY(override)) {
      if(f[-1]=='/' && f[-2]=='/') return http_redirect((f/"/"-({""}))*"/"+"/", id);
      if(f[-1]=='.') return http_redirect(f[..sizeof(f)-3], id);
    }
  }
  else if(f != "/" )
    return http_redirect(id->not_query+"/", id);

  // If the pathname ends with '.', and the 'override' variable
  // is set, a directory listing should be sent instead of the
  // indexfile.

  if(f[-1] == '/') /* Handle indexfiles */
  {
    string file;
    foreach(query("indexfiles") - ({""}), file) {
      if(id->conf->stat_file(f+file, id))
      {
	id->not_query = f + file;
	mapping got = id->conf->get_file(id);
	if (got) {
	  return(got);
	}
      }
    }
    // Restore the old query.
    id->not_query = f;
  }

  if(query("spartan") || id->prestate->spartan_directory)
    return http_string_answer(spartan_directory(f,id));

  id->misc->foldlist_exists=search(indices(id->conf->modules),"foldlist")!=-1;
  id->misc->rel_base="";
  return http_string_answer(parse_rxml(describe_directory(f, id), id));
}
