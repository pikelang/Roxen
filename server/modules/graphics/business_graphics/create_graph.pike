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


mapping(string:mixed) init(mapping(string:mixed) diagram_data)
{
  float xminvalue=0.0, xmaxvalue=-STORT, yminvalue=0.0, ymaxvalue=-STORT;

  if (diagram_data["type"]=="graph")
    diagram_data["subtype"]="line";
  
  if (diagram_data["type"]=="bars")
    diagram_data["xminvalue"]=0;


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

  foreach(diagram_data["data"], array(float) d)
    {
      int j=sizeof(d);

      if (diagram_data["type"]=="graph")
	for(int i; i<j; i++)
	  {
	    float k;
	    if (xminvalue>(k=d[i]))
	      xminvalue=k;
	    if (xmaxvalue<(k=d[i]))
	      xmaxvalue=k;
	    if (yminvalue>(k=d[++i]))
	      yminvalue=k;
	    if (ymaxvalue<(k=d[i]))
	      ymaxvalue=k;
	  }
      else
	if (diagram_data["type"]=="bars")
	  for(int i; i<j; i++)
	    {
	      float k; 
	      if (yminvalue>(k=d[i]))
		yminvalue=k;
	      if (ymaxvalue<(k=d[i]))
		ymaxvalue=k;
	      xminvalue=0.0;
	      xmaxvalue=10.0;
	    }
	else
	  throw( ({"\""+diagram_data["type"]+"\" is an unknown graph type!\n",
	backtrace()}));
      //werror("\""+diagram_data["type"]+"is an unknown graph type!");
    }
  xmaxvalue=max(xmaxvalue, xminvalue+LITET);
  ymaxvalue=max(ymaxvalue, yminvalue+LITET);

  write("ymaxvalue:"+ymaxvalue+"\n");
  write("yminvalue:"+yminvalue+"\n");
  write("xmaxvalue:"+xmaxvalue+"\n");
  write("xminvalue:"+xminvalue+"\n");

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

  write("Dymaxvalue:"+ diagram_data["ymaxvalue"]+"\n");
  write("Dyminvalue:"+ diagram_data["yminvalue"]+"\n");
  write("Dxmaxvalue:"+diagram_data["xmaxvalue"]+"\n");
  write("Dxminvalue:"+ diagram_data["xminvalue"]+"\n");

  //Ge tomma namn på xnames om namnen inte finns
  //Och ge bars max och minvärde på x-axeln.
  if (diagram_data["type"]=="bars")
    {
      if (!(diagram_data["xnames"]))
	diagram_data["xnames"]=allocate(sizeof(diagram_data["data"][0]));
    }
  //Om xnames finns så sätt xspace om inte values_for_xnames finns
  if (diagram_data["xnames"])
    diagram_data["xspace"]=max((diagram_data["xmaxvalue"]-
				diagram_data["xminvalue"])
			       /(float)sizeof(diagram_data["xnames"]), LITET*20);

  //Om ynames finns så sätt yspace.
  if (diagram_data["ynames"])
    diagram_data["yspace"]=(diagram_data["ymaxvalue"]-
			    diagram_data["yminvalue"])
      /(float)sizeof(diagram_data["ynames"]);
  
  
  return diagram_data;

};

object get_font(string j, int p, int t, int h, string fdg, int s, int hd)
{
  return Image.font()->load("avant_garde");
};


