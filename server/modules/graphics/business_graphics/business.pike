/* This is a roxen module. (c) Idonex AB 1997.
 * 
 * Draws diagrams pleasing to the eye.
 * 
 * Made by Peter Bortas <peter@idonex.se> and Henrik Wallin <hedda@idonex.se>
 * in October 1997
 */

constant cvs_version = "$Id: business.pike,v 1.84 1998/03/07 00:05:14 hedda Exp $";
constant thread_safe=1;

#include <module.h>
#include <roxen.h>

inherit "module";
inherit "roxenlib";
import Array;
import Image;

function create_pie, create_bars, create_graph;

#define SEP "\t"
#define VOIDSYMBOL "\n"

//FIXME (Inte alltid VOID!
#define VOIDCODE if(m->voidseparator) \
    voidsep=m->voidseparator; \
  else\
    if(m->voidsep)\
      voidsep=m->voidsep;\
    else\
      if (res->voidsep)\
	voidsep=res->voidsep;\
      else\
	voidsep="VOID";


int loaded;

mixed *register_module()
{
  return ({ 
    MODULE_PARSER|MODULE_LOCATION,
    "Business Graphics",
    (  !loaded?
       "The Business Graphics tag. This module draws\n"
       "line charts, pie charts, graphs and bar charts.<p>\n"
       "&lt;diagram help&gt;&lt;/diagram&gt; gives help.\n"
       :
       "<font size=+1><b>The Business Graphics tag</b></font>\n<br>"
       "Draws different kinds of diagrams.<br>"
       "<p><pre>"
       "\n&lt;<b>diagram</b>&gt; (container)\n"
       "Options:\n"
       "  <b>help</b>           Displays this text.\n"
       "  <b>type</b>           Mandatory. Type of graph. Valid types are:\n"
       "                 <b>sumbars</b>, <b>normsumbars</b>, <b>linechart</b>,"
       " <b>barchart</b>,\n"
       "                 <b>piechart</b> and <b>graph</b>\n"
#if constant(Image.JPEG.decode)
       "  <b>background</b>     Takes the filename of a pnm-, gif- or\n"
       "                 jpeg-image as input.\n"
#else
       "  <b>background</b>     Takes the filename of a pnm image as input.\n"
#endif
       "  <b>width</b>          Width of diagram image in pixels.\n"
       "                 (will not have any effect below 100)\n"
       "  <b>height</b>         Height of diagram image in pixels.\n"
       "                 (will not have any effect below 100)\n"
       "  <b>fontsize</b>       Height of text in pixels.\n"
       "  <b>legendfontsize</b> Height of legend text in pixels.\n"
       "                 <b>fontsize</b> is used if this is undefined.\n"
       "  <b>name</b>           Writes a name at the top of the diagram.\n"
       "  <b>namecolor</b>      The color of the name-text. Textcolor\n"
       "                 is used if this is not defined.\n"
       "  <b>namesize</b>       Height of the name text in pixels.\n"
       "                 <b>Fontsize</b> is used if this is undefined.\n"
       "  <b>grey</b>           Makes the default colors in greyscale.\n"

       "  <b>3D</b>             Render piecharts on top of a cylinder, takes"
       " the\n                 height in pixels of the cylinder as argument.\n"
       /* " tone         Do nasty stuff to the background.\n"
	  " Requires dark background to be visable.\n" */
       "  <b>eng</b>            If present, numbers are shown like 1.2M.\n"
       "  <b>neng</b>           As above but 0.1-1.0 is written 0.xxx .\n"
       "  <b>tonedbox</b>       Creates a background shading between the\n"
       "                 colors assigned to each of the four corners.\n"
       "  <b>center</b>         (Only for <b>pie</b>) center=n centers the nth"
       " slice\n"
       "  <b>voidsep</b>        If this separator is given it will be used\n"
       "                 instead of VOID (This option can also\n"
       "                 be given i <b>xnames</b> and so on)\n"
       "  <b>bgcolor</b>        Use this background color for antialias.\n"
       "  <b>colorbg</b>        Sets the color for the background\n"
       "  <b>textcolor</b>      Sets the color for all text\n"
       "                 (Can be overrided)\n"
       "  <b>labelcolor</b>     Sets the color for the labels of the axis\n"

       "  <b>horgrid</b>        If present a horizontal grid is drawn\n"
       "  <b>vertgrid</b>       If present a vertical grid is drawn\n"
       "  <b>xgridspace</b>     The space between two vertical grids in the\n"
       "                 same unit as the data.\n"
       "  <b>ygridspace</b>     The space between two horizontal grids in\n"
       "                 the same unit as the data.\n"

       "\n  You can also use the regular &lt;<b>img</b>&gt; arguments. They"
       " will be passed\n  on to the resulting &lt;<b>img</b>&gt; tag.\n\n"
       "The following internal tags are available:\n"
       "\n&lt;<b>data</b>&gt; (container) Mandatory.\n"
       "Tab and newline separated list of data values for the diagram."
       " Options:\n"
       "  <b>separator</b>      Use the specified string as separator instead"
       " of tab.\n"
       "  <b>lineseparator</b>  Use the specified string as lineseparator\n"
       "                 instead of newline.\n"
       "  <b>form</b>           Can be set to either row or column. Default\n"
       "                 is row.\n"
       "  <b>noparse</b>        Do not run the content of the tag through\n"
       "                 the RXML parser before data extraction is done.\n"
       "\n&lt;<b>colors</b>&gt; (container)\n"
       "Tab separated list of colors for the diagram. Options:\n"
       "  <b>separator</b>      Use the specified string as separator instead"
       " of tab.\n"
       "\n&lt;<b>legend</b>&gt; (container)\n"
       "Tab separated list of titles for the legend. Options:\n"
       "  <b>separator</b>      Use the specified string as separator instead"
       " of tab.\n"
       "\n&lt;<b>xnames</b>&gt; (container)\n"
       "Tab separated list of datanames for the diagram. Options:\n"
       "  <b>separator</b>      Use the specified string as separator instead"
       " of tab.\n"
       "  <b>orient</b>         If set to vert the xnames will be written"
       " vertical.\n"
       "\n&lt;<b>ynames</b>&gt; (container)\n"
       "Tab separated list of datanames for the diagram. Options:\n"
       "  <b>separator</b>      Use the specified string as separator instead"
       " of tab.\n"
       "\n&lt;<b>xaxis</b>&gt; and &lt;<b>yaxis</b>&gt; (tags)\n"
       "Options:\n"
       /* " name=        Dunno what this does.\n" */
       //I know!!! /Hedda
       "  <b>start</b>          Limit the start of the diagram at this"
       " quantity.\n"
       "                 If set to <b>min</b> the axis starts at the lowest"
       " value.\n\n"
       "  <b>stop</b>           Limit the end of the diagram at this"
       " quantity.\n"
       "  <b>quantity</b>       Name things represented in the diagram.\n"
       "  <b>unit</b>           Name the unit.\n"
       "</pre>"
       ), ({}), 1,
    });
}

