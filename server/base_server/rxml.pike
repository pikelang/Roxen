/*
 * $Id: rxml.pike,v 1.100 2000/02/06 20:08:22 mast Exp $
 *
 * The Roxen RXML Parser.
 *
 * Per Hedbor, Henrik Grubbström, Pontus Hagland, David Hedbor and others.
 */

inherit "roxenlib";
inherit "rxmlhelp";
#include <request_trace.h>

#define OLD_RXML_COMPAT
#define TAGMAP_COMPAT

#define RXML_NAMESPACE "rxml"

#ifndef manual

string rxml_error(string tag, string error, RequestID id) {
  return (id->misc->debug?sprintf("(%s: %s)",capitalize(tag),error):"")+"<false>";
}

string handle_rxml_error (mixed err, RXML.Type type)
// This is used for RXML errors thrown in the new parser. See
// RXML.Context.rxml_error().
{
#ifdef MODULE_DEBUG
  // FIXME: Make this a user option.
  report_notice (describe_error (err));
#endif
  if (type->subtype_of (RXML.t_html))
    return "<br clear=all>\n<pre>" + html_encode_string (describe_error (err)) + "</pre>";
  else return describe_error (err);
}

string handle_rxml_fatal (mixed err, RXML.Type type)
// This is used for RXML fatal errors thrown in the new parser. See
// RXML.Context.rxml_fatal().
{
#ifdef MODULE_DEBUG
  // FIXME: Make this a user option.
  report_notice (describe_error (err));
#endif
  if (type->subtype_of (RXML.t_html))
    return "<br clear=all>\n<pre>" + html_encode_string (describe_error (err)) + "</pre>";
  else return describe_error (err);
}

#ifdef OLD_RXML_COMPAT
RoxenModule rxml_warning_cache;
void old_rxml_warning(RequestID id, string no, string yes) {
  if(!rxml_warning_cache) rxml_warning_cache=id->conf->get_provider("oldRXMLwarning");
  if(!rxml_warning_cache) return;
  rxml_warning_cache->old_rxml_warning(id, no, yes);
}
#endif

// A note on tag overriding: It's possible for old style tags to
// propagate their results to the tags they have overridden. This is
// done by an extension to the return value:
//
// If an array of the form
//
// ({int 1, string name, mapping(string:string) args, void|string content})
//
// is returned, the tag function with the given name is called with
// these arguments. If the name is the same as the current tag, the
// overridden tag function is called. If there's no overridden
// function, the tag is generated in the output. Any argument may be
// left out to default to its value in the current tag. ({1, 0, 0}) or
// ({1, 0, 0, 0}) may be shortened to ({1}).
//
// Note that there's no other way to handle tag overriding -- the page
// is no longer parsed multiple times.


// ----------------------- Default scopes -------------------------

class ScopeRoxen {
  inherit RXML.Scope;

  string|int `[] (string var, void|RXML.Context c, void|string scope) {
    switch(var)
    {
     case "uptime":
       return (time(1)-roxen->start_time);
     case "uptime-days":
       return (time(1)-roxen->start_time)/3600/24;
     case "uptime-hours":
       return (time(1)-roxen->start_time)/3600 % 24;
     case "uptime-minutes":
       return (time(1)-roxen->start_time)/60 % 60;
     case "hits-per-minute":
       return c->id->conf->requests / (time(1)-roxen->start_time || 1);
     case "hits":
       return c->id->conf->requests;
     case "sent-mb":
       return sprintf("%1.2f",c->id->conf->sent / (1024.0*1024.0));
     case "sent":
       return c->id->conf->sent;
     case "sent-per-minute":
       return c->id->conf->sent / ((time(1)-roxen->start_time)/60 || 1);
     case "sent-kbit-per-second":
       return sprintf("%1.2f",((c->id->conf->sent*8)/1024.0/
                               (time(1)-roxen->start_time || 1)));
     case "pike-version":
       return predef::version();
     case "version":
       return roxen.version();
     case "time":
       return time(1);
     case "server":
       return c->id->conf->query("MyWorldLocation");
    }
    :: `[] (var, c, scope);
  }

  array(string) _indices() {
    return ({"uptime", "uptime-days", "uptime-hours", "uptime-minutes",
	     "hits-per-minute", "hits", "sent-mb", "sent",
             "sent-per-minute", "sent-kbit-per-second",
              "pike-version", "version", "time", "server"});
  }

  string _sprintf() { return "RXML.Scope(roxen)"; }
}

class ScopePage {
  inherit RXML.Scope;
  constant converter=(["fgcolor":"fgcolor", "bgcolor":"bgcolor",
		       "theme-bgcolor":"theme_bgcolor", "theme-fgcolor":"theme_fgcolor",
		       "theme-language":"theme_language"]);
  constant in_defines=aggregate_multiset(@indices(converter));

  mixed `[] (string var, void|RXML.Context c, void|string scope) {
    if(in_defines[var])
      return c->id->misc->defines[converter[var]];
    if(objectp(c->id->misc->page[var])) return c->id->misc->page[var]->rxml_var_eval(c);
    return c->id->misc->page[var];
  }

  mixed `[]= (string var, mixed val, void|RXML.Context c, void|string scope_name) {
    if(in_defines[var])
      return c->id->misc->defines[converter[var]]=val;
    return c->id->misc->page[var]=val;
  }

  array(string) _indices(void|RXML.Context c) {
    if(!c) return ({});
    array ind=indices(c->id->misc->page);
    foreach(indices(in_defines), string def)
      if(c->id->misc->defines[converter[def]]) ind+=({def});
    return ind;
  }

  void m_delete (string var, void|RXML.Context c, void|string scope_name) {
    if(!c) return;
    if(in_defines[var]) {
      if(var[0..4]=="theme")
	predef::m_delete(c->id->misc->defines, converter[var]);
      else
	::m_delete(var, c, scope_name);
    }
    predef::m_delete(c->id->misc->page, var);
  }

  string _sprintf() { return "RXML.Scope(page)"; }
}

RXML.Scope scope_roxen=ScopeRoxen();
RXML.Scope scope_page=ScopePage();


// ------------------------- RXML Parser ------------------------------

RXML.TagSet entities_tag_set = class
// This tag set always has the lowest priority.
{
  inherit RXML.TagSet;

  void prepare_context (RXML.Context c) {
    c->add_scope("roxen",scope_roxen);
    c->id->misc->page=([]);
    c->add_scope("page",scope_page);
    c->add_scope("cookie" ,c->id->cookies);
    c->add_scope("form", c->id->variables);
    c->add_scope("client", c->id->client_var);
    c->add_scope("var", ([]) );
  }

  // These are only used in new style tags.
  constant low_entities = ([
    "quot": "\"",
    "amp": "&",
    "lt": "<",
    "gt": ">",
    "nbsp": "\240",
    // FIXME: More...
  ]);
} ("entities_tag_set");

RXML.TagSet rxml_tag_set = class
// This tag set always has the highest priority.
{
  inherit RXML.TagSet;

  string prefix = RXML_NAMESPACE;

  array(RoxenModule) modules;
  // Each element in the imported array is the registered tag set of a
  // parser module. This array contains the corresponding module
  // object.

  void sort_on_priority()
  {
    array(RXML.TagSet) new_imported = imported[..sizeof (imported) - 2];
    array(RoxenModule) new_modules = modules[..sizeof (modules) - 2];
    array(int) priorities = new_modules->query ("_priority", 1);
    priorities = replace (priorities, 0, 4);
    sort (priorities, new_imported, new_modules);
    new_imported = reverse (new_imported) + ({imported[-1]});
    if (equal (imported, new_imported)) return;
    new_modules = reverse (new_modules) + ({modules[-1]});
    imported = new_imported, modules = new_modules;
  }

  void set_modules (array(RoxenModule) _modules)
  // Kludge currently necessary in Pike 7.
  {
    modules = _modules;
  }

  void create (string name, object rxml_object)
  {
    ::create (name);
    imported = ({entities_tag_set});
    modules = ({rxml_object});
  }
} ("rxml_tag_set", this_object());

