/* The Atlas module.
 *
 * Please note: The map is incomplete and incorrect in details.  Countries
 * and territories are missing.
 */

constant thread_safe = 1;
constant cvs_version = "$Id: atlas.pike,v 1.1 1999/05/15 17:23:05 noring Exp $";

#include <module.h>

inherit "module";
inherit "roxenlib";

static private int loaded = 0;

static private string doc()
{
  return !loaded?"":replace(Stdio.read_bytes("modules/tags/doc/atlas") || "",
			    ({ "{", "}" }), ({ "&lt;", "&gt;" }));
}

array register_module()
{
  return ({ MODULE_PARSER | MODULE_EXPERIMENTAL,
	    "Atlas",
	    "Draws maps.<p>"
	    "See <tt>&lt;atlas help&gt;&lt;/atlas&gt;</tt> for "
	    "more information.\n<p>"+doc(),
	    0, 1
         });
}

mapping query_container_callers()
{
  return ([ "atlas":container_atlas,
	    "atlas-list-regions":container_list_regions,
	    "atlas-list-countries":container_list_countries
  ]);
}

void start(int|void val, object|void conf)
{
  loaded = 1;
}

/* Temporary cache. */

#define RANDOM() random(2*1024*1024*1024-1)

static private int cache_base = RANDOM();
static private mapping cache = ([]);
static private mapping cache_reverse = ([]);
static private mapping cache_meta = ([]);

/* Store the state and return a unique key.  If the
   same state has been stored before, use that key. */
static private string cache_set(mixed value)
{
  string x = encode_value(value);
  string key = cache_reverse[x];
  
  if(!key)
  {
    /* Heavy key.  We do not want anyone
       to guess someone else's map number. */
    key = sprintf("%08x%08x%08x.gif",
		  RANDOM(), cache_base + sizeof(cache), time(1));
  
    cache[key] = value;
    cache_reverse[x] = key;
  }
  
  return key;
}

static private mixed cache_get(string key)
{
  return cache[key];
}

/* Set meta data, i.e. the calculated image for example. */
static private void cache_set_meta(string key, mixed meta)
{
  cache_meta[key] = meta;
}

static private mixed cache_get_meta(string key)
{
  return cache_meta[key];
}

/* Tags. */

string container_list_regions(string t, mapping arg, string contents,
			      object id)
{
  return do_output_tag(arg, Array.map(.Map.Earth()->regions(),
				      lambda(string c)
				      { return ([ "name":c ]); }),
		       contents, id);
}

string container_list_countries(string t, mapping arg, string contents,
				object id)
{
  return do_output_tag(arg, Array.map(.Map.Earth()->countries(),
				      lambda(string c)
				      { return ([ "name":c ]); }),
		       contents, id);
}

string container_atlas_country(string t, mapping arg, mapping state)
{
  string name;

  if(arg->domain)
    name = .Map.domain_to_country[lower_case(arg->domain)];
  else if(arg->name)
    name = .Map.aliases[lower_case(arg->name)] || arg->name;
  
  state->color[lower_case(name || "")] = parse_color(arg->color || "#e0c080");
  
  return "";
}

string container_atlas(string t, mapping arg, string contents,
		       object id, object foo, mapping defines)
{
  if(arg->help)
  {
    return doc();
  }
  
  /* Construct a state which will be used
     in order to draw the image later on. */
  mapping state = ([ "arg":arg, "color":([]) ]);

  /* Parse internal tags. */
  parse_html(contents,
	     ([ "atlas-country":container_atlas_country ]),
	     ([]),
	     state);

  /* Calculate size of image.  Preserve
     image aspect ratio if possible. */
  int w, h;
  if(arg->width) {
    sscanf(arg->width, "%d", w);
    h = (int)(w*3.0/5.0);
    sscanf(arg->height||"", "%d", h);
  } else {
    sscanf(arg->height||"300", "%d", h);
    w = (int)(h*5.0/3.0);
  }
  state->width = w;
  state->height = h;

  return "<img border=0"
         " alt=" + (arg->alt || "\"\"") +
         " width=" + state->width +
         " height=" + state->height +
         " src=" + query_internal_location() + cache_set(state) + ">";
}

mapping find_internal(string filename, object id)
{
  string r = cache_get_meta(filename);

  if(!r)
  {
    mapping state = cache_get(filename);
    
    if(!state)
      return 0;
    
    mapping arg = state->arg;
    
    mapping opt = ([]);
    if(arg->bgcolor)
      opt->color_sea = parse_color(arg->bgcolor);
    state->fgcolor = parse_color(arg->fgcolor || "#ffffff");
    
    .Map.Earth m = .Map.Earth(([ "region":arg->region ]));
    
    Image img = m->image(state->width, state->height,
			 ([ "color_fu":
			    lambda(string name, mapping state)
			    {
			      return state->color[name] || state->fgcolor;
			    },
			    "fu_args":({ state }) ]) + opt);
    
    /* Kludge because the image package does not handle polygons
       correctly (notice the funny pixels at the top of the map). */
    img->line(0, 0, img->xsize(), 0, 0,0,0);
    
    r = Image.GIF.encode(img);
    cache_set_meta(filename, r);
  }
  
  return http_string_answer(r, "image/gif");
}
