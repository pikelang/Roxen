inherit "roxenlib";

array (mapping) tag_callers, container_callers;
mapping (string:mapping(int:function)) real_tag_callers,real_container_callers;
array (object) parse_modules = ({ this_object() });
string date_doc=#string "../modules/tags/doc/date_doc";

#define TRACE_ENTER(A,B) do{if(id->misc->trace_enter)id->misc->trace_enter((A),(B));}while(0)
#define TRACE_LEAVE(A) do{if(id->misc->trace_leave)id->misc->trace_leave((A));}while(0)

string parse_doc(string doc, string tag)
{
  return replace(doc, ({"{","}","<tag>","<roxen-languages>"}),
		 ({"&lt;", "&gt;", tag, 
		   String.implode_nicely(sort(indices(roxen->languages)), 
					 "and")}));
}

string handle_help(string file, string tag, mapping args)
{
  return parse_doc(replace(Stdio.read_bytes(file),
			   "<date-attributes>",date_doc),tag);
}

array|string call_tag(string tag, mapping args, int line, int i,
		      object id, object file, mapping defines,
		      object client)
{
  string|function rf = real_tag_callers[tag][i];
  id->misc->line = (string)line;
  if(args->help && Stdio.file_size("modules/tags/doc/"+tag) > 0)
  {
    TRACE_ENTER("tag &lt;"+tag+" help&gt", rf);
    string h = handle_help("modules/tags/doc/"+tag, tag, args);
    TRACE_LEAVE("");
    return h;
  }
  if(stringp(rf)) return rf;

  TRACE_ENTER("tag &lt;" + tag + "&gt;", rf);
#ifdef MODULE_LEVEL_SECURITY
  if(check_security(rf, id, id->misc->seclevel))
  {
    TRACE_LEAVE("Access denied");
    return 0;
  }
#endif
  mixed result=rf(tag,args,id,file,defines,client);
  TRACE_LEAVE("");
  if(args->noparse && stringp(result)) return ({ result });
  return result;
}

array(string)|string 
call_container(string tag, mapping args, string contents, int line,
	       int i, object id, object file, mapping defines, object client)
{
  id->misc->line = (string)line;
  string|function rf = real_container_callers[tag][i];
  if(args->help && Stdio.file_size("modules/tags/doc/"+tag) > 0)
  {
    TRACE_ENTER("container &lt;"+tag+" help&gt", rf);
    string h = handle_help("modules/tags/doc/"+tag, tag, args)+contents;
    TRACE_LEAVE("");
    return h;
  }
  if(stringp(rf)) return rf;
  TRACE_ENTER("container &lt;"+tag+"&gt", rf);
  if(args->preparse) contents = parse_rxml(contents, id);
  if(args->trimwhites) {
    sscanf(contents, "%*[ \t\n\r]%s", contents);
    contents = reverse(contents);
    sscanf(contents, "%*[ \t\n\r]%s", contents);
    contents = reverse(contents);
  }
#ifdef MODULE_LEVEL_SECURITY
  if(check_security(rf, id, id->misc->seclevel))
  {
    TRACE_LEAVE("Access denied");
    return 0;
  }
#endif
  mixed result=rf(tag,args,contents,id,file,defines,client);
  TRACE_LEAVE("");
  if(args->noparse && stringp(result)) return ({ result });
  return result;
}


string do_parse(string to_parse, object id, object file, mapping defines,
		object my_fd)
{
  if(!id->misc->_tags)
    id->misc->_tags = copy_value(tag_callers[0]);
  if(!id->misc->_containers)
    id->misc->_containers = copy_value(container_callers[0]);
  to_parse=parse_html_lines(to_parse,id->misc->_tags,id->misc->_containers,
			    0, id, file, defines, my_fd);
  for(int i = 1; i<sizeof(tag_callers); i++)
    to_parse=parse_html_lines(to_parse,tag_callers[i], container_callers[i],
			      i, id, file, defines, my_fd);
  return to_parse;
}


