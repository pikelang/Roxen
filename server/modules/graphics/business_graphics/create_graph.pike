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

//inherit "../testserver/roxen/server/base_server/roxenlib.pike"; 

//Denna funktion ritar text-bilderna, initierar max, fixar till bk-bilder
//och allt annat som är gemensamt för alla sorters diagram.
//Denna funktion anropas i create_XXX.


void draw(object(image) img, float h, array(float) coords)
{
  for(int i=0; i<sizeof(coords)-3; i+=2)
    {
      img->
	polygone(make_polygon_from_line(h, coords[i..i+3],
					1, 1)[0]);
    }
}

mapping(string:mixed) setinitcolors(mapping(string:mixed) diagram_data)
{
  //diagram_data["datasize"]=0;
  foreach(diagram_data["data"], string* fo)
    if (sizeof(fo)>diagram_data["datasize"])
      diagram_data["datasize"]=sizeof(fo);
  

  object piediagram=diagram_data["image"];
  


  /*  if (diagram_data["xnames"]!=0)
    if (sizeof(diagram_data["xnames"])!=sizeof(diagram_data["data"][0]))
    diagram_data["xnames"]=0;*/
  if (diagram_data["datacolors"])
    {
      int cnum;
      if (diagram_data["type"]=="pie")
	cnum=diagram_data["datasize"];
      else
	cnum=sizeof(diagram_data["data"]);
      if (sizeof(diagram_data["datacolors"])<cnum)
	diagram_data["datacolors"]=0;
      else
	foreach(diagram_data["datacolors"], mixed color)
	  if (sizeof(color)!=3)
	    diagram_data["datacolors"]=0;
    }

  if (!(diagram_data["datacolors"]))
    {
      int numbers;
      if (diagram_data["type"]=="pie")
	numbers=diagram_data["datasize"];
      else
	numbers=sizeof(diagram_data["data"]);

      int** carr=allocate(numbers);
      int steg=128+128/(numbers);
      if (1==numbers)
	carr=({({39,155,102})});
      else
      if (2==numbers)
	carr=({({190, 180, 0}), ({39, 39, 155})});
      else
      if (3==numbers)
	carr=({({155, 39, 39}), ({39, 39, 155}), ({42, 155, 39})});
      else
      if (4==numbers)
	carr=({({155, 39, 39}), ({39, 66, 155}), ({180, 180, 0}), ({39, 155, 102})});
      else
      if (5==numbers)
	carr= ({({155, 39, 39}), ({39, 85, 155}), ({180, 180, 0}), ({129, 39, 155}), ({39, 155, 80})});
      else
     if (6==numbers)
	carr= ({({155, 39, 39}), ({39, 85, 155}), ({180, 180, 0}), ({74, 155, 39}), ({100, 39, 155}), ({39, 155, 102})});
      else
     if (7==numbers)
	carr= ({({155, 39, 39}), ({39, 85, 155}), ({180, 180, 0}), ({72, 39, 155}), ({74, 155, 39}), ({155, 39, 140}), ({39, 155, 102})});
      else
      if (8==numbers)
	carr=({({155, 39, 39}), ({39, 110, 155}), ({180, 180, 0}), ({55, 39, 155}), ({96, 155, 39}), ({142, 39, 155}), ({39, 155, 69}), ({80, 39, 155})}) ;
      else
      if (9==numbers)
	carr= ({({155, 39, 39}), ({39, 115, 155}), ({155, 115, 39}), ({39, 39, 155}), ({118, 155, 39}), ({115, 39, 155}), ({42, 155, 39}), ({155, 39, 118}), ({39, 155, 112})});
      else
      if (10==numbers)
	carr=({({155, 39, 39}), ({39, 121, 155}), ({155, 104, 39}), ({39, 55, 155}), ({140, 155, 39}), ({88, 39, 155}), ({74, 155, 39}), ({130, 24, 130}), ({39, 155, 69}), ({180, 180, 0})}) ;
      else
      if (11==numbers)
	carr=({({155, 39, 39}), ({39, 123, 155}), ({155, 99, 39}), ({39, 63, 155}), ({150, 155, 39}), ({74, 39, 155}), ({91, 155, 39}), ({134, 39, 155}), ({39, 155, 47}), ({155, 39, 115}), ({39, 155, 107})}) ;
      else
      if (12==numbers)
	carr=({({155, 39, 39}), ({39, 126, 155}), ({155, 93, 39}), ({39, 72, 155}), ({155, 148, 39}), ({61, 39, 155}), ({107, 155, 39}), ({115, 39, 155}), ({53, 155, 39}), ({155, 39, 140}), ({39, 155, 80}), ({155, 39, 85})}) ;
      else
	{
	  //No colours given!
	  //Now we have the %-numbers in pnumbers
	  //Lets create a colourarray carr
	  for(int i=0; i<numbers; i++)
	    {
	      carr[i]=Colors.hsv_to_rgb((i*steg)%256,190,155);
	    }
	}
      
      //write("carr: "+sprintf("%O", carr)+"\n");
      diagram_data["datacolors"]=carr;
      
    }
  

  diagram_data["image"]=piediagram;
  return diagram_data["image"];

}



