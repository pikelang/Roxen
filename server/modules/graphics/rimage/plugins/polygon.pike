constant doc = "points='x0,y0, x1,y1, ...' color='color'. Draws in the mask channel as well if the current channel is the image channel.";


void render(mapping args, mapping this, string channel, object id, object m)
{
  if(!this[channel]) return;
  array c = Colors.parse_color(args->color||
			       (channel=="mask"?"white":"black" ));
  array points = (array(float))(args->points/",");

  this[channel]->setcolor(@c);
  this[channel]->polyfill( points );

  if(channel == "image")
  {
    if(!this->mask) 
      this->mask = Image.image(this->image->xsize(), this->image->ysize());
    this->mask->setcolor( 255,255,255 );
    this->mask->polyfill( points );
  }
}
