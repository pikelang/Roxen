#!/usr/local/bin/pike
#define max(i, j) (((i)>(j)) ? (i) : (j))
#define min(i, j) (((i)<(j)) ? (i) : (j))
#define abs(arg) ((arg)*(1-2*((arg)<0)))

#define PI 3.14159265358979
//inherit Stdio;

import Image;
import Array;
import Stdio;
inherit "polyline.pike";
constant LITET = 1.0e-40;
constant STORT = 1.0e40;

inherit "create_graph.pike";



mapping(string:mixed) create_pie(mapping(string:mixed) diagram_data)
{
  //Supportar bara xsize>=100
  int si=diagram_data["fontsize"];

  string where_is_ax;

  object(image) piediagram;


  if (diagram_data["bgcolor"])
    piediagram=image(diagram_data["xsize"],diagram_data["ysize"],
		@(diagram_data["bgcolor"]));
  else
   {
     piediagram=diagram_data["image"];
     diagram_data["xsize"]=diagram_data["image"]->xsize();
     diagram_data["ysize"]=diagram_data["image"]->ysize();
   }
  
  diagram_data["image"]=piediagram;
  setinitcolors(diagram_data);

  set_legend_size(diagram_data);

  //write("ysize:"+diagram_data["ysize"]+"\n");
  diagram_data["ysize"]-=diagram_data["legend_size"];
  //write("ysize:"+diagram_data["ysize"]+"\n");
  
  //Bestäm största och minsta datavärden.
  init(diagram_data);

  //Initiera värden
  int|void  size=diagram_data["xsize"];
  array(int|float) numbers=diagram_data["data"][0];
  void | array(string) names=diagram_data["xnames"];
  void|int twoD=diagram_data["drawtype"]=="2D";
  void|array(array(int)) colors=diagram_data["datacolors"];
  array(int)bg=diagram_data["bgcolor"];
  array(int)fg=diagram_data["textcolor"];
  int tone=diagram_data["tone"];





  //////////////////////



  
  object* text;
  object notext;
  int ymaxtext;
  int xmaxtext;

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


  /*  if (names!=0)
    if (sizeof(names)!=sizeof(numbers))
      names=0;
  if (colors)
    {
      if (sizeof(colors)<sizeof(numbers))
	colors=0;
      else
	foreach( colors, mixed color)
	  if (sizeof(color)!=3)
	    colors=0;
    }
  if (!(size))
    size=400;
  */

  //create the text objects
  if (names)
    text=allocate(sizeof(names));
   

  if (names)
    if (notext=get_font("avant_garde", diagram_data["fontsize"], 0, 0, "left",0,0))
      for(int i=0; i<sizeof(names); i++)
	{
	  //if (names[i]=="")
	    //names[i]="Fel så inåt helvete";
	  text[i]=notext->write((string)(names[i]))
->scale(0,diagram_data["fontsize"])
;
	  if (xmaxtext<(text[i]->xsize()))
	    xmaxtext=text[i]->xsize();
	  if (ymaxtext<(text[i]->ysize()))
	    ymaxtext=text[i]->ysize();
	  
	}
  //skapa en array med fyra hundra koordinater

  //Börja med att räkna ut lite saker
  if (twoD)
    {
      xc=diagram_data["xsize"]/2;
      yc=diagram_data["ysize"]/2;
      xr=min(xc-xmaxtext-ymaxtext-1, yc-2*ymaxtext-1);
      yr=xr;
    }
  else
    {
      xc=diagram_data["xsize"]/2;
      yc=diagram_data["ysize"]/2-diagram_data["3Ddepth"];
      yr=min(xc-xmaxtext-ymaxtext-1-diagram_data["3Ddepth"], yc-2*ymaxtext-1);
      xr=min(xc-xmaxtext-ymaxtext-1, yc+diagram_data["3Ddepth"]-2*ymaxtext-1);
    }
  float w=diagram_data["linewidth"];
  //Initiate the piediagram!
  float FI=(float)(diagram_data["rotate"])*2.0*PI/360.0;
  float most_down=yc+yr+w;
  float most_right=xc+xr+w;
  float most_left=xc-xr-w;

  for(int i=0; i<401; i++)
    {
      arr[2*i]=xc+xr*sin((i*2.0*PI/400.0+0.0001)+FI);
      arr[1+2*i]=yc+yr*sin(0.0001-PI/2+i*2.0*PI/400.0+FI);
      arr2[2*i]=xc+(xr+w)*sin((i*2.0*PI/400.0+0.0001));
      arr2[2*i+1]=yc+(w+yr)*sin(0.0001-PI/2+i*2.0*PI/400.0);
    }

  /*piediagram=image(imxsize=30+size+xmaxtext*2, 
		   imysize=(int)(size*((twoD!=0)+2.0)/3.0+
		   30+ymaxtext*2+1), @bg);*/


  //write(sprintf("%O", arr));

  //initiate the 0.25*% for different numbers:
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


  //Draw the slices
  int t=sizeof(diagram_data["data"][0]);

  edge_nr=0;
  for(i=0; i<t; i++)
    {
      piediagram=piediagram->setcolor(@diagram_data["datacolors"][i]);
      piediagram=piediagram->polygone(({(float)xc,(float)yc})+
				      arr[2*edge_nr..2*(edge_nr+pnumbers[i]+2)+1]);
      edge_nr+=pnumbers[i];
    }
  


  edge_nr=pnumbers[0];


  //black borders
  if (diagram_data["linewidth"]>LITET)
    {
      piediagram=piediagram->setcolor(@diagram_data["axcolor"]);
      piediagram=piediagram->polygone(
				      make_polygon_from_line(diagram_data["linewidth"],
							     ({
							       xc,
							       yc,
							       arr[0],
							       arr[1]
							     })
							     ,
							     0, 1)[0]
				      );

      for(int i=1; i<sizeof(pnumbers); i++)
	{
	  piediagram=piediagram->
	    polygone(
		     make_polygon_from_line(diagram_data["linewidth"],
					    ({xc
					      ,yc,
					      arr[2*(edge_nr)],
					      arr[2*(edge_nr)+1]
					    })
					    ,
					    0, 1)[0]
		     );
	  
	  edge_nr+=pnumbers[i];
	}
      piediagram=piediagram->polygone(arr+arr2);
    }
  
  piediagram=piediagram->setcolor(255,255,255);
  
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
      int imxsize=piediagram->xsize(); //diagram_data["xsize"];
      int imysize=piediagram->ysize(); //diagram_data["ysize"]+diagram_data["legendsize"];

      if(tone)
	{
	  
	  
	  tbild=image(imxsize, imysize, 255, 255, 255)->
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
	    tbild->
	      paste(tbild->copy(0,0,63, imysize), 64, 0);
	  if (imxsize>128)
	    tbild=tbild->paste(tbild->copy(0,0,128, imysize), 128, 0);
	  if (imxsize>256)
	    tbild=tbild->paste(tbild->copy(0,0,256, imysize), 256, 0);
	  if (imxsize>512)
	    tbild=tbild->paste(tbild->copy(0,0,512, imysize), 512, 0);
	  piediagram+=tbild;
	}
      
      float* arr3;
      float* arr4;
      float* arr5;
      
      
      //Draw the border below.
      arr3=arr2[200..601];
      for(int i=1; i<402; i+=2)
	arr3[i]+=diagram_data["3Ddepth"];

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

      array(float) arr6=arr3+arr2[200..601];

      float plusx=ceil(2-(float)most_left);
      float plusy=ceil(2-(float)yc);
      for(int i=0; i<sizeof(arr6); )
	{
	  arr6[i++]+=plusx;
	  arr6[i++]+=plusy;
	}
      /*
      arr6=allocate(804);
      for(int i=0; i<201; i++)
	{
	  int j=i+200;
	  arr6[2*i]=2+(xr+w)+(xr+w)*sin((j*2.0*PI/400.0+0.0001));
	  arr6[2*i+1]=2+(w+yr)*sin(0.0001-PI/2+j*2.0*PI/400.0);

	  arr6[802-2*i]=arr6[2*i];
	  arr6[802-2*i+1]=diagram_data["3Ddepth"]+arr6[2*i+1];
	}
      */
      imxsize=(int)(ceil(most_right+4)+floor(-most_left));
      imysize=(int)(diagram_data["3Ddepth"]+yr+4);
      below=image(imxsize, imysize, 0, 0, 0)->
	setcolor(255,255,255)->
	polygone(arr6);
      
      b=({155,155,155});
      a=({100,100,100});
      
      object tbild;
      tbild=image(imxsize,imysize , 255, 255, 255)
	->tuned_box(0,0, imxsize/2, 1,
		  ({a,b,a,b}))
	->tuned_box(imxsize/2, 0,imxsize , 1,
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
      
      //write("tbild->xsize()"+tbild->xsize()+"\n");
      //write("tbild->ysize()"+tbild->ysize()+"\n");
      //write("below->xsize()"+below->xsize()+"\n");
      //write("below->ysize()"+below->ysize()+"\n");


      //piediagram=
      piediagram->paste_mask(tbild, below, -(int)ceil(plusx), -(int)ceil(plusy) );
      
      
      
    }

  
  //write the text!
  int|float place;
  sum=0;
  if (names)
    for(int i=0; i<sizeof(pnumbers); i++)
      {
	int t;
	sum+=pnumbers[i];
	place=sum-pnumbers[i]/2;
	if (FI)
	  {
	    place=place+FI*400.0/(2.0*PI);
	    while (place>400)
	      place-=400;
	  }
	piediagram=piediagram->setcolor(255,0, 0);

	
	t=(place<202)?0:-text[i]->xsize();
	//if (place<20) t-=7;
	//else if (place>380) t+=7;
	//else if ((place>180)&&(place<202)) t-=7;
	//else if ((place>=202)&&(place<220)) t+=7;
	//if ((place>190)&&(place<202)) t-=4;
	//if ((place>=202)&&(place<210)) t+=4;
	//if (place<10) t-=4;
	//if (place>390) t+=4;
	
	//int yt=0;
	//if ((place>120)&&(place<280))
	//  yt=(int)(34*sin(2*PI*(float)(place-100)/400.0));
	//if ((place<=80)||(place>=320)) yt-=ymaxtext;
	//else
	//  if (!((place>=120)&&(place<=280))) yt-=ymaxtext/2;
	int yt=0;
	if (((place>100)&&(place<300))&&
	    (!twoD))
	  yt=diagram_data["3Ddepth"];
	
	int ex=text[i]->ysize();
	int x=(int)(xc +t+ (xr+ex)*sin(place*PI*2.0/400.0+0.0001));
	int y=(int)(-text[i]->ysize()/2+yc +yt+ 
		    (yr+ex)*sin(-PI/2.0+place*PI*2.0/400.0+0.0001));
      

	//int x=(int)(arr2[2*place]+t);
	//int y=(int)arr[2*place+1]+yt;
	piediagram=piediagram->paste_alpha_color(text[i], @fg, x, y);
      }








  //////////////////////

  /*
  piediagram=image(diagram_data["xsize"],
		   diagram_data["ysize"]+diagram_data["legend_size"], 
		   @diagram_data["legendcolor"])->paste(piediagram->scale(diagram_data["xsize"],diagram_data["ysize"]));

  diagram_data["image"]=piediagram;
  set_legend_size(diagram_data);
  */

  diagram_data["ysize"]-=diagram_data["legend_size"];
  diagram_data["image"]=piediagram;
  return diagram_data;



}