mapping(string:mixed) init(mapping(string:mixed) diagram_data)
{
  float xminvalue=0.0, xmaxvalue=-STORT, yminvalue=0.0, ymaxvalue=-STORT;

  //Oulinecolors
  if ((diagram_data["backdatacolors"]==0)&&
      (diagram_data["backlinewidth"]))
    {
      int dcs=sizeof(diagram_data["datacolors"]);
      diagram_data["backdatacolors"]=allocate(dcs);
      for(int i=0; i<dcs; i++)
	diagram_data["backdatacolors"][i]=({255-diagram_data["datacolors"][i][0],
					    255-diagram_data["datacolors"][i][1],
					    255-diagram_data["datacolors"][i][2]
	});
      
    }
  //diagram_data["backlinewidth"]=diagram_data["linewidth"]+1.0;
  
  if (!(diagram_data["legendcolor"]))
    diagram_data["legendcolor"]=diagram_data["bgcolor"];

  if (diagram_data["type"]=="graph")
    diagram_data["subtype"]="line";
  
  if (diagram_data["type"]=="bars")
    diagram_data["xminvalue"]=0;

  if (diagram_data["type"]=="sumbars")
    {
      diagram_data["xminvalue"]=0;
      if (diagram_data["subtype"]=="norm")
	{
	  diagram_data["yminvalue"]=0;
	  if (!(diagram_data["labels"]))
	    diagram_data["labels"]=({"", "%", "", ""});
	}
    }
  if ((diagram_data["subtype"]==0) ||
      (diagram_data["subtype"]==""))
    diagram_data["subtype"]="line";

  if (diagram_data["subtype"]=="line")
    if ((!(diagram_data["drawtype"])) ||
	(diagram_data["drawtype"]==""))
      diagram_data["drawtype"]="linear";

  if (diagram_data["subtype"]=="box")
    if ((!(diagram_data["drawtype"])) ||
	(diagram_data["drawtype"]==""))
      diagram_data["drawtype"]="2D";

  if (diagram_data["type"]=="sumbars")
    {
      int j=sizeof(diagram_data["data"]);
      float k;
      if (diagram_data["subtype"]=="norm")
	{
	  int j2=diagram_data["datasize"];
	  for(int i=0; i<j2; i++)
	    {
	      k=`+(@column(diagram_data["data"], i));
	      if (k<LITET)
		k=LITET;
	      else
		k=100.0/k;
	      for(int i2=0; i2<j; i2++)
		diagram_data["data"][i2][i]*=k;
	    }
	  yminvalue=0.0;
	  ymaxvalue=100.0;
	  
	}
      else
	for(int i; i<j; i++)
	  {
	    if (yminvalue>(k=`+(@column(diagram_data["data"], i))))
	      yminvalue=k;
	    if (ymaxvalue<(k))
	      ymaxvalue=k;
	  }
      xminvalue=0.0;
      xmaxvalue=10.0;
      

    }
  else
    foreach(diagram_data["data"], array(float) d)
      {
	int j=sizeof(d);
	
	if (diagram_data["type"]=="graph")
	  for(int i; i<j; i++)
	    {
	      float k;
	      if (xminvalue>(k=d[i]))
		xminvalue=k;
	      if (xmaxvalue<(k))
		xmaxvalue=k;
	      if (yminvalue>(k=d[++i]))
		yminvalue=k;
	      if (ymaxvalue<(k))
		ymaxvalue=k;
	    }
	else
	  if ((diagram_data["type"]=="bars")||
	      (diagram_data["type"]=="pie"))
	    for(int i; i<j; i++)
	      {
		float k; 
		if (yminvalue>(k=d[i]))
		  yminvalue=k;
		if (ymaxvalue<(k))
		  ymaxvalue=k;
		xminvalue=0.0;
		xmaxvalue=10.0;
	      }
	  else
	    throw( ({"\""+diagram_data["type"]+"\" is an unknown graph type!\n",
		     backtrace()}));
      }

  if (diagram_data["type"]=="sumbars")
    diagram_data["box"]=0;


  xmaxvalue=max(xmaxvalue, xminvalue+LITET);
  ymaxvalue=max(ymaxvalue, yminvalue+LITET);

  //write("ymaxvalue:"+ymaxvalue+"\n");
  //write("yminvalue:"+yminvalue+"\n");
  //write("xmaxvalue:"+xmaxvalue+"\n");
  //write("xminvalue:"+xminvalue+"\n");

  if (!(diagram_data["xminvalue"]))
    diagram_data["xminvalue"]=xminvalue;
  if ((!(diagram_data["xmaxvalue"])) ||
      (diagram_data["xmaxvalue"]<xmaxvalue))
    if (xmaxvalue<0.0)
      diagram_data["xmaxvalue"]=0.0;
    else
      diagram_data["xmaxvalue"]=xmaxvalue;
  if (!(diagram_data["yminvalue"]))
    diagram_data["yminvalue"]=yminvalue;
  if ((!(diagram_data["ymaxvalue"])) ||
      (diagram_data["ymaxvalue"]<ymaxvalue))
    if (ymaxvalue<0.0)
      diagram_data["ymaxvalue"]=0.0;
    else
      diagram_data["ymaxvalue"]=ymaxvalue;

  //Ge tomma namn på xnames om namnen inte finns
  //Och ge bars max och minvärde på x-axeln.
  if ((diagram_data["type"]=="bars")||(diagram_data["type"]=="sumbars"))
    {
      if (!(diagram_data["xnames"]))
	diagram_data["xnames"]=allocate(diagram_data["datasize"]);
    }

  //Om xnames finns så sätt xspace om inte values_for_xnames finns
  if (diagram_data["xnames"])
    diagram_data["xspace"]=max((diagram_data["xmaxvalue"]-
				diagram_data["xminvalue"])
			       /(float)(diagram_data["datasize"]), 
			       LITET*20);

  //Om ynames finns så sätt yspace.
  if (diagram_data["ynames"])
    diagram_data["yspace"]=(diagram_data["ymaxvalue"]-
			    diagram_data["yminvalue"])
      /(float)sizeof(diagram_data["ynames"]);
  
  
  return diagram_data;

};

#ifndef ROXEN
object get_font(string j, int p, int t, int h, string fdg, int s, int hd)
{
  return Image.font()->load("avant_garde");
};
#endif

