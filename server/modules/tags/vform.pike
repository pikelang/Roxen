// This is a roxen module. Copyright © 2000, Roxen IS.
// By Martin Nilsson

#include <module.h>
inherit "module";

constant cvs_version="$Id: vform.pike,v 1.7 2000/09/05 15:06:47 per Exp $";
constant thread_safe=1;

constant module_type = MODULE_PARSER;
constant module_name = "Verified form";
constant module_doc  = "Creates a self verifying form.";

class TagVForm {
  inherit RXML.Tag;
  constant name = "vform";

  class TagVInput {
    inherit RXML.Tag;
    constant name = "vinput";
    mapping(string:RXML.Type) req_arg_types = ([ "name":RXML.t_text(RXML.PEnt) ]);

    constant ARGS=(< "type", "min", "max", "scope", "min", "max", "trim"
		     "regexp", "glob", "minlength", "maxlength", "case",
		     "mode", "fail-if-failed", "ignore-if-false",
		     "ignore-if-failed", "ignore-if-verified" >);

    class Frame {
      inherit RXML.Frame;
      string scope_name;
      mapping vars;

      object var;
      string warn;

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
	  if(args->case=="upper") var->add_upper();
	  if(args->case=="lower") var->add_lower();

	  // Shortcuts
	  if(args->equal) var->add_glob(args->equal); // Should use regexp
	  if(args->is=="empty") var->add_glob("");
	  break;
	}

	if(!id->variables["__clear"] && id->variables[args->name]) {
	  mixed new_value=id->variables[args->name];
	  if(args->trim) new_value=String.trim_whites(new_value);
	  [warn, new_value]=var->verify_set(var->transform_from_form(new_value));
	  var->set(new_value);
	}
	var->set_path(args->name);

	mapping new_args=([]);
	foreach(indices(args), string arg)
	  if(!ARGS[arg]) new_args[arg]=args[arg];

	vars=([ "input":var->render_form(id, new_args) ]);
	if(warn) vars->warning=warn;
	return 0;
      }

      array do_return(RequestID id) {
	int ok=!warn;
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
	else
	  verified_result(id);
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
	  result = var->render_form(id, args);
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
	  result = var->render_form(id, args) + content;
	}
      }
    }
  }

  class TagVerify {
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
							     TagVerify(),
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

      if(!sizeof(id->misc->vform_failed) &&
	 sizeof(id->misc->vform_verified) &&
	 args["hide-if-verified"]) {
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
  "vform":({ #"<desc cont>Creates a self verifying form.</desc>
<attr name=hide-if-verified>Hides the form if it is verified</attr>",

	     ([ "reload":"<desc tag>Reload the page without variable checking.</desc>",
		"clear":"<desc tag>Resets all the widgets.</desc>",
		"verify":"<desc cont></desc>",
		"vinput": ({ #"<desc cont>Create a self verifying input widget.</desc>
<attr name=fail-if-failed value=name>
  The verification of this variable will always fail if the verification of a named
  variable also failed.
</attr>
<attr name=ignore-if-false>
  Don't verify if the false flag i set.
</attr>
<attr name=ignore-if-failed value=name>
  Don't verify if the verification of a named variable failed.
</attr>
<attr name=ignore-if-verified value=name>
  Don't verify if the verification of a named variable succeeded.
</attr>
<attr name=trim>
  Trim the variable before verification.
</attr>
<attr name=minlength value=number>
  Verify that the variable has at least this many characters.
</attr>
<attr name=maxlength value=number>
  Verify that the variable has at most this many characters.
</attr>
<attr name=is value=mail|int|float|upper|lower|upper-alpha|lower-alpha|upper-alpha-num|lower-alpha-num>
  Verify that the variable is of a certain kind.
</attr>
<attr name=glob value=pattern>
  Verify that the variable match a certain glob pattern.
</attr>
<attr name=regexp value=pattern>
  Verify that the variable match a certain regexp pattern.
</attr>
<attr name=mode value=before|after|complex>
  Select how to treat the contents of the vinput container. Before puts the contents before the
  input tag, and after puts it after, in the event of failed verification. If complex, use one
  tag <tag>verified</tag> for what should be outputted in the event of successful verification
  tag <tag>failed</tag> for every other event.
</attr>
<attr name=min value=number>
  Check that the number is at least the given.
</attr>
<attr name=max value=number>
  Check that the number is at most the given.
</attr>
<attr name=filter value=string>
  Cehck that the variable only consists of the characters given in the filter string.
</attr>
", ([ "&_.input;":"<desc ent>The input tag, in complex mode</desc>",
      "verified":"<desc cont>The content will only be shown if the variable was verfied, in complex mode</desc>",
      "failed":"<desc cont>The content will only be shown if the variable failed to verify, in complex mode</desc>"
]) })
]) }) ]);
#endif
