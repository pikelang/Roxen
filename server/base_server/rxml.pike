inherit "roxenlib";


array (mapping) tag_callers, container_callers;
mapping (string:mapping(int:function)) real_tag_callers,real_container_callers;
mapping (string:function) real_if_callers;
array (object) parse_modules = ({  });
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
		      RequestID id, object file, mapping defines,
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
	       int i, RequestID id, object file, mapping defines, object client)
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


string do_parse(string to_parse, RequestID id, object file, mapping defines,
		object my_fd)
{
  if(!id->misc->_tags)
  {
    id->misc->_tags = copy_value(tag_callers[0]);
    id->misc->_containers = copy_value(container_callers[0]);
    id->misc->_ifs = copy_value(real_if_callers);
  }
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
  real_if_callers=([]);

  //   misc_cache = ([]);
  tag_callers=({ ([]) });
  container_callers=({ ([]) });

  parse_modules-=({0});

  foreach(parse_modules, o)
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

    if(o->query_if_callers)
    {
      foo=o->query_if_callers();
      if(mappingp(foo)) 
        real_if_callers |= foo;
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



string call_user_tag(string tag, mapping args, int line, mixed foo, RequestID id)
{
  id->misc->line = line;
  args = id->misc->defaults[tag]|args;
  TRACE_ENTER("user defined tag &lt;"+tag+"&gt;", call_user_tag);
  array replace_from = ({"#args#"})+
    Array.map(indices(args),
	      lambda(string q){return "&"+q+";";});
  array replace_to = (({make_tag_attributes( args  ) })+
		      values(args));
  string r = replace(id->misc->tags[ tag ], replace_from, replace_to);
  TRACE_LEAVE("");
  return r;
}

string call_user_container(string tag, mapping args, string contents, int line,
			 mixed foo, RequestID id)
{
  if(!id->misc->defaults[tag] && id->misc->defaults[""])
    tag = "";
  id->misc->line = line;
  args = id->misc->defaults[tag]|args;
  if(args->preparse && 
     (args->preparse=="preparse" || (int)args->preparse))
    contents = parse_rxml(contents, id);
  TRACE_ENTER("user defined container &lt;"+tag+"&gt", call_user_container);
  array replace_from = ({"#args#", "<contents>"})+
    Array.map(indices(args),
	      lambda(string q){return "&"+q+";";});
  array replace_to = (({make_tag_attributes( args  ),
			contents })+
		      values(args));
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

string parse_rxml(string what, RequestID id, 
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



string tag_help(string t, mapping args, RequestID id)
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


string tag_list_tags( string t, mapping args, RequestID id, object f )
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

string tag_line( string t, mapping args, RequestID id)
{
  return id->misc->line;
}

string tag_number(string t, mapping args)
{
  return roxen->language(args->language||args->lang, 
			 args->type||"number")( (int)args->num );
}

array(string) list_packages()
{
  return Array.filter(((get_dir("../local/rxml_packages")||({}))
                       |(get_dir("../rxml_packages")||({}))), 
                      lambda( string s ) {
                        return (Stdio.file_size("../local/rxml_packages/"+s)+
                                Stdio.file_size( "../rxml_packages/"+s )) > 0;
                      });

}

string read_package( string p )
{
  string data;
  p -= "/";
  if(file_stat( "../local/rxml_packages/"+p ))
    catch(data=Stdio.File( "../local/rxml_packages/"+p, "r" )->read());
  if(!data && file_stat( "../rxml_packages/"+p ))
    catch(data=Stdio.File( "../rxml_packages/"+p, "r" )->read());
  return data;
}


string use_file_doc( string f, string data, RequestID nid, object id )
{
  string res="";
  catch 
  {
    string doc = "";
    int help=0; /* If true, all tags support the 'help' argument. */
    sscanf(data, "%*sdoc=\"%s\"", doc);
    sscanf(data, "%*sdoc=%d", help); 
    parse_rxml("<scope>"+data+"</scope>", nid);
    res += "<dt><b>"+f+"</b><dd>"+(doc?doc+"<br>":"");
    array tags = indices(nid->misc->tags||({}));
    array containers = indices(nid->misc->containers||({}));
    array ifs = indices(nid->misc->_ifs||({}))- indices(id->misc->_ifs);
    array defines = indices(nid->misc->defines||({}))- indices(id->misc->defines);
    if(sizeof(tags))
      res += "defines the following tag"+
        (sizeof(tags)!=1?"s":"") +": "+
        String.implode_nicely( sort(tags) )+"<br>";
    if(sizeof(containers))
      res += "defines the following container"+
        (sizeof(tags)!=1?"s":"") +": "+
        String.implode_nicely( sort(containers) )+"<br>";
    if(sizeof(ifs))
      res += "defines the following if argument"+
        (sizeof(ifs)!=1?"s":"") +": "+
        String.implode_nicely( sort(ifs) )+"<br>";
    if(sizeof(defines))
      res += "defines the following macro"+
        (sizeof(defines)!=1?"s":"") +": "+
        String.implode_nicely( sort(defines) )+"<br>";
  };
  nid->misc->tags = 0;
  nid->misc->containers = 0;
  nid->misc->defines = ([]);
  nid->misc->_tags = 0;
  nid->misc->_containers = 0;
  nid->misc->defaults = ([]);
  nid->misc->_ifs = ([]);
  return res;
}

array tag_use(string tag, mapping m, string c, RequestID id)
{
  mapping res = ([]);
  object nid = id->clone_me();
  nid->misc->tags = 0;
  nid->misc->containers = 0;
  nid->misc->defines = ([]);
  nid->misc->_tags = 0;
  nid->misc->_containers = 0;
  nid->misc->defaults = ([]);
  nid->misc->_ifs = ([]);

  if(m->packageinfo)
  {
    string res ="<dl>";
    foreach(list_packages(), string f)
      res += use_file_doc( f, read_package( f ), nid,id );
    return ({res+"</dl>"});
  }

  if(!m->file && !m->package) 
    return ({"<use help>"});
  
  if(id->pragma["no-cache"] || 
     !(res=cache_lookup("macrofiles:"+name,(m->file||("pkg!"+m->package)))))
  {
    res = ([]);
    string foo;
    if(m->file)
      foo = try_get_file( fix_relative(m->file,nid), nid );
    else 
      foo=read_package( m->package );
      
    if(!foo)
      if(id->misc->debug)
	return ({"Failed to fetch "+(m->file||m->package)});
      else
	return ({""});

    if( m->info )
      return ({"<dl>"+use_file_doc( m->file || m->package, foo, nid,id )+"</dl>"});

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
    res->_ifs = nid->misc->_ifs;
    m_delete(res->defines, "line");
    cache_set("macrofiles:"+name, (m->file || ("pkg!"+m->package)), res);
  }
  id->misc->tags += res->tags;
  id->misc->containers += res->containers;
  id->misc->defaults += res->defaults;
  id->misc->defines += res->defines;
  id->misc->_tags += res->_tags;
  id->misc->_containers += res->_containers;
  id->misc->_ifs += res->_ifs;
  return ({parse_rxml( c, id )});
}

string tag_define(string tag, mapping m, string str, RequestID id, 
                  object file, mapping defines)
{ 
  if (m->name) 
    defines[m->name]=str;
  else if(m->variable)
    id->variables[m->variable] = str;
  else if (m->tag) 
  {
    m->tag = lower_case(m->tag);
    string n = m->tag;
    m_delete( m, "tag" );
    if(!id->misc->tags)
      id->misc->tags = ([]);
    if(!id->misc->defaults)
      id->misc->defaults = ([]);
    if(!id->misc->defaults[n])
      id->misc->defaults[n] = ([]);

    foreach( indices(m), string arg )
      if( arg[..7] == "default_" )
      {
	id->misc->defaults[n][arg[8..]] = m[arg];
        m_delete( m, arg );
      }
    
    id->misc->tags[n] = replace( str, indices(m), values(m) );
    id->misc->_tags[n] = call_user_tag;
  }
  else if (m->container) 
  {
    string n = lower_case(m->container);
    m_delete( m, "container" );
    if(!id->misc->containers)
      id->misc->containers = ([]);
    if(!id->misc->defaults)
      id->misc->defaults = ([]);
    if(!id->misc->defaults[n])
      id->misc->defaults[n] = ([]);

    foreach( indices(m), string arg )
      if( arg[0..7] == "default_" )
      {
	id->misc->defaults[n][arg[8..]] = m[arg];
        m_delete( m, arg );
      }
    
    id->misc->containers[n] = replace( str, indices(m), values(m) );
    id->misc->_containers[n] = call_user_container;
  }
  else if (m["if"])
  {
    id->misc->_ifs[ lower_case(m["if"]) ] = UserIf( str );
  }
  else 
  {
    if(!id->misc->debug)
      return "<!-- No name, tag, if or container specified for the define! "
        "&lt;define help&gt; for instructions. -->";
      return "No name, tag, if or container specified for the define! "
        "&lt;define help&gt; for instructions.";
  }
  
  return ""; 
}

string tag_undefine(string tag, mapping m, RequestID id, object file,
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
  else if (m["if"]) 
  {
    m_delete(id->misc->_ifs,m["if"]);
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



class Tracer
{
  inherit "roxenlib";
  string resolv="<ol>";
  int level;

  mapping et = ([]);
#if efun(gethrvtime)
  mapping et2 = ([]);
#endif

  string module_name(function|object m)
  {
    if(!m)return "";
    if(functionp(m)) m = function_object(m);
    catch {
      return (strlen(m->query("_name")) ? m->query("_name") :
              (m->query_name&&m->query_name()&&strlen(m->query_name()))?
              m->query_name():m->register_module()[1]);
    };
    return "Internal RXML tag";
  }

  void trace_enter_ol(string type, function|object module)
  {
    level++; 

    string efont="", font="";
    if(level>2) {efont="</font>";font="<font size=-1>";} 
    resolv += (font+"<b><li></b> "+type+" "+module_name(module)+"<ol>"+efont);
#if efun(gethrvtime)
    et2[level] = gethrvtime();
#endif
#if efun(gethrtime)
    et[level] = gethrtime();
#endif
  }

  void trace_leave_ol(string desc)
  {
#if efun(gethrtime)
    int delay = gethrtime()-et[level];
#endif
#if efun(gethrvtime)
    int delay2 = gethrvtime()-et2[level];
#endif
    level--;
    string efont="", font="";
    if(level>1) {efont="</font>";font="<font size=-1>";} 
    resolv += (font+"</ol>"+
#if efun(gethrtime)
	       "Time: "+sprintf("%.5f",delay/1000000.0)+
#endif
#if efun(gethrvtime)
	       " (CPU = "+sprintf("%.2f)", delay2/1000000.0)+
#endif /* efun(gethrvtime) */
	       "<br>"+html_encode_string(desc)+efont)+"<p>";

  }

  string res()
  {
    while(level>0) trace_leave_ol("");
    return resolv+"</ol>";
  }
}

class SumTracer
{
  inherit Tracer;
#if 0
  mapping levels = ([]);
  mapping sum = ([]);
  void trace_enter_ol(string type, function|object module)
  {
    resolv="";
    ::trace_enter_ol();
    levels[level] = type+" "+module;
  }

  void trace_leave_ol(string mess)
  {
    string t = levels[level--];
#if efun(gethrtime)
    int delay = gethrtime()-et[type+" "+module_name(module)];
#endif
#if efun(gethrvtime)
    int delay2 = +gethrvtime()-et2[t];
#endif
    t+=html_encode_string(mess);
    if( sum[ t ] ) {
      sum[ t ][ 0 ] += delay;
#if efun(gethrvtime)
      sum[ t ][ 1 ] += delay2;
#endif
    } else {
      sum[ t ] = ({ delay, 
#if efun(gethrvtime)
		    delay2 
#endif
      });
    }
  }

  string res()
  {
    foreach(indices());
  }
#endif
}

string tag_trace(string t, mapping args, string c , RequestID id)
{
  NOCACHE();
  object t;
  if(args->summary)
    t = SumTracer();
  else
    t = Tracer();
  function a = id->misc->trace_enter;
  function b = id->misc->trace_leave;
  id->misc->trace_enter = t->trace_enter_ol;
  id->misc->trace_leave = t->trace_leave_ol;
  t->trace_enter_ol( "tag &lt;trace&gt;", tag_trace);
  string r = parse_rxml(c, id);
  id->misc->trace_enter = a;
  id->misc->trace_leave = b;
  return r + "<h1>Trace report</h1>"+t->res()+"</ol>";
}

string tag_for(string t, mapping args, string c, RequestID id)
{
  string v = args->variable;
  int from = (int)args->from;
  int to = (int)args->to;
  int step = (int)args->step||1;
  
  m_delete(args, "from");
  m_delete(args, "to");
  m_delete(args, "variable");
  string res="";
  for(int i=from; i<=to; i+=step)
    res += "<set variable="+v+" value="+i+">"+c;
  return res;
}



array(string) tag_noparse(string t, mapping m, string c)
{
  return ({ c });
}

string tag_nooutput(string t, mapping m, string c, RequestID id)
{
  parse_rxml(c, id);
  return "";
}

string tag_strlen(string t, mapping m, string c, RequestID id)
{
  return (string)strlen(c);
}


string tag_case(string t, mapping m, string c, RequestID id)
{
  if(m->lower)
    c = lower_case(c);
  if(m->upper)
    c = upper_case(c);
  if(m->capitalize)
    c = capitalize(c);
  return c;
}

#define LAST_IF_TRUE id->misc->defines[" _ok"]

string tag_if( string t, mapping m, string c, RequestID id )
{
  int res, and = 1;

  if(m->not) 
  {
    m_delete( m, "not" );
    tag_if( t, m, c, id );
    LAST_IF_TRUE = !LAST_IF_TRUE;
    if(LAST_IF_TRUE)
      return c+"<true>";
    return "<false>";
  }

  if(m->or)  { and = 0; m_delete( m, "or" ); }
  if(m->and) { and = 1; m_delete( m, "and" ); }
  array possible = indices(m) & indices(real_if_callers);

  LAST_IF_TRUE=0;
  foreach(possible, string s)
  {
    res = real_if_callers[ s ]( m[s], id, m, and, s );
    LAST_IF_TRUE=res;
    if(res)
    {
      if(!and) 
        return c+"<true>";
    }
    else 
    {
      if(and) 
        return "<false>";
    }
  }
  if( LAST_IF_TRUE )
    return c+"<true>";
  return "<false>";
}

string tag_else( string t, mapping m, string c, RequestID id )
{
  if(!LAST_IF_TRUE) return c;
  return "";
}

string tag_elseif( string t, mapping m, string c, RequestID id )
{
  if(!LAST_IF_TRUE) return tag_if( t, m, c, id );
  return "";
}

string tag_true( string t, mapping m, string c, RequestID id )
{
  LAST_IF_TRUE = 1;
  return "";
}

string tag_false( string t, mapping m, string c, RequestID id )
{
  LAST_IF_TRUE = 0;
  return "";
}

void internal_tag_case( string t, mapping m, string c, int l, RequestID id,
                        mapping res )
{
  if(res->res) return;
  LAST_IF_TRUE = 0;
  tag_if( t, m, c, id );
  if(LAST_IF_TRUE) res->res = c+"<true>";
  return;
}

string tag_cond( string t, mapping m, string c, RequestID id )
{
  mapping result = ([]);
  parse_html_lines(c,([]),(["case":internal_tag_case, 
                            "default":lambda(mixed ... a){
    result->def = a[2]+"<false>"; }]),id,result);
  return result->res||result->def;
}

mapping query_container_callers()
{
  return ([
    "comment":lambda(){ return ""; },
    "if":tag_if,
    "else":tag_else,
    "elseif":tag_elseif,
    "elif":tag_elseif,
    "true":tag_true,
    "false":tag_false,
    "noparse":tag_noparse,
    "nooutput":tag_nooutput,
    "case":tag_case,
    "cond":tag_cond,
    "strlen":tag_nooutput,
    "define":tag_define,
    "for":tag_for,
    "trace":tag_trace,
    "use":tag_use,
  ]);
}


mapping query_tag_callers()
{
  return ([
    "list-tags":tag_list_tags,
    "number":tag_number,
    "undefine":tag_undefine,
    "help": tag_help,
    "line":tag_line,
  ]);
}


class UserIf
{
  string rxml_code;
  void create( string what )
  {
    rxml_code = what;
  }
  
  int `()( string ind, RequestID id, mapping args, int and, string a )
  {
    int oif, res;
    array replace_from = Array.map(indices(args),
                                   lambda(string q){return "&"+q+";";});
    array replace_to = values(args);

    oif = LAST_IF_TRUE;
    TRACE_ENTER("user defined if argument &lt;"+a+"&gt;", UserIf);
    LAST_IF_TRUE = 0;
    parse_rxml( replace(rxml_code, replace_from, replace_to ), id );
    res = LAST_IF_TRUE;

    TRACE_LEAVE("");
    LAST_IF_TRUE = oif;

    return res;
  } 
}

class IfIs
{
  string index;
  int cache, misc;
  function `() = match_in_map;

  void create( string ind, int c, int|void m )
  {
    index = ind;
    if(!ind)
      `() = match_in_string;
    cache = c;
    misc = m;
  }

  int match_in_string( string value, RequestID id )
  {
    string is;
    if(!cache) CACHE(0);
    sscanf( value, "%s is %s", value, is );
    if(!is) return strlen(value);
    value = lower_case( value );
    is = lower_case( is );
    return ((is==value)||glob(is,value)||
            sizeof(Array.filter( is/",", glob, value )));
  }

  int match_in_map( string value, RequestID id )
  {
    string is;
    if(!cache) CACHE(0);
    sscanf( value, "%s is %s", value, is );
    value = misc?id->misc[index][value]:id[index][value];
    if(!is || !value) return !!value;
    value = lower_case( value );
    is = lower_case( is );
    return ((is==value)||glob(is,value)||
            sizeof(Array.filter( is/",", glob, value )));
  }
}

class IfMatch
{
  string index;
  int cache, misc;
  void create(string ind, int c, int|void m)
  {
    index = ind;
    cache = c;
    misc = m;
  }
  void `()( string is, RequestID id )
  {
    array|string value = misc?id->misc[index]:id[index];
    if(!cache) CACHE(0);
    if(!value) return 0;
    if(arrayp(value)) value=value*" ";
    value = lower_case( value );
    is = lower_case( "*"+is+"*" );
    return (glob(is,value)||sizeof(Array.filter( is/",", glob, value )));
  }
}


int if_date( string date, RequestID id, mapping m )
{
  CACHE(60);
  int a, b;
  mapping c;
  c=localtime(time(1));
  b=(int)sprintf("%02d%02d%02d", c->year, c->mon + 1, c->mday);
  a=(int)date;
  if(a > 999999) a -= 19000000;
  else if(a < 901201) a += 10000000;
  if(m->inclusive || !(m->before || m->after) && a==b)
    return 1;
  if(m->before && a>b)
    return 1;
  else if(m->after && a<b)
    return 1;
}

int if_time( string ti, RequestID id, mapping m )
{
  CACHE(time(1)%60);

  int tok, a, b, d;
  mapping c;
  c=localtime(time());
  
  b=(int)sprintf("%02d%02d", c->hour, c->min);
  a=(int)ti;

  if(m->until) {
    d = (int)m->until;
    if (d > a && (b > a && b < d) )
      return 1;
    if (d < a && (b > a || b < d) )
      return 1;
    if (m->inclusive && ( b==a || b==d ) )
      return 1;
  }
  else if(m->inclusive || !(m->before || m->after) && a==b)
    return 1;
  if(m->before && a>b)
    return 1;
  else if(m->after && a<b)
    return 1;
}

int match_passwd(string try, string org)
{
  if(!strlen(org))   return 1;
  if(crypt(try, org)) return 1;
}

string simple_parse_users_file(string file, string u)
{
  if(!file) return 0;
  foreach(file/"\n", string line)
  {
    array(string) arr = line/":";
    if (arr[0] == u && sizeof(arr) > 1)
      return(arr[1]);
  }
}

int match_user(array u, string user, string f, int wwwfile, object id)
{
  string s, pass;
  if(u[1]!=user) 
    return 0;
  if(!wwwfile)
    s=Stdio.read_bytes(f);
  else
    s=id->conf->try_get_file(fix_relative(f,id), id);
  return (pass=simple_parse_users_file(s, u[1]) &&
          (u[0] || match_passwd(u[2], pass)));
}

multiset simple_parse_group_file(string file, string g)
{
 multiset res = (<>);
 array(string) arr ;
 foreach(file/"\n", string line)
   if(sizeof(arr = line/":")>1 && (arr[0] == g))
     res += (< @arr[-1]/"," >);
 return res;
}

int group_member(array auth, string group, string groupfile, object id)
{
  if(!auth)
    return 0; // No auth sent

  string s;
  catch { s = Stdio.read_bytes(groupfile); };

  if (!s)
    s = id->conf->try_get_file( fix_relative( groupfile, id), id );

  if (!s) 
    return 0;

  s = replace(s,({" ","\t","\r" }), ({"","","" }));

  multiset(string) members = simple_parse_group_file(s, group);
  return members[auth[1]];
}

int if_user( string u, RequestID id, mapping m )
{
  NOCACHE();
  if(!id->auth)
    return 0;
  if(u == "any")
    if(m->file)
      return match_user(id->auth,id->auth[1],m->file,!!m->wwwfile, id);
    else
      return id->auth[0];
  else
    if(m->file)
      // FIXME: wwwfile attribute doesn't work.
      return match_user(id->auth,u,m->file,!!m->wwwfile,id);
    else
      return id->auth[0] && (search(u/",", id->auth[1]) != -1);
}

int if_group( string u, RequestID id, mapping m)
{
  NOCACHE();
  return ((m->groupfile && sizeof(m->groupfile)) 
          && group_member(id->auth, m->group, m->groupfile, id));
}

mapping query_if_callers()
{
  return ([
    "successful":lambda(string u, RequestID id){ return LAST_IF_TRUE; },
    "failed":lambda(string u, RequestID id){ return !LAST_IF_TRUE; },
    "accept":IfMatch( "accept", 0, 1),
    "config":IfIs( "config", 0 ),
    "cookie":IfIs( "cookies", 0 ),
    "client":IfMatch( "client", 0 ),
    "date":if_date,
    "defined":IfIs( "defines", 1 ),
    "domain":IfMatch( "host", 0 ),
    "group":if_group,
    "host":IfMatch( "remoteaddr", 0 ),
    "ip":IfMatch( "remoteaddr", 0 ),
    "language":IfMatch( "accept-language", 0, 1),
    "match":IfIs( 0, 0 ),
    "name":IfMatch( "client", 0 ),
    "pragma":IfIs( "pragma", 0 ),
    "prestate":IfIs( "prestate", 1 ),
    "referrer":IfMatch( "referrer", 0 ),
    "supports":IfIs( "supports", 0 ),
    "time":if_time,
    "user":if_user,
    "variable":IfIs( "variables", 1 ),
  ]);
}
