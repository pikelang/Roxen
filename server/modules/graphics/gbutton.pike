//  Button module. Generates graphical buttons for use in Roxen config
//  interface, Roxen SiteBuilder and other places.
//
//  Copyright © 1999 - 2009, Roxen IS. Author: Jonas Walldén, <jonasw@roxen.com>


//  Usage:
//
//  <gbutton
//     bgcolor         -- background color inside/outside button
//     textcolor       -- button text color
//     href            -- button URL
//     target          -- target frame
//     alt             -- alternative button alt text
//     title           -- button tooltip
//     border          -- image border
//     state           -- enabled|disabled button state
//     textstyle       -- normal|consensed text
//     icon-src        -- icon reference
//     icon-data       -- inline icon data
//     align           -- left|center|right text alignment
//     align-icon      -- left|center-before|center-after|right icon alignment
//     valign-icon     -- above|middle|below icon vertical alignment
//   >Button text</gbutton>
//
//  Alignment restriction: when text alignment is either left or right, icons
//  must also be aligned left or right.


constant cvs_version = "$Id$";
constant thread_safe = 1;

#include <module.h>
inherit "module";

roxen.ImageCache  button_cache;
int do_ext;

constant module_type = MODULE_TAG;
constant module_name = "Graphics: GButton";
constant module_doc  = 
"Provides the <tt>&lt;gbutton&gt;</tt> tag that is used to draw graphical "
"buttons.";

void create()
{
  defvar("ext", Variable.Flag(0, VAR_MORE,
			      "Append format to generated images",
			      "Append the image format (.gif, .png, "
			      ".jpg, etc) to the generated images. "
			      "This is not necessary, but might seem "
			      "nicer, especially to people who try "
			      "to mirror your site."));
}

mapping tagdocumentation() {
  Stdio.File file=Stdio.File();
  if(!file->open(__FILE__,"r")) return 0;
  string doc=compile_string("#define manual\n"+file->read(), __FILE__)->gbuttonattr;
  string imagecache=button_cache->documentation();

  return ([

"gbutton":#"<desc type='cont'><p><short>
 Creates graphical buttons.</short></p>
</desc>"

	   +doc
	   +imagecache,

"gbutton-url":#"<desc type='cont'><p><short>
 Generates an URI to the button.</short> <tag>gbutton-url</tag> takes
 the same attributes as <xref href='gbutton.tag' /> including the
 image cache attributes.</p>
</desc>"

	   +doc
	   +imagecache,
  ]);
}

#ifdef manual
constant gbuttonattr=#"
<attr name='pagebgcolor' value='color'><p></p>

</attr>

<attr name='bgcolor' value='color'><p>
 Background color inside and outside button.</p>
<ex>
<gbutton bgcolor='lightblue'>Background</gbutton>
</ex>
</attr>

<attr name='textcolor' value='color'>
 <p>Button text color.</p>
<ex><gbutton textcolor='#ff6600'>Text</gbutton></ex>
</attr>

<attr name='frame-image' value='path'><p>
 Use this XCF-image as a frame for the button. The image is required
 to have at least the following layers: background, mask and frame.</p>
"+/* <ex><gbutton frame-image='internal-roxen-tabframe'>foo</gbutton></ex> */#"
</attr>

<attr name='alt' value='string'><p>
 Alternative button and alt text.</p>
</attr>

<attr name='title' value='string'><p>
 Button tooltip.</p>
</attr>

<attr name='href' value='uri'><p>
 Button URI.</p>
</attr>

<attr name='target' value='string'><p>
 Button target frame.</p>
</attr>

<attr name='textstyle' value='normal|condensed'><p>
 Set to <i>normal</i> or <i>condensed</i> to alter text style.</p>
</attr>

<attr name='width' value=''><p>
 Minimum button width.</p>
</attr>

