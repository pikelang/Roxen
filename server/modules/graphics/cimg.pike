// This is a ChiliMoon module. Copyright © 1999 - 2001, Roxen IS.
//

#include <module.h>
inherit "module";
constant thread_safe=1;

core.ImageCache the_cache;

constant cvs_version = "$Id: cimg.pike,v 1.59 2004/06/01 22:16:40 _cvs_dirix Exp $";
constant module_type = MODULE_TAG;
constant module_name = "Graphics: Image converter";
constant module_doc  = "Provides the tag <tt>&lt;cimg&gt;</tt> that can be used "
"to convert images between different image formats.";


mapping tagdocumentation()
{
  Stdio.File file=Stdio.File();
  if(!file->open(__FILE__,"r")) return 0;
  mapping doc = compile_string("#define manual\n"+file->read())->tagdoc;
  foreach(({ "cimg", "cimg-url" }), string tag)
    doc[tag] += the_cache->documentation(tag +
					 " src='/*/testimage'");
  return doc;
}

#ifdef manual
constant tagdoc=(["cimg":#"<desc tag='tag'><p><short>
 Manipulates and converts images between different image
 formats.</short> Provides the tag <tag>cimg</tag> that makes it is
 possible to convert, resize, crop and in other ways transform
 images.</p>
</desc>

<attr name='src' value='url' required='required'><p>
 The path to the indata file.</p>

<ex><cimg src='/*/testimage'/></ex>
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
</attr>",

"cimg-url":#"<desc tag='tag'><p><short>
 This tag generates an URL to the manipulated picture.</short>
 <tag>cimg-url</tag> takes the same attributes as <xref
 href='cimg.tag' />, including the image cache attributes. The use for
 the tag is to insert image-URLs into various places, e.g. a
 submit-box.</p>
</desc>

<attr name='src' value='url' required='required'><p>
 The path to the indata file.</p>

<ex><cimg-url src='/*/testimage'/></ex>
</attr>

<attr name='data' value='imagedata'><p>
 Insert images from other sources, e.g. databases through entities or
 variables.</p>
<ex-box><emit source='sql' query='select imagedata from images where id=37'>
  <cimg-url data='&sql.imagedata;'/>
</emit></ex-box>
</attr>",

"emit#cimg":({ #"<desc type='plugin'><p><short>
 Entitybased version of <xref href='../graphics/cimg.tag' />.</short>
 Takes the same attributes as <tag>cimg</tag>.</p>
</desc>",

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
}

void start()
{
  the_cache = core.ImageCache( "cimg", generate_image );
  do_ext = query("ext");
}

mapping(string:function) query_action_buttons() {
  return ([ "Clear cache":flush_cache ]);
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
		 s[0], String.int2size(s[1]));
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
    layers = core.decode_layers( args->data, opts );
  else
  {
    mixed tmp = core.load_layers( args->src, id, opts );
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
      error("Failed to decode specified data\n");
    else
      error("Failed to load specified image [%O]\n", args->src);
  }

  if (!sizeof(filter(layers->image(), objectp)))
    error("Failed to decode layers in specified image [%O]\n", args->src);

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
  // However, . is not a valid character in the ID, so just cutting at
  // the first one works.
  return the_cache->http_file_answer( (f/".")[0], id );
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
    mixed err = catch 
    {
      a->src = Roxen.fix_relative( args->src, id );
      Stdio.Stat st = (id->conf->try_stat_file(a->src, id) 
					|| file_stat(a->src));
      if (st)
      {
	string fn = id->conf->real_file( a->src, id );
	if( fn ) Roxen.add_cache_stat_callback( id, fn, st->mtime );
      	a->mtime = (string) (a->stat = st->mtime);
	a->filesize = (string) st->size;
      }
    };
#ifdef DEBUG
    if (err)
      report_error("<cimg> or <emit#cimg>: error in get_my_args(): %s\n",
		   describe_backtrace(err));
#endif
  }

  a["background-color"] = id->misc->defines->bgcolor || "#eeeeee";

  foreach( glob( "*-*", indices(args)), string n )
    a[n] = args[n];

  return a;
}

mapping check_args( mapping args )
{
  if( !args->format )
    args->format = "png";
  if( !(args->src || args->data) )
    RXML.parse_error("Required attribute 'src' or 'data' missing\n");
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
    mixed err = catch // This code will fail if the image does not exist.
    {
      res->src=(query_absolute_internal_location(id)+the_cache->store( a,id ));
      if(do_ext)
	res->src += "." + (a->format || "gif");
      data = the_cache->data( a, id , 0 );
      res["file-size"] = strlen(data);
      res["file-size-kb"] = strlen(data)/1024;
      res["data"] = data;
      res |= the_cache->metadata( a, id, 0 ); // enforce generation
      return ({ res });
    };
#ifdef DEBUG
    report_error("<emit#cimg> error in get_dataset(): %s\n",
		 describe_backtrace(err));
#endif
    RXML.parse_error( "Illegal arguments or image\n" );
    return ({});
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
      mapping a = get_my_args( check_args( args ), id );
      args -= a;
      string ext = "";
      if(do_ext)
	ext = "." + (a->format || "gif");
      args->src = query_absolute_internal_location( id )
		+ the_cache->store( a, id ) + ext;
      int no_draw = !id->misc->generate_images;
      if( mapping size = the_cache->metadata( a, id, no_draw ) )
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
      result = query_absolute_internal_location(id)
	     + the_cache->store(get_my_args(check_args( args ), id ), id)
	     + (do_ext ? "." + (args->format || "gif") : "");
      return 0;
    }
  }
}
