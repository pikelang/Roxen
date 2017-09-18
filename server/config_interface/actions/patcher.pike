// $Id$

#include <config_interface.h>
#include <roxen.h>

import RoxenPatch;

//<locale-token project="admin_tasks"> LOCALE </locale-token>
#define LOCALE(X,Y)  _STR_LOCALE("admin_tasks",X,Y)

constant action = "maintenance";

// constant long_flags = ([ "restart" : LOCALE(0, "Need to restart server") ]);

string name= LOCALE(326, "Patch management");
string doc = LOCALE(327, "Show information about the available patches and "
                         "their status.");

Write_back wb =
  class Write_back
  {
    private array(mapping(string:string)) all_messages = ({ });

    void write_mess(string s)
    {
      s = Roxen.html_encode_string(s);
      s = replace(s, ([ "&lt;green&gt;"  : "<b class='notify ok inline'>",
                        "&lt;/green&gt;" : "</b>" ]) );
      all_messages += ({ (["message":s ]) });
    }

    void write_error(string s)
    {
      s = Roxen.html_encode_string(s);
      all_messages += ({
        ([ "error":"<div class='notify error inline'>" + s + "</div><br>" ])
      });
    }

    string get_messages()
    {
      string res = "";

      foreach(all_messages->message, string s)
      {
        if(s)
          res += s;
      }

      return res;
    }

    string get_errors()
    {
      string res = "";
      foreach(all_messages->error, string s)
      {
        if(s)
          res += s;
      }
      return res;
    }

    void clear_all()
    {
      all_messages = ({ });
    }

    string get_all_messages()
    {
      string res = "";

      foreach(all_messages, mapping m)
      {
        if (m->message)
          res += m->message;
        else
          res += m->error;
      }

      res = replace(res, "\n", "<br />");
      return res;
    }
  } ();

mapping get_patch_stats(Patcher po)
{
  array a_imported = po->file_list_imported();
  array a_installed = po->file_list_installed();

  return ([
    "imported_count": sizeof(a_imported),
    "installed_count": sizeof(a_installed),
  ]);
}

array(string) get_missing_binaries() {
#ifdef __NT__
  array(string) bins = ({ "tar.exe", "patch.exe" });
#else
  array(string) bins = ({ "tar", "patch" });
#endif

  array(string) r = ({ });
  foreach (bins, string a) {
    if (!search_path(a)) r += ({ a });
  }
  return r;
}

array(array(string)) describe_metadata(Patcher po,
                                       array(mapping(string:string)) md,
                                       LocaleString singular,
                                       LocaleString plural,
                                       string|void patch_path)
{
  if (!md || !sizeof(md)) return ({});

  mapping(string:multiset(string)) files = ([]);
  foreach(md, mapping(string:string) item) {
    array(string) file_list = ({});
    if (item->destination) {
      file_list = ({ item->destination });
    } else if (item->source) {
      file_list = po->lsdiff(Stdio.read_file(combine_path(patch_path,
                                                          item->source)));
    }
    foreach(file_list, string file) {
      if (!files[file]) files[file] = (<>);
      files[file][item->platform] = 1;
    }
  }

  string res = "";
  foreach(sort(indices(files)), string file) {
    multiset(string) platforms = files[file];
    array(string) post = ({});
    if (!platforms[0] && !platforms[po->server_platform]) {
      res += "<span class='dimmed'>" + file + "</span>";
    } else {
      res += file;
    }
    if ((sizeof(platforms) > 1) || !platforms[0]) {
      res += "&nbsp;[";
      if (platforms[0]) {
        res += "<b>ALL</b>";
      }
      foreach(sort(indices(platforms)); int i; string platform) {
        if (!platform) continue;
        if (i || !platforms[0]) {
          res += ", ";
        }
        if (platform == po->server_platform) {
          res += "<b>" + platform + "</b>";
        } else {
          res += platform;
        }
      }
      res += "]";
    }
    res += "<br />\n";
  }
  if (sizeof(files) == 1) return ({ ({ singular, res }) });
  return ({ ({ plural, res }) });
}

