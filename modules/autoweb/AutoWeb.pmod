#include <stat.h>

class AutoFile {

  object id;
  string filename;
  
  string real_path(string path)
  {
    path = replace(path, "../", "");
    return id->misc->wa->query("searchpath")+id->misc->customer_id+
      (sizeof(path)?(path[0]=='/'?path:"/"+path):"/");
  }
  
  string read()
  {
    return Stdio.read_bytes(real_path(filename));
  }
  
  int save(string s)
  {
    werror("Saving file '%s' in %s\n", filename, real_path(filename));
    object file = Stdio.File(real_path(filename), "cwt");
    if(!objectp(file)) {
      werror("Can not save file %s", filename);
      return 0;
    }
    file->write(s);
    file->close;
    return 1;
  }

  int|array stat()
  {
    return file_stat(real_path(filename));
  }

  string type()
  {
    array f_stat = stat();
    if(!f_stat)
      return "";
    if(f_stat[1]==-2)
      return "Directory";
    if(f_stat[1]==-3)
      return "Link";
    if(f_stat[1]>=0)
      return "File";
    return "";
  }

  array get_dir()
  {
    return predef::get_dir(real_path(filename));
  }
  
  int visiblep()
  {
    array filters = ({ "CVS", "templates", "*.md", "*.menu", "*~" });
    foreach(filters, string filter)
      if(glob(filter, filename))
	return 0;
    return 1;
  }
  
  int move(string dest)
  {
    return mv(real_path(filename), real_path(dest));
  }

  int mkdir()
  {
    return predef::mkdir(real_path(filename));
  }

  int rm()
  {
    return predef::rm(real_path(filename));
  }
  
  void create(object _id, string _filename)
  {
    id = _id;
    filename = _filename;
  }
}


class ContentTypes {
  static private string default_content_type;
  static private mapping content_types;
  static private mapping name_to_type;

  mapping content_type(string ct) 
  {
    return content_types[ct];
  }
  
  string type_from_name(string name)
  {
    return name_to_type[name];
  }

  string img_from_type(string type)
  {
    mapping ct =  content_types[type||"autosite/unknown"];
    if(ct)
      return ct->img;
    return content_types["autosite/unknown"]->img;
  }
  
  string name_from_type(string type)
  {
    string ct = content_types[type];
    if(ct)
      return content_types[type]->name;
    return content_types[default_content_type]->name;
  }
  
  array names()
  {
    return indices(name_to_type);
  }
  
  string content_type_from_extension( string filename )
  {
    string extension = (filename / ".")[-1];
    
    foreach (indices( content_types ), string i)
      if (content_types[i]->extensions[ extension ])
	return i;
    if (sizeof( filename / "." ) >= 2)
      {
	extension = (filename / ".")[-2];
	
	foreach (indices( content_types ), string i)
	  if (content_types[i]->extensions[ extension ])
	    return i;
      }
    return "application/octet-stream";
  }

  string tag(string type, string f)
  {
    switch(type) {
    case "autosite/unknown":
    case "text/html":
    case "text/plain": return "<a href="+f+">Link text</a>";
    case "image/jpeg":
    case "image/gif": return "<img src="+f+" width=? height=?>";
    }
  }
  
  void create()
  {
    default_content_type = "autosite/unknown";
    string image_base = "";
    string image_ext = ".gif";
    content_types =
    ([ "text/html" :
       ([ "name" : "HTML",
	  "handler" : "html",
	  "downloadp" : 1,
	  "parsep" : 1,
	  "extensions" : (< "html", "htm" >),
	  "img" : image_base+"text"+image_ext ]),
       
       "text/plain" :
       ([ "name" : "Raw text",
	  "handler" : "text",
	  "downloadp" : 1,
	  "extensions" : (< "txt" >),
	  "img" : image_base+"text"+image_ext ]),
       
       "image/gif" :
       ([ "name" : "GIF Image",
	  "handler" : "image",
	  "downloadp" : 1,
	  "extensions" : (< "gif" >),
	  "img" : image_base+"image"+image_ext ]),
       
       "image/jpeg" :
       ([ "name" : "JPEG Image",
	  "handler" : "image",
	  "downloadp" : 1,
	  "extensions" : (< "jpg", "jpeg" >),
	  "img" : image_base+"image"+image_ext ]),
       
       "autosite/unknown" :
       ([ "name" : "Unknown",
	  "handler" : "default",
	  "downloadp" : 1,
	  "extensions" : (< >),
	  "img" : image_base+"unknown"+image_ext ]),
       
       "autosite/menu" :
       ([ "name" : "Menu",
	  "handler" : "menu",
	  "downloadp" : 0,
	  "extensions" : (< "menu" >),
	  "internalp" : 1,
	  "img" : image_base+"unknown"+image_ext ]),
       
       "autosite/template" :
       ([ "name" : "Template",
	  "handler" : "template",
	  "downloadp" : 1,
	  "extensions" : (< "tmpl" >),
	  "internalp" : 1,
	  "img" : image_base+"unknown"+image_ext ])
       
    ]);
    name_to_type = ([ ]);
    foreach (indices( content_types ), string ct)
      name_to_type[ content_types[ ct ]->name ] = ct;
  }
}