RXML.Type default_arg_type = RXML.t_text (RXML.PEntCompat);

int parse_html_compat;

class BacktraceFrame
// Only used to get old style tags in the RXML backtraces.
{
  inherit RXML.Frame;
  void create (RXML.Frame _up, string name, mapping(string:string) _args)
  {
    up = _up;
    tag = class {inherit RXML.Tag; string name;}();
    tag->name = name;
    args = _args;
  }
}

array|string call_overridden (array call_to, RXML.PHtml parser,
			      string name, mapping(string:string) args,
			      string content, RequestID id)
{
  mixed tdef, cdef;

  if (sizeof (call_to) > 1 && call_to[1] && call_to[1] != name) // Another tag.
    if (sizeof (call_to) == 3) tdef = parser->tags()[call_to[1]];
    else cdef = parser->containers()[call_to[1]];
  else {			// Same tag.
    mixed curdef = id->misc->__tag_overrider_def || // Yep, ugly..
      (content ? parser->containers()[name] : parser->tags()[name]);
#ifdef DEBUG
    if (!curdef) error ("Can't find tag definition for %s.\n", name);
#endif
    if (array tagdef = parser->get_overridden_low_tag (name, curdef)) {
      [tdef, cdef] = tagdef;
      id->misc->__tag_overrider_def = tdef || cdef;
      if (sizeof (call_to) == 1) call_to = ({1, 0, args, content});
    }
  }

  array|string result;
  if (tdef)			// Call an overridden tag.
    if (stringp (tdef))
      result = ({tdef});
    else if (arrayp (tdef))
      result = tdef[0] (parser, call_to[2] || args, @tdef[1..]);
    else
      result = tdef (parser, call_to[2] || args);
  else if (cdef)		// Call an overridden container.
    if (stringp (cdef))
      result = ({cdef});
    else if (arrayp (cdef))
      result = cdef[0] (parser, call_to[2] || args, call_to[3] || content, @cdef[1..]);
    else
      result = cdef (parser, call_to[2] || args, call_to[3] || content);
  else				// Nothing is overridden.
    if (sizeof (call_to) == 3)
      result = ({make_tag (call_to[1] || name, call_to[2] || args)});
    else if (sizeof (call_to) == 4)
      result = ({make_container (call_to[1] || name, call_to[2] || args,
				 call_to[3] || content)});
    else
      // No changes to args or content, but we can't return 0 because
      // we might have parsed entities in the args mapping.
      if (content)
	result = ({make_container (name, args, content)});
      else
	result = ({make_tag (name, args)});

  m_delete (id->misc, "__tag_overrider_def");
  return result;
}

array|string call_tag(RXML.PHtml parser, mapping args, string|function rf)
{
  RXML.Context ctx = parser->context;
  RequestID id = ctx->id;
  string tag = parser->tag_name();
  id->misc->line = parser->at_line();

  if(args->help)
  {
    TRACE_ENTER("tag &lt;"+tag+" help&gt", rf);
    string h = find_tag_doc(tag, id);
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

  mixed result;
  RXML.Frame orig_frame = ctx->frame;
  ctx->frame = BacktraceFrame (orig_frame, tag, args);
  mixed err = catch {
    foreach (indices (args), string arg)
      // Parse variable entities in arguments.
      args[arg] = default_arg_type->eval (args[arg], 0, rxml_tag_set, parser, 1);
    result=rf(tag,args,id,parser->_source_file,parser->_defines);
  };
  ctx->frame = orig_frame;
  if (err) throw (err);

  TRACE_LEAVE("");

  if(args->noparse && stringp(result)) return ({ result });
  if (arrayp (result) && sizeof (result) && result[0] == 1)
    return call_overridden (result, parser, tag, args, 0, id);

  return result || ({make_tag (tag, args)});
}

array(string)|string call_container(RXML.PHtml parser, mapping args,
				    string contents, string|function rf)
{
  RXML.Context ctx = parser->context;
  RequestID id = ctx->id;
  string tag = parser->tag_name();
  id->misc->line = parser->at_line();

  if(args->help)
  {
    TRACE_ENTER("container &lt;"+tag+" help&gt", rf);
    string h = find_tag_doc(tag, id);
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

  mixed result;
  RXML.Frame orig_frame = ctx->frame;
  ctx->frame = BacktraceFrame (orig_frame, tag, args);
  mixed err = catch {
    foreach (indices (args), string arg)
      // Parse variable entities in arguments.
      args[arg] = default_arg_type->eval (args[arg], 0, rxml_tag_set, parser, 1);
    result=rf(tag,args,contents,id,parser->_source_file,parser->_defines);
  };
  ctx->frame = orig_frame;
  if (err) throw (err);

  TRACE_LEAVE("");

  if(args->noparse && stringp(result)) return ({ result });
  if (arrayp (result) && sizeof (result) && result[0] == 1)
    return call_overridden (result, parser, tag, args, contents, id);

  return result || ({make_container (tag, args, contents)});
}

string do_parse(string to_parse, RequestID id,
                Stdio.File file, mapping defines)
{
  RXML.PHtml parent_parser = id->misc->_parser;	// Don't count on that this exists.
  RXML.PHtml parser;
  RXML.Context ctx;

  if (parent_parser && (ctx = parent_parser->context) && ctx->id == id) {
#ifdef DEBUG
    if (ctx != RXML.get_context())
      error ("Odd context switch."
#ifdef OBJ_COUNT_DEBUG
	     " Expected %O, got %O.\n", RXML.get_context(), ctx
#else
	     "\n"
#endif
	    );
#endif
    parser = RXML.t_html (RXML.PHtmlCompat)->get_parser (ctx);
    parser->_parent = parent_parser;
  }
  else {
    parser = rxml_tag_set (RXML.t_html (RXML.PHtmlCompat), id);
#ifdef OLD_RXML_COMPAT
    parser->context->add_scope("_", id->variables);
#endif
    parent_parser = 0;
  }
  parser->parse_html_compat (parse_html_compat);
  id->misc->_parser = parser;
  parser->_source_file = file;
  parser->_defines = defines;

#ifdef TAGMAP_COMPAT
  if (id->misc->_tags) {
    parser->tagmap_tags = id->misc->_tags;
    parser->tagmap_containers = id->misc->_containers;
  }
  else {
    id->misc->_tags = parser->tagmap_tags;
    id->misc->_containers = parser->tagmap_containers;
  }
#endif

  if (mixed err = catch {
    if (parent_parser)
      parser->finish (to_parse);
    else
      parser->write_end (to_parse);
    string result = parser->eval();
    parser->_defines = 0;
    id->misc->_parser = parent_parser;
    return result;
  }) {
    parser->_defines = 0;
    id->misc->_parser = parent_parser;
    if (objectp (err) && err->thrown_at_unwind)
      error ("Can't handle RXML parser unwinding in "
	     "compatibility mode (error=%O).\n", err);
    else throw (err);
  }
}

class GenericTag {
  inherit RXML.Tag;
  string name;
  int flags;
  function _do_return;
  array(RXML.Type) result_types = ({ RXML.t_text(RXML.PHtml) });

  void create(string _name, int _flags,
	      function __do_return) {
    name=_name;
    flags=_flags;
    _do_return=__do_return;
    if(flags&RXML.FLAG_DONT_PREPARSE)
      content_type = RXML.t_text;
  }

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      if(_do_return) {
	if(flags&RXML.FLAG_POSTPARSE)
	  return ({ _do_return(name, args, content, id, this_object()) });
	else
	  result=_do_return(name, args, content, id, this_object());
      }
    }
  }
}

