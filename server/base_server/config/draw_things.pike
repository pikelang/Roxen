#include <module.h>
import Image;

constant Image = image;
string cvs_verison = "$Id: draw_things.pike,v 1.23 1997/08/12 23:09:19 per Exp $";


object (Image) load_image(string f)
{
  object file = files.file();
  string data;
  object img = image();

//  werror("Loading "+f+"\n");

  if(!file->open("roxen-images/modules/"+f,"r"))
  {
    perror("Image things: Failed to open file ("+f+").\n");
    return 0;
  }

  if(!(data=file->read(0x7fffffff)))
    return 0;

  if(img->frompnm(data))
    return img->scale(0,48);
//  werror("Failed to parse image file.\n");
  
  return 0;
}

#define PASTE(X,Y) do{\
  /*if(!first_icon){knappar->paste(pad,cxp,0);cxp+=pad->xsize();}*/\
  if(X){knappar->paste(X,cxp,0);cxp+=X->xsize();first_icon=0;}\
  if(strlen(Y)) {\
    object f = font->write(Y)->scale(0.45);\
    knappar->paste_mask(Image(f->xsize(),f->ysize()),f,cxp-f->xsize()-4,-1);\
   }\
 }while(0)

#define first_filter  load_image("1stfilt.ppm")
#define last_filter   load_image("lastfilt.ppm")
#define last          load_image("last.ppm")
#define first         load_image("first.ppm")
#define dir           load_image("dir.ppm")
#define location      load_image("find.ppm")
#define extension     load_image("extension.ppm")
#define logger        load_image("log.ppm")
#define proxy         load_image("proxy.ppm")
#define security      load_image("security.ppm")
#define tag           load_image("tag.ppm")
#define fade          load_image("fade.ppm")
#define pad           load_image("padding.ppm")

object (Image) draw_module_header(string name, int type, object font)
{
  object result = Image(1000,48);
  object knappar = Image(1000,48);
  object text;
  int cxp = 0, first_icon;
  text = font->write(name);
  first_icon=1;PASTE(fade,"");first_icon=1;
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
//result->line(0,0,1000,0,255,255,0);
  result->paste_alpha_color(text, 255,255,0, 6,3);
  knappar = 0;
  text=0;

//  result = result->autocrop(10,0,0,1,1);
//  result = bevel(result, 4);
  result = result->scale(0.5);
  return result;
}

#define TABSIZE 15

#define R 11
#define G 33
#define B 77

#define dR 0xff
#define dG 0xff
#define dB 0xff


// 0x88, 0xcc, 0xaa
// 11, 33, 77

#define bR 11
#define bG 33
#define bB 77

#define btR 0xff
#define btG 0xff
#define btB 0xff

#define bhR 0x00
#define bhG 0x60
#define bhB 0xff

#define tR 0xff
#define tG 0xff
#define tB 0x88

#define hR 0
#define hG 0xa0
#define hB 0xff

object (Image) draw_config_button(string name, object font, int lm, int rm)
{
  if(!strlen(name)) return Image(1,15,dR, dG, dB);

  object txt = font->write(name)->scale(0.48);
  object ruta = Image(txt->xsize()+25, 20, bR, bG, bB);
  object linje = Image(2,30, rm?0:bhR,rm?0:bhG,rm?0:bhB);

  linje=linje->setcolor(0,0,0)->line(0,0,0,30);
  linje=linje->setcolor(bR,bG,bB)->rotate(-25)->copy(0,3,29,28);

  ruta->paste_alpha(linje, 50);
  ruta->paste_mask(Image(txt->xsize(),20,btR,btG,btB), txt, 22, 0);

  if(lm)
  {
    object s=ruta->select_from(0,0);
    ruta->paste_mask(Image(25,20, dR,dG,dB), s, 0,0);
    ruta->setpixel(0,0, dR, dG, dB);
  }
  if(rm)
  {
    object s=ruta->select_from(20,18);
    ruta->paste_mask(Image(200,20, dR,dG,dB), s, 0,0);
    ruta->setpixel(20,18, dR, dG, dB);
  }
  txt=linje=0;
  return ruta->scale(0,15);
}

