// This is a roxen module. Copyright © 2000 - 2009, Roxen IS.
// By Martin Nilsson

#include <module.h>
inherit "module";

constant cvs_version = "$Id$";
constant thread_safe = 1;

constant module_type = MODULE_TAG;
constant module_name = "Tags: Verified form";
constant module_doc  = "Creates a self-verifying form.";

// maxlength is excluded so that it gets exported. value is included
// since not all widgets have a value attribute, and those who do add
// it themselves.
constant ARGS=(< "type", "min", "max", "scope", "trim",
		 "regexp", "glob", "minlength", "case", "date",
		 "mode", "fail-if-failed", "ignore-if-false", "ignore-if-gone",
		 "ignore-if-failed", "ignore-if-verified", "optional", "value",
		 "disable-domain-check", >);

// pass along some HTML5-specific attributes (<type>:<attribute>)
constant HTML5_ARGS = (< "number:min", "number:max" >);

constant HTML5_TYPES = (< "number", "email", "url", "tel", "date", "datetime",
			  "datetime-local", "search", "month", "week", "time",
			  "color", "range", >);

constant forbidden = ({"\\", ".", "[", "]", "^",
		       "$", "(", ")", "*", "+", "|"});
constant allowed = ({"\\\\", "\\.", "\\[", "\\]", "\\^",
		     "\\$", "\\(", "\\)", "\\*", "\\+", "\\|"});

Parser.HTML verified;
Parser.HTML failed;

void create() {
  verified = Parser.HTML()->
    add_containers( ([ "verified" : lambda(Parser.HTML p, mapping m, string c) {
				      return c; },
		       "failed" : "" ]) );

  failed = Parser.HTML()->
    add_containers( ([ "failed" : lambda(Parser.HTML p, mapping m, string c) {
				      return c; },
		       "verified" : "" ]) );
}

class VInputFrame {
  inherit RXML.Frame;
  string scope_name;
  mapping vars;

  object var;

