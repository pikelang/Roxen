// This file is part of rimage. Copyright � 1998 - 2009, Roxen IS.

constant doc="Convert the channel to a greyscale image";

void render(mapping args, mapping this, string channel, object id, object m)
{
  m->set_channel( this, channel, m->get_channel( this, channel )->grey() );
}
