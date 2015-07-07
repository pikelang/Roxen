// This is a Roxen module. Copyright © 1996 - 2000, Roxen IS.
//
// Directory listings mark 2
//
// Henrik Grubbström 1997-02-13
// Martin Nilsson 1999-12-27
//
// TODO:
// Filter out body statements and replace them with tables to simulate
// the correct background and font colors.
//
// Make sure links work _inside_ unfolded documents.

constant cvs_version = "$Id$";
constant thread_safe = 1;

#ifdef DIRECTORIES_DEBUG
# define DIRS_WERR(X) werror("Directories: "+X+"\n");
#else
# define DIRS_WERR(X)
#endif

inherit "module";

array readme, indexfiles;
int filename_width, cache, config_id;

string output_format(array(string) filenames)
{
  int w = filename_width, i;
  if(!w)
    foreach(map(filenames, sizeof), i)
      if(i>w)
	w = i;

  return sprintf("<img border=\"0\" src=\"%%s\" alt=\"\" /> "
		 "<a href=\"%%s\">%%%s-%ds</a>%s%s   %%s\n",
		 (query("truncate")?":":""), w,
		 (query("size") ? "   %11s" : "%.0s" ),
		 (query("date")!="Don't show dates" ? "   %s" : "%.0s"));
}

void start(int n, Configuration c)
{
  readme = query("Readme")-({""});
  indexfiles = query("indexfiles")-({""});
  filename_width = query("fieldwidth");
  cache = query("cache");
  config_id = c->get_config_id();
}

constant module_type = MODULE_DIRECTORIES | MODULE_PARSER;
constant module_name = "Directory Listings";
constant module_doc = "This module pretty prints a list of files.";

void create()
{
  defvar("indexfiles",
         ({ "index.html", "index.xml", "index.htm", "index.pike",
            "index.cgi" }),
	 "Index files", TYPE_STRING_LIST|VAR_INITIAL,
	 "If one of these files is present in a directory, it will "
	 "be returned instead of the directory listing.");

  defvar("Readme", ({ "README.html", "README" }),
	 "Include readme files", TYPE_STRING_LIST|VAR_INITIAL,
	 "Include one of these readme files, if present, in directory listings");

  defvar("override", 0, "Allow directory index file overrides", TYPE_FLAG|VAR_INITIAL,
	 "If this variable is set, you can get a listing of all files "
	 "in a directory by appending '.' to the directory name. It is "
	 "<em>very</em> useful for debugging, but some people regard "
	 "it as a security hole.");

  defvar("spartan", 0, "Spartan listings", TYPE_FLAG|VAR_INITIAL,
	 "Show minimalistic file listings by default.");

  defvar("size", 1, "Include file size", TYPE_FLAG,
	 "If set, include the size of the file in the listing.");

  defvar("date", "Don't show dates", "Dates", TYPE_MULTIPLE_STRING,
	 "Select whether to include the last modification date in directory "
	 "listings, and if so, on what format. `ISO date' gives dates "
         "like 1999-11-26, while `CTIME date' gives dates like `Fri Nov "
         "26, 1999'. The `datetime' alternatives work similarly, but "
         "also add time of day information.",
         ({ "Don't show dates", "Show ISO date", "Show ISO datetime",
            "Show CTIME date", "Show CTIME datetime" }));

  defvar("fieldwidth", 40, "Filename field width", TYPE_INT,
	 "This sets the filename field width (in characters). The value 0 will "
	 "make the field width match the longest filename in the directory.");

  defvar("truncate", 0, "Filename truncation", TYPE_FLAG,
	 "If filenames are longer than the filename field width, enabling this "
	 "option truncates the name rather than making extra room on the "
	 "particular row.", 0,
	 lambda() { return !query("fieldwidth"); });

  defvar("cache", 0, "Cache result", TYPE_FLAG,
	 "If selected, the result pages will be cached in the memory cache. "
	 "Directory changes will not be visible until the cached entry "
         "has expired.");
}

