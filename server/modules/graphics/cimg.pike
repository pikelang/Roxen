// This is a roxen module. Copyright © 1999 - 2000, Roxen IS.
//

#include <module.h>
inherit "module";
constant thread_safe=1;

roxen.ImageCache the_cache;
constant cvs_version="$Id: cimg.pike,v 1.17 2000/05/18 12:19:29 kuntri Exp $";
constant tagdesc="Provides the tag <tt>&lt;cimg&gt;</tt> that can be used "
"to convert images between different image formats.";

constant module_type = MODULE_PARSER;
constant module_name = "Image converter";
constant module_doc  = tagdesc;

TAGDOCUMENTATION
#ifdef manual
constant imagecache=#"

<h2>Image cache attributes</h2>
All examples are made for the &lt;cimg&gt; tag.

<attr name='format' value='gif|jpeg|png|avs|gmp|bd|hrz|ilbm|psx|pnm|ps|pvr|tga|tiff|wbf|xbm|xpm' default='gif'>
 The format to encode the image to. The formats available are:
<table>
<tr><td>gif</td><td>Graphics Interchange Format (might be missing in your roxen)</td></tr>
<tr><td>jpeg</td><td>Joint Photography Expert Group image compression</td></tr>
<tr><td>png</td><td>Portable Networks Graphics</td></tr>
<tr><td>avs</td><td></td></tr>
<tr><td>bmp</td><td>Windows BitMaP file</td></tr>
<tr><td>gd</td><td></td></tr>
<tr><td>hrz</td><td>HRZ is (was?) used for amatuer radio slow-scan TV.</td></tr>
<tr><td>ilbm</td><td></td></tr>
<tr><td>pcx</td><td>Zsoft PCX file format (PC / DOS)</td></tr>
<tr><td>pnm</td><td>Portable AnyMap</td></tr>
<tr><td>ps</td><td>Adobe PostScript file</td></tr>
<tr><td>pvr</td><td>Pover VR (dreamcast image)</td></tr>
<tr><td>tga</td><td>TrueVision Targa (PC / DOS)</td></tr>
<tr><td>tiff</td><td>Tag Image File Format</td></tr>
<tr><td>wbf</td><td>WAP Bitmap File</td></tr>
<tr><td>xbm</td><td>XWindows Bitmap File</td></tr>
<tr><td>xpm</td><td>XWindows Pixmap File</td></tr>
</table>
<ex>
<cimg src='internal-roxen-robodog' format='png'/>
</ex>
<ex>
<cimg src='internal-roxen-robodog' format='gif'/>
</ex>
</attr>


<attr name='quant' value='number' default='format dependant'>
 The number of colors to quantizize the image to.
<p>
   Default for gif is 255(+1 transparent), for most other formats
   (except black and white) is it unlimited.</p>

<ex>
<cimg src='internal-roxen-robodog' quant='100'/>
</ex>
<ex>
<cimg src='internal-roxen-robodog' quant='10'/>
</ex>
<ex>
<cimg src='internal-roxen-robodog' quant='2'/>
</ex>

</attr>

<h1>Color/alpha attributes</h1>

<attr name='dither' value='none|random|floyd-steinberg' default='none'>
 Choose the dithering method.
<table>
<tr><td>none</td><td>No dithering is performed at all.</td></tr>
<tr><td>random</td><td>Random scatter dither. Not visually pleasing, but it is useful for very high resolution printing.</td></tr>
<tr><td>floyd-steinberg</td><td>Error diffusion dithering. Usually the best dithering method.</td></tr>
</table>

<ex>
<cimg src='internal-roxen-robodog' dither='random' quant='10'/>
</ex>
<ex>
<cimg src='internal-roxen-robodog' dither='floyd-steinberg' quant='10'/>
</ex>
</attr>

<attr name='true-alpha'>
 If present, render a real alpha channel instead of on/off alpha. If
 the file format only supports on/off alpha, the alpha channel is
 dithered using a floyd-steinberg dither.

<ex>
<cimg src='internal-roxen-robodog' opaque-value='20'/>
</ex>
<ex>
<cimg src='internal-roxen-robodog' opaque-value='20' true-alpha='1'/>
</ex>
</attr>

<attr name='background-color' value='color' default='taken from the page'>
 The color to render the image against.
<ex>
<cimg src='internal-roxen-robodog' background-color='black' opaque-value='50'/>
</ex>
</attr>