/* parsing modules */
void insert_in_map_list(mapping to_insert, string map_in_object)
{
  function do_call = this_object()["call_"+map_in_object];
  array (mapping) in = this_object()[map_in_object+"_callers"];
  mapping (string:mapping) in2=
    this_object()["real_"+map_in_object+"_callers"];

  
  foreach(indices(to_insert), string s)
  {
    if(!in2[s]) in2[s] = ([]);
    int i;
    for(i=0; i<sizeof(in); i++)
      if(!in[i][s])
      {
	in[i][s] = do_call;
	in2[s][i] = to_insert[s];
	break;
      }
    if(i==sizeof(in))
    {
      in += ({ ([]) });
      if(map_in_object == "tag")
	container_callers += ({ ([]) });
      else
	tag_callers += ({ ([]) });
      in[i][s] = do_call;
      in2[s][i] = to_insert[s];
    }
  }
  this_object()[map_in_object+"_callers"]=in;
  this_object()["real_"+map_in_object+"_callers"]=in2;
}


void build_callers()
{
  object o;
  real_tag_callers=([]);
  real_container_callers=([]);

  //   misc_cache = ([]);
  tag_callers=({ ([]) });
  container_callers=({ ([]) });

  parse_modules-=({0});

  foreach (parse_modules,o)
  {
    mapping foo;
    if(o->query_tag_callers)
    {
      foo=o->query_tag_callers();
      if(mappingp(foo)) insert_in_map_list(foo, "tag");
    }
     
    if(o->query_container_callers)
    {
      foo=o->query_container_callers();
      if(mappingp(foo)) insert_in_map_list(foo, "container");
    }
  }
  sort_lists();
}

void add_parse_module(object o)
{
  parse_modules |= ({o});
  remove_call_out(build_callers);
  call_out(build_callers,0);
}

void remove_parse_module(object o)
{
  parse_modules -= ({o});
  remove_call_out(build_callers);
  call_out(build_callers,0);
}



string call_user_tag(string tag, mapping args, int line, mixed foo, object id)
{
  id->misc->line = line;
  args = id->misc->defaults[tag]|args;
  if(!id->misc->up_args) id->misc->up_args = ([]);
  TRACE_ENTER("user defined tag &lt;"+tag+"&gt;", call_user_tag);
  array replace_from = ({"#args#"})+
    Array.map(indices(args)+indices(id->misc->up_args),
	      lambda(string q){return "&"+q+";";});
  array replace_to = (({make_tag_attributes( args + id->misc->up_args ) })+
		      values(args)+values(id->misc->up_args));
  foreach(indices(args), string a)
  {
    id->misc->up_args["::"+a]=args[a];
    id->misc->up_args[tag+"::"+a]=args[a];
  }
  string r = replace(id->misc->tags[ tag ], replace_from, replace_to);
  TRACE_LEAVE("");
  return r;
}

string call_user_container(string tag, mapping args, string contents, int line,
			 mixed foo, object id)
{
  if(!id->misc->defaults[tag] && id->misc->defaults[""])
    tag = "";
  id->misc->line = line;
  args = id->misc->defaults[tag]|args;
  if(!id->misc->up_args) id->misc->up_args = ([]);
  if(args->preparse && 
     (args->preparse=="preparse" || (int)args->preparse))
    contents = parse_rxml(contents, id);
  TRACE_ENTER("user defined container &lt;"+tag+"&gt", call_user_container);
  array replace_from = ({"#args#", "<contents>"})+
    Array.map(indices(args)+indices(id->misc->up_args),
	      lambda(string q){return "&"+q+";";});
  array replace_to = (({make_tag_attributes( args + id->misc->up_args ),
			contents })+
		      values(args)+values(id->misc->up_args));
  foreach(indices(args), string a)
  {
    id->misc->up_args["::"+a]=args[a];
    id->misc->up_args[tag+"::"+a]=args[a];
  }
  string r = replace(id->misc->containers[ tag ], replace_from, replace_to);
  TRACE_LEAVE("");
  return r;
}


