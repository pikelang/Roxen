// This is a roxen module. Copyright © 1997-1999, Idonex AB.
// Makes a tab list like the one in the config interface.

constant cvs_version="$Id: tablist.pike,v 1.35 2000/02/07 02:36:02 per Exp $";
constant thread_safe=1;

#include <module.h>
inherit "module";
inherit "roxenlib";

roxen.ImageCache the_cache;

/*
 * Functions
 */

void start()
{
  the_cache = roxen.ImageCache( "tablist", draw_tab );
  find_internal = the_cache->http_file_answer;
}

array register_module()
{
  return ({ MODULE_PARSER, "Tab list", "Adds some tags for making tab lists.", 0, 1 });
}

TAGDOCUMENTATION
#ifdef manual
constant tagdoc=(["tablist":({ "<desc cont>Tab list</desc>", (["tab":"<desc cont>Tab</desc>"]) }) ]);
/*
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
	      "the global setting."
 */
#endif

string internal_tag_tab(string t, mapping a, string contents, mapping d,
                        RequestID id)
{
  if (a->help)
    return register_module()[2];

  string fimage;
  int rf;
  if(a["frame-image"])
    fimage = fix_relative( a["frame-image"], id );
  else if(d["frame-image"])
    fimage = fix_relative( d["frame-image"], id );
  else if(id->misc->defines["tab-frame-image"])
    fimage = fix_relative( id->misc->defines["tab-frame-image"], id );
  else
  {
    fimage = getcwd()+"/roxen-images/tab_frame.xcf";
    rf = 1;
  }
  mapping args = ([
"text_height": (a["font-size"] || d["font-size"] ||
                id->misc->defines["tab-font-size"] ),
  "dither": a->dither || d->dither  || 0,
   "quant": a->quant  || d->quant   || "250",
   "gamma": a->gamma  || d->gamma   || 0,
  "format": a->format || d->format  || "gif",
    "sel" : a->selected,
   "font" : a->font || d->font || id->misc->defines->font ||
            roxen->query("default_font"),
  "first" : a->first,
  "last"  : a->last,
    "bg"  : parse_color(a->bgcolor || d->bgcolor ||
			id->misc->defines->theme_bgcolor ||
			id->misc->defines->bgcolor || "white"),
    "fg"  : parse_color(a->selcolor || d->selcolor || "white"),
    "dim" : parse_color(a->dimcolor || d->dimcolor || "#003366"),
    "txt" : parse_color((a->selected?(a->seltextcolor||d->seltextcolor):0)
                        || a->textcolor || d->textcolor ||
			(a->selected ? "black" : "white")),
  "frame_image": fimage,
  "frame_rf":rf,
  ]);

  foreach( glob( "*-*", indices(d)), string n )   args[n] = d[n];
  foreach( glob( "*-*", indices(a)), string n )   args[n] = a[n];

  m_delete(a, "selected");

  //  Create <img> tag
  mapping img_attrs = ([ ]);

  if (a->alt) {
    img_attrs->alt = a->alt;
    m_delete(a, "alt");
  } else
    img_attrs->alt = "_/" + html_encode_string(contents) + "\\_";

  if (a->border) {
    img_attrs->border = a->border;
    m_delete(a, "border");
  } else
    img_attrs->border="0";

  img_attrs->src = query_internal_location()+
                 the_cache->store( ({args,contents}), id );
  if( mapping size = the_cache->metadata( a, id, 1 ) )
  {
    // image in cache (1 above prevents generation on-the-fly,
    // first image will lack sizes)
    img_attrs->width = size->xsize;
    img_attrs->height = size->ysize;
  }
  d->result +=
            make_container("a", a,
                           make_container("b", ([]),
                                          make_tag("img", img_attrs)));
  return "";
}

string container_tablist(string t, mapping a, string contents, RequestID id)
{
  a->result="";
  replace(parse_html(contents, ([]), (["tab":internal_tag_tab]),
                     a, id),
          ({ "\n", "\r" }), ({ "", "" }));
  return a->result;
}

