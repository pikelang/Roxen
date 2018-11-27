#include <roxen.h>

import RoxenPatch;

//<locale-token project="admin_tasks"> LOCALE </locale-token>
#define LOCALE(X,Y)  _STR_LOCALE("admin_tasks",X,Y)

constant action = "maintenance";

// constant long_flags = ([ "restart" : LOCALE(0, "Need to restart server") ]);

string name= LOCALE(326, "Patch management");
string doc = LOCALE(327, "Show information about the available patches and "
			 "their status.");

Write_back wb = class Write_back
                {
		  private array(mapping(string:string)) all_messages = ({ });

		  void write_mess(string s) 
		  { 
		    s = replace(s, ([ "<green>"  : "<b style='color: green'>",
				      "</green>" : "</b>" ]) );
		    all_messages += ({ (["message":s ]) }); 
		  }
		  
		  void write_error(string s) 
		  { 
		    all_messages += ({ 
		      ([ "error":"<b style='color: red'>" + s + "</b>" ]) 
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

mapping get_patch_stats(Patcher po) {
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

string list_patches(RequestID id, Patcher po, string which_list)
{
  string self_url = "?class=maintenance&action=patcher.pike";
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

  string table_bgcolor = "&usr.fade1;";
  if (list && sizeof(list))
  {
    foreach(list; int i; mapping item)
    {
      if (table_bgcolor == "&usr.content-bg;")
	table_bgcolor = "&usr.fade1;";
      else
	table_bgcolor = "&usr.content-bg;";

      string installed_date = "";
      if(which_list == "installed")
      {
	if (item->installed)
	{
	  installed_date = sprintf("        <td><date strftime='%%c'"
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
      foreach(po->get_dependencies(item->metadata->id) || ({ }); 
	      int i; 
	      string s)
      {
	if (i > 0)
	  deps += ", ";

	deps += s; 
      }

      // Make sure that only patches for the right platform and version are
      // installable
      int is_right_version = 1;
      int is_right_platform = 1;
      if (which_list == "imported" &&
	  item->metadata->version)
	is_right_version = !!sizeof(filter(item->metadata->version,
					   po->check_server_version));

      if (which_list == "imported" &&
	  item->metadata->platform)
	is_right_platform = !!sizeof(filter(item->metadata->platform,
					    po->check_platform));

      if (!(is_right_version &&
	    is_right_platform))
	deps += "not_installable";
      

      res += sprintf("      <tr style='background-color: %s' >\n"
		     "        <td class='folded' id='%s_img'"
		     " style='background-color: %[0]s' "
		     " onmouseover='this.style.cursor=\"pointer\"'"
		     " onclick='expand(\"%[1]s\")' />&nbsp;</td>\n"
		     "        <td onclick='expand(\"%[1]s\");'"
		     " onmouseover='this.style.cursor=\"pointer\"'>%s</td>\n"
		     "        <td onclick='expand(\"%[1]s\");'"
		     " onmouseover='this.style.cursor=\"pointer\"'>%s</td>\n"
		     "%s"
		     + (which_list == "imported" ? 
			"<td style='text-align:right'>"
			"<link-gbutton href='?action=patcher.pike&class=maintenance&remove-patch-id=%[2]s'>remove"
			"</link-gbutton>"
			"</td>"
			: "") + 
		     "        </td>"
		     "        <td style='width:20px;text-align:right'>\n"		     
		     "          <input type='checkbox' id='%[2]s'"
		     " name='%s' value='%[2]s' dependencies='%s'" +
		     " onclick='toggle_%[5]s(%s)' />"
		     "</td>\n"
		     "      </tr>\n",
		     table_bgcolor,
		     replace(item->metadata->id, "-", ""),
		     item->metadata->id,
		     Roxen.html_encode_string(item->metadata->name),
		     installed_date,
		     (which_list == "imported") ? "install" : "uninstall",		     
		     deps,
		     (which_list == "installed") ? 
		                         "\"" + item->metadata->id + "\"" : "");
	
      array md = ({ });
      if (which_list == "installed")
      {
	md += ({
	  ({ LOCALE(328, "Installed by:")	, item->user || "Unknown" }),
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
	  ({ LOCALE(329, "Installed:")	, date }),
	  ({ LOCALE(328, "Installed by:")	, item->user || LOCALE(330, "Unknown") }),
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
	  ({ LOCALE(331, "Uninstalled:")	 , date }),
	  ({ LOCALE(332, "Uninstalled by:") , 
	     item->uninstall_user || LOCALE(330, "Unknown") }),
	});
      }

      md += ({
        ({ LOCALE(333, "Description:")	, 
	   Roxen.html_encode_string(item->metadata->description) }),
	({ LOCALE(334, "Originator:")	, item->metadata->originator  }) 
      });
      

      string active_flags = "        <table class='module-sub-list-2'"
			    " width='50%' cellspacing='0' cellpadding='0'>\n";
      foreach(known_flags; string index; string long_reading)
      {
	active_flags += sprintf("          <tr><td>%s</td>"
				"<td>&nbsp;</td>"
				"<td style='width: 100%%'>%s</td></tr>\n",
				replace(long_reading, " ", "&nbsp;") + ":",
				(item->metadata->flags && 
				 item->metadata->flags[index]) ?
				"<b style='color: green'>" + 
				LOCALE(335, "Yes") + "</b>" : 
				"<b>" + LOCALE(336, "No") + "</b>");
      }
      md += ({ ({ LOCALE(337, "Flags:"), active_flags + "        </table>\n"}) });
 
      if (!item->metadata->platform)
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
	     "<b style='color:red'>" + LOCALE(340, "Platform:") + "</b>", 
	     item->metadata->platform[0] })
	});
      }
      else
      {
	md += ({
	  ({ is_right_platform ? 
	     LOCALE(338, "Platforms:") :
	     "<b style='color:red'>" + LOCALE(338, "Platforms:") + "</b>", 
	     sprintf("%{%s<br />\n%}",
		     item->metadata->platform) })
	});
      }
      
      if (item->metadata->version)
      {
	md += ({
	  ({ is_right_version ? 
	     LOCALE(342, "Target version:"):
	     "<b style='color:red'>" + LOCALE(342, "Target version:") + "</b>", 
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
      
      if (item->metadata->depends)
      {
	string dep_list = "";
	foreach (item->metadata->depends, string dep_id)
	{
	  string dep_stat;
	  switch(po->patch_status(dep_id)->status)
	  {
	    case "installed":
	      dep_stat = LOCALE(344, "installed");
	      break;
	    case "uninstalled":
	    case "imported":
	      dep_stat = LOCALE(345, "imported");
	      break;
	    default:
	      dep_stat = "<b style='color:red'>" + LOCALE(346, "unavailable") + 
		         "</b>";
	      break;
	  }
	  dep_list += sprintf("%s (%s)<br />", dep_id, dep_stat);
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
      
      if (item->metadata->new && sizeof(item->metadata->new) == 1)
      {
	md += ({ 
	  ({ LOCALE(349, "New file:"), sprintf("%s", 
				  item->metadata->new[0]->destination) }) 
	});
      }
      else if (item->metadata->new)
      {
	md += ({ 
	  ({ LOCALE(350, "New files:"), sprintf("%{%s<br />\n%}", 
				   item->metadata->new->destination) })
	});
      }
      
      if (item->metadata->replace && sizeof(item->metadata->replace) == 1)
      {
	md += ({ 
	  ({ LOCALE(351, "Replaced file:"),  
	     sprintf("%s", item->metadata->replace[0]->destination) })
	});
      }
      else if (item->metadata->replace)
      {
	md += ({ 
	  ({ LOCALE(352, "Replaced files:"), 
	     sprintf("%{%s<br />\n%}", item->metadata->replace->destination) })
	});
      }
      
      if (item->metadata->delete && sizeof(item->metadata->delete) == 1)
      {
	md += ({ 
	  ({ LOCALE(353, "Deleted file:"), 
	     sprintf("%s", item->metadata->delete[0]) })
	});
      }
      else if (item->metadata->delete)
      {
	md += ({
	  ({ LOCALE(354, "Deleted files:"), 
	     sprintf("%{%s<br />\n%}", item->metadata->delete) })
	});
      }

      if (item->metadata->patch)
      {
	string patch_data = "";
	string patch_path = "";
	if (which_list == "imported")
	  patch_path = combine_path(po->get_import_dir(),
				    item->metadata->id);
	else
	  patch_path = combine_path(po->get_installed_dir(),
				    item->metadata->id);
	foreach(item->metadata->patch, string patch_file)
	{
	  patch_data += Stdio.read_file(combine_path(patch_path,
						     patch_file));
	}
	
	array(string) patched_files_list = po->lsdiff(patch_data);
	if (sizeof(patched_files_list) == 1)
	{
	  md += ({
	    ({ LOCALE(355, "Patched file:"),
	       sprintf("%s\n", patched_files_list[0]) })
	  });
	}
	else
	{
	  md += ({
	    ({ LOCALE(356, "Patched files:"),
	       sprintf("%{%s<br />\n%}", patched_files_list) })
	  });
	  }
      }      

      res += sprintf("      <tr id='id%s' bgcolor='%s' "
		     " style='display: none'>\n"
		     "        <td>&nbsp;</td>\n"
		     "        <td colspan='%d'>\n"
 		     "          <table class='module-sub-list'"
  		     " cellspacing='0' cellpadding='3' border='0'>\n"
  		     "%{            <tr valign='top'>\n"
  		     "              <th align='right'>%s</th>\n"
  		     "              <td>\n%s</td>\n"
  		     "            </tr>\n%}"
  		     "          </table>\n"
		     "          <td>\n"
		     "        </td>\n"
		     "      </tr>\n",
		     replace(item->metadata->id, "-", ""),
		     table_bgcolor,
		     colspan - 2,
 		     md);      
    }
  }
  else
  {
    res += sprintf("      <tr bgcolor='&usr.content-bg;'>\n"
		   "        <td colspan='%d'" 
		   " style='text-align:center;font-style:italic'>\n"
		   "          " + LOCALE(357, "No patches found") + "\n"
		   "        </td>\n"
		   "      </tr>\n",
		   colspan);
  }
  
  res += sprintf("      <tr>\n"
		 "        <td bgcolor='&usr.fade2;' colspan='%d'"
		 " align='right'>\n"
		 "          <submit-gbutton2"
		 " name='%s-button'>%s</submit-gbutton2>\n"
		 "        </td>\n"
		 "      </tr>\n",
		 colspan,
		 (which_list == "installed") ? "uninstall" : "install",
		 (which_list == "installed") ? LOCALE(358, "Uninstall selected patches") : 
		                               LOCALE(359, "Install selected patches"));

  return res; //+ sprintf("<td>&nbsp;</td>"
// 		       "<td>&nbsp;</td>"
// 		       "<td><pre>%O</pre></td>"
// 		       "<td>&nbsp;</td>"
// 		       "<td>&nbsp;</td>",
// 		       getenv("ROXEN_SERVER_DIR"));
}

mixed parse(RequestID id)
{
  string current_user = sprintf("%s (%s)", 
				RXML.get_var("user-name", "usr"),
				RXML.get_var("user-uid", "usr"));

  // Init patch-object
  wb->clear_all();
  Patcher plib = Patcher(wb->write_mess,
  			 wb->write_error,
  			 getcwd(),
			 getenv("LOCALDIR"));
			 
  string res = #"
    <style type='text/css'>
      td.folded {
        width:      20px;
        height:     20px;
        background: url('&usr.unfold;') 50% 50% no-repeat;
      }

      td.unfolded {
        width:      20px;
        height:     20px;
        background: url('&usr.fold;') 50% 50% no-repeat;
      }

      span.folded {
        width:        20px;
        height:       20px;
        padding-left: 20px;    
        background:   url('&usr.unfold;') top left no-repeat;
      }

      span.unfolded {
        width:        20px;
        height:       20px;
        padding-left: 20px;    
        background:   url('&usr.fold;') top left no-repeat;
      }

      div#idlog {
        font-size:  smaller;
        background: &usr.obox-bodybg;;
        border:     2px solid &usr.obox-border;;        
      }

      input#patchupload {
        background: #f8f8f8;;
        border:	    1px solid #ddd;
        padding:    5px;
        margin:     0 4px 0 0;
      }
    </style>
    <script type='text/javascript'>
      // <![CDATA[
      function expand(element)
      {
        var blockToToggle = document.getElementById('id' + element);
        var pictureToToggle = document.getElementById(element + '_img');

        if (blockToToggle.style.display == 'none')
        {
          blockToToggle.style.display = '';
          pictureToToggle.className = 'unfolded';
        }
        else
        {
          blockToToggle.style.display = 'none';
          pictureToToggle.className = 'folded';
        }
      }
      // ]]> 
    </script>";

  array(string) mbins = get_missing_binaries();
  if (sizeof(mbins)) {
    res += "<font size='+1' style='color: #d22;' ><b>" + LOCALE(0, "Warning: Missing tools") + "</b></font><br/><br/>";
    res += "Roxen can't find one or more tools required for the patch management to work properly.<br/>";
    res += "Before importing or installing any patches, please make sure you have the following executable(s) available on your system:<br/>";

    res += "<ul>";
    foreach (mbins, string a) res += "<li>" + a + "</li>";
    res += "</ul>";
    res += "<br/>";
  }

  if (id->real_variables["OK.x"] &&
      id->real_variables["fixedfilename"] &&
      sizeof(id->real_variables["fixedfilename"][0]) &&
      id->real_variables["file"] &&
      sizeof(id->real_variables["file"][0])) 
  {
    //  With Windows browsers the submitted filename may contain a full path
    //  with drive letter etc. When the Patcher processes it later it will
    //  convert slashes etc, but for our file to be accessible in that layer
    //  we must perform the same cleanup in the naming of our temp file.
    string patch_name =
      basename(RoxenPatch.unixify_path(id->real_variables["fixedfilename"][0]));
    string temp_dir =
      Stdio.append_path(plib->get_temp_dir(), patch_name);

    // Extra directory level to get rid of the sticky bit normally
    // present on /tmp/ that would require Privs for clean_up to work.
    mkdir(temp_dir);
    string temp_file = Stdio.append_path(temp_dir, patch_name);

    plib->write_file_to_disk(temp_file, id->real_variables["file"][0]);
    array(int|string) patch_ids = plib->import_file(temp_file);
    plib->clean_up(temp_dir);

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
		       "  <b style='color: red'>"
		       + LOCALE(0, "The patch import failed:") + 
		       "  </b>"
		       "</p>");	
      } else {
	res += sprintf("<p>"
		       "  <b style='color: red'>"
		       + LOCALE(0, "All patches were not imported:") +
		       "  </b>"
		       "</p>");
      }

    } else {
      res += sprintf("<p>"
		     "  <b style='color: green'>"
		     + LOCALE(0, "Patch import done.") +
		     "  </b>"
		     "</p>");
    }

    res += sprintf("<p><span id='log_img' class='%s'"
		   " onmouseover='this.style.cursor=\"pointer\"'"
		   " onclick='expand(\"log\")'>log</span>"
		   "<div style='%s' id='idlog'>%s</div></p>\n"
		   "<br clear='all' /><br />\n"
		   "<cf-ok-button href='?action=patcher.pike&"
		   "class=maintenance' />",
		   failed_patches ? "unfolded" : "folded",
		   failed_patches ? "" : "display: none",
		   wb->get_all_messages());
    wb->clear_all();
    return res;
  }
  
  if (id->real_variables["uninstall-button.x"] &&
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
    <gbutton href='?what=restart&action=restart.pike&class=maintenance&pid=" +
	pid + #"' width=250 icon_src=&usr.err-2;> " + LOCALE(197,"Restart") +
#" </gbutton>
  </cf-perm>

  <cf-perm not perm='Restart'>
    <gbutton dim width=250 icon_src=&usr.err-2;> " + LOCALE(197,"Restart") + 
#" </gbutton>
  </cf-perm>";
    }

    res += sprintf("<p><span id='log_img' class='%s'"
		   " onmouseover='this.style.cursor=\"pointer\"'"
		   " onclick='expand(\"log\")'>log</span>"
		   "<div style='%s' id='idlog'>%s</div></p>\n"
		   "<cf-ok-button href='?action=patcher.pike&"
		   "class=maintenance' />",
		   successful_uninstalls < no_of_patches ? "unfolded" : 
		   "folded",
		   successful_uninstalls < no_of_patches ? "" : "display: none",
		   wb->get_all_messages());
    wb->clear_all();
    return Roxen.http_string_answer(res);
  }
 
  if (id->real_variables["install-button.x"] &&
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
	if ( plib->install_patch(patch, current_user) )
	{
	  report_notice_for(0, "Patch manager: Installed %s.\n", patch);
	  successful_installs++;
	}
	else
	  report_error_for(0, "Patch manager: Failed to install %s.\n", patch);
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
    <gbutton href='?what=restart&action=restart.pike&class=maintenance&pid=" +
	pid + #"' width=250 icon_src=&usr.err-2;> " +
      LOCALE(197,"Restart") + #" </gbutton>
  </cf-perm>

  <cf-perm not perm='Restart'>
    <gbutton dim width=250 icon_src=&usr.err-2;> " +
      LOCALE(197,"Restart") + #" </gbutton>
  </cf-perm>
";
    }

    res += sprintf("<p><span id='log_img' class='%s'"
		   " onmouseover='this.style.cursor=\"pointer\"'"
		   " onclick='expand(\"log\")'>log</span>"
		   "<div style='%s' id='idlog'>%s</div></p>\n"
		   "<cf-ok-button href='?action=patcher.pike&"
		   "class=maintenance' />",
		   successful_installs < no_of_patches ? "unfolded" : "folded",
		   successful_installs < no_of_patches ? "" : "display: none",
		   wb->get_all_messages());
    wb->clear_all();
    return Roxen.http_string_answer(res);
  }
  
 removepatch:
  if (id->real_variables["remove-patch-id"] &&
      sizeof(id->real_variables["remove-patch-id"])) { 

    wb->clear_all();
    string patch_id = id->real_variables["remove-patch-id"][0];

    if (plib->remove_patch(patch_id, current_user)) {
      report_notice_for(0, "Patch manager: Removed %s from disk.\n", patch_id);
      break removepatch;
    } 

    report_error_for(0, "Patch manager: Failed to remove %s from disk.\n", patch_id);

    res += "<p>" +
      LOCALE(0, "Failed to remove the patch. See the log below for "
	     "details") + 
      "</p>\n";

    res += sprintf("<p>"
		   "  <span id='log_img' class='unfolded'"
		   "        onmouseover='this.style.cursor=\"pointer\"'"
		   "        onclick='expand(\"log\")'>log</span>"
		   "  <div id='idlog'>%s</div>"
		   "</p>\n"
		   "<cf-ok-button href='?action=patcher.pike&class=maintenance' />",
		   wb->get_all_messages());

    return Roxen.http_string_answer(res);
  }

  mapping patch_stats = get_patch_stats(plib);

  res += #" 
    <font size='+1'><b>" + LOCALE(0, "Import New Patches") + #"</b></font>
    <p>\n" + LOCALE(374,"Select local file to upload:") + #"</p>
        <input id='patchupload' type='file' name='file' size='40'/>
        <input type='hidden' name='fixedfilename' value='' />
        <submit-gbutton2 name='OK' width='75' align='center'
      onclick=\"this.form.fixedfilename.value=this.form.file.value.replace(/\\\\/g,'\\\\\\\\')\">" + LOCALE(404, "Import") + #"</submit-gbutton2>
    <p>" 
    + LOCALE(0, "You can upload either a single rxp file or tar/tar.gz/tgz "
	     " files containing multiple rxp files.")
    + LOCALE(0, "There is also an bin/rxnpatch command-line tool to "
	     "manage patches, if you prefer a terminal over a web interface.") +
   #"</p>
    <br />
    <font size='+1'><b>" + LOCALE(375, "Imported Patches") + " (" + patch_stats->imported_count + ")" + #"</b></font>
    <p>" +
    LOCALE(376, "These are patches that are not currently installed; "
		"they are imported but not applied. They can be found in "
	   "local/patches/.") +
   "</p>\n    <p>" +
    LOCALE(377, "Click on a patch for more information.") +
  #"</p>
    <box-frame width='100%' iwidth='100%' bodybg='&usr.content-bg;'
	       box-frame='yes' padding='0'>\n
      <table class='module-list' cellspacing='0' cellpadding='3' border='0' 
             width='100%' style='table-layout: fixed'>
	<tr bgcolor='&usr.obox-titlebg;' >
          <th style='width:20px'>&nbsp;</th>
	  <th style='width:12em; text-align:left;'>Id</th>
	  <th style='width: auto; text-align:left'>Patch Name</th>
          <th style='width: 70px;text-align:right'></th>
	  <th style='width:20px;text-align:right'>
            <input type='checkbox' 
                   name='install'
                   id='install_all'
                   onclick='check_all(\"install\")'/>
          </th>
	</tr>
";
  res += list_patches(id, plib, "imported");
  res += #"
      </table>
    </box-frame>

    <br clear='all' />
    <br />

    <font size='+1'><b>" + LOCALE(378, "Installed Patches") + " (" + patch_stats->installed_count + ")" + #"</b></font>
    <p>" +
    LOCALE(379, "Click on a Patch for more information.") +
  #"</p>
    <input type='hidden' name='action' value='&form.action;'/>
    <box-frame width='100%' iwidth='100%' bodybg='&usr.contentbg;'
	       box-frame='yes' padding='0'>
      <table class='module-list' cellspacing='0' cellpadding='3' border='0' 
             width='100%' style='table-layout: fixed'>\n
	<tr bgcolor='&usr.obox-titlebg;' >
          <th style='width:20px'>&nbsp;</th>
	  <th style='width:12em; text-align:left;'>Id</th>
	  <th style='width:auto; text-align:left'>Patch Name</th>
	  <th style='width:16em; text-align:left'>Time of Installation</th>
	  <th style='width:20px; text-align:right'>
            <input type='checkbox'
                   name='uninstall'
                   id='uninstall_all'
                   onclick='check_all(\"uninstall\")'/>
          </th>
	</tr>
";
  res += list_patches(id, plib, "installed");
  res += #"      
      </table>
    </box-frame>

    <br clear='all' />
    <br />
    <cf-ok-button href='?class=maintenance' />
";
  res += #"
    <script type='text/javascript'>
      // <![CDATA[
      function check_all(name)
      {
        var i;
        var reference = document.getElementById(name + '_all');
        var elements = document.getElementsByName(name)
        for (i = 0; i < elements.length; i++)
        {
	  elements[i].checked = reference.checked;
	  if (name == 'install')
	  {
	    toggle_install();
	  }
	  else if (name == 'uninstall' && i > 1)
	  {
	    elements[i].disabled = !elements[i].checked;
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
	      allElements[0].checked = false;
	      allElements[i+1].checked = false;
	      allElements[i+1].disabled = !currentElement.checked;
	    }
	    else
	    {
	      allElements[0].checked = currentElement.checked;
	    }
	  }
	}
      }

      function toggle_dep_install(checkBox)
      {
	var deps = checkBox.getAttribute('dependencies');
        if (deps && deps.length > 0)
        { 
	  deps = deps.split(', ');
          for (var i = 0; i < deps.length; i++)
          {
            var dep_element = document.getElementById(deps[i]);
            if (!dep_element || (dep_element &&
				 !(dep_element.name == 'uninstall' ||
				   dep_element.checked == true)))
            {
              checkBox.checked  = false;
              checkBox.disabled = true;
            }
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
    if (s
#ifndef __NT__
	// Some versions of NT don't set the x-bit on all files...
	&& (s->mode & 0111)
#endif
	)
      return p;
  }

  return 0;
}
