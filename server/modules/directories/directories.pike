// This is a roxen module. (c) Informationsvävarna AB 1996.

// A quite complex directory module. Generates macintosh like listings.
string cvs_version = "$Id: directories.pike,v 1.8 1997/02/13 13:01:07 per Exp $";
#include <module.h>
inherit "module";
inherit "roxenlib";

/************** Generic module stuff ***************/
int idi;



program dirnode_program = class {

  int finished, idi=time();
  array stat;
  inherit "base_server/struct/node";

#define configurl(f) ("/internal-roxen-"+f)
#define image(f) ("<img border=0 src="+(f)+" alt=\"\">")

  inline string configimage(string f) 
  { 
    return image(configurl(f)); 
  }

  inline string linkname(string a,string b) 
  { 
    return ("<a name="+(b)+">"+(a)+"</a>"); 
  }

  inline string link(string a,string b) 
  { 
    return ("<a href="+(b)+">"+(a)); 
  }

  inline string blink(string a,string b) 
  { 
    return ("<a href="+(b+"?"+(idi++))+">"+(a)); 
  }

  string show_me(string s, string root)
  {
    string name = path(1), lname;
    lname = name/*[strlen(root)..]*/;
    if(!stat) return "";
    if(stat[1]>-1) return "   "+link(s, name);
    if(stat[1]<0) lname+="/";
    if(folded)
      return linkname(link(configimage("unfold"), "/(diract,unfold)" +
			   name+"?"+(idi++)) + blink(s, lname), name);
    else
      return linkname(link(configimage("fold"), "/(diract,fold)"+name+"?"
			    +(idi++))
		      + blink(s, name), name);
  }

  mixed dcallout;
  string describe(int i, string|void foo)
  {
    string res="";
    object node,prevnode;
    mixed tmp;
    string root;

    if(dcallout) remove_call_out(dcallout);
    dcallout = call_out(dest, 60);

    if(i)
      root = path(1);
    else
      root = foo;

    if(describer)
      tmp = describer(this_object());
#ifdef NODE_DEBUG
    else
      perror("No describer in node "+path(1)+"\n");
#endif
    if(!tmp) return "";

    if(!i)
      res += tmp[0] +  show_me(tmp[1], root);
    else if(up) 
      res += link("Previous Directory", up->path(1));

    if(!folded)
    {
      res += "<dd>";
      if(!i)
	res += "<dl>";
      node = down;
      while(node)
      {
	if(!objectp(node))	// ERROR!
	{
	  if(objectp(prevnode))
	    prevnode->next=0;
	  node=0;
	  break;
	}
	prevnode = node;
	node = node->next;
	res += prevnode->describe(0,root);
      }
      if(!i)
	res += "</dl>";
    }
    return res;
  }
};

array register_module()
{
  return ({ MODULE_DIRECTORIES, 
	    "Directory parsing module",
	    "This is the default directory parsing module. "
	      "This one pretty prints a list of files, with "
	      "macintosh like fold and unfold buttons next to each "
	      "directory.", 
	    ({ }), 
	    1
	    });
}

void create()
{
  defvar("indexfiles", ({ "index.html", "Main.html", "welcome.html",
			  "index.cgi", "index.lpc","index.pike" }),
	 "Index files", TYPE_STRING_LIST,
	 "If one of these files is present in a directory, it will "
	 "be returned instead of the directory listing.");

  defvar("readme", 1, "Include readme files", TYPE_FLAG,
	 "If set, include readme files in directory listings");
  
#if 0
  defvar("date", 1, "Include date", TYPE_FLAG,
	 "If set, include the last modification date in directory "
	 "listings.");
  
  defvar("user", 0, "Include file user", TYPE_FLAG,
	 "If set, include the last user who modified the file in "
	 "directory listings. This requires a user database module.");
#endif

  defvar("override", 0, "Allow directory index file overrides", TYPE_FLAG,
	 "If this variable is set, you can get a listing of all files "
	 "in a directory by prepending '.' or '/' to the directory name, like this: "
	 "<a href=http://roxen.com//>http://roxen.com//</a>"
	 ". It is _very_ useful for debugging, but some people regard it as a "
	 "security hole.");
  
  defvar("size", 1, "Include file size", TYPE_FLAG,
	 "If set, include the size of the file in the listing.");
}



function global_describer, head, foot;

void start()
{
  global_describer = this_object()["describe_dir_node_" "mac"];
  head = this_object()["head_dir_"  "mac"];
  foot = this_object()["foot_dir_"  "mac"];
}

/*  Module specific stuff */

object _root;
object root(object id)
{
  return _root||(_root=dirnode_program());
}


string find_readme(object node, object id)
{
  string rm, f;
  object n;
  foreach(({ "README.html", "README"}), f)
    if(n=node->descend(f,1))
    {
      rm=roxen->try_get_file(n->path(), id);
      if(rm) if(f[-1] == 'l')
	return "<hr noshade>"+rm;
      else
	return "<pre><hr noshade>"+
	  replace(rm, ({"<",">","&"}), ({"&lt;","&gt;","&amp;"}))+"</pre>";
    }
  return "";
}

