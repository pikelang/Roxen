// This is a ChiliMoon module which provides tags which allow definition and
// reuse of usertags.
//
// This module is open source software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License as published
// by the Free Software Foundation; either version 2, or (at your option) any
// later version.
//

#define _ok id->misc->defines[" _ok"]

constant cvs_version =
 "$Id: usertags.pike,v 1.1 2004/05/31 14:42:34 _cvs_stephen Exp $";
constant thread_safe = 1;
constant module_unique = 1;

#include <module.h>
#include <request_trace.h>

inherit "module";


// ---------------- Module registration stuff ----------------

constant module_type = MODULE_TAG;
constant module_name = "Tags: Usertags";
constant module_doc  =
 "This module provides tags which allow the definition of usertags.<br />"
 "<p>This module is open source software; you can redistribute it and/or "
 "modify it under the terms of the GNU General Public License as published "
 "by the Free Software Foundation; either version 2, or (at your option) any "
 "later version.</p>";

void create() {
  set_module_creator("Stephen R. van den Berg <srb@cuci.nl>");
}

string status() {
  return "";
}

class TagMaketag {
  inherit RXML.Tag;
  constant name = "maketag";
  mapping(string:RXML.Type) req_arg_types = ([ "type" : RXML.t_text(RXML.PEnt) ]);
  mapping(string:RXML.Type) opt_arg_types = ([ "noxml" : RXML.t_text(RXML.PEnt),
					       "name" : RXML.t_text(RXML.PEnt) ]);

  class TagAttrib {
    inherit RXML.Tag;
    constant name = "attrib";
    mapping(string:RXML.Type) req_arg_types = ([ "name" : RXML.t_text(RXML.PEnt) ]);

    class Frame {
      inherit RXML.Frame;

      array do_return(RequestID id) {
	id->misc->makeargs[args->name] = content || "";
	return 0;
      }
    }
  }

  RXML.TagSet internal =
    RXML.shared_tag_set (0, "/rxmltags/maketag", ({ TagAttrib() }) );

  class Frame {
    inherit RXML.Frame;
    mixed old_args;
    RXML.TagSet additional_tags = internal;

    array do_enter(RequestID id) {
      old_args = id->misc->makeargs;
      id->misc->makeargs = ([]);
      return 0;
    }

    array do_return(RequestID id) {
      switch(args->type) {
      case "pi":
	if(!args->name) parse_error("Type 'pi' requires a name attribute.\n");
	result = RXML.t_xml->format_tag(args->name, 0, content, RXML.FLAG_PROC_INSTR);
	break;
      case "container":
	if(!args->name) parse_error("Type 'container' requires a name attribute.\n");
	result = RXML.t_xml->format_tag(args->name, id->misc->makeargs, content, RXML.FLAG_RAW_ARGS);
	break;
      case "tag":
	if(!args->name) parse_error("Type 'tag' requires a name attribute.\n");
	result = RXML.t_xml->format_tag(args->name, id->misc->makeargs, 0,
					(args->noxml?RXML.FLAG_COMPAT_PARSE:0)|
					RXML.FLAG_EMPTY_ELEMENT|RXML.FLAG_RAW_ARGS);
	break;
      case "comment":
	result = "<!--" + content + "-->";
	break;
      case "cdata":
	result = "<![CDATA[" + content/"]]>"*"]]]]><![CDATA[>" + "]]>";
	break;
      }
      id->misc->makeargs = old_args;
      return 0;
    }
  }
}

class UserIf
{
  constant name = "if";
  string plugin_name;
  string|RXML.RenewablePCode rxml_code;

  void create(string pname, string code) {
    plugin_name = pname;
    rxml_code = code;
  }

  int eval(string ind, RequestID id) {
    int otruth, res;
    string tmp;

    TRACE_ENTER("user defined if argument "+plugin_name, UserIf);
    otruth = _ok;
    _ok = -2;
    if (objectp (rxml_code))
      tmp = rxml_code->eval (RXML_CONTEXT);
    else
      [tmp, rxml_code] =
	RXML_CONTEXT->eval_and_compile (RXML.t_html (RXML.PXml), rxml_code, 1);
    res = _ok;
    _ok = otruth;

    TRACE_LEAVE("");

    if(ind==plugin_name && res!=-2)
      return res;

    return (ind==tmp);
  }

  // These objects end up in RXML_CONTEXT->misc and might therefore be
  // cached persistently.
  constant is_RXML_encodable = 1;
  array _encode() {return ({plugin_name, rxml_code});}
  void _decode (array data) {[plugin_name, rxml_code] = data;}
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

    array defs = parse_use_package(data, RXML_CONTEXT);
    cache_set("macrofiles", "|"+f, defs, 300);

    array(string) ifs = ({}), tags = ({});

    foreach (indices (defs[0]), string defname)
      if (has_prefix (defname, "if\0"))
	ifs += ({defname[sizeof ("if\0")..]});
      else if (has_prefix (defname, "tag\0"))
	tags += ({defname[sizeof ("tag\0")..]});

    constant types = ({ "if plugin", "tag", "form variable", "\"var\" scope variable" });

    array pack = ({ifs, tags, indices(defs[1]), indices(defs[2])});

