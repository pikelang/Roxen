// This file is part of rimage. Copyright © 1998 - 2009, Roxen IS.

inherit "roxenlib";
string doc="Load an image. NOTE: If the current layer is the 'image' layer this function can modify _both_ the mask and image layers if the loaded image has a alpha channel. Specify the image with the 'file' argument. The image can recide in roxen's virtual filesystem.";


void render( mapping args, mapping this,
	     string channel, object id, object m )
{
  mapping t = ([]);
  int xp = (int)args->xpos;
  int yp = (int)args->ypos;

  t = roxen.low_load_image( fix_relative( m->file, id ), id );
  m->add_channel( this, channel, t->img, xp, yp );
  if( channel == "image"  && t->alpha )
    m->add_channel( this, "alpha", t->alpha, xp, yp );
}