  array do_enter(RequestID id) {
    scope_name=args->scope||"vinput";

#ifdef VFORM_COMPAT
    if(args->is) {
      switch(args->is) {
      case "int":
	args->type="int";
	break;
      case "float":
	args->type="float";
	break;
      case "mail":
	args->type="email";
	break;
      case "date":
	args->type="date";
	break;
      case "upper-alpha":
	args->regexp="^[A-Z]*$";
	break;
      case "lower-aplha":
	args->regexp="^[a-z]*$";
	break;
      case "upper-alpha-num":
	args->regexp="^[A-Z0-9]*$";
	break;
      case "lower-alpha-num":
	args->regexp="^[a-z0-9]*$";
	break;
      }
      m_delete(args, "is");
    }
    if(args->filter) {
      args->regexp="^["+args->filter+"]*$";
      m_delete(args, "filter");
    }
#endif

    int(0..1) no_html5 = 0;

    var = id->misc->vform_objects[args->name];

    switch(args->type) {
    case "number": // fall through
    case "int":
      if(!var) var=Variable.Int(args->value||"");
      // FIXME: Should check invalid integer formats in min and max.
      var->set_range(args->min ? (int)args->min : Variable.no_limit,
		     args->max ? (int)args->max : Variable.no_limit);
      break;
    case "float":
      if(!var) var=Variable.Float(args->value||"");
      // FIXME: Should check invalid float formats in min and max.
      var->set_range(args->min ? (float)args->min : Variable.no_limit,
		     args->max ? (float)args->max : Variable.no_limit);
      break;
    case "email":
      if(!var) var=Variable.Email(args->value||"");
      if(args["disable-domain-check"]) var->disable_domain_check();
      break;
    case "datetime":
    case "datetime-local":
      if (!args["date"]) args["date"] = "%Y-%M-%DT%h:%m";
      // fall through
    case "date":
      if(!var) var=Variable.Date(args->value||"");
      if(args["date"]) {
	// Disable HTML5 if date format is incompatible
	if (args["date"] != "%Y-%M-%D" && args["date"] != "%Y-%M-%DT%h:%m") no_html5 = 1;

	var->set_date_type( args->date );
      }
      break;
    case "image":
      if(!var) var=Variable.Image( args->value||"", 0, 0, 0 );
      break;
//   case "upload":
//     if(!var) var=Variable.Upload( args->value||"", 0, 0, 0 );
//     break;
    case "password":
      if(!var) var=Variable.VerifiedPassword(args->value||"");
    case "text":
      if(!var) var=Variable.VerifiedText(args->value||"");
    case "color": // fall through
    case "tel":   // ...
    case "week":
    case "month":
    case "time":
    case "search":
    case "url":
    case "range":
    case "string":
      if(!var) var=Variable.VerifiedString(args->value||"");
      var->clear_verifications();
      if(args->regexp) var->add_regexp(args->regexp);
      if(args->glob) var->add_glob(args->glob);
      if(args->minlength) var->add_minlength((int)args->minlength);
      if(args->maxlength) var->add_maxlength((int)args->maxlength);

      if(args->case=="upper")
	var->add_upper();
      else if(args->case=="lower")
	var->add_lower();

      // Shortcuts
      if(args->equal)
	var->add_regexp( "^" + replace(args->equal, forbidden, allowed) + "$" );
      if(args->is=="empty") var->add_glob("");
      break;
    case 0:
      RXML.parse_error("There is no type argument.\n");
    default:
      RXML.parse_error("There is no type %s.\n", args->type);
    }

    var->set_path( args->name );

    if ( !id->real_variables["__clear"] ) {
      if (args->optional && id->real_variables[args->name] &&
          id->real_variables[args->name][0] == "") {
        var->set_warning(0);
        var->low_set ("");
      }
      else if(id->real_variables[args->name] &&
              !(args->optional && id->real_variables[args->name][0]=="") ) 
        {
          if(args->trim) 
            id->real_variables[args->name][0]
              = String.trim_all_whites(id->real_variables[args->name][0]);
          var->set_from_form( id, 1 );
        }
    }

    string type = !no_html5 && HTML5_TYPES[args->type] && args->type;

    mapping new_args=([]);
    foreach(indices(args), string arg)
      if(!ARGS[arg] || (type && HTML5_ARGS[type + ":" + arg])) new_args[arg]=args[arg];

    if (type) new_args->type = type;

    vars=([ "input":var->render_form(id, new_args) ]);
    if(var->get_warnings()) vars->warning=var->get_warnings();
    id->misc->vform_objects[args->name] = var;
    return 0;
  }

  array do_return(RequestID id) {
    int ok=!var->get_warnings();
    int show_err=1;
    if((args["fail-if-failed"] && id->misc->vform_failed[args["fail-if-failed"]]) ||
       (args["ignore-if-gone"] && !id->real_variables[args->name]))
      ok=1;

    if((!id->real_variables[args->name] && !args["ignore-if-gone"]) ||
       (args["ignore-if-false"] && !id->misc->vform_ok) ||
       id->real_variables["__reload"] ||
       id->real_variables["__clear"] ||
       (args["ignore-if-failed"] && id->misc->vform_failed[args["ignore-if-failed"]]) ||
       (args["ignore-if-verified"] && id->misc->vform_verified[args["ignore-if-verified"]]) ) {
      ok=0;
      show_err=0;
    }

    if(ok) {
      id->misc->vform_verified[args->name]=1;
      verified_result(id);
      return 0;
    }

    id->misc->vform_failed[args->name]=1;
    if(show_err)
      failed_result(id);
    else {
      m_delete(args, "warning");
      verified_result(id);
    }
    id->misc->vform_ok = 0;
    return 0;
  }

  void verified_result(RequestID id )
  // Create a tag result without error response.
  {
    switch(args->mode||"after") {
    case "complex":
      result = verified->clone()->finish(content)->read();
      break;
    case "before":
    case "after":
    default:
      result = RXML.get_var("input");
    }
  }

  void failed_result(RequestID id)
  // Creates a tag result with widget and error response.
  {
    switch(args->mode||"after") {
    case "complex":
      result = failed->clone()->finish(content)->read();
      break;
    case "before":
      result = content + var->render_form(id, args);
      break;
    case "after":
    default:
      result = RXML.get_var("input") + content;
    }
  }
}