<attr name='opaque-value' value='percentage' default='100'>
 The transparency value to use, 100 is fully opaque, and 0 is fully
 transparent.
</attr>

<attr name='cs-rgb-hsv' value='0|1' default='0'>
 Perform rgb to hsv colorspace conversion.
<ex>
<cimg src='internal-roxen-robodog' cs-rgb-hsv='1'/>
</ex>
</attr>

<attr name='gamma' value='number' default='1.0'>
 Perform gamma adjustment.
<ex>
<cimg src='internal-roxen-robodog' gamma='0.1' />
</ex>
<ex>
<cimg src='internal-roxen-robodog' gamma='0.5'/ />
</ex>
<ex>
<cimg src='internal-roxen-robodog' gamma='1.0'/>
</ex>
<ex>
<cimg src='internal-roxen-robodog' gamma='2.0' />
</ex>
<ex>
<cimg src='internal-roxen-robodog' gamma='8.0'/>
</ex>
</attr>

<attr name='cs-grey' value='0|1' default='0'>
 Perform rgb to greyscale colorspace conversion.
<ex>
<cimg src='internal-roxen-robodog' cs-grey='1'/>
</ex>
</attr>

<attr name='cs-invert' value='0|1' default='0'>
 Invert all colors
<ex>
<cimg src='internal-roxen-robodog' cs-invert='1'/>
</ex>
</attr>

<attr name='cs-hsv-rgb' value='0|1' default='0'>
 Perform hsv to rgb colorspace conversion.
<ex>
<cimg src='internal-roxen-robodog' cs-hsv-rgb='1'/>
</ex>
<ex>
<cimg src='internal-roxen-robodog' cs-grey='1' cs-hsv-rgb='1' cs-rgb-hsv='1'/>
</ex>
<ex>
<cimg src='internal-roxen-robodog' cs-hsv-rgb='1' cs-invert='1' cs-rgb-hsv='1/>
</ex>
</attr>

<h1>Transform attributes</h1>

<attr name='rotate-cw' value='degree' default='0'>
 Rotate the image clock-wise.
<ex>
<cimg src='internal-roxen-robodog' rotate-cw='20'/>
</ex>
<ex>
<cimg src='internal-roxen-robodog' rotate-cw='90'/>
</ex>
</attr>

<attr name='rotate-ccw' value='degree' default='0'>
 Rotate the image counter clock-wise.
<ex>
<cimg src='internal-roxen-robodog' rotate-ccw='20'/>
</ex>
<ex>
<cimg src='internal-roxen-robodog' rotate-ccw='90'/>
</ex>
</attr>

<attr name='rotate-unit' value='rad|deg|ndeg|part' default='deg'>
 Select the unit to use while rotating.

<table>
<tr><td>rad</td><td>Radians</td></tr>
<tr><td>deg</td><td>Degrees</td></tr>
<tr><td>ndeg</td><td>'New' degrees (400 for each full rotation)</td></tr>
<tr><td>part</td><td>0 - 1.0 (1.0 == full rotation)</td></tr>
</table>
<ex>
<cimg src='internal-roxen-robodog' rotate-ccw='1.2' rotate-unit='rad'/>
</ex>
<ex>
<cimg src='internal-roxen-robodog' rotate-ccw='20' rotate-unit='deg'/>
</ex>
<ex>
<cimg src='internal-roxen-robodog' rotate-ccw='0.2' rotate-unit='part'/>
</ex>
</attr>

<attr name='mirror-x' value='0|1' default='0'>
 Mirror the image around the X-axis.
<ex>
<cimg src='internal-roxen-robodog' mirror-x='1'/>
</ex>
</attr>

<attr name='mirror-y' value='0|1' default='0'>
 Mirror the image around the Y-axis.
<ex>
<cimg src='internal-roxen-robodog' mirror-y='1'/>
</ex>
</attr>

<attr name='scale' value='fact' default='1.0'>
 Scale fact times. (0.5 -> half size, 2.0 -> double size)
<ex>
<cimg src='internal-roxen-robodog' scale='0.5'/>
</ex>
<ex>
<cimg src='internal-roxen-robodog' scale='1.2'/>
</ex>
</attr>

<attr name='scale' value='x,y'>
 Scale to the exact size x,y. If either of X or Y is zero, the image
 is scaled to the specified width or hight, and the value that is zero
 is scaled in proportion to the other value.
