// This file is part of Roxen Webserver.
// Copyright © 1996 - 2000, Roxen IS.
// $Id: roxenlib.pike,v 1.208 2000/12/11 03:07:11 per Exp $

//#pragma strict_types

#include <roxen.h>
#include <config.h>
#include <stat.h>

inherit Roxen;

#define roxen roxenp()

// Functions declared as static are not reachable through Roxen.pmod.
// These functions are to be considered deprecated.

static string gif_size(Stdio.File gif)
{
  array(int) xy=Dims.dims()->get(gif);
  return "width="+xy[0]+" height="+xy[1];
}

static int ipow(int what, int how)
{
  return (int)pow(what, how);
}


static int compare( string a, string b )
// This method needs lot of work... but so do the rest of the system too
// RXML needs types
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

static string do_output_tag( mapping(string:string) args, array(mapping(string:string)) var_arr,
			     string contents, RequestID id )
//! Method for use by tags that replace variables in their content,
//! like formoutput, sqloutput and others.
//!
//! NOTE: This function is obsolete. This kind of functionality is now
//! provided intrinsicly by the new RXML parser framework, in a way
//! that avoids many of the problems that stems from this function.
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
    contents = parse_rxml( contents, id );

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
				lambda (mapping(string:string) m1,
					mapping(string:string) m2)
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
  foreach (var_arr, mapping(string:string) vars)
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

	  string tmp_val;
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
	parse_rxml (exploded * "", id);
      if (args["debug-output"]) unparsed_contents += exploded * "";
    }
    else {
      new_contents += args->preprocess ? contents : parse_rxml (contents, id);
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

