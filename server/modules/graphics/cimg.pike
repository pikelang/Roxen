// This is a roxen module. Copyright © 1999 - 2000, Roxen IS.
//

#include <module.h>
inherit "module";
constant thread_safe=1;

roxen.ImageCache the_cache;

constant cvs_version = "$Id: cimg.pike,v 1.25 2000/08/22 19:00:25 nilsson Exp $";
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
<desc tag><short>Manipulates and converts images between different image
formats.</short> Provides the tag <tag>cimg</tag> that makes it is possible to convert,
resize, crop and in other ways transform images.</desc>

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
<emit source='sql' query='select imagedata from images where id=37'>
<cimg data='&sql.imagedata;'/>
</emit>
</ex>
</attr>",
]);
#endif


void start()
{
  the_cache = roxen.ImageCache( "cimg", generate_image );
}

mapping(string:function) query_action_buttons() {
  return ([ "Clear cache":flush_cache ]);
}

void flush_cache() {
  the_cache->flush();
}

string status() {
  array s=the_cache->status();
  return sprintf("<b>Images in cache:</b> %d images<br />\n<b>Cache size:</b> %s",
		 s[0]/2, Roxen.sizetostring(s[1]));
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

mapping get_my_args( mapping args, RequestID id )
{
  mapping a=
  ([
    "src":Roxen.fix_relative( args->src, id ),
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

  if( a->src )
    catch 
    {
      array st = id->conf->stat_file(a->src, id) || file_stat(a->src);
      if (st) {
	a->mtime = (string) (a->stat = st[ST_MTIME]);
	a->filesize = (string) st[ST_SIZE];
      }
    };

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

    res->src = (query_internal_location()+the_cache->store( a,id ));
    data = the_cache->data( a, id , 0 );
    res["file-size"] = strlen(data);
    res["file-size-kb"] = strlen(data)/1024;
    res["data"] = data;
    res |= the_cache->metadata( a, id, 0 ); // enforce generation
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
      mapping a = get_my_args( check_args( args ), id );
      args -= a;
      args->src = query_internal_location()+the_cache->store( a,id );
      if( mapping size = the_cache->metadata( a, id, 1 ) )
      {
	// image in cache (1 above prevents generation on-the-fly)
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
      result = query_internal_location()+
             the_cache->store(get_my_args(check_args( args ), id ),id);
      return 0;
    }
  }
}
