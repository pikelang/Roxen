// The Roxen RXML Parser. See also the RXML Pike modules.
// Copyright © 1996 - 2000, Roxen IS.
//
// Per Hedbor, Henrik Grubbström, Pontus Hagland, David Hedbor and others.
// New parser by Martin Stjernholm
// New RXML, scopes and entities by Martin Nilsson
//
// $Id: rxml.pike,v 1.201 2000/07/02 16:53:40 nilsson Exp $


inherit "rxmlhelp";
#include <request_trace.h>
#include <config.h>

#ifndef manual

#define _stat defines[" _stat"]
#define _error defines[" _error"]
#define _extra_heads defines[" _extra_heads"]
#define _rettext defines[" _rettext"]
#define _ok     defines[" _ok"]

class RequestID { }

// ----------------------- Error handling -------------------------

function _run_error;
string handle_run_error (RXML.Backtrace err, RXML.Type type)
// This is used to report thrown RXML run errors. See
// RXML.run_error().
{
  RequestID id=RXML.get_context()->id;
  if(id->conf->get_provider("RXMLRunError")) {
    if(!_run_error)
      _run_error=id->conf->get_provider("RXMLRunError")->rxml_run_error;
    string res=_run_error(err, type, id);
    if(res) return res;
  }
  else
    _run_error=0;
  id->misc->defines[" _ok"]=0;
#ifdef MODULE_DEBUG
  report_notice ("Error in %s.\n%s", id->raw_url, describe_error (err));
#endif
  if (type->subtype_of (RXML.t_html) || type->subtype_of (RXML.t_xml))
    return "<br clear=\"all\" />\n<pre>" +
      Roxen.html_encode_string (describe_error (err)) + "</pre>\n";
  else return describe_error (err);
}

