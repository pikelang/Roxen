//  Button module. Generates graphical buttons for use in Roxen config
//  interface, Roxen SiteBuilder and other places.
//
//  Copyright © 1999 Idonex AB. Author: Jonas Walldén, <jonasw@idonex.se>


//  Usage:
//
//  <gbutton
//     bgcolor         -- background color inside/outside button
//     bordercolor     -- button border color
//     textcolor       -- button text color
//     href            -- button URL
//     alt             -- alternative button alt text
//     border          -- image border
//     dim             -- when set button is disabled
//     condensed       -- when set button text is condensed to 80%
//     icon_src        -- icon reference
//     icon_data       -- inline icon data
//     align           -- left|center|right text alignment
//     align_icon      -- left|center_before|center_after|right icon alignment
//   >Button text</gbutton>
//
//  Alignment restriction: when text alignment is either left or right, icons
//  must also be aligned left or right.


constant cvs_version = "$Id: gbutton.pike,v 1.4 1999/11/15 16:42:40 per Exp $";
constant thread_safe = 1;

#include <module.h>
inherit "module";
inherit "roxenlib";


roxen.ImageCache  button_cache;
object button_font = resolve_font("haru 32");
object button_border;
object button_mask;


//  Distance between icon image and text
#define IMAGE_SPC  5


array register_module()
{
  return( ({ MODULE_PARSER,
	     "GButton",
	     "Provides the <tt>&lt;gbutton&gt;Title&lt;/gbutton&gt;</tt> "
	     "tag for drawing graphical buttons. Arguments:<p>"
	     "<table border=0>"

	     "<tr><td><b>bgcolor</b></td><td>Background color inside and "
	     "outside button</td></tr>"

	     "<tr><td><b>bordercolor</b></td><td>Button border color</td></tr>"

	     "<tr><td><b>textcolor</b></td><td>Button text color</td></tr>"

	     "<tr><td><b>href</b></td><td>Button URL</td></tr>"

	     "<tr><td><b>alt</b></td><td>Alternative button alt text</td></tr>"

	     "<tr><td><b>border</b></td><td>Image border</td></tr>"

	     "<tr><td><b>dim</b></td><td>Set to dim button</td></tr>"

	     "<tr><td><b>condensed</b></td><td>Set to condense text to "
	     "80%</td></tr>"

	     "<tr><td><b>icon_src</b></td><td>Icon reference</td></tr>"

	     "<tr><td><b>icon_data</b></td><td>Inline icon data</td></tr>"

	     "<tr><td><b>align</b></td><td>Text alignment: "
	     "<tt>left|center|right</tt></td></tr>"

	     "<tr><td><b>align_icon</b></td><td>Icon alignment: "
	     "<tt>left|center_before|center_after|right</tt></td></tr>"

	     "</table><p>"
	     "There are some alignment restrictions: when text alignment is "
	     "either <tt>left</tt> or <tt>right</tt>, icons must also be "
	     "aligned <tt>left</tt> or <tt>right</tt>.",
	     
	     0, 1 }) );
}


void start()
{
  button_cache = roxen.ImageCache("gbutton", draw_button);
}


mapping query_tag_callers()
{
  return ([ ]);
}


mapping query_container_callers()
{
  return ([ "gbutton" : tag_button, "gbutton-url" : tag_button ]);
}


object(Image.Image)|mapping draw_button(mapping args, string text, object id)
{
  Image.Image  text_img, b, tmp, button;
  int          req_width, b_width, b_height, t_width, i_width, icn_x, txt_x;
  mapping      icon;
  
  //  Colorize borders
  if (!args->dim)
    b = button_border->clone()->grey()->
            modify_by_intensity(1, 1, 1, args->bo, ({ 255, 255, 255 }) );
  else {
    array dim_bg = ({ 255, 255, 255 });
    array dim_bo = ({ 0, 0, 0 });
    for (int i = 0; i < 3; i++) {
      dim_bo[i] = (args->bo[i] + args->bg[i]) / 2;
      dim_bg[i] = (args->bg[i] + dim_bg[i]) / 2;
    }
    
    b = button_border->clone()->grey()->
            modify_by_intensity(1, 1, 1, dim_bo, dim_bg);
  }
  b_width = b->xsize();
  b_height = b->ysize();
  
  //  Get icon
  if (args->icn)
    icon = roxen.low_load_image(args->icn, id);
  else if (args->icd)
    icon = roxen.low_decode_image(args->icd);
  i_width = icon && (icon->img->xsize() + IMAGE_SPC);
  
  //  Generate text
  text_img = button_font->write(text)->scale(0, b_height - IMAGE_SPC);
  if (args->cnd)
    text_img = text_img->scale((int) round(text_img->xsize() * 0.8),
			       text_img->ysize());
  t_width = text_img->xsize();
  