string head_dir_mac(object node, object id)
{
  string rm="";
  
  if(QUERY(readme)) rm=find_readme(node,id);
  
  return ("<h1>Directory listing of "+node->path()+"</h1>\n<p>"+rm
	  +"<pre>\n<dl><hr noshade>");
}

string foot_dir_mac()
{
  return "</dl><hr noshade></pre>";
}

#define TYPE_MP  "    Module location"
#define TYPE_DIR "    Directory"

array|string describe_dir_node_mac(object node)
{
  string type, filename, icon;
  int len;
  
  filename = node->data;
  
  if(node->stat)
  {
    switch(-(len=node->stat[1]))
    {
     case 3:
      type = TYPE_MP;
      icon = "internal-gopher-menu";
      filename += "/";
      break;

     case 2:
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
  } else {
    return ({ "<dt>", "Unknown" });
  }  
  /* Now we have
   * o The name of the file
   * o The icon to use
   * o The type of the file
   */
  
  return ({ "<dt>" , sprintf("%s %-25s</a> %8s %-40s\n", image(icon),
			     filename[0..24], sizetostring(len), type)
	      });
  
}

object create_node(string f, object id)
{
  object my_node, node;
  array (string) path = f/"/" - ({ "" }), dir;
  string tmp, file;
  
  path -= ({ "." });
  f=replace(f, ({ "./", "/.",  }), ({ "", "" }));
  
  my_node = root(id);
  
  foreach(path, tmp) 
    my_node = my_node->descend(tmp);
  
  if(!strlen(f) || (f[-1] != '/')) f += "/";
  dir = roxen->find_dir(f, id);
  
  if(sizeof(path))
    my_node->data = path[-1];
  else
    my_node->data = "";
  
  my_node->stat = roxen->stat_file(f, id);
  my_node->finished=1;
  my_node->describer = global_describer;
  
  if(!dir)    return my_node;
  
  foreach(sort((array)dir), file)
  {
    node = my_node->descend(file);
    node->data = file;
    node->stat = roxen->stat_file(f + file, id);
    if(node->stat && node->stat[1] >= 0) node->finished=1;
    node->describer = global_describer;
  }
  return my_node;
}

object find_finished_node(string f, object id)
{
  object my_node;
  array (string) path;
  string tmp;

  f=replace(f, ({ "./", "/.",  }), ({ "", "" }));

  path = f/"/"-({"", "."});
  my_node = root(id);

  
  foreach(path, tmp) 
    if(!(my_node = my_node->descend(tmp, 1)))
      return 0;
  
  if(!my_node->finished)
    return 0;
  
  return my_node;
}


mapping standard_redirect(object o, object id)
{
  string loc, l2;
  
  if(!o) o=root(id);
  
  if(sizeof(id->referer))
    loc=((((((id->referer*" ")/"#")[0])/"?")[0])+"#"+o->path(1));
  else
    if(o->up)
      loc = o->up->path(1) + ".?" + (idi++) + "#" + o->path(1);
    else
      return http_redirect("/.", id);
  return http_redirect(loc,id);
}

mapping parse_directory(object id)
{
  object node;
  string f;
  mixed tmp;

  f=id->not_query;

// If this prestate is set, do some folding/unfolding.
  if(!id->prestate->diract) 
  { 
    if(strlen(f) > 1) // I check the last two characters.
    {
      if(!((f[-1] == '/') || ( (f[-1] == '.') && (f[-2] == '/') )))
	return http_redirect(id->not_query+"/", id);
    } else {
      if(f != "/" )
	return http_redirect(id->not_query+"/", id);
    }
      
    /* If the pathname ends with '.', and the 'override' variable
     * is set, a directory listing should be sent instead of the
     * indexfile.
     */
    if(!(f[-1]=='.' && QUERY(override))) /* Handle indexfiles */
    {
      string file, old_file;
      mapping got;
      old_file = id->not_query;
      if(old_file[-1]=='.') old_file = old_file[..strlen(old_file)-2];
      foreach(query("indexfiles")-({""}), file) // Make recursion impossible
      {
	id->not_query = old_file+file;
	if(got = roxen->get_file(id))
	  return got;
      }
    }
  }

  if(id->pragma["no-cache"] || !(node = find_finished_node(f,id)))
    node = create_node(f, id);
  
  if(id->prestate->fold)
  {
    node->folded = 1;
    id->prestate->diract=0; // Remove the prestates before sending the redirect.
    id->prestate->fold=0;
    return standard_redirect(node, id);
  }
  
  if(id->prestate->unfold)
  {
    node->folded=0;
    id->prestate->diract=0;  // Remove the prestates before sending the redirect.
    id->prestate->unfold=0;
    return standard_redirect(node, id);
  }

  if(id->prestate->diract) return 0; // This should not happend
  
  f=node->folded;
  if(f) node->folded=0;
  tmp=http_string_answer(head(node,id)+node->describe(1)+foot(node,id));
  node->folded = f;
  
  return tmp;
}


