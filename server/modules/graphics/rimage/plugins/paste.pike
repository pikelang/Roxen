constant doc = "paste the 'image' slot over the current channel at xpos, ypos, using 'alpha' (defaults to solid) as a transparency mask";

void render(mapping args, mapping this, string channel, object id, object m)
{
  if(!this[channel]) return;
  object i = id->misc[ "__pimage_"+args->image ];
  if(!i) return;
  object a = id->misc[ "__pimage_"+args->alpha ];

  int xp = (int)args->xpos;
  int yp = (int)args->ypos;
  
  if(a)
    this[channel] = this[channel]->paste_mask( i, a, xp, yp );
  else
    this[channel] = this[channel]->paste( i, xp, yp );
}