void add_parse_module (RoxenModule mod)
{
  RXML.TagSet tag_set =
    mod->query_tag_set ? mod->query_tag_set() : RXML.TagSet (sprintf ("%O", mod));
  mapping(string:mixed) defs;

  if (mod->query_tag_callers &&
      mappingp (defs = mod->query_tag_callers()) &&
      sizeof (defs))
    tag_set->low_tags =
      mkmapping (indices (defs),
		 Array.transpose (({({call_tag}) * sizeof (defs),
				    values (defs)})));

  if (mod->query_container_callers &&
      mappingp (defs = mod->query_container_callers()) &&
      sizeof (defs))
    tag_set->low_containers =
      mkmapping (indices (defs),
		 Array.transpose (({({call_container}) * sizeof (defs),
				    values (defs)})));

  if (mod->query_simple_tag_callers &&
      mappingp (defs = mod->query_simple_tag_callers()) &&
      sizeof (defs))
    tag_set->add_tags(Array.map(indices(defs),
				lambda(string tag){ return GenericTag(tag, @defs[tag]); }));

  if (search (rxml_tag_set->imported, tag_set) < 0) {
    rxml_tag_set->set_modules (rxml_tag_set->modules + ({mod}));
    array(RXML.Tag) foo = rxml_tag_set->imported;
    rxml_tag_set->imported = foo + ({tag_set});
    remove_call_out (rxml_tag_set->sort_on_priority);
    call_out (rxml_tag_set->sort_on_priority, 0);
  }
}

void remove_parse_module (RoxenModule mod)
{
  int i = search (rxml_tag_set->modules, mod);
  if (i >= 0) {
    RXML.TagSet tag_set = rxml_tag_set->imported[i];
    rxml_tag_set->set_modules (
      rxml_tag_set->modules[..i - 1] + rxml_tag_set->modules[i + 1..]);
    rxml_tag_set->imported =
      rxml_tag_set->imported[..i - 1] + rxml_tag_set->imported[i + 1..];
    if (tag_set) destruct (tag_set);
  }
}


string call_user_tag(RXML.PHtml parser, mapping args)
{
  RequestID id = parser->context->id;
  string tag = parser->tag_name();
  id->misc->line = parser->at_line();
  args = id->misc->defaults[tag]|args;
  TRACE_ENTER("user defined tag &lt;"+tag+"&gt;", call_user_tag);
  array replace_from = map(indices(args),make_entity)+({"#args#"});
  array replace_to = values(args)+({make_tag_attributes( args  ) });

  string r = replace(id->misc->tags[ tag ], replace_from, replace_to);
  TRACE_LEAVE("");
  return r;
}

array|string call_user_container(RXML.PHtml parser, mapping args, string contents)
{
  RequestID id = parser->context->id;
  string tag = parser->tag_name();
  if(!id->misc->defaults[tag] && id->misc->defaults[""])
    tag = "";
  id->misc->line = parser->at_line();
  args = id->misc->defaults[tag]|args;
  if( args->preparse )
  {
    if( id->misc->do_not_recurse_for_ever_please++ > 10000 )
      error("Too deep Recursion.\n");
    contents = parse_rxml(contents, id);
    id->misc->do_not_recurse_for_ever_please--;
  }
  if(args->trimwhites)
  {
    sscanf(contents, "%*[ \t\n\r]%s", contents);
    contents = reverse(contents);
    sscanf(contents, "%*[ \t\n\r]%s", contents);
    contents = reverse(contents);
  }

  TRACE_ENTER("user defined container &lt;"+tag+"&gt", call_user_container);
  id->misc->do_not_recurse_for_ever_please++;
  array i = indices( args );
  array v = values( args );
  array replace_from = map(i,make_entity)+({"#args#", "<contents>"});
  array replace_to = v + ({make_tag_attributes( args  ), contents });
  string r = replace(id->misc->containers[ tag ], replace_from, replace_to);
  TRACE_LEAVE("");
  if( args->noparse ) return ({ r });
  return r;
}

#define _stat defines[" _stat"]
#define _error defines[" _error"]
#define _extra_heads defines[" _extra_heads"]
#define _rettext defines[" _rettext"]
#define _ok     defines[" _ok"]

