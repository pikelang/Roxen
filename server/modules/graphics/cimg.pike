// This is a roxen module. Copyright © 1999 - 2009, Roxen IS.
//

#include <module.h>
inherit "module";
constant thread_safe=1;

roxen.ImageCache the_cache;

constant cvs_version = "$Id$";
constant module_type = MODULE_TAG;
constant module_name = "Graphics: Image converter";
constant module_doc  = "Provides the tag <tt>&lt;cimg&gt;</tt> that can be used "
"to convert images between different image formats.";


mapping tagdocumentation()
{
  Stdio.File file=Stdio.File();
  if(!file->open(__FILE__,"r")) return 0;
  mapping doc = compile_string("#define manual\n"+file->read(), __FILE__)->tagdoc;
  foreach(({ "cimg", "cimg-url" }), string tag)
    doc[tag] += the_cache->documentation(tag +
					 " src='/internal-roxen-testimage'");
  return doc;
}

#ifdef manual
constant tagdoc=(["cimg":#"<desc tag='tag'><p><short>
 Manipulates and converts images between different image
 formats.</short> Provides the tag <tag>cimg</tag> that makes it is
 possible to convert, resize, crop and in other ways transform
 images. It is possible to pass attributes, such as the alt attribute, 
 to the resulting tag by including them in the cimg tag. </p>
</desc>

<attr name='src' value='url' required='required'><p>
 The path to the indata file.</p>

<ex><cimg src='/internal-roxen-testimage'/></ex>
</attr>

<attr name='filename' value='string'><p>
Append the filename value to the path. Recommended is not to append file suffix
to the filename since there are settings for handling that automatically through
this module settings.
</p><p>This is useful if you want to have images indexed, since many search engines
uses the filename as a description of the image.</p>
<ex><cimg-url src='/internal-roxen-testimage' filename='Roxen Test Image'/></ex>
</attr>

<attr name='data' value='imagedata'><p>
 Insert images from other sources, e.g. databases through entities or
 variables.</p>
<ex-box><emit source='sql' query='select imagedata from images where id=37'>
<cimg data='&sql.imagedata:none;'/>
</emit></ex-box>
</attr>

<attr name='process-all-layers'><p>Set this flag to make all image layers
visible regardless of their original state.</p>
</attr>

<attr name='include-layers' value='layer-glob-list'><p>Comma-separated list
of glob expressions which is matched against layer names. All matching
layers are made visible regardless of their original state.</p>
</attr>

<attr name='exclude-layers' value='layer-glob-list'><p>Comma-separated list
of glob expressions which is matched against layer names. All matching
layers are hidden regardless of their original state.</p>
</attr>

<attr name='exclude-invisible-layers'><p>Set this flag to
automatically exclude layers that are not shown in the original
image. This is only useful in combination with the
'process-all-layers' attribute.</p>
</attr>

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
</attr>
",

"cimg-url":#"<desc tag='tag'><p><short>
 This tag generates an URL to the manipulated picture.</short>
 <tag>cimg-url</tag> takes the same attributes as <xref
 href='cimg.tag' />, including the image cache attributes. The use for
 the tag is to insert image-URLs into various places, e.g. a
 submit-box.</p>
</desc>

<attr name='src' value='url' required='required'><p>
 The path to the indata file.</p>

<ex><cimg-url src='/internal-roxen-testimage'/></ex>
</attr>

<attr name='data' value='imagedata'><p>
 Insert images from other sources, e.g. databases through entities or
 variables.</p>
<ex-box><emit source='sql' query='select imagedata from images where id=37'>
  <cimg-url data='&sql.imagedata;'/>
</emit></ex-box>
</attr>

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
</attr>",

"emit#cimg":({ #"<desc type='plugin'><p><short>
 Entitybased version of <xref href='../graphics/cimg.tag' />.</short>
 Takes the same attributes as <tag>cimg</tag>.</p>
</desc>

<attr name='nodata' value='yes | no'><p>
 Controls suppression of <ent>_.data</ent> in the output. Useful for
 reducing memory consumption in cached emit tags. The default value
 is 'no'.</p>
</attr>",

([
"&_.type;":#"<desc type='entity'><p>
 Returns the image's content-type.</p>
</desc>",

"&_.src;":#"<desc type='entity'><p>
 Returns the path to the indata file.</p>
</desc>",

"&_.file-size;":#"<desc type='entity'><p>
 Returns the image's file size.</p>
</desc>",

"&_.xsize;":#"<desc type='entity'><p>
 Returns the width of the image.</p>
</desc>",

"&_.ysize;":#"<desc type='entity'><p>
 Returns the height of the image.</p>
</desc>",

"&_.data;":#"<desc type='entity'><p>
 Returns the imagedata given through other sources, like databases
 through entities.</p>
</desc>"
])

}),

]);
#endif