  //  Compute text and icon placement
  req_width = t_width + b_width + i_width;
  if (args->wi && (req_width < args->wi))
    req_width = args->wi;
  switch (lower_case(args->al)) {
  case "left":
    //  Allow icon alignment: left, right
    switch (lower_case(args->ica)) {
    case "left":
      icn_x = b_width / 2;
      txt_x = icn_x + i_width;
      break;
    default:
    case "right":
      txt_x = b_width / 2;
      icn_x = req_width - b_width / 2 - i_width + IMAGE_SPC;
      break;
    }
    break;

  default:
  case "center":
  case "middle":
    //  Allow icon alignment: left, center, center_before, center_after, right
    switch (lower_case(args->ica)) {
    case "left":
      icn_x = b_width / 2;
      txt_x = icn_x + i_width +
	      (req_width - icn_x - i_width - b_width / 2 - t_width) / 2;
      break;
    default:
    case "center":
    case "center_before":
      icn_x = (req_width - i_width - t_width) / 2;
      txt_x = icn_x + i_width;
      break;
    case "center_after":
      txt_x = (req_width - i_width - t_width) / 2;
      icn_x = txt_x + t_width + IMAGE_SPC;
      break;
    case "right":
      icn_x = req_width - b_width / 2 - i_width + IMAGE_SPC;
      txt_x = b_width / 2 + (icn_x - IMAGE_SPC - b_width / 2 - t_width) / 2;
      break;
    }
    break;

  case "right":
    //  Allow icon alignment: left, right
    switch (lower_case(args->ica)) {
    default:
    case "left":
      icn_x = b_width / 2;
      txt_x = req_width - b_width / 2 - t_width;
      break;
    case "right":
      icn_x = req_width - b_width / 2 - i_width + IMAGE_SPC;
      txt_x = icn_x - IMAGE_SPC - t_width;
      break;
    }
    break;
  }
  button = Image.Image(req_width, b_height, args->bg);
  
  //  Paste left and right edge of border
  tmp = b->copy(0, 0, b_width / 2 - 1, b_height - 1);
  button->paste_mask(tmp, button_mask->copy(0, 0,
					    b_width / 2 - 1, b_height - 1));
  tmp = b->copy(b_width / 2, 0, b_width - 1, b_height - 1);
  button->paste_mask(tmp, button_mask->copy(b_width / 2, 0,
					    b_width - 1, b_height - 1),
		     req_width - b_width / 2, 0);
  
  //  Stretch top/bottom borders
  tmp = button->copy(b_width / 2 - 1, 0, b_width / 2 - 1, b_height - 1);
  for (int offset = b_width / 2; offset <= req_width - b_width / 2; offset++)
    button->paste(tmp, offset, 0);
  
  //  Draw icon
  if (icon) {
    int icn_y = (b_height - icon->img->ysize()) / 2;
    
    if (!icon->alpha)
      icon->alpha = icon->img->clone()->clear(Image.Color.white);
    if (args->dim)
      icon->alpha *= 0.3;
    button->paste_mask(icon->img, icon->alpha, icn_x, icn_y);
  }
  
  //  Draw text
  if (args->dim)
    for (int i = 0; i < 3; i++)
      args->txt[i] = (args->txt[i] + args->bg[i]) / 2;
  button->paste_alpha_color(text_img, args->txt, txt_x, 2);
  
  return button;
}


mapping find_internal(string f, RequestID id)
{
  //  Load images
  if (!button_border) {
    button_border = roxen.load_image("roxen-images/gbutton_border.gif", id);
    button_mask = roxen.load_image("roxen-images/gbutton_mask.gif", id);
  }

  return button_cache->http_file_answer(f, id);
}


string tag_button(string tag, mapping args, string contents, RequestID id)
{
  mapping new_args = ([
    "bo"  : parse_color(args->bordercolor || "#333333"), //  Border color
    "bg"  : parse_color(args->bgcolor || "#eeeeee"),     //  Background color
    "txt" : parse_color(args->textcolor || "#000000"),   //  Text color
    "cnd" : args->condensed,                             //  Condensed text
    "wi"  : (int) args->width,                           //  Min button width
    "al"  : args->align || "left",                       //  Text alignment
    "dim" : args->dim,                                   //  Button dimming
    "icn" : args->icon_src && fix_relative(args->icon_src, id),  // Icon URL
    "icd" : args->icon_data,                             //  Inline icon data
    "ica" : args->align_icon || "left"                   //  Icon alignment
  ]);
  
  new_args->quant = args->quant || 128;
  foreach(glob("*-*", indices(args)), string n)
    new_args[n] = args[n];

  string img_src =
    query_internal_location() +
    button_cache->store( ({ new_args, contents }), id);

  if( tag == "gbutton-url" )
    return img_src;

  mapping img_attrs = ([ "src"    : img_src,
			 "alt"    : args->alt || contents,
			 "border" : args->border,
			 "hspace" : args->hspace,
			 "vspace" : args->vspace ]);
  
  if (mapping size = button_cache->metadata(new_args, id, 1)) {
    //  Image in cache (1 above prevents generation on-the-fly, i.e.
    //  first image will lack sizes).
    img_attrs->width = size->xsize;
    img_attrs->height = size->ysize;
  }
  
  //  Make button clickable if not dimmed
  if (args->href && !args->dim)
    return make_container("a", ([ "href" : args->href ]),
			  make_tag("img", img_attrs));
  else
    return make_tag("img", img_attrs);
}
