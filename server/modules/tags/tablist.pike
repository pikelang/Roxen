/*
 * $Id: tablist.pike,v 1.21 1999/11/11 07:39:54 mast Exp $
 *
 * Makes a tab list like the one in the config interface.
 *
 * $Author: mast $
 */

constant cvs_version="$Id: tablist.pike,v 1.21 1999/11/11 07:39:54 mast Exp $";
constant thread_safe=1;

#define use_contents_cache 0
#define use_gif_cache      1
#include <module.h>
inherit "module";
inherit "roxenlib";

#if use_contents_cache  
mapping(string:string) contents_cache = ([]);
#endif

#if use_gif_cache  
mapping(string:string) gif_cache = ([]);
#endif

/*
 * Functions
 */

array register_module()
{
  return ( ({ MODULE_PARSER, "Tab list",
	      "Adds some tags for making a config interface "
	      "look-alike tab list.<br>\n"
	      "Usage:<br>\n"
	      "<ul><pre>&lt;tablist&gt;\n"
	      "&lt;tab href=\"/tab1/\"&gt;Some text&lt;/tab&gt;\n"
	      "&lt;tab href=\"/tab2/\"&gt;Some more text&lt;/tab&gt;\n"
	      "&lt;tab href=\"a/strange/place/\"&gt;Tab 3&lt;/tab&gt;\n"
	      "&lt;/tablist&gt;\n"
	      "</pre></ul>Attributes for the &lt;tab&gt; tag:<br>\n"
	      "<ul><table border=0>\n"
	      "<tr><td><b>selected</b></td><td>Whether the tab is selected "
	      "or not.</td></tr>\n"
	      "<tr><td><b>bgcolor</b></td><td>What color to use as "
	      "background (behind the tab). Defaults to white.</td></tr>\n"
	      "<tr><td><b>selcolor</b></td><td>What color to use as "
	      "background for selected tab. Defaults to white.</td></tr>\n"
	      "<tr><td><b>dimcolor</b></td><td>What color to use as "
	      "background for unselected tab. Defaults to grayish.</td></tr>\n"
	      "<tr><td><b>textcolor</b></td><td>What color to use as "
	      "text color. Defaults to black for selected tabs and white "
	      "otherwise.</td></tr>\n"
	      "<tr><td><b>alt</b></td><td>Alt-text for the image (default: "
	      "\"_/\" + text + \"\\_\").</td></tr>\n"
	      "<tr><td><b>border</b></td><td>Border for the image (default: "
	      "0).</td></tr>\n"
              "<tr><td><b>noxml</b></td><td>Images will not be terminated "
	      "with a slash if this attribute is provided.</td></tr>\n"
	      "</table></ul>\n"
              "<br>The bgcolor, selcolor, dimcolor, textcolor and noxml "
	      "attribute can also be given in the tablist tag as global "
	      "attributes. Using color arguments in a tab tag will overide "
	      "the global setting.", 0, 1 }));
}

void create()
{
}

string tag_tab(string t, mapping a, string contents, mapping d)
{
  if (a->help)
    return register_module()[2];

  //  Encode arguments in string
  mapping args = ([
    "sel" : a->selected,
    "bg"  : parse_color(a->bgcolor || d->bgcolor || "white"),
    "fg"  : parse_color(a->selcolor || d->selcolor || "white"),
    "dim" : parse_color(a->dimcolor || d->dimcolor || "#003366"),
    "txt" : parse_color(a->textcolor || d->textcolor ||
			(a->selected ? "black" : "white"))
  ]);
  string dir = (MIME.encode_base64(encode_value(args)) - "\r" - "\n") + "|";
  m_delete(a, "selected");
  
  //  Create <img> tag
  mapping img_attrs = ([ ]);
  img_attrs->src = query_internal_location() + dir +
    replace(http_encode_string(contents), "?", "%3f") + ".gif";
  
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
  
  if (!a->noxml && !d->noxml)
    img_attrs["/"]="/";
  m_delete(a, "noxml");
  
  return make_container("a", a, make_container("b", ([]),
					       make_tag("img", img_attrs)));
}