<ex>
<cimg src='internal-roxen-robodog' scale='10,40'/>
</ex>
<ex>
<cimg src='internal-roxen-robodog' scale='100,0'/>
</ex>
<ex>
<cimg src='internal-roxen-robodog' scale='0,10'/>
</ex>
<ex>
<cimg src='internal-roxen-robodog' scale='100,10'/>
</ex>
</attr>

<attr name='max-width' value='xsize'>
 If width is larger than 'xsize', scale width to 'xsize' while
 keeping aspect.
<ex>
<cimg src='internal-roxen-robodog'  max-width='300'/>
</ex>
<ex>
<cimg src='internal-roxen-robodog' max-width='100'/>
</ex>
</attr>

<attr name='max-height' value='ysize'>
 If width is larger than 'ysize', scale width to 'ysize' while
 keeping aspect.
<ex>
<cimg src='internal-roxen-robodog' max-height='300'/>
</ex>
<ex>
<cimg src='internal-roxen-robodog' max-height='30'/>
</ex>
</attr>

<attr name='x-offset' value='pixels' default='0'>
 Cut n pixels from the beginning of the X scale.
<ex>
<cimg src='internal-roxen-robodog' x-offset='10'/>
</ex>
<ex>
<cimg src='internal-roxen-robodog' x-offset='50'/>
</ex>
</attr>

<attr name='y-offset' value='pixels' default='0'>
 Cut n pixels from the beginning of the Y scale.
<ex>
<cimg src='internal-roxen-robodog' y-offset='10'/>
</ex>
<ex>
<cimg src='internal-roxen-robodog' y-offset='30'/>
</ex>
</attr>

<attr name='x-size' value='pixels' default='whole image'>
 Keep n pixels from the beginning of the X scale.
<ex>
<cimg src='internal-roxen-robodog' x-size='100'/>
</ex>
</attr>

<attr name='y-size' value='pixels' default='whole image'>
 Keep n pixels from the beginning of the Y scale.
<ex>
<cimg src='internal-roxen-robodog' y-size='30'/>
</ex>
<ex>
<cimg src='internal-roxen-robodog' y-size='100'/>
</ex>
</attr>

<attr name=crop value='x0,y0-x1,y1' default='whole image'>
 Crop the image by specifying the pixel coordinates.
<ex>
<cimg src='internal-roxen-robodog' crop='50,00-150,20'/>
</ex>
<ex>
<cimg src='internal-roxen-robodog' crop='50,28-150,92'/>
</ex>
<ex>
<cimg src='internal-roxen-robodog' crop='0,0-200,20'/>
</ex>
<ex>
<cimg src='internal-roxen-robodog' crop='0,28-200,92'/>
</ex>
</attr>

<h1>Format specific attributes</h1>

<attr name='jpeg-quality' value='percentage' default='75'>
 Set the quality on the output jpeg image.
<ex>
<cimg src='internal-roxen-robodog' format='jpeg' jpeg-quality='100'/>
</ex>
<ex>
<cimg src='internal-roxen-robodog' format='jpeg' jpeg-quality='30'/>
</ex>
<ex>
<cimg src='internal-roxen-robodog' format='jpeg' jpeg-quality='1'/>
</ex>
</attr>

<attr name='jpeg-optimize' value='0|1' default='1'>
 If 0, do not generate optimal tables. Somewhat faster, but produces
 bigger files.
</attr>

<attr name='jpeg-progressive=' value='0|1' default='0'>
 Generate progressive jpeg images.
</attr>

<attr name='jpeg-smooth' value='0-100' default='0'>
 Smooth the image while compressing it. This produces smaller files,
 but might undo the effects of dithering.
<ex>
<cimg src='internal-roxen-robodog' format='jpeg' jpeg-quality='10' jpeg-smooth='0'/>
</ex>
<ex>
<cimg src='internal-roxen-robodog' format='jpeg' jpeg-quality='10' jpeg-smooth='100'/>
</ex>
</attr>

<attr name='bmp-bpp' value='1,4,8,24' default='24'>
 Force this number of bits per pixel for bmp images.
</attr>

<attr name='bmp-windows' value='0|1' default='1'>
 Windows or OS/2 mode, default is 1. (windows mode)
</attr>

<attr name='bmp-rle' value='0|1' default='0'>
 RLE 'compress' the BMP image.
</attr>

