#if __VERSION__ > 0.5
#include <module.h>
inherit "roxenlib";
inherit "module";

/*  ------------------------------------------- MODULE GLUE */
void create(object c)
{
  if(c)
  {
    defvar("location", "/ri/", "The mountpoint", TYPE_LOCATION, "");
    defvar("cache-dir", "../gimage/"+c->short_name( c->name )+"/",
	   "Cache directory", TYPE_STRING, 
	   "Image and argument cache directory.");
  }
}

void start()
{
  mkdirhier(query("cache-dir")+"foo");
}
#endif // __VERSION__ > 0.5

array register_module()
{
#if __VERSION__ > 0.5
  return ({ 
    MODULE_LOCATION|MODULE_PARSER,
    "Roxen image manipulation tag",
    "Layer base image manipulation tag with plugins",
    0,1 
  });
#endif // __VERSION__ > 0.5
} 

#if __VERSION__ > 0.5
/*  --------------------------------------- RENDERING FUNCTIONS */

mapping layer_ops = ([
  "normal":  0,
  "max":     1,
  "min":     2,
  "multiply":3,
  "add":     4,
  "diff":    5,
]);

constant plugin_dir = combine_path(__FILE__, "../plugins/");

mapping plugins = ([]);

object load_plugin( string hmm )
{
  if( file_stat( plugin_dir + hmm + ".pike" ) )
    return compile_file( plugin_dir + hmm + ".pike" )( );
}

function plugin_for( string what )
{
  what = (lower_case(what)-" ");
  if(!plugins[what] && !(plugins[what] = load_plugin( what )))
    error("No such gimage plugin: "+what+"\n");
  return plugins[what]->render;
}

string is_plugin(string what)
{
  if(sscanf(what, "%s.pike", what)==1) return what;
}

array available_plugins()
{
  return Array.map(get_dir(plugin_dir), is_plugin)-({0});
}

mixed internal_tag_image(string t, mapping m, int line, 
			 object id, mapping this)
{
  string c = m->channel||"image";

  mixed r = plugin_for( t )( m, this, c, id, this_object() );

  if(this[c])
  {
    if(this[c]->xsize() >= (int)this->width)
      this->width = this[c]->xsize();
    if(this[c]->ysize() >= (int)this->height)
      this->height = this[c]->ysize();
  }
  if(stringp(r)) return r;
}

string internal_parse_layer(string t, mapping m, string c, int line,
			    object id, mapping res)
{
  mapping this = ([]);

  this->method = layer_ops[m->method];
  this->xpos = (int)m->xpos;
  this->ypos = (int)m->ypos;
  this->opaque_value = (int)(((float)m->opaque_value * 2.55)) || 255;

  if(m->width) 
    this->width = (int)m->width;
  else
    this->width = (int)res->xsize;

  if(m->height) 
    this->height = (int)m->height;
  else
    this->width = (int)res->ysize;

  /* generate the image and the mask.. */
  array q = available_plugins();
  mapping empty = ([ ]);
  parse_html_lines( c, mkmapping(q,({internal_tag_image})*sizeof(q)), 
		    empty, id, this );
  /* done. Post process the images. */
  if(this->image->xsize() > res->xsize)
    res->xsize = this->image->xsize();
  if(this->image->ysize() > res->ysize)
    res->ysize = this->image->ysize();

  res->layers += ({ this });
}

object crop_image(object i, int x, int y)
{
  if(!i) return 0;
  if(i->xsize() == x && i->ysize() == y) return i;
  return i->copy(0,0,x-1,y-1);
}

mapping low_render_image(string how, object id)
{
  mapping res = ([ "layers":({}) ]);

  parse_html_lines( how, ([]), ([ "layer":internal_parse_layer]), id, res );

  object i = Image.image( (int)res->xsize, (int)res->ysize );
  foreach(res->layers, mapping l)
    switch(l->method)
    {
     case 0: /* normal. */
       if(l->opaque_value < 255)
       {
	 if(l->mask)
	   l->mask *= l->opaque_value/255.0;
	 else
	   l->mask = Image.image(l->image->xsize(), l->image->ysize(),
				 l->opaque_value, l->opaque_value,
				 l->opaque_value);
       }
       if(l->mask)
	 i->paste_mask( l->image, l->mask, l->xpos, l->ypos );
       else
	 i->paste( l->image, l->xpos, l->ypos );
       break; 
     case 1:
     case 2:
     case 3:
     case 4:
     case 5:
    }
  res = ([ "xsize":(string)res->xsize,
	   "ysize":(string)res->ysize, 
	   "image":res->image,
	   "type":"image/jpeg" ]);

  res->image = i;
  return res;
}