protected string format_description(string desc)
{
  if (!has_value(desc, "\n")) {
    // Old-style description.
    return Roxen.html_encode_string(desc);
  }

  // plain-text formatted description.
  //
  // Split into paragraphs, identify indentation levels,
  // and create list items.

  // Normalize empty lines.
  desc = map(desc/"\n",
             lambda(string line) {
               if (String.trim_all_whites(line) == "") return "";
               return line;
             }) * "\n";

  array(array(int|string)) paragraphs = ({});
  multiset(int) indents = (<>);
  foreach(desc/"\n\n", string paragraph) {
    if (String.trim_all_whites(paragraph) == "") continue;
    string indent = "";
    string bullet = "";
    sscanf(paragraph, "%[ ]%[-*o+ ]%s", indent, bullet, paragraph);
    if (sizeof(bullet) && has_suffix(bullet, " ")) {
      // Looks like we have a bullet.
      indent += bullet;
    } else {
      // Not a bullet. Restore the prefix.
      paragraph = bullet + paragraph;
      bullet = "";
    }

    paragraphs += ({ ({ sizeof(indent), !!sizeof(bullet), paragraph }) });
    indents[sizeof(indent)] = 1;
  }

  array(int) tabstops = sort(indices(indents));
  String.Buffer buf = String.Buffer();
  int tab = 0;
  int is_open = 1;
  foreach(paragraphs, [int indent, int is_bullet, string paragraph]) {
    while (indent > tabstops[tab]) {
      if (!is_open) {
        buf->add("<li'>\n");
      }
      buf->add("<ul class='no-list'>\n");
      is_open = 0;
      tab++;
    }
    while (indent < tabstops[tab]) {
      if (is_open) {
        buf->add("</li>\n");
      }
      buf->add("</ul>\n");
      is_open = 1;
      tab--;
    }
    paragraph = Roxen.html_encode_string(paragraph);
    if (!is_open) {
      if (is_bullet) {
        buf->add("<li>\n");
      } else {
        buf->add("<li'>\n");
      }
      buf->add("<p>", paragraph, "</p>\n");
      is_open = 1;
    } else if (is_bullet) {
      buf->add("</li>\n"
               "<li><p>", paragraph, "</p>\n");
    } else {
      buf->add("<p>", paragraph, "</p>\n");
    }
  }
  while (tab) {
    if (is_open) {
      buf->add("</li>\n");
    }
    buf->add("</ul>\n");
    is_open = 1;
    tab--;
  }

  return buf->get();
}