class Icons {
  inherit "roxenlib";
  string virtual_base;
  string fysical_base;
  array icons;
  mapping icons_dim;
  
  string tag(string icon)
  {
    return make_tag("img",
		    ([ "border":"0", "src":combine_path(virtual_base, icon) ])+
		    icons_dim[icon] );
  }
  
  void create(string _fysical_base, string _virtual_base)
  {
    virtual_base = _virtual_base; 
    fysical_base = _fysical_base; 
    icons = ({ "image.gif", "sound.gif", "unknown.gif",
	       "binary.gif", "text.gif", "binary.gif",
	       "menu.gif", "menu-open.gif", "menu-back.gif" });
    icons_dim = ([ ]);
    foreach(icons, string icon)
    {
      array dim = Dims.dims()->get(combine_path(fysical_base, icon));
      if(dim&&sizeof(dim)) {
	icons_dim[icon] = ([ "width":(string)dim[0],
			     "height":(string)dim[1] ]);
      }
    }
  }
}


class MetaData {
  inherit "roxenlib";

  object id;
  string f;

  static private string container_md(string tag, mapping args,
				     string contents, mapping md)
  {
    if(args->variable)
      md[args->variable] = contents;
  }
  
  mapping get()
  {
    mapping md_default =  ([ "content_type":"autosite/unknown",
			     "title":"Unknown",
			     "template":"default.tmpl",
			     "keywords":"",
			     "description":""]);
    
    string s = "";
    array fs=AutoFile(id, f+".md")->stat();
    array a;
    if(fs && (a=cache_lookup("autoweb_md_stat",""+id->misc->customer_id+f))
       && a[1]==fs[ST_MTIME])
      return a[0];
    else if(!fs)
      return md_default;
    mapping md = ([]);
    
    string s = AutoFile(id, f+".md")->read();
    if(!s)
      return md_default;
    parse_html(s, ([ ]), ([ "md":container_md ]), md);
    return cache_set("autoweb_md_stat",""+id->misc->custiner_id+f,
		     ({ ([ "content_type": md_default->content_type ]) + md,
			fs }))[0];
  }
  
  int set(mapping md)
  {
    string s = "";
    foreach(sort(indices(md)), string variable)
      s += "<md variable=\""+variable+"\">"+md[variable]+"</md>\n";
    if(!AutoFile(id, f+".md")->save(s))
      return 0;
    return 1;
  }
  
  static private string container_title(string tag, mapping args,
					string contents, mapping md)
  {
    if(tag="title")
      md["title"] = contents;
  }
  
  mapping get_from_html(string html)
  {
    mapping md = ([]);
    md->content_type = ContentTypes()->content_type_from_extension(f);
    if((md->content_type == "text/html")&&(sizeof(html))) 
      parse_html(html, ([ ]), ([ "title":container_title ]), md);
    return md;
  }

  string display()
  {
    mapping md = ([ "template":"No template" ])+get();
    array md_order = ({ "title", "content_type", "template",
			"keywords", "description" });
    mapping md_variables = ([ "title":"Title", "content_type":"Type",
			      "template":"Template", "keywords":"Keywords",
			      "description":"Description" ]);
    array rows = ({ "Metadata|||Value" });
    foreach(md_order, string variable) {
      if(md_variables[variable]&&md[variable])
	rows += ({ "<b>"+md_variables[variable]+"</b>"+"|||"+
		   (variable=="content_type"?
		    ContentTypes()->name_from_type(md[variable]):
		    html_encode_string(md[variable])) });
    }
    if(md->content_type=="image/gif"||md->content_type=="image/jpeg") {
      array dims=Dims.dims()->get(AutoFile(id, f)->real_path(f));
      if(dims) {
	rows += ({ "<b>Dimension</b>|||"+dims[0]+"*"+dims[1]+" pixels" });
	rows += ({ "<b>HTML Tag</b>|||"+
		   html_encode_string("<img src=\""+f+
				      "\" width="+dims[0]+
				      " height="+dims[1]+
				      " alt=\"\">") });
      }
    }
    return "<webadmtablify>"+(rows*"///")+"</webadmtablify>";
  }
  