//rita bilderna för texten
//ta ut xmaxynames, ymaxynames xmaxxnames ymaxxnames
mapping(string:mixed) create_text(mapping(string:mixed) diagram_data)
{
  object notext=get_font("avant_garde", 32, 0, 0, "left",0,0);
  int j;
  diagram_data["xnamesimg"]=allocate(j=sizeof(diagram_data["xnames"]));
  for(int i=0; i<j; i++)
    if (((diagram_data["values_for_xnames"][i]>LITET)||(diagram_data["values_for_xnames"][i]<-LITET))&&
	((diagram_data["xnames"][i]) && sizeof(diagram_data["xnames"][i])))
      diagram_data["xnamesimg"][i]=notext->write(diagram_data["xnames"][i])->scale(0,diagram_data["fontsize"]);
    else
      diagram_data["xnamesimg"][i]=
	image(diagram_data["fontsize"],diagram_data["fontsize"]);

  diagram_data["ynamesimg"]=allocate(j=sizeof(diagram_data["ynames"]));
  for(int i=0; i<j; i++)
    if ((diagram_data["values_for_ynames"][i]>LITET)||(diagram_data["values_for_ynames"][i]<-LITET))
      diagram_data["ynamesimg"][i]=notext->write(diagram_data["ynames"][i])->scale(0,diagram_data["fontsize"]);
    else
      diagram_data["ynamesimg"][i]=
	image(diagram_data["fontsize"],diagram_data["fontsize"]);



  if (diagram_data["orient"]=="vert")
    for(int i; i<sizeof(diagram_data["xnamesimg"]); i++)
      {
      diagram_data["xnamesimg"][i]=diagram_data["xnamesimg"][i]->rotate_ccw();
      }
  int xmaxynames=0, ymaxynames=0, xmaxxnames=0, ymaxxnames=0;
  
  foreach(diagram_data["xnamesimg"], object img)
    {
      if (img->ysize()>ymaxxnames) 
	ymaxxnames=img->ysize();
    }
  foreach(diagram_data["xnamesimg"], object img)
    {
      if (img->xsize()>xmaxxnames) 
	xmaxxnames=img->xsize();
    }
  foreach(diagram_data["ynamesimg"], object img)
    {
      if (img->ysize()>ymaxynames) 
	ymaxynames=img->ysize();
    }
  foreach(diagram_data["ynamesimg"], object img)
    {
      if (img->xsize()>xmaxynames) 
	xmaxynames=img->xsize();
    }
  
  diagram_data["ymaxxnames"]=ymaxxnames;
  diagram_data["xmaxxnames"]=xmaxxnames;
  diagram_data["ymaxynames"]=ymaxynames;
  diagram_data["xmaxynames"]=xmaxynames;


}

//Denna funktion returnerar en mapping med 
// (["graph":image-object, "xstart": var_i_bilden_vi_kan_börja_rita_data-int,
//   "ystart": var_i_bilden_vi_kan_börja_rita_data-int,
//   "xstop":int, "ystop":int 
//    osv...]);

/*
 foreach(make_polygon_from_line(...), array(float) p)
    img->polygone(p);
*/

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


