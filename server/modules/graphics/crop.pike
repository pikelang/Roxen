#include <module.h>
inherit "module";
inherit "roxenlib";

roxen.ImageCache the_cache;

array register_module()
{
   return 
   ({ 
      MODULE_PARSER,
      "Image converter",
      "Provides a tag 'cimg'. Usage: "
      "<cimg src=indata format=outformat [quant=numcolors] [img args]>",
      0,1
   });
}

void start()
{
  the_cache = roxen.ImageCache( "crop", generate_image );
}


mapping generate_image( mapping args, RequestID id )
{
  mapping q = roxen.low_load_image( args->src, id );
  if(!q || !q->img) return 0;
  if( q->alpha )
    q->alpha = q->alpha->copy( (int)args->fromx, (int)args->fromy,
                               (int)args->tox, (int)args->toy );
  q->img = q->img->copy( (int)args->fromx, (int)args->fromy,
                         (int)args->tox, (int)args->toy );
  return q;
}