    for(int i; i<3; i++)
      if(sizeof(pack[i])) {
	res += "Defines the following " + types[i] + (sizeof(pack[i])!=1?"s":"") +
	  ": " + String.implode_nicely( sort(pack[i]) ) + ".<br />";
      }

    if(help) res+="<br /><br />All tags accept the <i>help</i> attribute.";
    return res;
  }

  private array parse_use_package(string data, RXML.Context ctx) {
    RequestID id = ctx->id;

    RXML.Parser parser = Roxen.get_rxml_parser (ctx->id);
    parser->write_end (data);
    parser->eval();

    return ({
      parser->context->misc - ([" _extra_heads": 1, " _error": 1, " _stat": 1]),
      parser->context->get_scope ("form"),
      parser->context->get_scope ("var")
    });
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
      else if( args->locate )
      {
	filename = VFS.find_above( id->not_query, args->locate, id, "locate" );
	name = id->conf->get_config_id() + "|" + filename;
      }
      else
      {
	name = "|" + args->package;
      }
      RXML.Context ctx = RXML_CONTEXT;

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

      [mapping(string:mixed) newdefs,
       mapping(string:mixed)|RXML.Scope formvars,
       mapping(string:mixed)|RXML.Scope varvars] = res;
      foreach (indices (newdefs), string defname) {
	mixed def = ctx->misc[defname] = newdefs[defname];
	if (has_prefix (defname, "tag\0")) ctx->add_runtime_tag (def[3]);
      }
      ctx->extend_scope ("form", formvars);
      ctx->extend_scope ("var", varvars);

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

  class IdentityVar (string self)
  {
    mixed rxml_var_eval (RXML.Context ctx, string var, string scope_name,
			 void|RXML.Type type)
    {
      return ENCODE_RXML_XML (self, type);
    }
  }

  // Got two frame types in this tag: First the normal frame which is
  // created when <contents/> is parsed. Second the ExpansionFrame
  // which is made by the normal frame with the actual content the
  // UserTag frame got.

  class Frame
  {
    inherit RXML.Frame;
    constant is_user_tag_contents_tag = 1;

    string scope;

    local RXML.Frame get_upframe()
    {
      RXML.Frame upframe = up;
      int nest = 1;
      for (; upframe; upframe = upframe->up)
	if (upframe->is_contents_nest_tag) {
	  if ((!scope || upframe->scope_name == scope) && !--nest)
	    return upframe;
	}
	else
	  if (upframe->is_user_tag_contents_tag &&
	      (!scope || upframe->scope == scope)) nest++;
      parse_error ("No associated defined tag to get contents from.\n");
    }

    // Note: The ExpansionFrame instances aren't saved and restored
    // here for p-code use, since they can't be shared between
    // evaluations (due to e.g. orig_ctx_scopes).

    array do_return()
    {
      if (args["copy-of"] && args["value-of"])
	parse_error ("Attributes copy-of and value-of are mutually exclusive.\n");

      scope = args->scope;
      RXML.Frame upframe = get_upframe();

      // Note that args will be parsed again in the ExpansionFrame.

      if (upframe->is_define_tag) {
	// If upframe is a <define> tag and not the user tag then
	// we're being preparsed. Output an entity on the form
	// &_internal_.4711; so that we can find it again after the
	// preparse.
	if (mapping(string:ExpansionFrame) ctag = upframe->preparsed_contents_tags) {
	  RXML.Context ctx = RXML_CONTEXT;
	  string var = ctx->alloc_internal_var();
	  ctag[var] = ExpansionFrame (
	    0,
	    args["copy-of"] || args["value-of"] ?
	    RXML.t_xml (content_type->parser_prog) : content_type,
	    args);
	  // Install a value for &_internal_.4711; that expands to
	  // itself, in case something evaluates it during preparse.
	  // Don't use the proper ctx->set_var since these assigments
	  // doesn't need to be registered if p-code is created;
	  // they're only used temporarily during the preparse.
	  ctx->scopes->_internal_[var] = IdentityVar ("&_internal_." + var + ";");
	  result_type = result_type (RXML.PNone);
	  return ({"&_internal_." + var + ";"});
	}
	else
	  parse_error ("This tag is currently only supported in "
		       "<define tag='...'> and <define container='...'>.\n");
      }

      else {
	ExpansionFrame exp_frame =
	  ExpansionFrame (upframe,
			  args["copy-of"] || args["value-of"] ?
			  RXML.t_xml (content_type->parser_prog) : content_type,
			  args);
#ifdef DEBUG
	if (flags & RXML.FLAG_DEBUG) exp_frame->flags |= RXML.FLAG_DEBUG;
#endif
	return ({exp_frame});
      }
    }
  }

  static function(:mapping) get_arg_function (mapping args)
  {
    return lambda () {return args;};
  }

  class ExpansionFrame
  {
    inherit RXML.Frame;
    int do_iterate;

    RXML.Frame upframe;

    static void create (void|RXML.Frame upframe_,
			void|RXML.Type type, void|mapping contents_args)
    {
      if (type) {		// Might be created from decode or _clone_empty.
	content_type = type, result_type = type (RXML.PNone);
	args = contents_args;
	if (args["copy-of"] || args["value-of"])
	  // If there's an error it'll typically be completely lost if
	  // we use copy-of or value-of, so propagate it instead.
	  flags |= RXML.FLAG_DONT_RECOVER;
	if ((upframe = upframe_)) {
	  // upframe is zero if we're called during preparse.
	  RXML.PCode compiled_content = upframe->compiled_content;
	  if (compiled_content && !compiled_content->is_stale()) {
	    content = compiled_content;
	    // The internal way to flag a compiled but unevaluated
	    // flag is to set args to a function returning the
	    // argument mapping. It'd be prettier with a flag for
	    // this.
	    args = (mixed) get_arg_function (args);
	  }
	  else {
	    content = upframe->content_text;
	    flags |= RXML.FLAG_UNPARSED;
	  }
	  if (upframe->compile) flags |= RXML.FLAG_COMPILE_INPUT;
	}
      }
    }

    local mixed get_content (RXML.Frame upframe, mixed content)
    {
      if (string expr = args["copy-of"] || args["value-of"]) {
	string insert_type = args["copy-of"] ? "copy-of" : "value-of";

	string value;
	if (sscanf (expr, "%*[ \t\n\r]@%*[ \t\n\r]%s", expr) == 3) {
	  // Special treatment to select attributes at the top level.
	  sscanf (expr, "%[^][ \t\n\r/@(){}:.,]%*[ \t\n\r]%s", expr, string rest);
	  if (!sizeof (expr))
	    parse_error ("Error in %s attribute: No attribute name after @.\n",
			 insert_type);
	  if (sizeof (rest))
	    parse_error ("Error in %s attribute: "
			 "Unexpected subpath %O after attribute %s.\n",
			 insert_type, rest, expr);
	  if (expr == "*") {
	    if (insert_type == "copy-of")
	      value = upframe->vars->args;
	    else
	      foreach (indices (upframe->vars), string var)
		if (!(<"args", "rest-args", "contents">)[var] &&
		    !has_prefix (var, "__contents__")) {
		  value = upframe->vars[var];
		  break;
		}
	  }
	  else if (!(<"args", "rest-args", "contents">)[expr] &&
		   !has_prefix (expr, "__contents__"))
	    if (string val = upframe->vars[expr])
	      if (insert_type == "copy-of")
		value = Roxen.make_tag_attributes (([expr: val]));
	      else
		value = val;
	}

	else {
	  if (!objectp (content) || content->node_type != SloppyDOM.Node.DOCUMENT_NODE)
	    content = upframe->content_result = SloppyDOM.parse ((string) content, 1);

	  mixed res = 0;
	  if (mixed err = catch (
		res = content->simple_path (expr, insert_type == "copy-of")))
	    // We're sloppy and assume that the error is some parse
	    // error regarding the expression.
	    parse_error ("Error in %s attribute: %s", insert_type,
			 describe_error (err));

	  if (insert_type == "copy-of")
	    value = res;
	  else {
	    if (arrayp (res)) res = sizeof (res) && res[0];
	    if (objectp (res))
	      value = res->get_text_content();
	    else if (mappingp (res) && sizeof (res))
	      value = values (res)[0];
	    else
	      value = "";
	  }
	}

#ifdef DEBUG
	if (TAG_DEBUG_TEST (flags & RXML.FLAG_DEBUG))
	  tag_debug ("%O:   Did %s %O in %s: %s\n", this,
		     insert_type, expr,
		     RXML.utils.format_short (
		       objectp (content) ? content->xml_format() : content),
		     RXML.utils.format_short (value));
#endif
	return value;
      }

      else
	if (objectp (content) &&
	    content->node_type == SloppyDOM.Node.DOCUMENT_NODE &&
	    result_type->empty_value == "")
	  // The content has been parsed into a SloppyDOM.Document by
	  // the code above in an earlier <contents/>. Format it again
	  // if the result type is string-like.
	  return content->xml_format();
	else
	  return content;
    }

    mapping(string:mixed) orig_ctx_scopes;
    mapping(RXML.Frame:array) orig_ctx_hidden;

    array do_enter()
    {
      if (!upframe->got_content_result || args->eval) {
	do_iterate = 1;
	// Switch to the set of scopes that were defined at entry of
	// the UserTag frame, to get static variable binding in the
	// content. This is poking in the internals; there ought to be
	// some sort of interface here.
	RXML.Context ctx = RXML_CONTEXT;
	orig_ctx_scopes = ctx->scopes, ctx->scopes = upframe->saved_scopes;
	orig_ctx_hidden = ctx->hidden, ctx->hidden = upframe->saved_hidden;
      }
      else
	// Already have the result of the content evaluation.
	do_iterate = -1;
      return 0;
    }

    array do_return()
    {
      if (do_iterate >= 0) {
	// Switch back the set of scopes. This is poking in the
	// internals; there ought to be some sort of interface here.
	RXML.Context ctx = RXML_CONTEXT;
	ctx->scopes = orig_ctx_scopes, orig_ctx_scopes = 0;
	ctx->hidden = orig_ctx_hidden, orig_ctx_hidden = 0;
	upframe->content_result = content;
	upframe->got_content_result = 1;
      }
      else
	content = upframe->content_result;

      result = get_content (upframe, content);
      return 0;
    }

    // The frame might be used as a variable value if preparsing is in
    // use (see the is_define_tag stuff in Frame.do_return). Note: The
    // frame is not thread local in this case.
    mixed rxml_var_eval (RXML.Context ctx, string var, string scope_name,
			 void|RXML.Type type)
    {
      RXML.Frame upframe = ctx->frame;
#ifdef DEBUG
      if (!upframe || !upframe->is_user_tag)
	error ("Expected current frame to be UserTag, but it's %O.\n", upframe);
#endif

      mixed content;

      // Do the work in _eval, do_enter and do_return. Can't use the
      // do_* functions since the frame isn't thread local here.

      if (!upframe->got_content_result || args->eval) {
	// Switch to the set of scopes that were defined at entry of
	// the UserTag frame, to get static variable binding in the
	// content. This is poking in the internals; there ought to be
	// some sort of interface here.
	RXML.Context ctx = RXML_CONTEXT;
	mapping(string:mixed) orig_ctx_scopes = ctx->scopes;
	ctx->scopes = upframe->saved_scopes;
	mapping(RXML.Frame:array) orig_ctx_hidden = ctx->hidden;
	ctx->hidden = upframe->saved_hidden;

	RXML.PCode compiled_content = upframe->compiled_content;
	if (compiled_content && !compiled_content->is_stale())
	  content = compiled_content->eval (ctx);
	else if (upframe->compile)
	  [content, upframe->compiled_content] =
	    ctx->eval_and_compile (content_type, upframe->content_text);
	else
	  content = content_type->eval (upframe->content_text);

	// Switch back the set of scopes. This is poking in the
	// internals; there ought to be some sort of interface here.
	ctx->scopes = orig_ctx_scopes;
	ctx->hidden = orig_ctx_hidden;
	upframe->content_result = content;
	upframe->got_content_result = 1;
      }
      else
	content = upframe->content_result;

#if constant (_disable_threads)
      // If content is a SloppyDOM object, it's not thread safe when
      // it extends itself lazily, so a lock is necessary. We use the
      // interpreter lock since it's the cheapest one and since
      // get_content doesn't block anyway.
      Thread._Disabled threads_disabled = _disable_threads();
#endif
      mixed result = get_content (upframe, content);
#if constant (_disable_threads)
      threads_disabled = 0;
#endif

      // Note: result_type == content_type (except for the parser).
      return type && type != result_type ?
	type->encode (result, result_type) : result;
    }

    array _encode() {return ({content_type, upframe, args});}
    void _decode (array data) {create (@data);}

    string format_rxml_backtrace_frame (void|RXML.Context ctx)
    {
      if (ctx)
	// Used as an RXML.Value.
	return "<contents" + Roxen.make_tag_attributes (args) + ">";
      else
	// Used as a frame. The real contents frame is just above, so
	// suppress this one.
	return "";
    }

    string _sprintf (int flag)
    {
      return flag == 'O' && sprintf ("ExpansionFrame(contents in %O)", upframe);
    }
  }
}