void start(int num, object configuration)
{
  loaded = 1;
  program Bars  = (program)"create_bars";
  program Graph = (program)"create_graph";
  program Pie   = (program)"create_pie";
  create_pie   = Pie()->create_pie;
  create_bars  = Bars()->create_bars;
  create_graph = Graph()->create_graph;
}

void stop()
{
  /* Reload Pie, Bars and Graph */
  mapping progs = master()->programs;
  foreach(glob(combine_path(roxen->filename(this),"../*"), indices(progs)),
          string to_delete)
    m_delete(progs, to_delete);
}

void create()
{
  defvar( "location", "/diagram/", "Mountpoint", TYPE_LOCATION|VAR_MORE,
	  "The URL-prefix for the diagrams." );
  defvar( "maxwidth", 3000, "Limits:Max width", TYPE_INT,
	  "Maximal width of the generated image." );
  defvar( "maxheight", 1000, "Limits:Max height", TYPE_INT,
	  "Maximal height of the generated image." );
  defvar( "maxstringlength", 60, "Limits:Max string length", TYPE_INT,
	  "Maximal length of the strings used in the diagram." );
}

string itag_xaxis(string tag, mapping m, mapping res)
{
  if(m->name) res->xname = m->name;  
  if(m->start) 
    if (lower_case(m->start[0..2])=="min")
      res->xmin=1;
    else 
      res->xstart = (float)m->start;
  if(m->stop) res->xstop = (float)m->stop;
  if(m->quantity) res->xstor = m->quantity;
  if(m->unit) res->xunit = m->unit;

  return "";
}

