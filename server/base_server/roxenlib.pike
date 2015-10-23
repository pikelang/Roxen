// This file is part of Roxen WebServer.
// Copyright © 1996 - 2009, Roxen IS.
// $Id$

//#pragma strict_types

#include <roxen.h>
#include <config.h>
#include <stat.h>
#include <variables.h>

// Reference every public symbol in Roxen.pmod for compatibility.
// Can't inherit Roxen.pmod here since that'd cause duplicate
// instances of all its constants and scopes and stuff.
//
// Note that this list doesn't need to be kept up-to-date with
// additions in Roxen.pmod since we only do this for compatibility.
constant parse_box_xml = Roxen.parse_box_xml;
constant ip_to_int = Roxen.ip_to_int;
constant http_roxen_config_cookie = Roxen.http_roxen_config_cookie;
constant http_roxen_id_cookie = Roxen.http_roxen_id_cookie;
constant get_cookie_callback = Roxen.get_cookie_callback;
constant get_remoteaddr = Roxen.get_remoteaddr;
constant msectos = Roxen.msectos;
constant decode_mode = Roxen.decode_mode;
constant add_http_header = Roxen.add_http_header;
constant is_mysql_keyword = Roxen.is_mysql_keyword;
constant short_name = Roxen.short_name;
constant _match = Roxen._match;
constant http_low_answer = Roxen.http_low_answer;
constant http_status = Roxen.http_status;
constant http_method_not_allowed = Roxen.http_method_not_allowed;
constant http_pipe_in_progress = Roxen.http_pipe_in_progress;
constant http_rxml_answer = Roxen.http_rxml_answer;
constant http_try_again = Roxen.http_try_again;
constant http_try_resume = Roxen.http_try_resume;
constant http_string_answer = Roxen.http_string_answer;
constant http_file_answer = Roxen.http_file_answer;
constant log_date = Roxen.log_date;
constant log_time = Roxen.log_time;
constant cern_http_date = Roxen.cern_http_date;
constant http_status_message = Roxen.http_status_message;
constant http_date = Roxen.http_date;
constant iso8601_date_time = Roxen.iso8601_date_time;
#if !defined (MODULE_DEBUG) ||						\
  defined (ENABLE_INHERENTLY_BROKEN_HTTP_ENCODE_STRING_FUNCTION)