int do_ext;

void create()
{
  defvar("ext", Variable.Flag(0, VAR_MORE,
			      "Append format to generated images",
			      "Append the image format (.gif, .png, "
			      ".jpg, etc) to the generated images. "
			      "This is not necessary, but might seem "
			      "nicer, especially to people who try "
			      "to mirror your site."));
  defvar ("default_args",
	  Variable.Mapping (([]), 0,
			    "Default Arguments",
			    "Arguments to add implicitly to cimg/cimg-url/"
			    "emit#cimg calls. Explicit arguments will take "
			    "precedence over any arguments specified here."));
}

void start()
{
  //  Reuse previous cache object if possible
  if (the_cache) {
    //  Update reference to callback function in case we've been reloaded
    the_cache->set_draw_function(generate_image);
  } else {
    the_cache = roxen.ImageCache( "cimg", generate_image );
  }
  do_ext = query("ext");
}

void stop()
{
  //  Force cache object to be recreated in start()
  destruct(the_cache);
}

mapping(string:function) query_action_buttons() {
  return ([ "Clear Cache":flush_cache ]);
}

void flush_cache() {
  the_cache->flush();
  
  //  It's possible that user code contains a number of stale URLs in
  //  e.g. <cache> blocks so we can just as well flush the RAM cache to
  //  reduce the risk of broken images.
  cache.flush_memory_cache();
}

string status() {
  array s=the_cache->status();
  return sprintf("<b>Images in cache:</b> %d images<br />\n"
                 "<b>Cache size:</b> %s",
		 s[0], Roxen.sizetostring(s[1]));
}

array(Image.Layer)|mapping generate_image( mapping args, RequestID id )
{
  array layers;

  //  Photoshop layers: don't let individual layers expand the image
  //  beyond the bounds of the overall image.
  mapping opts = ([ "crop_to_bounds" : 1 ]);
  
  if( args["process-all-layers"] )
    opts->draw_all_layers = 1;

  if( args["jpeg-shrink" ] )
  {
    opts->scale_denom = (int)args["jpeg-shrink" ];
    opts->scale_num = 1;
  }
  
  if( args->data )
    layers = roxen.decode_layers( args->data, opts );
  else
  {
    mixed tmp;
#if constant(Sitebuilder) && constant(Sitebuilder.sb_start_use_imagecache)
    //  Let SiteBuilder get a chance to decode its argument data
    if (Sitebuilder.sb_start_use_imagecache) {
      Sitebuilder.sb_start_use_imagecache(args, id);
      tmp = roxen.load_layers(args->src, id, opts);
      Sitebuilder.sb_end_use_imagecache(args, id);
    } else
#endif
    {
      tmp = roxen.load_layers(args->src, id, opts);
    }
    
    if (mappingp(tmp)) {
      if (tmp->error == Protocols.HTTP.HTTP_UNAUTH)
	return tmp;
      else
	layers = 0;
    }
    else layers = tmp;
  }

  if(!layers)
  {
    if( args->data )
      RXML.run_error("Failed to decode specified data\n");
    else
      RXML.run_error("Failed to load specified image [%O]\n", args->src);
  }

  if (!sizeof(filter(layers->image(), objectp)))
    RXML.run_error("Failed to decode layers in specified image [%O]\n",
		   args->src);
  if(!args["exclude-invisible-layers"])
     layers->set_misc_value( "visible",1 );
  foreach( layers, Image.Layer lay )
    if( !lay->get_misc_value( "name" ) )
      lay->set_misc_value( "name", "Background" );

  if( args["exclude-layers"] )
  {
    foreach( args["exclude-layers"] / ",", string match )
      foreach( layers, Image.Layer lay )
	if( glob( match, lay->get_misc_value( "name" ) ) )
	  lay->set_misc_value( "visible", 0 );
  }

  if( args["include-layers"] )
  {
    foreach( args["include-layers"] / ",", string match )
      foreach( layers, Image.Layer lay )
	if( glob( match, lay->get_misc_value( "name" ) ) )
	  lay->set_misc_value( "visible", 1 );
  }

  array res = ({});
  foreach( layers, Image.Layer l )
  {
    if( l->get_misc_value( "visible" ) )
      res += ({ l });
  }
  return res;
}

mapping find_internal( string f, RequestID id )
{
  // It's not enough to
  //  1. Only do this check when the ext flag is set, old URLs might
  //     live in caches
  //
  //  2. Check str[-4] for '.', consider .jpeg .tiff etc.
  //
  //  3. Also handle / if filename attribute is used in either tag
  //
  // However, . is not a valid character in the ID, so just cutting at
  // the first one works as well as also cutting at the first /.
  sscanf (f, "%[^./]", f);
  return the_cache->http_file_answer( f, id );
}