//Denna funktion skriver också ut infon i Legenden
mapping set_legend_size(mapping diagram_data)
{
  if (diagram_data["legend_texts"])
    {
      array(object(image)) texts;
      //array(object(image)) plupps; //Det som ska ritas ut före texterna
      array(mixed) plupps; //Det som ska ritas ut före texterna
      texts=allocate(sizeof(diagram_data["legend_texts"]));
      plupps=allocate(sizeof(diagram_data["legend_texts"]));
      
      object notext=get_font("avant_garde", 32, 0, 0, "left",0,0);

      int j=sizeof(texts);
      if (!diagram_data["legendcolor"])
	diagram_data["legendcolor"]=diagram_data["bgcolor"];
      for(int i=0; i<j; i++)
	if (diagram_data["legend_texts"][i] && (sizeof(diagram_data["legend_texts"][i])))
	  texts[i]=notext->write(diagram_data["legend_texts"][i])->
	    scale(0,diagram_data["legendfontsize"]);
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
      write("J:"+j+"\n");
      if ((diagram_data["type"]=="graph") ||
	  (diagram_data["type"]=="bars") ||
	  (diagram_data["type"]=="pie"))
	for(int i=0; i<j; i++)
	  {
	    write("diagram_data[\"legendfontsize\"]"+diagram_data["legendfontsize"]+"\n");

	    plupps[i]=image(diagram_data["legendfontsize"],diagram_data["legendfontsize"]);
	                //,@(diagram_data["legendcolor"]));
	    //write("plupps[i]->xsize()-2"+(plupps[i]->xsize()-2)+"\n");
	    
	    write("\n\n"+sprintf("%O",make_polygon_from_line(diagram_data["linewidth"], 
							 ({
							   (float)(diagram_data["linewidth"]/2+1),
							   (float)(plupps[i]->ysize()-
							   diagram_data["linewidth"]/2-2),
							   (float)(plupps[i]->xsize()-
								   diagram_data["linewidth"]/2-2),
							   (float)(diagram_data["linewidth"]/2+1)
							 }), 
							 1, 1)[0])+"\n"); 
	    write("\n\n"+sprintf("%O",  ({
							   (float)(diagram_data["linewidth"]/2+1),
							   (float)(plupps[i]->ysize()-
							   diagram_data["linewidth"]/2-2),
							   (float)(plupps[i]->xsize()-
								   diagram_data["linewidth"]/2-2),
							   (float)(diagram_data["linewidth"]/2+1)
							 }))+"\n"); 
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
		write("\nboxelibox\n\n");
	      plupps[i]->box(1,
			     1,
			     plupps[i]->xsize()-2,
			     plupps[i]->ysize()-2
			     
			     );
	      /* plupps[i]->setcolor(0,0,0);
	      	      draw(plupps[i], 0.5, 
		   ({1.01, 1 //FIXME
		     ,plupps[i]->xsize()-2.01 , 1, //FIXME
		     plupps[i]->xsize()-2.0, plupps[i]->ysize()-2  //FIXME
		     ,1 , plupps[i]->ysize()-2 //FIXME
		     }));*/ 
	      }
	  }
      else
	throw( ({"\""+diagram_data["type"]+"\" is an unknown graph type!\n",
		 backtrace()}));
      //werror("Graph type unknown!");
      //else FIXME

      //Ta reda på hur många kolumner vi kan ha:
      int b;
      int columnnr=(diagram_data["image"]->xsize()-4)/(b=xmax+2*diagram_data["legendfontsize"]);

      diagram_data["legend_size"]=((j-1)/columnnr+1)*diagram_data["legendfontsize"];
      
      write("diagram_data[\"legend_size\"]:"+diagram_data["legend_size"]+"\n");

      //placera ut bilder och text.
      for(int i; i<j; i++)
	{
	  diagram_data["image"]->paste_alpha_color(plupps[i], 
						   @(diagram_data["datacolors"][i]), 
						   (i%columnnr)*b,
						   (i/columnnr)*diagram_data["legendfontsize"]+
						   diagram_data["image"]->ysize()-diagram_data["legend_size"]
						   
						   );
	  diagram_data["image"]->setcolor(0,0,0);
	  draw( diagram_data["image"], 0.5, 
	       ({(i%columnnr)*b+0.01, (i/columnnr)*diagram_data["legendfontsize"]+
						   diagram_data["image"]->ysize()-diagram_data["legend_size"]+1 //FIXME
		 ,(i%columnnr)*b+plupps[i]->xsize()-0.99 ,  (i/columnnr)*diagram_data["legendfontsize"]+
						   diagram_data["image"]->ysize()-diagram_data["legend_size"]+1, //FIXME
		 (i%columnnr)*b+plupps[i]->xsize()-1.0,  (i/columnnr)*diagram_data["legendfontsize"]+
						   diagram_data["image"]->ysize()-diagram_data["legend_size"]+plupps[i]->ysize()-1  //FIXME
		 ,(i%columnnr)*b+1 ,  (i/columnnr)*diagram_data["legendfontsize"]+
						   diagram_data["image"]->ysize()-diagram_data["legend_size"]+plupps[i]->ysize()-1 //FIXME

		 ,(i%columnnr)*b+0.01, (i/columnnr)*diagram_data["legendfontsize"]+
						   diagram_data["image"]->ysize()-diagram_data["legend_size"]+1 //FIXME

	       })); 
	

	  diagram_data["image"]->paste_alpha_color(texts[i], 
						   @(diagram_data["textcolor"]), 
						   (i%columnnr)*b+1+diagram_data["legendfontsize"],
						   (i/columnnr)*diagram_data["legendfontsize"]+
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

  object(image) graph;
  if (diagram_data["bgcolor"])
    graph=image(diagram_data["xsize"],diagram_data["ysize"],
		@(diagram_data["bgcolor"]));
  else
    graph=diagram_data["image"];

  diagram_data["image"]=graph;
  set_legend_size(diagram_data);

  write("ysize:"+diagram_data["ysize"]+"\n");
  diagram_data["ysize"]-=diagram_data["legend_size"];
  write("ysize:"+diagram_data["ysize"]+"\n");
  
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

      write("range"+range+"\n");
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
      labelimg=get_font("avant_garde", 32, 0, 0, "left",0,0)->
	write(label)->scale(0,diagram_data["labelsize"]);
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
	write("\nNu blev xminvalue noll!\nxmaxynames:"+diagram_data["xmaxynames"]+"\n");
	
	diagram_data["xstop"]=diagram_data["xsize"]-
	  (int)ceil(diagram_data["linewidth"]+si)-labelx/2;
	xpos_for_yaxis=diagram_data["xmaxynames"]+si*2;
	diagram_data["xstart"]=xpos_for_yaxis;
      }
    else
      {
	//sätt y-axeln längst ner och diagram_data["xstart"] en aning högre
	write("\nNu blev xminvalue större än noll!\nxmaxynames:"+diagram_data["xmaxynames"]+"\n");

	diagram_data["xstop"]=diagram_data["xsize"]-
	  (int)ceil(diagram_data["linewidth"]+si)-labelx/2;
	xpos_for_yaxis=diagram_data["xmaxynames"]+si*2;
	diagram_data["xstart"]=xpos_for_yaxis+si*2;
      }
  



  

  
  //Rita ut axlarna
  graph->setcolor(@(diagram_data["axcolor"]));
  
  write((string)diagram_data["xminvalue"]+"\n"+(string)diagram_data["xmaxvalue"]+"\n");

  
  //Rita xaxeln
  if ((diagram_data["xminvalue"]<=LITET)&&
      (diagram_data["xmaxvalue"]>=-LITET))
    graph->
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
	write("xpos_for_yaxis"+xpos_for_yaxis+"\n");

	//diagram_data["xstop"]-=(int)ceil(4.0/3.0*(float)si);
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

					    diagram_data["xsize"]-diagram_data["linewidth"]-labelx/2, 
					    diagram_data["ysize"]-ypos_for_xaxis

					  }), 
					  1, 1)[0]);
      }
    else
      if (diagram_data["xminvalue"]>LITET)
	{
	  //diagram_data["xstart"]+=(int)ceil(4.0/3.0*(float)si);
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
					      
					      diagram_data["xsize"]-diagram_data["linewidth"]-labelx/2, 
					      diagram_data["ysize"]-ypos_for_xaxis
					      
					    }), 
					    1, 1)[0]);

	}
  
  //Rita pilen på xaxeln
  graph->
    polygone(make_polygon_from_line(diagram_data["linewidth"], 
				    ({
				      diagram_data["xsize"]-
				      diagram_data["linewidth"]-
				      (float)si/2.0-labelx/2, 
				      diagram_data["ysize"]-ypos_for_xaxis-
				      (float)si/2.0,
				      diagram_data["xsize"]-
				      diagram_data["linewidth"]-labelx/2, 
				      diagram_data["ysize"]-ypos_for_xaxis,
				      diagram_data["xsize"]-
				      diagram_data["linewidth"]-
				      (float)si/2.0-labelx/2, 
				      diagram_data["ysize"]-ypos_for_xaxis+
				      (float)si/2.0
				    }), 
				    1, 1)[0]);

  //Rita yaxeln
  if ((diagram_data["yminvalue"]<=LITET)&&
      (diagram_data["ymaxvalue"]>=-LITET))
      graph->
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
					    diagram_data["linewidth"]+
					    diagram_data["labelsize"]
					  }), 
					  1, 1)[0]);
      }
    else
      if (diagram_data["yminvalue"]>LITET)
	{/*
	  write("\n\n"+sprintf("%O",make_polygon_from_line(diagram_data["linewidth"], 
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
					    
					      xpos_for_yaxis+0.0001, //FIXME!
					      diagram_data["linewidth"]+
					      diagram_data["labelsize"]
					      
					    }), 
					    1, 1)[0])+
					    "\n\n");*/
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
					    
					      xpos_for_yaxis+0.0001, //FIXME!
					      diagram_data["linewidth"]+
					      diagram_data["labelsize"]
					      
					    }), 
					    1, 1)[0]);

	}
    
  //Rita pilen
  graph->
    polygone(make_polygon_from_line(diagram_data["linewidth"], 
				    ({
				      xpos_for_yaxis-
				      (float)si/2.0,
				      diagram_data["linewidth"]+
				      (float)si/2.0+
					  diagram_data["labelsize"],
				      
				      xpos_for_yaxis,
				      diagram_data["linewidth"]+
					  diagram_data["labelsize"],
	
				      xpos_for_yaxis+
				      (float)si/2.0,
				      diagram_data["linewidth"]+
				      (float)si/2.0+
					  diagram_data["labelsize"]
				    }), 
				    1, 1)[0]);


  //Räkna ut lite skit
  float xstart=(float)diagram_data["xstart"];
  float xmore=(-xstart+diagram_data["xstop"])/
    (diagram_data["xmaxvalue"]-diagram_data["xminvalue"]);
  float ystart=(float)diagram_data["ystart"];
  float ymore=(-ystart+diagram_data["ystop"])/
    (diagram_data["ymaxvalue"]-diagram_data["yminvalue"]);
  
  

  //Placera ut texten på X-axeln
  int s=sizeof(diagram_data["xnamesimg"]);
  for(int i=0; i<s; i++)
    {
      graph->paste_alpha_color(diagram_data["xnamesimg"][i], 
			       @(diagram_data["textcolor"]), 
			       (int)floor((diagram_data["values_for_xnames"][i]-
					   diagram_data["xminvalue"])
					  *xmore+xstart
					  -
					  diagram_data["xnamesimg"][i]->xsize()/2), 
			       (int)floor(diagram_data["ysize"]-ypos_for_xaxis+
					  si/2.0));
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
      write("\nYmaXnames:"+diagram_data["ymaxynames"]+"\n");
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
      labelimg=get_font("avant_garde", 32, 0, 0, "left",0,0)->
	write(label)->scale(0,diagram_data["labelsize"]);
      
      
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
  write("xstart:"+diagram_data["xstart"]+"\nystart"+diagram_data["ystart"]+"\n");
  write("xstop:"+diagram_data["xstop"]+"\nystop"+diagram_data["ystop"]+"\n");

  foreach(diagram_data["data"], array(float) d)
    {
      for(int i=0; i<sizeof(d); i++)
	{
	  d[i]=(d[i]-diagram_data["xminvalue"])*xmore+xstart;
	  i++;
	  d[i]=-(d[i]-diagram_data["yminvalue"])*ymore+diagram_data["ysize"]-ystart;	  
	}

      graph->setcolor(@(diagram_data["datacolors"][farg++]));
      //graph->polygone(make_polygon_from_line(diagram_data["linewidth"],d,
      //				     1, 1)[0]);
      draw(graph, diagram_data["linewidth"],d);
    }

  diagram_data["ysize"]-=diagram_data["legend_size"];
  diagram_data["image"]=graph;
  return diagram_data;
}


