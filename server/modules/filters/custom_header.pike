// This is a roxen module. Copyright © 1996 - 2009, Roxen IS.

constant cvs_version = "$Id$";
constant thread_safe = 1;

inherit "module";
#include <module.h>

constant module_type = MODULE_FILTER;
constant module_name = "Custom Headers";
constant module_doc  = "Adds custom headers.";
constant module_unique = 0;

void create()
{
  defvar("custom_headers", Variable.Mapping(([]), 0, "Custom Headers",
    "List of custom headers that will be added to pages matching the path "
    "glob."));
  getvar("custom_headers")->key_title = "NAME";
  getvar("custom_headers")->val_title = "VALUE";

  defvar("path_globs", Variable.StringList(({}), 0, "Path Globs",
    "<p>The custom headers will only be added to requests with paths matching "
    "at least one of these globs.</p>"
    "<p>If no glob pattern is specified, custom headers will be added to all "
    "requests.</p>"
    "<p><b>Glob pattern:</b> A question sign ('?') matches any character and "
    "an asterisk ('*') matches a string of arbitrary length. All other "
    "characters only match themselves."));
}

string status()
{
  string headers = "";
  foreach (query("custom_headers"); string name; string value) {
    headers += "[" + name + ":" + " " + value + "], ";
  }
  headers = headers[0..<2]; // Remove traling ", ". Works on empty string also.
  array(string) globs = query("path_globs");
  return "<b>Custom Headers:</b> " + headers + "<br>"
         "<b>Globs:</b> " + globs * ", ";
}

mapping|void filter(mapping res, RequestID id)
{
  array(string) globs = query("path_globs");
  if (!sizeof(globs) || glob(globs, id->not_query)) {
    foreach (query("custom_headers"); string name; string value) {
      id->add_response_header(name, value);
    }
  }
  return res;
}
