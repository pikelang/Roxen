//  Button module. Generates graphical buttons for use in Roxen config
//  interface, Roxen SiteBuilder and other places.
//
//  Copyright © 1999-2000 Idonex AB. Author: Jonas Walldén, <jonasw@idonex.se>


//  Usage:
//
//  <gbutton
//     bgcolor         -- background color inside/outside button
//     bordercolor     -- button border color
//     textcolor       -- button text color
//     href            -- button URL
//     alt             -- alternative button alt text
//     border          -- image border
//     state           -- enabled|disabled button state
//     textstyle       -- normal|consensed text
//     icon_src        -- icon reference
//     icon_data       -- inline icon data
//     align           -- left|center|right text alignment
//     align_icon      -- left|center_before|center_after|right icon alignment
//   >Button text</gbutton>
//
//  Alignment restriction: when text alignment is either left or right, icons
//  must also be aligned left or right.


constant cvs_version = "$Id: gbutton.pike,v 1.22 2000/02/08 22:40:56 per Exp $";
constant thread_safe = 1;

#include <module.h>
inherit "module";
inherit "roxenlib";


roxen.ImageCache  button_cache;


array register_module()
{
  return( ({ MODULE_PARSER,
	     "GButton",
	     "Provides the <tt>&lt;gbutton&gt;Title&lt;/gbutton&gt;</tt> "
	     "tag for drawing graphical buttons.",
	     0, 1 }) );
}


TAGDOCUMENTATION
#ifdef manual
constant tagdoc=(["gbutton":"","gbutton-url":""]);
/*
	     "<table border=0>"

	     "<tr><td><b>bgcolor</b></td><td>Background color inside and "
	     "outside button</td></tr>"

	     "<tr><td><b>bordercolor</b></td><td>Button border color</td></tr>"

	     "<tr><td><b>textcolor</b></td><td>Button text color</td></tr>"

	     "<tr><td><b>href</b></td><td>Button URL</td></tr>"

	     "<tr><td><b>alt</b></td><td>Alternative button alt text</td></tr>"

	     "<tr><td><b>border</b></td><td>Image border</td></tr>"

	     "<tr><td><b>state</b></td><td>Set to <tt>enabled</tt> or "
	     "<tt>disabled</tt> to select button state</td></tr>"

	     "<tr><td><b>textstyle</b></td><td>Set to <tt>normal</tt> or "
	     "<tt>condensed</tt> to alter text style.</td></tr>"

	     "<tr><td><b>icon_src</b></td><td>Icon reference</td></tr>"

	     "<tr><td><b>icon_data</b></td><td>Inline icon data</td></tr>"

	     "<tr><td><b>align</b></td><td>Text alignment: "
	     "<tt>left|center|right</tt></td></tr>"

	     "<tr><td><b>align_icon</b></td><td>Icon alignment: "
	     "<tt>left|center_before|center_after|right</tt></td></tr>"

	     "</table><p>"
	     "There are some alignment restrictions: when text alignment is "
	     "either <tt>left</tt> or <tt>right</tt>, icons must also be "
	     "aligned <tt>left</tt> or <tt>right</tt>."
 */
#endif

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

Image.Layer layer_slice( Image.Layer l, int from, int to )
{
  return Image.Layer( ([
    "image":l->image()->copy( from,0, to-1, l->ysize()-1 ),
    "alpha":l->alpha()->copy( from,0, to-1, l->ysize()-1 ),
  ]) );
}

Image.Layer stretch_layer( Image.Layer o, int x1, int x2, int w )
{
  Image.Layer l, m, r;
  int leftovers = w - (x1 + (o->xsize()-x2) );
  object oo = o;

  l = layer_slice( o, 0, x1 );
  m = layer_slice( o, x1+1, x2-1 );
  r = layer_slice( o, x2, o->xsize() );

  m->set_image( m->image()->scale( leftovers, l->ysize() ),
                m->alpha()->scale( leftovers, l->ysize() ));

  l->set_offset(  0,0 );
  m->set_offset( x1,0 );
  r->set_offset( w-r->xsize(),0 );
  o = Image.lay( ({ l, m, r }) );
  return o;
}

object(Image.Image)|mapping draw_button(mapping args, string text, object id)
{
  Image.Image  text_img;
  mapping      icon;
  object       button_font = resolve_font( args->font );

  Image.Layer background;
  Image.Layer frame;
  Image.Layer mask;

  int left, right, top, bottom; /* offsets */
  int req_width;