class VInput {
  inherit RXML.Tag;
  constant name = "vinput";
  mapping(string:RXML.Type) req_arg_types = ([ "name":RXML.t_text(RXML.PEnt) ]);

  class Frame {
    inherit VInputFrame;
  }
}

class TagWizzVInput {
  inherit RXML.Tag;
  constant name="wizz";
  constant plugin_name="vinput";

  RXML.Tag get_tag() {
    return TagVInput();
  }

  class TagVInput {
    inherit VInput;
    class Frame {
      inherit VInputFrame;

      array do_enter(RequestID id) {
	id->misc->vform_ok = id->misc->wizard->verify?id->misc->wizard->verify_ok:1;
	if(!id->misc->vform_verified) {
	  id->misc->vform_verified=(<>);
	  id->misc->vform_failed=(<>);
          id->misc->vform_objects=([]);
	  id->misc->vform_xml = !args->noxml;
	}

	::do_enter(id);
	return 0;
      }

      array do_return(RequestID id) {
	::do_return(id);
	id->misc->wizard->verify_ok = id->misc->vform_ok;
	return 0;
      }
    }
  }
}

class TagVForm {
  inherit RXML.Tag;
  constant name = "vform";

  // Should disable caching since this module make heavy use of
  // id->misc, which isn't intercepted by the cache system. But then
  // again, disabling the cache can be just as bad, so we let it be a
  // known misfeature that some combinations of vform and the <cache>
  // tag fails (just as it always has been, btw).
  //constant flags = RXML.FLAG_DONT_CACHE_RESULT;

  class TagVInput {
    inherit VInput;
  }

  class TagVSelect {
    inherit RXML.Tag;
    constant name = "vselect";
    mapping(string:RXML.Type) req_arg_types = ([ "name":RXML.t_text(RXML.PEnt) ]);

    class Frame {
      inherit RXML.Frame;

      array do_return(RequestID id) {
	int ok=1;
	if(args->not && id->real_variables[args->name] &&
	   id->real_variables[args->name][0] == args->not)
	  ok = 0;
	
	m_delete(args, "not");
	if(ok) {
	  id->misc->vform_verified[args->name]=1;
	  result = RXML.t_xml->format_tag("select", args, content);
	}
	else {
	  id->misc->vform_failed[args->name]=1;
	  id->misc->vform_ok = 0;

	  //Create error message
	  string mode = args->mode || "after";
	  m_delete(args, "mode");
	  switch(mode) {
	  case "complex": // not working...
	    result =
	      parse_html(content, ([ ]),
			 ([ "failed"   : lambda(string t, mapping m,
						string c) {
					   return c;
					 },
			    "verified" : "" ]) );
	    break;
	  case "before":
	    string error =
	      parse_html(content, ([ ]),
			 ([ "error-message" : lambda(string t, mapping m,
						     string c) {
						return c;
					      },
			    "option"        : "" ]) );
	    result = error + RXML.t_xml->format_tag("select", args, content);
	  case "after":
	  default:
	    error =
	      parse_html(content, ([]),
			 ([ "error-message" : lambda(string t, mapping m,
						     string c) {
						return c;
					      },
			    "option"        : "" ]) );
	    result = RXML.t_xml->format_tag("select", args, content) + error;
	  }
	}
	return 0;
      }
    }
  }

  class TagReload {
    inherit RXML.Tag;
    constant name = "reload";
    constant flags = RXML.FLAG_EMPTY_ELEMENT;

    class Frame {
      inherit RXML.Frame;

      array do_return(RequestID id) {
	if(!args->type) args->type = "submit";
	args->name="__reload";
	
	result = Roxen.make_tag("input", args, id->misc->vform_xml);
	return 0;
      }
    }
  }

  class TagVerifyFail {
    inherit RXML.Tag;
    constant name = "verify-fail";
    constant flags = RXML.FLAG_EMPTY_ELEMENT;
    
    class Frame {
      inherit RXML.Frame;
      
      array do_return(RequestID id) {
	id->misc->vform_ok = 0;
	if(args->name) {
	  id->misc->vform_failed[args->name]=1;
	  id->misc->vform_verified[args->name]=0;
	}
	return 0;
      }
    }
  }

  class TagVerifyOk {
    inherit RXML.Tag;
    constant name = "verify-ok";
    constant flags = RXML.FLAG_EMPTY_ELEMENT;
    
