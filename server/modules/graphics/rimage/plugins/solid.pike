constant doc = 
"If there already is an image in the channel, add a 'width' x 'height' "
"pixels big solid box with the color 'color' at 'xpos', 'ypos', otherwise"
" create the channel as a 'width' x 'height' solid  'color' colored box";

void render( mapping args, mapping this, string channel, object id, object m )
{
  int xs = (int)(args->width  || this->width);
  int ys = (int)(args->height || this->height);
  int xp = (int)args->xpos;
  int yp = (int)args->ypos;
  array (int) color = Colors.parse_color( args->color || "black" );

  if(!args->replace && this[channel])
  {
    if(!args["nomask"] && channel == "image")
      this->mask->box( xp,yp,xp+xs-1,yp+ys-1, 255,255,255, 255-(int)this->alpha);
    this[channel]->box( xp,yp,xp+xs-1,yp+ys-1, @color, 
			255-(int)this->alpha);
  }
  else
  {
    if(!args["nomask"] && channel == "image")
      this->mask = Image.image(xs,ys,255,255,255);
    this[channel] = Image.image( xs,ys, @color );
  }
}
