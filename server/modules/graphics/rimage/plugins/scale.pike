constant doc = "If channel is 'image', scale both channels in the layer by 'scale', or to the explicit 'width' and/or 'height'. If the mask is used, scale the mask only.";

void render(mapping args, mapping this, string channel, object id, object m)
{
  if(!this[channel]) return;
  if(args->width || args->height)
  {
    if(channel == "image")
    {
      if(this->mask) 
	this->mask = this->mask->scale( (int)args->width, (int)args->height );
    }
    this[channel] = this[channel]->scale( (int)args->width, (int)args->height );
    return;
  }
  
  if(args->scale)
  {
    if(channel == "image")
    {
      if(this->mask) 
	this->mask = this->mask->scale( (float)args->scale );
    }
    this[channel] = this[channel]->scale( (float)args->scale );
    return;
  }
}
