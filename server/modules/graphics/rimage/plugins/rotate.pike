// This file is part of rimage. Copyright © 1998 - 2009, Roxen IS.

constant doc = "If channel is 'image', rotates both channels in the layer by 'degree' degrees. Otherwise rotate the mask only.";

void render(mapping args, mapping this, string channel, object id, object m)
{
  float degrees = (float)args->degrees;

  if((degrees%360.0) == 0.0)
    return;

  if(channel != "image")
  {
    m->set_channel( this, channel, m->get_channel( this, channel )->rgb2hsv() );
    return;
  }

  object i = m->get_channel( this, "image" );
  if(!i) return;
  object a = m->get_channel(this,"alpha")||Image.Image(i->xsize(),i->ysize(),255,255,255);

  m->set_channel( this, "image", i->rotate_expand(degrees) );
  m->set_channel( this, "alpha", a->rotate(degrees,0,0,0) );
}