string parse_rxml(string what, RequestID id,
		  void|Stdio.File file,
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

  what = do_parse(what, id, file, defines);

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


// ------------------------- RXML Core tags --------------------------

string tag_help(string t, mapping args, RequestID id)
{
  RXML.PHtml parser = rxml_tag_set (RXML.t_html (RXML.PHtmlCompat), id);
  array tags = sort(indices(parser->tags()+parser->containers()))-({"\x266a"});
  string help_for = args->for || id->variables->_r_t_h;
  string ret="<h2>Roxen Interactive RXML Help</h2>";

  if(!help_for)
  {
    string char;
    ret += "<b>Here is a list of all defined tags. Click on the name to "
      "receive more detailed information. All these tags are also availabe "
      "in the \""+RXML_NAMESPACE+"\" namespace.</b><p>\n";
    array tag_links;

    foreach(tags, string tag) {
      if(tag[0..0]!=char) {
	if(tag_links && char!="/") ret+="<h3>"+upper_case(char)+"</h3>\n<p>"+String.implode_nicely(tag_links)+"</p>";
	char=tag[0..0];
	tag_links=({});
      }
      if(tag[0..sizeof(RXML_NAMESPACE)]!=RXML_NAMESPACE+":")
	if(undocumented_tags[tag])
	  tag_links += ({ tag });
	else
	  tag_links += ({ sprintf("<a href=\"%s?_r_t_h=%s\">%s</a>\n",
				  id->not_query, http_encode_url(tag), tag) });
    }

    return ret + "<h3>"+upper_case(char)+"</h3>\n<p>"+String.implode_nicely(tag_links)+"</p>";
  }

  return ret+find_tag_doc(help_for, id);
}

string tag_number(string t, mapping args, RequestID id)
{
  return roxen.language(args->lang||args->language||id->misc->defines->theme_language,
                        args->type||"number")( (int)args->num );
}

private array(string) list_packages()
{
  return filter(((get_dir("../local/rxml_packages")||({}))
                 |(get_dir("../rxml_packages")||({}))),
                lambda( string s ) {
                  return (Stdio.file_size("../local/rxml_packages/"+s)+
                          Stdio.file_size( "../rxml_packages/"+s )) > 0;
                });

}

private string read_package( string p )
{
  string data;
  p = replace(p, ({"/", "\\"}), ({"",""}));
  if(file_stat( "../local/rxml_packages/"+p ))
    catch(data=Stdio.File( "../local/rxml_packages/"+p, "r" )->read());
  if(!data && file_stat( "../rxml_packages/"+p ))
    catch(data=Stdio.File( "../rxml_packages/"+p, "r" )->read());
  return data;
}

private string use_file_doc( string f, string data, RequestID nid, RequestID id )
{
  string res="";
  catch
  {
    string doc = "";
    int help=0; /* If true, all tags support the 'help' argument. */
    sscanf(data, "%*sdoc=\"%s\"", doc);
    sscanf(data, "%*sdoc=%d", help);
    parse_rxml(data, nid);
    res += "<dt><b>"+f+"</b><dd>"+(doc?doc+"<br>":"");
    array tags = indices(nid->misc->tags||({}));
    array containers = indices(nid->misc->containers||({}));
    array ifs = indices(nid->misc->_ifs)- indices(id->misc->_ifs);
    array defines = indices(nid->misc->defines)- indices(id->misc->defines);
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
  return res;
}

string|array tag_use(string tag, mapping m, string c, RequestID id)
{
  mapping res = ([]);
  if(!id->misc->_ifs) id->misc->_ifs=([]);

#define SETUP_NID()                             \
    RequestID nid = id->clone_me();             \
    nid->misc->tags = 0;                        \
    nid->misc->containers = 0;                  \
    nid->misc->defines = ([]);                  \
    nid->misc->_tags = 0;                       \
    nid->misc->_containers = 0;                 \
    nid->misc->defaults = ([]);                 \
    nid->misc->_ifs = ([]);                     \
    nid->misc->_parser = 0;

  if(m->packageinfo)
  {
    string res ="<dl>";
    foreach(list_packages(), string f) {
      SETUP_NID();
      res += use_file_doc( f, read_package( f ), nid, id );
    }
    return ({res+"</dl>"});
  }

  if(!m->file && !m->package)
    return "<use help>";

  if(id->pragma["no-cache"] ||
     !(res=cache_lookup("macrofiles:"+name,(m->file||("pkg!"+m->package)))))
  {
    SETUP_NID();
    res = ([]);
    string foo;
    if(m->file)
      foo = try_get_file( fix_relative(m->file, nid), nid );
    else
      foo = read_package( m->package );

    if(!foo)
      return ({ rxml_error(tag, "Failed to fetch "+(m->file||m->package)+".", id)-"<false>" });

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
    res->_ifs = nid->misc->_ifs - id->misc->_ifs;
    m_delete( res->defines, " _stat" );
    m_delete( res->defines, " _error" );
    m_delete( res->defines, " _extra_heads" );
    m_delete( res->defines, " _rettext" );
    m_delete( res->defines, " _ok" );
    m_delete( res->defines, "line");
    m_delete( res->defines, "sizefmt");
    cache_set("macrofiles:"+name, (m->file || ("pkg!"+m->package)), res);
  }
  id->misc->tags += copy_value(res->tags);
  id->misc->containers += res->containers;
  id->misc->defaults += res->defaults;
  id->misc->defines += copy_value(res->defines);
  id->misc->_tags += res->_tags;
  id->misc->_containers += res->_containers;
  id->misc->_ifs += res->_ifs;

  c = parse_rxml( c, id );
  return ({ c });
}

string tag_define(string tag, mapping m, string str, RequestID id,
                  Stdio.File file, mapping defines)
{
  if(m->variable)
    id->variables[m->variable] = str;
#ifdef OLD_RXML_COMPAT
  else if (m->name) {
    defines[m->name]=str;
    old_rxml_warning(id, "attempt to define name ","variable");
  }
#endif
  else if (m->tag)
  {
    m->tag = lower_case(m->tag);
    string n = m->tag;
    m_delete( m, "tag" );
    if(!id->misc->tags)
      id->misc->tags = ([]);
    if(!id->misc->defaults)
      id->misc->defaults = ([]);
    id->misc->defaults[n] = ([]);

#ifdef OLD_RXML_COMPAT
    // This is not part of RXML 1.4
    foreach( indices(m), string arg )
      if( arg[..7] == "default_" )
      {
	id->misc->defaults[n][arg[8..]] = m[arg];
        old_rxml_warning(id, "define attribute "+arg,"attrib container");
        m_delete( m, arg );
      }
#endif

    str=parse_html(str,([]),(["attrib":
      lambda(string tag, mapping m, string cont, mapping c) {
        if(m->name) id->misc->defaults[n][m->name]=parse_rxml(cont,id);
        return "";
      }
    ]));

    if(m->trimwhites) {
      sscanf(str, "%*[ \t\n\r]%s", str);
      str = reverse(str);
      sscanf(str, "%*[ \t\n\r]%s", str);
      str = reverse(str);
    }

#ifdef OLD_RXML_COMPAT
    id->misc->tags[n] = replace( str, indices(m), values(m) );
#else
    id->misc->tags[n] = str;
#endif
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
    id->misc->defaults[n] = ([]);

#ifdef OLD_RXML_COMPAT
    // This is not part of RXML 1.4
    foreach( indices(m), string arg )
      if( arg[0..7] == "default_" )
      {
	id->misc->defaults[n][arg[8..]] = m[arg];
        old_rxml_warning(id, "define attribute "+arg,"attrib container");
        m_delete( m, arg );
      }
#endif

    str=parse_html(str,([]),(["attrib":
      lambda(string tag, mapping m, string cont, mapping c) {
        if(m->name) id->misc->defaults[n][m->name]=parse_rxml(cont,id);
        return "";
      }
    ]));

    if(m->trimwhites) {
      sscanf(str, "%*[ \t\n\r]%s", str);
      str = reverse(str);
      sscanf(str, "%*[ \t\n\r]%s", str);
      str = reverse(str);
    }

#ifdef OLD_RXML_COMPAT
    id->misc->containers[n] = replace( str, indices(m), values(m) );
#else
    id->misc->containers[n] = str;
#endif
    id->misc->_containers[n] = call_user_container;
  }
  else if (m["if"]) {
    if(!id->misc->_ifs) id->misc->_ifs=([]);
    id->misc->_ifs[ lower_case(m["if"]) ] = UserIf( str );
  }
  else
    return rxml_error(tag, "No tag, variable, if or container specified.", id);

  return "";
}

string tag_undefine(string tag, mapping m, RequestID id,
                    Stdio.File file, mapping defines)
{
  if(m->variable)
    m_delete(id->variables,m->variable);
#ifdef OLD_RXML_COMPAT
  else if (m->name)
    m_delete(defines,m->name);
#endif
  else if (m->tag)
  {
    m_delete(id->misc->tags,m->tag);
    m_delete(id->misc->_tags,m->tag);
  }
  else if (m["if"])
    m_delete(id->misc->_ifs,m["if"]);
  else if (m->container)
  {
    m_delete(id->misc->containers,m->container);
    m_delete(id->misc->_containers,m->container);
  }
  else
    return rxml_error(tag, "No tag, variable, if or container specified.", id);

  return "";
}

class Tracer
{
  inherit "roxenlib";
  string resolv="<ol>";
  int level;

  string _sprintf()
  {
    return "Tracer()";
  }

  mapping et = ([]);
#if efun(gethrvtime)
  mapping et2 = ([]);
#endif

  string module_name(function|RoxenModule m)
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

  void trace_enter_ol(string type, function|RoxenModule module)
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

array(string) tag_trace(string t, mapping args, string c , RequestID id)
{
  NOCACHE();
  Tracer t;
//   if(args->summary)
//     t = SumTracer();
//   else
    t = Tracer();
  function a = id->misc->trace_enter;
  function b = id->misc->trace_leave;
  id->misc->trace_enter = t->trace_enter_ol;
  id->misc->trace_leave = t->trace_leave_ol;
  t->trace_enter_ol( "tag &lt;trace&gt;", tag_trace);
  string r = parse_rxml(c, id);
  id->misc->trace_enter = a;
  id->misc->trace_leave = b;
  return ({r + "<h1>Trace report</h1>"+t->res()+"</ol>"});
}

array(string) tag_noparse(string t, mapping m, string c)
{
  return ({ c });
}

class TagEval {
  inherit RXML.Tag;
  constant name = "eval";
  constant flags = RXML.FLAG_CONTAINER;
  array(RXML.Type) result_types = ({ RXML.t_xml(RXML.PHtml), RXML.t_html(RXML.PHtml) });
  class Frame {
    inherit RXML.Frame;
    array do_return(RequestID id) {
      return ({ content });
    }
  }
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
  if(m["case"])
    switch(lower_case(m["case"])) {
    case "lower": return lower_case(c);
    case "upper": return upper_case(c);
    case "capitalize": return capitalize(c);
    }

#ifdef OLD_RXML_COMPAT
  if(m->lower) {
    c = lower_case(c);
    old_rxml_warning(id, "attribute lower","case=lower");
  }
  if(m->upper) {
    c = upper_case(c);
    old_rxml_warning(id, "attribute upper","case=upper");
  }
  if(m->capitalize){
    c = capitalize(c);
    old_rxml_warning(id, "attribute capitalize","case=capitalize");
  }
#endif
  return c;
}

#define LAST_IF_TRUE id->misc->defines[" _ok"]

class TagIf {
  inherit RXML.Tag;
  constant name = "if";
  constant flags = RXML.FLAG_CONTAINER | RXML.FLAG_SOCKET_TAG;

  class Frame {
    inherit RXML.Frame;
    int do_iterate = 0;

    array do_enter(RequestID id) {
      int res, and = 1;

      if(args->not) {
	m_delete(args, "not");
	do_enter(id);
	do_iterate=!do_iterate;
	return 0;
      }

      if(args->or)  { and = 0; m_delete( args, "or" ); }
      if(args->and) { and = 1; m_delete( args, "and" ); }
      mapping plugins=get_plugins();
      if(id->misc->_ifs) plugins+=id->misc->_ifs;
      array possible = indices(args) & indices(plugins);

      int last=0;
      foreach(possible, string s) {
	res = plugins[ s ]( args[s], id, args, and, s );
	LAST_IF_TRUE=res;
	last=res;
	if(res) {
	  if(!and) {
	    do_iterate = 1;
	    return 0;
	  }
	}
	else
	  if(and) return 0;
      }
      if(last) do_iterate=1;
      return 0;
    }

    array do_return(RequestID id) {
      if(do_iterate) {
	result=content;
	LAST_IF_TRUE=1;
      }
      else
	LAST_IF_TRUE=0;
    }

  }
}

string tag_else( string t, mapping m, string c, RequestID id )
{
  if(!LAST_IF_TRUE) return c;
  return "";
}

string tag_then( string t, mapping m, string c, RequestID id )
{
  if(LAST_IF_TRUE) return c;
  return "";
}

string|array tag_elseif( string t, mapping m, string c, RequestID id )
{
  if(!LAST_IF_TRUE) return ({1, "if", m, c});
  return "";
}

string tag_true( string t, mapping m, RequestID id )
{
  LAST_IF_TRUE = 1;
  return "";
}

string tag_false( string t, mapping m, RequestID id )
{
  LAST_IF_TRUE = 0;
  return "";
}

private void internal_tag_case( string t, mapping m, string c, int l, RequestID id,
				mapping res )
{
  if(res->res) return;
  LAST_IF_TRUE = 0;
  //  tag_if( t, m, c, id );
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

class TagEmit {
  inherit RXML.Tag;
  constant name = "emit";
  constant flags = RXML.FLAG_CONTAINER | RXML.FLAG_SOCKET_TAG;
  constant req_arg_types = (["source":RXML.t_text]);

  class Frame {
    inherit RXML.Frame;
    string scope_name;
    mapping vars=(["counter":0]);

    object plugin;
    array(mapping(string:mixed))|function res;

    array do_enter(RequestID id) {
      if(!(plugin=get_plugins()[args->source])) rxml_error("Source not present.");
      scope_name=args->scope||args->source;
      res=plugin->get_dataset(args, id);
      if(arrayp(res)) {
	if(args["do-once"] && sizeof(res)==0) res=({ ([]) });

	do_iterate=array_iterate;
	LAST_IF_TRUE = 1;
	return 0;
      }
      if(functionp(res)) {
	do_iterate=function_iterate;
	LAST_IF_TRUE = 1;
	return 0;
      }
      rxml_fatal("Wrong return type from emit source plugin.");
    }

    function do_iterate;

    int function_iterate(RequestID id) {
      vars=res(args, id);
      return mappingp(vars);
    }

    int array_iterate(RequestID id) {
      int counter=vars->counter;
      if(counter>=sizeof(res)) return 0;
      vars=res[counter++];
      vars->counter=counter;
      return 1;
    }


  }
}

mapping query_container_callers()
{
  return ([
    "comment":lambda(){ return ""; },
    "else":tag_else,
    "then":tag_then,
    "elseif":tag_elseif,
    "elif":tag_elseif,
    "noparse":tag_noparse,
    "nooutput":tag_nooutput,
    "case":tag_case,
    "cond":tag_cond,
    "strlen":tag_strlen,
    "define":tag_define,
    "trace":tag_trace,
    "use":tag_use,
  ]);
}

mapping query_tag_callers()
{
  return ([
    "true":tag_true,
    "false":tag_false,
    "number":tag_number,
    "undefine":tag_undefine,
    "help": tag_help
  ]);
}

RXML.TagSet query_tag_set()
{
  // Note: By putting the tags in rxml_tag_set, they will always have
  // the highest priority.
  rxml_tag_set->add_tags (filter (rows (this_object(),
					glob ("Tag*", indices (this_object()))),
				  functionp)());
  return entities_tag_set;
}


// ---------------------------- If callers -------------------------------

class UserIf
{
  string rxml_code;
  void create( string what )
  {
    rxml_code = what;
  }

  string _sprintf()
  {
    return "UserIf("+rxml_code+")";
  }

  int `()( string ind, RequestID id, mapping args, int and, string a )
  {
    int otruth, res;
    string tmp;

    TRACE_ENTER("user defined if argument &lt;"+a+"&gt;", UserIf);
    otruth = LAST_IF_TRUE;
    LAST_IF_TRUE = -2;
    tmp = parse_rxml(rxml_code, id );
    res = LAST_IF_TRUE;
    LAST_IF_TRUE = otruth;

    TRACE_LEAVE("");

    if(ind==a && res!=-2)
      return res;

    return (ind==tmp);
  }
}

class IfIs
{
  inherit RXML.Tag;
  constant name = "if";

  constant cache = 0;
  function source;
  function `() = match_in_map;

  int match_in_string( string value, RequestID id )
  {
    string is;
    if(!cache) CACHE(0);
    sscanf( value, "%s is %s", value, is );
    if(!is) return strlen(value);
    value = lower_case( value );
    is = lower_case( is );
    return ((is==value)||glob(is,value)||
            sizeof(filter( is/",", glob, value )));
  }

  int match_in_map( string value, RequestID id )
  {
    string is,var;
    if(!cache) CACHE(0);
    array arr=value/" ";
    var=source(id, arr[0]);
    if(sizeof(arr)<2 || !var) return !!var;
    var = lower_case( (var+"") );
    if(sizeof(arr)==1) return !!var;
    is=lower_case(arr[2..]*" ");
    if(arr[1]=="==" || arr[1]=="=" || arr[1]=="is")
      return ((is==var)||glob(is,var)||
            sizeof(filter( is/",", glob, var )));
    if(arr[1]=="!=") return (is!=var);
    if(arr[1]=="<") return ((int)var<(int)is);
    if(arr[1]==">") return ((int)var>(int)is);
    value=source(id, value);
    return !!value;
  }
}

class IfMatch
{
  inherit RXML.Tag;
  constant name = "if";

  constant cache = 0;
  function source;

  int `()( string is, RequestID id ) {
    array|string value=source(id);
    if(!cache) CACHE(0);
    if(!value) return 0;
    if(arrayp(value)) value=value*" ";
    value = lower_case( value );
    is = lower_case( "*"+is+"*" );
    return (glob(is,value)||sizeof(filter( is/",", glob, value )));
  }
}

class TagIfDate {
  inherit RXML.Tag;
  constant name = "if";
  constant plugin_name = "date";

  int `() (string date, RequestID id, mapping m) {
    CACHE(60); // One minute accuracy is probably good enough...
    int a, b;
    mapping c;
    c=localtime(time(1));
    b=(int)sprintf("%02d%02d%02d", c->year, c->mon + 1, c->mday);
    a=(int)replace(date,"-","");
    if(a > 999999) a -= 19000000;
    else if(a < 901201) a += 10000000;
    if(m->inclusive || !(m->before || m->after) && a==b)
      return 1;
    if(m->before && a>b)
      return 1;
    else if(m->after && a<b)
      return 1;
  }
}

class TagIfTime {
  inherit RXML.Tag;
  constant name = "if";
  constant plugin_name = "time";

  int `() (string ti, RequestID id, mapping m) {
    CACHE(time(1)%60); // minute resolution...

    int tok, a, b, d;
    mapping c;
    c=localtime(time());

    b=(int)sprintf("%02d%02d", c->hour, c->min);
    a=(int)replace(ti,":","");

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
}

class TagIfUser {
  inherit RXML.Tag;
  constant name = "if";
  constant plugin_name = "user";

  int `() (string u, RequestID id, mapping m) {
    if(!id->auth)
      return 0;
    NOCACHE();
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

  private int match_user(array u, string user, string f, int wwwfile, RequestID id) {
    string s, pass;
    if(u[1]!=user)
      return 0;
    if(!wwwfile)
      s=Stdio.read_bytes(f);
    else
      s=id->conf->try_get_file(fix_relative(f,id), id);
    return ((pass=simple_parse_users_file(s, u[1])) &&
	    (u[0] || match_passwd(u[2], pass)));
  }

  private int match_passwd(string try, string org) {
    if(!strlen(org)) return 1;
    if(crypt(try, org)) return 1;
  }

  private string simple_parse_users_file(string file, string u) {
    if(!file) return 0;
    foreach(file/"\n", string line)
      {
	array(string) arr = line/":";
	if (arr[0] == u && sizeof(arr) > 1)
	  return(arr[1]);
      }
  }
}

class TagIfGroup {
  inherit RXML.Tag;
  constant name = "if";
  constant plugin_name = "group";

  int `() (string u, RequestID id, mapping m) {
    if( !id->auth )
      return 0;
    NOCACHE();
    return ((m->groupfile && sizeof(m->groupfile))
	    && group_member(id->auth, m->group, m->groupfile, id));
  }

  private int group_member(array auth, string group, string groupfile, RequestID id) {
    if(!auth)
      return 0; // No auth sent

    string s;
    catch { s = Stdio.read_bytes(groupfile); };

    if (!s)
      s = id->conf->try_get_file( fix_relative( groupfile, id), id );

    if (!s) return 0;

    s = replace(s,({" ","\t","\r" }), ({"","","" }));

    multiset(string) members = simple_parse_group_file(s, group);
    return members[auth[1]];
  }

  private multiset simple_parse_group_file(string file, string g) {
    multiset res = (<>);
    array(string) arr ;
    foreach(file/"\n", string line)
      if(sizeof(arr = line/":")>1 && (arr[0] == g))
	res += (< @arr[-1]/"," >);
    return res;
  }
}

class TagIfExists {
  inherit RXML.Tag;
  constant name = "if";
  constant plugin_name = "exists";

  int `() (string u, RequestID id) {
    CACHE(5);
    return id->conf->is_file(fix_relative(u, id), id);
  }
}

class TagIfTrue {
  inherit RXML.Tag;
  constant name = "if";
  constant plugin_name = "true";

  int `() (string u, RequestID id) {
    return LAST_IF_TRUE;
  }
}

class TagIfFalse {
  inherit RXML.Tag;
  constant name = "if";
  constant plugin_name = "false";

  int `() (string u, RequestID id) {
    return !LAST_IF_TRUE;
  }
}

class TagIfAccept {
  inherit IfMatch;
  constant plugin_name = "accept";
  array source(RequestID id) {
    return id->misc->accept;
  }
}

class TagIfConfig {
  inherit IfIs;
  constant plugin_name = "config";
  string source(RequestID id, string s) {
    return id->config[s];
  }
}

class TagIfCookie {
  inherit IfIs;
  constant plugin_name = "cookie";
  string source(RequestID id, string s) {
    return id->cookies[s];
  }
}

class TagIfClient {
  inherit IfMatch;
  constant plugin_name = "client";
  array source(RequestID id) {
    return id->client;
  }
}

class TagIfDefined {
  inherit IfIs;
  constant plugin_name = "defined";
  constant cache = 1;
  string source(RequestID id, string s) {
    return id->misc[s];
  }
}

class TagIfDomain {
  inherit IfMatch;
  constant plugin_name = "domain";
  string source(RequestID id) {
    return id->host;
  }
}

class TagIfHost {
  inherit IfMatch;
  constant plugin_name = "host";
  string source(RequestID id) {
    return id->remoteaddr;
  }
}

class TagIfIP {
  inherit IfMatch;
  constant plugin_name = "ip";
  string source(RequestID id) {
    return id->remoteaddr;
  }
}

class TagIfLanguage {
  inherit IfMatch;
  constant plugin_name = "language";
  array source(RequestID id) {
    return id->pref_languages->get_languages();
  }
}

class TagIfMatch {
  inherit IfIs;
  constant plugin_name = "match";
  string source(RequestID id, string s) {
    return s;
  }
}

class TagIfName {
  inherit TagIfClient;
  constant plugin_name = "name";
}

class TagIfPragma {
  inherit IfIs;
  constant plugin_name = "pragma";
  string source(RequestID id, string s) {
    return id->pragma[s];
  }
}

class TagIfPrestate {
  inherit IfIs;
  constant plugin_name = "prestate";
  constant cache = 1;
  string source(RequestID id, string s) {
    return id->prestate[s];
  }
}

class TagIfReferrer {
  inherit IfMatch;
  constant plugin_name = "referrer";
  array source(RequestID id) {
    return id->referer;
  }
}

class TagIfSupports {
  inherit IfIs;
  constant plugin_name = "supports";
  string source(RequestID id, string s) {
    return id->supports[s];
  }
}

class TagIfVariable {
  inherit IfIs;
  constant plugin_name = "variable";
  constant cache = 1;
  string source(RequestID id, string s) {
      return (string)RXML.get_context()->user_get_var(s);
  }
}

class TagIfClientvar {
  inherit IfIs;
  constant plugin_name = "clientvar";
  string source(RequestID id, string s) {
    return id->client_var[s];
  }
}

#endif

// ------------------------ Documentation -----------------------------

mapping tagdocumentation() {
  Stdio.File file=Stdio.File();
  if(!file->open(__FILE__,"r")) return 0;
  return compile_string("#define manual\n"+file->read())->tagdoc;
}

#ifdef manual
constant tagdoc=([
"case":#"<desc cont>
 Alters the case of the contents.
</desc>

<attr name=lower>
 Changes all upper case letters to lower case.
</attr>

<attr name=upper>
 Changes all lower case letters to upper case.
</attr>

<attr name=capitalize>
 Capitalizes the first letter in the content.
</attr>",
"cond":#"<desc>

</desc>",

"comment":#"<desc cont>
 The enclosed text will be removed from the document. The difference
 from a normal SGML (HTML/XML) comment is that the text is removed
 from the document, and can not be seen even with view source. Another
 difference is that any RXML tags inside this container will not be
 parsed.
</desc>",

"define":#"<desc cont>
 Defines variables, tags, containers, if-callers. One, and only one,
 attribute must be set.
</desc>

<attr name=variable value=name>
 Sets the value of the variable to the contents of the container.
</attr>

<attr name=tag value=name>
 Defines a tag that outputs the contents of the container.
</attr>

<attr name=container value=name>
 Defines a container that outputs the contents of the container.
</attr>

<attr name=if value=name>
 Defines an if-caller that compares something with the contents of the
 container.
</attr>

<attr name=trimwhites>
 Trim all white space characters fromt the begining and the end of the contents.
</attr>


 When defining a container the tag <tag>contents</tag> can be used to
 insert the contents of the defined container.

 <p>When defining a tag or a container the container <tag>attrib</tag>
 can be used to define default values of the attributes that the
 tag/container can have. The attrib container has the attribute
 attrib=name, and sets the default value of the attribute indicated
 with attrib=name to the contents of the attrib container. The
 attribute values can be accessed with enteties such as &amp;name;</p>",

"elif":#"<desc cont>
 Shows its content if the truth-value is false and the criterions in
 its attributes are met. Uses the same syntax as <tag><ref
 type=cont>if</ref><tag>. Sets the truth-value in the same way as if.
</desc>",

"else":#"<desc cont>
 Show the contents if the previous <tag><ref type=cont>if</ref></tag>
 tag didn't, or if there was a <tag><ref type=tag>false</ref></tag>
 above. The result is undefined if there has been no <tag><ref
 type=cont>if</ref></tag>, <true> or <tag><ref
 type=tag>false</ref></tag> tag above.
</desc>",

"elseif":#"<desc cont>
 Same as the <tag><ref type=cont>if</ref></tag>, but it will only
 evaluate if the previous <tag><ref type=cont>if</ref></tag> tag
 returned false.
</desc>",

"false":#"<desc tag>
 Internal tag used to set the return value of <tag><ref
 type=cont>if</ref></tag> tags. It will ensure that the next <tag><ref
 type=cont>else</ref></tag> tag will show its contents. It can be
 useful if you are writing your own <tag><ref type=cont>if</ref></tag>
 lookalike tag.
</desc>",

"help":#"<desc tag>
 Gives help texts for tags. If given no arguments, it will list all
 available tags.
</desc>

<attr name=for value=tag>
 Gives the help text for that tag.
</attr>

<ex>help for=modified</ex>",

"if":#"<desc cont>
 <tag><ref type=cont>if</ref></tag> is used to conditionally show its
 contents. <tag><ref type=cont>else</ref></tag>, <tag><ref
 type=cont>elif</ref></tag> or <tag><ref type=cont>elseif</ref></tag>
 can be used to suggest alternative content. It is possible to use
 glob patterns in almost all attributes, where * means match zero or
 more characters while ? matches one character. * Thus t*f?? will
 match trainfoo as well as * tfoo but not trainfork or tfo.
</desc>

<attr name=not>
 Inverts the result (true->false, false->true).
</attr>
<attr name=or>
 If any criterion is met the result is true.
</attr>

<attr name=and>
 If all criterions are met the result is true. And is default.
</attr>


 if-caller
 In the rxml.pike file the main if functionality is defined. There are
 two main types of if callers defined in rxml.pike,\"IfIs\" and \"IfMatch\". If the if caller is of an IfMatch type the if statement will be
 matched as a glob, i.e. * is considered a multicharacter wildcard.
 E.g. <tag><ref type=cont>if ip=\"130.236.*\"</ref></tag>Your domain is liu.se<tag><ref type=cont>/if</ref></tag>.

 If the if caller is of an IfIs type the if statement will be compared
 with one of the following operators is, =, ==, !=, &lt; and &gt. The
 operators is, = and == are the same. E.g. <tag><ref type=cont>if
 variable=\"x &gt; 5\"</ref></tag>More than one hand<tag><ref type=cont/if</ref></tag>",

"if#true":#"<desc plugin>
 This will always be true if the truth value is set to be true.
 Equivalent with <tag><ref type=cont>then</ref></tag>.
</desc>",

"if#false":#"<desc plugin>
 This will always be true if the truth value is set to be false.
 Equivalent with <tag><ref type=cont>else</ref></tag>.
</desc>",

"if#accept":#"<desc plugin>
 Returns true is the browser accept certain content types as specified
 by it's Accept-header, for example image/jpeg or text/html. If
 browser states that it accepts */* that is not taken in to account as
 this is always untrue. Accept is an IfMatch if caller.
</desc>",

"if#config":#"<desc plugin>
 Has the config been set by use of the <tag><ref
 type=cont>aconf</ref></tag> tag? (Config is an IfIs if caller,
 although that functionality does not apply here.).
</desc>",

"if#cookie":#"<desc plugin>
 Does the cookie exist and if a value is given, does it contain that
 value? Cookie is av IfIs if caller.
</desc>",

"if#client":#"<desc plugin>
 Compares the user agent string with a pattern. Client and name is an
 IfMatch if caller.
</desc>",

"if#date":#"<desc plugin>
 Is the date yyyymmdd? The attributes before, after and inclusive
 modifies the behavior.
</desc>

<attr name=after>

</attr>

<attr name=before>

</attr>

<attr name=inclusive>

</attr>",

"if#defined":#"<desc plugin>
 Tests if a certain define is defined? Defined is an IfIs if caller.
</desc>",

"if#domain":#"<desc plugin>
 Does the user'\s computer'\s DNS name match any of the patterns? Note
 that domain names are resolved asynchronously, and the the first time
 someone accesses a page, the domain name will probably not have been
 resolved. Domain is an IfMatch if caller.
</desc>",

"if#exists":#"<desc plugin>
 Returns true if the file path exists. If path does not begin with /,
 it is assumed to be a URL relative to the directory containing the page
 with the <tag><ref type=cont>if</ref></tag>-statement.
</desc>",

"if#expr":#"<desc plugin>
 Evaluates expressions. The following characters may be used: \"1, 2,
 3, 4, 5, 6, 7, 8, 9, x, a, b, c, d, e, f, n, t, \, X. A, B, C, D, E,
 F, l, o, &lt;, &gt;, =, 0, -, +, /, %, &, |, (, )\".
</desc>",

"if#group":#"<desc plugin>
 Checks if the current user is a member of the group according
 the groupfile.
</desc>",

"if#host and ip":#"<desc plugin>
 Does the users computers IP address match any of the patterns? Host and
 ip are IfMatch if callers.
</desc>",

"if#language":#"<desc plugin>
 Does the client prefer one of the languages listed, as specified by the
 Accept-Language header? Language is an IfMatch if caller.
</desc>",

"if#match":#"<desc plugin>
 Does the string match one of the patterns? Match is an IfMatch if caller.
</desc>",

"if#pragma":#"<desc plugin>
 Compares the pragma with a string. Pragma is an IfIs if caller.
</desc>",

"if#prestate":#"<desc plugin>
 Are all of the specified prestate options present in the URL? Prestate is
 an IfIs if caller.
</desc>",

"if#referrer":#"<desc plugin>
 Does the referrer header match any of the patterns? Referrer is an IfMatch
 if caller.
</desc>",

"if#supports":#"<desc plugin>
 Does the browser support this feature? Supports is an IfIs if caller.
</desc>

<attr name=activex>
  The browser handles active-X contents.
</attr>

<attr name=align>
 The browser supports the align attribute in its tags.
</attr>

<attr name=autogunzip>
 The browser can decode a gunzipped file on the fly.
</attr>

<attr name=backgrounds>
 The browser supports backgrounds according to the HTML3 specifications.
</attr>

<attr name=bigsmall>
 The browser supports the <tag>big</tag> and <tag>small</tag> tags.
</attr>

<attr name=center>
 The browser supports the <tag>center</tag> tag.
</attr>

<attr name=cookies>
 The browser can receive cookies.
</attr>

<attr name=divisions>
 The browser supports <tag>div align=...</tag>.
</attr>

<attr name=div>
 Same as divisions.
</attr>

<attr name=epsinline>
 The browser can show encapsulated postscript files inline.
</attr>

<attr name=font>
 The browser supports <tag>font size=num</tag>.
</attr>

<attr name=fontcolor>
 The browser can change color of individual characters.
</attr>

<attr name=fonttype>
 The browser can set the font.
</attr>

<attr name=forms>
 The browser supports forms according to the HTML 2.0 and 3.0
 specifications.
</attr>

<attr name=frames>
 The browser supports frames.
</attr>

<attr name=gifinline>
 The browser can show GIF images inlined.
</attr>

<attr name=html>
 This is a HTML browser (as opposed to e.g. a WAP browser).
</attr>

<attr name=imagealign>
 The browser supports align=left and align=right in images.
</attr>

<attr name=images>
 The browser can display images.
</attr>

<attr name=java>
 The browser supports Java applets.
</attr>

<attr name=javascript>
 The browser supports Java Scripts.
</attr>

<attr name=jpeginline>
 The browser can show JPEG images inlined.
</attr>

<attr name=mailto>
 The browser supports mailto URLs.
</attr>

<attr name=math>
 The <tag>math</tag> tag is correctly displayed by the browser.
</attr>

<attr name=msie>
 This is a Microsoft Internet Explorer browser.
</attr>

<attr name=netscape_javascript>
 The browser needs netscape styled javascript.
</attr>

<attr name=phone>
 The client is a phone.
</attr>

<attr name=pjpeginline>
 The browser can handle progressive JPEG images, .pjpeg, inline.
</attr>

<attr name=pnginline>
 The browser can handle PNG images inlined.
</attr>

<attr name=pull>
 The browser handles Client Pull.
</attr>

<attr name=push>
 The browser handles Server Push.
</attr>

<attr name=requests_are_utf8_encoded>
 The requests are UTF8 encoded.
</attr>

<attr name=ssl>
 The browser handles secure sockets layer.
</attr>

<attr name=stylesheets>
 The browser supports stylesheets.
</attr>

<attr name=supsub>
 The browser handles <tag>sup</tag> and <tag>sub</tag> tags correctly.
</attr>

<attr name=tables>
 The browser handles tables according to the HTML3.0 specification.
</attr>

<attr name=tablecolor>
 It is possible to set the background color in the browser.
</attr>

<attr name=tableimages>
 It is possible to set a backgroud image in a table in the browser.
</attr>

<attr name=unknown>
  The browser is not known, hence the supports classes can not be trusted.
</attr>

<attr name=vrml>
 The browser supports VRML
</attr>

<attr name=wbmp0>
 The browser supports Wireless Bitmap Picture Format, type 0.
</attr>

<attr name=wml1.0>
 The browser supports Wireless Markup Language 1.0.
</attr>

<attr name=wml1.1>
 The browser supports Wireless Markup Language 1.1.
</attr>",

"if#time":#"<desc plugin>
 Is the date ttmm? The attributes before, after and inclusive modifies
 the behavior. The attributes are used in the same fashion as with the
 date plugin.
</desc>",

"if#user":#"<desc plugin>
 Has the user been authenticated as one of these users? If any is given as
 argument, any authenticated user will do.
</desc>",

"if#variable":#"<desc plugin>
 Does the variable exist and, optionally, does it's content match the pattern?
 Variable is an IfIs plugin.
</desc>",

"if#clientvar":#"<desc plugin>

 The request really comes from a search robot, not an actual browser.

 Examples of robots are: architex, backrub, checkbot, fast, freecrawl,
 passagen, gcreep, googlebot, harvest, alexa, infoseek, intraseek,
 lycos, webinfo, roxen, altavista, scout, hotbot, url-minder,
 webcrawler, wget, xenu, yahoo, unknown. For more information search
 in the &lt;roxen-dir&gt;/server/etc/supports file.</p>

 Width - The presentation area width in pixels.
 Height - The presentation area height in pixels.

</desc>",

"nooutput":#"<desc cont>
 The contents will not be sent through to the page. Side effects, for
 example sending queries to databases, will take effect.
</desc>",
"noparse":#"<desc cont>
 The contents of this container tag won't be RXML parsed.
</desc>",
"number":#"<desc tag>
 Prints a number as a word.
</desc>

<attr name=num value=number>
 Print this number.
</attr>

<attr name=language value=ca, es_CA, hr, cs, nl, en, fi, fr, de, hu,
it, jp, mi, no, pt, ru, sr, si, es, sv>
 The language to use. Available languages are ca, es_CA (Catala), hr
 (Croatian), cs (Czech), nl (Dutch), en (English), fi (Finnish), fr
 (French), de (German), hu (Hungarian), it (Italian), jp (Japanese),
 mi (Maori), no (Norwegian), pt (Portuguese), ru (Russian), sr
 (Serbian), si (Slovenian), es (Spanish) and sv (Swedish).
</attr>

<attr name=type value=number,ordered>
 Default is number.
</attr>",

"strlen":#"<desc cont>
 Returns the length of the contents. Strlen can be used with <tag><ref
 type=cont>if eval=...</ref></tag> to test the length of variables.
</desc>",
"then":#"<desc cont>
 Shows its content if the truth-value is true.
</desc>",
"trace":#"<desc cont>
 Executes the contained RXML code and makes a trace report about how
 the contents are parsed by the RXML parser.
</desc>",

"true":#"<desc tag>
 An internal tag used to set the return value of tag><ref
 type=cont>if</ref></tag> tags. It will ensure that the next tag><ref
 type=cont>else</ref></tag> tag will not show its contents. It can be
 useful if you are writing your own tag><ref type=cont>if</ref></tag>
 lookalike tag.
</desc>",

"undefine":#"<desc tag>

 Removes a definition made by the define container. One attribute is
 required.

</desc>

<attr name=variable value=name>
 Undefines this variable.
</attr>

<attr name=tag value=name>
 Undefines this tag.
</attr>

<attr name=container value=name>
 Undefines this container.
</attr>

<attr name=if value=name>
 Undefines this if-plugin.
</attr>",

"use":#"<desc cont>
 Reads tags, container tags and defines from a file or package.
</desc>

<attr name=packageinfo>
 Show a all available packages.
 <ex><use packageinfo></ex>
</attr>

<attr name=package value=name>
 Reads all tags, container tags and defines from the given package.
 Packages are files located in local/rxml_packages/.

 <p>By default, the package gtext_headers is available, that replaces
 normal headers with graphical headers. It redefines the h1, h2, h3,
 h4, h5 and h6 container tags.</p>
</attr>

<attr name=file value=path>
 Reads all tags and container tags and defines from the file.

 <p>This file will be fetched just as if someone had tried to fetch it
 with an HTTP request. This makes it possible to use Pike script
 results and other dynamic documents. Note, however, that the results
 of the parsing are heavily cached for performance reasons. If you do
 not want this cache, use <tag><ref type=tag>insert file=...
 nocache</ref></tag> instead.</p>
</attr>

<attr name=info>
 Show a list of all defined tags/containers and if arguments in the file
</attr>
 The <tag><ref type=tag>use</ref></tag> tag is much faster than the
 <tag><ref type=tag>insert</ref></tag>, since the parsed definitions
 is cached.",

"eval":#"<desc cont>Postparses its content. Useful when an entity contains
 RXML-code. <tag>eval</tag> is then placed around the entity to get its
 content parsed.</desc>",

]);
#endif