string itag_yaxis(string tag, mapping m, mapping res)
{
  int l=query("maxstringlength")-1;
  if(m->name) res->yname = m->name[..l];
  if(m->start) 
    if (lower_case(m->start[0..2])=="min")
      res->ymin=1;
    else 
      res->ystart = (float)m->start;
  if(m->stop) res->ystop = (float)m->stop;
  if(m->quantity) res->ystor = m->quantity[..l];
  if(m->unit) res->yunit = m->unit[..l];

  return "";
}

/* Handle <xnames> and <ynames> */
string itag_names(string tag, mapping m, string contents,
		      mapping res, object id)
{
  int l=query("maxstringlength")-1;
  string sep=SEP;
  if(!m->noparse)
    contents = parse_rxml( contents, id );

  if(m->separator)
    sep=m->separator;

  string voidsep;
  VOIDCODE

  array foo;
  if( contents-" " != "" )
  {
    if(tag=="xnames")
    {
      foo=res->xnames = contents/sep;
      if(m->orient) 
	if (m->orient[0..3] == "vert")
	  res->orientation = "vert";
	else 
	  res->orientation="hor";
    }
    else
      foo=res->ynames = contents/sep;
  }
  
  for(int i=0; i<sizeof(foo); i++)
    if (voidsep==foo[i])
      foo[i]=" ";
    else
      foo[i]=foo[i][..l];
  return "";
}

float|string floatify( string in , string voidsep )
{
  if (voidsep==in)
    return VOIDSYMBOL;
  else
    return (float)in;
}

/* Handle <xvalues> and <yvalues> */
string itag_values(string tag, mapping m, string contents,
		   mapping res, object id)
{
  string sep=SEP;
  string voidsep;

  VOIDCODE

  if(!m->noparse)
    contents = parse_rxml( contents, id );

  if(m->separator)
    sep=m->separator;
  
  if( contents-" " != "" )
  {
    if(tag=="xvalues")
      res->xvalues = Array.map( contents/sep, floatify, voidsep );
    else
      res->yvalues = Array.map( contents/sep, floatify, voidsep );
  }

  return "";
}

string itag_data(mapping tag, mapping m, string contents,
		 mapping res, object id)
{
  string sep=SEP;
  string voidsep;

  VOIDCODE

  if(m->separator)
    sep=m->separator; 

  if (sep=="")
    sep=SEP;

  string linesep="\n";
  if(m->lineseparator)
    linesep=m->lineseparator; 

  if (linesep=="")
    linesep="\n";
  
  if(!m->noparse)
    contents = parse_rxml( contents, id );

  if ((sep!=" ")&&(linesep!=" "))
    contents = contents - " ";

  if ((sep!="\t")&&(linesep!="\t"))
    contents = contents - "\t";

  array lines = contents/linesep-({""});
  array foo = ({});
  array bar = ({});
  int maxsize=0;

  if (sizeof(lines)==0)
  {
    res->data=({});
    return 0;
  }

  foreach( lines, string entries )
  {
    foreach( entries/sep - ({""}), string gaz)
      if (gaz==voidsep)
	foo+=({ VOIDSYMBOL });  //FIXME?
      else
	foo += ({ gaz });
    if (sizeof(foo)>maxsize)
      maxsize=sizeof(foo);
    bar += ({ foo });
    foo = ({});
  }
  
  if (sizeof(bar[0])==0)
  {
    res->data=({});
    return 0;
  }

  if (m->form)
    if (m->form[0..2] == "col")
      {
	for(int i=0; i<sizeof(bar); i++)
	  if (sizeof(bar[i])<maxsize)
	    bar[i]+=allocate(maxsize-sizeof(bar[i]));
	
	array bar2=allocate(maxsize);
	for(int i=0; i<maxsize; i++)
	  bar2[i]=column(bar, i);
	res->data=bar2;
      } 
    else
      res->data=bar;
  else
    res->data=bar;

  if ((m->xnames)&&(sizeof(res->data)>0))
    {
      res->xnames=res->data[0];
      res->data=res->data[1..];
    }
  bar=res->data;
  for(int i=0; i<sizeof(bar); i++)
    for(int j=0; j<sizeof(bar[i]); j++)
      if (bar[i][j]!=VOIDSYMBOL)
	bar[i][j]=(float)bar[i][j];
  res->data=bar;
  return 0;
}

string itag_colors(mapping tag, mapping m, string contents,
		   mapping res, object id)
{
  string sep=SEP;
  if(!m->noparse)
    contents = parse_rxml( contents, id );

  if(m->separator) sep=m->separator;
  
  res->colors = map(contents/sep, parse_color); 

  return "";
}

