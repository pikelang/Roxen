/*
 * $Id: pie.pike,v 1.1 1997/09/06 01:45:59 hedda Exp $
 *
 * Makes pie-idagrams
 *
 * $Author: hedda $
 */

constant cvs_version="$Id: pie.pike,v 1.1 1997/09/06 01:45:59 hedda Exp $";
constant thread_safe=1;

#include <module.h>
inherit "module";
inherit "roxenlib";

/*
 * Functions
 */
#!/usr/local/bin/pike

#define PI 3.14159265358979
//inherit Stdio;

import Image;
import Array;
import Stdio;

// This function draws an image of a cake with sectors
// propotional to the numbers in "numbers".
// The strings in names are written near the cake-sectors.
// If twoD is != 0 the diagram becomes ugly.


object cake_diagram_draw(int|void  size, array(int|float) numbers, 
			 void | array(string) names, void|int twoD, 
			 void|array(array(int)) colors,
			 array(int)bg, array(int)fg,int tone)
{
  object* text;
  object notext;
  int ymaxtext;
  int xmaxtext;

  object cake;
  int imysize;
  int imxsize;
  float *arr=allocate(802);
  float *arr2=allocate(802);

  int yc;
  int xc;
  int xr;
  int yr;

  mixed sum;
  int sum2;

  int* pnumbers=allocate(sizeof(numbers));
  int* order=indices(numbers);

  int edge_nr=0;


  if (names!=0)
    if (sizeof(names)!=sizeof(numbers))
      names=0;
  if (colors)
    {
      if (sizeof(colors)<sizeof(numbers))
	colors=0;
      foreach( colors, mixed color)
	if (sizeof(color)!=3)
	  colors=0;
    }
  if (!(size))
    size=400;


  //create the text objects
  if (names)
    text=allocate(sizeof(names));

  if (names)
    if (notext=get_font("avant_garde", 32, 0, 0, "left",0,0))
      for(int i=0; i<sizeof(names); i++)
	{
	  //if (names[i]=="")
	    //names[i]="Fel så inåt helvete";
	  text[i]=notext->write((string)(names[i]));
	  if (xmaxtext<(text[i]->xsize()))
	    xmaxtext=text[i]->xsize();
	  if (ymaxtext<(text[i]->ysize()))
	    ymaxtext=text[i]->ysize();
	  
	}
  //skapa en array med fyra hundra koordinater
  if (twoD)
    yc=size/2;
  else
    yc=size/3;
  xc=size/2;
  xr=xc-5;
  yr=yc-3;
  yc+=ymaxtext;
  xc+=xmaxtext+15;

  cake=image(imxsize=30+size+xmaxtext*2, 
	     imysize=(int)(size*((twoD!=0)+2.0)/3.0+30+ymaxtext*2+1), @bg);

  //Initiate the cake!
  for(int i=0; i<401; i++)
    {
      arr[2*i]=xc+xr*sin((i*2.0*PI/400.0+0.0001));
      arr[1+2*i]=yc+yr*sin(0.0001-PI/2+i*2.0*PI/400.0);
      arr2[2*i]=xc+(xr+4)*sin((i*2.0*PI/400.0+0.0001));
      arr2[2*i+1]=yc+(4+yr)*sin(0.0001-PI/2+i*2.0*PI/400.0);
    }

  
  //write(sprintf("%O", arr));

  //initiate the % for different numbers:
  sum=`+(@ numbers);
  for(int i=0; i<sizeof(numbers); i++)
    {
      float t=(float)(numbers[i]*400)/sum;
      pnumbers[i]=(int)floor(t);
      numbers[i]=t-floor(t);
    }
  //Now the rests are in the numbers-array
  sort(numbers, order);
  sum2=`+(@ pnumbers);
  int i=sizeof(pnumbers);
  while(sum2<400)
    {
      pnumbers[order[--i]]++;
      sum2++;
    }  


  edge_nr=0;

  if (colors)
    {
      //Colours are given!
      for(int i=0; i<sizeof(pnumbers); i++)
	{
	  cake=cake->setcolor(@ colors[i]);
	  cake=cake->polygone(({(float)xc,(float)yc})+
			      arr[2*edge_nr..2*(edge_nr+pnumbers[i]+2)+1]);
	  edge_nr+=pnumbers[i];
	}
    }
  else
    {
      int** carr=allocate(sizeof(numbers));
      int steg=128+128/(sizeof(numbers));
      if (1==sizeof(numbers))
	carr=({({39,155,102})});
      else
      if (2==sizeof(numbers))
	carr=({({190, 180, 0}), ({39, 39, 155})});
      else
      if (3==sizeof(numbers))
	carr=({({155, 39, 39}), ({39, 39, 155}), ({42, 155, 39})});
      else
      if (4==sizeof(numbers))
	carr=({({155, 39, 39}), ({39, 66, 155}), ({180, 180, 0}), ({39, 155, 102})});
      else
      if (5==sizeof(numbers))
	carr= ({({155, 39, 39}), ({39, 85, 155}), ({180, 180, 0}), ({129, 39, 155}), ({39, 155, 80})});
      else
     if (6==sizeof(numbers))
	carr= ({({155, 39, 39}), ({39, 85, 155}), ({180, 180, 0}), ({74, 155, 39}), ({100, 39, 155}), ({39, 155, 102})});
      else
     if (7==sizeof(numbers))
	carr= ({({155, 39, 39}), ({39, 85, 155}), ({180, 180, 0}), ({72, 39, 155}), ({74, 155, 39}), ({155, 39, 140}), ({39, 155, 102})});
      else
      if (8==sizeof(numbers))
	carr=({({155, 39, 39}), ({39, 110, 155}), ({180, 180, 0}), ({55, 39, 155}), ({96, 155, 39}), ({142, 39, 155}), ({39, 155, 69}), ({80, 39, 155})}) ;
      else
      if (9==sizeof(numbers))
	carr= ({({155, 39, 39}), ({39, 115, 155}), ({155, 115, 39}), ({39, 39, 155}), ({118, 155, 39}), ({115, 39, 155}), ({42, 155, 39}), ({155, 39, 118}), ({39, 155, 112})});
      else
      if (10==sizeof(numbers))
	carr=({({155, 39, 39}), ({39, 121, 155}), ({155, 104, 39}), ({39, 55, 155}), ({140, 155, 39}), ({88, 39, 155}), ({74, 155, 39}), ({130, 24, 130}), ({39, 155, 69}), ({180, 180, 0})}) ;
      else
      if (11==sizeof(numbers))
	carr=({({155, 39, 39}), ({39, 123, 155}), ({155, 99, 39}), ({39, 63, 155}), ({150, 155, 39}), ({74, 39, 155}), ({91, 155, 39}), ({134, 39, 155}), ({39, 155, 47}), ({155, 39, 115}), ({39, 155, 107})}) ;
      else
      if (12==sizeof(numbers))
	carr=({({155, 39, 39}), ({39, 126, 155}), ({155, 93, 39}), ({39, 72, 155}), ({155, 148, 39}), ({61, 39, 155}), ({107, 155, 39}), ({115, 39, 155}), ({53, 155, 39}), ({155, 39, 140}), ({39, 155, 80}), ({155, 39, 85})}) ;
      else
	/*
      if (3==sizeof(numbers))
	carr= ;
      else
      if (3==sizeof(numbers))
	carr= ;
      else
      if (3==sizeof(numbers))
	carr= ;
      else
      if (3==sizeof(numbers))
	carr= ;
      else
      if (3==sizeof(numbers))
	carr= ;
      else
      if (3==sizeof(numbers))
	carr= ;
      else
      if (3==sizeof(numbers))
	carr= ;
      else*/
	{
	  //No colours given!
	  //Now we have the %-numbers in pnumbers
	  //Lets create a colourarray carr
	  for(int i=0; i<sizeof(numbers); i++)
	    {
	      carr[i]=Colors.hsv_to_rgb((i*steg)%256,190,155);
	    }
	}
      edge_nr=0;
      for(i=0; i<sizeof(carr); i++)
	{
	  cake=cake->setcolor(@ carr[i]);
	  cake=cake->polygone(({(float)xc,(float)yc})+
			      arr[2*edge_nr..2*(edge_nr+pnumbers[i]+2)+1]);
	  edge_nr+=pnumbers[i];
	}
      
    }
  
  edge_nr=pnumbers[0];


  //black borders
  cake=cake->setcolor(0,0,0);
  cake=cake->polygone(({xc+(arr[2]-arr[0])/2
			  ,yc+(arr[3]-arr[1])/2
			  })+
		      ({xc-(arr[2]-arr[0])/2
			  ,yc-(arr[3]-arr[1])/2
			  , arr[-2], arr[-1], arr[2], arr[3]}));
		      
			  
  for(int i=1; i<sizeof(pnumbers); i++)
    {
      cake=cake->polygone(({xc+(arr[2*edge_nr+2]-arr[2*edge_nr])/2
		 	      ,yc+(arr[2*edge_nr+3]-arr[2*edge_nr+1])/2
			      })+
			  ({xc-(arr[2*edge_nr+2]-arr[2*edge_nr])/2
			      ,yc-(arr[2*edge_nr+3]-arr[2*edge_nr+1])/2
			      })+
			  			  
			  arr[2*edge_nr..2*(edge_nr+1)+1]);
      edge_nr+=pnumbers[i];
    }
  cake=cake->polygone(arr+arr2);
  

  cake=cake->setcolor(255,255,255);
  
  //And now some shading!
  if (!twoD)
    {
      object below;
      int *b=({70,70,70});
      int *a=({0,0,0});
      
      
      object tbild;
      /*
	tbild=image(imxsize, 1, 255, 255, 255)->
	tuned_box(0, 0 , 1, imysize,
	({a,a,b,b}))->scale(imxsize, imysize);
	//400ms
	*/
      if(tone)
	{
	  tbild=image(64, imysize, 255, 255, 255)->
	    tuned_box(0, 0 , 1, imysize,
		      ({a,a,b,b}));
	  tbild=tbild->paste(tbild->copy(0,0,0, imysize), 1, 0);
	  tbild=tbild->paste(tbild->copy(0,0,1, imysize), 2, 0);
	  tbild=tbild->paste(tbild->copy(0,0,3, imysize), 4, 0);
	  tbild=tbild->paste(tbild->copy(0,0,7, imysize), 8, 0);
	  tbild=tbild->paste(tbild->copy(0,0,15, imysize), 16, 0);
	  if (imxsize>32)
	    tbild=tbild->paste(tbild->copy(0,0,31, imysize), 32, 0);
      
	  if (imxsize>64)
	    tbild=image(imxsize, imysize, 255, 255, 255)->
	      paste(tbild->copy(0,0,63, imysize), 0, 0)->
	      paste(tbild->copy(0,0,63, imysize), 64, 0);
	  if (imxsize>128)
	    tbild=tbild->paste(tbild->copy(0,0,128, imysize), 128, 0);
	  if (imxsize>256)
	    tbild=tbild->paste(tbild->copy(0,0,256, imysize), 256, 0);
	  if (imxsize>512)
	    tbild=tbild->paste(tbild->copy(0,0,512, imysize), 512, 0);
	  cake+=tbild;
	}
      
      float* arr3;
      float* arr4;
      float* arr5;
      
      
      //Draw the border below.
      arr3=arr2[200..601];
      for(int i=1; i<402; i+=2)
	arr3[i]+=30.0;

      arr4=arr3[0..200];
      arr5=arr3[0..200];
      for(int  i=0; i<201; i++)
	{
	  arr4[i]=arr3[i*2];
	  arr5[i]=arr3[i*2+1];
	}
      arr4=reverse(arr4);
      arr5=reverse(arr5);
      int j=0;

      for(int i=0; i<201; i++)
	{
	  arr3[j++]=arr4[i];
	  arr3[j++]=arr5[i];
	}


      below=image(imxsize, imysize, 0, 0, 0)->setcolor(255,255,255)->
	polygone(arr3+arr2[200..601]);
      
      b=({155,155,155});
      a=({0,0,0});
      
      object tbild;
      
      tbild=image(imxsize, imysize, 255, 255, 255)->
	tuned_box(0,0, imxsize/2, 1,
		  ({a,b,a,b}))->tuned_box(imxsize/2, 0, imxsize, 1,
					  ({b,a,b,a}));
		  tbild=tbild->paste(tbild->copy(0,0,imxsize, 0),0, 1);
		  
		  tbild=tbild->paste(tbild->copy(0,0,imxsize, 1),0, 2);
		  tbild=tbild->paste(tbild->copy(0,0,imxsize, 3),0, 4);
		  tbild=tbild->paste(tbild->copy(0,0,imxsize, 7),0, 8);
		  tbild=tbild->paste(tbild->copy(0,0,imxsize, 15),0, 16);
		  if (tbild->ysize()>32)
		    tbild=tbild->paste(tbild->copy(0,0,imxsize, 31),0, 32);
		  if (tbild->ysize()>64)
		    tbild=tbild->paste(tbild->copy(0,0,imxsize, 63),0, 64);
		  if (tbild->ysize()>128)
		    tbild=tbild->paste(tbild->copy(0,0,imxsize, 127),0, 128);
		  if (tbild->ysize()>256)
		    tbild=tbild->paste(tbild->copy(0,0,imxsize, 255),0, 256);
		  if (tbild->ysize()>512)
		    tbild=tbild->paste(tbild->copy(0,0,imxsize, 511),0, 512);
		  
		  cake=cake->paste_mask(below&tbild, below);
	
	    

    }

  
  //write the text!
  int place;
  sum=0;
  if (names)
    for(int i=0; i<sizeof(pnumbers); i++)
      {
	int t;
	sum+=pnumbers[i];
	place=sum-pnumbers[i]/2;
	cake=cake->setcolor(255,0, 0);
	t=(place<202)?15:-15-text[i]->xsize();
	if (place<20) t-=7;
	else if (place>380) t+=7;
	else if ((place>180)&&(place<202)) t-=7;
	else if ((place>=202)&&(place<220)) t+=7;
	if ((place>190)&&(place<202)) t-=4;
	if ((place>=202)&&(place<210)) t+=4;
	if (place<10) t-=4;
	if (place>390) t+=4;
	
	int yt=0;
	if ((place>120)&&(place<280))
	  yt=(int)(34*sin(2*PI*(float)(place-100)/400.0));
	if ((place<=80)||(place>=320)) yt-=ymaxtext;
	else
	  if (!((place>=120)&&(place<=280))) yt-=ymaxtext/2;
	
	
	int x=(int)(arr2[2*place]+t);
	int y=(int)arr[2*place+1]+yt;
	cake=cake->paste_alpha_color(text[i], @fg, x, y);
      }


  return cake; 

}


