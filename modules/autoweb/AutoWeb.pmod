class md {
  mapping get(object id, string f)
  {
    mapping md_default =  ([ "content_type":"autosite/unknown",
			     "title":"Unknown",
			     "template":"default.tmpl",
			     "keywords":"",
			     "description":""]);
    
    string file_name = real_path(id, f+".md");
    string s = Stdio.read_bytes(file_name);
    if(!s) {
      werror("File %s does not exist.\n", file_name);
      return md_default;
    }
    mapping md = ([]);
    parse_html(s, ([ ]), ([ "md":container_md ]), md);
    return ([ "content_type": md_default->content_type ]) + md;
  }
  
  int set(object id, string f, mapping md)
  {
    object file = Stdio.File(real_path(id, f+".md"), "cwt");
    if(!file)
      return 0;
    
    string s = "";
    foreach(sort(indices(md)), string variable)
      s += "<md variable=\""+variable+"\">"+md[variable]+"</md>\n";
    file->write(s);
    return 1;
  }
}


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