<attr name='align' value='left|center|right'><p>
 Set text alignment. There are some alignment restrictions: when text
 alignment is either <i>left</i> or <i>right</i>, icons must
 also be aligned <i>left</i> or <i>right</i>.</p>
</attr>

<attr name='img-align' value=''><p>
 Alignment passed on to the resulting <tag>img</tag>.</p>
</attr>

<attr name='state' value='enabled|disabled'><p>
 Set to <i>enabled</i> or <i>disabled</i> to select button state.</p>
</attr>

<attr name='icon-src' value='URI'><p>
 Fetch the icon from this URI.</p>
</attr>

<attr name='icon-data' value=''><p>
 Inline icon data.</p>
</attr>

<attr name='align-icon' value='left|center-before|center-after|right'><p>
 Set icon alignment.</p>

<xtable>
<row><c><p>left</p></c><c><p>Place icon on the left side of the text.</p></c></row>
<row><c><p>center-before</p></c><c><p>Center the icon before the text. Requires the <i>align='center'</i> attribute.</p></c></row>
<row><c><p>center-after</p></c><c><p>Center the icon after the text. Requires the <i>align='center'</i> attribute.</p></c></row>
<row><c><p>right</p></c><c><p>Place icon on the right side of the text.</p></c></row>
</xtable>

<ex>
<gbutton width='150' align-icon='center-before' icon-src='internal-roxen-help'>Roxen 2.0</gbutton>
</ex>
<ex>
<gbutton width='150' align='center' align-icon='center-after'
  icon-src='/internal-roxen-help'>Roxen 2.0</gbutton>
</ex>
</attr>

<attr name='valign-icon' value='above|middle|below'><p>
  Set icon vertical alignment. Requires three horizontal guidelines in the
  frame image. If set to <i>above</i> the icon is placed between the first
  and second guidelines and the text between the second and third ones. If
  set to <i>below</i> the placement is reversed. Default value is
  <i>middle</i>.</p>
</attr>

<attr name='font' value='fontname'><p></p></attr>

<h1>Timeout</h1>

<p>The generated image will by default never expire, but
in some circumstances it may be pertinent to limit the
time the image and its associated data is kept. Its
possible to set an (advisory) timeout on the image data
using the following attributes.</p>

<attr name='unix-time' value='number'><p>
Set the base expiry time to this absolute time.</p><p>
If left out, the other attributes are relative to current time.</p>
</attr>

<attr name='years' value='number'><p>
Add this number of years to the time this entry is valid.</p>
</attr>

<attr name='months' value='number'><p>
Add this number of months to the time this entry is valid.</p>
</attr>

<attr name='weeks' value='number'><p>
Add this number of weeks to the time this entry is valid.</p>
</attr>

<attr name='days' value='number'><p>
Add this number of days to the time this entry is valid.</p>
</attr>

<attr name='hours' value='number'><p>
Add this number of hours to the time this entry is valid.</p>
</attr>

<attr name='beats' value='number'><p>
Add this number of beats to the time this entry is valid.</p>
</attr>

<attr name='minutes' value='number'><p>
Add this number of minutes to the time this entry is valid.</p>
</attr>

<attr name='seconds' value='number'><p>
Add this number of seconds to the time this entry is valid.</p>
</attr>";
#endif

//  Cached copy of conf->query("compat_level"). This setting is defined
//  to require a module reload to take effect so we only query it when
//  the module instance is created.
float compat_level = (float) my_configuration()->query("compat_level");

function TIMER( function f )
{
#if 0
  return lambda(mixed ... args) {
           int h = gethrtime();
           mixed res;
           werror("Drawing ... ");
           res = f( @args );
           werror(" %.1fms\n", (gethrtime()-h)/1000000.0 );
           return res;
         };
#endif
  return f;
}
void start()
{
  button_cache = roxen.ImageCache("gbutton", TIMER(draw_button));
  do_ext = query("ext");
}

void stop()
{
  destruct(button_cache);
}

