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

/*
These functions is written by Henrik "Hedda" Wallin (hedda@idonex.se)
Create_bars can draw normal bars, sumbars and normalized sumbars.
*/ 



mapping(string:mixed) create_bars(mapping(string:mixed) diagram_data)
{
  //Supportar bara xsize>=100
  int si=diagram_data["fontsize"];
 
  //Fixa defaultfärger!
  setinitcolors(diagram_data);


  string where_is_ax;

  object(image) barsdiagram;

  init_bg(diagram_data);
  barsdiagram=diagram_data["image"];
  set_legend_size(diagram_data);

  //write("ysize:"+diagram_data["ysize"]+"\n");
  diagram_data["ysize"]-=diagram_data["legend_size"];
  //write("ysize:"+diagram_data["ysize"]+"\n");
  

  //Bestäm största och minsta datavärden.
  init(diagram_data);

  //Ta reda hur många och hur stora textmassor vi ska skriva ut
  if (!(diagram_data["xspace"]))
    {
      //Initera hur långt det ska vara emellan.
      
      float range=(diagram_data["xmaxvalue"]-
		 diagram_data["xminvalue"]);
      //write("range"+range+"\n");
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
 


  if (1)
    {
      float start;
      start=diagram_data["xminvalue"]+diagram_data["xspace"]/2.0;
      diagram_data["values_for_xnames"]=allocate(sizeof(diagram_data["xnames"]));
      for(int i=0; i<sizeof(diagram_data["xnames"]); i++)
	diagram_data["values_for_xnames"][i]=start+start*2*i;
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
  si=diagram_data["fontsize"];

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
  else
    diagram_data["labelsize"]=0;



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
      minpos=max(labely, diagram_data["ymaxxnames"])+si/2.0;
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
	    (int)ceil(diagram_data["linewidth"]+si*2.0)-
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
	ypos_for_xaxis=max(labely, diagram_data["ymaxxnames"])+si/2.0;
	diagram_data["ystart"]=ypos_for_xaxis;
      }
    else
      {
	//sätt x-axeln längst ner och diagram_data["ystart"] en aning högre
	diagram_data["ystop"]=diagram_data["ysize"]-
	  (int)ceil(diagram_data["linewidth"]+si)-diagram_data["labelsize"];
	ypos_for_xaxis=max(labely, diagram_data["ymaxxnames"])+si/2.0;
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
      minpos=diagram_data["xmaxynames"]+si/2.0;
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
	    (int)ceil(diagram_data["linewidth"]+si*2.0)-
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
	xpos_for_yaxis=diagram_data["xmaxynames"]+si/2.0;
	diagram_data["xstart"]=xpos_for_yaxis;
      }
    else
      {
	//sätt y-axeln längst ner och diagram_data["xstart"] en aning högre
	//write("\nNu blev xminvalue större än noll!\nxmaxynames:"+diagram_data["xmaxynames"]+"\n");

	diagram_data["xstop"]=diagram_data["xsize"]-
	  (int)ceil(diagram_data["linewidth"]+si)-labelx/2;
	xpos_for_yaxis=diagram_data["xmaxynames"]+si/2.0;
	diagram_data["xstart"]=xpos_for_yaxis+si*2;
      }
  



  


  //Räkna ut lite skit
  float xstart=(float)diagram_data["xstart"];
  float xmore=(-xstart+diagram_data["xstop"])/
    (diagram_data["xmaxvalue"]-diagram_data["xminvalue"]);
  float ystart=(float)diagram_data["ystart"];
  float ymore=(-ystart+diagram_data["ystop"])/
    (diagram_data["ymaxvalue"]-diagram_data["yminvalue"]);
  
  
  draw_grind(diagram_data, xpos_for_yaxis, ypos_for_xaxis, 
	     xmore, ymore, xstart, ystart, (float) si);
  


  //Rita ut bars datan
  int farg=0;
  //write("xstart:"+diagram_data["xstart"]+"\nystart"+diagram_data["ystart"]+"\n");
  //write("xstop:"+diagram_data["xstop"]+"\nystop"+diagram_data["ystop"]+"\n");

  if (diagram_data["type"]=="sumbars")
    {
      int s=diagram_data["datasize"];
      float barw=diagram_data["xspace"]*xmore/3.0;
      for(int i=0; i<s; i++)
	{
	  int j=0;
	  float x,y;
	  x=xstart+(diagram_data["xspace"]/2.0+diagram_data["xspace"]*i)*
	    xmore;
	  
	  y=-(-diagram_data["yminvalue"])*ymore+
	    diagram_data["ysize"]-ystart;	 
	  float start=y;

	  foreach(column(diagram_data["data"], i), float d)
	    {
	      y-=d*ymore;
	      
	      
	      barsdiagram->setcolor(@(diagram_data["datacolors"][j++]));
	      
	      barsdiagram->polygone(
				    ({x-barw+0.01, y //FIXME
				      , x+barw+0.01, y, //FIXME
				      x+barw, start
				      , x-barw, start
				    }));  
	      barsdiagram->setcolor(0,0,0);
	      draw(barsdiagram, 0.5, 
		   ({
		     x-barw, start,
		     x-barw+0.01, y //FIXME
		     , x+barw+0.01, y, //FIXME
		     x+barw, start

		   })
		   );

	      start=y;
	    }
	}
    }
  else
  if (diagram_data["subtype"]=="line")
    if (diagram_data["drawtype"]=="linear")
      foreach(diagram_data["data"], array(float) d)
	{
	  array(float) l=allocate(sizeof(d)*2);
	  for(int i=0; i<sizeof(d); i++)
	    {
	      l[i*2]=xstart+(diagram_data["xspace"]/2.0+diagram_data["xspace"]*i)*
		xmore;
	      l[i*2+1]=-(d[i]-diagram_data["yminvalue"])*ymore+
		diagram_data["ysize"]-ystart;	  
	    }
	  
	  //Draw Ugly outlines
	  if ((diagram_data["backdatacolors"])&&
	      (diagram_data["backlinewidth"]))
	    {
	      barsdiagram->setcolor(@(diagram_data["backdatacolors"][farg]));
	      draw(barsdiagram, diagram_data["backlinewidth"],l);
	    }

	  barsdiagram->setcolor(@(diagram_data["datacolors"][farg++]));
	  draw(barsdiagram, diagram_data["linewidth"],l);
	}
    else
      throw( ({"\""+diagram_data["drawtype"]+"\" is an unknown bars-diagram drawtype!\n",
	       backtrace()}));
  else
    if (diagram_data["subtype"]=="box")
      if (diagram_data["drawtype"]=="2D")
	{
	  int s=sizeof(diagram_data["data"]);
	  float barw=diagram_data["xspace"]*xmore/1.5;
	  float dnr=-barw/2.0+ barw/s/2.0;
	  barw/=s;
	  barw/=2.0;
	  farg=-1;
	  foreach(diagram_data["data"], array(float) d)
	    {
	      farg++;

	      for(int i=0; i<sizeof(d); i++)
		{
		  float x,y;
		  x=xstart+(diagram_data["xspace"]/2.0+diagram_data["xspace"]*i)*
		    xmore;
		  y=-(d[i]-diagram_data["yminvalue"])*ymore+
		    diagram_data["ysize"]-ystart;	 
		  
		  // if (y>diagram_data["ysize"]-ypos_for_xaxis-diagram_data["linewidth"]) 
		  // y=diagram_data["ysize"]-ypos_for_xaxis-diagram_data["linewidth"];

		  barsdiagram->setcolor(@(diagram_data["datacolors"][farg]));
  
		  barsdiagram->polygone(
					({x-barw+0.02+dnr, y //FIXME
					  , x+barw+0.02+dnr, y, //FIXME
					  x+barw+dnr, diagram_data["ysize"]-ypos_for_xaxis
					  , x-barw+dnr,diagram_data["ysize"]- ypos_for_xaxis
					})); 
		  barsdiagram->setcolor(0,0,0);		  
		  draw(barsdiagram, 0.5, 
		       ({x-barw+0.01+dnr, y //FIXME
			 , x+barw+0.01+dnr, y, //FIXME
			 x+barw+dnr, diagram_data["ysize"]-ypos_for_xaxis
			 , x-barw+dnr,diagram_data["ysize"]- ypos_for_xaxis,
			 x-barw+0.01+dnr, y //FIXME
			 }));
		}
	      dnr+=barw*2.0;
	    }   
	}
      else
	throw( ({"\""+diagram_data["drawtype"]+"\" is an unknown bars-diagram drawtype!\n",
		 backtrace()}));
    else
      throw( ({"\""+diagram_data["subtype"]+"\" is an unknown bars-diagram subtype!\n",
	       backtrace()}));


  
  //Rita ut axlarna
  barsdiagram->setcolor(@(diagram_data["axcolor"]));
  
  //write((string)diagram_data["xminvalue"]+"\n"+(string)diagram_data["xmaxvalue"]+"\n");

  
  //Rita xaxeln
  if ((diagram_data["xminvalue"]<=LITET)&&
      (diagram_data["xmaxvalue"]>=-LITET))
    barsdiagram->
      polygone(make_polygon_from_line(diagram_data["linewidth"], 
				      ({
					diagram_data["linewidth"],
					diagram_data["ysize"]- ypos_for_xaxis,
					diagram_data["xsize"]-
					diagram_data["linewidth"]-labelx/2, 
					diagram_data["ysize"]-ypos_for_xaxis
				      }), 
				      1, 1)[0]);
  else
    if (diagram_data["xmaxvalue"]<-LITET)
      {
	//write("xpos_for_yaxis"+xpos_for_yaxis+"\n");

	//diagram_data["xstop"]-=(int)ceil(4.0/3.0*(float)si);
	barsdiagram->
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

					    diagram_data["xsize"]-diagram_data["linewidth"]-labelx/2, 
					    diagram_data["ysize"]-ypos_for_xaxis

					  }), 
					  1, 1)[0]);
      }
    else
      if (diagram_data["xminvalue"]>LITET)
	{
	  //diagram_data["xstart"]+=(int)ceil(4.0/3.0*(float)si);
	  barsdiagram->
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
					      
					      diagram_data["xsize"]-diagram_data["linewidth"]-labelx/2, 
					      diagram_data["ysize"]-ypos_for_xaxis
					      
					    }), 
					    1, 1)[0]);

	}
  
  //Rita pilen på xaxeln

  //Rita yaxeln
  if ((diagram_data["yminvalue"]<=LITET)&&
      (diagram_data["ymaxvalue"]>=-LITET))
      barsdiagram->
	polygone(make_polygon_from_line(diagram_data["linewidth"], 
					({
					  xpos_for_yaxis,
					  diagram_data["ysize"]-diagram_data["linewidth"],
					  
					  xpos_for_yaxis,
					  diagram_data["linewidth"]+
					  diagram_data["labelsize"]
					}), 
					1, 1)[0]);
  else
    if (diagram_data["ymaxvalue"]<-LITET)
      {
	barsdiagram->
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
					    diagram_data["linewidth"]+
					    diagram_data["labelsize"]
					  }), 
					  1, 1)[0]);
      }
    else
      if (diagram_data["yminvalue"]>LITET)
	{
	  barsdiagram->
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
					      diagram_data["linewidth"]+
					      diagram_data["labelsize"]
					      
					    }), 
					    1, 1)[0]);

	}
    
  //Rita pilen
  barsdiagram->
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
  



  //Placera ut texten på X-axeln
  int s=sizeof(diagram_data["xnamesimg"]);
  for(int i=0; i<s; i++)
    {
      barsdiagram->paste_alpha_color(diagram_data["xnamesimg"][i], 
			       @(diagram_data["textcolor"]), 
			       (int)floor((diagram_data["values_for_xnames"][i]-
					   diagram_data["xminvalue"])
					  *xmore+xstart
					  -
					  diagram_data["xnamesimg"][i]->xsize()/2), 
			       (int)floor(diagram_data["ysize"]-ypos_for_xaxis+
					  si/4.0));
    }

  //Placera ut texten på Y-axeln
  s=sizeof(diagram_data["ynamesimg"]);
  for(int i=0; i<s; i++)
    {
      //write("\nYmaXnames:"+diagram_data["ymaxynames"]+"\n");
      barsdiagram->setcolor(@diagram_data["textcolor"]);
      barsdiagram->paste_alpha_color(diagram_data["ynamesimg"][i], 
			       @(diagram_data["textcolor"]), 
			       (int)floor(xpos_for_yaxis-
					  si/4.0-diagram_data["linewidth"]*2-
					  diagram_data["ynamesimg"][i]->xsize()),
			       (int)floor(-(diagram_data["values_for_ynames"][i]-
					    diagram_data["yminvalue"])
					  *ymore+diagram_data["ysize"]-ystart
					  -
					  diagram_data["ymaxynames"]/2));

      barsdiagram->setcolor(@diagram_data["axcolor"]);
      barsdiagram->
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
      barsdiagram->paste_alpha_color(labelimg, 
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
      
      
	//if (labelimg->xsize()> barsdiagram->xsize())
	//labelimg->scale(barsdiagram->xsize(),labelimg->ysize());
      
      x=max(0,((int)floor((float)xpos_for_yaxis)-labelimg->xsize()/2));
      x=min(x, barsdiagram->xsize()-labelimg->xsize());
      
      y=0; 

      
      if (label && sizeof(label))
	barsdiagram->paste_alpha_color(labelimg, 
				 @(diagram_data["labelcolor"]), 
				 x,
				 0);
      
      

    }


  diagram_data["ysize"]-=diagram_data["legend_size"];
  diagram_data["image"]=barsdiagram;
  return diagram_data;



}