  mapping ll = ([]);

  if( args->border_image )
  {
    array layers = roxen.load_layers(args->border_image, id);
    foreach( layers, object l )
    {
      ll[l->get_misc_value( "name" )] = l;
      switch( lower_case((l->get_misc_value( "name" )/" ")[0]) )
      {
       case "background": background = l; break;
       case "frame":      frame = l;     break;
       case "mask":       mask = l;     break;
      }
    }
  }

  //  otherwise load default images
  if ( !frame )
  {
    array layers = roxen.load_layers("roxen-images/gbutton.xcf", id);
    foreach( layers, object l )
    {
      ll[l->get_misc_value( "name" )] = l;
      switch( lower_case((l->get_misc_value( "name" )/" ")[0]) )
      {
       case "background": background = l; break;
       case "frame":      frame = l;     break;
       case "mask":       mask = l;     break;
      }
    }
  }


  if( !mask )
    mask = frame;

  array x = ({});
  array y = ({});
  foreach( frame->get_misc_value( "image_guides" ), object g )
    if( g->vertical )
      x += ({ g->pos });
    else
      y += ({ g->pos });

  sort( y ); sort( x );
  if(sizeof( x ) < 2)
    x = ({ 5, frame->xsize()-5 });
  if(sizeof( y ) < 2)
    y = ({ 2, frame->ysize()-2 });

  left = x[0]; right = x[-1];    top = y[0]; bottom = y[-1];
  right = frame->xsize()-right;

  int text_height = bottom - top;

  //  Get icon
  if (args->icn)
    icon = roxen.low_load_image(args->icn, id);
  else if (args->icd)
    icon = roxen.low_decode_image(args->icd);

  int i_width = icon && icon->img->xsize();
  int i_spc = i_width ? 5 : 0;

  //  Generate text
  if (sizeof(text))
  {
    text_img = button_font->write(text)->scale(0, text_height );
    if (args->cnd)
      text_img = text_img->scale((int) round(text_img->xsize() * 0.8),
				 text_img->ysize());
  }

  int t_width = text_img && text_img->xsize();

  //  Compute text and icon placement
  req_width = text_img->xsize() + left + right + i_width + i_spc;

  if (args->wi && (req_width < args->wi))
    req_width = args->wi;

  int icn_x, txt_x;

  switch (lower_case(args->al))
  {
  case "left":
    //  Allow icon alignment: left, right
    switch (lower_case(args->ica))
    {
     case "left":
       icn_x = left;
       txt_x = icn_x + i_width + i_spc;
       break;
     default:
     case "right":
       txt_x = left;
       icn_x = req_width - right - i_width;
       break;
    }
    break;

  default:
  case "center":
  case "middle":
    //  Allow icon alignment: left, center, center_before, center_after, right
    switch (lower_case(args->ica))
    {
     case "left":
       icn_x = left;
       txt_x = (req_width - right - left - i_width - i_spc - t_width) / 2;
       txt_x += icn_x + i_width + i_spc;
       break;
     default:
     case "center":
     case "center_before":
       icn_x = (req_width - i_width - i_spc - t_width) / 2;
       txt_x = icn_x + i_width + i_spc;
       break;
     case "center_after":
       txt_x = (req_width - i_width - i_spc - t_width) / 2;
       icn_x = txt_x + t_width + i_spc;
       break;
     case "right":
       icn_x = req_width - right - i_width;
       txt_x = left + (icn_x - i_spc - t_width) / 2;
       break;
    }
    break;

  case "right":
    //  Allow icon alignment: left, right
    switch (lower_case(args->ica))
    {
     default:
     case "left":
       icn_x = left;
       txt_x = req_width - right - t_width;
       break;
     case "right":
       icn_x = req_width - right - i_width;
       txt_x = icn_x - i_spc - t_width;
       break;
    }
    break;
  }

  right = frame->xsize()-right;
  frame = stretch_layer( frame, left, right, req_width );
  if (mask != frame)
    mask = stretch_layer( mask, left, right, req_width );

  if( args->extra_layers )
  {
    array l = ({ });
    if( background )
      l = ({ background });
    foreach( args->extra_layers/",", string q )
      l += ({ ll[q] });
    l-=({ 0 });
    background = Image.lay( l );
  }


  if( background )
  {
    if( !background->alpha() )
      background->set_image( background->image(),
                             Image.Image( background->xsize(),
                                          background->ysize(),
                                          ({255,255,255}) ) );
    if( args->dim )
      background->set_image(background->image(),
                            background->alpha() * 0.3 );
    background = stretch_layer( background, left, right, req_width );
  }

