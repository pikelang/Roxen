constant doc="Makes an grey-scale image, for alpha-channel use. The specified channel is scannedd from the given 'x' and 'y' coordinate, filled with 255 if the color is the same, or 255 minus distance in the colorcube, squared, rightshifted 8 steps (see distance). When the edge distance is reached, the scan is stopped. Default 'edge' value is 30. This value is squared and compared with the square of the distance above.";

void render(mapping args, mapping this, string channel, object id, object m)
{
  if(!this[channel]) return;
  this[channel]=this[channel]->select_from((int)args->x,(int)args->y,(int)args->edge||30);
}