//rita bilderna för texten
//ta ut xmaxynames, ymaxynames xmaxxnames ymaxxnames
mapping(string:mixed) create_text(mapping(string:mixed) diagram_data)
{
  object notext=get_font("avant_garde", diagram_data["fontsize"], 0, 0, "left",0,0);
  int j;
  diagram_data["xnamesimg"]=allocate(j=sizeof(diagram_data["xnames"]));
  for(int i=0; i<j; i++)
    if (((diagram_data["values_for_xnames"][i]>LITET)||(diagram_data["values_for_xnames"][i]<-LITET))&&
	((diagram_data["xnames"][i]) && sizeof(diagram_data["xnames"][i])))
      diagram_data["xnamesimg"][i]=notext->write(diagram_data["xnames"][i])
->scale(0,diagram_data["fontsize"])
;
    else
      diagram_data["xnamesimg"][i]=
	image(diagram_data["fontsize"],diagram_data["fontsize"]);

  diagram_data["ynamesimg"]=allocate(j=sizeof(diagram_data["ynames"]));
  for(int i=0; i<j; i++)
    if (((diagram_data["values_for_ynames"][i]>LITET)||(diagram_data["values_for_ynames"][i]<-LITET))&&    
	((diagram_data["ynames"][i]) && (sizeof(diagram_data["ynames"][i]))))
      diagram_data["ynamesimg"][i]=notext->write(diagram_data["ynames"][i])
	->scale(0,diagram_data["fontsize"])
	;
    else
      diagram_data["ynamesimg"][i]=
	image(diagram_data["fontsize"],diagram_data["fontsize"]);
  


  if (diagram_data["orient"]=="vert")
    for(int i; i<sizeof(diagram_data["xnamesimg"]); i++)
      diagram_data["xnamesimg"][i]=diagram_data["xnamesimg"][i]->rotate_ccw();

  int xmaxynames=0, ymaxynames=0, xmaxxnames=0, ymaxxnames=0;
  
  foreach(diagram_data["xnamesimg"], object img)
    if (img->ysize()>ymaxxnames) 
      ymaxxnames=img->ysize();

  foreach(diagram_data["xnamesimg"], object img)
    if (img->xsize()>xmaxxnames) 
      xmaxxnames=img->xsize();

  foreach(diagram_data["ynamesimg"], object img)
    if (img->ysize()>ymaxynames) 
      ymaxynames=img->ysize();

  foreach(diagram_data["ynamesimg"], object img)
    if (img->xsize()>xmaxynames) 
      xmaxynames=img->xsize();
  
  diagram_data["ymaxxnames"]=ymaxxnames;
  diagram_data["xmaxxnames"]=xmaxxnames;
  diagram_data["ymaxynames"]=ymaxynames;
  diagram_data["xmaxynames"]=xmaxynames;


}

string no_end_zeros(string f)
{
  if (search(f, ".")!=-1)
    {
      int j;
      for(j=sizeof(f)-1; f[j]=='0'; j--)
	{}
      if (f[j]=='.')
	return f[..--j];
      else
	return f[..j];
    }
  return f;
}


//Denna funktion ritar ut grinden i bilden.
mapping draw_grind(mapping diagram_data, int|float xpos_for_yaxis,
		   int|float ypos_for_xaxis, float xmore, float ymore, 
		   float xstart, float ystart, float si)
{
  //Placera ut vert grinden
  int s=sizeof(diagram_data["xnamesimg"]);
  object graph=diagram_data["image"];
  float gw=diagram_data["grindwidth"];
  if ((diagram_data["vertgrind"])&&
      (gw>LITET))
    for(int i=0; i<s; i++)
      {
	graph->
	  polygone(make_polygon_from_line(gw,
					  ({
					    ((diagram_data["values_for_xnames"][i]-
					      diagram_data["xminvalue"])
					     *xmore+xstart),
					    diagram_data["ysize"]-ystart
					    ,
					    
					    ((diagram_data["values_for_xnames"][i]-
					      diagram_data["xminvalue"])
					     *xmore+xstart),
					    gw
					  }), 
					  1, 1)[0]);
    }

  //Placera ut horgrinden
  s=sizeof(diagram_data["ynamesimg"]);
  if ((diagram_data["horgrind"])&&
      (gw>LITET))
  for(int i=0; i<s; i++)
    {
      graph->
	polygone(make_polygon_from_line(gw,
					({
					  xstart,
					  (-(diagram_data["values_for_ynames"][i]-
					     diagram_data["yminvalue"])
					   *ymore+diagram_data["ysize"]-ystart),

					  diagram_data["xsize"]-gw,
					  (-(diagram_data["values_for_ynames"][i]-
					     diagram_data["yminvalue"])
					   *ymore+diagram_data["ysize"]-ystart)
					}), 
					1, 1)[0]);
    }
  

}

