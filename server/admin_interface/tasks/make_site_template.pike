/*
 * $Id: make_site_template.pike,v 1.11 2004/05/29 00:52:38 _cvs_stephen Exp $
 *
 * Make a site-template from a virtual server configuration.
 *
 * Henrik Grubbström 2001-11-16
 */

#include <admin_interface.h>

constant task = "maintenance";
constant name = "Create site template";
constant doc  = "Create a site template from a site configuration";

string indent(string s)
{
  array a = s/"\n";
  if (a[-1] == "") {
    a = a[..sizeof(a)-2];
  }
  return sprintf("%{  %s\n%}", a);
}

string parse(RequestID id)
{
  if( !config_perm( "Create Site" ) )
    error("No permission, dude!\n"); // This should not happen, really.

  string res = "<font size='+1'><b>Create site template</b></font>";

  string conf_name;
  Configuration conf;
  int done;

  if (!(conf_name = id->variables->conf)) {
    foreach(indices(id->variables), string var) {
      if (has_prefix(var, "conf-") && has_suffix(var, ".x")) {
	conf_name = var[5..sizeof(var)-3];
	break;
      }
    }
  }

  if (conf_name) {
    conf_name = Roxen.http_decode_string(conf_name);
    conf = roxen.get_configuration(conf_name);
  }

  if (!conf) {
    // Page 1
    //
    // Select a configuration.
    if (conf_name) {
      res += sprintf("<p><font color='&usr.warncolor'>Couldn't find configuration: %s</font></p>\n",
		     conf_name);
    }
    res += sprintf("<p>Select configuration to base the template on.</p>\n"
		   "<p>%{<submit-gbutton2 name='conf-%s' width='200'>%s</submit-gbutton2><br\>\n%}</p>\n",
		   map(roxen.configurations->name,
		       lambda(string n) {
			 return ({ Roxen.http_encode_string(n),
				   Roxen.html_encode_string(n) });
		       }));
  } else {
    res += sprintf("<input type=hidden name='conf' value='%s' />\n",
		   conf_name);
    if (!id->variables->fname || !sizeof(id->variables->fname)) {
      // Page 2
      //
      // Select a filename.
      res += sprintf("<p>%s: %s</p>\n",
		     "Selected configuration",
		     Roxen.html_encode_string(conf_name));

      res += sprintf("<p>Filename (.pike will be added): "
		     "<input type='text' name='fname' value='%s'></p>\n",
		     Roxen.http_encode_string(lower_case(replace(conf_name,
								 " ", "_"))));

      res += "<cf-ok/> <cf-cancel href='./?class="+task+"'/>";
    } else {
      // Page 3
      //
      // Create the site template.
      res += sprintf("<input type=hidden name='fname' value='%s' />\n",
		     Roxen.http_encode_string(id->variables->fname));

      conf->enable_all_modules();

      string fname = combine_path("/", id->variables->fname)[1..];

      string template =
	sprintf("// %s\n"
		"//\n"
		"// Created automatically from the %O configuration\n"
		"// by make_site_template.pike\n"
		"//\n"
		"// Generated on %s\n"
		"//\n"
		"\n"
		"#include <roxen.h>\n"
		"\n"
		"inherit \"" SITE_TEMPLATES "common\";\n"
		"constant site_template = 1;\n"
		"\n"
		"constant name = \"Template of \" %O;\n"
		"constant doc  = \"Site template based on \"\n"
		"                \"the \" %O \" configuration\";\n"
		"\n"
		"constant modules = %O;\n"
		"\n",
		fname,
		conf_name,
		Calendar.Second()->format_smtp(),
		conf_name,
		conf_name,
		map(indices(conf->modules),
		    lambda(string modname) {
		      return ({ modname })*
			sizeof(indices(conf->modules[modname]));
		    })*({}));
      // First find modified globals.
      array(array) globvars = filter((array)conf->variables,
				     lambda(array pair) {
				       return !pair[1]->is_defaulted();
				     });
      mapping(string:array(array(array))) modvars = ([]);
      foreach(indices(conf->modules), string mod_name) {
	array(array(array)) modified = 0;
	object copies = conf->modules[mod_name];
	foreach(indices(copies), int num) {
	  object mod = copies[num];
	  array(array) variables = filter((array)mod->variables,
					  lambda(array pair) {
					    return !pair[1]->is_defaulted();
					  });
	  if (sizeof(variables)) {
	    if (!modified) {
	      modified = allocate(sizeof(copies));
	    }
	    modified[num] = variables;
	  }
	}
	if (modified) {
	  modvars[mod_name] = modified;
	}
      }

      if (sizeof(modvars) || sizeof(globvars)) {
	template +=
	  sprintf("void init_modules(Configuration c, RequestID id)\n"
		  "{\n"
		  "%s\n"
		  "%s}\n",
		  indent(map(globvars,
			     lambda(array pair) {
			       return sprintf("c->set(%O, %O);\n",
					      pair[0], pair[1]->query());
			     }) * ""),
		  indent(map(sort(indices(modvars)),
			     lambda(string mod_name) {
			       string res = "";
			       array(array(array)) settings = modvars[mod_name];
			       foreach(indices(settings), int num) {
				 if (settings[num]) {
				   foreach(settings[num], array pair) {
				     res += sprintf("c->find_module(%O\"#%d\")->\n"
						    "  set(%O, %O);\n",
						    mod_name, num,
						    pair[0],
						    pair[1]->query());
				   }
				 }
			       }
			       return res;
			     }) * "\n"));
      }

      object st;
      if (!(st = file_stat("../local/" SITE_TEMPLATES))) {
	if (!mkdir("../local/" SITE_TEMPLATES, 0755)) {
	  res += sprintf("<p><font color='&usr.warncolor'>Couldn't create directory: %O</font></p>\n",
			 "../local/" SITE_TEMPLATES);
	}
      }
      Stdio.File f = lopen(SITE_TEMPLATES + fname + ".pike", "cw", 0644);
      if (!f) {
	res += sprintf("<p><font color='&usr.warncolor'>Failed to create template file: %O</font></p>\n",
		       "../local/" SITE_TEMPLATES +
		       Roxen.html_encode_string(fname));
      } else {
	int n = f->write(template);
	f->close();

	if (n != sizeof(template)) {
	  res += sprintf("<p><font color='&usr.warncolor'>Failed to write template file: %O</font></p>\n",
			 "../local/" SITE_TEMPLATES +
			 Roxen.html_encode_string(fname));
	} else {
	  res += "<p>Site template created successfully.</p>\n"
	    "<cf-ok/>";

	  done = 1;
	}
      }
    }
  }
  if (!done) {
    res +=
      "<input type=hidden name='task' value='make_site_template.pike' />";
  }

  if (!conf) {
    // Only on first page.
    res += "<br clear='all'>"
      "<cf-cancel href='./?class="+task+"'/>";
  }

  return res;
}