// This tag set can't be shared since we look at compat_level in
// UserTagContents.
// NGSERVER: Since we don't look at compat_level anymore, this can be
//  improved upon.  Any volunteers?
RXML.TagSet user_tag_contents_tag_set =
  RXML.TagSet (this_module(), "_user_tag", ({UserTagContents()}));

class UserTag {
  inherit RXML.Tag;
  string name, lookup_name;
  int flags = RXML.FLAG_COMPILE_RESULT;
  RXML.Type content_type = RXML.t_xml;
  array(RXML.Type) result_types = ({ RXML.t_any(RXML.PXml) });

  // Note: We can't store the actual user tag definition directly in
  // this object; it won't work correctly in p-code since we don't
  // reparse the source and thus don't create a frame with the current
  // runtime tag definition. By looking up the definition in
  // RXML.Context.misc we can get the current definition even if it
  // changes in loops etc.

  void create(string _name, int moreflags) {
    if (_name) {
      name=_name;
      lookup_name = "tag\0" + name;
      flags |= moreflags;
    }
  }

  mixed _encode()
  {
    return ({ name, flags });
  }

  void _decode(mixed v)
  {
    [name, flags] = v;
    lookup_name = "tag\0" + name;
  }

  class Frame {
    inherit RXML.Frame;
    RXML.TagSet additional_tags;
    RXML.TagSet local_tags;
    string scope_name;
    mapping vars;
    string raw_tag_text;
    int do_iterate;
#ifdef MODULE_LEVEL_SECURITY
    object check_security_object = this_module();
#endif