string list_patches(RequestID id, Patcher po, string which_list)
{
  string self_url = "?class=maintenance&amp;action=patcher.pike&amp;&usr.set-wiz-id;";
  string res = "";

  array(mapping) list;
  int colspan = 5;
  if (which_list == "installed")
  {
    list = po->file_list_installed();
  }
  else if (which_list == "imported")
  {
    list = po->file_list_imported();
  }
  else
    // This should never happen.
    return 0;

  string table_bgcolor = "";
  if (list && sizeof(list))
  {
    multiset(string) extra_deps = (<>);
    foreach(list; int i; mapping item)
    {
      string installed_date = "";
      if(which_list == "installed")
      {
        if (item->installed)
        {
          installed_date = sprintf("        <td class='nobr'><date strftime='%%c'"
                                   " iso-time='%d-%02d-%02d %02d:%02d:%02d' />"
                                   "</td>\n",
                                   (item->installed->year < 1900) ?
                                   item->installed->year + 1900 :
                                   item->installed->year,
                                   item->installed->mon,
                                   item->installed->mday,
                                   item->installed->hour,
                                   item->installed->min,
                                   item->installed->sec
                                   );
        }
        else
          installed_date = "        <td><red>Unknown<red></td>\n";
      }

      // Calculate dependencies of other patches
      string deps = "";
      if (which_list != "installed") {
        // NB: There's no need to calculate forward dependencies
        //     for uninstallation...
        foreach(po->get_dependencies(item->metadata->id) || ({ });
                int i;
                string s)
        {
          foreach(s/"|", string d) {
            if (has_value(d, "/") && po->is_installed(d, 1)) {
              extra_deps[d] = 1;
            }
          }
          if (i > 0)
            deps += ", ";

          deps += s;
        }
      }

      // Make sure that only patches for the right platform and version are
      // installable
      int is_right_version = 1;
      int is_right_platform = 1;
      if (which_list == "imported") {
        if (sizeof(item->metadata->version || ({})))
          is_right_version = !!sizeof(filter(item->metadata->version,
                                             po->check_server_version));

        if (sizeof(item->metadata->platform || ({})))
          is_right_platform = !!sizeof(filter(item->metadata->platform,
                                              po->check_platform));

        if (!(is_right_version && is_right_platform))
          deps += "not_installable";
      }

      res += sprintf("      <tr>\n"
                     "        <td style='width:20px;text-align:right'>\n"
                     "          <cf-perm perm='Update'>\n"
                     "          <input type='checkbox' id='%s'"
                     " name='%s' value='%[0]s' dependencies='%s'" +
                     " onclick='toggle_%[1]s(%s)' />\n"
                     "          </cf-perm>\n"
                     "        </td>\n"
                     "        <td class='icon folded cursor-pointer' id='%s_img'"
                     " onclick='expand(\"%[4]s\")' /><span class='the-icon'></span></td>\n"
                     "        <td onclick='expand(\"%[4]s\");' class='cursor-pointer'>%[0]s</td>\n"
                     "        <td onclick='expand(\"%[4]s\");' class='cursor-pointer'>%s</td>\n"
                     "%s"
                     + (which_list == "imported" ?
                        "<td style='text-align:right'>"
                        "<cf-perm perm='Update'>"
                        "<link-gbutton href='?action=patcher.pike&"
                          "class=maintenance&remove-patch-id=%[0]s"
                          "&amp;&usr.set-wiz-id;' "
                          " type='remove'>Remove</link-gbutton>"
                        "</cf-perm>"
                        "</td>"
                        : "") +
                     "      </tr>\n",
                     item->metadata->id,
                     (which_list == "imported") ? "install" : "uninstall",
                     deps,
                     (which_list == "installed") ?
                     "\"" + item->metadata->id + "\"" : "",
                     replace(item->metadata->id, "-", ""),
                     Roxen.html_encode_string(item->metadata->name),
                     installed_date);

      array md = ({ });
      if (which_list == "installed")
      {
        md += ({
          ({ LOCALE(328, "Installed by:")       , item->user || "Unknown" }),
        });
      }
      else if (item->installed)
      {
        string date = sprintf("%4d-%02d-%02d %02d:%02d",
                              (item->installed->year < 1900) ?
                              item->installed->year + 1900 :
                              item->installed->year,
                              item->installed->mon,
                              item->installed->mday,
                              item->installed->hour,
                              item->installed->min);
        md += ({
          ({ LOCALE(329, "Installed:")  , date }),
          ({ LOCALE(328, "Installed by:")       , item->user || LOCALE(330, "Unknown") }),
        });
      }

      if (item->uninstalled)
      {
        string date = sprintf("%4d-%02d-%02d %02d:%02d",
                              (item->year < 1900) ?
                              item->installed->year + 1900 :
                              item->installed->year,
                              item->installed->mon,
                              item->installed->mday,
                              item->installed->hour,
                              item->installed->min);
        md += ({
          ({ LOCALE(331, "Uninstalled:")         , date }),
          ({ LOCALE(332, "Uninstalled by:") ,
             item->uninstall_user || LOCALE(330, "Unknown") }),
        });
      }

      md += ({
        ({ LOCALE(333, "Description:")  ,
           format_description(item->metadata->description) }),
        ({ LOCALE(334, "Originator:")   , item->metadata->originator  }),
        ({ LOCALE(408, "RXP Version:")    , item->metadata->rxp_version }),
      });


      string active_flags = "        <table class='module-sub-list-2'>\n";
      foreach(known_flags; string index; string long_reading)
      {
        active_flags += sprintf("          <tr><td>%s</td>"
                                "<td style='width: 100%%'>%s</td></tr>\n",
                                replace(long_reading, " ", "&nbsp;") + ":",
                                (item->metadata->flags &&
                                 item->metadata->flags[index]) ?
                                "<b class='notify ok inline'>" +
                                LOCALE(335, "Yes") + "</b>" :
                                "<b class='notify warn inline'>" + LOCALE(336, "No") + "</b>");
      }
      md += ({ ({ LOCALE(337, "Flags:"), active_flags + "        </table>\n"}) });

      if (!sizeof(item->metadata->platform || ({})))
      {
        md += ({
          ({ LOCALE(338, "Platforms:"), LOCALE(339, "All platforms") })
        });
      }
      else if (item->metadata->platform &&
               sizeof(item->metadata->platform) == 1)
      {
        md += ({
          ({ is_right_platform ?
             LOCALE(340, "Platform:") :
             "<b class='notify error inline'>" + LOCALE(340, "Platform:") + "</b>",
             item->metadata->platform[0] })
        });
      }
      else
      {
        md += ({
          ({ is_right_platform ?
             LOCALE(338, "Platforms:") :
             "<b class='notify error inline'" + LOCALE(338, "Platforms:") + "</b>",
             sprintf("%{%s<br />\n%}",
                     item->metadata->platform) })
        });
      }

      if (sizeof(item->metadata->version || ({})))
      {
        md += ({
          ({ is_right_version ?
             LOCALE(342, "Target version:"):
             "<b class='notify error inline'>" + LOCALE(342, "Target version:") + "</b>",
             sprintf("%{%s<br />\n%}",
                     item->metadata->version) })
        });
      }
      else
      {
        md += ({
          ({ LOCALE(342, "Target version:"), LOCALE(343, "All versions") })
        });
      }

      if (sizeof(item->metadata->depends || ({})))
      {
        string dep_list = "";
        foreach (item->metadata->depends, string dep)
        {
          foreach(dep/"|"; int i; string dep_id) {
            string dep_stat =
              "<b class='notify error inline'>" + LOCALE(346, "unavailable") + "</b>";
            if (!has_value(dep_id, "/")) {
              switch(po->patch_status(dep_id)->status)
              {
              case "installed":
                dep_stat = LOCALE(344, "installed");
                break;
              case "uninstalled":
              case "imported":
                dep_stat = LOCALE(345, "imported");
                break;
              }
            } else if (po->is_installed(dep_id,
                                        item->metadata->rxp_version > "1.0")) {
              dep_stat = LOCALE(344, "installed");
            }
            if (i) dep_list += " or ";
            dep_list += sprintf("%s (%s)", dep_id, dep_stat);
          }
          dep_list += "<br />\n";
        }
        md += ({
          ({ LOCALE(347, "Dependencies:"), dep_list })
        });
      }
      else
      {
        md += ({
          ({ LOCALE(347, "Dependencies:"), LOCALE(348, "None") }),
        });
      }

      md += describe_metadata(po, item->metadata->new,
                              LOCALE(349, "New file:"),
                              LOCALE(350, "New files:"));
      md += describe_metadata(po, item->metadata->replace,
                              LOCALE(351, "Replaced file:"),
                              LOCALE(352, "Replaced files:"));
      md += describe_metadata(po, item->metadata->delete,
                              LOCALE(353, "Deleted file:"),
                              LOCALE(354, "Deleted files:"));

      if (which_list == "imported") {
        md += describe_metadata(po, item->metadata->patch,
                                LOCALE(355, "Patched file:"),
                                LOCALE(356, "Patched files:"),
                                combine_path(po->get_import_dir(),
                                             item->metadata->id));
      } else {
        md += describe_metadata(po, item->metadata->patch,
                                LOCALE(355, "Patched file:"),
                                LOCALE(356, "Patched files:"),
                                combine_path(po->get_installed_dir(),
                                             item->metadata->id));
      }

      res += sprintf("      <tr id='id%s' style='display: none'>\n"
                     "        <td colspan='2'>&nbsp;</td>\n"
                     "        <td colspan='%d' class='nopad'>\n"
                     "          <table class='module-sub-list'>\n"
                     "%{            <tr>\n"
                     "              <th align='right'>%s</th>\n"
                     "              <td>\n%s</td>\n"
                     "            </tr>\n%}"
                     "          </table>\n"
                     "        </td>\n"
                     "      </tr>\n",
                     replace(item->metadata->id, "-", ""),
                     colspan - 2,
                     md);
    }
    foreach(sort(indices(extra_deps)), string dep) {
      // Add uninstall checkbox markers for all valid version dependencies,
      // so that the toggle_dep_install() javascript can know about them.
      //
      // Note that the value 'on' will cause the value to
      // be ignored when it is submitted.
      res +=
        sprintf("      <tr style='display:none'>\n"
                "        <td style='width:20px;text-align:right'>\n"
                "          <cf-perm perm='Update'>\n"
                "          <input type='checkbox' id='%s' name='uninstall'"
                " value='on' dependencies=''/>\n"
                "          </cf-perm>\n"
                "        </td>\n"
                "        <td colspan='4'>&nbsp;</td>\n"
                "      </tr>\n",
                dep);
    }
  }
  else
  {
    res += sprintf("      <tr>\n"
                   "        <td colspan='%d'"
                   " style='text-align:center;font-style:italic'>\n"
                   "          " + LOCALE(357, "No patches found") + "\n"
                   "        </td>\n"
                   "      </tr>\n",
                   colspan);
  }

  res += sprintf("      <tr class='tfoot'>\n"
                 "        <td colspan='%d'"
                 " align='left'>\n"
                 "          <cf-perm perm='Update'>\n"
                 "          <submit-gbutton2 type='%[4]s'"
                 " name='%s-button'%s>%s</submit-gbutton2>\n"
                 "          </cf-perm>\n"
                 "        </td>\n"
                 "      </tr>\n",
                 colspan,
                 (which_list == "installed") ? "uninstall" : "install",
                 (sizeof(list))              ? "" : " disabled='disabled'",
                 (which_list == "installed") ? LOCALE(358, "Uninstall selected patches") :
                                               LOCALE(359, "Install selected patches"),
                 (which_list == "installed") ? "remove" : "add");

  return res; //+ sprintf("<td>&nbsp;</td>"
//                     "<td>&nbsp;</td>"
//                     "<td><pre>%O</pre></td>"
//                     "<td>&nbsp;</td>"
//                     "<td>&nbsp;</td>",
//                     getenv("ROXEN_SERVER_DIR"));
}