constant http_encode_string = Roxen.http_encode_string;
#endif
constant http_encode_invalids = Roxen.http_encode_invalids;
constant http_encode_cookie = Roxen.http_encode_cookie;
constant http_encode_url = Roxen.http_encode_url;
constant correctly_http_encode_url = Roxen.correctly_http_encode_url;
constant add_pre_state = Roxen.add_pre_state;
constant http_redirect = Roxen.http_redirect;
constant http_stream = Roxen.http_stream;
constant http_digest_required = Roxen.http_digest_required;
constant http_auth_required = Roxen.http_auth_required;
constant http_proxy_auth_required = Roxen.http_proxy_auth_required;
constant extract_query = Roxen.extract_query;
constant build_env_vars = Roxen.build_env_vars;
constant build_roxen_env_vars = Roxen.build_roxen_env_vars;
constant strip_config = Roxen.strip_config;
constant strip_prestate = Roxen.strip_prestate;
constant compile_rxml = Roxen.compile_rxml;
constant eval_p_code = Roxen.eval_p_code;
constant get_rxml_parser = Roxen.get_rxml_parser;
constant get_xml_parser = Roxen.get_xml_parser;
constant iso88591 = Roxen.iso88591;
constant international = Roxen.international;
constant symbols = Roxen.symbols;
constant greek = Roxen.greek;
constant replace_entities = Roxen.replace_entities;
constant replace_values = Roxen.replace_values;
constant safe_characters = Roxen.safe_characters;
constant empty_strings = Roxen.empty_strings;
constant is_safe_string = Roxen.is_safe_string;
constant make_entity = Roxen.make_entity;
constant make_tag_attributes = Roxen.make_tag_attributes;
constant make_tag = Roxen.make_tag;
constant make_container = Roxen.make_container;
constant add_config = Roxen.add_config;
constant extension = Roxen.extension;
constant backup_extension = Roxen.backup_extension;
constant win_drive_prefix = Roxen.win_drive_prefix;
constant simplify_path = Roxen.simplify_path;
constant short_date = Roxen.short_date;
constant int2roman = Roxen.int2roman;
constant number2string = Roxen.number2string;
constant image_from_type = Roxen.image_from_type;
constant sizetostring = Roxen.sizetostring;
constant html_decode_string = Roxen.html_decode_string;
constant html_encode_tag_value = Roxen.html_encode_tag_value;
constant strftime = Roxen.strftime;
constant get_module = Roxen.get_module;
constant get_modname = Roxen.get_modname;
constant get_modfullname = Roxen.get_modfullname;
constant roxen_encode = Roxen.roxen_encode;
constant fix_relative = Roxen.fix_relative;
constant open_log_file = Roxen.open_log_file;
constant tagtime = Roxen.tagtime;
constant time_dequantifier = Roxen.time_dequantifier;
constant _charset_decoder = Roxen._charset_decoder;
constant magic_charset_variable_placeholder = Roxen.magic_charset_variable_placeholder;
constant magic_charset_variable_value = Roxen.magic_charset_variable_value;
constant get_client_charset_decoder = Roxen.get_client_charset_decoder;
#if constant(HAVE_OLD__Roxen_make_http_headers)
constant make_http_headers = Roxen.make_http_headers;
#endif /* constant(HAVE_OLD__Roxen_make_http_headers) */
constant QuotaDB = Roxen.QuotaDB;
constant EScope = Roxen.EScope;
constant SRestore = Roxen.SRestore;
constant add_scope_constants = Roxen.add_scope_constants;
constant parser_charref_table = Roxen.parser_charref_table;
constant inverse_charref_table = Roxen.inverse_charref_table;
constant decode_charref = Roxen.decode_charref;
constant safe_compile = Roxen.safe_compile;
constant encode_charref = Roxen.encode_charref;
constant ScopeRequestHeader = Roxen.ScopeRequestHeader;
constant ScopeRoxen = Roxen.ScopeRoxen;
constant get_ssl_strength = Roxen.get_ssl_strength;
constant ScopePage = Roxen.ScopePage;
constant ScopeCookie = Roxen.ScopeCookie;
constant scope_request_header = Roxen.scope_request_header;
constant scope_roxen = Roxen.scope_roxen;
constant scope_page = Roxen.scope_page;
constant scope_cookie = Roxen.scope_cookie;
constant ScopeModVar = Roxen.ScopeModVar;
constant scope_modvar = Roxen.scope_modvar;
constant FormScope = Roxen.FormScope;
constant scope_form = Roxen.scope_form;
constant entities_tag_set = Roxen.entities_tag_set;
constant monthnum= Roxen.monthnum;
constant parse_since = Roxen.parse_since;
constant is_modified = Roxen.is_modified;
constant httpdate_to_time = Roxen.httpdate_to_time;
constant set_cookie = Roxen.set_cookie;
constant remove_cookie = Roxen.remove_cookie;
constant add_cache_stat_callback = Roxen.add_cache_stat_callback;
constant add_cache_callback = Roxen.add_cache_callback;
constant get_server_url = Roxen.get_server_url;
constant get_world = Roxen.get_world;
constant get_owning_module = Roxen.get_owning_module;
constant get_owning_config = Roxen.get_owning_config;
#ifdef REQUEST_TRACE
constant trace_enter = Roxen.trace_enter;
constant trace_leave = Roxen.trace_leave;
#endif
constant init_wiretap_stack = Roxen.init_wiretap_stack;
constant push_color = Roxen.push_color;
constant pop_color = Roxen.pop_color;

// Low-level C-roxen optimization functions. FIXME: Avoid inheriting this too.
inherit _Roxen;

//! The old Roxen standard library. Everything defined in this class,
//! i.e. not the inherited, is to be considered deprecated. The
//! inherited functions are available directly from @[Roxen] instead.

#define roxen roxenp()

//! Converted the integer @[color] into a six character hexadecimal
//! value prepended with "#", e.g. "#FF8C00". Does the same thing as
//! @code
//!    sprintf("#%06X", color);
//! @endcode
protected string conv_hex( int color )
{
  return sprintf("#%06X", color);
}

//! Creates a proxy authentication needed response (error 407)
//! if no authentication is given, access denied (error 403)
//! on failed authentication and 0 otherwise.
mapping proxy_auth_needed(RequestID id)
{
  int|mapping res = id->conf->check_security(proxy_auth_needed, id);
  if(res)
  {
    if(res==1) // Nope...
      return http_low_answer(403, "You are not allowed to access this proxy");
    if(!mappingp(res))
      return 0; // Error, really.
    res->error = 407;
    return [mapping]res;
  }
  return 0;
}

//! Figures out the filename of the file which defines the program
//! for this object. Please use __FILE__ instead if possible.
string program_filename()
{
  return master()->program_name(this_object())||"";
}

//! Returns the directory part of @[program_filename()].
string program_directory()
{
  array(string) p = program_filename()/"/";
  return (sizeof(p)>1? p[..sizeof(p)-2]*"/" : getcwd());
}

