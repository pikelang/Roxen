constant doc = "If channel is 'image', rotates both channels in the layer by 'degree' degrees. Otherwise rotate the mask only.";

void render(mapping args, mapping this, string channel, object id, object m)
{
  float degrees = (float)args->degrees;
  if(channel == "mask")
  {
    if(this->mask)
      this->mask = this->mask->rotate(degrees, 0,0,0);
    return;
  }

  if(!this->image)
    return;

  if(!this->mask)
    this->mask = Image.image( this->image->xsize(), 
			      this->image->ysize(),
			      255,255,255 );
  this->image = this->image->rotate_expand(degrees);
  this->mask  = this->mask->rotate( degrees, 0,0,0 );
}