Image.Image draw_tab(mapping args, string txt, object id)
{
  int width, height;
  object  button_font = resolve_font( args->font );
  mapping m;

  if(args->frame_rf )
    m = Image._load( args->frame_image );
  else
    m = roxen.low_load_image( args->frame_image, id );

  if (!m)
    error(sprintf("Tablist: Image %O not found.\n", args->frame_image));

  if(!m->alpha)
    error(sprintf("Tablist: Image %O has no alpha channel.\n",
                  args->frame_image));

  object frame_image = m->img;
  object mask_image  = m->alpha->invert();

  frame_image->paste_alpha_color( mask_image->threshold(254), ({255,255,255}));

  if (!button_font)
    error(sprintf("Tablist: Font %O not found.\n", args->font));

  height = frame_image->ysize();
  width = frame_image->xsize();
  int text_height = (int)args->text_height;
  if( !text_height )
    text_height = height;

  Image.Image text = button_font->write( txt )->scale(0,text_height);
  //  Create image with proper background
  Image.Image i = Image.Image(width * 2 + text->xsize(),
                              height,
                              (args->sel ? args->fg : args->dim));

  //  Add outside corner
  i = i->paste_alpha_color(mask_image, args->bg);

  //  Add tab frame. We compose the corners in a separate buffer where we
  //  draw the sides using a mult() operation to preserve antialiasing.
  object corner = i->copy(0, 0, width - 1, height - 1);
  corner *= frame_image;
  i->paste(corner);
  i->paste(corner->mirrorx(), i->xsize() - corner->xsize(), 0);

  //  Add text which is drawn it twice if the color is bleak
  for (int loop = (`+(@args->txt) / 3 > 200 ? 2 : 1); loop; loop--)
    i->paste_alpha_color(text, args->txt, width, i->ysize()-text_height);

  //  Create line on top of tab (by copying last pixel in frame..)

  object s,q = frame_image->copy( width-1, 0, width-1, height-1);
  object q2 = Image.image(  8,q->ysize() );
  object q3 = Image.image( 64,q->ysize() );

  for( int x = 0; x<8; x++ )    q2->paste( q, x, 0 );
  for( int x = 0; x<8; x++ )    q3->paste( q2, x*8, 0 );

  int x = width;

  for(; (x%8) && (x<i->xsize()-width); x++ )
    i->paste( i->copy( x,0,x,height-1 )*q, x, 0);

  for(; (x%64) && ((x+8)<(i->xsize()-width)); x+=8 )
    i->paste( i->copy( x,0,x+7,height-1 )*q2, x, 0);

  for(; (x+64)<(i->xsize()-width); x+=64 )
    i->paste( i->copy( x,0,x+63,height-1 )*q3, x, 0);

  for(; (x+8)<(i->xsize()-width); x+=8 )
    i->paste( i->copy( x,0,x+7,height-1 )*q2, x, 0);

  for(; x<i->xsize()-width; x++ )
    i->paste( i->copy( x,0,x,height-1 )*q, x, 0);


  // and also at bottom if not selected
  if (!args->sel)
    i->line(0, i->ysize() - 1, i->xsize(), i->ysize() - 1, 0, 0, 0);

  if( args->first )
  {
    i = i->copy( -10,0, i->xsize()-1, i->ysize()-1, args->bg );
    for( int x=0; x<10; x++)
      i->setpixel( 10-x, i->ysize()-1,
                   (args->bg[0]*x)/10, (args->bg[1]*x)/10, (args->bg[2]*x)/10);
  }

  if( args->last )
  {
    int size;
    if( (int)args->last )
      size = (int)args->last;
    else
      size = 30;
    i = i->copy( 0,0, i->xsize()+(size-1), i->ysize()-1, args->bg );
    for( int x=0; x<size; x++)
      i->setpixel( i->xsize()-(size+1)+x,
                   i->ysize()-1,
                   (args->bg[0]*x)/size, (args->bg[1]*x)/size,
                   (args->bg[2]*x)/size);
  }
  return i;
}

function find_internal;