    constant is_user_tag = 1;
    constant is_contents_nest_tag = 1;
    string content_text;
    RXML.PCode compiled_content;
    mixed content_result;
    int got_content_result;
    mapping(string:mixed) saved_scopes;
    mapping(RXML.Frame:array) saved_hidden;
    int compile;

    array tagdef;

    array do_enter (RequestID id)
    {
      vars = 0;
      do_iterate = content_text ? -1 : 1;
      if ((tagdef = RXML_CONTEXT->misc[lookup_name]))
	if (tagdef[4]) {
	  local_tags = RXML.empty_tag_set;
	  additional_tags = 0;
	}
	else {
	  additional_tags = user_tag_contents_tag_set;
	  local_tags = 0;
	}
      return 0;
    }

    array do_return(RequestID id) {
      if (!tagdef) return ({propagate_tag()});
      RXML.Context ctx = RXML_CONTEXT;

      [array(string|RXML.PCode) def, mapping defaults,
       string def_scope_name, UserTag ignored,
       mapping(string:UserTagContents.ExpansionFrame) preparsed_contents_tags] = tagdef;
      vars = defaults+args;
      scope_name = def_scope_name || name;

      if (content_text)
	// A previously evaluated tag was restored.
	content = content_text;
      else {
	if(content && args->trimwhites)
	  content = String.trim_all_whites(content);

	content_text = content || "";
	compile = ctx->make_p_code;
      }

      vars->args = Roxen.make_tag_attributes(vars)[1..];
      vars["rest-args"] = Roxen.make_tag_attributes(args - defaults)[1..];
      vars->contents = content;
      if (preparsed_contents_tags) vars += preparsed_contents_tags;
      id->misc->last_tag_args = vars;
      got_content_result = 0;

      // Save the scope state so that we can switch back in
      // <contents/>, thereby achieving static variable binding in
      // the content. This is poking in the internals; there ought
      // to be some sort of interface here.
      saved_scopes = ctx->scopes + ([]);
      saved_hidden = ctx->hidden + ([]);

      return def;
    }

