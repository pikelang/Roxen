inherit "roxenlib";
inherit "wizard";
import AutoWeb;

array wanted_buttons = ({ });

array get_buttons(object id)
{
  return wanted_buttons;
}

void create (object webadm)
{
}

mapping dl(object id, string filename)
{
  if(AutoFile(id, filename)->type()=="File")
    return ([ "type" : "application/octet-stream",
	      "data" : AutoFile(id, filename)->read() ]);
  else
    return 0;
}

#if 1
string encode_url(string base, string func, string path)
{
  if(func=="dl") {
    return combine_path(base, func, MIME.encode_base64(path)+
			"/"+(path/"/")[-1]);
  }
  return combine_path(base, func, MIME.encode_base64(path));
}

mapping decode_url(string s)
{
  string func = "", path = "";
  sscanf(s, "%s/%s", func, path);
  sscanf(path, "%s/%*s", path);
  path = MIME.decode_base64(path);
  if(!sizeof(path)||path[0]!='/') path = "/" + path;
  return ([ "func":func, "path":path ]);
}
#else
string encode_url(string base, string func, string path)
{
  if(sizeof(path)) path = path[1..];
  return combine_path(base, func, http_encode_string(path));
}

mapping decode_url(string s)
{
  string func = "", path = "";
  sscanf("hej", "%s/%s", func, path);
  sscanf(s, "%s/%s", func, path);
//  path = MIME.decode_base64(path);
  if(!sizeof(path)||path[0]!='/') path = "/" + path;
  return ([ "func":func, "path":path ]);
}
#endif

string|mapping navigate(object id, string f, string base_url)
{

  object contenttypes = ContentTypes();
  string res="<comment><htmleditorp>t</htmleditorp></comment>";

  if(AutoFile(id, f)->type()=="")
    if(f!="/")
      return http_redirect(encode_url(base_url, "go",
				      combine_path(f, "../")), id);
    else
      return "Location "+html_encode_string(f)+
	" not found or permission denied.\n";
  
  if(f[-1]!='/') // it's a file
  {
    array br = ({ });
    int t;
    
    mapping md = MetaData(id, f)->get();
    br += ({ ({ "View",  "'"+http_encode_string(f)+"'"+
		  " target='_autosite_show_real'" }) });
    //werror("%O\n", md);
    if(md->content_type=="text/html")
      br += ({ ({ "Edit File", (["path":http_encode_string(f) ]) }) });
    br += ({ ({ "Edit Metadata", ([ "path":http_encode_string(f) ]) }),
	     ({ "Add To Menu", ([ "path":http_encode_string(f) ]) }),
	     ({ "Download File", "'"+encode_url(base_url, "dl", f)+"'" }),
	     ({ "Move File", ([ "path":http_encode_string(f) ]) }),
	     ({ "Remove File", ([ "path":http_encode_string(f) ]) })
    });
    wanted_buttons=br;

    // Show info about the file;
    res += id->misc->icons->tag(contenttypes->img_from_type(md->content_type))+
	   "&nbsp;&nbsp;";
    res += "<b>"+html_encode_string(f)+"</b><br>\n";
    
    res += MetaData(id, f)->display();
  }
  else  // it's a directory
  {
    res += id->misc->icons->tag("menu-open.gif")+
      "&nbsp;&nbsp;<b>"+f+"</b><br>";
    wanted_buttons =
    ({ ({ "Create File", ([ "path": f ]) }),
       ({ "Upload File", ([ "path": f ]) }),
       ({ "New Directory", ([ "path": f ]) }),
       ({ "Move Directory", ([ "path": f ]) }),
       ({ "Remove Directory", ([ "path": f ]) })
    });
    
    // Show the directory
    array files = ({ });
    array dirs = ({ });

    // Scan directory for files and directories.
    foreach(AutoFile(id, f)->get_dir(), string file)
      if(AutoFile(id, file)->visiblep())
	if(AutoFile(id, f+file)->type()=="Directory")
	  dirs += ({ file });
	else 
	  files += ({ file });
    
    res += "<table cellpadding=2>";
    // Display directories.
    foreach(sort(dirs), string item) {
      string href = "<a href='"+encode_url(base_url, "go", f+item+"/")+"'>";
      res += ("<tr><td>"+href+id->misc->icons->tag("menu.gif")+"</a></td>");
      res += "<td>"+href+"<tt>"+
	     html_encode_string(item+"/")+"</tt></a></td></tr>\n";
    }
    
    // Display files.
    foreach(sort(files), string item) {
      mapping md = MetaData(id, f+item)->get();
      string img = contenttypes->img_from_type(md->content_type);
      string href = "<a href='"+encode_url(base_url, "go", f+item)+"'>";
      res += "<tr><td>"+href+id->misc->icons->tag(img)+"</a></td>";
      res += "<td>"+href+"<tt>"+html_encode_string(item)+"</tt></a></td>";
      res += "<td>";
      if(md->title)
	res += html_encode_string(md->title);
      res += "</td></tr>\n";
      
    }
    if(!sizeof(dirs+files))
      res += "Directory is Empty!";
      
    res += "</table>";
  }
  if(sizeof(f)>1) {
    string href = "<a href='"+encode_url(base_url,
					 "go", combine_path(f, "../"))+"'>";
    res = (href+id->misc->icons->tag("menu-back.gif")+"</a>"
	   "&nbsp;&nbsp;"+href+
	   "Up to parent directory</a><br>\n<br>\n"+res);
  }
  return res;
}

string|mapping handle(string sub, object id)
{
  wanted_buttons=({ });
  string base_url = id->not_query[..sizeof(id->not_query)-sizeof(sub)-1];

  mapping m = decode_url(sub);
  switch(m->func) {
  case "":
    break;
  case "go":
    break;
  case "dl":
    return dl(id, m->path);
  default:
    return "What?";
  }
  return navigate(id, m->path, base_url);
}