void sort_lists()
{
  array ind, val, s;
  foreach(indices(real_tag_callers), string c)
  {
    ind = indices(real_tag_callers[c]);
    val = values(real_tag_callers[c]);
    sort(ind);
    s = Array.map(val, lambda(function f) {
			 catch {
			   return
			     function_object(f)->query("_priority");
			 };
// 			 werror("no priority for tag function %O\n",f);
			 return 4;
		       });
    sort(s,val);
    real_tag_callers[c]=mkmapping(ind,val);
  }
  foreach(indices(real_container_callers), string c)
  {
    ind = indices(real_container_callers[c]);
    val = values(real_container_callers[c]);
    sort(ind);
    s = Array.map(val, lambda(function f) {
			 catch{
			   if (functionp(f)) 
			     return function_object(f)->query("_priority");
			 };
// 			 werror("no priority for tag function %O\n",f);
			 return 4;
		       });
    sort(s,val);
    real_container_callers[c]=mkmapping(ind,val);
  }
}


#define _stat defines[" _stat"]
#define _error defines[" _error"]
#define _extra_heads defines[" _extra_heads"]
#define _rettext defines[" _rettext"]
#define _ok     defines[" _ok"]

string parse_rxml(string what, object id, 
		  void|object file,
		  void|mapping defines )
{
  id->misc->_rxml_recurse++;
#ifdef RXML_DEBUG
  werror("parse_rxml( "+strlen(what)+" ) -> ");
  int time = gethrtime();
#endif
  if(!defines) 
  {
    defines = id->misc->defines||([]);
    if(!_error)
      _error=200;
    if(!_extra_heads)
      _extra_heads=([ ]);
  }
  if(!defines->sizefmt)
  {
    set_start_quote(set_end_quote(0));
    defines->sizefmt = "abbrev"; 
    _error=200;
    _extra_heads=([ ]);
    if(id->misc->stat)
      _stat=id->misc->stat;
    else if(file)
      _stat=file->stat();
  }
  id->misc->defines = defines;

  what = do_parse(what, id, file||id->my_fd, defines, id->my_fd);

  if(sizeof(_extra_heads) && !id->misc->moreheads)
  {
    id->misc->moreheads= ([]);
    id->misc->moreheads |= _extra_heads;
  }
  id->misc->_rxml_recurse--;
#ifdef RXML_DEBUG
  werror("%d (%3.3fs)\n%s", strlen(what),(gethrtime()-time)/1000000.0,
	 ("  "*id->misc->_rxml_recurse));
#endif
  return what;
}



string tag_help(string t, mapping args, object id)
{
  array tags = sort(Array.filter(get_dir("modules/tags/doc/"),
			     lambda(string tag) {
			       if(tag[0] != '#' &&
				  tag[-1] != '~' &&
				  tag[0] != '.' &&
				  tag != "CVS")
				 return 1;
			     }));
  string help_for = args["for"] || id->variables->_r_t_h;

  if(!help_for)
  {
    string out = "<h3>Roxen Interactive RXML Help</h3>"
      "<b>Here is a list of all documented tags. Click on the name to "
      "receive more detailed information.</b><p>";
    array tag_links = ({});
    foreach(tags, string tag)
    {
      tag_links += ({ sprintf("<a href=?_r_t_h=%s>%s</a>", tag, tag) });
    }
    return out + String.implode_nicely(tag_links);
  } else if(Stdio.file_size("modules/tags/doc/"+help_for) > 0) {
    string h = handle_help("modules/tags/doc/"+help_for, help_for, args);
    return h;
  } else {
    return "<h3>No help available for "+help_for+".</h3>";
  }
}


