#include <module.h>

string cvs_verison = "$Id: draw_things.pike,v 1.16.2.1 1997/03/02 19:10:36 grubba Exp $";


object (Image.image) load_image(string f)
{
  object file = files.file();
  string data;
  object img = Image.image();

//  werror("Loading "+f+"\n");

  if(!file->open("roxen-images/modules/"+f,"r"))
  {
    perror("Image things: Failed to open file ("+f+").\n");
    return 0;
  }

  if(!(data=file->read(0x7fffffff)))
    return 0;

  if(img->frompnm(data))
    return img->modify_by_intensity(0,1,0,
				    ({0,0,20}),({0,1,40}),({0,2,60}),
				    ({0,8,80}),({0,16,100}),({0,32,120}),
				    ({0,64,140}),({0,128,160}),({8,128,160}),
				    ({16,128,180}),({32,168,200}),({64,188,220}),
				    ({128,208,240}),({200,228,256}));

//  werror("Failed to parse image file.\n");
  
  return 0;
}

#define PASTE(X,Y) do{\
  if(X){knappar->paste(X,cxp,0);cxp+=X->xsize();}\
  if(strlen(Y)) {\
    object f = font->write(Y)->scale(0.45);\
    knappar->paste_mask(Image.image(f->xsize(),f->ysize()),f,cxp-f->xsize()-4,-1);\
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

object (Image.image) draw_module_header(string name, int type, object font)
{
  object result = Image.image(1000,48);
  object knappar = Image.image(1000,48);
  object text;
  int cxp = 0;
  text = font->write(name)->color(255,255,0);
  
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

  result->paste(knappar,result->xsize()-knappar->xsize(),0);
  result->line(0,0,1000,0,255,255,0);
  result->paste(text,6,3);
  knappar = 0;
  text=0;

//  result = result->autocrop(10,0,0,1,1);
//  result = bevel(result, 4);
  result = result->scale(0.5);
  return result;
}

#define TABSIZE 15

#define R 0x00
#define G 0x40
#define B 0x80

#define dR 0x00
#define dG 0x06
#define dB 0x30


#define bR 0x00
#define bG 0x50
#define bB 0x90

#define btR 0xff
#define btG 0xff
#define btB 0xff

#define bhR 0x00
#define bhG 0xaa
#define bhB 0xff

#define tR 0xff
#define tG 0xff
#define tB 0x88

#define hR 0
#define hG 0xa0
#define hB 0xff

object (Image.image) draw_config_button(string name, object font, int lm, int rm)
{
  if(!strlen(name)) return Image.image(1,15,dR, dG, dB);

  object txt = font->write(name)->scale(0.48);
  object ruta = Image.image(txt->xsize()+25, 20, bR, bG, bB);
  object linje = Image.image(2,30, rm?0:bhR,rm?0:bhG,rm?0:bhB);

  linje=linje->setcolor(0,0,0)->line(0,0,0,30);
  linje=linje->setcolor(bR,bG,bB)->rotate(-25)->copy(0,3,29,28);

  ruta->paste_alpha(linje, 50);
  ruta->paste_mask(Image.image(txt->xsize(),20,btR,btG,btB), txt, 22, 0);

  if(lm)
  {
    object s=ruta->select_from(0,0);
    ruta->paste_mask(Image.image(25,20, dR,dG,dB), s, 0,0);
  }
  if(rm)
  {
    object s=ruta->select_from(20,18);
    ruta->paste_mask(Image.image(200,20, dR,dG,dB), s, 0,0);
  }
  txt=linje=0;
  return ruta->scale(0,15);
}

object (Image.image) draw_unselected_button(string name, object font)
{
  if(!strlen(name)) return Image.image(1,15, R,G,B);

  object txt = font->write(name)->scale(0.48);
  object ruta = Image.image(txt->xsize()+40, 20, R, G, B), s;
  object linje = Image.image(2,30, hR,hG,hB);
  object linje_mask = Image.image(2,30, 128,128,128);

  linje_mask=linje_mask->setcolor(0,0,0)->rotate(-25)->copy(0,3,29,28);
  
  ruta=ruta->paste_mask(Image.image(txt->xsize(),20,tR,tG,tB), txt, 20, 0);
  ruta=ruta->paste_mask(Image.image(30,20,hR,hG,hB), linje_mask);
  s=ruta->select_from(0,0);
  ruta->paste_mask(Image.image(40,40,dR,dG,dB), s);
  linje_mask = linje_mask->mirrory()->color(196,196,196);
  ruta->paste_mask(Image.image(20,20,0,0,0), linje_mask,txt->xsize()+27,0);
  s=ruta->select_from(txt->xsize()+34,0);
  ruta->paste_mask(Image.image(400,40,dR,dG,dB), s);
  txt=linje=0;
  ruta = ruta->line(0,ruta->ysize()-2,ruta->xsize(),ruta->ysize()-2,R,G,B);
  ruta = ruta->line(0,ruta->ysize()-1,ruta->xsize(),ruta->ysize()-1,hR/2,hG/2,hB/2);
  return ruta->scale(0,TABSIZE);
}

object (Image.image) draw_selected_button(string name, object font)
{
  if(!strlen(name)) return Image.image(1,15, dR, dG, dB);

  object txt = font->write(name)->scale(0.48);
  object ruta = Image.image(txt->xsize()+40, 20, dR, dG, dB), s;
  object linje = Image.image(2,30, hR,hG,hB);
  object linje_mask = Image.image(2,30, 128,128,128);

  linje_mask=linje_mask->setcolor(0,0,0)->rotate(-25)->copy(0,3,29,28);
  
  ruta=ruta->paste_mask(Image.image(txt->xsize(),20,tR,tG,tB), txt, 20, 0);
  ruta=ruta->paste_mask(Image.image(30,20,hR,hG,hB), linje_mask);
  linje_mask = linje_mask->mirrory()->color(128,128,128);
  ruta->paste_mask(Image.image(20,20,0,0,10), linje_mask,txt->xsize()+27,0);
  txt=linje=0;
  return ruta->scale(0,TABSIZE);
}


object pil(int c)
{
  object f=Image.image(50,50,dR,dG,dB);
  f->setcolor(c?255:bR,c?255:bG,c?bR:bB);
  for(int i=1; i<25; i++)
    f->line(25-i,i,25+i,i);
  return f;
}

object draw_unfold(int c)
{
  return pil(c)->setcolor(dR,dG,dB)->rotate(-90)->scale(15,0);
}

object draw_fold(int c)
{
  return pil(c)->setcolor(dR,dG,dB)->rotate(-180)->scale(15,0);
}

object draw_back(int c)
{
  object f=pil(1)->color(0,255,255)->setcolor(0,255,0);
  for(int i=0; i<10; i++){
    f=f->line(25-i,24,25-i,50);
    f=f->line(25+i,24,25+i,50);
  }
  f->setcolor(0,dG,dB);
  f=f->rotate(45)->autocrop()->scale(15,0)->autocrop(5, 0,1,0,0, dR,dG,dB);
  return f;
}