  Image.Image button = Image.Image(req_width, frame->ysize(), args->bg);

  button = button->rgb_to_hsv();
  if( args->dim )
    frame->set_image( frame->image()->modify_by_intensity( 1,1,1,
                                                           ({ 64,64,64 }),
                                                           ({ 196,196,196 })),
                      frame->alpha());
  object h = button*({255,0,0});
  object s = button*({0,255,0});
  object v = button*({0,0,255});
  v->paste_mask( frame->image(), frame->alpha() );
  button = Image.lay( ({
    Image.Layer( h )->set_mode( "red" ),
    Image.Layer( s )->set_mode( "green" ),
    Image.Layer( v )->set_mode( "blue" ),
  }) )->image();
  button = button->hsv_to_rgb();

  // if there is a background, draw it.
  if( background )
    button->paste_mask( background->image(), background->alpha() );

  //  fix transparency (somewhat)
  if( !equal( args->pagebg, args->bg ) )
    button->paste_alpha_color( mask->alpha()->invert()->threshold( 200 ),
                               args->pagebg );


  //  Draw icon.
  if (icon)
  {
    int icn_y = (button->ysize() - icon->img->ysize()) / 2;

    if (!icon->alpha)
      icon->alpha = icon->img->clone()->clear(({255,255,255}));

    if (args->dim)
      icon->alpha *= 0.3;

    button->paste_mask(icon->img, icon->alpha, icn_x, icn_y);
  }

  //  Draw text
  if (args->dim)
    for (int i = 0; i < 3; i++)
      args->txt[i] = (args->txt[i] + args->bg[i]) / 2;

  if(text_img)
    button->paste_alpha_color(text_img, args->txt, txt_x, top);

  return ([
    "img":button,
    "alpha":mask->alpha()->threshold( 40 ),
  ]);
}


mapping find_internal(string f, RequestID id)
{
  return button_cache->http_file_answer(f, id);
}


string tag_button(string tag, mapping args, string contents, RequestID id)
{
  string fi = (args["frame-image"]||id->misc->defines["gbutton-frame-image"]);
  if( fi )
    fi = fix_relative( fi, id );
  mapping new_args = ([
    "pagebg" :parse_color(id->misc->defines->theme_bgcolor ||
                          id->misc->defines->bgcolor ||
                          args->bgcolor ||
                          "#eeeeee"), // _page_ background color
    "bg"  : parse_color(args->bgcolor ||
                        id->misc->defines->theme_bgcolor ||
			id->misc->defines->bgcolor ||
                        "#eeeeee"),     //  Background color
    "txt" : parse_color(args->textcolor || id->misc->defines->theme_bgcolor ||
			id->misc->defines->fgcolor || "#000000"),   //  Text color
    "cnd" : args->condensed ||                           //  Condensed text
            (lower_case(args->textstyle || "") == "condensed"),
    "wi"  : (int) args->width,                           //  Min button width
    "al"  : args->align || "left",                       //  Text alignment
    "dim" : args->dim ||                                 //  Button dimming
            (< "dim", "disabled" >)[lower_case(args->state || "")],
    "icn" : args->icon_src && fix_relative(args->icon_src, id),  // Icon URL
    "icd" : args->icon_data,                             //  Inline icon data
    "ica" : args->align_icon || "left",                  //  Icon alignment
    "font": (args->font||id->misc->defines->font||
             roxen->query("default_font")),
    "border_image":fi,
    "extra_layers":args["extra-layers"],
  ]);

//   array hsv = Image.Color( @new_args->bg )->hsv( );
//   hsv[-1] = min( hsv[-1]+70, 255 );
//   new_args->bob = (array)Image.Color.hsv( @hsv );
//   hsv[-1] = max( hsv[-1]-140, 0 );
//   new_args->bo = (array)Image.Color.hsv( @hsv );

//   if(args->bordercolor)
//     new_args->bo=parse_color(args->bordercolor); //  Border color

//   if(args->borderbottom)
//     new_args->bob=parse_color(args->borderbottom);

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
  if (args->href && !new_args->dim) {
    mapping a_attrs = ([ "href" : args->href ]);
    if (args->target)
      a_attrs->target = args->target;
    return make_container("a", a_attrs, make_tag("img", img_attrs));
  } else
    return make_tag("img", img_attrs);
}
