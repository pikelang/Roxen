// This is a ChiliMoon module which provides tags which aid RXML development
//
// This module is open source software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License as published
// by the Free Software Foundation; either version 2, or (at your option) any
// later version.
//

#define _ok id->misc->defines[" _ok"]

constant cvs_version =
 "$Id: development.pike,v 1.2 2004/05/31 14:42:34 _cvs_stephen Exp $";
constant thread_safe = 1;
constant module_unique = 1;

#include <module.h>
#include <request_trace.h>

inherit "module";


// ---------------- Module registration stuff ----------------

constant module_type = MODULE_TAG;
constant module_name = "Tags: RXML Development";
constant module_doc  =
 "This module provides tags which aid RXML development.<br />"
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

class TagDebug {
  inherit RXML.Tag;
  constant name = "debug";
  constant flags = RXML.FLAG_EMPTY_ELEMENT|RXML.FLAG_CUSTOM_TRACE;

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      if (args->showid) {
	TAG_TRACE_ENTER("");
	array path=lower_case(args->showid)/"->";
	if(path[0]!="id" || sizeof(path)==1) RXML.parse_error("Can only show parts of the id object.");
	mixed obj=id;
	foreach(path[1..], string tmp) {
	  if(!has_value(indices(obj),tmp)) RXML.run_error("Could only reach "+tmp+".");
	  obj=obj[tmp];
	}
	result = "<pre>"+Roxen.html_encode_string(sprintf("%O",obj))+"</pre>";
	TAG_TRACE_LEAVE("");
	return 0;
      }
      if (args->werror) {
	report_debug("%^s%#-1s\n",
		     "<debug>: ",
		     id->conf->query_name()+":"+id->not_query+"\n"+
		     replace(args->werror,"\\n","\n") );
	TAG_TRACE_ENTER ("message: %s", args->werror);
      }
      else
	TAG_TRACE_ENTER ("");
      if (args->off)
	id->misc->debug = 0;
      else if (args->toggle)
	id->misc->debug = !id->misc->debug;
      else
	id->misc->debug = 1;
      //result = "<!-- Debug is "+(id->misc->debug?"enabled":"disabled")+" -->";
      TAG_TRACE_LEAVE ("");
      return 0;
    }
  }
}

class TagIfModuleDebug {
  inherit RXML.Tag;
  constant name = "if";
  constant plugin_name = "module-debug";

  int eval( string dbg, RequestID id, mapping m ) {
#ifdef MODULE_DEBUG
    return 1;
#else
    return 0;
#endif
  }
}

class TagInsertVariables {
  inherit RXML.Tag;
  constant name = "insert";
  constant plugin_name = "variables";

  string get_data(string var, mapping args) {
    RXML.Context context=RXML_CONTEXT;
    if(var=="full")
      return map(sort(context->list_var(args->scope)),
		 lambda(string s) {
		   mixed value = context->get_var(s, args->scope);
		   if (zero_type (value))
		     return sprintf("%s=UNDEFINED", s);
		   else
		     return sprintf("%s=%O", s, value);
		 } ) * "\n";
    return String.implode_nicely(sort(context->list_var(args->scope)));
  }
}

class TagInsertScopes {
  inherit RXML.Tag;
  constant name = "insert";
  constant plugin_name = "scopes";

  string get_data(string var, mapping args) {
    RXML.Context context=RXML_CONTEXT;
    if(var=="full") {
      string result = "";
      foreach(sort(context->list_scopes()), string scope) {
	result += scope+"\n";
	result += Roxen.html_encode_string(map(sort(context->list_var(args->scope)),
					       lambda(string s) {
						 return sprintf("%s.%s=%O", scope, s,
								context->get_var(s, args->scope) );
					       } ) * "\n");
	result += "\n";
      }
      return result;
    }
    return String.implode_nicely(sort(context->list_scopes()));
  }
}

class TagGauge {
  inherit RXML.Tag;
  constant name = "gauge";

  class Frame {
    inherit RXML.Frame;
    int t;

    array do_enter(RequestID id) {
      NOCACHE();
      t=gethrtime();
    }

    array do_return(RequestID id) {
      t=gethrtime()-t;
      if(args->variable) RXML.user_set_var(args->variable, t/1000000.0, args->scope);
      if(args->silent) return ({ "" });
      if(args->timeonly) return ({ sprintf("%3.6f", t/1000000.0) });
      if(args->resultonly) return ({content});
      return ({ "<br /><font size=\"-1\"><b>Time: "+
		sprintf("%3.6f", t/1000000.0)+
		" seconds</b></font><br />"+content });
    }
  }
}

class TagHelp {
  inherit RXML.Tag;
  constant name = "help";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;

  class Frame {
    inherit "rxmlhelp";
    inherit RXML.Frame;

