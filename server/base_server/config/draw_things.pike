#include <module.h>

string cvs_verison = "$Id: draw_things.pike,v 1.2 1996/12/02 16:31:32 per Exp $";

object (Image) bevel(object (Image) in, int width)
{
  object vedge_white = Image(width, in->ysize()-width*2, 255,255,255);
  object vedge_black = Image(width, in->ysize()-width, 0,0,0);
  object hedge_white = Image(in->xsize()-width, width, 255,255,255);
  object hedge_black = Image(in->xsize()-width, width, 0,0,0);
  object corner = Image(width+1,width+1);

  for(int i=-1; i<=width; i++)
    corner->line(i,width-i,i,-1, 200,200,200);

  in->paste_alpha(vedge_white, 160, 0, width);
  in->paste_alpha(vedge_black, 128, in->xsize()-width, width);
  in->paste_alpha(hedge_white, 160, 0, 0);
  in->paste_alpha(hedge_black, 128, width, in->ysize()-width);
  in->paste_alpha(corner, 128, in->xsize()-width,0);
  in->paste_alpha(corner, 128, -1, in->ysize()-width);
  vedge_white=vedge_black=hedge_white=hedge_black=0;

  return in;
}

object (Image) load_image(string f)
{
  object file = File();
  string data;
  object img = Image();
//  werror("Loading "+f+"\n");
  if(!file->open("roxen-images/modules/"+f,"r"))
  {
    perror("Image things: Failed to open file ("+f+").\n");
    return 0;
  }
  if(!(data=file->read(0x7fffffff))) return 0;
  if(img->frompnm(data)) return img;
  if(img->fromgif(data)) return img;
//  werror("Failed to parse image file.\n");
  return 0;
}

#define PASTE(X,Y) do{\
  if(X){knappar->paste(X,cxp,0);cxp+=X->xsize()-3;}\
  if(strlen(Y)) {\
    object f = font->write(Y)->scale(0.4);\
    knappar->paste_mask(Image(f->xsize(),f->ysize()),f,cxp-f->xsize()-4,1);\
  }}while(0)

object first_filter = load_image("1stfilt.ppm");
object last_filter = load_image("lastfilt.ppm");
object last = load_image("last.ppm");
object first = load_image("first.ppm");
object dir = load_image("dir.ppm");
object location = load_image("find.ppm");
object extension = load_image("extension.ppm");
object logger = load_image("log.ppm");
object proxy = load_image("proxy.ppm");
object security = load_image("security.ppm");
object tag = load_image("tag.ppm");

object (Image) draw_module_header(string name, int type, object font)
{
  object result = Image(1000,48);
  object knappar = Image(1000,48);
  object text;
  int cxp = 0;
  text = font->write(name);
  
  if((type&MODULE_AUTH)||(type&MODULE_SECURITY)) PASTE(security,"");
  if(type&MODULE_FIRST) PASTE(first,"First");
  if(type&MODULE_URL) PASTE(first_filter,"Filter");
  if(type&MODULE_PROXY) PASTE(proxy,"Proxy");
  if(type&MODULE_LOCATION) PASTE(location,"Location");
  if(type&MODULE_DIRECTORIES) PASTE(dir,"Dir");
  if((type&MODULE_EXTENSION)||(type&MODULE_FILE_EXTENSION))
    PASTE(extension,"Ext.");
  if(type&MODULE_PARSER) PASTE(tag,"");
  if(type&MODULE_FILTER) PASTE(last_filter,"Filter");
  if(type&MODULE_LAST) PASTE(last,"Last");
  if(type&MODULE_LOGGER) PASTE(logger,"Logger");

  knappar = knappar->autocrop();

#if 0
  result->paste(knappar,(result->xsize()/2)-(knappar->xsize()/2),text->ysize());
  result->paste_mask(Image(100,60,0,0,0), text, knappar->xsize(),0);
#else
  result->paste(knappar,result->xsize()-knappar->xsize(),0);
//  result->paste_mask(Image(600,60,0,0,0), text, 0,5);
  result->paste(text,6,5);
  knappar = 0;
  text=0;
#endif
//  result = result->autocrop(10,0,0,1,1);
//  result = bevel(result, 4);
  result = result->scale(0.5);
  return result;
}

object (Image) draw_config_button(string name, object font)
{
  if(!strlen(name)) return Image(1,15,0xff/2, 0xee/2, 0xaa/2);

  object txt = font->write(name)->scale(0.5);
  object ruta = Image(txt->xsize()+25, 20, 0xff/2, 0xee/2, 0xaa/2);
  object linje = Image(2,30, 255,255,255);

  linje=linje->setcolor(0,0,0)->line(0,0,0,30);

  linje=linje->setcolor(0xff/2, 0xee/2, 0xaa/2)->rotate(-25)->copy(0,3,29,28);

  ruta=ruta->paste_alpha(linje, 50);
  ruta=ruta->paste_mask(Image(txt->xsize(),20), txt, 22, 0);

  txt=linje=0;
  return ruta->scale(0,15);
}