string tag_list_tags( string t, mapping args, object id, object f )
{
  int verbose;
  string res="";
  if(args->verbose) verbose = 1;

  for(int i = 0; i<sizeof(tag_callers); i++)
  {
    res += ("<b><font size=+1>Tags at prioity level "+i+": </b></font><p>");
    foreach(sort(indices(tag_callers[i])), string tag)
    {
      res += "  <a name=\""+replace(tag+i, "#", ".")+"\"><a href=\""+id->not_query+"?verbose="+replace(tag+i, "#","%23")+"#"+replace(tag+i, "#", ".")+"\">&lt;"+tag+"&gt;</a></a><br>";
      if(verbose || id->variables->verbose == tag+i)
      {
	res += "<blockquote><table><tr><td>";
	string tr;
	catch(tr=call_tag(tag, (["help":"help"]), 
				    id->misc->line,i,
				    id, f, id->misc->defines, id->my_fd ));
	if(tr) res += tr; else res += "no help";
	res += "</td></tr></table></blockquote>";
      }
    }
  }

  for(int i = 0; i<sizeof(container_callers); i++)
  {
    res += ("<p><b><font size=+1>Containers at prioity level "+i+": </b></font><p>");
    foreach(sort(indices(container_callers[i])), string tag)
    {
      res += " <a name=\""+replace(tag+i, "#", ".")+"\"><a href=\""+id->not_query+"?verbose="+replace(tag+i, "#", "%23")+"#"+replace(tag+i,"#",".")+"\">&lt;"+tag+"&gt;&lt;/"+tag+"&gt;</a></a><br>";
      if(verbose || id->variables->verbose == tag+i)
      {
	res += "<blockquote><table><tr><td>";
	string tr;
	catch(tr=call_container(tag, (["help":"help"]), "",
				id->misc->line,
				i, id,f, id->misc->defines, id->my_fd ));
	if(tr) res += tr; else res += "no help";
	res += "</td></tr></table></blockquote>";
      }
    }
  }
  return res;
}

string tag_line( string t, mapping args, object id)
{
  return id->misc->line;
}


string tag_use(string tag, mapping m, object id)
{
  mapping res = ([]);
  object nid = id->clone_me();
  nid->misc->tags = 0;
  nid->misc->containers = 0;
  nid->misc->defines = ([]);
  nid->misc->_tags = 0;
  nid->misc->_containers = 0;
  nid->misc->defaults = ([]);

  if(m->packageinfo)
  {
    string res ="<dl>";
    array dirs = get_dir("../rxml_packages");
    if(dirs)
      foreach(dirs, string f)
	catch 
	{
	  string doc = "";
	  string data = Stdio.read_bytes("../rxml_packages/"+f);
	  sscanf(data, "%*sdoc=\"%s\"", doc);
	  parse_rxml(data, nid);
	  res += "<dt><b>"+f+"</b><dd>"+doc+"<br>";
	  array tags = indices(nid->misc->tags||({}));
	  array containers = indices(nid->misc->containers||({}));
	  if(sizeof(tags))
	    res += "defines the following tag"+
	      (sizeof(tags)!=1?"s":"") +": "+
	      String.implode_nicely( sort(tags) )+"<br>";
	  if(sizeof(containers))
	    res += "defines the following container"+
	      (sizeof(tags)!=1?"s":"") +": "+
	      String.implode_nicely( sort(containers) )+"<br>";
	};
    else
      return "No package directory installed.";
    return res+"</dl>";
  }


  if(!m->file && !m->package) 
    return "<use help>";
  
  if(id->pragma["no-cache"] || 
     !(res = cache_lookup("macrofiles:"+ name ,
			  (m->file || m->package))))
  {
    res = ([]);
    string foo;
    if(m->file)
      foo = try_get_file( fix_relative(m->file,nid), nid );
    else 
      foo=Stdio.read_bytes("../rxml_packages/"+combine_path("/",m->package));
      
    if(!foo)
      if(id->misc->debug)
	return "Failed to fetch "+(m->file||m->package);
      else
	return "";
    parse_rxml( foo, nid );
    res->tags  = nid->misc->tags||([]);
    res->_tags = nid->misc->_tags||([]);
    foreach(indices(res->_tags), string t)
      if(!res->tags[t]) m_delete(res->_tags, t);
    res->containers  = nid->misc->containers||([]);
    res->_containers = nid->misc->_containers||([]);
    foreach(indices(res->_containers), string t)
      if(!res->containers[t]) m_delete(res->_containers, t);
    res->defines = nid->misc->defines||([]);
    res->defaults = nid->misc->defaults||([]);
    m_delete(res->defines, "line");
    cache_set("macrofiles:"+ name, (m->file || m->package), res);
  }

  if(!id->misc->tags)
    id->misc->tags = res->tags;
  else
    id->misc->tags |= res->tags;

  if(!id->misc->containers)
    id->misc->containers = res->containers;
  else
    id->misc->containers |= res->containers;

  if(!id->misc->defaults)
    id->misc->defaults = res->defaults;
  else
    id->misc->defaults |= res->defaults;

  if(!id->misc->defines)
    id->misc->defines = res->defines;
  else
    id->misc->defines |= res->defines;

  foreach(indices(res->_tags), string t)
    id->misc->_tags[t] = res->_tags[t];

  foreach(indices(res->_containers), string t)
    id->misc->_containers[t] = res->_containers[t];

  if(id->misc->debug)
    return sprintf("<!-- Using the file %s, id %O -->", m->file, res);
  else
    return "";
}

