inherit "roxenlib";
inherit "wizard";

object wa;

array wanted_buttons = ({ });

array get_buttons(object id)
{
  return wanted_buttons;
}

void create (object webadm)
{
  wa = webadm;
}

mapping dl(object id, string filename)
{
  object f = Stdio.File(wa->real_path(id, filename), "r");
  if(f)
    return ([ "type" : "application/octet-stream",
	      "data" : f->read() ]);
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

  // werror("File: %O\n", f);
  // werror("Real file: %O\n", wa->real_path(id, f));
  
  string res="";

  if(!file_stat(wa->real_path(id, f)))
    return "Location "+wa->html_safe_encode(f)+
      " not found or permission denied.\n";
  
  if(f[-1]!='/') // it's a file
  {
    array br = ({ });
    int t;
    
    mapping md = wa->get_md(id, f);
    br += ({ ({ "View",  "'"+http_encode_string(f)+"'"
		  " target='_autosite_show_real'" }) });
    //werror("%O\n", md);
    if(md->content_type=="text/html")
      br += ({ ({ "Edit File", (["filename":f ]) }) });
    br += ({ ({ "Edit Metadata", ([ "path":f ]) }),
	     ({ "Download File", encode_url(base_url, "dl", f) }),
	     ({ "Move File", ([ "path":f ]) }),
	     ({ "Remove File", ([ "path":f ]) })
    });
    wanted_buttons=br;

    // Show info about the file;
    res += "<img src='"+
	   wa->content_types[md->content_type||"autosite/unknown"]->img+
	   "'>&nbsp;&nbsp;";
    res += "<b>"+wa->html_safe_encode(f)+"</b><br>\n";

    mapping md = wa->get_md(id, f);
    array md_order = ({ "title", "content_type", "template",
			"keywords", "description" });
    mapping md_variables = ([ "title":"Title", "content_type":"Type",
			      "template":"Template", "keywords":"Keywords",
			      "description":"Description" ]);
    array rows = ({ });
    foreach(md_order, string variable) {
      if(md_variables[variable]&&md[variable])
	rows += ({ ({ "<b>"+md_variables[variable]+"</b>",
		      (variable=="content_type"?
		       wa->content_types[md[variable]]->name:
		       wa->html_safe_encode(md[variable])
		       // md[variable]
			) }) });
    }
    res += html_table( ({ "Metadata", "Value" }), rows);
  }
  else  // it's a directory
  {
    res += "<b>"+f+"</b><br>";
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
    foreach(get_dir(wa->real_path(id, f)), string file) {
      array f_stat = file_stat(wa->real_path(id, f+file));
      if((sscanf(file, "%*s.md") == 0)&&(file!="templates")) {
	if(f_stat&&(sizeof(f_stat)>0)&&f_stat[1]==-2)
	  dirs += ({ file });
	else 
	  files += ({ file });
      }
    }
    res += "<browser>";
    // Display directories.
    foreach(sort(dirs), string item) {
      string href = "<a href='"+encode_url(base_url, "go", f+item+"/")+"'>";
      res += href+"<img src='/internal-gopher-menu' border=0></a>";
      res += "&nbsp;&nbsp;"+href+"<tt>"+
	     wa->html_safe_encode(item+"/")+"</tt></a><br>\n";
    }
    
    // Display files.
    foreach(sort(files), string item) {
      mapping md = wa->get_md(id, f+item);
      string img = "internal-gopher-unknown";
      if(md)
	img = wa->content_types[md->content_type||
			       "autosite/unknown"]->img;
      string href = "<a href='"+encode_url(base_url, "go", f+item)+"'>";
      res += href+"<img src='/"+img+"' border=0></a>";
      res += "&nbsp;&nbsp;"+href+"<tt>";
      res += replace(sprintf("%-22s", wa->html_safe_encode(item)),
		     " ", "&nbsp;");
      if(md->title)
	res += wa->html_safe_encode(md->title);
      res += "</tt></a><br>\n";
      
    }
    if(!sizeof(dirs+files))
      res += "Empty!";
      
    res += "</browser>";
  }
  if(sizeof(f)>1)
    res = "<a href='"+encode_url(base_url, "go", combine_path(f, "../"))+"'>"
      "Up to parent directory</a><br>\n<br>\n"+res;
  
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