string status() {
  array s=button_cache->status();
  return sprintf("<b>Images in cache:</b> %d images<br />\n"
                 "<b>Cache size:</b> %s",
		 s[0], Roxen.sizetostring(s[1]));
}

mapping(string:function) query_action_buttons() {
  return ([ "Clear Cache":flush_cache ]);
}

void flush_cache() {
  button_cache->flush();
  
  //  It's possible that user code contains a number of stale URLs in
  //  e.g. <cache> blocks so we can just as well flush the RAM cache to
  //  reduce the risk of broken images.
  cache.flush_memory_cache();
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
  o->set_mode( oo->mode() );
  o->set_alpha_value( oo->alpha_value() );
  return o;
}

array(Image.Layer)|mapping draw_button(mapping args, string text, object id)
{
  Image.Image  text_img;
  mapping      icon;

  Image.Layer background;
  Image.Layer frame;
  Image.Layer mask;

  int left, right, top, middle, bottom; /* offsets */
  int req_width, noframe;

  mapping ll = ([]);

  //  Photoshop layers: don't let individual layers expand the image
  //  beyond the bounds of the overall image.
  mapping opts = ([ "crop_to_bounds" : 1 ]);

  void set_image( array layers )
  {
    foreach( layers||({}), object l )
    {
      if(!l->get_misc_value( "name" ) ) // Hm. Probably PSD
        continue;

      ll[lower_case(l->get_misc_value( "name" ))] = l;
      switch( lower_case(l->get_misc_value( "name" )) )
      {
       case "background": background = l; break;
       case "frame":      frame = l;     break;
       case "mask":       mask = l;     break;
      }
    }
  };

  if( args->border_image )
  {
    array(Image.Layer)|mapping tmp;

#if constant(Sitebuilder)
    //  Let SiteBuilder get a chance to decode its argument data
    if (Sitebuilder.sb_start_use_imagecache) {
      Sitebuilder.sb_start_use_imagecache(args, id);
      tmp = roxen.load_layers(args->border_image, id, opts);
      Sitebuilder.sb_end_use_imagecache(args, id);
    } else
#endif
    {
      tmp = roxen.load_layers(args->border_image, id, opts);
    }
    
    if (mappingp(tmp)) {
      if (tmp->error != 401)
	report_debug("GButton: Failed to load frame image: %O (error: %O)\n",
		     args->border_image, tmp->error);
      return tmp;
    }
    set_image( tmp );
  }


  //  otherwise load default images
  if ( !frame && !background && !mask )
  {
    string data = Stdio.read_file("roxen-images/gbutton.xcf");
    if (!data)
      error ("Failed to load default frame image "
	     "(roxen-images/gbutton.xcf): " + strerror (errno()));
    mixed err = catch {
      set_image(Image.XCF.decode_layers(data));
    };
    if( !frame )
      if (err) {
	catch (err[0] = "Failed to decode default frame image "
	       "(roxen-images/gbutton.xcf): " + err[0]);
	throw (err);
      }
      else
	error("Failed to decode default frame image "
	      "(roxen-images/gbutton.xcf).\n");
  }

  if( !frame )
  {
    noframe = 1;
    frame = background || mask; // for sizes offsets et.al.
  }
  
  // Translate frame image to 0,0 (left layers are most likely to the
  // left of the frame image)
  int x0 = frame->xoffset();
  int y0 = frame->yoffset();
  if( x0 || y0 )
    foreach( values( ll ), object l )
    {
      int x = l->xoffset();
      int y = l->yoffset();
      l->set_offset( x-x0, y-y0 );
    }

  if( !mask )
    mask = frame;

  array x = ({});
  array y = ({});

  foreach( frame->get_misc_value( "image_guides" ), object g )
    if( g->vertical )
      x += ({ g->pos - x0 });
    else
      y += ({ g->pos - y0 });

  sort( y );
  sort( x );

  if(sizeof( x ) < 2)
    x = ({ 5, frame->xsize()-5 });

  if(sizeof( y ) < 2)
    y = ({ 2, frame->ysize()-2 });

  left = x[0]; right = x[-1];    top = y[0]; middle = y[1]; bottom = y[-1];
  right = frame->xsize()-right;

  //  Text height depends on which guides we should align to
  int text_height;
  switch (args->icva) {
  case "above":
    text_height = bottom - middle;
    break;
  case "below":
    text_height = middle - top;
    break;
  default:
  case "middle":
    text_height = bottom - top;
    break;
  }

  //  Get icon
  if (args->icn) {
    //  Pass error mapping to find out possible errors when loading icon
    mapping err = ([ ]);
    icon = roxen.low_load_image(args->icn, id, err);

    //  If icon loading fails due to missing authentication we reject the
    //  gbutton request so that the browser can re-request it with proper
    //  authentication headers.
    if (!icon && err->error == 401)
      return err;
  } else if (args->icd)
    icon = roxen.low_decode_image(args->icd);
  
  int i_width = icon && icon->img->xsize();
  int i_height = icon && icon->img->ysize();
  int i_spc = i_width && sizeof(text) && 5;

  //  Generate text
  if (sizeof(text))
  {
    int min_font_size = 0;
    int max_font_size = text_height * 2;
    do {
      //  Use binary search to find an appropriate font size. Since we prefer
      //  font sizes which err on the small side (so we never extend outside
      //  the given boundaries) we must round up when computing the next size
      //  or we risk missing a good size.
      int try_font_size = (max_font_size + min_font_size + 1) / 2;
      Font button_font = resolve_font(args->font + " " + try_font_size);
      text_img = button_font->write(text);
      int real_height = text_img->ysize();
      
      //  Early bail for fixed-point fonts which are too large
      if (real_height > try_font_size * 2)
	break;
      
      //  Go up or down in size?
      if (real_height == text_height)
	break;
      if (real_height > text_height)
	max_font_size = try_font_size - 1;
      else {
	if (min_font_size == max_font_size)
	  break;
	min_font_size = try_font_size;
      }
    } while (max_font_size - min_font_size >= 0);
    
    // fonts that can not be scaled.
    if( abs(text_img->ysize() - text_height)>2 )
      text_img = text_img->scale(0, text_height );
    else
    {
      int o = text_img->ysize() - text_height; 
      top -= o;
      middle -= o/2;
    }
    if (args->cnd)
      text_img = text_img->scale((int) round(text_img->xsize() * 0.8),
				 text_img->ysize());
  } else
    text_height = 0;

  int t_width = text_img && text_img->xsize();

  //  Compute text and icon placement. Only incorporate icon width/spacing if
  //  it's placed inline with the text.
  req_width = t_width + left + right;
  if ((args->icva || "middle") == "middle")
    req_width += i_width + i_spc;
  if (args->wi && (req_width < args->wi))
    req_width = args->wi;

  int icn_x, icn_y, txt_x, txt_y;

  //  Are text and icon lined up or on separate lines?
  switch (args->icva) {
  case "above":
  case "below":
    //  Note: This requires _three_ guidelines! Icon and text can only be
    //  horizontally centered
    icn_x = left + (req_width - right - left - i_width) / 2;
    txt_x = left + (req_width - right - left - t_width) / 2;
    if (args->icva == "above" || !text_height) {
      txt_y = middle;
      icn_y = top + ((text_height ? middle : bottom) - top - i_height) / 2;
    } else {
      txt_y = top;
      icn_y = middle + (bottom - middle - i_height) / 2;
    }
    break;

  default:
  case "middle":
    //  Center icon vertically on same line as text
    icn_y = icon && (frame->ysize() - icon->img->ysize()) / 2;
    txt_y = top;
    
    switch (args->al)
    {
    case "left":
      //  Allow icon alignment: left, right
      switch (args->ica)
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
      //  Allow icon alignment:
      //  left, center, center-before, center-after, right
      switch (args->ica)
      {
      case "left":
	icn_x = left;
	txt_x = (req_width - right - left - i_width - i_spc - t_width) / 2;
	txt_x += icn_x + i_width + i_spc;
	break;
      default:
      case "center":
      case "center_before":
      case "center-before":
	icn_x = (req_width - i_width - i_spc - t_width) / 2;
	txt_x = icn_x + i_width + i_spc;
	break;
      case "center_after":
      case "center-after":
	txt_x = (req_width - i_width - i_spc - t_width) / 2;
	icn_x = txt_x + t_width + i_spc;
	break;
      case "right":
	icn_x = req_width - right - i_width;
	txt_x = left + (icn_x - i_spc - t_width - left) / 2;
	break;
      }
      break;
      
    case "right":
      //  Allow icon alignment: left, right
      switch (args->ica)
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
    break;
  }

  if( args->extra_frame_layers )
  {
    array l = ({ });
    foreach( args->extra_frame_layers/",", string q )
      l += ({ ll[q] });
    l-=({ 0 });
    if( sizeof( l ) )
      frame = Image.lay( l+(noframe?({}):({frame})) );
  }

  if( args->extra_mask_layers )
  {
    array l = ({ });
    foreach( args->extra_mask_layers/",", string q )
      l += ({ ll[q] });
    l-=({ 0 });
    if( sizeof( l ) )
    {
      if( mask )
        l = ({ mask })+l;
      mask = Image.lay( l );
    }
  }

  right = frame->xsize()-right;
  if (mask != frame)
  {
    Image.Image i = mask->image();
    Image.Image m = mask->alpha();
    int x0 = -mask->xoffset();
    int y0 = -mask->yoffset();
    int x1 = frame->xsize()-1+x0;
    int y1 = frame->ysize()-1+y0;
    
    i = i->copy(x0,y0, x1,y1);
    if( m )
      m = m->copy(x0,y0, x1,y1);
    mask->set_image( i, m );
    mask = stretch_layer( mask, left, right, req_width );
  }
  if( frame != background )
    frame = stretch_layer( frame, left, right, req_width );
  array(Image.Layer) button_layers = ({
     Image.Layer( Image.Image(req_width, frame->ysize(), args->bg),
                  mask->alpha()->copy(0,0,req_width-1,frame->ysize()-1)),
  });


  if( args->extra_background_layers || background)
  {
    array l = ({ background });
    foreach( (args->extra_background_layers||"")/","-({""}), string q )
      l += ({ ll[q] });
    l-=({ 0 });
    foreach( l, object ll )
    {
      if( args->dim )
        ll->set_alpha_value( 0.3 );
      button_layers += ({ stretch_layer( ll, left, right, req_width ) });
    }
  }

  if( !noframe )
  {
    button_layers += ({ frame });
    frame->set_mode( "value" );
  }

  if( args->dim )
  {
    //  Adjust dimmed border intensity to the background
    int bg_value = Image.Color(@args->bg)->hsv()[2];
    int dim_high, dim_low;
    if (bg_value < 128) {
      dim_low = max(bg_value - 64, 0);
      dim_high = dim_low + 128;
    } else {
      dim_high = min(bg_value + 64, 255);
      dim_low = dim_high - 128;
    }
    frame->set_image(frame->image()->
                     modify_by_intensity( 1, 1, 1,
                                          ({ dim_low, dim_low, dim_low }),
                                          ({ dim_high, dim_high, dim_high })),
                     frame->alpha());
  }

  //  Draw icon.
  if (icon)
    button_layers += ({
      Image.Layer( ([
        "alpha_value":(args->dim ? 0.3 : 1.0),
        "image":icon->img,
        "alpha":icon->alpha,
        "xoffset":icn_x,
        "yoffset":icn_y
      ]) )});

  //  Draw text
  if(text_img)
  {
    float ta = args->txtalpha?args->txtalpha:1.0;
    button_layers +=
      ({
        Image.Layer(([
          "mode":args->txtmode,
          "image":text_img->color(0,0,0)->invert()->color(@args->txt),
          "alpha":(text_img*(args->dim?0.5*ta:ta)),
          "xoffset":txt_x,
          "yoffset":txt_y,
        ]))
    });
  }

  // 'plain' extra layers are added on top of everything else
  if( args->extra_layers )
  {
    array q = map(args->extra_layers/",",
                  lambda(string q) { return ll[q]; } )-({0});
    foreach( q, object ll )
    {
      if( args->dim )
        ll->set_alpha_value( 0.3 );
      button_layers += ({stretch_layer(ll,left,right,req_width)});
      button_layers[-1]->set_offset( 0,
                                     button_layers[0]->ysize()-
                                     button_layers[-1]->ysize() );
    }
  }

  button_layers  -= ({ 0 });
  // left layers are added to the left of the image, and the mask is
  // extended using their mask. There is no corresponding 'mask' layers
  // for these, but that is not a problem most of the time.
  if( args->extra_left_layers )
  {
    array l = ({ });
    foreach( args->extra_left_layers/",", string q )
      l += ({ ll[q] });
    l-=({ 0 });
    l->set_offset( 0, 0 );
    if( sizeof( l ) )
    {
      object q = Image.lay( l );
      foreach( button_layers, object b )
      {
        int x = b->xoffset();
        int y = b->yoffset();
        b->set_offset( x+q->xsize(), y );
      }
      q->set_offset( 0, button_layers[0]->ysize()-q->ysize() );
      button_layers += ({ q });
    }
  }

  // right layers are added to the right of the image, and the mask is
  // extended using their mask. There is no corresponding 'mask' layers
  // for these, but that is not a problem most of the time.
  if( args->extra_right_layers )
  {
    array l = ({ });
    foreach( args->extra_right_layers/",", string q )
      l += ({ ll[q] });
    l-=({ 0 });
    l->set_offset( 0, 0 );
    if( sizeof( l ) )
    {
      object q = Image.lay( l );
      q->set_offset( button_layers[0]->xsize()+
                     button_layers[0]->xoffset(),
                     button_layers[0]->ysize()-q->ysize());
      button_layers += ({ q });
    }
  }

//   if( !equal( args->pagebg, args->bg ) )
//   {
  // FIXME: fix transparency (somewhat)
  // this version totally destroys the alpha channel of the image,
  // but that's sort of the intention. The reason is that
  // the png images are generated without alpha.
  if (args->format == "png")
    return ({ Image.Layer(([ "fill":args->pagebg, ])) }) + button_layers;
  else
    return button_layers;
//   }
}

mapping find_internal(string f, RequestID id)
{
  // It's not enough to
  //  1. Only do this check when the ext flag is set, old URLs might
  //     live in caches
  //
  //  2. Check str[-4] for '.', consider .jpeg .tiff etc.
  //
  // However, . is not a valid character in the ID, so just cutting at
  // the first one works.
  return button_cache->http_file_answer( (f/".")[0], id );
}

int get_file_stat( string f, RequestID id  )
{
  int res;
  mapping stat_cache;
  
  //  -1 is used to cache negative results. When SiteBuilder crawler runs
  //  we must let the stat_file() run unconditionally to register
  //  dependencies properly.
  if (stat_cache = id->misc->gbutton_statcache) {
    if (!id->misc->persistent_cache_crawler)
      if (res = stat_cache[f])
	return (res > 0) && res;
  } else
    stat_cache = id->misc->gbutton_statcache = ([ ]);
  
  int was_internal = id->misc->internal_get;
  id->misc->internal_get = 1;
  res = stat_cache[ f ] = (id->conf->stat_file( f,id ) ||
			   ({ 0,0,0,0 }) )[ST_MTIME] || -1;
  if (!was_internal)
    m_delete(id->misc, "internal_get");
  return (res > 0) && res;
}

class ButtonFrame {
  inherit RXML.Frame;

  array mk_url(RequestID id) 
  {
//     int t = gethrtime();
    string fi = (args["frame-image"] ||
		 id->misc->defines["gbutton-frame-image"]);
    if( fi ) {
      //  Reject empty file paths for sufficiently high compat_level
      if (fi == "" && compat_level >= 5.2)
	RXML.parse_error("Empty frame-image attribute not allowed.");
      
      fi = Roxen.fix_relative( fi, id );
    }
    m_delete(args, "frame-image");
    
    //  Harmonize some attribute names to RXML standards...
    args->icon_src = args["icon-src"]       || args->icon_src;
    args->icon_data = args["icon-data"]     || args->icon_data;
    args->align_icon = args["align-icon"]   || args->align_icon;
    args->valign_icon = args["valign-icon"] || args->valign_icon;
    m_delete(args, "icon-src");
    m_delete(args, "icon-data");
    m_delete(args, "align-icon");

    if (args->icon_src == "" && compat_level >= 5.2)
      RXML.parse_error("Empty icon-src attribute not allowed.");
    
    mapping new_args =
      ([
	"pagebg" :parse_color(args->pagebgcolor ||
			      id->misc->defines->theme_bgcolor ||
			      id->misc->defines->bgcolor ||
			      args->bgcolor ||
			      "#eeeeee"),                 // _page_ bg color
	"bg"  : parse_color(args->bgcolor ||
			    id->misc->defines->theme_bgcolor ||
			    id->misc->defines->bgcolor ||
			    "#eeeeee"),                   //  Background color
	"txt" : parse_color(args->textcolor ||
			    id->misc->defines->theme_bgcolor ||
			    id->misc->defines->fgcolor ||
			    "#000000"),                   //  Text color
	"txtalpha": (args->textalpha?(float)args->textalpha:1.0),
	"txtmode": (args->textmode||"normal"),
	"cnd" : (args->condensed ||                       //  Condensed text
		 (lower_case(args->textstyle || "") == "condensed")),
	"wi"  : (int) args->width,                        //  Min button width
	"al"  : args->align || "left",                    //  Text alignment
	"dim" : (args->dim ||                             //  Button dimming
		 (< "dim", "disabled" >)[lower_case(args->state || "")]),
	"icn" : args->icon_src &&
	Roxen.fix_relative(args->icon_src, id),  // Icon URL
	"icd" : args->icon_data,                          //  Inline icon data
	"ica" : lower_case(args->align_icon || "left"),   //  Icon alignment
	"icva": lower_case(args->valign_icon || "middle"),//  Vertical align
	"font": (args->font||id->misc->defines->font||
		 roxen->query("default_font")),
	"fontkey": roxen->fonts->verify_font(args->font||id->misc->defines->font),
	"border_image":fi,
	"extra_layers":args["extra-layers"],
	"extra_left_layers":args["extra-left-layers"],
	"extra_right_layers":args["extra-right-layers"],
	"extra_background_layers":args["extra-background-layers"],
	"extra_mask_layers":args["extra-mask-layers"],
	"extra_frame_layers":args["extra-frame-layers"],
	"scale":args["scale"],
	"format":args["format"],
	"gamma":args["gamma"],
	"crop":args["crop"],
      ]);

    //  Remove extra layer attributes to avoid *-* copying below
    m_delete(args, "extra-layers");
    m_delete(args, "extra-left-layers");
    m_delete(args, "extra-right-layers");
    m_delete(args, "extra-background-layers");
    m_delete(args, "extra-mask-layers");
    m_delete(args, "extra-frame-layers");
    
    int timeout = Roxen.timeout_dequantifier(args);

    if( fi ) {
      new_args->stat = get_file_stat( fi, id );
#if constant(Sitebuilder)
      //  The file we called get_file_stat() on above may be a SiteBuilder
      //  file. If so we need to extend the argument data with e.g.
      //  current language fork.
      if (Sitebuilder.sb_prepare_imagecache)
	new_args = Sitebuilder.sb_prepare_imagecache(new_args, fi, id);
#endif
    }

    if (string icn_path = new_args->icn) {
      new_args->stat_icn = get_file_stat(icn_path, id);
#if constant(Sitebuilder)
      if (Sitebuilder.sb_prepare_imagecache)
	new_args = Sitebuilder.sb_prepare_imagecache(new_args, icn_path, id);
#endif
    }

    new_args->quant = args->quant || 128;
    foreach(glob("*-*", indices(args)), string n)
      new_args[n] = args[n];

    //string fn;
    //  if( new_args->stat && (fn = id->conf->real_file( fi, id ) ) )
    //     Roxen.add_cache_stat_callback( id, fn, new_args->stat );

//     werror("mkurl took %dµs\n", gethrtime()-t );

//     t = gethrtime();
    string img_src =
      query_absolute_internal_location(id) +
      button_cache->store( ({ new_args, (string)content }), id, timeout);

    if(do_ext)
      img_src += "." + (new_args->format || "gif");

//     werror("argcache->store took %dµs\n", gethrtime()-t );
    return ({ img_src, new_args, timeout });
  }
}

class TagGButtonURL {
  inherit RXML.Tag;
  constant name = "gbutton-url";
  constant flags = RXML.FLAG_DONT_REPORT_ERRORS;
  RXML.Type content_type = RXML.t_text(RXML.PXml);

  class Frame {
    inherit ButtonFrame;
    array do_return(RequestID id) {
      result=mk_url(id)[0];
      return 0;
    }
  }
}

class TagGButton {
  inherit RXML.Tag;
  constant name = "gbutton";
  constant flags = RXML.FLAG_DONT_REPORT_ERRORS;
  RXML.Type content_type = RXML.t_text(RXML.PXml);

  class Frame {
    inherit ButtonFrame;
    array do_return(RequestID id) {
      //  Peek at img-align and remove it so it won't be copied by "*-*" glob
      //  in mk_url().
      string img_align = args["img-align"];
      string title = args->title;
      m_delete(args, "img-align");
      
      [string img_src, mapping new_args, int timeout]=mk_url(id);

      mapping img_attrs = ([ "src"    : img_src,
			     "alt"    : args->alt || (string)content,
			     "border" : args->border,
			     "hspace" : args->hspace,
			     "vspace" : args->vspace ]);
      if (img_align)
        img_attrs->align = img_align;
      if (title)
	img_attrs->title = title;
      
      int no_draw = !id->misc->generate_images;
      if (mapping size = button_cache->metadata( ({ new_args, (string)content }),
						 id, no_draw, timeout)) {
	//  Image in cache (no_draw above prevents generation on-the-fly, i.e.
	//  first image will lack sizes).
	img_attrs->width = size->xsize;
	img_attrs->height = size->ysize;
      }

      result = Roxen.make_tag("img", img_attrs, !args->noxml);

      //  Make button clickable if not dimmed
      if(args->href && !new_args->dim)
      {
	mapping a_attrs = ([ "href"    : args->href,
			     "onfocus" : "this.blur();" ]);

	foreach(indices(args), string arg)
	  if(has_value("/target/onmousedown/onmouseup/onclick/ondblclick/"
		       "onmouseout/onmouseover/onkeypress/onkeyup/"
		       "onkeydown/style/class/id/accesskey/",
		       "/" + lower_case(arg) + "/"))
	    a_attrs[arg] = args[arg];

	result = Roxen.make_container("a", a_attrs, result);
      }

      return 0;
    }
  }
}