    class Frame {
      inherit RXML.Frame;
      
      array do_return(RequestID id) {
	
	if(args->name) {
	  id->misc->vform_failed[args->name] = 0;
	  id->misc->vform_verified[args->name] = 1;
	  if( !sizeof(id->misc->vform_failed) )
	    id->misc->vform_ok = 1;
	}
	else
	  id->misc->vform_ok = 1;
	
	return 0;
      }
    }
  }

  class TagClear {
    inherit RXML.Tag;
    constant name = "clear";
    constant flags = RXML.FLAG_EMPTY_ELEMENT;

    class Frame {
      inherit RXML.Frame;

      array do_return(RequestID id) {
	if(!args->type) args->type = "submit";
	args->name="__clear";

	result = Roxen.make_tag("input", args, id->misc->vform_xml);
	return 0;
      }
    }
  }

  class TagIfVFailed {
    inherit RXML.Tag;
    constant name = "if";
    constant plugin_name = "vform-failed";

    int eval(string ind, RequestID id) {
      if(!ind || !sizeof(ind)) return !id->misc->vform_ok;
      if(!id->real_variables[ind]) return 0;
      return id->misc->vform_failed[ind];
    }
  }

  class TagIfVVerified {
    inherit RXML.Tag;
    constant name = "if";
    constant plugin_name = "vform-verified";

    int eval(string ind, RequestID id) {
      if(!ind || !sizeof(ind)) return id->misc->vform_ok;
      return id->misc->vform_verified[ind];
    }
  }

  // This tag set can probably be shared, but I don't know for sure. /mast
  RXML.TagSet internal = RXML.TagSet (this_module(), "internal",
				      ({ TagVInput(),
					 TagReload(),
					 TagClear(),
					 TagVSelect(),
					 TagIfVFailed(),
					 TagIfVVerified(),
					 TagVerifyFail(),
					 TagVerifyOk(),
				      }) );

  class Frame {
    inherit RXML.Frame;
    RXML.TagSet additional_tags = internal;
    private StateHandler.Page_state state;

    array do_enter(RequestID id) {
      id->misc->vform_ok = 1;
      id->misc->vform_verified=(<>);
      id->misc->vform_failed=(<>);
      id->misc->vform_xml = !args->noxml;

      state = StateHandler.Page_state(id);
      state->register_consumer("vform");
      if(id->real_variables->__state) {
	state->use_session( StateHandler.decode_session_id(id->real_variables->__state[0]) );
	state->decode(id->real_variables->__state[0]);
      }
      else
	state->use_session();
      id->misc->vform_objects = state->get() || ([]);

      return 0;
    }

    array do_return(RequestID id) {
      id->misc->defines[" _ok"] = id->misc->vform_ok;
      m_delete(id->misc, "vform_ok");

      if(args["hide-if-verified"] &&
	 !sizeof(id->misc->vform_failed) &&
	 sizeof(id->misc->vform_verified) &&
	 id->misc->defines[" _ok"] ) {
	m_delete(id->misc, "vform_verified");
	m_delete(id->misc, "vform_failed");
        m_delete(id->misc, "vform_xml");
	return 0;
      }

      state->alter(id->misc->vform_objects);
      content = "<input name=\"__state\" type=\"hidden\" value=\"" + 
	state->encode() + "\" />\n" + content;

      m_delete(id->misc, "vform_objects");
      m_delete(id->misc, "vform_verified");
      m_delete(id->misc, "vform_failed");
      m_delete(id->misc, "vform_xml");
      m_delete(args, "noxml");
      m_delete(args, "hide-if-verified");

      if(!args->method) args->method="post";
      if(!args->action) args->action=get_var("self", "page");
      result = RXML.t_xml->format_tag("form", args, content);
      return 0;
    }
  }
}