mixed parse(RequestID id)
{
  string current_user = sprintf("%s (%s)",
                                RXML.get_var("user-name", "usr"),
                                RXML.get_var("user-uid", "usr"));

  string tmp_dir = roxen_path("$VVARDIR/tmp");

  if (!Stdio.is_dir(tmp_dir)) {
    Privs privs = Privs("RoxenPatch: Creating tmp directory.\n");
    Stdio.mkdirhier(roxen_path("$VVARDIR"));
    mkdir(tmp_dir, 01777);      /* rwxrwxrwxt */
    privs = 0;
  }

  // Init patch-object
  wb->clear_all();
  Patcher plib = Patcher(wb->write_mess,
                         wb->write_error,
                         getcwd(),
                         roxen_path("$LOCALDIR"),
                         tmp_dir);

  string res = #"
    <script type='text/javascript'>
      // <![CDATA[
      function expand(element)
      {
        var blockToToggle = document.getElementById('id' + element);
        var pictureToToggle = document.getElementById(element + '_img');

        if (blockToToggle.style.display == 'none')
        {
          blockToToggle.style.display = '';
          pictureToToggle.className = 'unfolded icon cursor-pointer';
        }
        else
        {
          blockToToggle.style.display = 'none';
          pictureToToggle.className = 'folded icon cursor-pointer';
        }
      }
      // ]]>
    </script>";

  array(string) mbins = get_missing_binaries();
  if (sizeof(mbins)) {
    res += "<div class='notify warn'><b>" + LOCALE(409, "Warning: Missing tools") + "</b><br/><br/>";
    res += "Roxen can't find one or more tools required for the patch management to work properly.<br/>";
    res += "Before importing or installing any patches, please make sure you have the following executable(s) available on your system:<br/>";

    res += "<ul>";
    foreach (mbins, string a) res += "<li>" + a + "</li>";
    res += "</ul>";
    res += "</div>";
  }


  if(config_perm("Update") &&
     (id->real_variables["auto-import-button.x"] ||
      (id->real_variables["OK.x"] &&
       id->real_variables["fixedfilename"] &&
       sizeof(id->real_variables["fixedfilename"][0]) &&
       id->real_variables["file"] &&
       sizeof(id->real_variables["file"][0]))))
  {
    array(int|string) patch_ids;

    if (id->real_variables["auto-import-button.x"]) {
      // The Patcher will download the latest rxp cluster from www.roxen.com
      // and import the patches.
      patch_ids = plib->import_file_http();

      if (!patch_ids) {
        report_error("Patch manager: RXP cluster import over HTTP failed.\n");
        res += sprintf("<p>"
                       "  <b class='notify error inline'>"
                       + LOCALE(410, "RXP cluster import over HTTP failed..") +
                       "  </b>"
                       "</p>");
          res += sprintf("<p><span id='log_img' class='unfolded icon'"
                         " onmouseover='this.style.cursor=\"pointer\"'"
                         " onclick='expand(\"log\")'>log</span>"
                         "<div  id='idlog'>%s</div></p>\n"
                         "<br clear='all' /><br />\n"
                         "<cf-ok-button href='?action=patcher.pike&amp;"
                         "class=maintenance&amp;&usr.set-wiz-id;' />",
                         wb->get_all_messages());
        return res;
      }

    } else {
      //  With Windows browsers the submitted filename may contain a full path
      //  with drive letter etc. When the Patcher processes it later it will
      //  convert slashes etc, but for our file to be accessible in that layer
      //  we must perform the same cleanup in the naming of our temp file.
      string patch_name =
        basename(RoxenPatch.unixify_path(id->real_variables["fixedfilename"][0]));
      string file_data = id->real_variables["file"][0];

      string temp_dir =
        Stdio.append_path(plib->get_temp_dir(), patch_name);

      Privs privs = Privs("RoxenPatch: Saving uploaded patch cluster...");
      // Extra directory level to get rid of the sticky bit normally
      // present on /tmp/ that would require Privs for clean_up to work.
      mkdir(temp_dir);
      string temp_file = Stdio.append_path(temp_dir, patch_name);
      plib->write_file_to_disk(temp_file, file_data);
      privs = 0;

      patch_ids = plib->import_file(temp_file);
      plib->clean_up(temp_dir);
    }

    int failed_patches, num_patches = sizeof(patch_ids);
    foreach(patch_ids, int|string patch_id) {
      if (patch_id == 0)
        failed_patches++;
    }

    res += sprintf("<font size='+1' >"
                   "  <b>"
                   + LOCALE(360, "Importing") +
                   "  </b>"
                   "</font>"
                   "<br/><br/>\n");

    if (failed_patches) {
      if (failed_patches == sizeof(patch_ids)) {
        res += sprintf("<p>"
                       "  <b class='notify error inline'>"
                       + LOCALE(411, "The patch import failed:") +
                       "  </b>"
                       "</p>");
      } else {
        res += sprintf("<p>"
                       "  <b class='notify warn inline'>"
                       + LOCALE(412, "All patches were not imported:") +
                       "  </b>"
                       "</p>");
      }

    } else {
      res += sprintf("<p>"
                     "  <b class='notify ok inline'>"
                     + LOCALE(413, "Patch import done.") +
                     "  </b>"
                     "</p>");
    }

    res += sprintf("<p><span id='log_img' class='icon %s'"
                   " onmouseover='this.style.cursor=\"pointer\"'"
                   " onclick='expand(\"log\")'>log</span>"
                   "<div style='%s' id='idlog'>%s</div></p>\n"
                   "<br clear='all' /><br />\n"
                   "<cf-ok-button href='?action=patcher.pike&amp;"
                   "class=maintenance&amp;&usr.set-wiz-id;' />",
                   failed_patches ? "unfolded" : "folded",
                   failed_patches ? "" : "display: none",
                   wb->get_all_messages());
    wb->clear_all();
    return res;
  }

  if (config_perm("Update") &&
      id->real_variables["uninstall-button.x"] &&
      id->real_variables->uninstall &&
      sizeof(id->real_variables->uninstall))
  {
    int successful_uninstalls;
    int no_of_patches;
    multiset flags = (< >);
    foreach(id->real_variables->uninstall, string patch)
    {
      if (patch != "on")
      {
        if (plib->uninstall_patch(patch, current_user))
        {
          report_notice_for(0, "Patch manager: Successfully uninstalled %s.\n",
                            patch);
          successful_uninstalls++;
        }
        else
          report_error_for(0, "Patch manager: Failed to uninstall %s\n", patch);
        no_of_patches++;
        PatchObject md = plib->get_metadata(patch);
        if (md && md->flags)
          flags += md->flags;
      }
    }
    res += "<font size='+1' ><b>" + LOCALE(363, "Uninstalling") +
           "</b></font><br/><br/>\n<h1>" + LOCALE(364, "Done!") + "</h1><br/>";

    if (no_of_patches == 1)
    {
      if (!successful_uninstalls)
        res += "<p>" + LOCALE(365, "Failed to uninstall the patch. See the log"
                                 " below for details") + "</p>\n";
      else
        res += "<p>" + LOCALE(366, "Patch uninstalled successfully. See the log"
                                 " below for details") + "</p>\n";
    }
    else
    {
      res += sprintf("<p>" + LOCALE(367, "%d out of %d patches sucessfully"
                     " uninstalled. See the log below for details.") + "</p>\n",
                     successful_uninstalls,
                     no_of_patches);
    }

    // Do we need to restart?
    if (flags->restart)
    {
      string pid = (string)getpid();
      res += "<blockquote><br />\n"
             + LOCALE(368, "The server needs to be restarted.") + #"
  <cf-perm perm='Restart'>
    " + LOCALE(369, "Would you like to do  that now?") + #"<br />
    <gbutton href='?what=restart&amp;action=restart.pike&amp;class=maintenance&amp;pid=" +
        pid + #"&amp;&usr.set-wiz-id;' width=250 icon_src=&usr.err-2;> " + LOCALE(197,"Restart") +
#" </gbutton>
  </cf-perm>

  <cf-perm not perm='Restart'>
    <gbutton dim width=250 icon_src=&usr.err-2;> " + LOCALE(197,"Restart") +
#" </gbutton>
  </cf-perm>";
    }

    res += sprintf("<p><span id='log_img' class='icon %s'"
                   " onmouseover='this.style.cursor=\"pointer\"'"
                   " onclick='expand(\"log\")'>log</span>"
                   "<div style='%s' id='idlog'>%s</div></p>\n"
                   "<cf-ok-button href='?action=patcher.pike&amp;"
                   "class=maintenance&amp;&usr.set-wiz-id;' />",
                   successful_uninstalls < no_of_patches ? "unfolded" :
                   "folded",
                   successful_uninstalls < no_of_patches ? "" : "display: none",
                   wb->get_all_messages());
    wb->clear_all();
    return Roxen.http_string_answer(res);
  }

  if (config_perm("Update") &&
      id->real_variables["install-button.x"] &&
      id->real_variables->install &&
      sizeof(id->real_variables->install))
  {
    int successful_installs;
    int no_of_patches;
    multiset flags = (< >);
    foreach(id->real_variables->install, string patch)
    {
      if (patch != "on")
      {
        mixed err = catch {
            if ( plib->install_patch(patch, current_user) )
            {
              report_notice_for(0, "Patch manager: Installed %s.\n", patch);
              successful_installs++;
            }
            else
              report_error_for(0, "Patch manager: Failed to install %s.\n",
                               patch);
          };
        if (err) {
          report_error_for(0, "Patch manager: Failed to install %s:\n"
                           "%s\n",
                           patch, describe_backtrace(err));
        }
        no_of_patches++;
        PatchObject md = plib->get_metadata(patch);
        if (md && md->flags)
          flags += md->flags;
      }
    }
    res += "<font size='+1' ><b>" + LOCALE(370, "Installing") +
           "</b></font><br/><br/>\n"
           "<h1>" + LOCALE(364, "Done!") + "</h1><br/>\n";

    if (no_of_patches == 1)
    {
      if (!successful_installs)
        res += "<p>" +
               LOCALE(371, "Failed to install the patch. See the log below for "
                         "details") + "</p>\n";
      else
        res += "<p>" + LOCALE(372 ,"Patch successfully installed. See the log below "
                                 "for details") + "</p>\n";
    }
    else
    {
      res += sprintf("<p>%d out of %d patches sucessfully installed. "
                     "See the log below for details.</p>\n",
                     successful_installs,
                     no_of_patches);
    }

    // Do we need to restart?
    if (flags->restart)
    {
      string pid = (string)getpid();
      res += "<blockquote><br />\n"
             + LOCALE(368, "The server needs to be restarted.") + #"
  <cf-perm perm='Restart'>
    " + LOCALE(369, "Would you like to do  that now?") + #"<br />
    <link-gbutton href='?what=restart&amp;action=restart.pike&amp;class=maintenance&amp;pid=" +
        pid + #"&amp;&usr.set-wiz-id;' type='restart'> " +
      LOCALE(197,"Restart") + #" </link-gbutton>
  </cf-perm>

  <cf-perm not perm='Restart'>
    <disabled-gbutton type='restart'> " +
      LOCALE(197,"Restart") + #" </disabled-gbutton>
  </cf-perm>
";
    }

    res += sprintf("<p><span id='log_img' class='icon %s'"
                   " onmouseover='this.style.cursor=\"pointer\"'"
                   " onclick='expand(\"log\")'>log</span>"
                   "<div style='%s' id='idlog'>%s</div></p>\n"
                   "<cf-ok-button href='?action=patcher.pike&amp;"
                   "class=maintenance&amp;&usr.set-wiz-id;' />",
                   successful_installs < no_of_patches ? "unfolded" : "folded",
                   successful_installs < no_of_patches ? "" : "display: none",
                   wb->get_all_messages());
    wb->clear_all();
    return Roxen.http_string_answer(res);
  }

 removepatch:
  if (config_perm("Update") &&
      id->real_variables["remove-patch-id"] &&
      sizeof(id->real_variables["remove-patch-id"])) {

    wb->clear_all();
    string patch_id = id->real_variables["remove-patch-id"][0];

    if (plib->remove_patch(patch_id, current_user)) {
      report_notice_for(0, "Patch manager: Removed %s from disk.\n", patch_id);
      break removepatch;
    }

    report_error_for(0, "Patch manager: Failed to remove %s from disk.\n", patch_id);

    res += "<p>" +
      LOCALE(414, "Failed to remove the patch. See the log below for "
             "details") +
      "</p>\n";

    res += sprintf("<p>"
                   "  <span id='log_img' class='icon unfolded'"
                   "        onmouseover='this.style.cursor=\"pointer\"'"
                   "        onclick='expand(\"log\")'>log</span>"
                   "  <div id='idlog'>%s</div>"
                   "</p>\n"
                   "<cf-ok-button href='?action=patcher.pike&amp;class=maintenance&amp;&usr.set-wiz-id;' />",
                   wb->get_all_messages());

    return Roxen.http_string_answer(res);
  }

  mapping patch_stats = get_patch_stats(plib);

  res += #"
    <cf-perm perm='Update'>
    <h3>" + LOCALE(415, "Import New Patches") + #"</h3>

    <p>" +
      LOCALE(416, "Fetch and import the latest patches from www.roxen.com") +
    ":</p>\n";
  if (Stdio.exist("VERSION.DIST")) {
    res += #"
      <submit-gbutton2 name='auto-import-button' type='import'>" +
      LOCALE(417, "Import from Roxen") +
      #"</submit-gbutton2>\n";
  } else {
    // Unknown distribution version.
    res += #"
      <disabled-gbutton name='auto-import-button' type='import'>" +
      LOCALE(417, "Import from Roxen") +
      #"</disabled-gbutton>\n";
  }
  res += #"
    <p>\n" + LOCALE(418,"Or manually select a local file to upload:") + #"</p>
        <input id='patchupload' type='file' name='file' size='40'/>
        <input type='hidden' name='fixedfilename' value='' />
        <submit-gbutton2 name='OK' type='upload'
      onclick=\"this.form.fixedfilename.value=this.form.file.value.replace(/\\\\/g,'\\\\\\\\')\">" + LOCALE(419, "Import file") + #"</submit-gbutton2>
    <p>"
    + LOCALE(420, "You can upload either a single rxp file or a tar/tar.gz/tgz "
             "file containing multiple rxp files.")
    + LOCALE(421, "There is also a <tt>bin/rxnpatch</tt> command-line tool to "
             "manage patches, if you prefer a terminal over a web interface.") +
   #"</p>
    <hr class='section'>
    </cf-perm>
    <h3>" + LOCALE(375, "Imported Patches") + " (" + patch_stats->imported_count + ")" + #"</h3>
    <p>" +
    LOCALE(376, "These are patches that are not currently installed; "
                "they are imported but not applied. They can be found in "
           "local/patches/.") +
   "</p>\n    <p>" +
    LOCALE(377, "Click on a patch for more information.") +
  #"</p>

      <table class='patch-list'>
        <thead>
          <tr>
            <th style='width:20px;text-align:left'>
              <cf-perm perm='Update'>
              <input type='checkbox'
                     name='install'
                     id='install_all'
                     onclick='check_all(\"install\")'/>
              </cf-perm>
            </th>
            <th style='width:20px'>&nbsp;</th>
            <th style='width:11em; text-align:left;'>Id</th>
            <th style='width: auto; text-align:left'>Patch Name</th>
            <th style='width: 70px;text-align:right'></th>
          </tr>
        </thead>
        <tbody>
";
  res += list_patches(id, plib, "imported");
  res += #"
      </tbody>
      </table>


    <hr class='section'>

    <h3>" + LOCALE(378, "Installed Patches") + " (" + patch_stats->installed_count + ")" + #"</h3>
    <p>" +
    LOCALE(379, "Click on a Patch for more information.") +
  #"</p>
    <input type='hidden' name='action' value='&form.action;'/>

    <table class='patch-list'>
      <thead>
        <tr>
          <th style='width:20px; text-align:left'>
            <cf-perm perm='Update'>
            <input type='checkbox'
                   name='uninstall'
                   id='uninstall_all'
                   onclick='check_all(\"uninstall\")'/>
            </cf-perm>
          </th>
          <th style='width:20px'>&nbsp;</th>
          <th style='width:11em; text-align:left;'>Id</th>
          <th style='width:auto; text-align:left'>Patch Name</th>
          <th style='width:14em; text-align:left'>Time of Installation</th>
        </tr>
      </thead>
      <tbody>
";
  res += list_patches(id, plib, "installed");
  res += #"
      </tbody>
    </table>

    <br clear='all' />
    <br />
    <cf-ok-button href='?class=maintenance&amp;&usr.set-wiz-id;' />
";
  res += #"
    <script type='text/javascript'>
      // <![CDATA[
      function check_all(name)
      {
        var i;
        var reference = document.getElementById(name + '_all');
        var elements = document.getElementsByName(name);
        var found = false;
        for (i = 0; i < elements.length; i++)
        {
          if (elements[i].value == 'on') continue;

          // Default to the value from the 'all'-checkbox.
          elements[i].checked = reference.checked;
          if (name == 'install')
          {
            // FIXME: Why call it so many times?
            toggle_install();
          }
          else if (name == 'uninstall')
          {
            if (found)
            {
              // Disable unchecked uninstall checkboxes
              // after the first unchecked one.
              elements[i].disabled = !elements[i].checked;
            }
            else
            {
              // Found the first non-magic uninstall checkbox.
              found = true;
              elements[i].disabled = false;
            }
          }
        }
      }

      function toggle_install()
      {
        var allElements = document.getElementsByName('install');
        for (var i = 0; i < allElements.length; i++)
        {
          allElements[i].disabled = false;
          toggle_dep_install(allElements[i]);
        }
      }

      function toggle_uninstall(id)
      {
        var toggleAllElement = document.getElementById('uninstall_all');
        var currentElement = document.getElementById(id);
        var allElements = document.getElementsByName('uninstall');
        var currentNo = 0;
        for (var i = 0; i < allElements.length; i++)
        {
          if (currentNo && i > (currentNo + 1))
          {
            allElements[i].checked = false;
            allElements[i].disabled = true;
          }
          else if (allElements[i].id == id)
          {
            currentNo = i;

            if ((i+1) < allElements.length)
            {
              // There are some checkboxes left to check.
              toggleAllElement.checked = false;

              // Make the next one available.
              allElements[i+1].checked = false;
              allElements[i+1].disabled = !currentElement.checked;
            }
            else
            {
              // Checked the last checkbox ==> All are checked.
              toggleAllElement.checked = currentElement.checked;
            }
          }
        }
      }

      function toggle_dep_install(checkBox)
      {
        var deps = checkBox.getAttribute('dependencies');
        if (deps && deps.length > 0)
        {
          var deps_ok = true;
          deps = deps.split(', ');
          for (var i = 0; i < deps.length; i++)
          {
            deps_ok = false;
            var alts = deps[i].split('|');
            for (var j = 0; j < alts.length; j++) {
              var alt = alts[j];
              var dep_element = document.getElementById(alt);
              if (dep_element && (dep_element.name == 'uninstall' ||
                                  dep_element.checked == true)) {
                // One of the dependencies in the set is satisfied.
                deps_ok = true;
                break;
              }
            }
            if (!deps_ok) {
              // One of the dependencies is not satisfied.
              break;
            }
          }
          checkBox.disabled = !deps_ok;
          if (checkBox.disabled) {
            checkBox.checked = false;
          }
        }
        else
          checkBox.disabled = false;
      }

      (function()
       {
         toggle_install();
         check_all('uninstall');
       })();
      // ]]>
    </script>";
  return res;
}

// Non-caching version of Process.search_path()
string search_path(string command) {
  array(string) search_path_entries=0;
  if (command=="" || command[0]=='/') return command;

  if (!search_path_entries) {
#ifdef __NT__
    array(string) e=replace(getenv("PATH")||"", "\\", "/")/";"-({""});
#elif defined(__amigaos__)
    array(string) e=(getenv("PATH")||"")/";"-({""});
#else
    array(string) e=(getenv("PATH")||"")/":"-({""});
#endif

    multiset(string) filter=(<>);
    search_path_entries=({});
    foreach (e,string s) {
      string t;
      if (s[0]=='~') {  // some shells allow ~-expansion in PATH
        if (s[0..1]=="~/" && (t=[string]getenv("HOME")))
          s=t+s[1..];
        else {
          // expand user?
        }
      }

      if (!filter[s] /* && directory exist */ ) {
        search_path_entries+=({s});
        filter[s]=1;
      }
    }
  }

  foreach (search_path_entries, string path) {
    string p=combine_path(path,command);
    Stdio.Stat s=file_stat(p);
    if (s && s->mode&0111) return p;
  }

  return 0;
}