//! Creates an HTTP response string from the internal
//! file representation mapping @[file].
protected string http_res_to_string( mapping file, RequestID id )
{
  mapping(string:string|array(string)) heads=
    ([
      "Content-type":[string]file["type"],
      "Server":replace(roxen->version(), " ", "_"),
      "Date":http_date([int]id->time)
      ]);

  if(file->encoding)
    heads["Content-Encoding"] = [string]file->encoding;

  if(!file->error)
    file->error=200;

  if(file->expires)
      heads->Expires = http_date([int]file->expires);

  if(!file->len)
  {
    if(objectp(file->file))
      if(!file->stat && !(file->stat=([mapping(string:mixed)]id->misc)->stat))
	file->stat = (array(int))file->file->stat();
    array fstat;
    if(arrayp(fstat = file->stat))
    {
      if(file->file && !file->len)
	file->len = fstat[1];

      heads["Last-Modified"] = http_date([int]fstat[3]);
    }
    if(stringp(file->data))
      file->len += strlen([string]file->data);
  }

  if(mappingp(file->extra_heads))
    heads |= file->extra_heads;

  if(mappingp(([mapping(string:mixed)]id->misc)->moreheads))
    heads |= ([mapping(string:mixed)]id->misc)->moreheads;

  array myheads=({id->prot+" "+
		  replace (file->rettext||errors[file->error], "\n", " ")});
  foreach(indices(heads), string h)
    if(arrayp(heads[h]))
      foreach([array(string)]heads[h], string tmp)
	myheads += ({ `+(h,": ", tmp)});
    else
      myheads +=  ({ `+(h, ": ", heads[h])});


  if(file->len > -1)
    myheads += ({"Content-length: " + file->len });
  string head_string = (myheads+({"",""}))*"\r\n";

  if(id->conf) {
    id->conf->hsent+=strlen(head_string||"");
    if(id->method != "HEAD")
      id->conf->sent+=(file->len>0 ? file->len : 1000);
  }
  if(id->method != "HEAD")
    head_string+=(file->data||"")+(file->file?file->file->read():"");
  return head_string;
}

//! Returns the dimensions of the file @[gif] as
//! a string like @tt{"width=17 height=42"@}. Use
//! @[Dims] instead.
protected string gif_size(Stdio.File gif)
{
  array(int) xy=Dims.dims()->get(gif);
  return "width="+xy[0]+" height="+xy[1];
}

//! Returns @[x] to the power of @[y].
protected int ipow(int x, int y)
{
  return (int)pow(x, y);
}

//! Compares @[a] with @[b].
//!
//! If both @[a] & @[b] contain only digits, they will be compared
//! as integers, and otherwise as strings.
//!
//! @returns
//!   @int
//!     @value 1
//!       a > b
//!     @value 0
//!       a == b
//!     @value -1
//!       a < b
//!   @endint
protected int compare( string a, string b )
{
  if (!a)
    if (b)
      return -1;
    else
      return 0;
  else if (!b)
    return 1;
  else if ((string)(int)a == a && (string)(int)b == b)
    if ((int )a > (int )b)
      return 1;
    else if ((int )a < (int )b)
      return -1;
    else
      return 0;
  else
    if (a > b)
      return 1;
    else if (a < b)
      return -1;
    else
      return 0;
}

protected string do_output_tag( mapping(string:string) args,
				array(mapping(string:string)|object) var_arr,
				string contents, RequestID id )
