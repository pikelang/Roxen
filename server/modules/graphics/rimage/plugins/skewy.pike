// This file is part of rimage. Copyright © 1998 - 2009, Roxen IS.

constant doc = "If channel is 'image', skews both channels in the layer by 'amount' pixels. Otherwise skew the mask only.";

void render(mapping args, mapping this, string channel, object id, object m)
{
  int amnt = (int)args->amount;
  object i = m->get_channel( this, channel );
  object a = m->get_channel( this, "alpha" );

  if(!i) return;

  if(channel == "image")
  {
    m->set_channel( this, "image", i->skewy_expand( amnt ));
    m->set_channel( this, "alpha", a->skewy( amnt ));
  } else {
    m->set_channel( this, channel, i->skewy( amnt ));
  }
}
