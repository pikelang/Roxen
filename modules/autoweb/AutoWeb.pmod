class AutoFile {

  object id;
  
  string real_path(string filename)
  {
    filename = replace(filename, "../", "");
    return id->misc->wa->query("searchpath")+id->misc->customer_id+
      (sizeof(filename)?(filename[0]=='/'?filename:"/"+filename):"/");
  }
  
  string read(string f)
  {
    return Stdio.read_bytes(real_path(f));
  }
  
  int save(string f, string s)
  {
    werror("Saving file '%s' in %s\n", f, real_path(f));
    object file = Stdio.File(real_path(f), "cwt");
    if(!objectp(file)) {
      werror("Can not save file %s", f);
      return 0;
    }
    file->write(s);
    file->close;
    return 1;
  }

  int|array stat(string f)
  {
    file_stat(real_path(f));
  }

  string mv(string src, string dest)
  {
    mv(real_path(src), real_path(dest));
  }

  void create(object _id)
  {
    id = _id;
  }
}


class MetaData {

  object id;

  string container_md(string tag, mapping args, string contents, mapping md)
  {
    if(args->variable)
      md[args->variable] = contents;
  }
  
  mapping get(string f)
  {
    mapping md_default =  ([ "content_type":"autosite/unknown",
			     "title":"Unknown",
			     "template":"default.tmpl",
			     "keywords":"",
			     "description":""]);
    
    string s = "";
    string s = AutoFile(id)->read(f+".md");
    if(!s)
      return md_default;
    mapping md = ([]);
    parse_html(s, ([ ]), ([ "md":container_md ]), md);
    return ([ "content_type": md_default->content_type ]) + md;
  }
  
  int set(string f, mapping md)
  {
    string s = "";
    foreach(sort(indices(md)), string variable)
      s += "<md variable=\""+variable+"\">"+md[variable]+"</md>\n";
    if(!AutoFile(id)->save(f+".md", s))
      return 0;
    return 1;
  }
  
  void create(object _id)
  {
    id = _id;
  }
}

#if 0
class menufile {
  static private string parse_item(string tag, mapping args,
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
  
  string encode(object id, array items)
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
    mapping items = ([ "items":({ }) ]);
    parse_html(s, ([]), (["mi":parse_item]),
	       items);
    return items->items;
  }
}
#endif
