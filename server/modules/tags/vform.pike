// This is a roxen module. Copyright © 2000, Roxen IS.
// By Martin Nilsson

#include <module.h>
inherit "module";

constant cvs_version="$Id: vform.pike,v 1.2 2000/07/17 12:22:53 nilsson Exp $";
constant thread_safe=1;

constant module_type = MODULE_PARSER;
constant module_name = "Verified form";
constant module_doc  = "Creates a self verifying form.";

constant num="0123456789";
constant low_alpha="abcdefghijklmnopqrstuvwxyz";
constant hi_alpha ="ABCDEFGHIJKLMNOPQRSTUVWXYZ";
constant hi_int   ="ÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏĞÑÒÓÔÕÖØÙÚÛÜİŞ";
constant low_int  ="àáâãäåæçèéêëìíîïğñòóôõöøùúûüışÿß";
constant interp   ="!\"#$%&'()*+,-./:;<=>?@[\]^_`{|}~";

class TagVForm {
  inherit RXML.Tag;
  constant name = "vform";

  class TagVInput {
    inherit RXML.Tag;
    constant name = "vinput";
    mapping(string:RXML.Type) req_arg_types = ([ "name":RXML.t_text(RXML.PEnt) ]);

    constant ARGS=({ "minlength", "maxlength", "trim", "is", "glob",
		     "ignore-if-false", "ignore-if-failed", "ignore-if-verified",
		     "filter", "min", "max", "date" });

    int filter(string what, string with) {
      multiset chars=(multiset)(with/"");
      foreach(what/"", string char)
	if(!chars[char]) return 0;
      return 1;
    }

    class Frame {
      inherit RXML.Frame;
      string scope_name;
      mapping vars;

      class EntityForm {
	inherit RXML.Value;
	string rxml_const_eval(RXML.Context c) {
	  mapping new_args=args+([]);
	  foreach(ARGS, string arg)
	    m_delete(new_args, arg);
	  new_args->value=c->id->variables[args->name]||args->value||"";
	  if(c->id->variables["__clear"]) new_args->value=args->value||"";
	  return Roxen.make_tag("input", new_args);
	}
      }

      array do_enter(RequestID id) {
	scope_name=args->scope||"vinput";
	vars=([ "input":EntityForm() ]);
	return 0;
      }

      array do_return(RequestID id) {
	int ok = 1;
	string var = id->variables[args->name];
	args->value=var||args->value||"";
	
	if(args["fail-if-failed"] && id->misc->vform_failed[args["fail-if-failed"]]) {
	  make_result(1, 0, id);
	  return 0;
	}
	
	if(!var ||
	   (args["ignore-if-false"] && !id->misc->vform_ok) ||
	   id->variables["__reload"] ||
	   id->variables["__clear"] ||
	   (args["ignore-if-failed"] && id->misc->vform_failed[args["ignore-if-failed"]]) ||
	   (args["ignore-if-verified"] && id->misc->vform_verified[args["ignore-if-verified"]]) ) {
	  if(id->variables["__clear"]) args->value=args->value||"";
	  make_result(0, 0, id);
	  return 0;
	}
	
	if(args->trim)
	  id->variables[args->name] = var = args->value = String.trim_whites(var);
	
	if(args->minlength &&
	   sizeof(var)<(int)args->minlength)
	  ok=0;
	
	if(args->maxlength &&
	   sizeof(var)>(int)args->maxlength)
	  ok=0;
	
	
	if(args->is) {
	  switch(args->is) {
	  case "mail":
	    string a,b,c;
	    int temp=(sscanf(lower_case(var), "%s@%s.%s", a,b,c)==3);
	    ok &= temp && filter(a+b+c, low_alpha+num+"_-.");
	    break;
	  case "int":
	    ok &= filter(var, num);
	    break;
	  case "float":
	    ok &= filter(var, num+".") && sizeof(var/".")==2;
	    break;
	  case "upper-alpha":
	    ok &= filter(var, hi_alpha);
	    break;
	  case "lower-alpha":
	    ok &= filter(var, low_alpha);
	    break;
     	  case "upper-alpha-num":
	    ok &= filter(var, hi_alpha+num);
	    break;
	  case "lower-alpha-num":
	    ok &= filter(var, low_alpha+num);
	    break;
	  case "lower":
	    ok &= filter(var, low_alpha+low_int+num+interp);
	    break;
	  case "upper":
	    ok &= filter(var, hi_alpha+hi_int+num+interp);
	    break;
	  case "date":
	    int y,m,d;
	    if( sscanf(var,"%4d-%2d-%2d",y,m,d)!=3 &&
		sscanf(var,"%4d%2d%2d",y,m,d)!=3 )
	      ok = 0;
	    else {
	      if( sprintf("%4d-%02d-%02d", y, m, d) != Calendar.ISO.Year(y)->
		  month(m)->day(d)->iso_name() )
		ok = 0;
	    }
	    break;

	  default:
	    ok=0;
	    break;
	  }
	}

	if(args->filter)
	  ok &= filter(var, args->filter);
	
	if(args->min)
	  ok &= (float)var>=(float)args->min;
	
	if(args->max)
	  ok &= (float)var<=(float)args->max;
	
	if(args->glob)
	  ok &= glob(args->glob, var);

	if(args->regexp)
	  ok &= Regexp(args->regexp)->match(var);

	if(args->equal)
	  ok &= (var == id->variables[args->equal]);

	if(args->empty) {
	  if(var == "")
	    ok = 1;
	}

	make_result(ok, 1, id);
	return 0;
      }

      void make_result(int ok, int show_err, RequestID id) {
	foreach(ARGS, string arg)
	  m_delete(args, arg);
	
	if(ok) {
	  id->misc->vform_verified[args->name]=1;
	  verified_result();
	}
	else {
	  id->misc->vform_failed[args->name]=1;
	  if(show_err)
	    failed_result();
	  else
	    verified_result();
	  id->misc->vform_ok = 0;
	}
	return;
      }

      void verified_result()
	// Create a tag result withut error response.
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
	  result = Roxen.make_tag("input", args);
	}
      }

      void failed_result()
	// Creates a tag result with widget and error response.
      {
	switch(args->mode||"after") {
	case "complex":
	  result = parse_html(content, ([]),
			      ([ "failed":lambda(string t, mapping m, string c) { return c; },
				 "verified":"" ]) );
	  break;
	case "before":
	  result = content + Roxen.make_tag("input", args);
	case "after":
	default:
	  result = Roxen.make_tag("input", args) + content;
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
	  result = Roxen.make_container("select", args, content);
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
	    result = error + Roxen.make_container("select", args, content);
	  case "after":
	  default:
	    string error = parse_html(content, ([]),
				      ([ "error-message":lambda(string t, mapping m, string c) { return c; },
					 "option":"" ]) );
	    result = Roxen.make_container("select", args, content) + error;
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

      array do_return() {
	if(!args->type) args->type = "submit";
	args->name="__reload";
	args["/"]="/";
	
	result = Roxen.make_tag("input", args);
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

      array do_return() {
	if(!args->type) args->type = "submit";
	args->name="__clear";
	args["/"]="/";

	result = Roxen.make_tag("input", args);
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
      result = Roxen.make_container("form", args, content);
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
