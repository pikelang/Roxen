// The Roxen RXML Parser. See also the RXML Pike modules.
// Copyright � 1996 - 2000, Roxen IS.
//
// Per Hedbor, Henrik Grubbstr�m, Pontus Hagland, David Hedbor and others.
// New parser by Martin Stjernholm
// New RXML, scopes and entities by Martin Nilsson
//
// $Id: rxml.pike,v 1.288 2001/03/30 14:38:37 jenny Exp $


inherit "rxmlhelp";
#include <request_trace.h>
#include <config.h>

#ifndef manual
#define _stat defines[" _stat"]
#define _error defines[" _error"]
#define _extra_heads defines[" _extra_heads"]
#define _ok     defines[" _ok"]

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
  NOCACHE();
  id->misc->defines[" _ok"]=0;
#ifdef MODULE_DEBUG
  report_notice ("Error in %s.\n%s", id->not_query, describe_error (err));
#endif
  if (type->subtype_of (RXML.t_html) || type->subtype_of (RXML.t_xml))
    return "<br clear=\"all\" />\n<pre>" +
      Roxen.html_encode_string (describe_error (err)) + "</pre>\n";
  return describe_error (err);
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
  NOCACHE();
  id->misc->defines[" _ok"]=0;
#ifdef MODULE_DEBUG
  report_notice ("Error in %s.\n%s", id->not_query, describe_error (err));
#endif
  if (type->subtype_of (RXML.t_html) || type->subtype_of (RXML.t_xml))
    return "<br clear=\"all\" />\n<pre>" +
      Roxen.html_encode_string (describe_error (err)) + "</pre>\n";
  return describe_error (err);
}

#if ROXEN_COMPAT <= 1.3
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

#ifdef THREADS
  Thread.Mutex lists_mutex = Thread.Mutex();
  // Locks destructive changes to the arrays modules and imported.