    array save() {return ({content_text, compiled_content});}
    void restore (array saved) {[content_text, compiled_content] = saved;}

    string _sprintf (int t)
    {
      if (catch {return "UserTag.Frame(" + name + ")";})
	return "UserTag.Frame(?)";
    }
  }

  string _sprintf(int t) {return "UserTag(" + name + ")";}
}

// A helper Scope class used when preparsing in TagDefine: Every
// variable in it has its own entity string as value, so that e.g.
// &_.contents; goes through the preparse step.
class IdentityVars
{
  inherit RXML.Scope;
  mixed `[] (string var, void|RXML.Context ctx,
	     void|string scope_name, void|RXML.Type type)
  {
    // Note: The fallback for scope_name here is not necessarily
    // correct, but this is typically only called from the rxml
    // parser, which always sets it.
    return ENCODE_RXML_XML ("&" + (scope_name || "_") + "." + var + ";", type);
  }
};
IdentityVars identity_vars = IdentityVars();

class TagDefine {
  inherit RXML.Tag;
  constant name = "define";
  constant flags = RXML.FLAG_DONT_RECOVER;
  RXML.Type content_type = RXML.t_xml (RXML.PXml);
  array(RXML.Type) result_types = ({RXML.t_nil}); // No result.

  class Frame {
    inherit RXML.Frame;
    RXML.TagSet additional_tags;

    constant is_define_tag = 1;
    constant is_contents_nest_tag = 1;
    array(string|RXML.PCode) def;
    mapping defaults;
    int do_iterate;

    // Used when we preparse.
    RXML.Scope|mapping vars;
    string scope_name;
    mapping(string:UserTagContents.ExpansionFrame) preparsed_contents_tags;

    array do_enter(RequestID id) {
      if (def)
	// A previously evaluated tag was restored.
	do_iterate = -1;
      else {
	preparsed_contents_tags = 0;
	do_iterate = 1;
	if(args->preparse) {
	  m_delete(args, "preparse");
	  // Older rxml code might use the _ scope and don't expect
	  // it to be overridden in this situation.
	  if (args->tag || args->container) {
	    vars = identity_vars;
	    preparsed_contents_tags = ([]);
	  }
	  else
	    // Even though there won't be any postparse fill-in of
	    // &_.foo; etc we define a local scope for consistency.
	    // This way we can provide special values in the future,
	    // or perhaps fix postparse fill-in even for variables,
	    // if plugins, etc.
	    vars = ([]);
	  additional_tags = user_tag_contents_tag_set;
	  scope_name = args->scope;
	}
	else
	  content_type = RXML.t_xml;
      }
      return 0;
    }

    // Callbacks used by the <attrib> parser. These are intentionally
    // defined outside the scope of do_return to avoid getting dynamic
    // frames with cyclic references. This is only necessary for Pike
    // 7.2.

    private string add_default(Parser.HTML p, mapping m, string c,
			       mapping defaults, RequestID id)
    {
      if(m->name) defaults[m->name]=Roxen.parse_rxml(c, id);
      return "";
    };

    private array no_more_attrib (Parser.HTML p, void|string ignored)
    {
      p->add_container ("attrib", 0);
      p->_set_tag_callback (0);
      p->_set_data_callback (0);
      p->add_quote_tag ("?", 0, "?");
      p->add_quote_tag ("![CDATA[", 0, "]]");
      return 0;
    };

    private array data_between_attribs (Parser.HTML p, string d)
    {
      sscanf (d, "%[ \t\n\r]", string ws);
      if (d != ws) no_more_attrib (p);
      return 0;
    }

    private array quote_other_entities (Parser.HTML p, string s, void|string scope_name)
    {
      // We know that s ends with ";", so it must be
      // longer than the following prefixes if they match.
      if (sscanf (s, "&_.%c", int c) && c != '.' ||
	  (scope_name &&
	   sscanf (s, "&" + replace (scope_name, "%", "%%") + ".%c", c) &&
	   c != '.'))
	return 0;
      return ({"&:", s[1..]});
    }

    array do_return(RequestID id) {
      string n;
      RXML.Context ctx = RXML_CONTEXT;

      if(n=args->variable) {
	if(args->trimwhites) content=String.trim_all_whites((string)content);
	RXML.user_set_var(n, content, args->scope);
	return 0;
      }

      if (n=args->tag||args->container) {
	int moreflags=0;
	if(args->tag) {
	  moreflags = RXML.FLAG_EMPTY_ELEMENT;
	  m_delete(args, "tag");
	} else
	  m_delete(args, "container");

	if (!def) {
	  defaults=([]);

	  if(!content) content = "";

	  Parser.HTML p;
	  p = Parser.get_xml_parser();
	  p->add_container ("attrib", ({add_default, defaults, id}));
	  // Stop parsing for attrib tags when we reach something else
	  // than whitespace and comments.
	  p->_set_tag_callback (no_more_attrib);
	  p->_set_data_callback (data_between_attribs);
	  p->add_quote_tag ("?", no_more_attrib, "?");
	  p->add_quote_tag ("![CDATA[", no_more_attrib, "]]");

	  if (preparsed_contents_tags) {
	    // Translate the &_internal_.4711; references to
	    // &_.__contents__17;. This is necessary since the numbers
	    // in the _internal_ scope is only unique within the
	    // current parse context. Otoh it isn't safe to use
	    // &_.__contents__17; during preparse since the current
	    // scope varies.
	    int id = 0;
	    foreach (indices (preparsed_contents_tags), string var) {
	      preparsed_contents_tags["__contents__" + ++id] =
		preparsed_contents_tags[var];
	      m_delete (preparsed_contents_tags, var);
	      p->add_entity ("_internal_." + var, "&_.__contents__" + id + ";");
	      m_delete (ctx->scopes->_internal_, var);
	    }

	    // Quote all entities except those handled above and those
	    // in the current scope, to avoid repeated evaluation of
	    // them in the expansion phase in UserTag. We use the rxml
	    // special "&:foo;" quoting syntax.
	    p->_set_entity_callback (quote_other_entities);
	    if (args->scope) p->set_extra (args->scope);
	  }

	  content = p->finish (content)->read();

	  if(args->trimwhites) {
	    content=String.trim_all_whites(content);
	    m_delete (args, "trimwhites");
	  }

#ifdef DEBUG
	  if (defaults->_debug_) {
	    moreflags |= RXML.FLAG_DEBUG;
	    m_delete (defaults, "_debug_");
	  }
#endif

	  def = ({content});
	}

	string lookup_name = "tag\0" + n;
	array oldtagdef;
	UserTag user_tag;
	if ((oldtagdef = ctx->misc[lookup_name]) &&
	    !((user_tag = oldtagdef[3])->flags & RXML.FLAG_EMPTY_ELEMENT) ==
	    !(moreflags & RXML.FLAG_EMPTY_ELEMENT)) // Redefine.
	  ctx->set_misc (lookup_name, ({def, defaults, args->scope, user_tag,
					preparsed_contents_tags}));
	else {
	  user_tag = UserTag (n, moreflags);
	  ctx->set_misc (lookup_name, ({def, defaults, args->scope, user_tag,
					preparsed_contents_tags}));
	  ctx->add_runtime_tag(user_tag);
	}
	return 0;
      }

      if (n=args->if) {
	ctx->set_misc ("if\0" + n, UserIf (n, content));
	return 0;
      }

      if (n=args->name) {
	ctx->set_misc (n, content);
	//old_rxml_warning(id, "attempt to define name ","variable");
        // NGSERVER deprecated, to be dropped
	return 0;
      }

      parse_error("No tag, variable, if or container specified.\n");
    }

    array save() {return ({def, defaults, preparsed_contents_tags});}
    void restore (array saved) {[def, defaults, preparsed_contents_tags] = saved;}
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
	RXML_CONTEXT->user_delete_var(n, args->scope);
	return 0;
      }

      if (n=args->tag||args->container) {
	m_delete (RXML_CONTEXT->misc, "tag\0" + n);
	RXML_CONTEXT->remove_runtime_tag(n);
	return 0;
      }

      if (n=args->if) {
	m_delete(RXML_CONTEXT->misc, "if\0" + n);
	return 0;
      }

      if (n=args->name) {
	m_delete(RXML_CONTEXT->misc, args->name);
	return 0;
      }

      parse_error("No tag, variable, if or container specified.\n");
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

// --------------------- Documentation -----------------------

TAGDOCUMENTATION;
#ifdef manual
constant tagdoc=([

//----------------------------------------------------------------------

"maketag":({ #"<desc type='cont'><p><short hide='hide'>
 Makes it possible to create tags.</short>This tag creates tags.
 The contents of the container will be put into the contents of the produced container.
</p></desc>

<attr name='name' value='string'>
 <p>The name of the tag that should be produced. This attribute is required for tags,
 containers and processing instructions, i.e. for the types 'tag', 'container' and 'pi'.</p>
<ex-src><maketag name='one' type='tag'></maketag>
<maketag name='one' type='tag' noxml='noxml'></maketag></ex-src>
</attr>

<attr name='noxml'>
 <p>Tags should not be terminated with a trailing slash. Only makes a difference for
 the type 'tag'.</p>
</attr>

<attr name='type' value='tag|container|pi|comment|cdata'>
 <p>What kind of tag should be produced. The argument 'Pi' will produce a processing instruction tag.</p>
<ex-src><maketag type='pi' name='PICS'>l gen true r (n 0 s 0 v 0 l 2)</maketag></ex-src>
<ex-src><maketag type='comment'>Menu starts here</maketag></ex-src>
<ex-box><maketag type='comment'>Debug: &form.res; &var.sql;</maketag></ex-box>
<ex-src><maketag type='cdata'>Exact   words</maketag></ex-src>
</attr>",

 ([
   "attrib":#"<desc type='cont'><p>
   Inside the maketag container the container
   <tag>attrib</tag> is defined. It is used to add attributes to the produced
   tag. The contents of the attribute container will be the
   attribute value. E.g.</p>
   </desc>

<ex><eval>
<maketag name=\"replace\" type=\"container\">
 <attrib name=\"from\">A</attrib>
 <attrib name=\"to\">U</attrib>
 MAD
</maketag>
</eval>
</ex>

   <attr name='name' value='string' required='required'>
   <p>The name of the attribute.</p>
   </attr>"
 ])
   }),

//----------------------------------------------------------------------

"use":#"<desc type='cont'><p><short>
 Reads <i>tag definitions</i>, user defined <i>if plugins</i> and 
 <i>variables</i> from a file or package and includes into the 
 current page.</short></p>
 <note><p>The file itself is not inserted into the page. This only 
 affects the environment in which the page is parsed. The benefit is 
 that the package file needs only be parsed once, and the compiled 
 versions of the user defined tags can then be used, thus saving time. 
 It is also a fairly good way of creating templates for your website. 
 Just define your own tags for constructions that appears frequently 
 and save both space and time. Since the tag definitions are cached 
 in memory, make sure that the file is not dependent on anything dynamic, 
 such as form variables or client settings, at the compile time. Also 
 note that the use tag only lets you define variables in the form 
 and var scope in advance. Variables with the same name will be 
 overwritten when the use tag is parsed.</p></note>
</desc>

<attr name='packageinfo'><p>
 Show a list of all available packages.</p>
</attr>

<attr name='package' value='name'><p>
 Reads all tags, container tags and defines from the given package.
 Packages are files located by default in <i>../rxml_packages/</i>.</p>
</attr>

<attr name='file' value='path'><p>
 Reads all tags and container tags and defines from the file.</p>

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

//----------------------------------------------------------------------

"define":({ #"<desc type='cont'><p><short>
Defines new tags, containers and if-callers. Can also be used to set
variable values.</short></p>

<p>The attributes \"tag\", \"container\", \"if\" and \"variable\"
specifies what is being defined. Exactly one of them are required. See
the respective attributes below for further information.</p></desc>

<attr name='variable' value='name'><p>
 Sets the value of the variable to the contents of the container.</p>
</attr>

<attr name='tag' value='name'><p>
 Defines a tag with the given name that doesn't take any content. When
 the defined tag is used, the content of this <tag>define</tag> is
 RXML parsed and the result is inserted in place of the defined tag.
 The arguments to the defined tag are available in the current scope
 in the <tag>define</tag>. An example:

 <ex><define tag='my-tag'>
  <inc variable='var.counter'/>
  A counter: &var.counter;<br />
  The 'foo' argument is: &_.foo;<br />
</define>
<my-tag/>
<my-tag foo='bar'/></ex>
</p>
</attr>

<attr name='container' value='name'><p>
 Like the 'tag' attribute, but the defined tag may also take content.
 The unevaluated content is available in <ent>_.contents</ent> inside
 the <tag>define</tag> (see the scope description below). You can also
 get the content after RXML evaluation with the <tag>contents</tag>
 tag - see below for further details.</p>
</attr>

<attr name='if' value='name'><p>
 Defines an if-caller that compares something with the contents of the
 container.</p>
</attr>

<attr name='trimwhites'><p>
 Trim all white space characters from the beginning and the end of the
 contents.</p>
</attr>

<attr name='preparse'><p>
 Sends the definition through the RXML parser when the
 <tag>define</tag> is executed instead of when the defined tag is
 used.</p>

 <p>Compatibility notes: If the compatibility level is 2.2 or earlier,
 the result from the RXML parse is parsed again when the defined tag
 is used, which can be a potential security problem. Also, if the
 compatibility level is 2.2 or earlier, the <tag>define</tag> tag does
 not set up a local scope during the preparse pass, which means that
 the enclosed code will still use the closest surrounding \'_\'
 scope.</p>
</attr>",

	    ([
"attrib":#"<desc type='cont'><p>
 When defining a tag or a container the tag <tag>attrib</tag>
 can be used to define default values of the attributes that the
 tag/container can have. The attrib tag must be the first tag(s)
 in the define tag.</p>
</desc>

 <attr name='name' value='name'><p>
  The name of the attribute which default value is to be set.</p>
 </attr>",

"&_.args;":#"<desc type='entity'><p>
 The full list of the attributes, and their arguments, given to the
 tag.
</p></desc>",

"&_.rest-args;":#"<desc type='entity'><p>
 A list of the attributes, and their arguments, given to the tag,
 excluding attributes with default values defined.
</p></desc>",

"&_.contents;":#"<desc type='entity'><p>
 The unevaluated contents of the container.
</p></desc>",

"contents":#"<desc type='tag'><p>
 Inserts the whole or some part of the arguments or the contents
 passed to the defined tag or container.</p>

 <p>The passed contents are RXML evaluated in the first encountered
 <tag>contents</tag>; the later ones reuses the result of that.
 (However, if it should be compatible with 2.2 or earlier then it\'s
 reevaluated each time unless there\'s a \'copy-of\' or \'value-of\'
 attribute.)</p>

 <p>Note that when the preparse attribute is used, this tag is
 converted to a special variable reference on the form
 \'<ent>_.__contents__<i>n</i></ent>\', which is then substituted with
 the real value when the defined tag is used. It\'s that way to make
 the expansion work when the preparsed code puts it in an attribute
 value. (This is mostly an internal implementation detail, but it can
 be good to know since the variable name might show up.)
</p></desc>

<attr name='scope' value='scope'><p>
 Associate this <tag>contents</tag> tag with the innermost
 <tag>define</tag> container with the given scope. The default is to
 associate it with the innermost <tag>define</tag>.</p>
</attr>

<attr name='eval'><p>
 When this attribute exists, the passed content is (re)evaluated
 unconditionally before being inserted. Normally the evaluated content
 from the preceding <tag>contents</tag> tag is reused, and it\'s only
 evaluated if this is the first encountered <tag>contents</tag>.</p>
</attr>

<attr name='copy-of' value='expression'><p>
 Selects a part of the content node tree to copy. As opposed to the
 value-of attribute, all the selected nodes are copied, with all
 markup.</p>

 <p>The expression is a simplified variant of an XPath location path:
 It consists of one or more steps delimited by \'<tt>/</tt>\'.
 Each step selects some part(s) of the current node. The first step
 operates on the defined tag or container itself, and each following
 one operates on the part(s) selected by the previous step.</p>

 <p>A step may be any of the following:</p>

 <list type=\"ul\">
   <item><p>\'<i>name</i>\' selects all elements (i.e. tags or
   containers) with the given name in the content. The name can be
   \'<tt>*</tt>\' to select all.</p></item>

   <item><p>\'<tt>@</tt><i>name</i>\' selects the element attribute
   with the given name. The name can be \'<tt>*</tt>\' to select
   all.</p></item>

   <item><p>\'<tt>comment()</tt>\' selects all comments in the
   content.</p></item>

   <item><p>\'<tt>text()</tt>\' selects all text pieces in the
   content.</p></item>

   <item><p>\'<tt>processing-instruction(<i>name</i>)</tt>\' selects
   all processing instructions with the given name in the content. The
   name may be left out to select all.</p></item>

   <item><p>\'<tt>node()</tt>\' selects all the different sorts of
   nodes in the content, i.e. the whole content.</p></item>
 </list>

 <p>A step may be followed by \'<tt>[<i>n</i>]</tt>\' to choose
 the nth item in the selected set. The index n may be negative to
 select an element in reverse order, i.e. -1 selects the last element,
 -2 the second-to-last, etc.</p>

 <p>An example: The expression \'<tt>p/*[2]/@href</tt>\' first
 selects all <tag>p</tag> elements in the content. In the content of
 each of these, the second element with any name is selected. It\'s
 not an error if some of the <tag>p</tag> elements have less than two
 child elements; those who haven\'t are simply ignored. Lastly, all
 \'href\' attributes of all those elements are selected. Again it\'s
 not an error if some of the elements lack \'href\' attributes.</p>

 <p>Note that an attribute node is both the name and the value, so in
 the example above the result might be
 \'<tt>href=\"index.html\"</tt>\' and not
 \'<tt>index.html</tt>\'. If you only want the value, use the
 value-of attribute instead.</p>
</attr>

<attr name='value-of' value='expression'><p>
 Selects a part of the content node tree and inserts its text value.
 As opposed to the copy-of attribute, only the value of the first
 selected node is inserted. The expression is the same as for the
 copy-of attribute.</p>

 <p>The text value of an element node is all the text in it and all
 its subelements, without the elements themselves or any processing
 instructions.</p>
</attr>"
	    ])

}),

//----------------------------------------------------------------------

"undefine":#"<desc type='tag'><p><short>
 Removes a definition made by the define container.</short> One
 attribute is required.
</p></desc>

<attr name='variable' value='name'><p>
 Undefines this variable.</p>

 <ex>
  <define variable='var.hepp'>hopp</define>
  &var.hepp;
  <undefine variable='var.hepp'/>
  &var.hepp;
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

//----------------------------------------------------------------------

"noparse":#"<desc type='cont'><p><short>
 The contents of this container tag won't be RXML parsed.</short>
</p></desc>",

//----------------------------------------------------------------------

"?noparse": #"<desc type='pi'><p><short>
 The content is inserted as-is, without any parsing or
 quoting.</short> The first whitespace character (i.e. the one
 directly after the \"noparse\" name) is discarded.</p>
</desc>",

//----------------------------------------------------------------------

    ]);
#endif