//Denna funktion skriver också ut infon i Legenden
mapping set_legend_size(mapping diagram_data)
{
  if (!(diagram_data["legendfontsize"]))
    diagram_data["legendfontsize"]=diagram_data["fontsize"];

  if (diagram_data["legend_texts"])
    {
      array(object(image)) texts;
      //array(object(image)) plupps; //Det som ska ritas ut före texterna
      array(mixed) plupps; //Det som ska ritas ut före texterna
      texts=allocate(sizeof(diagram_data["legend_texts"]));
      plupps=allocate(sizeof(diagram_data["legend_texts"]));
      
      object notext=get_font("avant_garde",diagram_data["legendfontsize"], 0, 0, 
			     "left",0,0);

      int j=sizeof(texts);
      if (!diagram_data["legendcolor"])
	diagram_data["legendcolor"]=diagram_data["bgcolor"];
      for(int i=0; i<j; i++)
	if (diagram_data["legend_texts"][i] && (sizeof(diagram_data["legend_texts"][i])))
	  texts[i]=notext->write(diagram_data["legend_texts"][i])
	    ->scale(0,diagram_data["legendfontsize"])
;
      	else
	  texts[i]=
	    image(diagram_data["legendfontsize"],diagram_data["legendfontsize"]);


      int xmax=0, ymax=0;
  
      foreach(texts, object img)
	{
	  if (img->ysize()>ymax) 
	    ymax=img->ysize();
	}
      foreach(texts, object img)
	{
	  if (img->xsize()>xmax) 
	    xmax=img->xsize();
	}
      
      //Skapa strecket för graph/boxen för bars.
      //write("J:"+j+"\n");
      if ((diagram_data["type"]=="graph") ||
	  (diagram_data["type"]=="bars") ||
	  (diagram_data["type"]=="sumbars") ||
	  (diagram_data["type"]=="pie"))
	for(int i=0; i<j; i++)
	  {
	    plupps[i]=image(diagram_data["legendfontsize"],diagram_data["legendfontsize"]);

	    plupps[i]->setcolor(255,255,255);
	    if ((diagram_data["linewidth"]*1.5<(float)diagram_data["legendfontsize"])&&
		(diagram_data["subtype"]=="line")&&(diagram_data["drawtype"]!="level"))
	      plupps[i]->polygone(make_polygon_from_line(diagram_data["linewidth"], 
							 ({
							   (float)(diagram_data["linewidth"]/2+1),
							   (float)(plupps[i]->ysize()-
								   diagram_data["linewidth"]/2-2),
							   (float)(plupps[i]->xsize()-
								   diagram_data["linewidth"]/2-2),
							   (float)(diagram_data["linewidth"]/2+1)
							 }), 
							 1, 1)[0]);
	    else
	      {
	      plupps[i]->box(1,
			     1,
			     plupps[i]->xsize()-2,
			     plupps[i]->ysize()-2
			     
			     );
	      }
	  }
      else
	throw( ({"\""+diagram_data["type"]+"\" is an unknown graph type!\n",
		 backtrace()}));

      //Ta redapå hur många kolumner vi kan ha:
      int b;
      int columnnr=(diagram_data["image"]->xsize()-4)/
	(b=xmax+2*diagram_data["legendfontsize"]);
      
      if (columnnr==0)
	{
	  int m=((diagram_data["image"]->xsize()-4)-2*diagram_data["legendfontsize"]);
	  if (m<4) m=4;
	  for(int i=0; i<sizeof(texts); i++)
	    if (texts[i]->xsize()>m)
	      {
		texts[i]=
		  texts[i]->scale((int)m,0);
		//write("x: "+texts[i]->xsize()+"\n");
		//write("y: "+texts[i]->ysize()+"\n");
	      }
	  columnnr=1;
	}

      int raws=(j+columnnr-1)/columnnr;
      diagram_data["legend_size"]=raws*diagram_data["legendfontsize"];

      //placera ut bilder och text.
      for(int i=0; i<j; i++)
	{
	  diagram_data["image"]->paste_alpha_color(plupps[i], 
						   @(diagram_data["datacolors"][i]), 
						   (i/raws)*b,
						   (i%raws)*diagram_data["legendfontsize"]+
						   diagram_data["image"]->ysize()-diagram_data["legend_size"]
						   
						   );
	  diagram_data["image"]->setcolor(0,0,0);
	  draw( diagram_data["image"], 0.5, 
	       ({(i/raws)*b+0.01, (i%raws)*diagram_data["legendfontsize"]+
						   diagram_data["image"]->ysize()-diagram_data["legend_size"]+1 //FIXME
		 ,(i/raws)*b+plupps[i]->xsize()-0.99 ,  (i%raws)*diagram_data["legendfontsize"]+
						   diagram_data["image"]->ysize()-diagram_data["legend_size"]+1, //FIXME
		 (i/raws)*b+plupps[i]->xsize()-1.0,  (i%raws)*diagram_data["legendfontsize"]+
						   diagram_data["image"]->ysize()-diagram_data["legend_size"]+plupps[i]->ysize()-1  //FIXME
		 ,(i/raws)*b+1 ,  (i%raws)*diagram_data["legendfontsize"]+
						   diagram_data["image"]->ysize()-diagram_data["legend_size"]+plupps[i]->ysize()-1 //FIXME

		 ,(i/raws)*b+0.01, (i%raws)*diagram_data["legendfontsize"]+
						   diagram_data["image"]->ysize()-diagram_data["legend_size"]+1 //FIXME

	       })); 
	

	  diagram_data["image"]->paste_alpha_color(texts[i], 
						   @(diagram_data["textcolor"]), 
						   (i/raws)*b+1+diagram_data["legendfontsize"],
						   (i%raws)*diagram_data["legendfontsize"]+
						   diagram_data["image"]->ysize()-diagram_data["legend_size"]
						   
						   );
	  

	  
	}
    }
  else
    diagram_data["legend_size"]=0;

  


}

