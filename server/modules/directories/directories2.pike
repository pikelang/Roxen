/* This is a Roxen module. Copyright © 1996 - 1998, Idonex AB
 * $Id: directories2.pike,v 1.13 1999/01/14 00:43:57 grubba Exp $
 *
 * Directory listings mark 2
 *
 * Henrik Grubbström 1997-02-13
 *
 * TODO:
 * Filter out body statements and replace them with tables to simulate
 * the correct background and fontcolors.
 *
 * Make sure links work _inside_ unfolded dokuments.
 */

constant cvs_version = "$Id: directories2.pike,v 1.13 1999/01/14 00:43:57 grubba Exp $";
constant thread_safe=1;

#include <module.h>
inherit "module";
inherit "roxenlib";

import Array;

void start( int num, object conf )
{
  module_dependencies (conf, ({ "flik", "htmlparse" }));
}

array register_module()
{
  return ({ MODULE_DIRECTORIES | MODULE_PARSER,
	      "Enhanced directory listings",
	      "This module is an experimental directory parsing module. "
	      "It pretty prints a list of files much like the ordinary "
	      "directory parsing module. "
	      "The difference is that this one uses the flik-module "
	      "for the fold/unfolding, and uses relative URL's with "
	      "the help of some new tags: "
	      "&lt;REL&gt;, &lt;AREL&gt; and &lt;INSERT-QUOTED&gt;.",
	      ({ }), 1 });
}

int dirlisting_not_set()
{
  return(!QUERY(dirlisting));
}

void create()
{
  defvar("indexfiles", ({ "index.html", "Main.html", "welcome.html",
			  "index.cgi", "index.lpc", "index.pike" }),
	 "Index files", TYPE_STRING_LIST,
	 "If one of these files is present in a directory, it will "
	 "be returned instead of the directory listing.");

  defvar("dirlisting", 1, "Enable directory listings", TYPE_FLAG,
	 "If set, a directory listing is generated if there is "
	 "no index file for the directory.<br>\n"
	 "If disabled, a file not found error will be generated "
	 "instead.<br>\n");

  defvar("readme", 1, "Include readme files", TYPE_FLAG,
	 "If set, include readme files in directory listings",
	 0, dirlisting_not_set);
  
  defvar("override", 0, "Allow directory index file overrides", TYPE_FLAG,
	 "If this variable is set, you can get a listing of all files "
	 "in a directory by appending '.' or '/' to the directory name, like "
	 "this: <a href=http://www.roxen.com//>http://www.roxen.com//</a>"
	 ". It is _very_ useful for debugging, but some people regard it as a "
	 "security hole.",
	 0, dirlisting_not_set);
  
  defvar("size", 1, "Include file size", TYPE_FLAG,
	 "If set, include the size of the file in the listing.",
	 0, dirlisting_not_set);
}

string quote_plain_text(string s)
{
  return(replace(s, ({"<",">","&"}),({"&lt;","&gt;","&amp;"})));
}

string tag_rel(string tag_name, mapping args, string contents,
	       object request_id, mapping defines)
{
  string old_base;
  string res;

  if (request_id->misc->rel_base) {
    old_base = request_id->misc->rel_base;
  } else {
    old_base = "";
  }
  request_id->misc->rel_base = old_base + args->base;
  
  res = parse_rxml(contents, request_id);

  request_id->misc->rel_base = old_base;
  return(res);
}

string tag_arel(string tag_name, mapping args, string contents,
		object request_id, mapping defines)
{
  if (request_id->misc->rel_base) {
    args->href = request_id->misc->rel_base+args->href;
  }

  return(make_tag("a", args)+contents+"</a>");
}

string tag_insert_quoted(string tag_name, mapping args, object request_id,
			 mapping defines)
{
  if (args->file) {
    string s = request_id->conf->try_get_file(args->file, request_id);

    if (s) {
      return(quote_plain_text(s));
    }
    return("<!-- Couldn't open file \""+args->file+"\" -->");
  }
  return("<!-- File not specified -->");
}

mapping query_container_callers()
{
  return( ([ "rel":tag_rel, "arel":tag_arel ]) );
}

mapping query_tag_callers()
{
  return( ([ "insert-quoted":tag_insert_quoted ]) );
}

string find_readme(string d, object id)
{
  foreach(({ "README.html", "README"}), string f) {
    string readme = id->conf->try_get_file(d+f, id);

    if (readme) {
      if (f[strlen(f)-5..] != ".html") {
	readme = "<pre>" + quote_plain_text(readme) +"</pre>";
      }
      return("<hr noshade>"+readme);
    }
  }
  return("");
}