void sort_dia_data(array(float|int) numbers, array(mixed) names)
{
  if (sizeof(numbers)<5)
    return;
  if (sizeof(numbers)!=sizeof(names))
    return;
  float* tnums;
  tnums=numbers+({});
  sort(tnums, names);
  array(mixed) tnames;
  tnames=names+({});

  for(int i=0; i<sizeof(numbers)/2; i++)
    {
      numbers[i]=tnums[-i*2-2];
      names[i]=tnames[-i*2-2];
    }
  
  numbers[sizeof(numbers)/2]=tnums[-1];
  names[sizeof(numbers)/2]=tnames[-1];
  for(int i=sizeof(numbers)/2+1; i<sizeof(numbers); i++)
    {
      int j;
      numbers[sizeof(numbers)+sizeof(numbers)/2-i]=tnums[j=-(i-sizeof(numbers)/2)*2-1];
      names[sizeof(numbers)+sizeof(numbers)/2-i]=tnames[j];
    }

  tnums=numbers+({});
  tnames=names+({});

  numbers[0]=tnums[-1];
  names[0]=tnames[-1];
  numbers[-1]=tnums[0];
  names[-1]=tnames[0];
 
  int j=sizeof(numbers)/2-2;
  int i=1+j%2; 
  for(; 
      i<j; i+=2, j-=2)
    {
      numbers[i]=tnums[j];
      names[i]=tnames[j];
      numbers[j]=tnums[i];
      names[j]=tnames[i];
    }

  int i=sizeof(numbers)/2+2;
  int j=sizeof(numbers)-(0==(sizeof(numbers)+i)%2)-2; 
  for(; 
      i<j; i+=2, j-=2)
    {
      numbers[i]=tnums[j];
      names[i]=tnames[j];
      numbers[j]=tnums[i];
      names[j]=tnames[i];
    }

   
  return;
}

