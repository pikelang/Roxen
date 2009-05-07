// This file is part of rimage. Copyright © 1998 - 2009, Roxen IS.

constant doc="Colorize an image. The red, green and blue values of the pixels are multiplied with the given color. This works best on a grey image.";

void render( mapping args, mapping this, string channel, object id, object m )
{
  Image.Image i = m->get_channel( this, channel );
  if( i )
    i = i->color( Image.Colors[args->color||"red"] );
  m->set_channel( this, channel, i );
}