string itag_legendtext(mapping tag, mapping m, string contents,
		       mapping res, object id)
{
  int l=query("maxstringlength")-1;
  string sep=SEP;
  string voidsep;

  VOIDCODE

  if(!m->noparse)
    contents = parse_rxml( contents, id );

  if(m->separator)
    sep=m->separator;

  res->legend_texts = contents/sep;

  array foo=res->legend_texts;

  for(int i=0; i<sizeof(foo); i++)
    if (voidsep==foo[i])
      foo[i]=" ";
    else
      foo[i]=foo[i][..l];


  return "";
}

string syntax( string error )
{
  return "<hr noshade><font size=+1><b>Syntax error</b></font>&nbsp;&nbsp;"
         "(&lt;<b>diagram help</b>&gt;&lt;/<b>diagram</b>&gt; gives help)<p>"
    + error
    + "<hr noshade>";
}

mapping(string:mapping) cache = ([]);
int datacounter = 0; 

string quote(mapping in)
{
  // Don't try to be clever here. It will break threads.
  string out;
  cache[ out =
       sprintf("%d%08x%x", ++datacounter, random(99999999), time(1)) ] = in;
  
  return out;
}

constant _diagram_args =
({ "xgridspace", "ygridspace", "horgrid", "size", "type", "3d",
   "templatefontsize", "fontsize", "tone", "background","colorbg", "subtype",
   "dimensions", "dimensionsdepth", "xsize", "ysize", "fg", "bg",
   "orientation", "xstart", "xstop", "ystart", "ystop", "data", "colors",
   "xnames", "xvalues", "ynames", "yvalues", "axcolor", "gridcolor",
   "gridwidth", "vertgrid", "labels", "labelsize", "legendfontsize",
   "legend_texts", "labelcolor", "axwidth", "linewidth", "center",
   "rotate", "image", "bw", "eng", "neng", "xmin", "ymin" });
constant diagram_args = mkmapping(_diagram_args,_diagram_args);

constant _shuffle_args = 
({ "dimensions", "dimensionsdepth", "ygridspace", "xgridspace",
   "xstart", "xstop", "ystart", "ystop", "colors", "xvalues", "yvalues",
   "axwidth", "xstor", "ystor", "xunit", "yunit", "fg", "bg", "voidsep" });
constant shuffle_args = mkmapping( _shuffle_args, _shuffle_args );

string tag_diagram(string tag, mapping m, string contents,
		   object id, object f, mapping defines)
{
  int l=query("maxstringlength")-1;
  contents=replace(contents, "\r\n", "\n");
  contents=replace(contents, "\r", "\n");

  mapping(string:mixed) res=([]);

  res->datacounter=0;  // Lets see.. What was this for?!
  if(m->help) return register_module()[2];

  if(m->type) res->type = m->type;
  else return syntax("You must specify a type for your table.<br>"
		     "Valid types are: "
		     "<b>sumbars</b>, "
		     "<b>normsumbars</b>, "
		     "<b>linechart</b>, "
		     "<b>barchart</b>, "
		     "<b>piechart</b> and "
		     "<b>graph</b>");

  if(m->background)
    res->background =
      combine_path( dirname(id->not_query), (string)m->background);

  if (m->name)
    {
      res->name=m->name[..l];
      if (m->namesize)
	res->namesize=(int)m->namesize;
      if (m->namecolor)
	res->namecolor=parse_color(m->namecolor);
    }
  if(m->voidseparator)
    res->voidsep=m->voidseparator;
  else
    if(m->voidsep)
      res->voidsep=m->voidsep;

  if (m->tunedbox)
    m->tonedbox=m->tunedbox;
  if(m->tonedbox) {
    array a = m->tonedbox/",";
    if(sizeof(a) != 4)
      return syntax("tonedbox must have a comma separated list of 4 colors.");
    res->tonedbox = map(a, parse_color);
  }
  else if (m->colorbg)
    res->colorbg=parse_color(m->colorbg);
  
  res->drawtype="linear";

  switch(res->type[0..3]) {
   case "pie":
   case "piec":
     res->type = "pie";
     res->subtype="pie";
     res->drawtype = "2D";
     break;
   case "bar":
   case "bars":
   case "barc":
     res->type = "bars";
     res->subtype = "box";
     m_delete( res, "drawtype" );
     break;
   case "line":
     res->type = "bars";
     res->subtype = "line";
     break;
   case "norm":
     res->type = "sumbars";
     res->subtype = "norm";
     break;
   case "grap":
     res->type = "graph";
     res->subtype = "line";
     break;
   case "sumb":
     res->type = "sumbars";
     //res->subtype = "";
     break;
   default:
     return syntax("\""+res->type+"\" is an FIX unknown type of diagram\n");
  }