//! Method for use by tags that replace variables in their content,
//! like formoutput, sqloutput and others.
//!
//! @note
//!   This function is obsolete. This kind of functionality is now
//!   provided intrinsicly by the new RXML parser framework, in a way
//!   that avoids many of the problems that stems from this function.
{
  string quote = args->quote || "#";
  mapping(string:string) other_vars = [mapping(string:string)]id->misc->variables;
  string new_contents = "", unparsed_contents = "";
  int first;

  // multi_separator must default to \000 since one sometimes need to
  // pass multivalues through several output tags, and it's a bit
  // tricky to set it to \000 in a tag..
  string multi_separator = args->multi_separator || args->multisep || "\000";

  if (args->preprocess)
    contents = Roxen.parse_rxml( contents, id );

  switch (args["debug-input"]) {
    case 0: break;
    case "log":
      report_debug ("tag input: " + contents + "\n");
      break;
    case "comment":
      new_contents = "<!--\n" + html_encode_string (contents) + "\n-->";
      break;
    default:
      new_contents = "\n<br><b>[</b><pre>" +
	html_encode_string (contents) + "</pre><b>]</b>\n";
  }

  if (args->sort)
  {
    array(string) order = args->sort / "," - ({ "" });
    var_arr = Array.sort_array( var_arr,
				lambda (mapping(string:string)|object m1,
					mapping(string:string)|object m2)
				{
				  int tmp;

				  foreach (order, string field)
				  {
				    int tmp;

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

  if (args->range)
  {
    int begin, end;
    string b, e;


    sscanf( args->range, "%s..%s", b, e );
    if (!b || b == "")
      begin = 0;
    else
      begin = (int )b;
    if (!e || e == "")
      end = -1;
    else
      end = (int )e;

    if (begin < 0)
      begin += sizeof( var_arr );
    if (end < 0)
      end += sizeof( var_arr );
    if (begin > end)
      return "";
    if (begin < 0)
      if (end < 0)
	return "";
      else
	begin = 0;
    var_arr = var_arr[begin..end];
  }

  first = 1;
  foreach (var_arr, mapping(string:string)|object vars)
  {
    if (args->set)
      foreach (indices (vars), string var) {
	array|string val = vars[var];
	if (!val) val = args->zero || "";
	else {
	  if (arrayp( val ))
	    val = Array.map (val, lambda (mixed v) {return (string) v;}) *
	      multi_separator;
	  else
	    val = replace ((string) val, "\000", multi_separator);
	  if (!sizeof (val)) val = args->empty || "";
	}
	id->variables[var] = [string]val;
      }

    id->misc->variables = vars;

    if (!args->replace || lower_case( args->replace ) != "no")
    {
      array exploded = contents / quote;
      if (!(sizeof (exploded) & 1))
	return "<b>Content ends inside a replace field</b>";

      for (int c=1; c < sizeof( exploded ); c+=2)
	if (exploded[c] == "")
	  exploded[c] = quote;
	else
	{
	  array(string) options =  [string]exploded[c] / ":";
	  string var = String.trim_whites(options[0]);
	  mixed val = vars[var];
	  array(string) encodings = ({});
	  string multisep = multi_separator;
	  string zero = args->zero || "";
	  string empty = args->empty || "";

	  foreach(options[1..], string option) {
	    array (string) foo = option / "=";
	    string optval = String.trim_whites(foo[1..] * "=");

	    switch (lower_case (String.trim_whites( foo[0] ))) {
	      case "empty":
		empty = optval;
		break;
	      case "zero":
		zero = optval;
		break;
	      case "multisep":
	      case "multi_separator":
		multisep = optval;
		break;
	      case "quote":	// For backward compatibility.
		optval = lower_case (optval);
		switch (optval) {
		  case "mysql": case "sql": case "oracle":
		    encodings += ({optval + "-dtag"});
		    break;
		  default:
		    encodings += ({optval});
		}
		break;
	      case "encode":
		encodings += Array.map (lower_case (optval) / ",", String.trim_whites);
		break;
	      default:
		return "<b>Unknown option " + String.trim_whites(foo[0]) +
		  " in replace field " + ((c >> 1) + 1) + "</b>";
	    }
	  }

	  if (!val)
	    if (zero_type (vars[var]) && (args->debug || id->misc->debug))
	      val = "<b>No variable " + options[0] + "</b>";
	    else
	      val = zero;
	  else {
	    if (arrayp( val ))
	      val = Array.map (val, lambda (mixed v) {return (string) v;}) *
		multisep;
	    else
	      val = replace ((string) val, "\000", multisep);
	    if (!sizeof ([string]val)) val = empty;
	  }

	  if (!sizeof (encodings))
	    encodings = args->encode ?
	      Array.map (lower_case (args->encode) / ",", String.trim_whites) : ({"html"});

	  foreach (encodings, string encoding)
	    if( !(val = roxen_encode( [string]val, encoding )) )
	      return ("<b>Unknown encoding " + encoding
		      + " in replace field " + ((c >> 1) + 1) + "</b>");

	  exploded[c] = val;
	}

      if (first)
	first = 0;
      else if (args->delimiter)
	new_contents += args->delimiter;
      new_contents += args->preprocess ? exploded * "" :
	Roxen.parse_rxml (exploded * "", id);
      if (args["debug-output"]) unparsed_contents += exploded * "";
    }
    else {
      new_contents += args->preprocess ? contents : Roxen.parse_rxml (contents, id);
      if (args["debug-output"]) unparsed_contents += contents;
    }
  }

  switch (args["debug-output"]) {
    case 0: break;
    case "log":
      report_debug ("tag output: " + unparsed_contents + "\n");
      break;
    case "comment":
      new_contents += "<!--\n" + html_encode_string (unparsed_contents) + "\n-->";
      break;
    default:
      new_contents = "\n<br><b>[</b><pre>" + html_encode_string (unparsed_contents) +
	"</pre><b>]</b>\n";
  }

  id->misc->variables = other_vars;
  return new_contents;
}

//! Works like @[Roxen.parse_rxml()], but also takes the optional
//! arguments @[file] and @[defines].
string parse_rxml(string what, RequestID id,
			 void|Stdio.File file,
			 void|mapping(string:mixed) defines)
{
  if(!objectp(id)) error("No id passed to parse_rxml\n");
  return id->conf->parse_rxml( what, id, file, defines );
}