#endif

  array(RoxenModule) modules;
  // Each element in the imported array is the registered tag set of a
  // parser module. This array contains the corresponding module
  // object.

  void sort_on_priority()
  {
#ifdef THREADS
    Thread.MutexKey lock = lists_mutex->lock();
#endif
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
// left out to default to its value in the current tag. ({1,�0,�0}) or
// ({1,�0,�0,�0}) may be shortened to ({1}).
//
// Note that there's no other way to handle tag overriding -- the page
// is no longer parsed multiple times.

string parse_rxml(string what, RequestID id,
		  void|Stdio.File file,
		  void|mapping defines )
// Note: Don't use this function to do recursive parsing inside an
// rxml parse session. The RXML module provides several different ways
// to accomplish that.
{
  id->misc->_rxml_recurse++;
#ifdef RXML_DEBUG
  report_debug("parse_rxml( "+strlen(what)+" ) -> ");
  int time = gethrtime();
#endif
  if(!defines)
    defines = id->misc->defines||([]);
  if(!_error)
    _error=200;
  if(!_extra_heads)
    _extra_heads=([ ]);
  if(!_stat) {
    if(id->misc->stat)
      _stat=id->misc->stat;
    else if(file)
      _stat=file->stat();
  }

  id->misc->defines = defines;

  RXML.PXml parent_parser = id->misc->_parser; // Don't count on that this exists.
  RXML.PXml parser;
  RXML.Context ctx;

  if (parent_parser && (ctx = parent_parser->context) && ctx->id == id) {
    parser = default_content_type->get_parser (ctx, 0, parent_parser);
    parser->recover_errors = parent_parser->recover_errors;
  }
  else {
    parser = rxml_tag_set (default_content_type, id);
    parser->recover_errors = 1;
    parent_parser = 0;
#if ROXEN_COMPAT <= 1.3
    if (old_rxml_compat) parser->context->compatible_scope = 1;
#endif
  }
  id->misc->_parser = parser;

  // Hmm, how does this propagation differ from id->misc? Does it
  // matter? This is only used by the compatibility code for old style
  // tags.
  parser->_defines = defines;
  parser->_source_file = file;

  if (mixed err = catch {
    if (parent_parser && ctx == RXML.get_context())
      parser->finish (what);
    else
      parser->write_end (what);
    what = parser->eval();
    parser->_defines = 0;
    id->misc->_parser = parent_parser;
  }) {
#ifdef DEBUG
    if (!parser) {
      report_debug("RXML: Parser destructed!\n");
#if constant(_describe)
      _describe(parser);
#endif /* constant(_describe) */
      error("Parser destructed!\n");
    }
#endif
    parser->_defines = 0;
    id->misc->_parser = parent_parser;
    if (objectp (err) && err->thrown_at_unwind)
      error ("Can't handle RXML parser unwinding in "
	     "compatibility mode (error=%O).\n", err);
    else throw (err);
  }

  if(sizeof(_extra_heads) && !id->misc->moreheads)
  {
    id->misc->moreheads= ([]);
    id->misc->moreheads |= _extra_heads;
  }
  id->misc->_rxml_recurse--;
#ifdef RXML_DEBUG
  report_debug("%d (%3.3fs)\n%s", strlen(what),(gethrtime()-time)/1000000.0,
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
  constant is_compat_tag=1;

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

    array do_enter (RequestID id)
    {
      if (args->preparse)
	content_type = content_type (RXML.PXml);
    }

    array do_return (RequestID id)
    {
      id->misc->line = "0";	// No working system for this yet.

      if (stringp (fn)) return ({fn});
      if (!fn) {
	result_type = result_type (RXML.PNone);
	return ({propagate_tag()});
      }

      Stdio.File source_file;
      mapping defines;
      if (id->misc->_parser) {
	source_file = id->misc->_parser->_source_file;
	defines = id->misc->_parser->_defines;
      }

      string|array(string) result;
      if (flags & RXML.FLAG_EMPTY_ELEMENT)
	result = fn (name, args, id, source_file, defines);
      else {
	if(args->trimwhites) content = String.trim_all_whites(content);
	result = fn (name, args, content, id, source_file, defines);
      }

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
      else {
	result_type = result_type (RXML.PNone);
	return ({propagate_tag()});
      }
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
      // Note: args may be zero here since this function is inherited
      // by GenericPITag.
      if (flags & RXML.FLAG_POSTPARSE)
	result_type = result_type (RXML.PXml);
      if (!(flags & RXML.FLAG_STREAM_CONTENT))
	piece = content || "";
      array|string res = _do_return(name, args, piece, id, this_object());
      return stringp (res) ? ({res}) : res;
    }
  }
}

class GenericPITag
{
  inherit GenericTag;

  void create (string _name, int _flags,
	       function(string,mapping(string:string),string,RequestID,RXML.Frame:
			array|string) __do_return)
  {
    ::create (_name, _flags | RXML.FLAG_PROC_INSTR, __do_return);
    content_type = RXML.t_text;
    // The content is always treated literally;
    // RXML.FLAG_DONT_PREPARSE has no effect.
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

  if (mod->query_simple_pi_tag_callers &&
      mappingp (defs = mod->query_simple_pi_tag_callers()) &&
      sizeof (defs))
    tag_set->add_tags (map (indices (defs),
			    lambda (string name) {
			      return GenericPITag (name, @defs[name]);
			    }));

  if (search (rxml_tag_set->imported, tag_set) < 0) {
#ifdef THREADS
    Thread.MutexKey lock = rxml_tag_set->lists_mutex->lock();
#endif
    rxml_tag_set->modules += ({mod});
    rxml_tag_set->imported += ({tag_set});
#ifdef THREADS
    lock = 0;
#endif
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
      array tags=map(indices(RXML.get_context()->tag_set->get_tag_names()),
		     lambda(string tag) {
		       if(tag[..3]=="!--#" || !has_value(tag, "#"))
			 return tag;
		       return "";
		     } ) - ({ "" });
      tags += map(indices(RXML.get_context()->tag_set->get_proc_instr_names()),
		  lambda(string tag) { return "&lt;?"+tag+"?&gt;"; } );
      tags = Array.sort_array(tags,
			      lambda(string a, string b) {
				if(a[..4]=="&lt;?") a=a[5..];
				if(b[..4]=="&lt;?") b=b[5..];
				if(lower_case(a)==lower_case(b)) return a>b;
				return lower_case(a)>lower_case(b); })-({"\x266a"});
      string help_for = args->for || id->variables->_r_t_h;
      string ret="<h2>Roxen Interactive RXML Help</h2>";

      if(!help_for) {
	string char;
	ret += "<b>Here is a list of all defined tags. Click on the name to "
	  "receive more detailed information. All these tags are also availabe "
	  "in the \""+RXML_NAMESPACE+"\" namespace.</b><p>\n";
	array tag_links;

	foreach(tags, string tag) {
	  if(tag[0]!='&' && lower_case(tag[0..0])!=char) {
	    if(tag_links && char!="/") ret+="<h3>"+upper_case(char)+"</h3>\n<p>"+
					 String.implode_nicely(tag_links)+"</p>";
	    char=lower_case(tag[0..0]);
	    tag_links=({});
	  }
	  if (tag[0]=='&' && lower_case(tag[5..5])!=char) {
	    if(tag_links && char!="/") ret+="<h3>"+upper_case(char)+"</h3>\n<p>"+
					 String.implode_nicely(tag_links)+"</p>";
	    char=lower_case(tag[5..5]);
	    tag_links=({});
	  }
	  if(tag[0..sizeof(RXML_NAMESPACE)]!=RXML_NAMESPACE+":") {
	    string enc=tag;
	    if(enc[0..4]=="&lt;?") enc="<?"+enc[5..sizeof(enc)-6];
	    if(undocumented_tags && undocumented_tags[tag])
	      tag_links += ({ tag });
	    else
	      tag_links += ({ sprintf("<a href=\"%s?_r_t_h=%s\">%s</a>\n",
				      id->not_query, Roxen.http_encode_url(enc), tag) });
	    }
	}

	ret+="<h3>"+upper_case(char)+"</h3>\n<p>"+String.implode_nicely(tag_links)+"</p>";
	/*
	ret+="<p><b>This is a list of all currently defined RXML scopes and their entities</b></p>";

	RXML.Context context=RXML.get_context();
	foreach(sort(context->list_scopes()), string scope) {
	  ret+=sprintf("<h3><a href=\"%s?_r_t_h=%s\">%s</a></h3>\n",
		       id->not_query, Roxen.http_encode_url("&"+scope+";"), scope);
	  ret+="<p>"+String.implode_nicely(Array.map(sort(context->list_var(scope)),
						       lambda(string ent) { return ent; }) )+"</p>";
	}
	*/
	return ({ ret });
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
      if(args->type=="roman") return ({ Roxen.int2roman((int)args->num) });
      if(args->type=="memory") return ({ Roxen.sizetostring((int)args->num) });
      result=roxen.language(args->lang||args->language||
                            id->misc->defines->theme_language,
			    args->type||"number",id)( (int)args->num );
    }
  }
}


class TagUse {
  inherit RXML.Tag;
  constant name = "use";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;

  private array(string) list_packages() { 
    return filter(((get_dir("../local/rxml_packages")||({}))
		   |(get_dir("rxml_packages")||({}))),
		  lambda( string s ) {
		    return s!=".cvsignore" &&
		      (Stdio.file_size("../local/rxml_packages/"+s)+
		       Stdio.file_size( "rxml_packages/"+s )) > 0;
		  });
  }

  private string read_package( string p ) {
    string data;
    p = combine_path("/", p);
    if(file_stat( "../local/rxml_packages/"+p ))
      catch(data=Stdio.File( "../local/rxml_packages/"+p, "r" )->read());
    if(!data && file_stat( "rxml_packages/"+p ))
      catch(data=Stdio.File( "rxml_packages/"+p, "r" )->read());
    return data;
  }

  private string use_file_doc(string f, string data) {
    string res, doc;
    int help; // If true, all tags support the 'help' argument.
    sscanf(data, "%*sdoc=\"%s\"", doc);
    sscanf(data, "%*shelp=%d", help);
    res = "<dt><b>"+f+"</b></dt><dd>"+(doc?doc+"<br />":"")+"</dd>";

    array pack = parse_use_package(data, RXML.get_context());
    cache_set("macrofiles", "|"+f, pack, 300);

    constant types = ({ "if plugin", "tag", "variable" });

    pack = pack + ({});
    pack[0] = indices(pack[0]);
    pack[1] = pack[1]->name;
    pack[2] = indices(pack[2])+indices(pack[3]);

    for(int i; i<3; i++)
      if(sizeof(pack[i])) {
	res += "Defines the following " + types[i] + (sizeof(pack[i])!=1?"s":"") +
	  ": " + String.implode_nicely( sort(pack[i]) ) + ".<br />";
      }

    if(help) res+="<br /><br />All tags accept the <i>help</i> attribute.";
    return res;
  }

  private array parse_use_package(string data, RXML.Context ctx) {
    array res = allocate(4);
    multiset before=ctx->get_runtime_tags();
    if(!ctx->id->misc->_ifs) ctx->id->misc->_ifs = ([]);
    mapping before_ifs = mkmapping(indices(ctx->id->misc->_ifs),
				   indices(ctx->id->misc->_ifs));
    mapping scope_form = mkmapping(ctx->list_var("form"),
				   map(ctx->list_var("form"),
				       lambda(string v) { return ctx->get_var(v, "form"); } ));
    mapping scope_var = mkmapping(ctx->list_var("var"),
				  map(ctx->list_var("var"),
				      lambda(string v) { return ctx->get_var(v, "var"); } ));

    parse_rxml( data, ctx->id );

    foreach( ctx->list_var("form"), string var ) {
      mixed val = ctx->get_var(var, "form");
      if(scope_form[var]==val)
	m_delete(scope_form, var);
      else
	scope_form[var]=val;
    }

    foreach( ctx->list_var("var"), string var ) {
      mixed val = ctx->get_var(var, "var");
      if(scope_var[var]==val)
	m_delete(scope_var, var);
      else
	scope_var[var]=val;
    }

    res[0] = ctx->id->misc->_ifs - before_ifs;
    res[1] = indices(RXML.get_context()->get_runtime_tags()-before);
    res[2] = scope_form;
    res[3] = scope_var;
    return res;
  }

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      if(args->packageinfo) {
	NOCACHE();
	string res ="<dl>";
	foreach(list_packages(), string f)
	  res += use_file_doc(f, read_package( f ));
	return ({ res+"</dl>" });
      }

      if(!args->file && !args->package)
	parse_error("No file or package selected.\n");

      array res;
      string name, filename;
      if(args->file)
      {
	filename = Roxen.fix_relative(args->file, id);
	name = id->conf->get_config_id() + "|" + filename;
      }
      else
	name = "|" + args->package;
      RXML.Context ctx = RXML.get_context();

      if(args->info || id->pragma["no-cache"] ||
	 !(res=cache_lookup("macrofiles",name)) ) {

	string file;
	if(filename)
	  file = id->conf->try_get_file( filename, id );
	else
	  file = read_package( args->package );

	if(!file)
	  run_error("Failed to fetch "+(args->file||args->package)+".\n");

	if( args->info )
	  return ({"<dl>"+use_file_doc( args->file || args->package, file )+"</dl>"});

	res = parse_use_package(file, ctx);
	cache_set("macrofiles", name, res);
      }

      id->misc->_ifs += res[0];
      foreach(res[1], RXML.Tag tag)
	ctx->add_runtime_tag(tag);
      foreach(indices(res[2]), string var)
	ctx->set_var(var, res[2][var], "form");
      foreach(indices(res[3]), string var)
	ctx->set_var(var, res[3][var], "var");

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
    if(tag) flags=RXML.FLAG_EMPTY_ELEMENT;
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

#if ROXEN_COMPAT <= 1.3
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
  constant flags = RXML.FLAG_DONT_REPORT_ERRORS;

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
#if ROXEN_COMPAT <= 1.3
	n = old_rxml_compat?lower_case(n):n;
#endif
	int tag=0;
	if(args->tag) {
	  tag=1;
	  m_delete(args, "tag");
	} else
	  m_delete(args, "container");

	mapping defaults=([]);

#if ROXEN_COMPAT <= 1.3
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

#if ROXEN_COMPAT <= 1.3
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

#if ROXEN_COMPAT <= 1.3
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

#if ROXEN_COMPAT <= 1.3
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
  // Note: \n is used sparingly in output to make it look nice even
  // inside <pre>.
  string resolv="<ol>";
  int level;

  string _sprintf()
  {
    return "Tracer()";
  }

#if constant (gethrtime)
  mapping et = ([]);
#endif
#if constant (gethrvtime)
  mapping et2 = ([]);
#endif

  local void start_clock()
  {
#if constant (gethrvtime)
    et2[level] = gethrvtime();
#endif
#if constant (gethrtime)
    et[level] = gethrtime();
#endif
  }

  local string stop_clock()
  {
    string res;
#if constant (gethrtime)
    res = sprintf("%.5f", (gethrtime() - et[level])/1000000.0);
#else
    res = "";
#endif
#if constant (gethrvtime)
    res += sprintf(" (CPU = %.2f)", (gethrvtime() - et2[level])/1000000.0);
#endif
    return res;
  }

  void trace_enter_ol(string type, function|object thing)
  {
    level++;

    if (thing) {
      string name = Roxen.get_modfullname (Roxen.get_owning_module (thing));
      if (name)
	name = "module " + name;
      else if (this_program conf = Roxen.get_owning_config (thing))
	name = "configuration " + Roxen.html_encode_string (conf->query_name());
      else
	name = Roxen.html_encode_string (sprintf ("object %O", thing));
      type += " in " + name;
    }

    string efont="", font="";
    if(level>2) {efont="</font>";font="<font size=-1>";}

    resolv += font + "<li><b>�</b> " + type + "<ol>" + efont;
    start_clock();
  }

  void trace_leave_ol(string desc)
  {
    level--;

    string efont="", font="";
    if(level>1) {efont="</font>";font="<font size=-1>";}

    resolv += "</ol>" + font;
    if (sizeof (desc))
      resolv += "<b>�</b> " + Roxen.html_encode_string(desc);
    string time = stop_clock();
    if (sizeof (time)) {
      if (sizeof (desc)) resolv += "<br />";
      resolv += "<i>Time: " + time + "</i>";
    }
    resolv += efont + "</li>\n";
  }

  string res()
  {
    while(level>0) trace_leave_ol("");
    return resolv + "</ol>";
  }
}

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
      t->start_clock();
      return 0;
    }

    array do_return(RequestID id) {
      id->misc->trace_enter = a;
      id->misc->trace_leave = b;
      result = "<h3>Tracing</h3>" + content +
	"<h3>Trace report</h3>" + t->res();
      string time = t->stop_clock();
      if (sizeof (time))
	result += "<h3>Total time: " + time + "</h3>";
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

class TagPINoParse {
  inherit TagNoParse;
  constant flags = RXML.FLAG_PROC_INSTR;
  class Frame {
    inherit RXML.Frame;
    array do_return(RequestID id) {
      result = content[1..];
      return 0;
    }
  }
}

class TagPICData
{
  inherit RXML.Tag;
  constant name = "cdata";
  constant flags = RXML.FLAG_PROC_INSTR;
  RXML.Type content_type = RXML.t_text;
  class Frame
  {
    inherit RXML.Frame;
    array do_return (RequestID id)
    {
      result_type = RXML.t_text;
      result = content[1..];
      return 0;
    }
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
  constant flags = RXML.FLAG_DONT_REPORT_ERRORS;

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
  constant flags = RXML.FLAG_DONT_REPORT_ERRORS;

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
      if(args->case) {
	string op;
	switch(lower_case(args->case)) {
	  case "lower":
	    if (content_type->lower_case)
	      return ({content_type->lower_case (content)});
	    op = "lowercased";
	    break;
	  case "upper":
	    if (content_type->upper_case)
	      return ({content_type->upper_case (content)});
	    op = "uppercased";
	    break;
	  case "capitalize":
	    if (content_type->capitalize) {
	      if(cap) return ({content});
	      if (sizeof (content)) cap=1;
	      return ({content_type->capitalize (content)});
	    }
	    op = "capitalized";
	    break;
	  default:
	    // FIXME: 2.1 compat: Not an error.
	    parse_error ("Invalid value %O to the case argument.\n", args->case);
	}
	// FIXME: 2.1 compat: Not an error.
	parse_error ("Content of type %s doesn't handle being %s.\n",
		     content_type->name, op);
      }

#if ROXEN_COMPAT <= 1.3
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
  RXML.Type content_type = RXML.t_nil (RXML.PXml);
  array(RXML.Type) result_types = ({RXML.t_any});

  class TagCase
  {
    inherit RXML.Tag;
    constant name = "case";
    array(RXML.Type) result_types = ({RXML.t_nil});

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
    array(RXML.Type) result_types = ({RXML.t_nil});

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
  constant flags = RXML.FLAG_SOCKET_TAG|RXML.FLAG_DONT_REPORT_ERRORS;
  mapping(string:RXML.Type) req_arg_types = (["source":RXML.t_text(RXML.PEnt)]);

  int(0..1) should_filter(mapping vs, mapping filter) {
    foreach(indices(filter), string v) {
      if(!vs[v])
	return 1;
      if(!glob(filter[v], vs[v]))
	return 1;
    }
    return 0;
  }

  class TagDelimiter {
    inherit RXML.Tag;
    constant name = "delimiter";

    static int(0..1) more_rows(array|object res, mapping filter) {
      if(objectp(res)) {
	while(res->peek() && should_filter(res->peek(), filter))
	  res->skip_row();
	return !!res->peek();
      }
      if(!sizeof(res)) return 0;
      foreach(res[RXML.get_var("real-counter")..], mapping v) {
	if(!should_filter(v, filter))
	  return 1;
      }
      return 0;
    }

    class Frame {
      inherit RXML.Frame;

      array do_return(RequestID id) {
	object|array res = id->misc->emit_rows;
	if(!id->misc->emit_filter) {
	  if( objectp(res) ? res->peek() :
	      RXML.get_var("counter") < sizeof(res) )
	    result = content;
	  return 0;
	}
	if(id->misc->emit_args->maxrows &&
	   (int)id->misc->emit_args->maxrows == RXML.get_var("counter"))
	  return 0;
	if(more_rows(res, id->misc->emit_filter))
	  result = content;
	return 0;
      }
    }
  }

  RXML.TagSet internal = RXML.TagSet("TagEmit.internal", ({ TagDelimiter() }) );

  // A slightly modified Array.dwim_sort_func
  // used as emits sort function.
  static int compare(string a0,string b0) {
    if (!a0) {
      if (b0)
	return -1;
      return 0;
    }

    if (!b0)
      return 1;

    string a2="",b2="";
    int a1,b1;
    sscanf(a0,"%s%d%s",a0,a1,a2);
    sscanf(b0,"%s%d%s",b0,b1,b2);
    if (a0>b0) return 1;
    if (a0<b0) return -1;
    if (a1>b1) return 1;
    if (a1<b1) return -1;
    if (a2==b2) return 0;
    return compare(a2,b2);
  }

  class Frame {
    inherit RXML.Frame;
    RXML.TagSet additional_tags = internal;
    string scope_name;
    mapping vars;

    // These variables are used to store id->misc-variables
    // that otherwise would be overwritten when emits are
    // nested.
    array(mapping(string:mixed))|object outer_rows;
    mapping outer_filter;
    mapping outer_args;

    object plugin;
    array(mapping(string:mixed))|object res;
    mapping filter;

    array expand(object res) {
      array ret = ({});
      do {
	ret += ({ res->get_row() });
      } while(ret[-1]!=0);
      return ret[..sizeof(ret)-2];
    }

    array do_enter(RequestID id) {
      if(!(plugin=get_plugins()[args->source]))
	parse_error("The emit source %O doesn't exist.\n", args->source);
      scope_name=args->scope||args->source;
      vars = (["counter":0]);

      TRACE_ENTER("Fetch emit dataset for source "+args->source, 0);
      res=plugin->get_dataset(args, id);
      TRACE_LEAVE("");

      if(plugin->skiprows && args->skiprows)
	m_delete(args, "skiprows");
      if(args->maxrows) {
	if(plugin->maxrows)
	  m_delete(args, "maxrows");
	else
	  args->maxrows = (int)args->maxrows;
      }

      // Parse the filter argument
      if(args->filter) {
	array pairs = args->filter / ",";
	filter = ([]);
	foreach( args->filter / ",", string pair) {
	  string v,g;
	  if( sscanf(pair, "%s=%s", v,g) != 2)
	    continue;
	  v = String.trim_whites(v);
	  if(g != "*"*sizeof(g))
	    filter[v] = g;
	}
	if(!sizeof(filter)) filter = 0;
      }

      outer_args = id->misc->emit_args;
      outer_rows = id->misc->emit_rows;
      outer_filter = id->misc->emit_filter;
      id->misc->emit_args = args;
      id->misc->emit_filter = filter;

      if(objectp(res))
	if(args->sort ||
	   (args->skiprows && args->skiprows[0]=='-') )
	  res = expand(res);
	else if(filter) {
	  do_iterate = object_filter_iterate;
	  id->misc->emit_rows = res;
	  if(args->skiprows) args->skiprows = (int)args->skiprows;
	  return 0;
	}
	else {
	  do_iterate = object_iterate;
	  id->misc->emit_rows = res;

	  if(args->skiprows) {
	    int loop = (int)args->skiprows;
	    while(loop--)
	      res->skip_row();
	  }

	  return 0;
	}

      if(arrayp(res)) {
	if(args->sort && !plugin->sort)
	{
	  array(string) order = (args->sort - " ")/"," - ({ "" });
	  res = Array.sort_array( res,
				  lambda (mapping(string:string) m1,
					  mapping(string:string) m2)
				  {
				    foreach (order, string field)
				    {
				      int(-1..1) tmp;
				      
				      if (field[0] == '-')
					tmp = compare( m2[field[1..]],
						       m1[field[1..]] );
				      else if (field[0] == '+')
					tmp = compare( m1[field[1..]],
						       m2[field[1..]] );
				      else
					tmp = compare( m1[field], m2[field] );

				      if (tmp == 1)
					return 1;
				      else if (tmp == -1)
					return 0;
				    }
				    return 0;
				  } );
	}

	if(filter) {

	  // If rowinfo or negative skiprows are used we have
	  // to do filtering in a loop of its own, instead of
	  // doing it during the emit loop.
	  if(args->rowinfo ||
	     (args->skiprows && args->skiprows[-1]=='-')) {
	    for(int i; i<sizeof(res); i++)
	      if(should_filter(res[i], filter)) {
		res = res[..i-1] + res[i+1..];
		i--;
	      }
	    filter = 0;
	  }
	  else {

	    // If skiprows is to be used we must only count
	    // the rows that wouldn't be filtered in the
	    // emit loop.
	    if(args->skiprows) {
	      int skiprows = (int)args->skiprows;
	      if(skiprows > sizeof(res))
		res = ({});
	      else {
		int i;
		for(; i<sizeof(res) && skiprows; i++)
		  if(!should_filter(res[i], filter))
		    skiprows--;
		res = res[i..];
	      }
	    }

	    vars["real-counter"] = 0;
	    do_iterate = array_filter_iterate;
	  }
	}

	// We have to check the filter again, since it
	// could have been zeroed in the last if statement.
	if(!filter) {

	  if(args->skiprows) {
	    if(args->skiprows[0]=='-') args->skiprows=sizeof(res)+(int)args->skiprows;
	    res=res[(int)args->skiprows..];
	  }

	  if(args->remainderinfo)
	    RXML.user_set_var(args->remainderinfo, args->maxrows?
			      max(sizeof(res)-args->maxrows, 0): 0);

	  if(args->maxrows) res=res[..args->maxrows-1];
	  if(args["do-once"] && sizeof(res)==0) res=({ ([]) });

	  do_iterate = array_iterate;
	}

	id->misc->emit_rows = res;

	return 0;
      }

      parse_error("Wrong return type from emit source plugin.\n");
    }

    int(0..1) do_once_more() {
      if(vars->counter || !args["do-once"]) return 0;
      vars = (["counter":1]);
      return 1;
    }

    function do_iterate;

    int(0..1) object_iterate(RequestID id) {
      int counter = vars->counter;

      if(args->maxrows && counter == args->maxrows)
	return do_once_more();

      if(mappingp(vars=res->get_row())) {
	vars->counter = ++counter;
	return 1;
      }

      vars = (["counter":counter]);
      return do_once_more();
    }

    int(0..1) object_filter_iterate(RequestID id) {
      int counter = vars->counter;

      if(args->maxrows && counter == args->maxrows)
	return do_once_more();

      if(args->skiprows>0)
	while(args->skiprows-->-1)
	  while((vars=res->get_row()) &&
		should_filter(vars, filter));
      else
	while((vars=res->get_row()) &&
	      should_filter(vars, filter));

      if(mappingp(vars)) {
	vars->counter = ++counter;
	return 1;
      }

      vars = (["counter":counter]);
      return do_once_more();
    }

    int(0..1) array_iterate(RequestID id) {
      int counter=vars->counter;
      if(counter>=sizeof(res)) return 0;
      vars=res[counter++];
      vars->counter=counter;
      return 1;
    }

    int(0..1) array_filter_iterate(RequestID id) {
      int real_counter = vars["real-counter"];
      int counter = vars->counter;

      if(real_counter>=sizeof(res)) return do_once_more();

      if(args->maxrows && counter == args->maxrows)
	return do_once_more();

      while(should_filter(res[real_counter++], filter))
	if(real_counter>=sizeof(res)) return do_once_more();

      vars=res[real_counter-1];

      vars["real-counter"] = real_counter;
      vars->counter = counter+1;
      return 1;
    }

    array do_return(RequestID id) {
      result = content;

      id->misc->emit_rows = outer_rows;
      id->misc->emit_filter = outer_filter;
      id->misc->emit_args = outer_args;

      int rounds = vars->counter - !!args["do-once"];
      if(args->rowinfo)
	RXML.user_set_var(args->rowinfo, rounds);
      LAST_IF_TRUE = !!rounds;

      if(args->remainderinfo) {
	if(args->filter) {
	  int rem;
	  if(arrayp(res)) {
	    foreach(res[vars["real-counter"]+1..], mapping v)
	      if(!should_filter(v, filter))
		rem++;
	  } else {
	    mapping v;
	    while( v=res->get_row() )
	      if(!should_filter(v, filter))
		rem++;
	  }
	  RXML.user_set_var(args->remainderinfo, rem);
	}
	else if( do_iterate == object_iterate )
	  RXML.user_set_var(args->remainderinfo, res->num_rows_left());
      }
      return 0;
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


class TagPathplugin
{
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "path";

  array get_dataset(mapping m, RequestID id)
  {
    string fp = "";
    array res = ({});
    string p = m->path || id->not_query;
    if( m->trim )
      sscanf( p, "%s"+m->trim, p );
    if( p[-1] == '/' )
      p = p[..strlen(p)-2];
    array q = p / "/";
    if( m->skip )
      q = q[(int)m->skip..];
    if( m["skip-end"] )
      q = q[..sizeof(q)-((int)m["skip-end"]+1)];
    foreach( q, string elem )
    {
      fp += "/" + elem;
      fp = replace( fp, "//", "/" );
      res += ({
        ([
          "name":elem,
          "path":fp
        ])
      });
    }
    return res;
  }
}

class TagEmitValues {
  inherit RXML.Tag;
  constant name="emit";
  constant plugin_name="values";

  array(mapping(string:string)) get_dataset(mapping m, RequestID id) {
    if(m["from-scope"]) {
      m->values=([]);
      RXML.Context context=RXML.get_context();
      map(context->list_var(m["from-scope"]),
	  lambda(string var){ m->values[var]=context->get_var(var, m["from-scope"]);
	  return ""; });
    }

    if( m->variable )
      m->values = RXML.get_context()->user_get_var( m->variable );

    if(!m->values)
      return ({});

    if(stringp(m->values)) {
      if(m->advanced) {
	switch(m->advanced) {
	case "chars":
	  m->split="";
	  break;
	case "lines":
	  m->values = replace(m->values, ({ "\n\r", "\r\n", "\r" }),
			      ({ "\n", "\n", "\n" }));
	  m->split = "\n";
	  break;
	case "words":
	  m->values = replace(m->values, ({ "\n\r", "\r\n", "\r" }),
			      ({ "\n", "\n", "\n" }));
	  m->values = replace(m->values, ({ "-\n", "\n", "\t" }),
			      ({ "", " ", " " }));
	  m->values = map(m->values/" " - ({""}),
			  lambda(string word) {
			    if(word[-1]=='.' || word[-1]==',' || word[-1]==';' ||
			       word[-1]==':' || word[-1]=='!' || word[-1]=='?')
			      return word[..sizeof(word)-2];
			    return word;
			  });
	  break;
	}
      }
      m->values=m->values / (m->split || "\000");
    }

    if(mappingp(m->values))
      return map( indices(m->values),
		  lambda(mixed ind) { return (["index":ind,"value":m->values[ind]]); });

    if(arrayp(m->values))
      return map( m->values,
		  lambda(mixed val) {
		    if(m->trimwhites) val=String.trim_all_whites((string)val);
		    if(m->case=="upper") val=upper_case(val);
		    else if(m->case=="lower") val=lower_case(val);
		    return (["value":val]);
		  } );

    RXML.run_error("Values variable has wrong type %t.\n", m->values);
  }
}

class TagComment {
  inherit RXML.Tag;
  constant name = "comment";
  constant flags = RXML.FLAG_DONT_REPORT_ERRORS;
  class Frame {
    inherit RXML.Frame;
    int do_iterate=-1;
    array do_enter() {
      if(args && args->preparse)
	do_iterate=1;
      return 0;
    }
    array do_return = ({});
  }
}

class TagPIComment
{
  inherit TagComment;
  constant flags = RXML.FLAG_PROC_INSTR;
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
  constant case_sensitive = 0;
  function source;

  int eval( string value, RequestID id )
  {
    if(cache != -1) CACHE(cache);
    array arr=value/" ";
    string|int|float var=source(id, arr[0]);
    if( !var && zero_type( var ) ) return 0;
    if(sizeof(arr)<2) return !!var;
    string is;
    if(case_sensitive) {
      var = var+"";
      if(sizeof(arr)==1) return !!var;
      is=arr[2..]*" ";
    }
    else {
      var = lower_case( (var+"") );
      if(sizeof(arr)==1) return !!var;
      is=lower_case(arr[2..]*" ");
    }

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
    if(cache != -1) CACHE(cache);
    if(!value) return 0;
    if(arrayp(value)) value=value*" ";
    value = lower_case( value );
    is = lower_case( "*"+is+"*" );
    return glob(is,value) || sizeof(filter( is/",", glob, value ));
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
    c=localtime(time(1));

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

  int eval(string u, RequestID id, mapping m)
  {
    object db;
    if( m->database )
      db = id->conf->find_user_database( m->database );
    User uid = id->conf->authenticate( id, db );

    if( !uid && !id->auth )
      return 0;

    NOCACHE();

    if( u == "any" )
      if( m->file )
	// Note: This uses the compatibility interface. Should probably
	// be fixed.
	return match_user( id->auth, id->auth[1], m->file, !!m->wwwfile, id);
      else
	return !!u;
    else
      if(m->file)
	// Note: This uses the compatibility interface. Should probably
	// be fixed.
	return match_user(id->auth,u,m->file,!!m->wwwfile,id);
      else
	return has_value(u/",", uid->name());
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
    object db;
    if( m->database )
      db = id->conf->find_user_database( m->database );
    User uid = id->conf->authenticate( id, db );

    if( !uid && !id->auth )
      return 0;

    NOCACHE();
    if( m->groupfile )
      return ((m->groupfile && sizeof(m->groupfile))
	      && group_member(id->auth, u, m->groupfile, id));
    return sizeof( uid->groups() & (u/"," )) > 0;
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

class TagIfNserious {
  inherit RXML.Tag;
  constant name = "if";
  constant plugin_name = "nserious";

  int eval() {
#ifdef NSERIOUS
    return 1;
#else
    return 0;
#endif
  }
}

class TagIfModule {
  inherit RXML.Tag;
  constant name = "if";
  constant plugin_name = "module";

  int eval(string u, RequestID id) {
    if (!sizeof(u)) return 0;
    return sizeof(glob(u+"#*", indices(id->conf->enabled_modules)));
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

#if ROXEN_COMPAT <= 1.3
class TagIfName {
  inherit TagIfClient;
  constant plugin_name = "name";
}
#endif

class TagIfDefined {
  inherit IfIs;
  constant plugin_name = "defined";
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

#if ROXEN_COMPAT <= 1.3
class TagIfHost {
  inherit TagIfIP;
  constant plugin_name = "host";
}
#endif

class TagIfLanguage {
  inherit IfMatch;
  constant plugin_name = "language";
  array source(RequestID id) {
    return id->misc->pref_languages->get_languages();
  }
}

class TagIfMatch {
  inherit IfIs;
  constant plugin_name = "match";
  string source(RequestID id, string s) {
    return s;
  }
}

class TagIfMaTcH {
  inherit TagIfMatch;
  constant plugin_name = "Match";
  constant case_sensitive = 1;
}

class TagIfPragma {
  inherit IfIs;
  constant plugin_name = "pragma";
  int source(RequestID id, string s) {
    return id->pragma[s];
  }
}

class TagIfPrestate {
  inherit IfIs;
  constant plugin_name = "prestate";
  constant cache = -1;
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
    return RXML.t_text->encode (var);
  }
}

class TagIfVaRiAbLe {
  inherit TagIfVariable;
  constant plugin_name = "Variable";
  constant case_sensitive = 1;
}

class TagIfSizeof {
  inherit IfIs;
  constant plugin_name = "sizeof";
  constant cache = -1;
  int source(RequestID id, string s) {
    mixed var=RXML.user_get_var(s);
    if(!var) {
      if(zero_type(RXML.user_get_var(s))) return 0;
      return 1;
    }
    if(stringp(var) || arrayp(var) ||
       multisetp(var) || mappingp(var)) return sizeof(var);
    if(objectp(var) && var->_sizeof) return sizeof(var);
    return sizeof((string)var);
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

static int format_support(string t, mapping m, string c, mapping doc) {
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
"&roxen;":#"<desc scope='scope'><p><short>
 This scope contains information specific to this Roxen
 WebServer.</short> It is not possible to write any information to
 this scope
</p></desc>",

"&roxen.domain;":#"<desc ent='ent'><p>
 The domain name of this site.
</p></desc>",

"&roxen.hits;":#"<desc ent='ent'><p>
 The number of hits, i.e. requests the webserver has accumulated since
 it was last started.
</p></desc>",
"&roxen.hits-per-minute;":#"<desc ent='ent'><p>
 The number of hits per minute, in average.
</p></desc>",

"&roxen.pike-version;":#"<desc ent='ent'><p>
 The version of Pike the webserver is using.
</p></desc>",

"&roxen.sent;":#"<desc ent='ent'><p>
The total amount of data the webserver has sent.
</p></desc>",

"&roxen.sent-kbit-per-second;":#"<desc ent='ent'><p>
The average amount of data the webserver has sent, in
Kibibits.
</p></desc>",

"&roxen.sent-mb;":#"<desc ent='ent'><p>
 The total amount of data the webserver has sent, in
 Mebibits.
</p></desc>",

"&roxen.sent-per-minute;":#"<desc ent='ent'><p>



</p></desc>",

"&roxen.server;":#"<desc ent='ent'><p>
 The URL of the webserver.
</p></desc>",

"&roxen.ssl-strength;":#"<desc ent='ent'><p>
 How many bits encryption strength are the SSL capable of
</p></desc>",

"&roxen.time;":#"<desc ent='ent'><p>
 The current posix time.
</p></desc>",

"&roxen.uptime;":#"<desc ent='ent'><p>
 The total uptime of the webserver, in seconds.
</p></desc>",

"&roxen.uptime-days;":#"<desc ent='ent'><p>
 The total uptime of the webserver, in days.
</p></desc>",

"&roxen.uptime-hours;":#"<desc ent='ent'><p>
 The total uptime of the webserver, in hours.
</p></desc>",

"&roxen.uptime-minutes;":#"<desc ent='ent'><p>
 The total uptime of the webserver, in minutes.
</p></desc>",

"&client;":#"<desc scope='scope'><p><short>
 This scope contains information specific to the client/browser that
 is accessing the page.</short>
</p></desc>",

"&page;":#"<desc scope='scope'><p><short>
 This scope contains information specific to this page.</short></p>
</desc>",

"&form;":#"<desc scope='scope'><p><short hide='hide'>
 This scope contains form variables.</short>This scope contains the
 form variables, i.e. the answers to HTML forms sent by the client.
 There are no predefined entities for this scope.
</p></desc>",

"&cookie;":#"<desc scope='scope'><p><short>
 This scope contains the cookies sent by the client.</short> Adding,
 deleting or changing in this scope updates the clients cookies. There
 are no predefined entities for this scope. When adding cookies to
 this scope they are automatically set to expire after two years.
</p></desc>",

"&var;":#"<desc scope='scope'><p><short>
 This scope is empty when the page parsing begins.</short> There are
 no predefined entities for this
</p></desc>",

"case":#"<desc cont='cont'><p><short>
 Alters the case of the contents.</short>
</p></desc>

<attr name='case' value='upper|lower|capitalize' required='required'><p>
 Changes all characters to upper or lower case letters, or
 capitalizes the first letter in the content.</p>

<ex><case upper=''>upper</case></ex>
<ex><case lower=''>lower</case></ex>
<ex><case capitalize=''>capitalize</case></ex>
</attr>",

"cond":({ #"<desc cont='cont'><p><short>
 This tag makes a boolean test on a specified list of cases.</short>
 This tag is almost eqvivalent to the <xref href='../if/if.tag'
 />/<xref href='../if/else.tag' /> combination. The main difference is
 that the <tag>default</tag> tag may be put whereever you want it
 within the <tag>cond</tag> tag. This will of course affect the order
 the content is parsed. The <tag>case</tag> tag is required.</p>
</desc>",

	  (["case":#"<desc cont='cont'><p>
 This tag takes the argument that is to be tested and if it's true,
 it's content is executed before exiting the <tag>cond</tag>. If the
 argument is false the content is skipped and the next <tag>case</tag>
 tag is parsed.</p></desc>

<ex type='box'>
<cond>
 <case variable='form.action = edit'>
   some database edit code
 </case>
 <case variable='form.action = delete'>
   some database delete code
 </case>
 <default>
   view something from the database
 </default>
</cond>
</ex>",

	    "default":#"<desc cont='cont'><p>
 The <tag>default</tag> tag is eqvivalent to the <tag>else</tag> tag
 in an <tag>if</tag> statement. The difference between the two is that
 the <tag>default</tag> may be put anywhere in the <tag>cond</tag>
 statement. This affects the parseorder of the statement. If the
 <tag>default</tag> tag is put first in the statement it will allways
 be executed, then the next <tag>case</tag> tag will be executed and
 perhaps add to the result the <tag>default</tag> performed.</p></desc>"
	    ])
	  }),

"comment":#"<desc cont='cont'><p><short>
 The enclosed text will be removed from the document.</short> The
 difference from a normal SGML (HTML/XML) comment is that the text is
 removed from the document, and can not be seen even with <i>view
 source</i> in the browser.</p>

 <p>Note that since this is a normal tag, it requires that the content
 is properly formatted. Therefore it's ofter better to use the
 &lt;?comment&nbsp;...&nbsp;?&gt; processing instruction tag to
 comment out arbitrary text (which doesn't contain '?&gt;').</p>

 <p>Just like any normal tag, the <tag>comment</tag> tag nests inside
 other <tag>comment</tag> tags. E.g:</p>

 <ex>
   <comment> a <comment> b </comment> c </comment>
 </ex>

 <p>Here 'c' is not output since the comment starter before 'a'
 matches the ender after 'c' and not the one before it.</p>
</desc>

<attr name='preparse'>
 Parse and execute any RXML inside the comment tag. This can be used
 to do stuff without producing any output in the response. This is a
 compatibility argument; the recommended way is to use <ref
 type='tag'><tag>nooutput</tag> instead.
</attr>",


"?comment":#"<desc pi='pi'><p><short>
 Processing instruction tag for comments.</short> This tag is similar
 to the RXML <ref type='tag'><tag>comment</tag> tag but should be used
 when commenting arbitrary text that doesn't contain '?&gt;'.
</desc>",

// <cset> is deprecated. This information is to be put in a special
// 'deprecated' chapter in the manual, due to many persons asking
// about its whereabouts.
"cset":#"<desc tag='tag'><p><short>
 Deprecated in favor of <tag>define variable</tag></short> Deprecated
 in Roxen 2.0.
</p></desc>",

"define":({ #"<desc cont='cont'><p><short>

 Defines variables, tags, containers and if-callers.</short> This tag
 can also be used to redefine existing HTML-tags. Note that everything
 defined by this tag are locally for the document they exist in, not
 globally like variables or tags defined in Roxen-modules are.
</p></desc>

<attr name='variable' value='name'><p>
 Sets the value of the variable to the contents of the container.</p>
</attr>

<attr name='tag' value='name'><p>
 Defines a tag that outputs the contents of the container.</p>
</attr>

<attr name='container' value='name'><p>
 Defines a container that outputs the contents of the container.</p>
</attr>

<attr name='if' value='name'><p>
 Defines an if-caller that compares something with the contents of the
 container.</p>
</attr>

<attr name='trimwhites'><p>
 Trim all white space characters from the beginning and the end of the
 contents.</p>
</attr>

 <p>The values of the attributes given to the defined tag are
 available in the scope created within the define tag.</p>

<ex><define tag=\"hi\">Hello <ent>_.name</ent>!</define>
<hi name=\"Martin\"/></ex>",


	    ([
"attrib":#"<desc cont='cont'><p>
 When defining a tag or a container the container <tag>attrib</tag>
 can be used to define default values of the attributes that the
 tag/container can have.</p>
</desc>

 <attr name='name' value='name'><p>
  The name of the attribute which default value is to be set.</p>
 </attr>",

"&_.args;":#"<desc ent='ent'><p>
 The full list of the attributes, and their arguments, given to the
 tag.
</p></desc>",

"&_.rest-args;":#"<desc ent='ent'><p>
 A list of the attributes, and their arguments, given to the tag,
 excluding attributes with default values defined.
</p></desc>",

"&_.contents;":#"<desc ent='ent'><p>
 The containers contents.
</p></desc>",

"contents":#"<desc tag='tag'><p>
 As the contents entity, but unquoted.
</p></desc>"
	    ])

}),

"else":#"<desc cont='cont'><p><short>

 Show the contents if the previous <xref href='if.tag' /> tag didn't,
 or if there was a <xref href='false.tag' /> tag above.</short> This
 tag also detects if the page's truthvalue has been set to false.
 <xref href='../output/emit.tag' /> is an example of a tag that may
 change a page's truthvalue.</p>

 <p>The result is undefined if there has been no <xref href='if.tag'
 />, <xref href='true.tag' /> or <xref href='false.tag' /> tag
 above.</p>

</desc>",

"elseif":#"<desc cont='cont'><p><short>
 Same as the <xref href='if.tag' />, but it will only evaluate if the
 previous <tag>if</tag> returned false.</short></p>
</desc>",

"false":#"<desc tag='tag'><p><short>
 Internal tag used to set the return value of <xref href='../if/'
 />.</short> It will ensure that the next <xref href='else.tag' /> tag
 will show its contents. It can be useful if you are writing your own
 <xref href='if.tag' /> lookalike tag. </p>
</desc>",

"help":#"<desc tag='tag'><p><short>
 Gives help texts for tags.</short> If given no arguments, it will
 list all available tags. By inserting <tag>help/</tag> in a page, a
 full index of the tags available in that particular Roxen WebServer
 will be presented. If a particular tag is missing from that index, it
 is not available at that moment. All tags are available through
 modules, hence that particular tags' module hasn't been added to the
 Roxen WebServer. Ask an administrator to add the module.
</p>
</desc>

<attr name='for' value='tag'><p>
 Gives the help text for that tag.</p>
<ex type='vert'><help for='roxen'/></ex>
</attr>",

"if":#"<desc cont='cont'><p><short>
 <tag>if</tag> is used to conditionally show its contents.</short>The
 <tag>if</tag> tag is used to conditionally show its contents. <xref
 href='else.tag'/> or <xref href='elseif.tag' /> can be used to
 suggest alternative content.</p>

 <p>It is possible to use glob patterns in almost all attributes,
 where * means match zero or more characters while ? matches one
 character. * Thus t*f?? will match trainfoo as well as * tfoo but not
 trainfork or tfo. It is not possible to use regexp's together
 with any of the if-plugins.</p>

 <p>The tag itself is useless without its
 plugins. Its main functionality is to provide a framework for the
 plugins.</p>

 <p>It is mandatory to add a plugin as one attribute. The other
 attributes provided are and, or and not, used for combining plugins
 or logical negation.</p>

 <ex type='box'>
  <if variable='var.foo > 0' and='' match='var.bar is No'>
    ...
  </if>
 </ex>

 <ex type='box'>
  <if variable='var.foo > 0' not=''>
    <ent>var.foo</ent> is lesser than 0
  </if>
  <else>
    <ent>var.foo</ent> is greater than 0
  </else>
 </ex>

 <p>Operators valid in attribute expressions are: '=', '==', 'is', '!=',
 '&lt;' and '&gt;'.</p>

 <p>The If plugins are sorted according to their function into five
 categories: Eval, Match, State, Utils and SiteBuilder.</p>

 <p>The Eval category is the one corresponding to the regular tests made
 in programming languages, and perhaps the most used. They evaluate
 expressions containing variables, entities, strings etc and are a sort
 of multi-use plugins. All If-tag operators and global patterns are
 allowed.</p>

 <ex>
  <set variable='var.x' value='6'/>
  <if variable='var.x > 5'>More than one hand</if>
 </ex>

 <p>The Match category contains plugins that match contents of
 something, e.g. an IP package header, with arguments given to the
 plugin as a string or a list of strings.</p>

 <ex>
  Your domain <if ip='130.236.*'> is </if>
  <else> isn't </else> liu.se.
 </ex>

 <p>State plugins check which of the possible states something is in,
 e.g. if a flag is set or not, if something is supported or not, if
 something is defined or not etc.</p>

 <ex>
   Your browser
  <if supports='javascript'>
   supports Javascript version <ent>client.javascript</ent>
  </if>
  <else>doesn't support Javascript</else>.
 </ex>

 <p>Utils are additonal plugins specialized for certain tests, e.g.
 date and time tests.</p>

 <ex>
  <if time='1700' after=''>
    Are you still at work?
  </if>
  <elseif time='0900' before=''>
     Wow, you work early!
  </elseif>
  <else>
   Somewhere between 9 to 5.
  </else>
 </ex>

 <p>SiteBuilder plugins requires a Roxen Platform SiteBuilder
 installed to work. They are adding test capabilities to web pages
 contained in a SiteBuilder administrated site.</p>
</desc>

<attr name='not'><p>
 Inverts the result (true-&gt;false, false-&gt;true).</p>
</attr>

<attr name='or'><p>
 If any criterion is met the result is true.</p>
</attr>

<attr name='and'><p>
 If all criterions are met the result is true. And is default.</p>
</attr>",

"if#true":#"<desc plugin='plugin'><p><short>
 This will always be true if the truth value is set to be
 true.</short> Equivalent with <xref href='then.tag' />.
 True is a <i>State</i> plugin.
</p></desc>

<attr name='true' required='required'><p>
 Show contents if truth value is false.</p>
</attr>",

"if#false":#"<desc plugin='plugin'><p><short>
 This will always be true if the truth value is set to be
 false.</short> Equivalent with <xref href='else.tag' />.
 False is a <i>State</i> plugin.</p>
</desc>

<attr name='false' required='required'><p>
 Show contents if truth value is true.</p>
</attr>",

"if#module":#"<desc plugin='plugin'><p><short>
 Enables true if the selected module is enabled in the current
 server.</short></p>
</desc>

<attr name='module' value='name'><p>
 The \"real\" name of the module to look for, i.e. its filename
 without extension.</p>
</attr>",

"if#accept":#"<desc plugin='plugin'><p><short>
 Returns true if the browser accepts certain content types as specified
 by it's Accept-header, for example image/jpeg or text/html.</short> If
 browser states that it accepts */* that is not taken in to account as
 this is always untrue. Accept is a <i>Match</i> plugin.
</p></desc>

<attr name='accept' value='type1[,type2,...]' required='required'>
</attr>",

"if#config":#"<desc plugin='plugin'><p><short>
 Has the config been set by use of the <xref href='../http/aconf.tag'
 /> tag?</short> Config is a <i>State</i> plugin.</p>
</desc>

<attr name='config' value='name' required='required'>
</attr>",

"if#cookie":#"<desc plugin='plugin'><p><short>
 Does the cookie exist and if a value is given, does it contain that
 value?</short> Cookie is an <i>Eval</i> plugin.
</p></desc>
<attr name='cookie' value='name[ is value]' required='required'>
</attr>",

"if#client":#"<desc plugin='plugin'><p><short>
 Compares the user agent string with a pattern.</short> Client is an
 <i>Match</i> plugin.
</p></desc>
<attr name='client' value='' required='required'>
</attr>",

"if#date":#"<desc plugin='plugin'><p><short>
 Is the date yyyymmdd?</short> The attributes before, after and
 inclusive modifies the behavior. Date is a <i>Utils</i> plugin.
</p></desc>
<attr name='date' value='yyyymmdd' required='required'><p>
 Choose what date to test.</p>
</attr>

<attr name='after'><p>
 The date after todays date.</p>
</attr>

<attr name='before'><p>
 The date before todays date.</p>
</attr>

<attr name='inclusive'><p>
 Adds todays date to after and before.</p>

 <ex>
  <if date='19991231' before='' inclusive=''>
     - 19991231
  </if>
  <else>
    20000101 -
  </else>
 </ex>
</attr>",


"if#defined":#"<desc plugin='plugin'><p><short>
 Tests if a certain RXML define is defined by use of the <xref
 href='../variable/define.tag' /> tag.</short> Defined is a
 <i>State</i> plugin. </p>
</desc>

<attr name='defined' value='define' required='required'><p>
 Choose what define to test.</p>
</attr>",

"if#domain":#"<desc plugin='plugin'><p><short>
 Does the user's computer's DNS name match any of the
 patterns?</short> Note that domain names are resolved asynchronously,
 and that the first time someone accesses a page, the domain name will
 probably not have been resolved. Domain is a <i>Match</i> plugin.
</p></desc>

<attr name='domain' value='pattern1[,pattern2,...]' required='required'><p>
 Choose what pattern to test.</p>
</attr>
",

// If eval is deprecated. This information is to be put in a special
// 'deprecated' chapter in the manual, due to many persons asking
// about its whereabouts.

"if#eval":#"<desc plugin='plugin'><p><short>
 Deprecated due to non-XML compliancy.</short> The XML standard says
 that attribute-values are not allowed to contain any markup. The
 <tag>if eval</tag> tag was deprecated in Roxen 2.0.</p>

 <ex typ='box'>

 <!-- If eval statement -->
 <if eval=\"<foo>\">x</if>

 <!-- Compatible statement -->
 <define variable=\"var.foo\" preparse=\"preparse\"><foo/></define>
 <if sizeof=\"var.foo\">x</if>
 </ex>
 <p>A similar but more XML compliant construct is a combination of
 <tag>define variable</tag> and an apropriate <tag>if</tag> plugin.
</p></desc>",

"if#exists":#"<desc plugin><short>
 Returns true if the file path exists.</short> If path does not begin
 with /, it is assumed to be a URL relative to the directory
 containing the page with the <tag><ref
 type='tag'>if</ref></tag>-statement. Exists is a <i>Utils</i>
 plugin.
</desc>
<attr name='exists' value='path' required>
 Choose what path to test.
</attr>",

"if#group":#"<desc plugin='plugin'><p><short>
 Checks if the current user is a member of the group according
 the groupfile.</short> Group is a <i>Utils</i> plugin.
</p></desc>
<attr name='group' value='name' required='required'><p>
 Choose what group to test.</p>
</attr>

<attr name='groupfile' value='path' required='required'><p>
 Specify where the groupfile is located.</p>
</attr>",

"if#ip":#"<desc plugin='plugin'><p><short>

 Does the users computers IP address match any of the
 patterns?</short> This plugin replaces the Host plugin of earlier
 RXML versions. Ip is a <i>Match</i> plugin.
</p></desc>
<attr name='ip' value='pattern1[,pattern2,...]' required='required'><p>
 Choose what IP-adress pattern to test.</p>
</attr>
",

"if#language":#"<desc plugin='plugin'><p><short>
 Does the client prefer one of the languages listed, as specified by the
 Accept-Language header?</short> Language is a <i>Match</i> plugin.
</p></desc>

<attr name='language' value='language1[,language2,...]' required='required'><p>
 Choose what language to test.</p>
</attr>
",

"if#match":#"<desc plugin='plugin'><p><short>
 Evaluates patterns.</short> More information can be found in the
 <xref href='../../tutorial/if_tags/plugins.xml'>If tags
 tutorial</xref>. Match is an <i>Eval</i> plugin. </p></desc>

<attr name='match' value='pattern' required='required'><p>
 Choose what pattern to test. The pattern could be any expression.
 Note!: The pattern content is treated as strings:</p>

<ex type='vert'>
 <set variable='var.hepp' value='10' />

 <if match='var.hepp is 10'>
  true
 </if>
 <else>
  false
 </else>
</ex>

 <p>This example shows how the plugin treats \"var.hepp\" and \"10\"
 as strings. Hence when evaluating a variable as part of the pattern,
 the entity associated with the variable should be used, i.e.
 <ent>var.hepp</ent> instead of var.hepp. A correct example would be:</p>

<ex type='vert'>
<set variable='var.hepp' value='10' />

 <if match='&var.hepp; is 10'>
  true
 </if>
 <else>
  false
 </else>
</ex>

 <p>Here, <ent>var.hepp</ent> is treated as an entity and parsed
 correctly, letting the plugin test the contents of the entity.</p>
</attr>
",

"if#Match":#"<desc plugin='plugin'><p><short>
 Case sensitive version of the match plugin</short></p>
</desc>",


"if#pragma":#"<desc plugin='plugin'><p><short>
 Compares the HTTP header pragma with a string.</short> Pragma is a
 <i>State</i> plugin.
</p></desc>

<attr name='pragma' value='string' required='required'><p>
 Choose what pragma to test.</p>

<ex>
 <if pragma='no-cache'>The page has been reloaded!</if>
 <else>Reload this page!</else>
</ex>
</attr>
",

"if#prestate":#"<desc plugin='plugin'><p><short>
 Are all of the specified prestate options present in the URL?</short>
 Prestate is a <i>State</i> plugin.
</p></desc>
<attr name='prestate' value='option1[,option2,...]' required='required'><p>
 Choose what prestate to test.</p>
</attr>
",

"if#referrer":#"<desc plugin='plugin'><p><short>
 Does the referrer header match any of the patterns?</short> Referrer
 is a <i>Match</i> plugin.
</p></desc>
<attr name='referrer' value='pattern1[,pattern2,...]' required='required'><p>
 Choose what pattern to test.</p>
</attr>
",

// The list of support flags is extracted from the supports database and
// concatenated to this entry.
"if#supports":#"<desc plugin='plugin'><p><short>
 Does the browser support this feature?</short> Supports is a
 <i>State</i> plugin.
</p></desc>

<attr name=supports'' value='feature' required required='required'>
 <p>Choose what supports feature to test.</p>
</attr>

<p>The following features are supported:</p> <supports-flags-list/>",

"if#time":#"<desc plugin='plugin'><p><short>
 Is the time hhmm?</short> The attributes before, after and inclusive modifies
 the behavior. Time is a <i>Utils</i> plugin.
</p></desc>
<attr name='time' value='hhmm' required='required'><p>
 Choose what time to test.</p>
</attr>

<attr name='after'><p>
 The time after present time.</p>
</attr>

<attr name='before'><p>
 The time before present time.</p>
</attr>

<attr name='inclusive'><p>
 Adds present time to after and before.</p>

 <ex>
  <if time='1200' before='' inclusive=''>
    ante meridiem
  </if>
  <else>
    post meridiem
  </else>
 </ex>
</attr>",

"if#user":#"<desc plugin='plugin'><p><short>
 Has the user been authenticated as one of these users?</short> If any
 is given as argument, any authenticated user will do. User is a
 <i>Utils</i> plugin.
</p></desc>

<attr name='user' value='name1[,name2,...]|any' required='required'><p>
 Specify which users to test.</p>
</attr>
",

"if#variable":#"<desc plugin='plugn'><p><short>
 Does the variable exist and, optionally, does it's content match the
 pattern?</short> Variable is an <i>Eval</i> plugin.
</p></desc>

<attr name='variable' value='name[ is pattern]' required='required'><p>
 Choose variable to test. Valid operators are '=', '==', 'is', '!=',
 '&lt;' and '&gt;'.</p>
</attr>",

"if#Variable":#"<desc plugin='plugin'><p><short>
 Case sensitive version of the variable plugin</short></p>
</desc>",

// The list of support flags is extracted from the supports database and
// concatenated to this entry.
"if#clientvar":#"<desc plugin='plugin'><p><short>
 Evaluates expressions with client specific values.</short> Clientvar
 is an <i>Eval</i> plugin.
</p></desc>

<attr name='clientvar' value='variable [is value]' required='required'><p>
 Choose which variable to evaluate against. Valid operators are '=',
 '==', 'is', '!=', '&lt;' and '&gt;'.</p>
</attr>

<p>Available variables are:</p>",

"if#sizeof":#"<desc plugin='plugin'><p><short>
 Compares the size of a variable with a number.</short></p>

<ex>
<set variable=\"var.x\" value=\"hello\"/>
<set variable=\"var.y\" value=\"\"/>
<if sizeof=\"var.x == 5\">Five</if>
<if sizeof=\"var.y > 0\">Nonempty</if>
</ex>
</desc>",

"nooutput":#"<desc cont='cont'><p><short>
 The contents will not be sent through to the page.</short> Side
 effects, for example sending queries to databases, will take effect.
</p></desc>",

"noparse":#"<desc cont='cont'><p><short>
 The contents of this container tag won't be RXML parsed.</short>
</p></desc>",

"<?noparse": #"<desc pi='pi'><p><short>
 The content is inserted as-is, without any parsing or
 quoting.</short> The first whitespace character (i.e. the one
 directly after the \"noparse\" name) is discarded.</p>
</desc>",

"<?cdata": #"<desc pi='pi'><p><short>
 The content is inserted as a literal.</short> I.e. any XML markup
 characters are encoded with character references. The first
 whitespace character (i.e. the one directly after the \"cdata\" name)
 is discarded.</p>

 <p>This processing instruction is just like the &lt;![CDATA[ ]]&gt;
 directive but parsed by the RXML parser, which can be useful to
 satisfy browsers that does not handle &lt;![CDATA[ ]]&gt; correctly.</p>
</desc>",

"number":#"<desc tag='tag'><p><short>
 Prints a number as a word.</short>
</p></desc>

<attr name='num' value='number' required='required'><p>
 Print this number.</p>
<ex type='vert'><number num='4711'/></ex>
</attr>

<attr name='language' value='langcodes'><p>
 The language to use.</p>
 <lang/>
 <ex type='vert'>Mitt favoritnummer �r <number num='11' language='sv'/>.</ex>
 <ex type='vert'>Il mio numero preferito <ent>egrave</ent> <number num='15' language='it'/>.</ex>
</attr>

<attr name='type' value='number|ordered|roman|memory' default='number'><p>
 Sets output format.</p>

 <ex type='vert'>It was his <number num='15' type='ordered'/> birthday yesterday.</ex>
 <ex type='vert'>Only <number num='274589226' type='memory'/> left on the Internet.</ex>
 <ex type='vert'>Spock Garfield <number num='17' type='roman'/> rests here.</ex>
</attr>",

"strlen":#"<desc cont='cont'><p><short>
 Returns the length of the contents.</short></p>

 <ex type='vert'>There are <strlen>foo bar gazonk</strlen> characters
 inside the tag.</ex>
</desc>",

"then":#"<desc cont='cont'><p><short>
 Shows its content if the truth value is true.</short></p>
</desc>",

"trace":#"<desc cont='cont'><p><short>
 Executes the contained RXML code and makes a trace report about how
 the contents are parsed by the RXML parser.</short>
</p></desc>",

"true":#"<desc tag='tag'><p><short>
 An internal tag used to set the return value of <xref href='../if/'
 />.</short> It will ensure that the next <xref href='else.tag'
 /> tag will not show its contents. It can be useful if you are
 writing your own <xref href='if.tag' /> lookalike tag.</p>
</desc>",

"undefine":#"<desc tag='tag'><p><short>
 Removes a definition made by the define container.</short> One
 attribute is required.
</p></desc>

<attr name='variable' value='name'><p>
 Undefines this variable.</p>

 <ex>
  <define variable='var.hepp'>hopp</define>
  <ent>var.hepp</ent>
  <undefine variable='var.hepp'/>
  <ent>var.hepp</ent>
 </ex>
</attr>

<attr name='tag' value='name'><p>
 Undefines this tag.</p>
</attr>

<attr name='container' value='name'><p>
 Undefines this container.</p>
</attr>

<attr name='if' value='name'><p>
 Undefines this if-plugin.</p>
</attr>",

"use":#"<desc cont='cont'><p><short>
 Reads tag definitions, user defined if plugins and variables from a
 file or package and includes into the current page.</short> Note that the
 file itself is not inserted into the page. This only affects the
 environment in which the page is parsed. The benefit is that the
 package file needs only be parsed once, and the compiled versions of
 the user defined tags can then be used, thus saving time. It is also
 a fairly good way of creating templates for your website. Just define
 your own tags for constructions that appears frequently and save both
 space and time. Since the tag definitions are cached in memory, make
 sure that the file is not dependent on anything dynamic, such as form
 variables or client settings, at the compile time. Also note that the
 use tag only lets you define variables in the form and var scope in
 advance. Variables with the same name will be overwritten when the
 use tag is parsed.</p>
</desc>

<attr name='packageinfo'><p>
 Show a list of all available packages.</p>
</attr>

<attr name='package' value='name'><p>
 Reads all tags, container tags and defines from the given package.
 Packages are files located by default in <i>../rxml_packages/</i>.</p>
</attr>

<attr name='file' value='path'><p>
 Reads all tags and container tags and defines from the file.

 <p>This file will be fetched just as if someone had tried to fetch it
 with an HTTP request. This makes it possible to use Pike script
 results and other dynamic documents. Note, however, that the results
 of the parsing are heavily cached for performance reasons. If you do
 not want this cache, use <tag>insert file='...'
 nocache='1'</tag> instead.</p>
</attr>

<attr name='info'><p>
 Show a list of all defined tags/containers and if arguments in the
 file.</p>
</attr>",

"eval":#"<desc cont='cont'><p><short>
 Postparses its content.</short> Useful when an entity contains
 RXML-code. <tag>eval</tag> is then placed around the entity to get
 its content parsed.</p>
</desc>",

"emit#path":({ #"<desc plugin='plugin'><p><short>
 Prints paths.</short> This plugin traverses over all directories in
 the path from the root up to the current one.</p>
</desc>

<attr name='path' value='string'><p>
   Use this path instead of the document path</p>
</attr>

<attr name='trim' value='string'><p>
 Removes all of the remaining path after and including the specified
 string.</p>
</attr>

<attr name='skip' value='number'><p>
 Skips the 'number' of slashes ('/') specified, with beginning from
 the root.</p>
</attr>

<attr name='skip-end' value='number'><p>
 Skips the 'number' of slashes ('/') specified, with beginning from
 the end.</p>
</attr>",
	       ([
"&_.name;":#"<desc ent='ent'><p>
 Returns the name of the most recently traversed directory.</p>
</desc>",

"&_.path;":#"<desc ent='ent'><p>
 Returns the path to the most recently traversed directory.</p>
</desc>"
	       ])
}),

"emit#sources":({ #"<desc plugin='plugin'><p><short>
 Provides a list of all available emit sources.</short>
</p></desc>",
  ([ "&_.source;":#"<desc ent='ent'><p>
  The name of the source.</p></desc>" ]) }),


"emit#values":({ #"<desc plugin='plugin'><p><short>
 Splits the string provided in the values attribute and outputs the
 parts in a loop.</short> The value in the values attribute may also
 be an array or mapping.
</p></desc>

<attr name='values' value='string, mapping or array' required='required'><p>
 An array, mapping or a string to be splitted into an array.</p>
</attr>

<attr name='split' value='string' default='NULL'><p>
 The string the values string is splitted with.</p>
</attr>

<attr name='advanced' value='lines|words|chars'><p>
 If the input is a string it can be splitted into separate lines, words
 or characters by using this attribute.</p>
</attr>

<attr name='case' value='upper|lower'><p>
 Changes the case of the value.</p>
</attr>

<attr name='trimwhites'><p>
 Trims away all leading and trailing white space charachters from the
 values.</p>
</attr>

<attr name='from-scope' value='name'>
 Create a mapping out of a scope and give it as indata to the emit.
</attr>
",

([
"&_.value;":#"<desc ent='ent'><p>
 The value of one part of the splitted string</p>
</desc>",

"&_.index;":#"<desc ent='ent'><p>
 The index of this mapping entry, if input was a mapping</p>
</desc>"
])
	      }),


"emit":({ #"<desc cont='cont'><p><short hide='hide'>

 Provides data, fetched from different sources, as entities. </short>

 <tag>emit</tag> is a generic tag used to fetch data from a
 provided source, loop over it and assign it to RXML variables
 accessible through entities.</p>

 <p>Occasionally an <tag>emit</tag> operation fails to produce output.
 This might happen when <tag>emit</tag> can't find any matches or if
 the developer has made an error. When this happens the truthvalue of
 that page is set to <i>false</i>. By using <xref
 href='../if/else.tag' /> afterwards it's possible to detect when an
 <tag>emit</tag> operation fails.</p>
</desc>

<attr name='source' value='plugin' required='required'><p>
 The source from which the data should be fetched.</p>
</attr>

<attr name='scope' value='name' default='The emit source'><p>
 The name of the scope within the emit tag.</p>
</attr>

<attr name='maxrows' value='number'><p>
 Limits the number of rows to this maximum.</p>
</attr>

<attr name='skiprows' value='number'><p>
 Makes it possible to skip the first rows of the result. Negative
 numbers means to skip everything execept the last n rows.</p>
</attr>

<attr name='rowinfo' value='variable'><p>
 The number of rows in the result, after it has been limited by
 maxrows and skiprows, will be put in this variable, if given.</p>
</attr>

<attr name='do-once'><p>
 Indicate that at least one loop should be made. All variables in the
 emit scope will be empty.</p>
</attr>",

	  ([

"&_.counter;":#"<desc ent='ent'><p>
 Gives the current number of loops inside the <tag>emit</tag> tag.
</p>
</desc>"

	  ])
       }),

]);
#endif