TAGDOCUMENTATION;
#ifdef manual
constant tagdoc=([
"vform":({ #"<desc type='cont'><p><short>
 Creates a self-verifying form.</short> You can use all standard
 HTML input widgets in this container as well.</p>

<p>Other tags that is related and useful are <tag>default</tag>
and <tag>roxen-automatic-charset-variable</tag>.</p>

<ex-box>
<vform>
  <vinput name='mail' type='email'>&_.warning;</vinput>
  <input type='hidden' name='user' value='&form.userid;' />
  <input type='submit' />
</vform>
<then><redirect to='other_page.html' /></then>
<else>No, this form is still not valid</else>
</ex-box>
</desc>

<attr name='hide-if-verified'>
 <p>Hides the form if it is verified</p>
</attr>",

	     ([
"reload":#"<desc tag='tag'><p><short>
 Reload the page without variable checking.</short>
</p></desc>

<attr name='value' value='string'><p>
 The text on the button.</p>
</attr>",

"clear":#"<desc tag='tag'><p><short>
 Resets all the widgets to their initial values.</short>
</p></desc>

<attr name='value' value='string'><p>
 The text in the button.</p>
</attr>",

"verify-fail":#"<desc tag='tag'><p><short>
 If put in a vform tag, the vform will always fail.</short>This is
 useful e.g. if you put the verify-fail tag in an if tag.
</p></desc>",

"verify-ok":#"<desc tag='tag'><p><short>
 If put in a vform tag, the vform will always be verified.</short>This
 tag is probably only useful when the name-attribute inside the tag is
 set. If it is it will force that specific vform-variable as verified
 ok even if the &lt;vinput&gt;-tag that tested the variable failed.
</p></desc>

<attr name='name' value='string'><p>
 The name of the vform variable to force as verified ok.</p>
</attr>",

"if#vform-failed":#"<desc type='plugin'><p>
 If used with empty argument this will be true if the complete form is
 failed, otherwise only if the named field failed.
</p></desc>",

"if#vform-verified":#"<desc type='plugin'><p>
 If used with empty arguemnt this will be true if the complete form so
 far is verified, otherwise only if the named field was successfully
 verified.
</p></desc>",

"vinput":({ #"<desc type='cont'><p><short>
 Creates a self-verifying input widget.</short>
</p></desc>

<attr name='fail-if-failed' value='name'><p>
  The verification of this variable will always fail if the
  verification of a named variable also failed.</p>
</attr>

<attr name='ignore-if-false'><p>
  Don't verify if the false flag i set.</p>
</attr>

<attr name='ignore-if-failed' value='name'><p>
  Don't verify if the verification of a named variable failed.</p>
</attr>

<attr name='ignore-if-gone'><p>
  Don't verify if the variable is missing from the form scope.
  This is useful if the widget might be disabled. Be careful not to
  set this flag on all input fields since this would cause the form
  to verify upon first request to the page.</p>
</attr>

<attr name='ignore-if-verified' value='name'><p>
  Don't verify if the verification of a named variable succeeded.</p>
</attr>

<attr name='name' value='string' required='required'><p>
  The name of the variable that should be set.</p>
</attr>

<attr name='value' value='anything'><p>
  The default value of this input widget.</p>
</attr>

<attr name='scope' value='name' default='vinput'><p>
  The name of the scope that is created in this tag.</p>
</attr>

<attr name='trim'><p>
  Trim the variable before verification.</p>
</attr>

<attr name='type' value='int|float|email|date|text|string|password' required='required'><p>
 Set the type of the data that should be input, and hence what
 widget should be used and how the input should be verified.</p>
</attr>

<attr name='date' value='string'><p>
 If not specified toghether with the type=\"date\" attribute the date will be
 verified as an ISO-date, i.e Y-M-D. If another date format is
 desired it should be specified with the date-attribute.
 </p>

 <p>
 Examples:<br />
 date='%Y-%M-%D %h:%m' will verify a date formatted as '2040-11-08 2:46',<br />
 date='%Y w%W %e %h:%m %p %z' will verify '1913 w4 monday 2:14 pm CET'
 </p>

 <p>These are the format characters:</p>

 <xtable>
  <row><c><p>%Y</p></c><c><p>absolute year</p></c></row>
  <row><c><p>%y</p></c><c><p>dwim year (70-99 is 1970-1999, 0-69 is 2000-2069)</p></c></row>
  <row><c><p>%M</p></c><c><p>month (number, name or short name) (needs %y)</p></c></row>
  <row><c><p>%W</p></c><c><p>week (needs %y)</p></c></row>
  <row><c><p>%D</p></c><c><p>date (needs %y, %m)</p></c></row>
  <row><c><p>%d</p></c><c><p>short date (20000304, 000304)</p></c></row>
  <row><c><p>%a</p></c><c><p>day (needs %y)</p></c></row>
  <row><c><p>%e</p></c><c><p>weekday (needs %y, %w)</p></c></row>
  <row><c><p>%h</p></c><c><p>hour (needs %d, %D or %W)</p></c></row>
  <row><c><p>%m</p></c><c><p>minute (needs %h)</p></c></row>
  <row><c><p>%s</p></c><c><p>second (needs %m)</p></c></row>
  <row><c><p>%f</p></c><c><p>fraction of a second (needs %s)</p></c></row>
  <row><c><p>%t</p></c><c><p>short time (205314, 2053)</p></c></row>
  <row><c><p>%z</p></c><c><p>zone</p></c></row>
  <row><c><p>%p</p></c><c><p>'am' or 'pm'</p></c></row>
  <row><c><p>%n</p></c><c><p>empty string (to be put at the end of formats).
       You can also use '%*[....]' to skip some characters.</p></c></row>
 </xtable>

</attr>
	    
<attr name='minlength' value='number'><p>
 Verify that the variable has at least this many characters. Only
 available when using the type password, string or text.</p>
</attr>

<attr name='maxlength' value='number'><p>
 Verify that the variable has at most this many characters. Only
 available when using the type password, string or text.</p>
</attr>

<attr name='is' value='empty'><p>
 Verify that the variable is empty. Pretty useless... Only available
 when using the type password, string or text.</p>
</attr>

<attr name='glob' value='pattern'><p>
 Verify that the variable match a certain glob pattern. Only available
 when using the type password, string or text.</p>
</attr>

<attr name='regexp' value='pattern'><p>
 Verify that the variable match a certain regexp pattern. Only
 available when using the type password, string or text.</p>
</attr>

<attr name='case' value='upper|lower'><p>
 Verify that the variable is all uppercased (or all lowercased). Only
 available when using the type password, string or text.</p>
</attr>

<attr name='equal' value='string'><p>
 Verify that the variable is equal to a given string. Pretty
 useless... Only available when using the type password, string or text.</p>
</attr>

<attr name='disable-domain-check'><p>
 Only available when using the email type. When set the email domain
 will not be checked against a DNS to verify that it does exists.</p>
</attr>

<attr name='mode' value='before|after|complex'><p>
 Select how to treat the contents of the vinput container. 
 <i>Before</i> puts the contents before the input tag, and <i>after</i> 
 puts it after, in the event of failed verification. If complex, use one tag
 <tag>verified</tag> for what should be outputted in the event of
 successful verification tag <tag>failed</tag> for every other event.</p>

<ex-box><table>
<tr><td>upper</td>
<vinput name='a' case='upper' mode='complex'>
<verified><td bgcolor='green'>&_.input:none;</td></verified>
<failed><td bgcolor='red'>&_.input:none;</td></failed>
</vinput></tr>
<tr><td><input type='submit' /></td></tr>
</table></ex-box>
</attr>

<attr name='min' value='number'><p>
 Check that the number is at least the given. Only available when
 using the type int or float.</p>
</attr>

<attr name='max' value='number'><p>
 Check that the number is not greater than the given. Only available when using
 the type int or float.</p>
</attr>

<attr name='optional'><p>
 Indicates that the variable should only be tested if it does contain
 something.</p>
</attr>",
	    ([
"&_.input;":#"<desc type='entity'><p>
 The input tag, in complex mode.
</p></desc>",

"&_.warning;":#"<desc type='entity'><p>
 May contain a explaination of why the test failed.
</p></desc>",

"verified":#"<desc type='cont'><p>
 The content will only be shown if the variable was verfied, in
 complex mode.
</p></desc>",

"failed":#"<desc type='cont'><p>
 The content will only be shown if the variable failed to verify, in
 complex mode.
</p></desc>"

//      Should this subtag exist?
//	"vselect":"<desc type='cont'>Mail stewa@roxen.com for a description</desc>",


	    ])
	 })
]) }) ]);
#endif