function _parse_error;
string handle_parse_error (RXML.Backtrace err, RXML.Type type)
// This is used to report thrown RXML parse errors. See
// RXML.parse_error().
{
  RequestID id=RXML.get_context()->id;
  if(id->conf->get_provider("RXMLParseError")) {
    if(!_parse_error)
      _parse_error=id->conf->get_provider("RXMLParseError")->rxml_parse_error;
    string res=_parse_error(err, type, id);
    if(res) return res;
  }
  else
    _parse_error=0;
  id->misc->defines[" _ok"]=0;
#ifdef MODULE_DEBUG
  report_notice ("Error in %s.\n%s", id->raw_url, describe_error (err));
#endif
  if (type->subtype_of (RXML.t_html) || type->subtype_of (RXML.t_xml))
    return "<br clear=\"all\" />\n<pre>" +
      Roxen.html_encode_string (describe_error (err)) + "</pre>\n";
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


// ------------------------- RXML Parser ------------------------------

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
    int i = search (imported, Roxen.entities_tag_set);
    array(RXML.TagSet) new_imported = imported[..i-1] + imported[i+1..];
    array(RoxenModule) new_modules = modules[..i-1] + modules[i+1..];
    array(int) priorities = new_modules->query ("_priority", 1);
    priorities = replace (priorities, 0, 4);
    sort (priorities, new_imported, new_modules);
    new_imported = reverse (new_imported) + ({imported[i]});
    if (equal (imported, new_imported)) return;
    new_modules = reverse (new_modules) + ({modules[i]});
    `->= ("imported", new_imported);
    modules = new_modules;
  }

  mixed `->= (string var, mixed val)
  // Currently necessary due to misfeature in Pike.
  {
    if (var == "modules") modules = val;
    else ::`->= (var, val);
    return val;
  }

  void create (object rxml_object)
  {
    ::create ("rxml_tag_set");

    // Fix a better name later when we know the name of the
    // configuration.
    call_out (lambda () {
		string cname = sprintf ("%O", rxml_object);
		if (sscanf (cname, "Configuration(%s", cname) == 1 &&
		    sizeof (cname) && cname[-1] == ')')
		  cname = cname[..sizeof (cname) - 2];
		name = sprintf ("rxml_tag_set,%s", cname);
	      }, 0);

    imported = ({Roxen.entities_tag_set});
    modules = ({rxml_object});
  }
} (this_object());

RXML.Type default_content_type = RXML.t_html (RXML.PXml);
RXML.Type default_arg_type = RXML.t_text (RXML.PEnt);

int old_rxml_compat;

class BacktraceFrame
// Only used to get old style tags in the RXML backtraces.
{
  RXML.Frame up;
  string tag_name;
  mapping(string:string) args;
  void create (RXML.Frame _up, string name, mapping(string:string) _args)
  {
    up = _up;
    tag_name = name;
    args = _args;
  }

  string _sprintf() {return "BacktraceFrame(" + tag_name + ")";}
}

// A note on tag overriding: It's possible for old style tags to
// propagate their results to the tags they have overridden (new style
// tags can use RXML.Frame.propagate_tag()). This is done by an
// extension to the return value:
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

array|string call_overridden (array call_to, RXML.PXml parser,
			      string name, mapping(string:string) args,
			      string content, RequestID id)
{
  mixed tdef, cdef;
#ifdef OLD_RXML_COMPAT
  if (old_rxml_compat) name = lower_case (name);
#endif

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
      result = ({Roxen.make_tag (call_to[1] || name, call_to[2] || args)});
    else if (sizeof (call_to) == 4)
      result = ({Roxen.make_container (call_to[1] || name, call_to[2] || args,
				 call_to[3] || content)});

  m_delete (id->misc, "__tag_overrider_def");
  return result;
}

array|string call_tag(RXML.PXml parser, mapping args, string|function rf)
{
  RXML.Context ctx = parser->context;
  RequestID id = ctx->id;
  string tag = parser->tag_name();
  id->misc->line = (string)parser->at_line();

  if(args->help)
  {
    TRACE_ENTER("tag &lt;"+tag+" help&gt;", rf);
    string h = find_tag_doc(tag, id);
    TRACE_LEAVE("");
    return h;
  }

  if(stringp(rf)) return rf;
  if (!rf) return 0;

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
    if (++ctx->frame_depth >= ctx->max_frame_depth) {
      ctx->frame_depth--;
      RXML.run_error ("Too deep recursion -- exceeding %d nested tags.\n",
		      ctx->max_frame_depth);
    }
    if (string splice_args = args["::"]) {
      // Somewhat kludgy solution for the time being.
      splice_args = default_arg_type->eval (splice_args, 0, rxml_tag_set, parser, 1);
      m_delete (args, "::");
      args += parser->parse_tag_args (splice_args);
    }
    foreach (indices (args), string arg)
      // Parse variable entities in arguments.
      args[arg] = default_arg_type->eval (args[arg], 0, rxml_tag_set, parser, 1);
    result=rf(tag,args,id,parser->_source_file,parser->_defines);
  };
  ctx->frame = orig_frame;
  ctx->frame_depth--;
  if (err) {
    ctx->handle_exception (err, parser); // Will rethrow unknown errors.
    result = ({});
  }

  TRACE_LEAVE("");

  if(args->noparse && stringp(result)) return ({ result });
  if (arrayp (result) && sizeof (result) && result[0] == 1)
    return call_overridden (result, parser, tag, args, 0, id);

  return result || ({Roxen.make_tag (tag, args)});
}

array(string)|string call_container(RXML.PXml parser, mapping args,
				    string contents, string|function rf)
{
  RXML.Context ctx = parser->context;
  RequestID id = ctx->id;
  string tag = parser->tag_name();
  id->misc->line = (string)parser->at_line();

  if(args->help)
  {
    TRACE_ENTER("container &lt;"+tag+" help&gt", rf);
    string h = find_tag_doc(tag, id);
    TRACE_LEAVE("");
    return h;
  }

  if(stringp(rf)) return rf;
  if (!rf) return 0;

  TRACE_ENTER("container &lt;"+tag+"&gt", rf);

  if(args->preparse) contents = parse_rxml(contents, id);
  if(args->trimwhites) contents = String.trim_all_whites(contents);

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
    if (++ctx->frame_depth >= ctx->max_frame_depth) {
      ctx->frame_depth--;
      RXML.run_error ("Too deep recursion -- exceeding %d nested tags.\n",
		      ctx->max_frame_depth);
    }
    if (string splice_args = args["::"]) {
      // Somewhat kludgy solution for the time being.
      splice_args = default_arg_type->eval (splice_args, 0, rxml_tag_set, parser, 1);
      m_delete (args, "::");
      args += parser->parse_tag_args (splice_args);
    }
    foreach (indices (args), string arg)
      // Parse variable entities in arguments.
      args[arg] = default_arg_type->eval (args[arg], 0, rxml_tag_set, parser, 1);
    result=rf(tag,args,contents,id,parser->_source_file,parser->_defines);
  };
  ctx->frame = orig_frame;
  ctx->frame_depth--;
  if (err) {
    ctx->handle_exception (err, parser); // Will rethrow unknown errors.
    result = ({});
  }

  TRACE_LEAVE("");

  if(args->noparse && stringp(result)) return ({ result });
  if (arrayp (result) && sizeof (result) && result[0] == 1)
    return call_overridden (result, parser, tag, args, contents, id);

  return result || ({Roxen.make_container (tag, args, contents)});
}

string do_parse(string to_parse, RequestID id,
                Stdio.File file, mapping defines)
{
  RXML.PXml parent_parser = id->misc->_parser;	// Don't count on that this exists.
  RXML.PXml parser;
  RXML.Context ctx;

  if (parent_parser && (ctx = parent_parser->context) && ctx->id == id)
    parser = default_content_type->get_parser (ctx, 0, parent_parser);
  else {
    parser = rxml_tag_set (default_content_type, id);
    parent_parser = 0;
#ifdef OLD_RXML_COMPAT
    if (old_rxml_compat) parser->context->compatible_scope = 1;
#endif
  }
  id->misc->_parser = parser;
  parser->_source_file = file;
  parser->_defines = defines;

  if (mixed err = catch {
    if (parent_parser && ctx == RXML.get_context())
      parser->finish (to_parse);
    else
      parser->write_end (to_parse);
    string result = parser->eval();
    parser->_defines = 0;
    id->misc->_parser = parent_parser;
    return result;
  }) {
    if (!parser) {
      werror("RXML: Parser destructed!\n");
#if constant(_describe)
      _describe(parser);
#endif /* constant(_describe) */
      error("Parser destructed!\n");
    }
    parser->_defines = 0;
    id->misc->_parser = parent_parser;
    if (objectp (err) && err->thrown_at_unwind)
      error ("Can't handle RXML parser unwinding in "
	     "compatibility mode (error=%O).\n", err);
    else throw (err);
  }
}

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

#define COMPAT_TAG_TYPE \
  function(string,mapping(string:string),RequestID,void|Stdio.File,void|mapping: \
	   string|array(int|string))

#define COMPAT_CONTAINER_TYPE \
  function(string,mapping(string:string),string,RequestID,void|Stdio.File,void|mapping: \
	   string|array(int|string))

class CompatTag
{
  inherit RXML.Tag;

  string name;
  int flags;
  string|COMPAT_TAG_TYPE|COMPAT_CONTAINER_TYPE fn;

  RXML.Type content_type = RXML.t_same; // No preparsing.
  array(RXML.Type) result_types =
    ({RXML.t_xml (RXML.PXml), RXML.t_html (RXML.PXml)}); // Postparsing.

  void create (string _name, int empty, string|COMPAT_TAG_TYPE|COMPAT_CONTAINER_TYPE _fn)
  {
    name = _name, fn = _fn;
    flags = empty && RXML.FLAG_EMPTY_ELEMENT;
  }

  class Frame
  {
    inherit RXML.Frame;
    string raw_tag_text;

    array do_return (RequestID id)
    {
      id->misc->line = "0";	// No working system for this yet.

      if (stringp (fn)) return ({fn});
      if (!fn) return ({propagate_tag()});

      Stdio.File source_file;
      mapping defines;
      if (id->misc->_parser) {
	source_file = id->misc->_parser->_source_file;
	defines = id->misc->_parser->_defines;
      }

      string|array(string) result;
      if (flags & RXML.FLAG_EMPTY_ELEMENT)
	result = fn (name, args, id, source_file, defines);
      else
	result = fn (name, args, content, id, source_file, defines);

      if (arrayp (result)) {
	result_type = result_type (RXML.PNone);
	if (sizeof (result) && result[0] == 1) {
	  [string pname, mapping(string:string) pargs, string pcontent] =
	    (result[1..] + ({0, 0, 0}))[..2];
	  if (!pname || pname == name)
	    return ({!pargs && !pcontent ? propagate_tag () :
		     propagate_tag (pargs || args, pcontent || content)});
	  else
	    return ({RXML.make_unparsed_tag (pname, pargs || args, pcontent || content)});
	}
	else return result;
      }
      else if (result) {
	if (args->noparse) result_type = result_type (RXML.PNone);
	return ({result});
      }
      else return ({propagate_tag()});
    }
  }
}

class GenericTag {
  inherit RXML.Tag;
  constant is_generic_tag=1;
  string name;
  int flags;

  function(string,mapping(string:string),string,RequestID,RXML.Frame:
	   array|string) _do_return;

  void create(string _name, int _flags,
	      function(string,mapping(string:string),string,RequestID,RXML.Frame:
		       array|string) __do_return) {
    name=_name;
    flags=_flags;
    _do_return=__do_return;
    if(flags&RXML.FLAG_DONT_PREPARSE)
      content_type = RXML.t_same;
  }

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id, void|mixed piece) {
      if (flags & RXML.FLAG_POSTPARSE)
	result_type = result_type (RXML.PXml);
      if (!(flags & RXML.FLAG_STREAM_CONTENT))
	piece = content || "";
      array|string res = _do_return(name, args, piece, id, this_object());
      return stringp (res) ? ({res}) : res;
    }
  }
}

void add_parse_module (RoxenModule mod)
{
  RXML.TagSet tag_set =
    mod->query_tag_set ? mod->query_tag_set() : RXML.TagSet (mod->module_identifier());
  mapping(string:mixed) defs;

  if (mod->query_tag_callers &&
      mappingp (defs = mod->query_tag_callers()) &&
      sizeof (defs))
    tag_set->add_tags (map (indices (defs),
			    lambda (string name) {
			      return CompatTag (name, 1, defs[name]);
			    }));

  if (mod->query_container_callers &&
      mappingp (defs = mod->query_container_callers()) &&
      sizeof (defs))
    tag_set->add_tags (map (indices (defs),
			    lambda (string name) {
			      return CompatTag (name, 0, defs[name]);
			    }));

  if (mod->query_simpletag_callers &&
      mappingp (defs = mod->query_simpletag_callers()) &&
      sizeof (defs))
    tag_set->add_tags(Array.map(indices(defs),
				lambda(string tag){ return GenericTag(tag, @defs[tag]); }));

  if (search (rxml_tag_set->imported, tag_set) < 0) {
    rxml_tag_set->modules += ({mod});
    rxml_tag_set->imported += ({tag_set});
    remove_call_out (rxml_tag_set->sort_on_priority);
    call_out (rxml_tag_set->sort_on_priority, 0);
  }
}

void remove_parse_module (RoxenModule mod)
{
  int i = search (rxml_tag_set->modules, mod);
  if (i >= 0) {
    RXML.TagSet tag_set = rxml_tag_set->imported[i];
    rxml_tag_set->modules =
      rxml_tag_set->modules[..i - 1] + rxml_tag_set->modules[i + 1..];
    rxml_tag_set->imported =
      rxml_tag_set->imported[..i - 1] + rxml_tag_set->imported[i + 1..];
    if (tag_set) destruct (tag_set);
  }
}

void ready_to_receive_requests (object this)
{
  remove_call_out (rxml_tag_set->sort_on_priority);
  rxml_tag_set->sort_on_priority();
}


// ------------------------- RXML Core tags --------------------------

class TagHelp {
  inherit RXML.Tag;
  constant name = "help";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      RXML.PXml parser = rxml_tag_set (RXML.t_html (RXML.PXml), id);
      array tags = sort(indices(parser->tags()+parser->containers()))-({"\x266a"});
      string help_for = args->for || id->variables->_r_t_h;
      string ret="<h2>Roxen Interactive RXML Help</h2>";

      if(!help_for) {
	string char;
	ret += "<b>Here is a list of all defined tags. Click on the name to "
	  "receive more detailed information. All these tags are also availabe "
	  "in the \""+RXML_NAMESPACE+"\" namespace.</b><p>\n";
	array tag_links;

	foreach(tags, string tag) {
	  if(tag[0..0]!=char) {
	    if(tag_links && char!="/") ret+="<h3>"+upper_case(char)+"</h3>\n<p>"+
					 String.implode_nicely(tag_links)+"</p>";
	    char=tag[0..0];
	    tag_links=({});
	  }
	  if(tag[0..sizeof(RXML_NAMESPACE)]!=RXML_NAMESPACE+":")
	    if(undocumented_tags[tag])
	      tag_links += ({ tag });
	    else
	      tag_links += ({ sprintf("<a href=\"%s?_r_t_h=%s\">%s</a>\n",
				      id->not_query, Roxen.http_encode_url(tag), tag) });
	}

	result=ret+"<h3>"+upper_case(char)+"</h3>\n<p>"+String.implode_nicely(tag_links)+"</p>";
	return 0;
      }

      result=ret+find_tag_doc(help_for, id);
    }
  }
}

class TagNumber {
  inherit RXML.Tag;
  constant name = "number";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;

  class Frame {
    inherit RXML.Frame;
    array do_return(RequestID id) {
      result=roxen.language(args->lang||args->language||
                            id->misc->defines->theme_language,
			    args->type||"number",id)( (int)args->num );
    }
  }
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
  p = combine_path("/", p);
  if(file_stat( "../local/rxml_packages/"+p ))
    catch(data=Stdio.File( "../local/rxml_packages/"+p, "r" )->read());
  if(!data && file_stat( "../rxml_packages/"+p ))
    catch(data=Stdio.File( "../rxml_packages/"+p, "r" )->read());
  return data;
}

private string use_file_doc(string f, string data)
{
  string res="", doc="";
  int help=0; /* If true, all tags support the 'help' argument. */
  sscanf(data, "%*sdoc=\"%s\"", doc);
  sscanf(data, "%*shelp=%d", help);
  res += "<dt><b>"+f+"</b></dt><dd>"+(doc?doc+"<br />":"")+"</dd>";

  mapping d=(["tag":({}),
	      "container":({}),
	      "if":({}),
	      "variable":({}) ]);

  parse_html(data, ([]), (["define":
			   lambda(string t, mapping m, string c) {
			     foreach(indices(d), string type)
			       if(m[type]) d[type]+=({m[type]});
			     return "";
			   },
			   "undefine":
			   lambda(string t, mapping m, string c) {
			     foreach(indices(d), string type)
			       if(m[type]) d[type]+=({m[type]});
			     return "";
			   } ]) );

  foreach(indices(d), string type) {
    array ind=d[type];
    if(sizeof(ind))
      res += "defines the following tag"+
	(sizeof(ind)!=1?"s":"") +": "+
	String.implode_nicely( sort(ind) )+"<br />";
  }

  if(help) res+="<br /><br />All tags accept the <i>help</i> attribute.";

  return res;
}

class TagUse {
  inherit RXML.Tag;
  constant name = "use";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      if(args->packageinfo) {
	string res ="<dl>";
	foreach(list_packages(), string f)
	  res += use_file_doc(f, read_package( f ));
	return ({ res+"</dl>" });
      }

      if(!args->file && !args->package)
	parse_error("No file or package selected.\n");


      array res;
      if(!id->misc->_ifs) id->misc->_ifs=([]);
      string name=args->file?(id->conf->get_config_id()+"|"+args->file):("|"+args->package);
      RXML.Context ctx=RXML.get_context();

      if(args->info || id->pragma["no-cache"] ||
	 !(res=cache_lookup("macrofiles",name)) ) {
	res = ({ ([]), ({}) });

	string file;
	if(args->file)
	  file = try_get_file( Roxen.fix_relative(args->file, id), id );
	else
	  file = read_package( args->package );

	if(!file)
	  run_error("Failed to fetch "+(args->file||args->package)+".\n");

	if( args->info )
	  return ({"<dl>"+use_file_doc( args->file || args->package, file )+"</dl>"});

	multiset before=ctx->get_runtime_tags();
	mapping before_ifs=id->misc->_ifs;
	parse_rxml( file, id );

	res[0] = id->misc->_ifs - before_ifs;
	res[1]=indices(RXML.get_context()->get_runtime_tags()-before);
	cache_set("macrofiles", name, res);
      }

      id->misc->_ifs += res[0];
      foreach(res[1], RXML.Tag tag)
	ctx->add_runtime_tag(tag);

      return 0;
    }
  }
}

class UserTagContents
{
  inherit RXML.Tag;
  constant name = "contents";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;
  array(RXML.Type) result_types = ({RXML.t_any (RXML.PXml)});

  class Frame
  {
    inherit RXML.Frame;
    RXML.Frame user_tag_up;
    array do_return()
    {
      RXML.Frame frame = up;
      while (frame && !frame->user_tag_contents)
	frame = frame->user_tag_up || frame->up;
      if (!frame) parse_error ("No contents to insert.\n");
      user_tag_up = frame->up;
      return ({frame->user_tag_contents});
    }
  }
}

RXML.TagSet user_tag_contents_tag_set =
  RXML.TagSet ("user_tag_contents", ({UserTagContents()}));

class UserTag {
  inherit RXML.Tag;
  string name;
  int flags = 0;
  RXML.Type content_type = RXML.t_same;
  array(RXML.Type) result_types = ({ RXML.t_any(RXML.PXml) });

  string c;
  mapping defaults;
  string scope;

  void create(string _name, string _c, mapping _defaults,
	      int tag, void|string scope_name) {
    name=_name;
    c=_c;
    defaults=_defaults;
    flags|=RXML.FLAG_EMPTY_ELEMENT*tag;
    scope=scope_name;
  }

  class Frame {
    inherit RXML.Frame;
    RXML.TagSet additional_tags = user_tag_contents_tag_set;
    mapping vars;
    string scope_name;
    string user_tag_contents;

    array do_return(RequestID id) {
      mapping nargs=defaults+args;
      id->misc->last_tag_args = nargs;
      scope_name=scope||name;
      vars = nargs;

      if(!(RXML.FLAG_EMPTY_ELEMENT&flags) && args->trimwhites)
	content=String.trim_all_whites(content);

#ifdef OLD_RXML_COMPAT
      if(old_rxml_compat) {
	array replace_from, replace_to;
	if (flags & RXML.FLAG_EMPTY_ELEMENT) {
	  replace_from = map(indices(nargs),Roxen.make_entity)+({"#args#"});
	  replace_to = values(nargs)+({ Roxen.make_tag_attributes(nargs)[1..] });
	}
	else {
	  replace_from = map(indices(nargs),Roxen.make_entity)+({"#args#", "<contents>"});
	  replace_to = values(nargs)+({ Roxen.make_tag_attributes(nargs)[1..], content });
	}
	string c2;
	c2 = replace(c, replace_from, replace_to);
	if(c2!=c) {
	  vars=([]);
	  return ({c2});
	}
      }
#endif

      vars->args = Roxen.make_tag_attributes(nargs)[1..];
      vars["rest-args"] = Roxen.make_tag_attributes(args - defaults)[1..];
      user_tag_contents = vars->contents = content;
      return ({ c });
    }
  }
}

class TagDefine {
  inherit RXML.Tag;
  constant name = "define";

  class Frame {
    inherit RXML.Frame;

    array do_enter(RequestID id) {
      if(args->preparse)
	m_delete(args, "preparse");
      else
	content_type = RXML.t_xml;
      return 0;
    }

    array do_return(RequestID id) {
      result = "";
      string n;

      if(n=args->variable) {
	if(args->trimwhites) content=String.trim_all_whites(content);
	RXML.user_set_var(n, content, args->scope);
	return 0;
      }

      if (n=args->tag||args->container) {
#ifdef OLD_RXML_COMPAT
	n = old_rxml_compat?lower_case(n):n;
#endif
	int tag=0;
	if(args->tag) {
	  tag=1;
	  m_delete(args, "tag");
	} else
	  m_delete(args, "container");

	mapping defaults=([]);

#ifdef OLD_RXML_COMPAT
	if(old_rxml_compat)
	  foreach( indices(args), string arg )
	    if( arg[..7] == "default_" )
	      {
		defaults[arg[8..]] = args[arg];
		old_rxml_warning(id, "define attribute "+arg,"attrib container");
		m_delete( args, arg );
	      }
#endif
	content=parse_html(content||"",([]),
			   (["attrib":
			     lambda(string tag, mapping m, string cont) {
			       if(m->name) defaults[m->name]=parse_rxml(cont,id);
			       return "";
			     }
			   ]));

	if(args->trimwhites) {
	  content=String.trim_all_whites(content);
	  m_delete (args, "trimwhites");
	}

#ifdef OLD_RXML_COMPAT
	if(old_rxml_compat) content = replace( content, indices(args), values(args) );
#endif

	RXML.get_context()->add_runtime_tag(UserTag(n, content, defaults,
						    tag, args->scope));
	return 0;
      }

      if (n=args->if) {
	if(!id->misc->_ifs) id->misc->_ifs=([]);
	id->misc->_ifs[args->if]=UserIf(args->if, content);
	return 0;
      }

#ifdef OLD_RXML_COMPAT
      if (n=args->name) {
	id->misc->defines[n]=content;
	old_rxml_warning(id, "attempt to define name ","variable");
	return 0;
      }
#endif

      parse_error("No tag, variable, if or container specified.\n");
    }
  }
}

class TagUndefine {
  inherit RXML.Tag;
  int flags = RXML.FLAG_EMPTY_ELEMENT;
  constant name = "undefine";
  class Frame {
    inherit RXML.Frame;
    array do_enter(RequestID id) {
      string n;

      if(n=args->variable) {
	RXML.get_context()->user_delete_var(n, args->scope);
	return 0;
      }

      if (n=args->tag||args->container) {
	RXML.get_context()->remove_runtime_tag(n);
	return 0;
      }

      if (n=args->if) {
	m_delete(id->misc->_ifs, n);
	return 0;
      }

#ifdef OLD_RXML_COMPAT
      if (n=args->name) {
	m_delete(id->misc->defines, args->name);
	return 0;
      }
#endif

      parse_error("No tag, variable, if or container specified.\n");
    }
  }
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
	       "<br />"+Roxen.html_encode_string(desc)+efont)+"<p>";

  }

  string res()
  {
    while(level>0) trace_leave_ol("");
    return resolv+"</ol>";
  }
}

function trace;

class TagTrace {
  inherit RXML.Tag;
  constant name = "trace";

  class Frame {
    inherit RXML.Frame;
    function a,b;
    Tracer t;

    array do_enter(RequestID id) {
      NOCACHE();
      //   if(args->summary)
      //     t = SumTracer();
      //   else
      t = Tracer();
      a = id->misc->trace_enter;
      b = id->misc->trace_leave;
      id->misc->trace_enter = t->trace_enter_ol;
      id->misc->trace_leave = t->trace_leave_ol;
      t->trace_enter_ol( "tag &lt;trace&gt;", trace);
      return 0;
    }

    array do_return(RequestID id) {
      id->misc->trace_enter = a;
      id->misc->trace_leave = b;
      content += "\n<h1>Trace report</h1>"+t->res()+"</ol>";
      return 0;
    }
  }
}

class TagNoParse {
  inherit RXML.Tag;
  constant name = "noparse";
  RXML.Type content_type = RXML.t_same;
  class Frame {
    inherit RXML.Frame;
  }
}

class TagEval {
  inherit RXML.Tag;
  constant name = "eval";
  array(RXML.Type) result_types = ({ RXML.t_any(RXML.PXml) });

  class Frame {
    inherit RXML.Frame;
    array do_return(RequestID id) {
      return ({ content });
    }
  }
}

class TagNoOutput {
  inherit RXML.Tag;
  constant name = "nooutput";
  constant flags = 0;

  class Frame {
    inherit RXML.Frame;
    array do_process() {
      return ({""});
    }
  }
}

class TagStrLen {
  inherit RXML.Tag;
  constant name = "strlen";
  constant flags = 0;

  class Frame {
    inherit RXML.Frame;
    array do_return() {
      if(!stringp(content)) {
	result="0";
	return 0;
      }
      result = (string)strlen(content);
    }
  }
}

class TagCase {
  inherit RXML.Tag;
  constant name = "case";
  class Frame {
    inherit RXML.Frame;
    int cap=0;
    array do_process(RequestID id) {
      if(args->case)
	switch(lower_case(args->case)) {
	case "lower": return ({ lower_case(content) });
	case "upper": return ({ upper_case(content) });
	case "capitalize":
	  if(cap) return content;
	  cap=1;
	  return ({ capitalize(content) });
	}

#ifdef OLD_RXML_COMPAT
      if(args->lower) {
	content = lower_case(content);
	old_rxml_warning(id, "attribute lower","case=lower");
      }
      if(args->upper) {
	content = upper_case(content);
	old_rxml_warning(id, "attribute upper","case=upper");
      }
      if(args->capitalize){
	content = capitalize(content);
	old_rxml_warning(id, "attribute capitalize","case=capitalize");
      }
#endif
      return ({ content });
    }
  }
}

#define LAST_IF_TRUE id->misc->defines[" _ok"]

class FrameIf {
  inherit RXML.Frame;
  int do_iterate = -1;

  array do_enter(RequestID id) {
    int and = 1;

    if(args->not) {
      m_delete(args, "not");
      do_enter(id);
      do_iterate=do_iterate==1?-1:1;
      return 0;
    }

    if(args->or)  { and = 0; m_delete( args, "or" ); }
    if(args->and) { and = 1; m_delete( args, "and" ); }
    mapping plugins=get_plugins();
    if(id->misc->_ifs) plugins+=id->misc->_ifs;
    array possible = indices(args) & indices(plugins);

    int ifval=0;
    foreach(possible, string s) {
      ifval = plugins[ s ]->eval( args[s], id, args, and, s );
      if(ifval) {
	if(!and) {
	  do_iterate = 1;
	  return 0;
	}
      }
      else
	if(and)
	  return 0;
    }
    if(ifval) {
      do_iterate = 1;
      return 0;
    }
    return 0;
  }

  array do_return(RequestID id) {
    if(do_iterate==1) {
      LAST_IF_TRUE = 1;
      result = content;
    }
    else
      LAST_IF_TRUE = 0;
    return 0;
  }
}

class TagIf {
  inherit RXML.Tag;
  constant name = "if";
  constant flags = RXML.FLAG_SOCKET_TAG;
  program Frame = FrameIf;
}

class TagElse {
  inherit RXML.Tag;
  constant name = "else";
  constant flags = 0;
  class Frame {
    inherit RXML.Frame;
    int do_iterate=1;
    array do_enter(RequestID id) {
      if(LAST_IF_TRUE) do_iterate=-1;
      return 0;
    }
  }
}

class TagThen {
  inherit RXML.Tag;
  constant name = "then";
  constant flags = 0;
  class Frame {
    inherit RXML.Frame;
    int do_iterate=1;
    array do_enter(RequestID id) {
      if(!LAST_IF_TRUE) do_iterate=-1;
      return 0;
    }
  }
}

class TagElseif {
  inherit RXML.Tag;
  constant name = "elseif";

  class Frame {
    inherit FrameIf;
    int last;
    array do_enter(RequestID id) {
      last=LAST_IF_TRUE;
      if(last) return 0;
      return ::do_enter(id);
    }

    array do_return(RequestID id) {
      if(last) return 0;
      return ::do_return(id);
    }

    mapping(string:RXML.Tag) get_plugins() {
      return RXML.get_context()->tag_set->get_plugins ("if");
    }
  }
}

class TagTrue {
  inherit RXML.Tag;
  constant name = "true";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;

  class Frame {
    inherit RXML.Frame;
    array do_enter(RequestID id) {
      LAST_IF_TRUE = 1;
    }
  }
}

class TagFalse {
  inherit RXML.Tag;
  constant name = "false";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;
  class Frame {
    inherit RXML.Frame;
    array do_enter(RequestID id) {
      LAST_IF_TRUE = 0;
    }
  }
}

class TagCond
{
  inherit RXML.Tag;
  constant name = "cond";
  RXML.Type content_type = RXML.t_none (RXML.PXml);
  array(RXML.Type) result_types = ({RXML.t_any});

  class TagCase
  {
    inherit RXML.Tag;
    constant name = "case";
    array(RXML.Type) result_types = ({RXML.t_none});

    class Frame
    {
      inherit FrameIf;

      array do_enter (RequestID id)
      {
	if (up->result != RXML.Void) return 0;
	content_type = up->result_type (RXML.PXml);
	return ::do_enter (id);
      }

      array do_return (RequestID id)
      {
	::do_return (id);
	if (up->result != RXML.Void) return 0;
	up->result = result;
	result = RXML.Void;
	return 0;
      }

      // Must override this since it's used by FrameIf.
      mapping(string:RXML.Tag) get_plugins()
	{return RXML.get_context()->tag_set->get_plugins ("if");}
    }
  }

  class TagDefault
  {
    inherit RXML.Tag;
    constant name = "default";
    array(RXML.Type) result_types = ({RXML.t_none});

    class Frame
    {
      inherit RXML.Frame;
      int do_iterate = 1;

      array do_enter()
      {
	if (up->result != RXML.Void) {
	  do_iterate = -1;
	  return 0;
	}
	content_type = up->result_type (RXML.PNone);
	return 0;
      }

      array do_return()
      {
	up->default_data = content;
	return 0;
      }
    }
  }

  RXML.TagSet cond_tags =
    RXML.TagSet ("TagCond.cond_tags", ({TagCase(), TagDefault()}));

  class Frame
  {
    inherit RXML.Frame;
    RXML.TagSet local_tags = cond_tags;
    string default_data;

    array do_return (RequestID id)
    {
      if (result == RXML.Void && default_data) {
	LAST_IF_TRUE = 0;
	return ({RXML.parse_frame (result_type (RXML.PXml), default_data)});
      }
      return 0;
    }
  }
}

class TagEmit {
  inherit RXML.Tag;
  constant name = "emit";
  constant flags = RXML.FLAG_SOCKET_TAG;
  mapping(string:RXML.Type) req_arg_types = (["source":RXML.t_text]);

  class Frame {
    inherit RXML.Frame;
    string scope_name;
    mapping vars=(["counter":0]);

    object plugin;
    array(mapping(string:mixed))|function res;

    array do_enter(RequestID id) {
      if(!(plugin=get_plugins()[args->source]))
	parse_error("Source not present.\n");
      scope_name=args->scope||args->source;
      res=plugin->get_dataset(args, id);
      if(arrayp(res)) {
	if(!plugin->skiprows && args->skiprows) {
	  if(args->skiprows[0]=='-') args->skiprows=sizeof(res)-(int)args->skiprows-1;
	  res=res[(int)args->skiprows..];
	}
	if(!plugin->maxrows && args->maxrows) res=res[..(int)args->maxrows-1];
	if(args->rowinfo) RXML.user_set_var(args->rowinfo, sizeof(res));
	if(args["do-once"] && sizeof(res)==0) res=({ ([]) });

	do_iterate=array_iterate;

	if(sizeof(res))
	  LAST_IF_TRUE = 1;
	else
	  LAST_IF_TRUE = 0;

	return 0;
      }
      if(functionp(res)) {
	do_iterate=function_iterate;
	LAST_IF_TRUE = 1;
	return 0;
      }
      parse_error("Wrong return type from emit source plugin.\n");
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

class TagEmitSources {
  inherit RXML.Tag;
  constant name="emit";
  constant plugin_name="sources";

  array(mapping(string:string)) get_dataset(mapping m, RequestID id) {
    return Array.map( indices(RXML.get_context()->tag_set->get_plugins("emit")),
		      lambda(string source) { return (["source":source]); } );
  }
}

class TagComment {
  inherit RXML.Tag;
  constant name = "comment";
  class Frame {
    inherit RXML.Frame;
    int do_iterate=-1;
    array do_enter() {
      if(args->preparse) {
	do_iterate=1;
	return 0;
      }
      else
	return ({ "" });
    }
    array do_return() {
      return ({ "" });
    }
  }
}

RXML.TagSet query_tag_set()
{
  // Note: By putting the tags in rxml_tag_set, they will always have
  // the highest priority.
  rxml_tag_set->add_tags (filter (rows (this_object(),
					glob ("Tag*", indices (this_object()))),
				  functionp)());
  return Roxen.entities_tag_set;
}


// ---------------------------- If callers -------------------------------

class UserIf
{
  inherit RXML.Tag;
  constant name = "if";
  string plugin_name;
  string rxml_code;

  void create(string pname, string code) {
    plugin_name = pname;
    rxml_code = code;
  }

  int eval(string ind, RequestID id) {
    int otruth, res;
    string tmp;

    TRACE_ENTER("user defined if argument "+plugin_name, UserIf);
    otruth = LAST_IF_TRUE;
    LAST_IF_TRUE = -2;
    tmp = parse_rxml(rxml_code, id);
    res = LAST_IF_TRUE;
    LAST_IF_TRUE = otruth;

    TRACE_LEAVE("");

    if(ind==plugin_name && res!=-2)
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
  function eval = match_in_map;

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
    if(!cache) CACHE(0);
    array arr=value/" ";
    string|int|float var=source(id, arr[0]);
    if( !var && zero_type( var ) ) return 0;
    if(sizeof(arr)<2) return !!var;
    var = lower_case( (var+"") );
    if(sizeof(arr)==1) return !!var;
    string is=lower_case(arr[2..]*" ");

    if(arr[1]=="==" || arr[1]=="=" || arr[1]=="is")
      return ((is==var)||glob(is,var)||
            sizeof(filter( is/",", glob, var )));
    if(arr[1]=="!=") return is!=var;

    string trash;
    if(sscanf(var,"%f%s",float f_var,trash)==2 && trash=="" &&
       sscanf(is ,"%f%s",float f_is ,trash)==2 && trash=="") {
      if(arr[1]=="<") return f_var<f_is;
      if(arr[1]==">") return f_var>f_is;
    }
    else {
      if(arr[1]=="<") return (var<is);
      if(arr[1]==">") return (var>is);
    }

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

  int eval( string is, RequestID id ) {
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

  int eval(string date, RequestID id, mapping m) {
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

  int eval(string ti, RequestID id, mapping m) {
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

  int eval(string u, RequestID id, mapping m) {
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
      s=id->conf->try_get_file(Roxen.fix_relative(f,id), id);
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

  int eval(string u, RequestID id, mapping m) {
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
      s = id->conf->try_get_file( Roxen.fix_relative( groupfile, id), id );

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

  int eval(string u, RequestID id) {
    CACHE(5);
    return id->conf->is_file(Roxen.fix_relative(u, id), id);
  }
}

class TagIfTrue {
  inherit RXML.Tag;
  constant name = "if";
  constant plugin_name = "true";

  int eval(string u, RequestID id) {
    return LAST_IF_TRUE;
  }
}

class TagIfFalse {
  inherit RXML.Tag;
  constant name = "if";
  constant plugin_name = "false";

  int eval(string u, RequestID id) {
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
  int source(RequestID id, string s) {
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

#ifdef OLD_RXML_COMPAT
class TagIfName {
  inherit TagIfClient;
  constant plugin_name = "name";
}
#endif

class TagIfDefined {
  inherit IfIs;
  constant plugin_name = "defined";
  constant cache = 1;
  string|int|float source(RequestID id, string s) {
    mixed val;
    if(!id->misc->defines || !(val=id->misc->defines[s])) return 0;
    if(stringp(val) || intp(val) || floatp(val)) return val;
    return 1;
  }
}

class TagIfDomain {
  inherit IfMatch;
  constant plugin_name = "domain";
  string source(RequestID id) {
    return id->host;
  }
}

class TagIfIP {
  inherit IfMatch;
  constant plugin_name = "ip";
  string source(RequestID id) {
    return id->remoteaddr;
  }
}

#ifdef OLD_RXML_COMPAT
class TagIfHost {
  inherit TagIfIP;
  constant plugin_name = "host";
}
#endif

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
  int source(RequestID id, string s) {
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
  int source(RequestID id, string s) {
    return id->supports[s];
  }
}

class TagIfVariable {
  inherit IfIs;
  constant plugin_name = "variable";
  constant cache = 1;
  string source(RequestID id, string s) {
    mixed var=RXML.user_get_var(s);
    if(!var) return var;
    return RXML.t_text->convert (var);
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
  mapping doc=compile_string("#define manual\n"+file->read())->tagdoc;
  file->close();
  if(!file->open("etc/supports","r")) return doc;
  parse_html(file->read(), ([]), (["flags":format_support,
				   "vars":format_support]), doc);
  return doc;
}

private int format_support(string t, mapping m, string c, mapping doc) {
  string key=(["flags":"if#supports","vars":"if#clientvar"])[t];
  c=Roxen.html_encode_string(c)-"#! ";
  c=(Array.map(c/"\n", lambda(string row) {
			 if(sscanf(row, "%*s - %*s")!=2) return "";
			 return "<li>"+row+"</li>";
		       }) - ({""})) * "\n";
  doc[key]+="<ul>\n"+c+"</ul>\n";
  return 0;
}

#ifdef manual
constant tagdoc=([
"&roxen;":#"<desc scope><short>This scope contains information specific to this Roxen WebServer.</short></desc>",
"&roxen.domain;":#"<desc ent>The domain name of this virtual server.</desc>",
"&roxen.hits;":#"<desc ent>The number of hits, i.e. requests the
 webserver has accumulated since it was last started.</desc>",
"&roxen.hits-per-minute;":"<desc ent>The number of hits per minute, in average.</desc>",
"&roxen.pike-version;":"<desc ent>The version of Pike the webserver is using.</desc>",
"&roxen.sent;":"<desc ent>The total amount of data the webserver has sent. </desc>",
"&roxen.sent-kbit-per-second;":"<desc ent>The average amount of data the webserver has sent, in Kibibits.</desc>",
"&roxen.sent-mb;":"<desc ent>The total amount of data the webserver has sent, in Mebibits.</desc>",
"&roxen.sent-per-minute;":"<desc ent></desc>",
"&roxen.server;":"<desc ent>The URL of the webserver.</desc>",
"&roxen.ssl-strength;":"<desc ent>How many bits encryption strength are the SSL capable of</desc>",
"&roxen.time;":"<desc ent>The current posix time.</desc>",
"&roxen.uptime;":"<desc ent>The total uptime of the webserver, in seconds.</desc>",
"&roxen.uptime-days;":"<desc ent>The total uptime of the webserver, in days.</desc>",
"&roxen.uptime-hours;":"<desc ent>The total uptime of the webserver, in hours.</desc>",
"&roxen.uptime-minutes;":"<desc ent>The total uptime of the webserver, in minutes.</desc>",
"&roxen.version;":"<desc ent>Which version of Roxen WebServer that is running.</desc>",

"&client;":#"<desc scope><short>
 This scope contains information specific to the client/browser that
 is accessing the page.</short>
</desc>",

"&page;":"<desc scope><short>This scope contains information specific to this page.</short></desc>",

"case":#"<desc cont><short>
 Alters the case of the contents.</short>
</desc>

<attr name=case value=upper|lower|capitalize required>
 Changes all characters to upper or lower case letters, or
 capitalizes the first letter in the content.
</attr>",

"cond":({ #"<desc cont><short hide>This tag makes a boolean test on a specified list of cases.</short>
 This tag is almost eqvivalent to the <tag>if</tag>/<tag>else</tag>
 tag combination. The main diffirence is that the <tag>default</tag>
 tag may be put whereever you want it within the <tag>cond</tag> tag.
 This will of course affect the order the content is parsed. The
 <tag>case</tag> tag is required.</desc>",

	  (["case":#"<desc cont>
 This tag takes the argument that is to be tested and if it's true,
 it's content is executed before exiting the <tag>cond</tag>. If the
 argument is false the content is skipped and the next <tag>case</tag>
 tag is parsed.</desc>

<ex type=vert>
<set variable=\"var.foo\" value=\"17\"/>
<cond>
  <case true>&var.foo;<set variable=\"var.foo\" expr=\"&var.foo;+1\"/></case>
  <default>&var.foo;<set variable=\"var.foo\" expr=\"&var.foo;+2\"/></default>
</cond>
&var.foo;
</ex>",

	    "default":#"<desc cont>
 The <tag>default</tag> tag is eqvivalent to the <tag>else</tag> tag
 in an <tag>if</tag> statement. The difference between the two is that
 the <tag>default</tag> may be put anywhere in the <tag>cond</tag>
 statement. This affects the parseorder of the statement. If the
 <tag>default</tag> tag is put first in the statement it will allways
 be executed, then the next <tag>case</tag> tag will be executed and
 perhaps add to the result the <tag>default</tag> performed.</desc>

<ex type=vert>
<set variable=\"var.foo\" value=\"17\"/>
<cond>
  <default>&var.foo;<set variable=\"var.foo\" expr=\"&var.foo;+2\"/></default>
  <case true>&var.foo;<set variable=\"var.foo\" expr=\"&var.foo;+1\"/></case>
</cond>
&var.foo;
</ex>
<br/>
<ex type=vert>
<set variable=\"var.foo\" value=\"17\"/>
<cond>
  <case false>&var.foo;<set variable=\"var.foo\" expr=\"&var.foo;+1\"/></case>
  <default>&var.foo;<set variable=\"var.foo\" expr=\"&var.foo;+2\"/></default>
</cond>
&var.foo;
</ex>"
	    ])
	  }),

"comment":#"<desc cont><short>
 The enclosed text will be removed from the document.</short> The difference
 from a normal SGML (HTML/XML) comment is that the text is removed
 from the document, and can not be seen even with view source. Another
 difference is that any RXML tags inside this container will not be
 parsed.
</desc>",

"define":({ #"<desc cont><short>
 Defines variables, tags, containers and if-callers.</short> One, and only one,
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
 Trim all white space characters from the begining and the end of the contents.
</attr>

The values of the attributes given to the defined tag are available in the
scope created within the define tag.

<ex><define tag=\"hi\">Hello &_.name;!</define>
<hi name=\"Martin\"/></ex>",

	    (["attrib":#"<desc cont>
 When defining a tag or a container the container <tag>attrib</tag>
 can be used to define default values of the attributes that the
 tag/container can have.</desc>

 <attr name=name value=name>
  The name of the attribute which default value is to be set.
 </attr>",

	      "&_.args;":#"<desc ent>The full list of the attributes, and their
 arguments, given to the tag.</desc>",
	      "&_.rest-args;":#"<desc ent>A list of the attributes, and their
 arguments, given to the tag, excluding attributes with default values defined.</desc>",
	      "&_.contents;":#"<desc ent>The containers contents.</desc>",
	      "contents":"<desc tag>As the contents entity, but unquoted.</desc>"
	    ])

}),

"else":#"<desc cont><short hide>
 Show the contents if the previous <if> tag didn't, or if there was a
 <false> tag above.</short>Show the contents if the previous <tag><ref
 type='tag'>if</ref></tag> tag didn't, or if there was a <tag><ref
 type='tag'>false</ref></tag> tag above. The result is undefined if there
 has been no <tag><ref type='tag'>if</ref></tag>, <true> or <tag><ref
 type='tag'>false</ref></tag> tag above. </desc>",

"elseif":#"<desc cont><short hide>
 Same as the <if> tag, but it will only evaluate if the previous <if>
 tag returned false.</short>Same as the <tag><ref
 type='tag'>if</ref></tag>, but it will only evaluate if the previous
 <tag><ref type='tag'>if</ref></tag> tag returned false. </desc>",

"false":#"<desc tag><short hide>
 Internal tag used to set the return value of <if> tags.
 </short>Internal tag used to set the return value of <tag><ref
 type='tag'>if</ref></tag> tags. It will ensure that the next
 <tag><ref type='tag'>else</ref></tag> tag will show its contents. It
 can be useful if you are writing your own <tag><ref
 type='tag'>if</ref></tag> lookalike tag. </desc>",

"help":#"<desc tag><short>
 Gives help texts for tags.</short> If given no arguments, it will
 list all available tags. By inserting <tag>help/</tag> in a page, a
 full index of the tags available in that particular Roxen WebServer
 will be presented. If a particular tag is missing from that index, it
 is not available at that moment. All tags are available through
 modules, hence that particular tags' module hasn't been added to the
 Roxen WebServer. Ask an administrator to add the module.
</desc>

<attr name=for value=tag>
 Gives the help text for that tag.
<ex type='vert'><help for='roxen'/></ex>
</attr>",

"if":#"<desc cont><short hide>
 <if> is used to conditionally show its contents.</short><tag><ref
 type='tag'>if</ref></tag> is used to conditionally show its contents.
 <tag><ref type='tag'>else</ref></tag>, <tag><ref
 type='tag'>elif</ref></tag> or <tag><ref
 type='tag'>elseif</ref></tag> can be used to suggest alternative
 content. It is possible to use glob patterns in almost all
 attributes, where * means match zero or more characters while ?
 matches one character. * Thus t*f?? will match trainfoo as well as *
 tfoo but not trainfork or tfo. </desc>

<attr name=not>
 Inverts the result (true->false, false->true).
</attr>
<attr name=or>
 If any criterion is met the result is true.
</attr>

<attr name=and>
 If all criterions are met the result is true. And is default.
</attr>

 <p>
 In the rxml.pike file the main if functionality is defined. There are
 two main types of if callers defined in rxml.pike,\"IfIs\" and \"IfMatch\".
 If the if caller is of an IfMatch type the if statement will be
 matched as a glob, i.e. * is considered a multicharacter wildcard.
 </p>

 <ex type=vert>Your domain <if ip=\"130.236.*\">is</if><else>isn't</else> liu.se.</ex>

 <p>
 If the if caller is of an IfIs type the if statement will be compared
 with one of the following operators is, =, ==, !=, &lt; and &gt. The
 operators is, = and == are the same.
 </p>
 <ex><set variable=x value=6>
<if variable=\"x > 5\">More than one hand</if></ex>",

"if#true":#"<desc plugin>
 This will always be true if the truth value is set to be true.
 Equivalent with <tag><ref type=cont>then</ref></tag>.
</desc>",

"if#false":#"<desc plugin>
 This will always be true if the truth value is set to be false.
 Equivalent with <tag><ref type='tag'>else</ref></tag>.
</desc>",

"if#accept":#"<desc plugin>
 Returns true is the browser accept certain content types as specified
 by it's Accept-header, for example image/jpeg or text/html. If
 browser states that it accepts */* that is not taken in to account as
 this is always untrue. Accept is an IfMatch if caller.
</desc>",

"if#config":#"<desc plugin>
 Has the config been set by use of the <tag><ref
 type='tag'>aconf</ref></tag> tag? (Config is an IfIs if caller,
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
 with the <tag><ref type='tag'>if</ref></tag>-statement.
</desc>",

"if#group":#"<desc plugin>
 Checks if the current user is a member of the group according
 the groupfile. Syntax is groupfile=path.
</desc>",

"if#ip":#"<desc plugin>
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

// The list of support flags is extracted from the supports database and
// concatenated to this entry.
"if#supports":#"<desc plugin>
 Does the browser support this feature? Supports is an IfIs if caller.
</desc>

The following features are supported:
",

"if#time":#"<desc plugin>
 Is the date ttmm? The attributes before, after and inclusive modifies
 the behavior.
</desc>

<attr name=after>
</attr>

<attr name=before>
</attr>

<attr name=inclusive>
</attr>",

"if#user":#"<desc plugin>
 Has the user been authenticated as one of these users? If any is given as
 argument, any authenticated user will do.
</desc>",

"if#variable":#"<desc plugin>
 Does the variable exist and, optionally, does it's content match the pattern?
 Variable is an IfIs plugin.
</desc>",

// The list of support flags is extracted from the supports database and
// concatenated to this entry.
"if#clientvar":#"<desc plugin>
 </desc>

 Available variables are:
",

"nooutput":#"<desc cont><short>
 The contents will not be sent through to the page.</short> Side effects, for
 example sending queries to databases, will take effect.
</desc>",

"noparse":#"<desc cont><short>
 The contents of this container tag won't be RXML parsed.</short>
</desc>",

"number":#"<desc tag><short>
 Prints a number as a word.</short>
</desc>

<attr name=num value=number required>
 Print this number.
<ex type='vert'><number num='4711'/></ex>
</attr>

<attr name=language value=langcodes>
 The language to use.
 <lang/>
<ex type='vert'>Mitt favoritnummer är <number num='11' language='sv'/>.</ex>
<ex type='vert'>My favorite number is <number num='21' language='en'/>.</ex>
<ex type='vert'>Il mio numero preferito &egrave;<number num='15' language='it'/>.</ex>
</attr>

<attr name=type value=number|ordered default=number>
 Sets output format.
<ex type='vert'>It was his <number num='15' type='ordered'/> birthday yesterday.</ex>
</attr>",

"strlen":#"<desc cont><short>
 Returns the length of the contents.</short>
</desc>",

"then":#"<desc cont><short>
 Shows its content if the truth-value is true.</short>
</desc>",

"trace":#"<desc cont><short>
 Executes the contained RXML code and makes a trace report about how
 the contents are parsed by the RXML parser.</short>
</desc>",

"true":#"<desc tag><short hide>
 An internal tag used to set the return value of <if> tags. </short>An
 internal tag used to set the return value of <tag><ref
 type='tag'>if</ref></tag> tags. It will ensure that the next
 <tag><ref type='tag'>else</ref></tag> tag will not show its contents.
 It can be useful if you are writing your own
 <tag><ref type='tag'>if</ref></tag> lookalike tag.
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

"use":#"<desc cont><short>
 Reads tags, container tags and defines from a file or package.
</short></desc>

<attr name=packageinfo>
 Show a all available packages.
</attr>

<attr name=package value=name>
 Reads all tags, container tags and defines from the given package.
 Packages are files located in local/rxml_packages/.
</attr>

<attr name=file value=path>
 Reads all tags and container tags and defines from the file.

 <p>This file will be fetched just as if someone had tried to fetch it
 with an HTTP request. This makes it possible to use Pike script
 results and other dynamic documents. Note, however, that the results
 of the parsing are heavily cached for performance reasons. If you do
 not want this cache, use <tag><ref type='tag'>insert file=...
 nocache</ref></tag> instead.</p>
</attr>

<attr name=info>
 Show a list of all defined tags/containers and if arguments in the file
</attr>
 The <tag><ref type='tag'>use</ref></tag> tag is much faster than the
 <tag><ref type='tag'>insert</ref></tag>, since the parsed definitions
 is cached.",

"eval":#"<desc cont><short>Postparses its content.</short> Useful when an entity contains
 RXML-code. <tag>eval</tag> is then placed around the entity to get its
 content parsed.</desc>",

"emit#sources":({
  "<desc plugin>Provides a list of all available emit sources.</desc>",
  ([ "&_.source;":"<desc ent>The name of the source.</desc>" ]) }),

"emit":#"<desc cont><short>Provides data, fetched from different sources, as
 entities</short></desc>

<attr name=source value=plugin required>
 The source from which the data should be fetched.
</attr>

<attr name=scope value=name default='The emit source'>
 The name of the scope within the emit tag.
</attr>

<attr name=maxrows value=number>
 Limits the number of rows to this maximum.
</attr>

<attr name=skiprows value=number>
 Makes it possible to skip the first rows of the result. Negative numbers means
 to skip everything execept the last n rows.
</attr>

<attr name=rowinfo value=variable>
 The number of rows in the result, after it has been limited by maxrows
 and skiprows, will be put in this variable, if given.
</attr>

<attr name=do-once>
 Indicate that at least one loop should be made. All variables in the
 emit scope will be empty.
</attr>",

]);
#endif