array register_module()
{
  return(({ MODULE_PARSER|MODULE_LOCATION, "Pie-diagrams", 
	      "Adds a tag which draws pie-diagrams.<br>\n"
	      "Usage:<br>\n"
	      "<ul><pre>&lt;pie height=<i>height of pie in pixels</i> 2D/3D NOSORT/SORT TONE/NOTONE"
	      "&gt;\n(400, 3D, SORT and NOTONE is default)\n"
	      "&lt;slice size=<i>number</i>&gt;<i>any text</i>&lt;/slice&gt;\n"
	      "&lt;slice size=<i>number</i>&gt;<i>any text</i>&lt;/slice&gt;\n"
	      "...\n"
	      "&lt;/pie&gt;\n</pre></ul>"
	      "The numbers can be percent or not and can be integers or floats. 2D "
	      "makes the pie appear in 2D. If the NOSORT option is present "
	      "no change of the order of the slices will take place. Without NOSORT "
	      "the slices will be reordered in a way that makes it possible to write the slice-texts near them. If TONE is given the pie will be more white at the front.\n"
	      , 0, 1 }));
}

void create()
{
  defvar("location", "/pie/", "Mountpoint", TYPE_LOCATION|VAR_MORE,
	 "The URL-prefix for the pies.");
}

string tag_slice(string t, mapping a, string contents, mapping res)
{
  if (!a->size) {
    return 0;
  }
  if (!res->slices) {
    res->slices = ({ ({ a->size, contents }) });
  } else {
    res->slices += ({ ({ a->size, contents }) });
  }
  return("");
}

