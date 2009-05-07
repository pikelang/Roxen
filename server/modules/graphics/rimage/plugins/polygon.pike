// This file is part of rimage. Copyright © 1998 - 2009, Roxen IS.

constant doc = "points='x0,y0, x1,y1, ...' color='color'. Draws in the mask channel as well if the current channel is the image channel.";

void render(mapping args, mapping this, string channel, object id, object m)
{
  array c = Colors.parse_color(args->color||
			       (channel=="mask"?"white":"black" ));
  array points = (array(float))(args->points/",");

  i = m->get_channel( this, channel );
  if(!i)
  {
    int x, y;
    for( int q = 0; q<sizeof(points); q+=2 )
    {
      if(points[q] > x)
        x = points[q];
      if(points[q+1] > y)
        y = points[q];
    }
    i = Image.image( x,y );
  }
  i->setcolor(@c);
  i->polyfill( points );
  m->set_channel( this, "image", i );

  if(channel == "image")
  {
    object a = m->get_channel( this, "alpha" );
    if(!a)
      a = Image.image( i->xsize(), i->ysize(), 0, 0, 0 );
    a->setcolor( 255,255,255 );
    a->polyfill( points );
    m->set_channel( this, "alpha", a );
  }
}
