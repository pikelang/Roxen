/*
 * $Id: mk_wxs.pike,v 1.2 2004/11/09 17:47:26 grubba Exp $
 *
 * Make a Windows Installer XML Source file (wxs) suitable
 * for a Roxen installer.
 *
 * 2004-11-03 Henrik Grubbström
 */

import Standards.XML.Wix;

#include "../etc/include/version.h"

int main(int argc, array(string) argv)
{
  string base_guid = "e0eb949e-2d84-11d9-8482-77582478aab0"; // WebServer.
  string version_str = __roxen_version__+"."+__roxen_build__;
  string title = "Roxen Webserver";
  string manufacturer = "Roxen Internet Software";
  string pike_module = "Pike_module.msm";

  foreach(Getopt.find_all_options(argv, ({
    ({"--guid", Getopt.HAS_ARG, ({"-g", "--guid"})}),
    ({"--version", Getopt.MAY_HAVE_ARG, ({"-v", "--version"})}),
    ({"--title", Getopt.HAS_ARG, ({"-t", "--title", "--name"})}),
    ({"--manufacturer", Getopt.HAS_ARG, ({"-m", "--manufacturer"})}),
    ({"--pike-module", Getopt.HAS_ARG, ({"-p", "--pike", "--pike-module"})}),
  })), array(string) opt) {
    switch(opt[0]) {
    case "--guid":
      base_guid = Standards.UUID.UUID(opt[1])->str();
      break;
    case "--version":
      if (stringp(opt[1])) {
	version_str = opt[1];
      } else {
	werror("$Id: mk_wxs.pike,v 1.2 2004/11/09 17:47:26 grubba Exp $\n");
	exit(0);
      }
      break;
    case "--title":
      title = opt[1];
      break;
    case "--manufacturer":
      manufacturer = opt[1];
      break;
    case "--pike-module":
      pike_module = opt[1];
      break;
    }
  }

  argv = Getopt.get_args(argv);

  string version_guid =
    Standards.UUID.make_version3(base_guid, version_str)->str();
  Directory root = Directory("SourceDir",
			     Standards.UUID.UUID(version_guid)->encode(),
			     "TARGETDIR");
  string server_dir = "server-"+version_str;

  // First make sure we have a pike binary in the appropriate place.
  root->merge_module(server_dir+"/pike", pike_module, "Pike",
		     "PIKE_TARGETDIR");

  Parser.XML.Tree.SimpleTextNode line_feed =
    Parser.XML.Tree.SimpleTextNode("\n");

  WixNode feature_node =
    WixNode("Feature", ([
	      "ConfigurableDirectory":"TARGETDIR",
	      "Title":title,
	      "Level":"1",
	      "Id":"F_ROXEN",
	    ]))->
    add_child(line_feed)->
    add_child(WixNode("MergeRef", ([ "Id":"Pike" ])))->
    add_child(line_feed);

  // Then populate with the other modules.
  foreach(argv[1..]; int number; string module_name) {
    string id = "M_"+number;
    if (has_suffix(module_name, "_server.msm")) {
      root->merge_module(server_dir, module_name, id, "SERVERDIR");
    } else {
      root->merge_module(".", module_name, id, "ROXEN_ROOT");
    }
    feature_node->add_child(WixNode("MergeRef", ([ "Id":id ])))->
      add_child(line_feed);
  }

  // Generate the XML.
  Parser.XML.Tree.SimpleRootNode root_node = Parser.XML.Tree.SimpleRootNode()->
    add_child(Parser.XML.Tree.SimpleHeaderNode((["version": "1.0",
						 "encoding": "utf-8"])))->
    add_child(WixNode("Wix", (["xmlns":wix_ns]))->
	      add_child(line_feed)->
	      add_child(WixNode("Product", ([
				  "Manufacturer":manufacturer,
				  "Name":title,
				  "Language":"1033",
				  "UpgradeCode":base_guid,
				  "Id":version_guid,
				  "Version":version_str,
				]))->
			add_child(line_feed)->
			add_child(WixNode("Package", ([
					    "Manufacturer":manufacturer,
					    "Languages":"1033",
					    "Compressed":"yes",
					    "InstallerVersion":"200",
					    "Platforms":"Intel",
					    "SummaryCodepage":"1252",
					    "Id":version_guid,
					  ])))->
			add_child(line_feed)->
			add_child(WixNode("Media", ([
					    "Cabinet":"Roxen.cab",
					    "EmbedCab":"yes",
					    "Id":"1",
					  ])))->
			add_child(line_feed)->
			add_child(root->gen_xml())->
			add_child(line_feed)->
			add_child(feature_node)->
			add_child(line_feed)->
			add_child(WixNode("FragmentRef", ([
					    "Id":"RoxenUI",
					  ])))))->
    add_child(line_feed);

  write(root_node->render_xml());
}