int my_hash(mixed o)
{
  switch(sprintf("%t",o))
  {
    case "string": return hash(o);
    case "int": return o;
    case "mapping":
      int h = 17 + sizeof(o);
      foreach(indices(o), mixed index)
         h += hash(index) * my_hash(o[index]);
      return h;

   case "array":
    return hash(sprintf("%O",o));
   default:
     return hash(encode_value(o));
  }
}


string tag_tablist(string t, mapping a, string contents)
{
#if use_contents_cache
  object md5 = Crypto.md5();
  md5->update(contents+my_hash(a));
  string key=md5->digest();
  if(contents_cache[key])
    return contents_cache[key];
#endif
  string res=replace(parse_html(contents, ([]), (["tab":tag_tab]), a),
		 ({ "\n", "\r" }), ({ "", "" }));
#if use_contents_cache  
  contents_cache[key]=res;
#endif  
  return res;
}


mapping query_tag_callers()
{
  return ([]);
}


mapping query_container_callers()
{
  return ([ "tablist":tag_tablist ]);
}


Image.image load_image(string f)
{
  string data;
  
  if (!(data = Stdio.read_bytes("roxen-images/" + f))) {
    werror("Tablist: Failed to open file: %s\n", f);
    return 0;
  }
  return Image.PNM.decode(data);
}

object mask_image = load_image("tab_mask.png");
object frame_image = load_image("tab_frame.png");
object button_font = resolve_font("haru 32");


Image.image draw_tab(object text, mapping args)
{
  //  Create image with proper background
  text = text->scale(0, frame_image->ysize());
  object i = Image.image(frame_image->xsize() * 2 + text->xsize(),
			 frame_image->ysize(),
			 args->sel ? args->fg : args->dim);
  
  //  Add outside corners
  i->paste_alpha_color(mask_image, args->bg);
  i->paste_alpha_color(mask_image->mirrorx(), args->bg,
		       i->xsize() - mask_image->xsize(), 0);
  
  //  Add tab frame. We compose the corners in a separate buffer where we
  //  draw the sides using a mult() operation to preserve antialiasing.
  object corner = i->copy(0, 0,
			  frame_image->xsize() - 1, frame_image->ysize() - 1);
  corner *= frame_image;
  i->paste(corner);
  i->paste(corner->mirrorx(), i->xsize() - corner->xsize(), 0);
  
  //  Add text which is drawn it twice if the color is bleak
  for (int loop = (`+(@args->txt) / 3 > 200 ? 2 : 1); loop; loop--)
    i->paste_alpha_color(text, args->txt, frame_image->xsize(), 0);
  
  //  Create line on top of tab, and also at bottom if not selected
  i->line(frame_image->xsize() - 1, 0, i->xsize() - frame_image->xsize(), 0,
	  0, 0, 0);
  if (!args->sel)
    i->line(0, i->ysize() - 1, i->xsize(), i->ysize() - 1, 0, 0, 0);
  
  return i;
}


mapping find_internal(string f, object id)
{
  string s;
  
#if use_gif_cache
  if(s = gif_cache[f]) {
    //  report_debug("Tablist: "+f+" found in cache.\n");
    return http_string_answer(s, "image/gif");
  }
#endif  

  array(string) arr = f / "|";
  if (sizeof(arr) > 1) {
    //  Remove extension
    if (arr[-1][sizeof(arr[-1]) - 4..] == ".gif") {
      arr[-1] = arr[-1][..sizeof(arr[-1]) - 5];
    }
    
    mapping args = decode_value(MIME.decode_base64(arr[0]));
    s = Image.GIF.encode(draw_tab(button_font->write(arr[1..] * "|"), args));
    
#if use_gif_cache
    if(!gif_cache[f])
      gif_cache[f] = s;
#endif  
    
    return http_string_answer(s, "image/gif");
  }
  return 0;
}