mapping(string:mixed) create_graph(mapping diagram_data)
{
  //Supportar bara xsize>=100
  int si=diagram_data["fontsize"];

  string where_is_ax;

  //Fixa defaultfärger!
  setinitcolors(diagram_data);

  object(image) graph;
  if (diagram_data["bgcolor"])
    graph=image(diagram_data["xsize"],diagram_data["ysize"],
		@(diagram_data["bgcolor"]));
  else
    {
      graph=diagram_data["image"];
      diagram_data["xsize"]=diagram_data["image"]->xsize();
      diagram_data["ysize"]=diagram_data["image"]->ysize();
    }
  diagram_data["image"]=graph;

  set_legend_size(diagram_data);

  diagram_data["ysize"]-=diagram_data["legend_size"];
  
  //Bestäm största och minsta datavärden.
  init(diagram_data);

  //Ta reda hur många och hur stora textmassor vi ska skriva ut
  if (!(diagram_data["xspace"]))
    {
      //Initera hur långt det ska vara emellan.
      float range=(diagram_data["xmaxvalue"]-
		 diagram_data["xminvalue"]);
      if ((range>-LITET)&&
	  (range<LITET))
	range=LITET*10.0;

      float space=pow(10.0, floor(log(range/3.0)/log(10.0)));
      if (range/space>5.0)
	{
	  if(range/(2.0*space)>5.0)
	    {
	      space=space*5.0;
	    }
	  else
	    space=space*2.0;
	}
      diagram_data["xspace"]=space;      
    }
  if (!(diagram_data["yspace"]))
    {
      //Initera hur långt det ska vara emellan.
      
      float range=(diagram_data["ymaxvalue"]-
		 diagram_data["yminvalue"]);
      float space=pow(10.0, floor(log(range/3.0)/log(10.0)));
      if (range/space>5.0)
	{
	  if(range/(2.0*space)>5.0)
	    {
	      space=space*5.0;
	    }
	  else
	    space=space*2.0;
	}
      diagram_data["yspace"]=space;      
    }
 


  if (!(diagram_data["values_for_xnames"]))
    {
      float start;
      start=diagram_data["xminvalue"];
      start=diagram_data["xspace"]*ceil((start)/diagram_data["xspace"]);
      diagram_data["values_for_xnames"]=({start});
      while(diagram_data["values_for_xnames"][-1]<=
	    diagram_data["xmaxvalue"]-diagram_data["xspace"])
	diagram_data["values_for_xnames"]+=({start+=diagram_data["xspace"]});
    }
  if (!(diagram_data["values_for_ynames"]))
    {
      float start;
      start=diagram_data["yminvalue"];
      start=diagram_data["yspace"]*ceil((start)/diagram_data["yspace"]);
      diagram_data["values_for_ynames"]=({start});
      while(diagram_data["values_for_ynames"][-1]<=
	    diagram_data["ymaxvalue"]-diagram_data["yspace"])
	diagram_data["values_for_ynames"]+=({start+=diagram_data["yspace"]});
    }
  
  //Generera texten om den inte finns
  if (!(diagram_data["ynames"]))
    {
      diagram_data["ynames"]=
	allocate(sizeof(diagram_data["values_for_ynames"]));
      
      for(int i=0; i<sizeof(diagram_data["values_for_ynames"]); i++)
	diagram_data["ynames"][i]=no_end_zeros((string)(diagram_data["values_for_ynames"][i]));
    }
  if (!(diagram_data["xnames"]))
    {
      diagram_data["xnames"]=
	allocate(sizeof(diagram_data["values_for_xnames"]));
      
      for(int i=0; i<sizeof(diagram_data["values_for_xnames"]); i++)
	diagram_data["xnames"][i]=no_end_zeros((string)(diagram_data["values_for_xnames"][i]));
    }


  //rita bilderna för texten
  //ta ut xmaxynames, ymaxynames xmaxxnames ymaxxnames
  create_text(diagram_data);

  //Skapa labelstexten för xaxlen
  object labelimg;
  string label;
  int labelx=0;
  int labely=0;
  if (diagram_data["labels"])
    {
      if (diagram_data["labels"][2] && sizeof(diagram_data["labels"][2]))
	label=diagram_data["labels"][0]+" ["+diagram_data["labels"][2]+"]"; //Xstorhet
      else
	label=diagram_data["labels"][0];
      if ((label!="")&&(label!=0))
	labelimg=get_font("avant_garde", diagram_data["labelsize"], 0, 0, "left",0,0)->
	  write(label)
->scale(0,diagram_data["labelsize"])
;
      else
	labelimg=image(diagram_data["labelsize"],diagram_data["labelsize"]);
      labely=diagram_data["labelsize"];
      labelx=labelimg->xsize();
    }

  int ypos_for_xaxis; //avstånd NERIFRÅN!
  int xpos_for_yaxis; //avstånd från höger
  //Bestäm var i bilden vi får rita graf
  diagram_data["ystart"]=(int)ceil(diagram_data["linewidth"]);
  diagram_data["ystop"]=diagram_data["ysize"]-
    (int)ceil(diagram_data["linewidth"]+si)-diagram_data["labelsize"];
  if (((float)diagram_data["yminvalue"]>-LITET)&&
      ((float)diagram_data["yminvalue"]<LITET))
    diagram_data["yminvalue"]=0.0;
  
  if (diagram_data["yminvalue"]<0)
    {
      //placera ut x-axeln.
      //om detta inte funkar så rita xaxeln längst ner/längst upp och räkna om diagram_data["ystart"]
      ypos_for_xaxis=((-diagram_data["yminvalue"])*(diagram_data["ystop"]-diagram_data["ystart"]))/
	(diagram_data["ymaxvalue"]-diagram_data["yminvalue"])+diagram_data["ystart"];
      
      int minpos;
      minpos=max(labely, diagram_data["ymaxxnames"])+si*2;
      if (minpos>ypos_for_xaxis)
	{
	  ypos_for_xaxis=minpos;
	  diagram_data["ystart"]=ypos_for_xaxis+
	    diagram_data["yminvalue"]*(diagram_data["ystop"]-ypos_for_xaxis)/
	    (diagram_data["ymaxvalue"]);
	}
      else
	{
	  int maxpos;
	  maxpos=diagram_data["ysize"]-
	    (int)ceil(diagram_data["linewidth"]+si*2)-
	    diagram_data["labelsize"];
	  if (maxpos<ypos_for_xaxis)
	    {
	      ypos_for_xaxis=maxpos;
	      diagram_data["ystop"]=ypos_for_xaxis+
		diagram_data["ymaxvalue"]*(ypos_for_xaxis-diagram_data["ystart"])/
		(0-diagram_data["yminvalue"]);
	    }
	}
    }
  else
    if (diagram_data["yminvalue"]==0.0)
      {
	// sätt x-axeln längst ner och diagram_data["ystart"] på samma ställe.
	diagram_data["ystop"]=diagram_data["ysize"]-
	  (int)ceil(diagram_data["linewidth"]+si)-diagram_data["labelsize"];
	ypos_for_xaxis=max(labely, diagram_data["ymaxxnames"])+si*2;
	diagram_data["ystart"]=ypos_for_xaxis;
      }
    else
      {
	//sätt x-axeln längst ner och diagram_data["ystart"] en aning högre
	diagram_data["ystop"]=diagram_data["ysize"]-
	  (int)ceil(diagram_data["linewidth"]+si)-diagram_data["labelsize"];
	ypos_for_xaxis=max(labely, diagram_data["ymaxxnames"])+si*2;
	diagram_data["ystart"]=ypos_for_xaxis+si*2;
      }
  
  //xpos_for_yaxis=diagram_data["xmaxynames"]+
  // si;

  //Bestäm positionen för y-axeln
  diagram_data["xstart"]=(int)ceil(diagram_data["linewidth"]);
  diagram_data["xstop"]=diagram_data["xsize"]-
    (int)ceil(diagram_data["linewidth"]+si)-labelx/2;
  if (((float)diagram_data["xminvalue"]>-LITET)&&
      ((float)diagram_data["xminvalue"]<LITET))
    diagram_data["xminvalue"]=0.0;
  
  if (diagram_data["xminvalue"]<0)
    {
      //placera ut y-axeln.
      //om detta inte funkar så rita yaxeln längst ner/längst upp och räkna om diagram_data["xstart"]
      xpos_for_yaxis=((-diagram_data["xminvalue"])*(diagram_data["xstop"]-diagram_data["xstart"]))/
	(diagram_data["xmaxvalue"]-diagram_data["xminvalue"])+diagram_data["xstart"];
      
      int minpos;
      minpos=diagram_data["xmaxynames"]+si*2;
      if (minpos>xpos_for_yaxis)
	{
	  xpos_for_yaxis=minpos;
	  diagram_data["xstart"]=xpos_for_yaxis+
	    diagram_data["xminvalue"]*(diagram_data["xstop"]-xpos_for_yaxis)/
	    (diagram_data["ymaxvalue"]);
	}
      else
	{
	  int maxpos;
	  maxpos=diagram_data["xsize"]-
	    (int)ceil(diagram_data["linewidth"]+si*2)-
	    labelx/2;
	  if (maxpos<xpos_for_yaxis)
	    {
	      xpos_for_yaxis=maxpos;
	      diagram_data["xstop"]=xpos_for_yaxis+
		diagram_data["xmaxvalue"]*(xpos_for_yaxis-diagram_data["xstart"])/
		(0-diagram_data["xminvalue"]);
	    }
	}
    }
  else
    if (diagram_data["xminvalue"]==0.0)
      {
	// sätt y-axeln längst ner och diagram_data["xstart"] på samma ställe.
	//write("\nNu blev xminvalue noll!\nxmaxynames:"+diagram_data["xmaxynames"]+"\n");
	
	diagram_data["xstop"]=diagram_data["xsize"]-
	  (int)ceil(diagram_data["linewidth"]+si)-labelx/2;
	xpos_for_yaxis=diagram_data["xmaxynames"]+si*2;
	diagram_data["xstart"]=xpos_for_yaxis;
      }
    else
      {
	//sätt y-axeln längst ner och diagram_data["xstart"] en aning högre
	//write("\nNu blev xminvalue större än noll!\nxmaxynames:"+diagram_data["xmaxynames"]+"\n");

	diagram_data["xstop"]=diagram_data["xsize"]-
	  (int)ceil(diagram_data["linewidth"]+si)-labelx/2;
	xpos_for_yaxis=diagram_data["xmaxynames"]+si*2;
	diagram_data["xstart"]=xpos_for_yaxis+si*2;
      }
  



  

  
  //Rita ut axlarna
  graph->setcolor(@(diagram_data["axcolor"]));
  
  //Rita xaxeln
  if ((diagram_data["xminvalue"]<=LITET)&&
      (diagram_data["xmaxvalue"]>=-LITET))
    graph->
      polygone(make_polygon_from_line(diagram_data["linewidth"], 
				      ({
					diagram_data["linewidth"],
					diagram_data["ysize"]- ypos_for_xaxis,
					diagram_data["xsize"]-
					si-labelx/2, 
					diagram_data["ysize"]-ypos_for_xaxis
				      }), 
				      1, 1)[0]);
  else
    if (diagram_data["xmaxvalue"]<-LITET)
      {
	graph->
	  polygone(make_polygon_from_line(diagram_data["linewidth"], 
					  ({
					    diagram_data["linewidth"],
					    diagram_data["ysize"]- ypos_for_xaxis,
					    
					    xpos_for_yaxis-4.0/3.0*si, 
					    diagram_data["ysize"]-ypos_for_xaxis,
					    
					    xpos_for_yaxis-si, 
					    diagram_data["ysize"]-ypos_for_xaxis-
					    si/2.0,
					    xpos_for_yaxis-si/1.5, 
					    diagram_data["ysize"]-ypos_for_xaxis+
					    si/2.0,
					    
					    xpos_for_yaxis-si/3.0, 
					    diagram_data["ysize"]-ypos_for_xaxis,

					    diagram_data["xsize"]-si-labelx/2, 
					    diagram_data["ysize"]-ypos_for_xaxis

					  }), 
					  1, 1)[0]);
      }
    else
      if (diagram_data["xminvalue"]>LITET)
	{
	  graph->
	    polygone(make_polygon_from_line(diagram_data["linewidth"], 
					    ({
					      diagram_data["linewidth"],
					      diagram_data["ysize"]- ypos_for_xaxis,
					      
					      xpos_for_yaxis+si/3.0, 
					      diagram_data["ysize"]-ypos_for_xaxis,
					      
					      xpos_for_yaxis+si/1.5, 
					      diagram_data["ysize"]-ypos_for_xaxis-
					      si/2.0,
					      xpos_for_yaxis+si, 
					      diagram_data["ysize"]-ypos_for_xaxis+
					      si/2.0,
					      
					      xpos_for_yaxis+4.0/3.0*si, 
					      diagram_data["ysize"]-ypos_for_xaxis,
					      
					      diagram_data["xsize"]-si-labelx/2, 
					      diagram_data["ysize"]-ypos_for_xaxis
					      
					    }), 
					    1, 1)[0]);

	}
  
 graph->polygone(
	  ({
	    diagram_data["xsize"]-
	    diagram_data["linewidth"]/2-
	    (float)si-labelx/2, 
	    diagram_data["ysize"]-ypos_for_xaxis-
	    (float)si/4.0,
	    diagram_data["xsize"]-
	    diagram_data["linewidth"]/2-labelx/2, 
	    diagram_data["ysize"]-ypos_for_xaxis,
	    diagram_data["xsize"]-
	    diagram_data["linewidth"]/2-
	    (float)si-labelx/2, 
	    diagram_data["ysize"]-ypos_for_xaxis+
	    (float)si/4.0
	  })
	  );


  //Rita yaxeln
  if ((diagram_data["yminvalue"]<=LITET)&&
      (diagram_data["ymaxvalue"]>=-LITET))
      graph->
	polygone(make_polygon_from_line(diagram_data["linewidth"], 
					({
					  xpos_for_yaxis,
					  diagram_data["ysize"]-diagram_data["linewidth"],
					  
					  xpos_for_yaxis,
					  si+
					  diagram_data["labelsize"]
					}), 
					1, 1)[0]);
  else
    if (diagram_data["ymaxvalue"]<-LITET)
      {
	graph->
	  polygone(make_polygon_from_line(diagram_data["linewidth"], 
					  ({
					    xpos_for_yaxis,
					    diagram_data["ysize"]-diagram_data["linewidth"],

					    xpos_for_yaxis,
					    diagram_data["ysize"]-ypos_for_xaxis+
					    si*4.0/3.0,

					    xpos_for_yaxis-si/2.0,
					    diagram_data["ysize"]-ypos_for_xaxis+
					    si,
					    
					    xpos_for_yaxis+si/2.0,
					    diagram_data["ysize"]-ypos_for_xaxis+
					    si/1.5,
					    
					    xpos_for_yaxis,
					    diagram_data["ysize"]-ypos_for_xaxis+
					    si/3.0,
					    
					    xpos_for_yaxis,
					    si+
					    diagram_data["labelsize"]
					  }), 
					  1, 1)[0]);
      }
    else
      if (diagram_data["yminvalue"]>LITET)
	{
	  graph->
	    polygone(make_polygon_from_line(diagram_data["linewidth"], 
					    ({
					      xpos_for_yaxis,
					      diagram_data["ysize"]-diagram_data["linewidth"],

					      xpos_for_yaxis,
					      diagram_data["ysize"]-ypos_for_xaxis-
					      si/3.0,
					      
					      xpos_for_yaxis-si/2.0,
					      diagram_data["ysize"]-ypos_for_xaxis-
					      si/1.5,
					    
					      xpos_for_yaxis+si/2.0,
					      diagram_data["ysize"]-ypos_for_xaxis-
					      si,
					      
					      xpos_for_yaxis,
					      diagram_data["ysize"]-ypos_for_xaxis-
					      si*4.0/3.0,
					    
					      xpos_for_yaxis+0.01, //FIXME!
					      si+
					      diagram_data["labelsize"]
					      
					    }), 
					    1, 1)[0]);

	}
    
  //Rita pilen
  graph->
    polygone(
	     ({
	       xpos_for_yaxis-
	       (float)si/4.0,
	       diagram_data["linewidth"]/2.0+
	       (float)si+
	       diagram_data["labelsize"],
				      
	       xpos_for_yaxis,
	       diagram_data["linewidth"]/2.0+
	       diagram_data["labelsize"],
	
	       xpos_for_yaxis+
	       (float)si/4.0,
	       diagram_data["linewidth"]/2.0+
	       (float)si+
	       diagram_data["labelsize"]
	     })); 
  

  //Räkna ut lite skit
  float xstart=(float)diagram_data["xstart"];
  float xmore=(-xstart+diagram_data["xstop"])/
    (diagram_data["xmaxvalue"]-diagram_data["xminvalue"]);
  float ystart=(float)diagram_data["ystart"];
  float ymore=(-ystart+diagram_data["ystop"])/
    (diagram_data["ymaxvalue"]-diagram_data["yminvalue"]);
  
  draw_grind(diagram_data, xpos_for_yaxis, ypos_for_xaxis, 
	     xmore, ymore, xstart, ystart, (float) si);
  
  //Placera ut texten på X-axeln
  int s=sizeof(diagram_data["xnamesimg"]);
  for(int i=0; i<s; i++)
    {
      graph->setcolor(@diagram_data["textcolor"]);
      graph->paste_alpha_color(diagram_data["xnamesimg"][i], 
			       @(diagram_data["textcolor"]), 
			       (int)floor((diagram_data["values_for_xnames"][i]-
					   diagram_data["xminvalue"])
					  *xmore+xstart
					  -
					  diagram_data["xnamesimg"][i]->xsize()/2), 
			       (int)floor(diagram_data["ysize"]-ypos_for_xaxis+
					  si/2.0));
      graph->setcolor(@diagram_data["axcolor"]);
      graph->
	polygone(make_polygon_from_line(diagram_data["linewidth"], 
					({
					  ((diagram_data["values_for_xnames"][i]-
					    diagram_data["xminvalue"])
					   *xmore+xstart),
					  diagram_data["ysize"]-ypos_for_xaxis+
					   si/4,
					  ((diagram_data["values_for_xnames"][i]-
					    diagram_data["xminvalue"])
					   *xmore+xstart),
					  diagram_data["ysize"]-ypos_for_xaxis-
					   si/4
					}), 
					1, 1)[0]);
    }

  //Placera ut texten på Y-axeln
  s=sizeof(diagram_data["ynamesimg"]);
  for(int i=0; i<s; i++)
    {
      //write("\nYmaXnames:"+diagram_data["ymaxynames"]+"\n");
      graph->setcolor(@diagram_data["textcolor"]);
      graph->paste_alpha_color(diagram_data["ynamesimg"][i], 
			       @(diagram_data["textcolor"]), 
			       (int)floor(xpos_for_yaxis-
					  si/2.0-diagram_data["linewidth"]*2-
					  diagram_data["ynamesimg"][i]->xsize()),
			       (int)floor(-(diagram_data["values_for_ynames"][i]-
					    diagram_data["yminvalue"])
					  *ymore+diagram_data["ysize"]-ystart
					  -
					  diagram_data["ymaxynames"]/2));
      graph->setcolor(@diagram_data["axcolor"]);
      graph->
	polygone(make_polygon_from_line(diagram_data["linewidth"], 
					({
					  xpos_for_yaxis-
					   si/4,
					  (-(diagram_data["values_for_ynames"][i]-
					     diagram_data["yminvalue"])
					   *ymore+diagram_data["ysize"]-ystart),

					  xpos_for_yaxis+
					   si/4,
					  (-(diagram_data["values_for_ynames"][i]-
					     diagram_data["yminvalue"])
					   *ymore+diagram_data["ysize"]-ystart)
					}), 
					1, 1)[0]);
    }


  //Sätt ut labels ({xstorhet, ystorhet, xenhet, yenhet})
  if (diagram_data["labelsize"])
    {
      graph->paste_alpha_color(labelimg, 
			       @(diagram_data["labelcolor"]), 
			       diagram_data["xsize"]-labelx-(int)ceil((float)diagram_data["linewidth"]),
			       diagram_data["ysize"]-(int)ceil((float)(ypos_for_xaxis-si)));
      
      string label;
      int x;
      int y;
      
      if (diagram_data["labels"][3] && sizeof(diagram_data["labels"][3]))
	label=diagram_data["labels"][1]+" ["+diagram_data["labels"][3]+"]"; //Ystorhet
      else
	label=diagram_data["labels"][1];
      if ((label!="")&&(label!=0))
	labelimg=get_font("avant_garde", diagram_data["labelsize"], 0, 0, "left",0,0)->
	  write(label)
->scale(0,diagram_data["labelsize"])
;
      else
	labelimg=image(diagram_data["labelsize"],diagram_data["labelsize"]);
      
      
	//if (labelimg->xsize()> graph->xsize())
	//labelimg->scale(graph->xsize(),labelimg->ysize());
      
      x=max(0,((int)floor((float)xpos_for_yaxis)-labelimg->xsize()/2));
      x=min(x, graph->xsize()-labelimg->xsize());
      
      y=0; 

      
      if (label && sizeof(label))
	graph->paste_alpha_color(labelimg, 
				 @(diagram_data["labelcolor"]), 
				 x,
				 0);
      
      

    }

  //Rita ut datan
  int farg=0;

  foreach(diagram_data["data"], array(float) d)
    {
      for(int i=0; i<sizeof(d); i++)
	{
	  d[i]=(d[i]-diagram_data["xminvalue"])*xmore+xstart;
	  i++;
	  d[i]=-(d[i]-diagram_data["yminvalue"])*ymore+diagram_data["ysize"]-ystart;	  
	}

      graph->setcolor(@(diagram_data["datacolors"][farg++]));

      draw(graph, diagram_data["linewidth"],d);
    }

  diagram_data["ysize"]-=diagram_data["legend_size"];
  diagram_data["image"]=graph;
  return diagram_data;
}


