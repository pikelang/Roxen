#include <config_interface.h>

constant base = #"<use file='/template'/><tmpl><topmenu base='../' selected='sites'/>
<content><cv-split><subtablist><st-page>
 <input type='hidden' name='name' value='&form.name;' />
 %s
 %s
</st-page></subtablist></cv-split></content></tmpl>
";

string decode_site_name( string what )
{
  if( (int)what && (search(what, ",") != -1))
    return (string)((array(int))(what/","-({""})));
  return what;
}

string encode_site_name( string what )
{
  return map( (array(int))what,
              lambda( int i ) {
                return ((string)i)+",";
              } ) * "";
}

string get_site_template(RequestID id)
{
  if( id->real_variables->site_template )
    return id->real_variables->site_template[0];
  return "&form.site_template;";
}

string|mapping parse( RequestID id )
{
  if( !config_perm( "Create Site" ) )
    error("No permission, dude!\n"); // This should not happen, really.
  if( !id->variables->name ) {
    return Roxen.http_redirect("/sites/new_site.html");
    error("No name for the site!\n"); // This should not happen either.
  }

  id->variables->name = decode_site_name( id->variables->name );

  if (!id->variables->site_template ||
      search(id->variables->site_template, "site_templates")!=-1 )
  {
    foreach( glob("*" SITE_TEMPLATES "*.x",
                   indices(id->variables) ), string t )
    {
      t = t[..sizeof(t)-3];
      id->real_variables->site_template = ({ t });
      id->variables->site_template = t;
    }
  }

  License.LicenseVariable license =
    License.LicenseVariable(getenv("ROXEN_LICENSEDIR") || "../license/", 0,
                            "License file",
                            "Use this license file for the new configuration.",
                            0, 1);
  license->set_path("license");
  if(id->variables[license->path()])
    license->set_from_form(id);

  if( id->variables->site_template &&
      search(id->variables->site_template, "site_templates")!=-1 )
  {
    object c = roxen.find_configuration( id->variables->name );
    if( !c ) c = roxen.enable_configuration( id->variables->name );
    catch(DBManager.set_permission( "docs", c,   DBManager.READ ));
    catch(DBManager.set_permission( "replicate", c, DBManager.WRITE ));
    DBManager.set_permission( "local", c,  DBManager.WRITE );
    c->error_log[0] = 1;
    id->misc->new_configuration = c;

    // Set license in the new configuration if it is unset.
    if(!c->getvar("license")->query()) {
      c->getvar("license")->set(license->query());
    }

    master()->clear_compilation_failures();

    object b;
    if (file_stat("../local/"+id->variables->site_template)) {
      b = ((program)("../local/"+id->variables->site_template))();
    } else {
      b = ((program)id->variables->site_template)();
    }

    string q = b->parse( id );
    if( !stringp( q ) )
      return q;

    if( lower_case(q-" ") == "<done/>" )
    {
      c->error_log = ([]);
      return Roxen.http_redirect(Roxen.fix_relative("site.html/"+
                                                    id->variables->name+"/",
                                                    id), id);
    }
    return sprintf(base,"<input name='site_template' type='hidden' "
                   "value='"+get_site_template(id)+"' />\n", q);
  }

  roxenloader.ErrorContainer e = roxenloader.ErrorContainer( );
  master()->set_inhibit_compile_errors( e );
  string res = "";
  array sts = ({});
  array(string) templates = ({});
  foreach(({ "." }) + roxenloader->package_directories,
          string pkg_dir) {
    string template_dir = combine_path(pkg_dir, SITE_TEMPLATES);
    array(string) sts = get_dir(template_dir);
    if (!sts) continue;
    templates += map(glob( "*.pike", sts),
                     lambda(string st, string template_dir) {
                       return template_dir + st;
                     }, template_dir);
    TRACE("templates: %O\n", templates);
  }

  foreach( templates, string st ) {
    mixed err = catch {
      program p;
      object q;
      p = (program)(st);
      if(!p) {
        report_error("Template \""+st+"\" failed to compile.\n");
        continue;
      }
      q = p();
      if( q->site_template )
      {
        string name, doc, group;
        if( q[ "name_"+id->misc->cf_locale ] )
          name = q[ "name_"+id->misc->cf_locale ];
        else
          name = q->name;

        if( q[ "doc_"+id->misc->cf_locale ] )
          doc = q[ "doc_"+id->misc->cf_locale ];
        else
          doc = q->doc;

        if( q[ "group_"+id->misc->cf_locale ] )
          group = q[ "group_"+id->misc->cf_locale ];
        else
          group = q->group;

        string button;
        if(q->locked && !(license->get_key() && q->unlocked(license->get_key())))
          button =
            "<disabled-gbutton width='400px' type='padlock'>"
            + Roxen.html_encode_string(name) +
            "</disabled-gbutton>";
        else {
          button = "<submit-gbutton2 name='" + st + "' type='add' width='400px'>" +
                   Roxen.html_encode_string(name) +
                   "</submit-gbutton2>";
        }

        //  Build a sort identifier on the form "999|Group name|template name"
        //  where 999 is a number which orders the groups. The group name is
        //  the only string which the user will see. All templates which don't
        //  contain a number will default to position 500.
        string sort_id = group || "Roxen WebServer";
        if (!has_value(sort_id, "|"))
          sort_id = "500|" + sort_id;
        sort_id += "|" + name;
        sts += ({ ({ sort_id, name,
                     button + "<blockquote>" + doc + "</blockquote>" }) });
      }
    };
    if (err) {
      report_error(sprintf("Template %O failed:\n"
                           "%s\n",
                           st, describe_backtrace(err)));
    }
  }

  int n;
  string last_group;
  sort( sts );
  foreach( sts, array q ) {
    //  Extract group name and create divider if different from last one
    string group = (q[0] / "|")[1];
    if (group != last_group) {
      if (n++) {
        res += "<hr>";
      }
      res +=
        "<h3>" + group + "</h3>\n";
      last_group = group;
    }
    res += q[2] + "\n\n\n";
  }

  res += "<hr><cf-cancel href='./'/>\n"
    "<input type='hidden' name='initialize_template' value='1' />\n";


  if( strlen( e->get() ) ) {
    res += ("Compile errors:<pre>"+
            Roxen.html_encode_string(e->get())+
            "</pre>");
    report_error("Compile errors: "+e->get()+"\n");
  }
  master()->set_inhibit_compile_errors( 0 );


  // License stuff
  string render_variable(Variable.Variable var, RequestID id)
  {
    string pre = var->get_warnings();

    if( pre ) {
      pre = "<div>"+
            Roxen.html_encode_string( pre )+
            "</div>";
    }
    else {
      pre = "";
    }

    string name = var->name()+"";
    string ret = "<div class='margin-bottom'><label class='large bold'>"+
      Roxen.html_encode_string(name)+": </label> "
      "<span class='select-wrapper'>" +
        var->render_form(id, ([ "autosubmit":1 ])) +
      "</span> "
      "<submit-gbutton2 name='set_license'>Set</submit-gbutton2>"
      "</div>";
      if (sizeof(pre)) {
        ret += "<div class='notify error margin-top'>" + pre + "</div>";
      }
      ret += "<div>"+var->doc()+"</div>\n";

    return ret;
  };
  string license_res = "";
  if(license->check_visibility(id, 0, 0, 0, 0))
    license_res =
      render_variable(license, id) +
      "<hr>\n";

  return sprintf(base, license_res, res);
}