  void create(object _id, string _f)
  {
    id = _id;
    f = _f;
  }
}

class EditMetaData {
  
  inherit "wizard";
  object contenttypes;
  
  static private array describe_metadata_var(array in)
  {
    return ({ "<font size=+1><b>"+in[0]+"</b></font>", 
	      "<var name='"+in[1]+"' default='"+in[2]+"' "+
	      (in[3]==3?"choices='"+in[5]+"' ":" ")+
	      " type='"+
	      ((in[3]==0)?"string":"")+
	      (in[3]==1?"text":"")+
	      (in[3]==3?"select":"")+
	      "'>",
	      ({ "<font size=-1><i>"+in[4]+"</i></font>" }) });
  }

  string page( object id, string f, mapping|void m)
  {
    if(!m && f)
      m = MetaData(id, f)->get();
  
    array (string) templates = ({ "No template", "default.tmpl" });
  
    array rows = ({
      ({ "Type", "meta_content_type", 
	 contenttypes->name_from_type(m->content_type), 3,
	 " This is the type of the file. "
	 /* Normal for text-files is text/html,"
	    " most images are image/gif or image/jpeg."*/,
	 contenttypes->names() * ","
      }),
      ({ "Template", "meta_template", m->template||"No template", 3,
	 " This is the template used on this page. You can see all templates "
	 "available under the 'templates' tab.", templates * ","
      }),
      ({ "Title", "meta_title", m->title||"No title", 0,
	 " This is the title of the page. Make sure that it accurately "
	 "describes it"
      }),
      ({ "Keywords", "meta_keywords", m->keywords||"", 0,
	 " Document keywords. These are primarily used when search-engines "
	 "are indexing the site."
      }),
      ({ "Description<p><br><br><br>", "meta_description", 
	 m->description||"\n", 1,
	 " Document description. this is also primarily used when "
	 "search-engines are indexing the site."
      }),
    });
  
    return "<b>Metadata for file "+html_encode_string(f)+":</b><p>\n" + 
      html_table(({ "Data", "Value", ({ "Description" }) }),
		 Array.map(rows, describe_metadata_var));
  }
  
  mixed done( object id, string f)
  {
    mapping md = ([ ]);
    //werror("EditMetaData()->done() f: %O\n", f);
    foreach (glob( "meta_*", indices( id->variables )), string s)
      md[ s-"meta_" ] = id->variables[ s ];
    md[ "content_type" ] = ContentTypes()->type_from_name(md[ "content_type" ]);
    if (md[ "template" ] == "No template")
      m_delete( md, "template" );
    
    MetaData(id, f)->set(md);
  }
  
  void create()
  {
    contenttypes = ContentTypes();
  }
}


class Error {

  object id;
  
  string set(string error)
  {
    return id->variables->error = error;
  }

  string reset()
  {
    m_delete(id->variables, "error");
  }

  string get()
  {
    return (id->variables->error?"<error>"+
	    id->variables->error+"</error>":"");
  }
  
  void create(object _id)
  {
    id = _id;
  }
}

class MenuFile {
  inherit "roxenlib";

  string parse_item(string tag, mapping args,
				   string contents, mapping items)
  {
    function parseit=lambda(string tag, mapping args,
			    string contents, mapping meta)
		     {
		       meta[tag]=replace( contents, ({ "&amp;", "&lt;", "&gt" }),
					  ({ "&", "<", ">" }) );
		       meta[tag]=html_decode_string(contents);
		     };
    
    mapping res=([]);
    parse_html(contents, ([]),
	       ([
		 "url":parseit,
		 "title":parseit,
	       ]),
	       res);
    items->items=items->items+({res});
    return 0;
  }
  
  string encode(array items)
  {
    string res="";
    foreach(items, mapping item)
    {
      res+="<mi>\n";
      foreach(sort(indices(item)), string itemstr)
	if(itemstr[0..0]!="_")
	  res+=sprintf("  <%s>%s</%s>\n",itemstr,
		       html_encode_string((string)item[itemstr]), itemstr);
      res+="</mi>\n";
    }
    return res;
  }

  array decode(string s)
  {
    if(!s) return ({});
    mapping items = ([ "items":({ }) ]);
    parse_html(s, ([]), (["mi":parse_item]),
	       items);
    return items->items;
  }
}