int main(int argc, string *argv)
{
  write("\nRitar axlarna. Filen sparad som test.ppm\n");

  mapping(string:mixed) diagram_data;
  diagram_data=(["type":"graph",
		 "textcolor":({0,0,0}),
		 "subtype":"",
		 "orient":"vert",
		 "data": 
		 ({ ({1.2, 12.3, 4.01, 10.0, 4.3, 12.0 }),
		    ({1.2, 11.3, -1.5, 11.7,  1.0, 11.5, 1.0, 13.0, 2.0, 16.0  }),
		    ({1.2, 13.3, 1.5, 10.1 }),
		    ({3.2, 13.3, 3.5, 13.7} )}),
		 "fontsize":32,
		 "axcolor":({0,0,0}),
		 "bgcolor":({255,255,255}),
		 "labelcolor":({0,0,0}),
		 "datacolors":({({0,255,0}),({255,255,0}), ({0,255,255}), ({255,0,255}) }),
		 "linewidth":2.2,
		 "xsize":400,
		 "ysize":200,
		 "fontsize":16,
		 "labels":({"xstor", "ystor", "xenhet", "yenhet"}),
		 "legendfontsize":12,
		 "legend_texts":({"streck 1", "streck 2", "foo", "bar gazonk foobar illalutta!" }),
		 "labelsize":0,
		 "xminvalue":0.1,
		 "yminvalue":0.1

  ]);
  /*
  diagram_data["data"]=({({ 
     101.858620,
    146.666672,
    101.825584,
    146.399109,
    101.728462,
    146.147629,
    101.573090,
    145.927322,
    101.368790,
    145.751419,
    95.240158,
    141.665649,
    109.106468,
    137.043549,
    109.606232,
    136.701111,
    109.848892,
    136.145996,
    109.760834,
    135.546616,
    109.368790,
    135.084732,
    101.858620,
    130.077972,
    101.858719,
    2.200001,
    101.792381,
    1.823779,
    101.601372,
    1.492934,
    101.308723,
    1.247373,
    100.949730,
    1.116712,
    100.567711,
    1.116711,
    100.208717,
    1.247372,
    99.916069,
    1.492933,
    99.725060,
    1.823777,
    99.658722,
    2.199999,
    99.658623,
    130.666672,
    99.691658,
    130.934219,
    99.788780,
    131.185715,
    99.944160,
    131.406036,
    100.148453,
    131.581924,
    106.277084,
    135.667679,
    92.410774,
    140.289780,
    91.911018,
    140.632217,
    91.668350,
    141.187317,
    91.756401,
    141.786713,
    92.148453,
    142.248581,
    99.658623,
    147.255371,
    99.658623,
    397.799988,
    99.724960,
    398.176208,
    99.915970,
    398.507050,
    100.208618,
    398.752625,
    100.567612,
    398.883270,
    100.949631,
    398.883270,
    101.308624,
    398.752625,
    101.601273,
    398.507050,
    101.792282,
    398.176208,
    101.858620,
    397.799988

})});
  */

  object o=Stdio.File();
  o->open("test.ppm", "wtc");
  o->write(create_graph(diagram_data)["image"]->toppm());
  o->close();

};
