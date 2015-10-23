// This file is part of rimage. Copyright © 1998 - 2009, Roxen IS.

constant doc = "restore the current channel from the slot specified by 'from'";

void render(mapping args, mapping this, string channel, object id, object m)
{
  m->set_channel( this, channel, id->misc[ "__pimage_"+args->from ] );
}
