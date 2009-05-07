// This file is part of rimage. Copyright © 1998 - 2009, Roxen IS.

constant doc = "save the current channel to the slot specified by 'to'";

void render(mapping args, mapping this, string channel, object id, object m)
{
  id->misc[ "__pimage_"+args->to ] = m->get_channel( this, channel )->copy();
}
