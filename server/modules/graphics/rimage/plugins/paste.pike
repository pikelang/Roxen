// This file is part of rimage. Copyright © 1998 - 2009, Roxen IS.

constant doc = "paste the 'image' slot over the current channel at xpos, ypos, using 'alpha' (defaults to solid) as a transparency mask";

void render(mapping args, mapping this, string channel, object id, object m)
{
  object i = id->misc[ "__pimage_"+args->image ];
  if(!i) return;
  object a = id->misc[ "__pimage_"+args->alpha ];

  int xp = (int)args->xpos;
  int yp = (int)args->ypos;

  object i = m->get_channel( this, channel );

  if( a )
    i = i->paste_mask( i, a, xp, yp );
  else
    i = i->paste( i, xp, yp );
  m->set_channel( this, channel, i );
}