#ifndef ROXEN
int main(int argc, string *argv)
{
  mapping(string:mixed) diagram_data;
  diagram_data=(["type":"graph",
		 "textcolor":({0,255,0}),
		 "subtype":"",
		 "orient":"vert",
		 "data": 
		 ({ ({1.2, 12.3, 4.01, 10.0, 4.3, 12.0 }),
		    ({1.2, 11.3, -1.5, 11.7,  1.0, 11.5, 1.0, 13.0, 2.0, 16.0  }),
		    ({1.2, 13.3, 1.5, 10.1 }),
		    ({3.2, 13.3, 3.5, 13.7} )}),
		 "fontsize":32,
		 "axcolor":({0,0,0}),
		 "bgcolor":0,//({255,255,255}),
		 "labelcolor":({0,0,0}),
		 "datacolors":0,//({({0,255,0}),({255,255,0}), ({0,255,255}), ({255,0,255}) }),
		 "linewidth":2.2,
		 "xsize":400,
		 "ysize":200,
		 "fontsize":16,
		 "labels":({"xstor", "ystor", "xenhet", "yenhet"}),
		 "legendfontsize":12,
		 "legend_texts":({"streck 1", "streck 2", "foo", "bar gazonk foobar illalutta!" 
}),
		 "labelsize":0,
		 "xminvalue":0,
		 "yminvalue":-1,
		 "vertgrind": 1,
		 "grindwidth": 0.5

  ]);

  diagram_data["image"]=image(2,2)->fromppm(read_file("girl.ppm"));

  object o=Stdio.File();
  o->open("test.ppm", "wtc");
  o->write(create_graph(diagram_data)["image"]->toppm());
  //o->write(diagram_data["image"]->toppm());
  o->close();

};
#endif