class TagDirectoryInsert {
  inherit RXML.Tag;
  constant name="directory-insert";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      if(!args->file) RXML.parse_error("File not specified.");
      if(args->dir) {
	string old_base=id->misc->rel_base||"";
	id->misc->rel_base=old_base+args->file;
	array dir=id->conf->find_dir(args->file, id, 1)||({});
	result="";
	if(!sizeof(dir)) return 0;
	if(dir[0])
	  result=describe_directory(args->file, dir, id);
	else {
	  string lock;
	  foreach(dir[1..], string file) {
	    string lock=id->conf->try_get_file(args->file+file, id);
	    if(lock && sizeof(lock)) {
	      result=lock;
	      break;
	    }
	  }
	}
	id->misc->rel_base=old_base;
	return 0;
      }
      Stdio.File f;
      DIRS_WERR("Showing "+Roxen.fix_relative(args->file, id));
      if(f=open(id->conf->real_file(Roxen.fix_relative(args->file, id), id), "r")) {
	string s=f->read();
	if(s) {
	  if(args->quote=="none")
	    result=s;
	  else
	    result=Roxen.html_encode_string(s);
	  return 0;
	}
      }

      RXML.run_error("Couldn't open file \""+args->file+"\".");
    }
  }
}

string find_readme(string d, RequestID id)
{
  foreach(readme, string f) {
    string txt = id->conf->try_get_file(d+f, id);

    if (txt) {
      if (id->conf->type_from_filename(f)!="text/html")
	txt = "<pre>" + Roxen.html_encode_string(txt) +"</pre>";
      return "<hr noshade=\"noshade\" />"+txt;
    }
  }
  return "";
}

string spartan_directory(string d, array(string) dir, RequestID id)
{
  d="/"+((d/"/")-({".",""}))*"/"+"/";
  if(d="//") d="/";

  return sprintf("<html><head><title>Directory listing of %s</title></head>\n"
		 "<body><h1>Directory listing of %s</h1>\n"
		 "<pre>%s</pre></body></html>\n",
		 d, d,
		 Array.map(sort(dir),
			   lambda(string f, string d)
			   {
			     array stats = id->conf->stat_file(d+f, id);
			     if(stats && stats[1]<0)
			       return "<a href=\""+f+"/.\">"+f+"/</a>";
			     else
			       return "<a href=\""+f+"\">"+f+"</a>";
			   }, d)*"\n");
}