#ifndef ROXEN
int main(int argc, string *argv)
{
  //write("\nRitar axlarna. Filen sparad som test.ppm\n");

  mapping(string:mixed) diagram_data;
  diagram_data=(["type":"pie",
		 "textcolor":({0,255,0}),
		 "subtype":"box",
		 "orient":"vert",
		 "data": 
		 ({ ({55, 40, 30 ,20, 10, 10, 10, 10, 5 })/*,
		     ({91.2, 101.3, 91.5, 101.7,  -91.0, 101.5}),
		    ({91.2, 103.3, -91.5, 100.1, 94.3, 95.2 }),
		    ({93.2, -103.3, 93.5, 103.7, 94.3, -91.2 }) */}),
		 "fontsize":16,
		 "axcolor":({0,0,0}),
		 "bgcolor":0, //({255,255,255}),
		 "labelcolor":({0,0,0}),
		 "datacolors":({({0,255,0}),({255,255,0}), ({0,255,255}), ({255,0,255}),({0,255,0}),({255,255,0})  }),
		 "linewidth":2.2,
		 "xsize":300,
		 "ysize":300,
		 "xnames":({"jan", "feb", "mar", "apr", "maj", "jun", "jul", "aug", "sep"
		 }),
		 "labels":({"xstor", "ystor", "xenhet", "yenhet"}),
		 //"legendfontsize":12,
		 "legend_texts":({"streck 1", "streck 2", "foo", "bar gazonk foobar illalutta!", "lila", "turkos" }),
		 "labelsize":12,
		 "xminvalue":0.1,
		 "yminvalue":0,
		 "3Ddepth":30,
		 "drawtype": "3D",
		 "tone":0,
		 "rotate":30

  ]);

  diagram_data["image"]=image(2,2)->fromppm(read_file("girl.ppm"));


  object o=Stdio.File();
  o->open("test.ppm", "wtc");
  o->write(create_pie(diagram_data)["image"]->toppm());
  o->close();

};
#endif
