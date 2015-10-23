// This file is part of rimage. Copyright © 1998 - 2009, Roxen IS.

constant doc="Move the selected layer with dx,dy pixels.";

void render( mapping args, mapping this, string channel, object id, object m)
{
  int dx = (int)args->dx;
  int dy = (int)args->dy;
  if(!dx && !dy) return;

  object i = m->get_channel( this, channel );
  i = i->copy( -dx,-dy, this[channel]->xsize()-dx-1, this[channel]->ysize()-dy-1);
  m->set_channel( this, channel, i );
}
