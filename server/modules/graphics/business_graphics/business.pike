/* This is a roxen module. (c) Idonex AB 1997.
 * 
 * Draws diagrams pleasing to the eye.
 * 
 * Made by Peter Bortas <peter@idonex.se> and Henrik Wallin <hedda@idonex.se>
 * in October 1997
 *
 * BUGS:
 * Sends the data through the URL. This will be changed to a internal
 * reference cache shortly.
 */

constant cvs_version = "$Id: business.pike,v 1.70 1998/02/17 17:12:28 hedda Exp $";
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
       "  <b>legendfontsize</b> Height of legend text in pixels. Uses\n"
       "                 <b>fontsize</b> if not defined.\n"
       "  <b>3D</b>             Render piecharts on top of a cylinder, takes"
       " the\n                 height in pixels of the cylinder as argument.\n"
       /* " tone         Do nasty stuff to the background.\n"
	  " Requires dark background to be visable.\n" */
       "  <b>eng</b>            If present, numbers are shown like 1.2M.\n"
       "  <b>tonedbox</b>       Creates a background shading between the\n"
       "                 colors assigned to each of the four corners.\n"
       "  <b>center</b>         (Only for <b>pie</b>) center=n centers the nth"
       " slice\n"
       "  <b>voidsep</b>        If this separator is given it will be used\n"
       "                 instead of VOID (This option can also\n"
       "                 be given i <b>xnames</b> and so on)\n"
       "  <b>bgcolor</b>        Sets the color for the background\n"
       "  <b>textcolor</b>      Sets the color for all text\n"
       "                 (Can be overrided)\n"
       "  <b>labelcolor</b>     Sets the color for the labels of the axis\n"
       
       "  <b>horgrid</b>        If present a horizontal grid is drawn\n"
       "  <b>vertgrid</b>       If present a vertical grid is drawn\n"

       "\n  You can also use the regular &lt;<b>img</b>&gt; arguments. They"
       " will be passed\n  on to the resulting &lt;<b>img</b>&gt; tag.\n\n"
       "The following internal tags are available:\n"
       "\n&lt;<b>data</b>&gt; (container) Mandatory.\n"
       "Tab and newline separated list of data values for the diagram."
       " Options:\n"
       "  <b>separator</b>      Use the specified string as separator instead"
       " of tab.\n"
       "  <b>lineseparator</b>  Use the specified string as lineseparator"
       " instead of newline.\n"
       "  <b>form</b>           Can be set to either row or column. Default"
       " is row.\n"
       "  <b>parse</b>          Run the content of the tag through the RXML"
       " parser\n"
       "                 before data extraction is done.\n"
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
  defvar( "maxwidth", 800, "Maxwidth", TYPE_INT,
	  "Maximal width of the generated image." );
  defvar( "maxheight", 600, "Maxheight", TYPE_INT,
	  "Maximal height of the generated image." );
  defvar( "maxstringlength", 60, "Maxstringlength", TYPE_INT,
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

  if (sep!=" ")
    contents = contents - " ";

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
	foo += ({ (float)gaz });
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

string quote(string in)
{
  string pack;
//   object g;
  /*
  if( sizeof(indices(g=Gz)) ) {
    pack = MIME.encode_base64(g->deflate()->deflate(in), 1);
  } else {
  */
    pack = MIME.encode_base64(in, 1);
//  }
//  if(search(in,"/")!=-1) return pack;
//  string res="$";	// Illegal in BASE64
//   for(int i=0; i<strlen(in); i++)
//     switch(in[i])
//     {
//      case 'a'..'z':
//      case 'A'..'Z':
//      case '0'..'9':
//      case '.': case ',': case '!':
//       res += in[i..i];
//       break;
//      default:
//       res += sprintf("%%%02x", in[i]);
//     }
//   if( strlen(res) < strlen(pack) ) return res;
  return pack;
}

string tag_diagram(string tag, mapping m, string contents,
		   object id, object f, mapping defines)
{
  contents=replace(contents, "\r\n", "\n");
  contents=replace(contents, "\r", "\n");

  mapping res=([]);
  res->datacounter=0;
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
    res->image = combine_path( dirname(id->not_query), (string)m->background);

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

  /* Piechart */
  if(res->type[0..2] == "pie")
    res->type = "pie";

  /* Barchart */
  else if(res->type[0..2] == "bar")
  {
    res->type = "bars";
    res->subtype = "box";
  }   

  /* Linechart */
  else if(res->type[0..3] == "line")
  {
    res->type = "bars";
    res->subtype = "line";
  }   

  /* Normaliced sumbar */
  else if(res->type[0..3] == "norm")
  {
    res->type = "sumbars";
    res->subtype = "norm";
  }   

  switch(res->type) {
   case "sumbars":
   case "bars":
   case "pie":
   case "graph":
     break;
   default:
     return syntax("\""+res->type+"\" is an unknown type of diagram\n");
  }

  /*
  if(m->subtype)
    res->subtype = (string)m->subtype;
  */

  if(res->type == "pie")
    res->subtype="pie";
  else
    res->drawtype="linear";

  if(res->type == "bars")
    if(res->subtype!="line")
      res->subtype="box";

  if(res->type == "graph")
    res->subtype="line";
  
//   if(res->type == "sumbars")
//     if(res->subtype!="norm"); //FIXME Va faan är detta???

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
    return "<hr noshade><h3>No data for the diagram</h3><hr noshade>";

  res->bg = parse_color(m->bgcolor || defines->bg || "#e0e0e0");
  res->fg = parse_color(m->textcolor || defines->fg || "black");

  //This code is obsolete. It's now placed in xnames
  //But this can not be taken away... (Logview)
  if (!res->orientation)
    if (m->orient && m->orient[0..3] == "vert")
      res->orientation = "vert";
    else res->orientation="hor";
  

  if(m->center) res->center = (int)m->center;

  if (m->eng) res->eng=1;

  if(m["3d"])
  {
    res->drawtype = "3D";
    if( lower_case(m["3d"])!="3d" )
      res->dimensionsdepth = (int)m["3d"];    
    else
      res->dimensionsdepth = 20;    
  }
  else 
    if(res->type=="pie") res->drawtype = "2D";
    else res->drawtype = "linear";
      
  if(m->fontsize) res->fontsize = (int)m->fontsize;
  else res->fontsize=16;

  if(m->legendfontsize) res->legendfontsize = (int)m->legendfontsize;
  else res->legendfontsize = res->fontsize;

  if(m->labelsize) res->labelsize = (int)m->labelsize;
  else res->labelsize = res->fontsize;

  res->labelcolor=m->labelcolor?parse_color(m->labelcolor):0;
  res->axcolor=m->axcolor?parse_color(m->axcolor):({0,0,0});
  res->gridcolor=m->gridcolor?parse_color(m->gridcolor):({0,0,0});
  res->linewidth=m->linewidth || "2.2";
  res->axwidth=m->axwidth || "2.2";

  if(m->rotate) res->rotate = m->rotate;

  if(m->grey) res->bw = 1;

  if(m->width) {
    if((int)m->width > query("maxwidth"))
      m->width  = (string)query("maxwidth");
    if((int)m->width < 100)
      m->width  = "100";
  } else if(!res->image)
    m->width = "350";

  if(m->height) {  
    if((int)m->height > query("maxheight"))
      m->height = (string)query("maxheight");
    if((int)m->height < 100)
      m->height = "100";
  } else if(!res->image)
    m->height = "250";

  if(!res->image)
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

  m_delete( m, "xgridspace" );
  m_delete( m, "ygridspace" );

  m_delete( m, "size" );
  m_delete( m, "type" );
  m_delete( m, "3d" );
  m_delete( m, "templatefontsize" );
  m_delete( m, "fontsize" );
  m_delete( m, "tone" );
  m_delete( m, "background" );

  m->src = query("location") + quote(encode_value(res)) + ".gif";

  return make_tag("img", m);
}

mapping query_container_callers()
{
  return ([ "diagram" : tag_diagram ]);
}

/* Needs some more work */
int|object PPM(string fname, object id)
{
  string q;
  q = roxen->try_get_file( fname, id);
  // q = Stdio.read_file((string)fname);
  //  q = Stdio.read_bytes(fname);
  //  if(!q) q = roxen->try_get_file( dirname(id->not_query)+fname, id);

  if(!q) perror("Diagram: Unknown image '"+fname+"'\n");
  mixed g = Gz;
  if (g->inflate) {
    catch {
      q = g->inflate()->inflate(q);
    };
  }
  if(q)
    { 
      object foo;
#if constant(Image.JPEG.decode)
      if (q[0..2]=="GIF")
	if (catch{foo=Image.GIF.decode(q);})
	  return 1;
	else
	  return foo;
      else if (search(q[0..13],"JFIF")!=-1)
	if (catch{foo=Image.JPEG.decode(q);})
	  return 1;
	else
	  return foo;
      else 
#endif
	if (q[0..0]=="P")
	  if (catch{foo=Image.PNM.decode(q);})
	    return 1;
	  else
	    return foo;

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

mapping find_file(string f, object id)
{
  if (f[sizeof(f)-4..] == ".gif")
    f = f[..sizeof(f)-5];

  mapping res;

  if (sizeof(f)) {
    object g;
    if (f[0] == '$') {	// Illegal in BASE64
      f = f[1..];
//    } else if( sizeof(indices(g=Gz)) ) {
      /* Catch here later */
//      f = g->inflate()->inflate(MIME.decode_base64(f));
    } else if( sizeof(f) ) {
      /* Catch here later */
      f = MIME.decode_base64(f);
    }
    res = decode_value(f);  //FIXME Fix error in f
  } else
    perror( "Diagram: Fatal Error, f: %s\n", f );

  res->labels = ({ res->xstor, res->ystor, res->xunit, res->yunit });

  mapping(string:mixed) diagram_data;
  array back = res->bg;

  if(res->image)
  {
    m_delete( res, "bg" );
    res->image = PPM(res->image, id);

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
    m_delete( res, "bg" );
    res->image = image(res->xsize, res->ysize)->
      tuned_box(0, 0, res->xsize, res->ysize, res->tonedbox);
  }

  if (res->xstop)
    if(res->xstart > res->xstop) m_delete( res, "xstart" );

  if (res->ystop)
    if(res->ystart > res->ystop) m_delete( res, "ystart" );

  diagram_data=(["type":      res->type,
		 "subtype":   res->subtype,
		 "drawtype":  res->dimensions,
		 "3Ddepth":   res->dimensionsdepth,
		 "yspace":     res->ygridspace,
		 "xspace":     res->xgridspace,
		 "xsize":     res->xsize,
		 "ysize":     res->ysize,
		 "textcolor": res->fg,
		 "bgcolor":   res->bg,
		 "orient":    res->orientation,
		 
		 "xminvalue": (float)res->xstart,
		 "xmaxvalue": (float)res->xstop,
		 "yminvalue": (float)res->ystart,
		 "ymaxvalue": (float)res->ystop,

		 "data":      res->data,
		 "datacolors":res->colors,
		 "fontsize":  res->fontsize,

		 "xnames":              res->xnames,
		 "values_for_xnames":   res->xvalues,
		 "ynames":              res->ynames,
		 "values_for_ynames":   res->yvalues,

		 "axcolor":   res->axcolor,
		 "gridcolor":   res->gridcolor,

		 "gridwidth": res->gridwidth,
		 "vertgrid":  res->vertgrid,
		 "horgrid":   res->horgrid,

		 "labels":         res->labels,
		 "labelsize":      res->labelsize,
		 "legendfontsize": res->legendfontsize,
		 "legend_texts":   res->legend_texts,
		 "labelcolor":     res->labelcolor,

		 "linewidth": (float)res->axwidth,
		 "graphlinewidth": (float)res->linewidth,
		 "tone":      res->tone,
		 "center":    res->center,
		 "rotate":    res->rotate,
		 "image":     res->image,

		 "bw":       res->bw,
		 "eng":      res->eng,
		 "xmin":     res->xmin,
		 "ymin":     res->ymin
  ]);

  if(!res->ygridspace)  m_delete( diagram_data, "yspace" );
  if(!res->xgridspace)  m_delete( diagram_data, "xspace" );
  if(!res->xstart)  m_delete( diagram_data, "xminvalue" );
  if(!res->xstop)   m_delete( diagram_data, "xmaxvalue" );
  if(!res->ystart)  m_delete( diagram_data, "yminvalue" );
  if(!res->ystop)   m_delete( diagram_data, "ymaxvalue" );
  if(!res->bg)      m_delete( diagram_data, "bgcolor" );
  if(!res->rotate)  m_delete( diagram_data, "rotate" );
  if(!res->xmin)    m_delete( diagram_data, "xmin" );
  if(!res->ymin)    m_delete( diagram_data, "ymin" );

  object(Image.image) img;

  if(res->image)
    diagram_data["image"] = res->image;

  switch(res->type)
  {
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
