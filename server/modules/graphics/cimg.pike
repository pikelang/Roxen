// This is a roxen module. Copyright © 1999 - 2000, Roxen IS.
//

#include <module.h>
inherit "module";
inherit "roxenlib";
constant thread_safe=1;

roxen.ImageCache the_cache;

constant cvs_version = "$Id: cimg.pike,v 1.19 2000/06/01 14:36:47 nilsson Exp $";
constant module_type = MODULE_PARSER;
constant module_name = "Image converter";
constant module_doc  = "Provides the tag <tt>&lt;cimg&gt;</tt> that can be used "
"to convert images between different image formats.";


mapping tagdocumentation() {
  Stdio.File file=Stdio.File();
  if(!file->open(__FILE__,"r")) return 0;
  mapping doc=compile_string("#define manual\n"+file->read())->tagdoc;
  string imagecache=the_cache->documentation("cimg src='internal-roxen-robodog'");

  doc->cimg+=imagecache;
  doc["cimg-url"]=imagecache;
  return doc;
}

#ifdef manual
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
&lt;emit source='sql' query='select imagedata from images where id=37'&gt;
&lt;cimg data='&sql.imagedata;'/&gt;
&lt/emit&gt;
</ex>
</attr>",

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
&lt;emit source='sql' query='select imagedata from images where id=37'&gt;
&lt;cimg data='&sql.imagedata;'/&gt;
&lt/emit&gt;
</ex>
</attr>",
]);
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
    "src":(args->src?fix_relative( args->src, id ):0),
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
  return make_tag( "img", args );
}

string tag_cimg_url( string t, mapping args, RequestID id )
{
  return query_internal_location()+the_cache->store(get_my_args(args,id),id);
}
