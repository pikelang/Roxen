/* The Atlas module. Copyright © 1999 - 2000, Roxen IS.
 *
 * Please note: The map is incomplete and incorrect in details.  Countries
 * and territories are missing.
 */

constant thread_safe = 1;
constant cvs_version = "$Id: atlas.pike,v 1.6 2000/09/10 13:53:43 nilsson Exp $";

#include <module.h>

inherit "module";

constant module_type = MODULE_PARSER | MODULE_EXPERIMENTAL;
constant module_name = "Atlas";
constant module_doc  = 
#"Provides the <tt>&lt;atlas&gt;</tt> tag that creates a world map. It is
possible to highlight countries on the generated world map.";

roxen.ImageCache the_cache;

void start() {
  the_cache = roxen.ImageCache( "atlas", generate_image );
}

mapping find_internal( string f, RequestID id ) {
  return the_cache->http_file_answer( f, id );
}


// ---------------------- Tags ------------------------------

#ifdef OLD_RXML_COMPAT
inherit "roxenlib";

array(string) container_atlas_list_regions(string t, mapping arg, string contents,
				     RequestID id)
{
  return ({do_output_tag(arg, map(.Map.Earth()->regions(),
				  lambda(string c)
				  { return ([ "name":c ]); }),
			 contents, id)});
}

array(string) container_atlas_list_countries(string t, mapping arg, string contents,
				       RequestID id)
{
  return ({do_output_tag(arg, map(.Map.Earth()->countries(),
				  lambda(string c)
				  { return ([ "name":c ]); }),
			 contents, id)});
}
#endif

class TagEmitAtlas {
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "atlas";

  array get_dataset( mapping args, RequestID id ) {
    if (args->list=="countries")
      return map(.Map.Earth()->countries(),
		 lambda(string c) { return (["name":c]); });
    if (args->list=="regions")
      return map(.Map.Earth()->regions(),
		 lambda(string c) { return (["name":c]); });
    RXML.parse_error("No valid list argument given\n");
  }
}

string cont_atlas_country(string t, mapping arg, mapping state)
{
  string name;

  if(arg->domain)
    name = .Map.domain_to_country[lower_case(arg->domain)];
  else if(arg->name)
    name = .Map.aliases[lower_case(arg->name)] || arg->name;

  state->color[lower_case(name || "")] = parse_color(arg->color || "#e0c080");

  return "";
}

constant imgargs = ({ "width", "height", "alt", "src", "class", "border", "name" });

string container_atlas(string t, mapping args, string contents, RequestID id)
{
  // Construct a state which will be used
  // in order to draw the image later on.
  mapping state=([]);
  foreach( indices(args), string arg)
    if(!imgargs[arg]) {
      state[arg]=args[arg];
      m_delete(args, arg);
    }
  state->color=([]);

  // Parse internal tags.
  parse_html(contents,
	     ([ "atlas-country":cont_atlas_country ]),
	     ([]),
	     state);

  // Calculate size of image.  Preserve
  // image aspect ratio if possible.
  int w, h;
  if(args->width) {
    sscanf(args->width, "%d", w);
    h = (int)(w*3.0/5.0);
    sscanf(args->height||"", "%d", h);
  } else {
    sscanf(args->height||"300", "%d", h);
    w = (int)(h*5.0/3.0);
  }
  state->width = w;
  state->height = h;

  args->src = query_internal_location()+the_cache->store(state, id);
  return RXML.t_xml->format_tag("img", args);
}

mixed generate_image(mapping state, RequestID id)
{
  if(!state)
    return 0;

  mapping opt = ([]);
  if(state->bgcolor)
    opt->color_sea = parse_color(state->bgcolor);
  state->fgcolor = parse_color(state->fgcolor || "#ffffff");

  .Map.Earth m = .Map.Earth(([ "region":state->region ]));

  Image img = m->image(state->width, state->height,
		       ([ "color_fu":
			  lambda(string name, mapping state)
			  {
			    return state->color[name] || state->fgcolor;
			  },
			  "fu_args":({ state }) ]) + opt);

  // Kludge because the image package does not handle polygons
  // correctly (notice the funny pixels at the top of the map).
  img->line(0, 0, img->xsize(), 0, 0,0,0);

  return img;
}
