/*
 * $Id: configtablist.pike,v 1.1 1997/08/22 23:16:03 grubba Exp $
 *
 * Makes a tab-list like the one in the config-interface.
 *
 * $Author: grubba $
 */

#include <module.h>
inherit "module";
inherit "roxenlib";

/*
 * Functions
 */

array register_module()
{
  return(({ MODULE_PARSER|MODULE_LOCATION, "Config tab-list", 
	      "Adds some tags for making a config-interface "
	      "look-alike tab-list.<br>\n", 0, 1 }));
}

void create()
{
  defvar("location", "/configtabs/", "Mountpoint", TYPE_LOCATION|VAR_MORE,
	 "The URL-prefix for the buttons.");
}

string tag_config_tab(string t, mapping a, string contents)
{
  string dir = "u/";
  mapping img_attrs = ([]);
  if (a->selected) {
    dir = "s/";
  }
  m_delete(a, "selected");

  img_attrs->src = QUERY(location) + dir + replace(contents,
						   ({ "\"", "\'", "%" }),
						   ({ "%22", "%27", "%25" }));
  if (a->alt) {
    img_attrs->alt = a->alt;
    m_delete(a, "alt");
  } else {
    img_attrs->alt = "_/" + html_encode_string(contents) + "\\_";
  }
  if (a->border) {
    img_attrs->border = a->border;
    m_delete(a, "border");
  } else {
    img_attrs->border="0";
  }
  return make_container("a", a, make_container("b", ([]),
					       make_tag("img", img_attrs)));
}

string tag_config_tablist(string t, mapping a, string contents)
{
  return(replace(parse_html(contents, ([]), (["tab":tag_config_tab])),
		 ({ "\n", "\r" }), ({ "", "" })));
}

mapping query_container_callers()
{
  return ([ "config_tablist":tag_config_tablist ]);
}

mapping find_file(string f, object id)
{
  array(string) arr = f/"/";
  if (sizeof(arr) > 1) {
    object interface = roxen->configuration_interface();
    object(Image.image) button;
    switch (arr[0]) {
    case "s":	/* Selected */
      button = interface->draw_selected_button(arr[1..]*"/",
					       interface->button_font);
      break;
    case "u":	/* Unselected */
      button = interface->draw_unselected_button(arr[1..]*"/",
						 interface->button_font);
      break;
    default:
      return 0;
    }
    return http_string_answer(button->togif(), "image/gif");
  }
  return 0;
}