    array do_return(RequestID id) {
      string help_for = args->for || id->variables->_r_t_h;
      string ret="<h2>ChiliMoon Interactive RXML Help</h2>";

      if(!help_for) {
	NOCACHE();
	array tags=map(indices(RXML_CONTEXT->tag_set->get_tag_names()),
		       lambda(string tag) {
			 if (!has_prefix (tag, "_"))
			   if(tag[..3]=="!--#" || !has_value(tag, "#"))
			     return tag;
			 return "";
		       } ) - ({ "" });
	tags += map(indices(RXML_CONTEXT->tag_set->get_proc_instr_names()),
		    lambda(string tag) { return "&lt;?"+tag+"?&gt;"; } );
	tags = Array.sort_array(tags,
				lambda(string a, string b) {
				  if(has_prefix (a, "&lt;?")) a=a[5..];
				  if(has_prefix (b, "&lt;?")) b=b[5..];
				  if(lower_case(a)==lower_case(b)) return a > b;
				  return lower_case (a) > lower_case (b);
				})-({"\x266a"});   // What is this character?
						   // FIXME remove it?
	string char;
	ret += "<b>Here is a list of all defined tags. Click on the name to "
	  "receive more detailed information. All these tags are also availabe "
	  "in the \""+RXML_NAMESPACE+"\" namespace.</b><p>\n";
	array tag_links;

	foreach(tags, string tag) {
	  string tag_char =
	    lower_case (has_prefix (tag, "&lt;?") ? tag[5..5] : tag[0..0]);
	  if (tag_char != char) {
	    if(tag_links && char!="/") ret+="<h3>"+upper_case(char)+"</h3>\n<p>"+
					 String.implode_nicely(tag_links)+"</p>";
	    char = tag_char;
	    tag_links=({});
	  }
	  if(tag[0..sizeof(RXML_NAMESPACE)]!=RXML_NAMESPACE+":") {
	    string enc=tag;
	    if(enc[0..4]=="&lt;?") enc=enc[4..sizeof(enc)-6];
	    if(undocumented_tags && undocumented_tags[tag])
	      tag_links += ({ tag });
	    else
	      tag_links += ({ sprintf("<a href=\"%s?_r_t_h=%s\">%s</a>\n",
				      id->url_base() + id->not_query[1..],
				      Roxen.http_encode_url(enc), tag) });

	  }
	}

	ret+="<h3>"+upper_case(char)+"</h3>\n<p>"+String.implode_nicely(tag_links)+"</p>";
	/*
	ret+="<p><b>This is a list of all currently defined RXML scopes and their entities</b></p>";

	RXML.Context context=RXML_CONTEXT;
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

class Tracer (Configuration conf)
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

    resolv += font + "<li><b>»</b> " + type + "<ol>" + efont;
    start_clock();
  }

  void trace_leave_ol(string desc)
  {
    level--;

    string efont="", font="";
    if(level>1) {efont="</font>";font="<font size=-1>";}

    resolv += "</ol>" + font;
    if (sizeof (desc))
      resolv += "<b>«</b> " + Roxen.html_encode_string(desc);
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
      t = Tracer(id->conf);
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

class TagIfDebug {
  inherit RXML.Tag;
  constant name = "if";
  constant plugin_name = "debug";

  int eval( string dbg, RequestID id, mapping m ) {
#ifdef DEBUG
    return 1;
#else
    return 0;
#endif
  }
}

class TagEmitFonts
{
  inherit RXML.Tag;
  constant name = "emit", plugin_name = "fonts";
  array get_dataset(mapping args, RequestID id)
  {
    return roxen->fonts->get_font_information(args->ttf_only);
  }
}

class TagEmitSources {
  inherit RXML.Tag;
  constant name="emit";
  constant plugin_name="sources";

  array(mapping(string:string)) get_dataset(mapping m, RequestID id) {
    return Array.map( indices(RXML_CONTEXT->tag_set->get_plugins("emit")),
		      lambda(string source) { return (["source":source]); } );
  }
}

class TagIfTrue {
  inherit RXML.Tag;
  constant name = "if";
  constant plugin_name = "true";

  int eval(string u, RequestID id) {
    return _ok;
  }
}

class TagIfFalse {
  inherit RXML.Tag;
  constant name = "if";
  constant plugin_name = "false";

  int eval(string u, RequestID id) {
    return !_ok;
  }
}

// --------------------- Documentation -----------------------

TAGDOCUMENTATION;
#ifdef manual
constant tagdoc=([
"debug":#"<desc type='tag'><p><short>
 Helps debugging RXML-pages as well as modules.</short> When debugging mode is
 turned on, all error messages will be displayed in the HTML code.
</p></desc>

<attr name='on'>
 <p>Turns debug mode on.</p>
</attr>

<attr name='off'>
 <p>Turns debug mode off.</p>
</attr>

<attr name='toggle'>
 <p>Toggles debug mode.</p>
</attr>

<attr name='showid' value='string'>
 <p>Shows a part of the id object. E.g. showid=\"id->request_headers\".</p>
</attr>

<attr name='werror' value='string'>
  <p>When you have access to the server debug log and want your RXML
     page to write some kind of diagnostics message or similar, the
     werror attribute is helpful.</p>

  <p>This can be used on the error page, for instance, if you'd want
     such errors to end up in the debug log:</p>

  <ex-box><debug werror='File &page.url; not found!
(linked from &client.referrer;)'/></ex-box>

  <p>The message is also shown the request trace, e.g. when
  \"Tasks\"/\"Debug information\"/\"Resolve path...\" is used in the
  configuration interface.</p>
</attr>",

//----------------------------------------------------------------------

"insert#variables":#"<desc type='plugin'><p><short>
 Inserts a listing of all variables in a scope.</short></p><note><p>It is
 possible to create a scope with an infinite number of variables set.
 In this case the programmer of that scope decides which variables that
 should be listable, i.e. this will not cause any problem except that
 all variables will not be listed. It is also possible to hide
 variables so that they are not listed with this tag.
</p></note></desc>

<attr name='variables' value='full|plain'>
 <p>Sets how the output should be formatted.</p>

 <ex><pre>
<insert variables='full' scope='roxen'/>
</pre></ex>
</attr>

<attr name='scope'>
 <p>The name of the scope that should be listed, if not the present scope.</p>
</attr>",

//----------------------------------------------------------------------

"insert#scopes":#"<desc type='plugin'><p><short>
 Inserts a listing of all present variable scopes.</short>
</p></desc>

<attr name='scopes' value='full|plain'>
 <p>Sets how the output should be formatted.</p>

 <ex><insert scopes='plain'/></ex>
</attr>",

//----------------------------------------------------------------------

"gauge":#"<desc type='cont'><p><short>
 Measures how much CPU time it takes to run its contents through the
 RXML parser.</short> Returns the number of seconds it took to parse
 the contents.
</p></desc>

<attr name='variable' value='string'>
 <p>The result will be put into a variable. E.g. variable=\"var.gauge\" will
 put the result in a variable that can be reached with <ent>var.gauge</ent>.</p>
</attr>

<attr name='silent'>
 <p>Don't print anything.</p>
</attr>

<attr name='timeonly'>
 <p>Only print the time.</p>
</attr>

<attr name='resultonly'>
 <p>Only print the result of the parsing. Useful if you want to put the time in
 a database or such.</p>
</attr>",

//----------------------------------------------------------------------

"trace":#"<desc type='cont'><p><short>
 Executes the contained RXML code and makes a trace report about how
 the contents are parsed by the RXML parser.</short>
</p></desc>",

//----------------------------------------------------------------------

"emit#sources":({ #"<desc type='plugin'><p><short>
 Provides a list of all available emit sources.</short>
</p></desc>",
  ([ "&_.source;":#"<desc type='entity'><p>
  The name of the source.</p></desc>" ]) }),

//----------------------------------------------------------------------

"emit#fonts":({ #"<desc type='plugin'><p><short>
 Prints available fonts.</short> This plugin makes it easy to list all
 available fonts in ChiliMoon.
</p></desc>

<attr name='type' value='ttf|all'>
 <p>Which font types to list. ttf means all true type fonts, whereas all
 means all available fonts.</p>
</attr>",
		([
"&_.name;":#"<desc type='entity'><p>
 Returns a font identification name.</p>

<p>This example will print all available ttf fonts in gtext-style.</p>
<ex-box><emit source='fonts' type='ttf'>
  <gtext font='&_.name;'>&_.expose;</gtext><br />
</emit></ex-box>
</desc>",
"&_.copyright;":#"<desc type='entity'><p>
 Font copyright notice. Only available for true type fonts.
</p></desc>",
"&_.expose;":#"<desc type='entity'><p>
 The preferred list name. Only available for true type fonts.
</p></desc>",
"&_.family;":#"<desc type='entity'><p>
 The font family name. Only available for true type fonts.
</p></desc>",
"&_.full;":#"<desc type='entity'><p>
 The full name of the font. Only available for true type fonts.
</p></desc>",
"&_.path;":#"<desc type='entity'><p>
 The location of the font file.
</p></desc>",
"&_.postscript;":#"<desc type='entity'><p>
 The fonts postscript identification. Only available for true type fonts.
</p></desc>",
"&_.style;":#"<desc type='entity'><p>
 Font style type. Only available for true type fonts.
</p></desc>",
"&_.format;":#"<desc type='entity'><p>
 The format of the font file, e.g. ttf.
</p></desc>",
"&_.version;":#"<desc type='entity'><p>
 The version of the font. Only available for true type fonts.
</p></desc>",
"&_.trademark;":#"<desc type='entity'><p>
 Font trademark notice. Only available for true type fonts.
</p></desc>",
		])
	     }),

//----------------------------------------------------------------------

"if#true":#"<desc type='plugin'><p><short>
 This will always be true if the truth value is set to be
 true.</short> Equivalent with <xref href='then.tag' />.
 This is a <i>State</i> plugin.
</p></desc>

<attr name='true' required='required'><p>
 Show contents if truth value is false.</p>
</attr>",

//----------------------------------------------------------------------

"if#false":#"<desc type='plugin'><p><short>
 This will always be true if the truth value is set to be
 false.</short> Equivalent with <xref href='else.tag' />.
 This is a <i>State</i> plugin.</p>
</desc>

<attr name='false' required='required'><p>
 Show contents if truth value is true.</p>
</attr>",

//----------------------------------------------------------------------


    ]);
#endif
