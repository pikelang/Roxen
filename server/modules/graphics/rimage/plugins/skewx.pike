constant doc = "If channel is 'image', skews both channels in the layer by 'amount' pixels. Otherwise skew the mask only.";

void render(mapping args, mapping this, string channel, object id, object m)
{
  int amnt = (int)args->amount;
  if(channel == "mask")
  {
    if(this->mask)
      this->mask->skewx(amnt, 0,0,0);
    return;
  }

  if(!this->image)
    return;

  if(!this->mask)
    this->mask = Image.image( this->image->xsize(), 
			      this->image->ysize(),
			      255,255,255 );
  this->image->skewx_expand(amnt);
  this->mask->skewx( amnt, 0,0,0 );
}