string tag_pie(string t, mapping a, string contents, object id, object f, mapping defines)
{
  mapping res = ([]);
  if(a->help) return register_module()[2];
  parse_html(contents, ([]), (["slice":tag_slice]), res);
  res->twod=a["2d"] || a->twod;
  res->nosort = a->nosort || a["no-sort"];
  res->tone = a->tone;
  res->size=(int)(a->height)||400;
  res->bg = parse_color(defines->bg || "#e0e0e0");
  res->fg = parse_color(defines->fg || "black");

  m_delete(a, "twod");
  m_delete(a, "nosort");
  m_delete(a, "width");
  m_delete(a, "height");
  
  a->src = QUERY(location) + MIME.encode_base64(encode_value(res)) + ".gif";

  return(make_tag("img", a));
}


mapping query_container_callers()
{
  return ([ "pie":tag_pie ]);
}
 
mapping find_file(string f, object id)
{
  if (f[sizeof(f)-4..] == ".gif") {
    f = f[..sizeof(f)-5];
  }
  //catch {
    mapping res = decode_value(MIME.decode_base64(f));
    
    object(Image.image) img;
    array (int) bg = res->bg, fg = res->fg;
    array (float) numbers;
    array (string) texts;
    numbers=Array.map(column(res->slices,0),lambda(mixed v){return (float)v; });
    texts=column(res->slices,1);

    if (res->nosort==0)
      sort_dia_data(numbers, texts);
    
    img=cake_diagram_draw(res->size, numbers, texts, 0!=res->twod,0,bg,fg,res->tone);
    img = img->map_closest(img->select_colors(254)+({bg}));
    return http_string_answer(img->togif(@bg), "image/gif");
    
  //};

  
  return 0;
}