mapping render_image(string how, object id)
{
  mapping res = low_render_image( how, id );
  object ct = Image.colortable( res->image );
  ct->floyd_steinberg();
  res->data = Image.GIF.encode( res->image, ct );
  m_delete(res, "image");
  return res;
}


/*  ------------------------------------- IMAGE CACHE FUNCTIONS */
mapping cached_image(int hmm, object id)
{
  mapping rv;
  if(rv = cache_lookup("rimage:"+id->conf->name, (string)hmm))
     return rv;
  
  if(file_stat(query("cache-dir")+hmm))
  {
    catch {
      return cache_set("rimage:"+id->conf->name, (string)hmm, 
		       decode_value(Stdio.read_bytes(query("cache-dir")+hmm)));
    };
    rm(query("cache-dir")+hmm);
  }
}

mapping cache_image(int hmm, mapping val)
{
  rm( query("cache-dir")+hmm );
  Stdio.write_file( query("cache-dir")+hmm, encode_value( val ) );
}

/*  ---------------------------------------- LOCATION FUNCTIONS */

mapping find_file(string f, object id)
{
  int img_id = (int)f;
  int oimc = id->misc->cacheable;
  mapping res;
  id->misc->cacheable = 4711;
  if((string)img_id != f)
    return 0;

  if(res = cached_image( img_id, id ))
    return res;
  
  if(!image_ids)
    restore_image_ids();

  if(!image_ids[ img_id ])
    return 0;

  array e;
  e = catch {
    mapping r = render_image( image_ids[ img_id ], id );
    if(id->misc->cacheable == 4711)
    {
      cache_image( img_id, r );
      id->misc->cacheable = oimc;
    }
    return r;
  };
  uncache_img( img_id );
  throw( e );
}

/*  ---------------------------------------- ID CACHE FUNCTIONS */


mapping image_ids;
int next_image_id = time();

void uncache_img(int i)
{
  m_delete(image_ids, image_ids[i]);
  m_delete( image_ids, i );
  rm(query("cache-dir")+i);
}

void restore_image_ids()
{
  image_ids = ([ ]);
  int now = time();
  if( file_stat( query("cache-dir")+"idcache") )
    catch {
      image_ids=decode_value(Stdio.read_bytes(query("cache-dir")+"idcache" ));
    };

  foreach(indices(image_ids), string i)
    if(stringp(i))
    {
      if(image_ids[i][0] >= next_image_id)
	next_image_id = image_ids[i][0];
      if(now-image_ids[i][1] > 3600*24*2)
	uncache_img( image_ids[i][0] );
    }
}

void save_ids()
{
  object f = Stdio.File();
  if(f->open(query("cache-dir")+"idcache", "wct"))
    f->write( encode_value( image_ids ) );
  return 0;
}

array new_image_id(string f)
{
  image_ids[next_image_id+1] = f;
  remove_call_out(save_ids);
  call_out(save_ids, 1);
  return ({ ++next_image_id, time() });
}


/*  --------------------------------------- RXML GLUE FUNCTIONS */

string tag_rimage_id( string t, mapping m, string contents, object id )
{
  array i;
  if(!image_ids) restore_image_ids();

  if(m->nocache || !(i = image_ids[ contents ]))
    i = image_ids[ contents ] = new_image_id( contents );
  else
  {
    i[1] = time(1);
    if( mapping t = cached_image( i[0], id ) )
    {
      m->width = (string)t->xsize;
      m->height = (string)t->ysize;
    }
  }
  return query_location() + i[0];
}

string tag_rimage(string t, mapping m, string contents, object id)
{
  m->src = tag_rimage_id( t, m, contents, id );
  return make_tag( "img", m );
}

mapping query_container_callers()
{
  return ([ 
    "rimage":tag_rimage,
    "rimage-id":tag_rimage_id
  ]);
}
#endif // __VERSION__ > 0.5