string tag_define(string tag, mapping m, string str, object id, object file,
		  mapping defines)
{ 
  if (m->name) 
    defines[m->name]=str;
  else if(m->variable)
    id->variables[m->variable] = str;
  else if (m->tag) 
  {
    if(!id->misc->tags)
      id->misc->tags = ([]);
    if(!id->misc->defaults)
      id->misc->defaults = ([]);
    m->tag = lower_case(m->tag);
    if(!id->misc->defaults[m->tag])
      id->misc->defaults[m->tag] = ([]);

    foreach( indices(m), string arg )
      if( arg[0..7] == "default_" )
	id->misc->defaults[m->tag] += ([ arg[8..]:m[arg] ]);
    
    id->misc->tags[m->tag] = str;
    id->misc->_tags[m->tag] = call_user_tag;
  }
  else if (m->container) 
  {
    if(!id->misc->containers)
      id->misc->containers = ([]);

    if(!id->misc->defaults)
      id->misc->defaults = ([]);
    if(!id->misc->defaults[m->container])
      id->misc->defaults[m->container] = ([]);

    foreach( indices(m), string arg )
      if( arg[0..7] == "default_" )
	id->misc->defaults[m->container] += ([ arg[8..]:m[arg] ]);
    
    id->misc->containers[m->container] = str;
    id->misc->_containers[m->container] = call_user_container;
  }
  else return "<!-- No name, tag or container specified for the define! "
	 "&lt;define help&gt; for instructions. -->";
  return ""; 
}

string tag_undefine(string tag, mapping m, object id, object file,
		    mapping defines)
{ 
  if (m->name) 
    m_delete(defines,m->name);
  else if(m->variable)
    m_delete(id->variables,m->variable);
  else if (m->tag) 
  {
    m_delete(id->misc->tags,m->tag);
    m_delete(id->misc->_tags,m->tag);
  }
  else if (m->container) 
  {
    m_delete(id->misc->containers,m->container);
    m_delete(id->misc->_containers,m->container);
  }
  else return "<!-- No name, tag or container specified for undefine! "
	 "&lt;undefine help&gt; for instructions. -->";
  return ""; 
}


mapping query_container_callers()
{
  return ([
    "define":tag_define,
  ]);
}


mapping query_tag_callers()
{
  return ([
    "list-tags":tag_list_tags,
    "undefine":tag_undefine,
    "help": tag_help,
    "line":tag_line,
    "use":tag_use,
  ]);
}