#ifndef ROXEN
int main(int argc, string *argv)
{
  //write("\nRitar axlarna. Filen sparad som test.ppm\n");

  mapping(string:mixed) diagram_data;
  diagram_data=(["type":"bars",
		 "textcolor":({0,255,0}),
		 "subtype":"box",
		 "orient":"hor",
		 "data": 
		 ({ ({12.2, 10.3, 8.01, 9.0, 5.3, 4.0 }),
		     ({91.2, 101.3, 91.5, 101.7,  141.0, 181.5}),
		    ({191.2, 203.3, 241.5, 200.1, 194.3, 195.2 }),
		    ({93.2, 113.3, 133.5, 143.7, 154.3, 400}) }),
		 "axcolor":({0,0,255}),
		 "bgcolor":0,//({255,255,255}),
		 "labelcolor":({0,0,0}),
		 //"datacolors":({({0,255,0}),({255,255,0}), ({0,255,255}), ({255,0,255}) }),
		 "linewidth":2.2,
		 "backlinewidth":0,
		 "xsize":400,
		 "ysize":200,
		 "xnames":({"jan", "feb", "mar", "apr", "maj"//, "jun"
}),
		 "fontsize":42,
		 "labels":0,//({"xstor", "ystor", "xenhet", "yenhet"}),
		 "legendfontsize":25, 
		 "legend_texts":({"Roxen", "Netscape", "Apache", "Microsoft" }),
		 "labelsize":22,
		 "xminvalue":0.1,
		 "yminvalue":0,
		 "horgrind": 1,
		 "grindwidth": 0.5,
		 "backlinecolor":1.0,
		 "bw":3,
		 "xnames":({"hej", "olle"})
  ]);

    diagram_data["image"]=image(2,2)->fromppm(read_file("girl.ppm"));
  diagram_data["image"]=diagram_data["image"]->copy(10,10, diagram_data["image"]->xsize()-10,
  diagram_data["image"]->ysize()-10);


  object o=Stdio.File();
  o->open("test.ppm", "wtc");
  o->write(create_bars(diagram_data)["image"]->toppm());
  o->close();
 
};
#endif