mapping get_my_args( mapping args, RequestID id )
{
  mapping a=
  ([
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

  if( args->src ) {
      a->src = Roxen.fix_relative( args->src, id );
      array(int)|Stat st = (id->conf->try_stat_file(a->src, id));
      if (st)
      {
	string fn = id->conf->real_file( a->src, id );
	if( fn ) Roxen.add_cache_stat_callback( id, fn, st[ST_MTIME] );
      	a->mtime = (string) (a->stat = st[ST_MTIME]);
	a->filesize = (string) st[ST_SIZE];
	
#if constant(Sitebuilder) && constant(Sitebuilder.sb_start_use_imagecache)
	//  The file we called try_stat_file() on above may be a SiteBuilder
	//  file. If so we need to extend the argument data with e.g.
	//  current language fork.
	if (Sitebuilder.sb_prepare_imagecache)
	  a = Sitebuilder.sb_prepare_imagecache(a, a->src, id);
#endif
      }
  }

  a["background-color"] = id->misc->defines->bgcolor || "#eeeeee";

  foreach( glob( "*-*", indices(args)), string n ) {
    if (!has_prefix(n, "data-"))
      a[n] = args[n];
  }

  return a;
}

mapping check_args( mapping args )
{
  args = query ("default_args") + args;
  if( !args->format )
    args->format = "png";
  if( !(args->src || args->data) )
    RXML.parse_error("Required attribute 'src' or 'data' missing\n");
  if (args->src == "")
    RXML.parse_error("Attribute 'src' cannot be empty\n");
  if( args->src && args->data )
    RXML.parse_error("Only one of 'src' and 'data' may be specified\n");

  return args;
}

class TagCimgplugin
{
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "cimg";

  array get_dataset( mapping args, RequestID id )
  {
    mapping res = ([ ]);
    mapping a = get_my_args( check_args( args ), id );
    string data;

    int timeout = Roxen.timeout_dequantifier(args);

      // Store misc->cacheable since the image cache can raise it and
      // disable protocol cache.
      int cacheable = id->misc->cacheable;
      int no_proto_cache = id->misc->no_proto_cache;
#ifdef DEBUG_CACHEABLE
      report_debug("%s:%d saved cacheable flags\n", __FILE__, __LINE__);
#endif
      res->src=(query_absolute_internal_location(id)+
		the_cache->store( a, id, timeout ));
      if(args->filename && sizeof(args->filename))
	res->src += "/" + Roxen.http_encode_url(args->filename);
      if(do_ext)
	res->src += "." + a->format;
      data = the_cache->data( a, id , 0 );
      res["file-size"] = strlen(data);
      res["file-size-kb"] = strlen(data)/1024;
      if (lower_case(args->nodata || "no") == "no")
	res["data"] = data;
      res |= the_cache->metadata( a, id, 0, timeout ); // enforce generation
#ifdef DEBUG_CACHEABLE
      report_debug("%s:%d restored cacheable flags\n", __FILE__, __LINE__);
#endif
      id->misc->cacheable = cacheable;
      id->misc->no_proto_cache = no_proto_cache;
      return ({ res });
  }
}

class TagCImg 
{
  inherit RXML.Tag;
  constant name = "cimg";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;

  class Frame
  {
    inherit RXML.Frame;

    array do_return(RequestID id) 
    {
      int timeout = Roxen.timeout_dequantifier(args);
      mapping a = get_my_args( check_args( args ), id );
      args -= a;
      string ext = "";
      string filename = "";
      if(args->filename && sizeof(args->filename))
	filename += "/" + Roxen.http_encode_url(m_delete(args, "filename"));
      if(do_ext)
	ext = "." + a->format;
      args->src = query_absolute_internal_location( id )
	+ the_cache->store( a, id, timeout ) + filename + ext;
      int no_draw = !id->misc->generate_images;
      mapping size;
      if( !args->width && !args->height
	  && (size = the_cache->metadata( a, id, no_draw, timeout )) )
      {
	// image in cache (no_draw above prevents generation on-the-fly)
	args->width = size->xsize;
	args->height = size->ysize;
      }
      int xml=!args->noxml;
      m_delete(args, "noxml");
      result = Roxen.make_tag( "img", args, xml );
      return 0;
    }
  }
}

class TagCImgURL {
  inherit RXML.Tag;
  constant name = "cimg-url";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;

  class Frame 
  {
    inherit RXML.Frame;

    array do_return(RequestID id)
    {
      int timeout = Roxen.timeout_dequantifier(args);
      string filename = "";
      mapping a = get_my_args (check_args (args), id);
      
      if(args->filename && sizeof(args->filename))
	filename = "/" + Roxen.http_encode_url(args->filename);
      result = query_absolute_internal_location(id)
	+ the_cache->store(a, id, timeout)
	     + filename
	     + (do_ext ? "." + a->format : "");
      return 0;
    }
  }
}
