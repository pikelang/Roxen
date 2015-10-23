// This file is part of rimage. Copyright © 1998 - 2009, Roxen IS.

constant doc = "If channel is 'image', scale both channels in the layer by 'scale', or to the explicit 'width' and/or 'height'. If the mask is used, scale the mask only.";

void render(mapping args, mapping this, string channel, object id, object m)
{
  object i = m->get_channel( this, channel );
  object a = m->get_channel( this, "alpha" );

  if(!i) return;

  if(args->width || args->height)
  {
    m->set_channel( this, channel, i->scale( (int)args->width, (int)args->height ));
    if(channel == "image")
      m->set_channel( this, "alpha", a->scale( (int)args->width, (int)args->height ))
    return;
  }

  if(args->scale)
  {
    m->set_channel( this, channel, i->scale( (float)args->scale ));
    if(channel == "image")
      m->set_channel( this, "alpha", a->scale( (float)args->scale  ))
    return;
  }
}