string describe_directory(string d, object id)
{
  array(string) path = d/"/" - ({ "" });
  array(string) dir;
  int override = (path[-1] == ".");
  string result = "";
  int toplevel;

  // werror(sprintf("describe_directory(%s)\n", d));
  
  path -= ({ "." });
  d = "/"+path*"/" + "/";

  dir = id->conf->find_dir(d, id);

  if (dir && sizeof(dir)) {
    dir = sort(dir);
  } else {
    dir = ({});
  }

  if (id->prestate->spartan_directories) {
    return(sprintf("<html><head><title>Directory listing of %s</title></head>\n"
		   "<body><h1>Directory listing of %s</h1>\n"
		   "<pre>%s</pre></body</html>\n",
		   d, d,
		   map(sort(dir), lambda(string f, string d, object r, object id) {
		     array stats = r->stat_file(d+f, id);
		     if (stats && stats[1]<0) {
		       return("<a href=\""+f+"/.\">"+f+"/</a>");
		     } else {
		       return("<a href=\""+f+"\">"+f+"</a>");
		     } }, d, roxen, id)*"\n"+"</pre></body></html>\n"));
  }

  if ((toplevel = !id->misc->dir_no_head)) {
    id->misc->dir_no_head = 1;

    result += "<html><head><title>Directory listing of "+d+"</title></head>\n"
      "<body>\n<h1>Directory listing of "+d+"</h1>\n<p>";

    if (QUERY(readme)) {
      result += find_readme(d, id);
    }
    result += "<hr noshade><pre>\n";
  }
  result += "<fl folded>\n";

  foreach(sort(dir), string file) {
    array stats = id->conf->stat_file(d + file, id);
    string type = "Unknown";
    string icon;
    int len = stats?stats[1]:0;

    // werror(sprintf("stat_file(\"%s\")=>%O\n", d+file, stats));

    switch(-len) {
    case 3:
    case 2:
      type = "   "+({ 0,0,"Directory","Module location" })[-stats[1]];
      
      /* Directory or module */
      file += "/";
      icon = "internal-gopher-menu";
      
      break;
    default:
      array tmp = id->conf->type_from_filename(file,1);
      if (tmp) {
	type = tmp[0];
      }
      icon = image_from_type(type);
      if (tmp && tmp[1]) {
	type += " " + tmp[1];
      }
      
      break;
    }
    result += sprintf("<ft><img border=0 src=\"%s\" alt=\"\"> "
		      "<arel href=\"%s\">%-40s</arel> %8s %-20s\n",
		      icon, file, file, sizetostring(len), type);
    
    array(string) split_type = type/"/";
    string extras = "Not supported for this file type";
    
    switch(split_type[0]) {
    case "text":
      if (sizeof(split_type) > 1) {
	switch(split_type[1]) {
	case "html":
	  extras = "</pre>\n<insert file=\""+d+file+"\"><pre>";
	  break;
	case "plain":
	  extras = "<insert-quoted file=\""+d+file+"\">";
	  break;
	}
      }
      break;
    case "application":
      if (sizeof(split_type) > 1) {
	switch(split_type[1]) {
	case "x-include-file":
	case "x-c-code":
	  extras = "<insert-quoted file=\""+d+file+"\">";
	  break;
	}
      }
      break;
    case "image":
      extras = "<img src=\""+ replace( d, "//", "/" ) + file +"\" border=0>";
      break;
    case "   Directory":
    case "   Module location":
      extras = "<rel base=\""+file+"\">"
	"<insert nocache file=\""+d+file+".\"></rel>";
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
	extras = "<insert-quoted file=\""+d+file+"\">";
	break;
      }
      break;
    }
    result += "<fd>"+extras+"\n";
  }
  result += "</fl>\n";
  if (toplevel) {
    result +="</pre></body></html>\n";
  }

  // werror(sprintf("describe_directory()=>\"%s\"\n", result));

  return(result);
}

string|mapping parse_directory(object id)
{
  string f = id->not_query;

  // werror(sprintf("parse_directory(%s)\n", id->raw_url));

  /* First fix the URL
   *
   * It must end with "/" or "/."
   */
  if (!(((sizeof(f) > 1) && ((f[-1] == '/') ||
			     ((f[-2] == '/') && (f[-1] == '.')))) ||
	(f == "/"))) {
    string new_query = http_encode_string(f) + "/" +
      (id->query?("?" + id->query):"");
    return(http_redirect(new_query, id));
  }
  /* If the pathname ends with '.', and the 'override' variable
   * is set, a directory listing should be sent instead of the
   * indexfile.
   */
  if(!(sizeof(f)>1 && f[-2]=='/' && f[-1]=='.' &&
       QUERY(dirlisting) && QUERY(override))) {
    /* Handle indexfiles */
    string file, old_file;
    string old_not_query;
    mapping got;
    old_file = old_not_query = id->not_query;
    if(old_file[-1]=='.') old_file = old_file[..strlen(old_file)-2];
    foreach(query("indexfiles")-({""}), file) { // Make recursion impossible
      id->not_query = old_file+file;
      if(got = id->conf->get_file(id))
	return got;
    }
    id->not_query = old_not_query;
  }
  if (!QUERY(dirlisting)) {
    return 0;
  }
  if (f[-1] != '.') {
#if 0
    return(http_redirect(f+".",id));
#endif /* 0 */
    f += ".";
  }
  return http_string_answer(parse_rxml(describe_directory(f, id), id));
}
