// The Atlas module. Copyright © 1999 - 2000, Roxen IS.
//
// Please note: The map is incomplete and incorrect in details.  Countries
// and territories are missing.

#include <module.h>
inherit "module";

constant cvs_version = "$Id: atlas.pike,v 1.8 2000/11/26 17:24:36 nilsson Exp $";
constant thread_safe = 1;
constant module_type = MODULE_TAG | MODULE_EXPERIMENTAL;
constant module_name = "Atlas";
constant module_doc  = 
#"Provides the <tt>&lt;atlas&gt;</tt> tag that creates a world map. It is
possible to highlight countries on the generated world map.";

roxen.ImageCache the_cache;

void start() {
  the_cache = roxen.ImageCache( "atlas", generate_image );
}

string status() {
  array s=the_cache->status();
  return sprintf("<b>Images in cache:</b> %d images<br />\n<b>Cache size:</b> %s",
		 s[0]/2, Roxen.sizetostring(s[1]));
}

mapping(string:function) query_action_buttons() {
  return ([ "Clear cache":flush_cache ]);
}

void flush_cache() {
  the_cache->flush();
}

mapping find_internal( string f, RequestID id ) {
  return the_cache->http_file_answer( f, id );
}


// ---------------------- Tags ------------------------------

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

constant imgargs = ({ "region", "fgcolor", "bgcolor" });

class TagAtlas {
  inherit RXML.Tag;
  constant name = "atlas";

  class TagCountry {
    inherit RXML.Tag;
    constant name = "country";
    constant flags = RXML.FLAG_EMPTY_ELEMENT;

    class Frame {
      inherit RXML.Frame;

      array do_enter(RequestID id) {
	string name;

	if(args->domain)
	  name = .Map.domain_to_country[lower_case(args->domain)];
	else if(args->name)
	  name = .Map.aliases[lower_case(args->name)] || args->name;

	id->misc->atlas_state->color[lower_case(name || "")] =
	  parse_color(args->color || "#e0c080");
	return 0;
      }
    }
  }

  RXML.TagSet internal = RXML.TagSet("TagAtlas.internal",
				     ({ TagCountry() }) );

  class Frame {
    inherit RXML.Frame;
    RXML.TagSet additional_tags = internal;

    array do_enter(RequestID id) {
      // Construct a state which will be used
      // in order to draw the image later on.
      id->misc->atlas_state = ([ "color":([]) ]);
      foreach( imgargs, string arg)
	if(args[arg])
	  id->misc->atlas_state[arg]=m_delete(args, arg);
    }

    array do_return(RequestID id) {
      // Calculate size of image.  Preserve
      // image aspect ratio if possible.
      int w, h;
      mapping state = id->misc->atlas_state;
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

      args->src = query_internal_location() + the_cache->store(state, id);
      args->width = w;
      args->height = h;
      if(!args->alt)
	args->alt = state->region || "The World";
 
      result = RXML.t_xml->format_tag("img", args);
      return 0;
    }
  }
}

Image generate_image(mapping state, RequestID id)
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
  return img;
}

TAGDOCUMENTATION;
#ifdef manual
constant tagdoc=([
  "emit#atlas" : ({ "<desc plugin>Lists altas stuff.</desc>"
		    "<attr name='list' value='regions|countries'>Select what to list</attr>",
		    ([ "&_.name;":"The name of the region/country" ])
  }),
  "atlas" : ({ #"<desc cont>Draws a map</desc>
<attr name='region' value='name'>Which map to show. The value may be any of the 
listed region values that <emit source='list' value='regions'>&_.name;</emit> returns.</attr>
<attr name='width' value='number'>The width of the image</attr>
<attr name='height' value='number'>The height of the image</attr>
<attr name='fgcolor' value='color'>The color of the unselected land areas</attr>
<attr name='bgcolor' value='color'>The color of the sea.</attr>",
	       ([ "country" : #"<desc tag>A region that should be highlighted.</desc>
<attr name='domain' value='name'>The top domain of the country that should be highlighted.</attr>
<attr name='name' value='name'>The name of the country that should be highlighted.</attr>
<attr name='color' value='color'>The color that should be used for highlighting.</attr>" ])
  }),
]);
#endif