object (Image) draw_unselected_button(string name, object font)
{
  if(!strlen(name)) return Image(1,15, R,G,B);

  object txt = font->write(name)->scale(0.48);
  object ruta = Image(txt->xsize()+40, 20, 11, 33, 77), s;
  object linje = Image(2,30, hR,hG,hB);
  object linje_mask = Image(2,30, 128,128,128);

  linje_mask=linje_mask->setcolor(0,0,0)->rotate(-25)->copy(0,3,29,28);
  
  ruta=ruta->paste_mask(Image(txt->xsize(),20,255,255,255), txt, 20, 0);
  ruta=ruta->paste_mask(Image(30,20,0,0,0), linje_mask);
  s=ruta->select_from(0,0);
  ruta->paste_mask(Image(40,40,dR,dG,dB), s);
  ruta->setpixel(0,0, dR, dG, dB);
  linje_mask = linje_mask->mirrory()->color(196,196,196);
  ruta->paste_mask(Image(20,20,0,0,0), linje_mask,txt->xsize()+27,0);
  s=ruta->select_from(txt->xsize()+34,0);
  ruta->paste_mask(Image(400,40,dR,dG,dB), s);
  ruta->setpixel(txt->xsize()+34,0, dR, dG, dB);
  txt=linje=0;
  ruta = ruta->line(0,ruta->ysize()-2,ruta->xsize(),ruta->ysize()-2,R,G,B);
  ruta = ruta->line(0,ruta->ysize()-1,ruta->xsize(),ruta->ysize()-1,hR/2,hG/2,hB/2);
  return ruta->scale(0,TABSIZE);
}

object (Image) draw_selected_button(string name, object font)
{
  if(!strlen(name)) return Image(1,15, R,G,B);

  object txt = font->write(name)->scale(0.48);
  object ruta = Image(txt->xsize()+40, 20, 0x88, 0xcc, 0xaa), s;
  object linje = Image(2,30, hR,hG,hB);
  object linje_mask = Image(2,30, 128,128,128);

  linje_mask=linje_mask->setcolor(0,0,0)->rotate(-25)->copy(0,3,29,28);
  
  ruta=ruta->paste_mask(Image(txt->xsize(),20,0,0,0), txt, 20, 0);
  ruta=ruta->paste_mask(Image(30,20,0,0,0), linje_mask);
  s=ruta->select_from(0,0);
  ruta->paste_mask(Image(40,40,dR,dG,dB), s);
  ruta->setpixel(0,0, dR, dG, dB);
  linje_mask = linje_mask->mirrory()->color(196,196,196);
  ruta->paste_mask(Image(20,20,0,0,0), linje_mask,txt->xsize()+27,0);
  s=ruta->select_from(txt->xsize()+34,0);
  ruta->paste_mask(Image(400,40,dR,dG,dB), s);
  ruta->setpixel(txt->xsize()+34,0, dR, dG, dB);
  txt=linje=0;
  ruta = ruta->line(0,ruta->ysize()-2,ruta->xsize(),ruta->ysize()-2,R,G,B);
  ruta = ruta->line(0,ruta->ysize()-1,ruta->xsize(),ruta->ysize()-1,hR/2,hG/2,hB/2);
  return ruta->scale(0,TABSIZE);
}


object pil(int c)
{
  object f=Image(50,50,dR,dG,dB);
  f->setcolor(c?200:bR,c?0:bG,c?0:bB);
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
  object f=Image(50,50,dR,dG,dB);
  f->setcolor(0,0,100);
  for(int i=1; i<25; i++)
    f->line(25-i,i,25+i,i);
  return f->setcolor(255,255,255)->rotate(45)->autocrop()->scale(15,0);
}