string describe_directory(string d, array(string) dir, RequestID id)
{
  d="/"+((d/"/")-({".",""}))*"/"+"/";
  if(d=="//") d="/";
  if (sizeof(dir)) dir = sort(dir);

  string result="";
  int toplevel=!id->misc->dir_no_head++;
  if(toplevel)
  {
    result = "<html><head><title>Directory listing of "+d+"</title></head>\n"
	     "<body><h1>Directory listing of "+d+"</h1>\n<p>";

    if(sizeof(readme))
      result += find_readme(d, id);
    result += "<hr noshade=\"noshade\" /><pre>\n";
  }

  if(id->misc->foldlist_exists) result += "<foldlist folded>\n";

  string out_form = output_format(dir);
  foreach(sort(dir), string file) {
    string tmp=id->not_query;
    array stats = id->conf->stat_file(d + file, id);
    id->not_query=tmp;

    string type = "Unknown";
    string icon;
    int len = 0;
    string mtime = "";

    if(stats) {
      len=stats[1];
      switch(query("date")) {
      case "Show CTIME date":
        mtime=ctime(stats[3]);
        mtime=mtime[0..9] + ", " +
              mtime[sizeof(mtime)-5..sizeof(mtime)-2];
	break;
      case "Show CTIME datetime":
        mtime=ctime(stats[3]);
        mtime=mtime[0..sizeof(mtime)-2];
	break;
      case "Show ISO date":
	mapping t=localtime(stats[3]);
	mtime=sprintf("%4d-%02d-%02d", t->year+1900, t->mon+1, t->mday);
	break;
      case "Show ISO datetime":
	mapping t=localtime(stats[3]);
	mtime=sprintf("%4d-%02d-%02d %02d:%02d", t->year+1900, t->mon+1,
		      t->mday, t->hour, t->min);
      }
    }
    else mtime = "(no-stats)";

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
      icon = Roxen.image_from_type(type);
      if (tmp && tmp[1]) type += " " + tmp[1];

      break;
    }

    if(id->misc->foldlist_exists) result+="<ft>";
    result += sprintf(out_form, icon, id->misc->rel_base+file, file,
		      Roxen.sizetostring(len), mtime, type);

    array(string) split_type = type/"/"+({"",""});
    string extras = "No support for this file type.";

    switch(split_type[0]) {
    case "text":
      switch(split_type[1]) {
      case "html":
	extras = "</pre>\n<directory-insert quote=\"none\" file=\""+d+file+"\"><pre>";
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
      extras = "<img src=\""+ replace( d, "//", "/" ) + file +"\" border=\"0\" />";
      break;
    case "Directory":
    case "Module location":
      extras = "<directory-insert nocache=\"\" file=\""+d+file+"\" dir>";
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
  DIRS_WERR("Request for \""+f+"\"");

  // First fix the URL
  //
  // It must end with "/" or "/."

  if(strlen(f) > 1)
  {
    if(f[-1]!='/' && f[-1]!='.') return Roxen.http_redirect(f+"/", id);
    if(f[-1]=='/' && has_value(f, "//"))
      return Roxen.http_redirect("/"+(f/"/"-({""}))*"/"+"/", id);
    if(f[-1]=='.') {
      if(!query("override")) return Roxen.http_redirect(f[..sizeof(f)-2], id);
      id->not_query="/.";
    }
  }
  else if(f != "/" )
    return Roxen.http_redirect(id->not_query+"/", id);
  DIRS_WERR("Request \""+f+"\" was not redirected");

  // If the pathname ends with '.', and the 'override' variable
  // is set, a directory listing should be sent instead of the
  // indexfile.

  if(f[-1] == '/') /* Handle indexfiles */
  {
    foreach(indexfiles, string file)
    {
      array s;
      if((s = id->conf->stat_file(f+file, id)) && (s[ST_SIZE]>0))
      {
	id->not_query = f + file;
	mapping got = id->conf->get_file(id);
	if (got) {
	  DIRS_WERR("A suitable index file found.");
	  return got;
	}
      }
    }
    // Restore the old query.
    id->not_query = f;
  }

  DIRS_WERR("Looking for lock file in "+f);
  array dir=id->conf->find_dir(f, id, 1)||({});
  if(!sizeof(dir) || !dir[0])
    foreach(dir[1..], string file) {
      string lock=id->conf->try_get_file(f+file, id);
      if(lock) {
	if(!sizeof(lock)) {
	  lock =
	    "<html><head><title>Forbidden</title></head>\n"
	    "<body><h1>Forbidden</h1></body></html>\n";
	}
	return Roxen.http_string_answer(lock)+(["error":403]);
      }
    }

  string dirlist;

  DIRS_WERR("Deciding between fancy or slimmed down direcory view");
  if(query("spartan") || id->prestate->spartan_directory) {
    if(!(dirlist=cache_lookup("dir-s"+config_id,f))) {
      dirlist=spartan_directory(f, dir, id);
      if(cache) cache_set("dir-s"+config_id,f,dirlist);
    }
    return Roxen.http_string_answer(dirlist);
  }

  if(!(dirlist=cache_lookup("dir-f"+config_id,f))) {
    id->misc->foldlist_exists=search(indices(id->conf->modules),"foldlist")!=-1;
    id->misc->rel_base="";
    dirlist=Roxen.parse_rxml(describe_directory(f, dir, id),id);
    if(cache) cache_set("dir-f"+config_id,f,dirlist);
  }
  return Roxen.http_string_answer(dirlist);
}