  if(m["3d"])
  {
    res->drawtype = "3D";
    if( lower_case(m["3d"])!="3d" )
      res->dimensionsdepth = (int)m["3d"];    
    else
      res->dimensionsdepth = 20;
  }

  parse_html(contents, (["xaxis":itag_xaxis,"yaxis":itag_yaxis]),
	     ([ "data":itag_data,
		"xnames":itag_names,
		"ynames":itag_names,
		"xvalues":itag_values,
		"yvalues":itag_values,
		"colors":itag_colors,
		"legend":itag_legendtext ]),
	     res, id );

  if( sizeof(res->data) == 0 )
    return syntax("No data for the diagram");

  res->bg = parse_color(m->bgcolor || defines->bg || "#e0e0e0");
  res->fg = parse_color(m->textcolor || defines->fg || "black");

  if(m->center) res->center = (int)m->center;
  if(m->eng) res->eng=1;
  if(m->neng) res->neng=1;

  res->fontsize       = (int)m->fontsize || 16;
  res->legendfontsize = (int)m->legendfontsize || res->fontsize;
  res->labelsize      = (int)m->labelsize || res->fontsize;

  if(m->labelcolor) res->labelcolor = parse_color(m->labelcolor);
  res->axcolor   = m->axcolor?parse_color(m->axcolor):({0,0,0});
  res->gridcolor = m->gridcolor?parse_color(m->gridcolor):({0,0,0});
  res->linewidth = m->linewidth || "2.2";
  res->axwidth   = m->axwidth || "2.2";

  if(m->rotate) res->rotate = m->rotate;
  if(m->grey) res->bw = 1;

  if(m->width) {
    if((int)m->width > query("maxwidth"))
      m->width  = (string)query("maxwidth");
    if((int)m->width < 100)
      m->width  = "100";
  } else if(!res->background)
    m->width = "350";

  if(m->height) {  
    if((int)m->height > query("maxheight"))
      m->height = (string)query("maxheight");
    if((int)m->height < 100)
      m->height = "100";
  } else if(!res->background)
    m->height = "250";

  if(!res->background)
  {
    if(m->width) res->xsize = (int)m->width;
    else         res->xsize = 400; // A better algo for this is coming.

    if(m->height) res->ysize = (int)m->height;
    else res->ysize = 300; // Dito.
  } else {
    if(m->width) res->xsize = (int)m->width;
    if(m->height) res->ysize = (int)m->height;
  }

  if(m->tone) res->tone = 1;

  if(!res->xnames)
    if(res->xname) res->xnames = ({ res->xname });
      
  if(!res->ynames)
    if(res->yname) res->ynames = ({ res->yname });

  if(m->gridwidth) res->gridwidth = m->gridwidth;
  if(m->vertgrid) res->vertgrid = 1;
  if(m->horgrid) res->horgrid = 1;

  if(m->xgridspace) res->xgridspace = (int)m->xgridspace;
  if(m->ygridspace) res->ygridspace = (int)m->ygridspace;

  m -= diagram_args;

  // Start of res-cleaning
  res->textcolor = res->fg;
  res->bgcolor = res->bg;

  m_delete( res, "voidsep" );

  if (res->xstop)
    if(res->xstart > res->xstop) m_delete( res, "xstart" );

  if (res->ystop)
    if(res->ystart > res->ystop) m_delete( res, "ystart" );

  res->labels = ({ res->xstor, res->ystor, res->xunit, res->yunit });

  if(res->dimensions) res->drawtype = res->dimensions;
  if(res->dimensionsdepth) res["3Ddepth"] = res->dimensionsdepth;
  if(res->ygridspace)  res->yspace = res->ygridspace;
  if(res->xgridspace)  res->xspace = res->xgridspace;
  if(res->orientation) res->orient = res->orientation;
  if((int)res->xstart)  res->xminvalue  = (float)res->xstart;
  if((int)res->xstop)   res->xmaxvalue  = (float)res->xstop;
  if(res->ystart)  res->yminvalue  = (float)res->ystart;
  if(res->ystop)   res->ymaxvalue  = (float)res->ystop;
  if(res->colors)  res->datacolors = res->colors;
  if(res->xvalues) res->values_for_xnames = res->xvalues;
  if(res->yvalues) res->values_for_ynames = res->yvalues;
  if((int)res->linewidth) res->graphlinewidth = (float)res->linewidth;
  else m_delete( res, "linewidth" );
  if((int)res->axwidth) res->linewidth  = (float)res->axwidth;

