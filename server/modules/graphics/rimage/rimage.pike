// This is a roxen module. Copyright © 1998 - 2009, Roxen IS.

#include <module.h>
inherit "roxenlib";
inherit "module";

/*  ------------------------------------------- MODULE GLUE */

constant module_type = MODULE_TAG;
constant module_name = "Image manipulator";
constant module_doc  = 
#"Provides the <tt>&lt;rimage&gt;</tt> tag that is used for layer base image
manipulations. It also comes with plugin support.";

/*  --------------------------------------- RENDERING FUNCTIONS */

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

Image.Image assert_size( Image.Image in, int x, int y )
{
  if( in->xsize() < x || in->ysize() < y )
    return in->copy( 0,0, x-1, y-1 );
}

Image.Image get_channel( Image.Layer from, string channel )
{
  if(channel == "mask") channel="alpha";
  return from[channel]();
}

Image.Layer add_channel( Image.Layer to, string channel, object img, int xp, int yp )
{
  Image.Image i = get_channel( to, channel );
  if(!i)
  {
    if(!xp && !yp)
      i = img;
    else
    {
      i = Image.Image( img->xsize()+xp, img->ysize()+yp );
      i->paste( img, xp, yp );
    }
  }
  else
  {
    i = assert_size( i, img->xsize()+xp, img->ysize()+yp );
    i->paste( img, xp, yp );
  }
  set_channel( to, channel, i );
}

Image.Layer set_channel( Image.Layer in, string channel, Image.Image from )
{
  if(channel == "mask") channel="alpha";
  mapping q = ([ "image":in->image(), "alpha":in->alpha() ]);
  q[channel] = from;

  int x, y;
  if( q->image )
  {
    x = q->image->xsize();
    y = q->image->ysize();
  }
  if( q->alpha )
  {
    if( q->alpha->xsize() > x )
      x = q->alpha->xsize();
    if( q->alpha->ysize() > y )
      y = q->alpha->ysize();
  }

  if( q->image )
    q->image = assert_size( q->image, x, y );
  if( q->alpha )
    q->alpha = assert_size( q->alpha, x, y );

  in->set_image( q->image, q->alpha );

  return in;
}

mixed internal_tag_image(string t, mapping m, int line,
			 object id, Image.Layer this)
{
  string c = m->channel||"image";
  mixed r = plugin_for( t )( m, this, c, id, this_object() );
  if(stringp(r)) return r;
}

string internal_parse_layer(string t, mapping m, string c, int line,
			    object id, mapping res)
{
  Image.Layer l = Image.Layer();

  if( m->tiled ) l->set_tiled( 1 );
  if( m->mode ) l->set_mode( m->mode );
  l->set_offset( (int)m->xpos, (int)m->ypos );
  l->set_alpha_value( 1.0 - ((float)m->opaque_value/100.0) );

  if( m->width && m->height )
    l->set_image( Image.Image( (int)m->width, (int)m->height ),
                  Image.Image( (int)m->width, (int)m->height ) );


  /* generate the image and the mask.. */
  array q = available_plugins();
  parse_html_lines( c, mkmapping(q,({internal_tag_image})*sizeof(q)), ([]), id, l );
  /* done. Post process the images. */

  if(l->xsize() > res->xsize)   res->xsize = l->xsize();
  if(l->ysize() > res->ysize)   res->ysize = l->ysize();
  res->layers += ({ l });
}

mapping low_render_image(string how, object id)
{
  mapping res = ([ "layers":({}) ]);
  Image.Layer l;

  parse_html_lines( how, ([]), ([ "layer":internal_parse_layer]), id, res );

  l = Image.lay( res->layers );

  res = ([
    "xsize":l->xsize(),
    "ysize":l->ysize(),
    "image":l->image(),
    "alpha":l->alpha(),
    "type":"image/png",
  ]);

  res->image = l;
  return res;
}

mapping render_image(string how, object id)
{
  mapping res = low_render_image( how, id );
  res->data = Image.PNG.encode( res->image, res );
  m_delete(res, "image");
  m_delete(res, "alpha");
  return res;
}


/*  ------------------------------------- IMAGE CACHE FUNCTIONS */
mapping cached_image(string hmm, object id)
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

mapping cache_image(string hmm, mapping val)
{
  rm( query("cache-dir")+hmm );
  Stdio.write_file( query("cache-dir")+hmm, encode_value( val ) );
}

/*  -------------------------- 'INTERNAL' MODULE FUNCTIONS */

mapping find_internal(string f, object id)
{
  int oimc = id->misc->cacheable;
  mapping res;
  id->misc->cacheable = 4711;

  if(res = cached_image( f, id ))
    return res;

  mixed e;
  e = catch
  {
    mapping r = render_image( roxen.argcache.lookup( f )[0], id );
    if(id->misc->cacheable == 4711)
    {
      cache_image( f, r );
      id->misc->cacheable = oimc;
    }
    return r;
  };
//   uncache_img( f );
  throw( e );
}

/*  --------------------------------------- RXML GLUE FUNCTIONS */

string container_rimage_id( string t, mapping m, string contents, object id )
{
  mapping q = ([ 0:contents ]);
  string i = roxen.argcache.store( q );

  if( mapping t = cached_image( i, id ) )
  {
    m->width = (string)t->xsize;
    m->height = (string)t->ysize;
  }
  return query_absolute_internal_location(id) + i;
}

string container_rimage(string t, mapping m, string contents, object id)
{
  m->src = container_rimage_id( t, m, contents, id );
  int xml=!m->noxml;
  m_delete(m, "noxml");
  return make_tag( "img", m, xml );
}
