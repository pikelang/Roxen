#include <config_interface.h>
#include <roxen.h>

//<locale-token project="roxen_config">LOCALE</locale-token>
#define LOCALE(X,Y)     _DEF_LOCALE("roxen_config",X,Y)


void get_dead( string cfg, int del )
{
};

constant tmpl = #"
<use file='/template' />
<tmpl title='{{ title }}'>
  <topmenu base='&cf.num-dotdots;' selected='sites'/>
  <content><cv-split>
    <subtablist>
      <st-tabs></st-tabs>
      <st-page>
        <div class='notify warn'><b>{{ warning }}</b></div>

      </st-page>
    </subtablist>
  </cv-split></content>
</tmpl>
";

string|mapping parse( RequestID id )
{
  if (!config_perm("Create Site")) {
    return LOCALE(226, "Permission denied");
  }

  if (!id->variables->site) {
    return Roxen.http_redirect("/sites/", id);
  }

  Configuration cf = roxen->find_configuration(id->variables->site);

  if (!cf) {
    return "No such configuration: "+id->variables->site;
  }

  if (!id->variables["really.x"]) {
    mapping mctx = ([
      "site"        : Roxen.html_encode_string(id->variables->site),
      "title"       : LOCALE(249,"Drop old site"),
      "warning"     : sprintf(
                        (string)LOCALE(235,"Are you sure you want to disable "
                                           "the site %s?"),
                        cf->query_name()||""),
      "ports_msg"   : LOCALE(468,"This site listens to the following ports:"),
      "drop_db_msg" : LOCALE(469,"Databases that will no longer be used"),
      "urls"        : ({}),
      "dbs"         : ({})
    ]);

    string res =
      "<use file='/template' />\n"
      "<tmpl title=' "+ LOCALE(249,"Drop old site") +"'>"
      "<topmenu base='&cf.num-dotdots;' selected='sites'/>\n"
      "<content><cv-split>"
      "<subtablist width='100%'>"
      "<st-tabs></st-tabs>"
      "<st-page><div class='notify warn'><b>"+
      sprintf((string)(LOCALE(235,"Are you sure you want to disable the site %s?")+"\n"),
               (cf->query_name()||""))+
      "</b></div>";

    // 1: Find databases that will be "dead" when this site is gone.
    mapping q = DBManager.get_permission_map();
    array dead = ({});

    foreach (sort(indices(q)), string db) {
      int ok;
      foreach (indices(q[db]), string c) {
        foreach ((roxen->configurations - ({ cf }))->name, string c) {
          if (q[db][c] != DBManager.NONE) {
            ok=1;
            break;
          }
        }
      }

      if (!ok) {
        dead += ({ db });
      }
    }

    // Never ever drop these.
    dead -= ({ "roxen", "mysql", "local", "replicate" });

    res += "<b>"+
      LOCALE(468,"This site listens to the following ports:")+"</b><br />\n";

    res += "<ul>\n";

    foreach (cf->query("URLs"), string url) {
      url = (url/"#")[0];
#if constant(gethostname)
      res += "<li> "+replace(url,"*",gethostname())+"\n";
      url = replace(url, "*", gethostname());
#else
      res += "<li> "+url+"\n";
#endif
      mctx->urls += ({ url });
    }

    res += "</ul\n>";

    if (sizeof(dead)) {
      res += "<b>"+LOCALE(469,"Databases that will no longer be used")+
        "</b><br />";

      res += "<blockquote>";

      if (sizeof(dead) == 1)
        res += LOCALE(470,"If you do not want to delete this database, "
                      "uncheck the checkmark in front of it");
      else {
        res += "<p>" +
          LOCALE(471,"If you do not want to delete one or more of these "
                 "databases, uncheck the checkmark in front of the ones"
                 " you want to keep.") +
          #"</p>
<script type='text/javascript'>
  var check_all_toggle = 0;
  function checkAll() {
    var checkboxes = document.getElementById ('checkbox_list').
      getElementsByTagName ('INPUT');
    for (var i = 0; i < checkboxes.length; i++) {
      checkboxes[i].checked = check_all_toggle;
    }
    check_all_toggle = !check_all_toggle;
  }
</script>
<p><a id='check_all_button' onClick='checkAll()'><gbutton>" +
          LOCALE(1065, "Uncheck/Check All") +
          "</gbutton></a></p>\n";
      }
      res += "<ul id='checkbox_list'>";
      int n;
      foreach (dead, string d) {
        mctx->dbs += ({ d });
        res += "<li style='list-style-image: none; list-style-type: none'>"
          "<input name='del_db_"+d+"' id='del_db_"+d+"' type=checkbox checked=checked />"
          "<label for='del_db_"+d+"'>"+d+"</label></li>\n";
      }
      res += "</ul>";
      res += "</blockquote>";
    }
    // 2: Tables


    res += ("<input type=hidden name=site value='"+
            Roxen.html_encode_string(id->variables->site)+"' />");

    res +=
      "<p><submit-gbutton2 name='really'> "+
      LOCALE(249,"Drop old site") +
      " </submit-gbutton2> "
      "<cf-cancel href='./'/>";

    TRACE("ctx: %O\n", mctx);

    return res +
      "</st-page></subtablist></td></tr></table>"
      "</cv-split></content></tmpl>";
  }


  report_notice(LOCALE(255, "Disabling old configuration %s")+"\n",
                cf->name);

  foreach( glob("del_db_*", indices(id->variables)), string d ) {
    d = d[7..];
    DBManager.drop_db( d );
  }
  string cfname = roxen.configuration_dir + "/" + cf->name;
  mv (cfname, cfname + "~");
  roxen->remove_configuration( cf->name );
  cf->stop();
  destruct( cf );

  return Roxen.http_redirect( "/sites/", id );
}
