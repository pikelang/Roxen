// This is a roxen module. Copyright © 2000, Roxen IS.
// By Martin Nilsson

#include <module.h>
inherit "module";

constant cvs_version="$Id: vform.pike,v 1.19 2003/09/25 11:00:33 anders Exp $";
constant thread_safe=1;

constant module_type = MODULE_TAG;
constant module_name = "Verified form";
constant module_doc  = "Creates a self verifying form.";

// maxlength is excluded so that it gets exported.
constant ARGS=(< "type", "min", "max", "scope", "min", "max", "trim",
		 "regexp", "glob", "minlength", "case",
		 "mode", "fail-if-failed", "ignore-if-false",
		 "ignore-if-failed", "ignore-if-verified", "optional" >);

constant forbidden = ({"\\", ".", "[", "]", "^",
		       "$", "(", ")", "*", "+", "|"});
constant allowed = ({"\\\\", "\\.", "\\[", "\\]", "\\^",
		     "\\$", "\\(", "\\)", "\\*", "\\+", "\\|"});

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

    switch(args->type) {
    case "int":
      var=Variable.Int(args->value||"");
      var->set_range((int)args->min, (int)args->max);
      break;
    case "float":
      var=Variable.Float(args->value||"");
      var->set_range((float)args->min, (float)args->max);
      break;
    case "email":
      var=Variable.Email(args->value||"");
      if(args["disable-domain-check"]) var->disable_domain_check();
      break;
    case "date":
      var=Variable.Date(args->value||"");
      break;
    case "text":
      var=Variable.VerifiedText(args->value||"");
    case "string":
    default:
      if(!var) var=Variable.VerifiedString(args->value||"");
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
    }

    if(!id->variables["__clear"] && id->variables[args->name] &&
       !(args->optional && id->variables[args->name]=="") ) {
      mixed new_value=id->variables[args->name];
      if(args->trim) new_value=String.trim_whites(new_value);
      var->set(var->transform_from_form(new_value));
    }
    var->set_path(args->name);

    mapping new_args=([]);
    foreach(indices(args), string arg)
      if(!ARGS[arg]) new_args[arg]=args[arg];

    vars=([ "input":var->render_form(id, new_args) ]);
    if(var->get_warnings()) vars->warning=var->get_warnings();
    return 0;
  }

  array do_return(RequestID id) {
    int ok=!var->get_warnings();
    int show_err=1;
    if(args["fail-if-failed"] && id->misc->vform_failed[args["fail-if-failed"]])
      ok=1;

    if(!id->variables[args->name] ||
       (args["ignore-if-false"] && !id->misc->vform_ok) ||
       id->variables["__reload"] ||
       id->variables["__clear"] ||
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
      result = parse_html(content, ([]),
			  ([ "verified":lambda(string t, mapping m, string c) { return c; },
			     "failed":"" ]) );
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
      result = parse_html(content, ([]),
			  ([ "failed":lambda(string t, mapping m, string c) { return c; },
			     "verified":"" ]) );
      break;
    case "before":
      result = content + var->render_form(id, args);
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

/*
class TagWizzVInput {
  inherit VInput;
  constant name="wizz";
  constant plugin_name="vinput";

  class Frame {
    inherit VInputFrame;
  }
}
*/

class TagVForm {
  inherit RXML.Tag;
  constant name = "vform";

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
	if(args->not && id->variables[args->name]==args->not) ok=0;
	
	m_delete(args, "not");
	if(ok) {
	  id->misc->vform_verified[args->name]=1;
	  result = RXML.t_xml->format_tag("select", args, content);
	}
	else {
	  id->misc->vform_failed[args->name]=1;
	  id->misc->vform_ok = 0;

	  //Create error message
	  switch(args->mode||"after") {
	  case "complex": // not working...
	    result = parse_html(content, ([]),
				([ "failed":lambda(string t, mapping m, string c) { return c; },
				   "verified":"" ]) );
	    break;
	  case "before":
	    string error = parse_html(content, ([]),
				      ([ "error-message":lambda(string t, mapping m, string c) { return c; },
					 "option":"" ]) );
	    result = error + RXML.t_xml->format_tag("select", args, content);
	  case "after":
	  default:
	    error = parse_html(content, ([]),
                               ([ "error-message":lambda(string t, mapping m, string c) { return c; },
                                  "option":"" ]) );
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

  RXML.TagSet internal = RXML.TagSet("TagVForm.internal", ({ TagVInput(),
							     TagReload(),
							     TagClear(),
							     TagVSelect(),
							     TagIfVFailed(),
							     TagIfVVerified(),
							     TagVerifyFail(),
  }) );

  class Frame {
    inherit RXML.Frame;
    RXML.TagSet additional_tags = internal;

    array do_enter(RequestID id) {
      id->misc->vform_ok = 1;
      id->misc->vform_verified=(<>);
      id->misc->vform_failed=(<>);
      id->misc->vform_xml = !args->noxml;
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
	return 0;
      }

      m_delete(id->misc, "vform_verified");
      m_delete(id->misc, "vform_failed");
      result = RXML.t_xml->format_tag("form", args, content);
      return 0;
    }
  }
}

TAGDOCUMENTATION;
#ifdef manual
constant tagdoc=([
  "vform":({ #"<desc cont='cont'><p><short>
 Creates a self verifying form.</short> You can use all standard
 HTML-input widgets in this container as well.</p>

<ex type='box'>
<vform>
  <vinput name='mail' type='email'>&_.warning;</vinput>
  <input type='hidden' name='user' value='&form.userid;' />
  <input type='submit' />
</vform>
<then><redirect to='other_page.html' /></then>
<else>No, this form is still not valid</else>
</ex>
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

// It's a tagdoc bug that these, locally defined if-plugins does not show up
// in the online manual.

"if#vform-failed":#"<desc plugin='plugin'><p>
 If used with empty argument this will be true if the complete form is
 failed, otherwise only if the named field failed.
</p></desc>",

"if#vform-verified":#"<desc plugin='plugin'><p>
 If used with empty arguemnt this will be true if the complete form so
 far is verified, otherwise only if the named field was successfully
 verified.
</p></desc>",

"vinput":({ #"<desc cont='cont'><p><short>
 Creates a self verifying input widget.</short>
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

<attr name='type' value='int|float|email|date|text|string' required='required'><p>
 Set the type of the data that should be input, and hence what
 widget should be used and how the input should be verified.</p>
</attr>

<attr name='minlength' value='number'><p>
 Verify that the variable has at least this many characters. Only
 available when using the type string or text.</p>
</attr>

<attr name='maxlength' value='number'><p>
 Verify that the variable has at most this many characters. Only
 available when using the type string or text.</p>
</attr>

<attr name='is' value='empty'><p>
 Verify that the variable is empty. Pretty useless... Only available
 when using the type string or text.</p>
</attr>

<attr name='glob' value='pattern'><p>
 Verify that the variable match a certain glob pattern. Only available
 when using the type string or text.</p>
</attr>

<attr name='regexp' value='pattern'><p>
 Verify that the variable match a certain regexp pattern. Only
 available when using the type string or text.</p>
</attr>

<attr name='case' value='upper|lower'><p>
 Verify that the variable is all uppercased (or all lowercased). Only
 available when using the type string or text.</p>
</attr>

<attr name='equal' value='string'><p>
 Verify that the variable is equal to a given string. Pretty
 useless... Only available when using the type string or text.</p>
</attr>

<attr name='disable-domain-check'><p>
 Only available when using the email type. When set the email domain
 will not be checked against a DNS to verify that it does exists.</p>
</attr>

<attr name='mode' value='before|after|complex'><p>
 Select how to treat the contents of the vinput container. Before puts
 the contents before the input tag, and after puts it after, in the
 event of failed verification. If complex, use one tag
 <tag>verified</tag> for what should be outputted in the event of
 successful verification tag <tag>failed</tag> for every other event.</p>

<ex type='box'>
<table>
<tr><td>upper</td><vinput name='a' case='upper' mode='complex'>
<verified><td bgcolor=green></verified>
<failed><td bgcolor=red></failed>&_.input:none;</td>
</vinput></tr>
<tr><td><input type='submit' /></td></tr>
</table>
</ex>
</attr>

<attr name='min' value='number'><p>
 Check that the number is at least the given. Only available when
 using the type int or float.</p>
</attr>

<attr name='max' value='number'><p>
 Check that the number is at most the given. Only available when using
 the type int or float.</p>
</attr>

<attr name='optional'><p>
 Indicates that the variable should only be tested if it does contain
 something.</p>
</attr>",
	    ([
"&_.input;":#"<desc ent='ent'><p>
 The input tag, in complex mode.
</p></desc>",

"&_.warning;":#"<desc ent='ent'><p>
 May contain a explaination of why the test failed.
</p></desc>",

"verified":#"<desc cont='cont'><p>
 The content will only be shown if the variable was verfied, in
 complex mode.
</p></desc>",

"failed":#"<desc cont='cont'><p>
 The content will only be shown if the variable failed to verify, in
 complex mode.
</p></desc>"
	    ])
	 }),

]) }) ]);
#endif