<attr name='gd-alpha_index' value='color' default='0'>
 Color in the colormap to make transparent for GD-images with alpha
 channel.
</attr>

<attr name='pcx-raw' value='1|0' default='0'>
 If 1, do not RLE encode the PCX image.
</attr>

<attr name='pcx-dpy' value='0-10000000.0' default='75.0'>
 Resolution, in pixels per inch.
</attr>

<attr name='pcx-xdpy' value='0-10000000.0' default='75.0'>
 Resolution, in pixels per inch.
</attr>

<attr name='pcx-ydpy' value='0-10000000.0' default='75.
 Resolution, in pixels per inch.
</attr>

<attr name='pcx-xoffset' value='0-imagexsize-2' default='0'>
 Offset from start of image data to image content for PCX images.
 Unused by most programs.
</attr>

<attr name='pcx-yoffset' value='0-imageysize-2' default='0'>
 Offset from start of image data to image content for PCX images.
 Unused by most programs.
</attr>

<attr name='tga-raw' value='1|0' default='0'>
 If 1, do not RLE encode the Targa image.
</attr>

<attr name='ps-dpi' value='0-10000000.0' default='75.0'>
 Dots per inch for the resulting postscript file.
</attr>";
constant tagdoc=(["cimg":#"
<desc tag><short>Convert and manuipulate images between different image
formats.</short> The <tag>cimg</tag> makes it is possible to convert, alter size, and transform images between many formats.</desc>

<attr name='src' value='uri' required>
 The path to the indata file.

<ex><cimg src='internal-roxen-robodog'/></ex>
</attr>

<attr name='data' value='imagedata'>
 Insert images from other sources, e.g. databases through entities or
 variables.
<ex type='box'>
<emit source='sql' query='select imagedata from images where id=37'>
<cimg data='&sql.imagedata;'/>
</emit>
</ex>
</attr>"+imagecache,

"cimg-url":#"<desc tag><short>This tag generates an URI to the manipulated
picture.</short> <tag>cimg-url</tag> takes the same attributes as
<tag>cimg</tag> including the image cache attributes. The use for the
tag is to insert image-URI's into various places, e.g. a submit-box.
</desc>

<attr name='src' value='uri' required>
 The path to the indata file.

<ex><cimg-url src='internal-roxen-robodog'/></ex>
</attr>

<attr name='data' value='imagedata'>
 Insert images from other sources, e.g. databases through entities or
 variables.
<ex type='box'>
<emit source='sql' query='select imagedata from images where id=37'>
<cimg-url data='&sql.imagedata;'/>
</emit>
</ex>
</attr>"+imagecache,
		]);

/*
      "Provides a tag 'cimg'. Usage: "
      "&lt;cimg src=\"indata file\" format=outformat [quant=numcolors] [img args]&gt;",
*/
#endif

void start()
{
  the_cache = roxen.ImageCache( "cimg", generate_image );
}

mapping generate_image( mapping args, RequestID id )
{
  if( args->data )
    return roxen.low_decode_image( args->data );
  else
    return roxen.low_load_image( args->src, id );
}

mapping find_internal( string f, RequestID id )
{
  return the_cache->http_file_answer( f, id );
}

mapping get_my_args( mapping args, object id )
{
  mapping a=
  ([
    "src":(args->src?Roxen.fix_relative( args->src, id ):0),
    "quant":args->quant,
    "crop":args->crop,
    "format":args->format,
    "maxwidth":args->maxwidth,
    "maxheight":args->maxheight,
    "scale":args->scale,
    "dither":args->dither,
    "gamma":args->gamma,
    "data":args->data,
  ]);

  a["background-color"] = id->misc->defines->bgcolor 
                          || "#eeeeee";

  foreach( glob( "*-*", indices(args)), string n )
    a[n] = args[n];

  return a;
}

string tag_cimg( string t, mapping args, RequestID id )
{
  mapping a = get_my_args( args, id );
  args -= a;
  args->src = query_internal_location()+the_cache->store( a,id );
  if( mapping size = the_cache->metadata( a, id, 1 ) )
  {
    // image in cache (1 above prevents generation on-the-fly)
    args->width = size->xsize;
    args->height = size->ysize;
  }
  return Roxen.make_tag( "img", args );
}

string tag_cimg_url( string t, mapping args, RequestID id )
{
  return query_internal_location()+the_cache->store(get_my_args(args,id),id);
}