  res -= shuffle_args;

  m->src = query("location") + quote(res) + ".gif";

  return make_tag("img", m);
}

mapping query_container_callers()
{
  return ([ "diagram" : tag_diagram ]);
}

int|object PPM(string fname, object id)
{
  perror("fname: %O\n",fname);
  if( objectp(fname) )
    perror("fname: %O\n",indices(fname));
  string q;
  q = roxen->try_get_file( fname, id );

  if(!q) perror("Diagram: Unknown image '"+fname+"'\n");

  object g;
  if (sizeof(indices( g=Gz )))
    if (g->inflate)
      catch { q = g->inflate()->inflate(q); };

  if(q)
  { 
    object img_decode;
#if constant(Image.JPEG.decode)
    if (q[0..2]=="GIF")
      if (catch{img_decode=Image.GIF.decode(q);})
	return 1;
      else
	return img_decode;
    else if (search(q[0..13],"JFIF")!=-1)
      if (catch{img_decode=Image.JPEG.decode(q);})
	return 1;
      else
	return img_decode;
    else 
#endif
      if (q[0..0]=="P")
	if (catch{img_decode=Image.PNM.decode(q);})
	  return 1;
	else
	  return img_decode;

#if constant(Image.JPEG.decode)
    perror("Diagram: Unknown image type for '"+fname+"', "
	   "only GIF, jpeg and pnm is supported.\n");
    return 1;
#else
    perror("Diagram: Unknown image type for '"+fname+"', "
	   "only pnm is supported.\n");
    return 1;
#endif
  }
  else
    return 1;
}

mapping http_img_answer( string msg )
{
  return http_string_answer( msg );
}

mapping unquote( string f )
{
  return cache[ f ];
}

mapping find_file(string f, object id)
{
  if (f[sizeof(f)-4..] == ".gif")
    f = f[..sizeof(f)-5];

  if( f=="" )
    return http_img_answer( "This is BG's mountpoint." );

  mapping res = unquote( f );

  if(!res)
    return http_img_answer( "Please reload this page." );

  if(id->prestate->debug)
    return http_string_answer( sprintf("<pre>%O\n", res) );
  
  mapping(string:mixed) diagram_data;

  array back;
  if(res->bgcolor)
    back = res->bgcolor;

  if(res->background)
  {
    m_delete( res, "bgcolor" );
    res->image = PPM(res->background, id);

    /* Image was not found or broken */
    if(res->image == 1) 
    {
      res->image=get_font("avant_garde", 24, 0, 0,"left", 0, 0);
      if (!(res->image))
	throw(({"Missing font or similar error!\n", backtrace() }));
      res->image=res->image->
#if constant(Image.JPEG.decode)
	write("The file was", "not found ",
	      "or was not a","jpeg-, gif- or","pnm-picture.");
#else
	write("The file was","not found ",
	      "or was not a","pnm-picture.");
#endif
    }
  } else if(res->tonedbox) {
    m_delete( res, "bgcolor" );
    res->image = image(res->xsize, res->ysize)->
      tuned_box(0, 0, res->xsize, res->ysize, res->tonedbox);
  }
  else if (res->colorbg)
    {
      m_delete( res, "bgcolor" );
      res->image = image(res->xsize, res->ysize, @res->colorbg);
    }

  diagram_data = res;

  object(Image.image) img;

  if(res->image)
    diagram_data["image"] = res->image;

  switch(res->type) {
   case "pie":
     img = create_pie(diagram_data)["image"];
     break;
   case "bars":
   case "sumbars":
      img = create_bars(diagram_data)["image"];
      break;
   case "graph":
     img = create_graph(diagram_data)["image"];
     break;
  }

  if (res->image)
    return http_string_answer(Image.GIF.encode( img,
	     Image.colortable( 6,6,6,
			       ({0,0,0}),
			       ({255,255,255}), 39)->floyd_steinberg(), 
			       @back), "image/gif");  
  else
    return http_string_answer(Image.GIF.encode(img, @back), "image/gif");      
}
