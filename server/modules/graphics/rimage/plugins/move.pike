constant doc="Move the selected layer with dx,dy pixels.";

void render( mapping args, mapping this, string channel, object id, object m)
{
  int dx = (int)args->dx;
  int dy = (int)args->dy;
  if(!this[channel]) return;
  this[channel] = this[channel]->copy( -dx,-dy, 
				       this[channel]->xsize()-dx-1,
				       this[channel]->ysize()-dy-1);
}
