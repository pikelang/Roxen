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
