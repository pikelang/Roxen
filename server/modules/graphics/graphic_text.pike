string cvs_version="$Id: graphic_text.pike,v 1.7 1996/12/10 00:15:42 per Exp $";
#include <module.h>
inherit "module";
inherit "roxenlib";


array register_module()
{
  return ({ MODULE_LOCATION | MODULE_PARSER,
	      "Graphics text",
	      "Makes a few new tags:<p>"
	      "<b>&lt;gh1&gt;</b> to <b>&lt;gh6&gt;:</b> Headers<br>\n"
	      "<b>&lt;gh&gt;:</b> Header<br>\n"
	      "<b>&lt;gtext&gt;:</b> Graphical text<br>\n"
	      "<b>&lt;anfang&gt;:</b> Make the first character to a graphical one. Not all that usefull, really.<br>\n"
	      "\n"
	      "Common arguments:\n <pre>"
	      " bg=#rrggbb      Use this background, default taken from the\n"
	      "                 &lt;body&gt; tag, if any\n"
	      " fg=#rrggbb      Use this foreground, default taken from the\n"
	      "                 &lt;body&gt; tag, if any\n"
	      " font=fnt        Use this font. The fonts can be found in the\n"
	      "                 directory specified in the configuration\n"
	      "                 interface.\n"
	      "                 If no font is specified, the one from the\n"
	      "                 define 'font' is used, or if there is no\n"
	      "                 define, the default font will be used.\n"
	      " scale=float     Scale to this font, mostly useful in the &lt;gtext&gt;\n"
	      "                 tag, will not work at all in the &lt;gh[number]&gt;\n"
	      "                 tags.\n"
	      " 2 3 4 5 6       Short for scale=1.0/([number]*0.6)\n"
	      " notrans         Do _not_ make the background color transparent\n"
	      " split           Make each word into a separate gif image\n"
	      " href=url        Link the image to the specified URL\n"
	      "                 The 'link' color of the document will be\n"
	      "                 used as the default foreground of the text\n"
	      " quant=cols      Use this number of colors\n"
	      " magic[=message] Modifier to href, more flashy links\n"
	      "                 Does <b>not</b> work with 'split'\n"
	      " fs              Use floyd-steinberg dithering\n"
	      " border=int,#col Draw an border (width is the first argument\n"
	      "                 in the specified color\n"
	      " spacing=int     Add this amount of spacing around the text\n"
	      " bevel=int       Draw a bevel box (width is the argument)\n"
	      " pressed         Invert the \"direction\" of the bevel box\n"
	      " talign=dir      Justify the text to the left, right, or center\n"
	      " textbox=al,#col Use 'al' as opaque value to draw a box below\n"
	      "                 the text with the specified color.\n"
	      " xpad=X%         Increase padding between characters with X%\n"
	      " xpad=Y%         Increase padding between lines with Y%\n"
	      " shadow=int,dist Draw a drop-shadow (variable distance/intensity)\n"
	      " fuzz=#col       The 'shine' effect used in the 'magic'\n"
	      "                 highlightning\n"
	      " opaque=0-100%   Draw with more or less opaque text (100%\n"
	      "                 is default)\n"
	      " rotate=ang(deg.)Rotate the finished image\n"
	      " background=file Use the specifed file as a background\n"
	      " texture=file    Use the specified file as text texture\n"
	      " turbulence=args args is: frequency,color;freq,col;freq,col\n"
	      "                 Apply a turbulence filter, and use this as the"
	      "                 background.\n"
	      "</pre>\n",
	      0,
	      1,
	      });
}


array (string) list_fonts()
{
  array fnts;
  catch(fnts = get_dir("fonts/32/") - ({".",".."}));
  if(!fnts)
  {
    report_error("Failed to find any fonts in 'fonts/32/'. No default font.\n");
    return ({});
  }
  return fnts;
}

void create()
{
  defvar("location", "/gtext/", "Mountpoint", TYPE_LOCATION,
	 "The URL-prefix for the anfang characters.");

  defvar("cols", 16, "Default number of colors per image", TYPE_INT_LIST,
	 "The default number of colors to use. 16 seems to be enough. "
	 "The size of the image depends on the number of colors",
	 ({ 1,2,3,4,5,6,7,8,10,16,32,64,128,256 }));
  
  defvar("default_size", 32, "Default font size", TYPE_INT_LIST,
	 "The default size for the font. This is used for the 'base' size, "
	 "and can be scaled up or down in the tags.",
	 ({ 16, 32, 64 }));

  defvar("default_font", "urw_itc_avant_garde-demi-r", "Default font",
	 TYPE_STRING_LIST,
	 "The default font. The 'font dir' will be prepended to the path",
	 list_fonts());
}

string query_location() { return query("location"); }

mapping (string:object) fonts = ([]);

object(Font) load_font(string name, string justification, int xs, int ys)
{
  object fnt = Font();

  if(sscanf(name, "%*s/%*s") != 2)
    name=QUERY(default_size)+"/"+name;

  name = "fonts/" + name;

  if(!fnt->load( name ))
  {
    perror("Failed to load the font "+name+", using the default font.\n");
    if(!fnt->load("fonts/"+QUERY(default_size) +"/"+ QUERY(default_font)))
      error("Failed to load the default font\n");
  }

  if(justification=="right") fnt->right();
  if(justification=="center") fnt->center();
  fnt->set_x_spacing((100.0+(float)xs)/100.0);
  fnt->set_y_spacing((100.0+(float)ys)/100.0);
  return fnt;
}

static private mapping (int:mapping(string:mixed)) cached_args = ([ ]);

#define MAX(a,b) ((a)<(b)?(b):(a))

static private mapping (int:array(array(int))) matrixes = ([]);
array (array(int)) make_matrix(int size)
{
  if(matrixes[size]) return matrixes[size];
  array res;
  int i;
  int j;
  res = map_array(allocate(size), lambda(int s, int size){
    return allocate(size); }, size);

  for(i=0; i<size; i++)
    for(j=0; j<size; j++)
      res[i][j] = (int)MAX((float)size/2.0-sqrt((size/2-i)*(size/2-i) + (size/2-j)*(size/2-j)),0);
  return matrixes[size] = res;
}


object (Image) load_image(string f)
{
  object file = File();
  string data;
  object img = Image();
  perror("Loading "+f+"\n");
  if(!file->open(f,"r"))
  {
    perror("Failed to open file ("+f+").\n");
    return 0;
  }
  if(!(data=file->read(0x7fffffff))) return 0;
  if(img->frompnm(data)) return img;
  if(img->fromgif(data)) return img;
  perror("Failed to parse file.\n");
  return 0;
}

object (Image) blur(object (Image) img, int amnt)
{
  for(int i=0; i<amnt; i++) 
    img = img->apply_matrix( make_matrix((int)sqrt(img->ysize()+10)));
  return img;
}

constant white = ({ 255,255,255 });
constant lgrey = ({ 200,200,200 });
constant grey = ({ 128,128,128 });
constant black = ({ 0,0,0 });

constant wwwb = ({ lgrey,lgrey,grey,black });
object (Image) bevel(object (Image) in, int width, int|void invert)
{
  int h=in->ysize();
  int w=in->xsize();

  object corner = Image(width+1,width+1);
  object corner2 = Image(width+1,width+1);
  object pix = Image(1,1);

  for(int i=-1; i<=width; i++) {
    corner->line(i,width-i,i,-1, @white);
    corner2->setpixel(width-i, width-i, @white);
    in->paste_alpha(pix, 185, w - width + i+1, h - width + i+1);
  }

  if(!invert)
  {
    in->paste_alpha(Image(width,h-width*2,@white), 160, 0, width);
    in->paste_alpha(Image(width,h-width*2,@black), 128, in->xsize()-width, width);
    in->paste_alpha(Image(w-width,width,@white), 160, 0, 0);
    in->paste_alpha(Image(w-width,width,@black), 128, width, in->ysize()-width);
  } else  {
    corner=corner->invert();
    corner2=corner2->invert();
    in->paste_alpha(Image(width,h-width*2,@black), 160, 0, width);
    in->paste_alpha(Image(width,h-width*2,@white), 128, in->xsize()-width, width);
    in->paste_alpha(Image(w-width,width,@black), 160, 0, 0);
    in->paste_alpha(Image(w-width,width,@white), 128, width, in->ysize()-width);
  }

  in->paste_mask(corner, corner->color(95,95,95), in->xsize()-width,-1);
  in->paste_mask(corner, corner->invert()->color(128,128,128),
		 in->xsize()-width,-1);
  in->paste_mask(corner, corner->color(95,95,95), -1, in->ysize()-width);
  in->paste_mask(corner, corner->invert()->color(128,128,128),
                 -1, in->ysize()-width);
  in->paste_mask(corner2, corner2->color(70,70,70), -1, -1);

  corner = corner2 = pix = 0;

  return in;
}


object (Image) make_text_image(mapping args, object font, string text)
{
  object (Image) text_alpha=font->write(@(text/"\n"));
  int xoffset=0, yoffset=0;

  if(int op=((((int)args->opaque)*255)/100)) // Transparent text...
    text_alpha=text_alpha->color(op,op,op);

  int txsize=text_alpha->xsize();
  int tysize=text_alpha->ysize(); // Size of the text, in pixels. 

  int xsize=txsize; // Image size, in pixels
  int ysize=tysize;

  if(args->bevel)
  {
    xoffset += (int)args->bevel;
    yoffset += (int)args->bevel;
    xsize += ((int)args->bevel)*2;
    ysize += ((int)args->bevel)*2;
  }

  if(args->spacing)
  {
    xoffset += (int)args->spacing;
    yoffset += (int)args->spacing;
    xsize += ((int)args->spacing)*2;
    ysize += ((int)args->spacing)*2;
  }

  if(args->yspacing)
  {
    yoffset += (int)args->yspacing;
    ysize += ((int)args->yspacing)*2;
  }

  if(args->shadow)
  {
    xsize+=((int)(args->shadow/",")[-1])+2;
    ysize+=((int)(args->shadow/",")[-1])+2;
  }

  if(args->xspacing)
  {
    xoffset += (int)args->xspacing;
    xsize += ((int)args->xspacing)*2;
  }

  if(args->border)
  {
    xoffset += (int)args->border;
    yoffset += (int)args->border;
    xsize += ((int)args->border)*2;
    ysize += ((int)args->border)*2;
  }

  
  array (int) bgcolor = parse_color(args->bg);
  array (int) fgcolor = parse_color(args->fg);

  object background,foreground;


  if(args->texture)    foreground = load_image(args->texture);

  if(args->background)
  {
    background = load_image(args->background);
    xsize = background->xsize();
    ysize = background->ysize();
    switch(lower_case(args->talign))
    {
     case "center":
      xoffset = (xsize/2 - txsize/2);
      break;
     case "right":
      xoffset = (xsize - txsize);
      break;
     case "left":
    }
  } else
    background = Image(xsize, ysize, @bgcolor);

  if(args->turbulence)
  {
    array (float|array(int)) arg=({});
    foreach((args->turbulence/";"),  string s)
    {
      array q= s/",";
      if(sizeof(q)<2) args+=({ ((float)s)||0.2, ({ 255,255,255 }) });
      arg+=({ ((float)q[0])||0.2, parse_color(q[1]) });
    }
    background=background->turbulence(arg);
  }
  

  if(args->bevel)
    background = bevel(background,(int)args->bevel,!!args->pressed);

  if(args->textbox) // Draw a text-box on the background.
  {
    int alpha,border;
    string bg;
    sscanf(args->textbox, "%d,%s", alpha, bg);
    sscanf(bg,"%s,%d", bg,border);
    background->paste_alpha(Image(txsize+border*2,tysize+border*2,
				  @parse_color(bg)),
			    255-(alpha*255/100),xoffset-border,yoffset-border);
  }

  if(args->shadow)
  {
    int sd = ((int)args->shadow+10)*2;
    int sdist = ((int)(args->shadow/",")[-1])+2;
    object ta = text_alpha->copy();
    ta = ta->color(256-sd,256-sd,256-sd);
    background->paste_mask(Image(txsize,tysize),ta,xoffset+sdist, yoffset+sdist);
  }

  if(args->chisel)
    foreground=text_alpha->apply_matrix( ({ ({8,1,0}),
					   ({1,0,-1}),
					   ({0,-1,-8}) }), 128,128,128, 15 )
      ->color(@fgcolor);
  

  if(!foreground)  foreground=Image(txsize, tysize, @fgcolor);

  background->paste_mask(foreground, text_alpha, xoffset, yoffset);

  foreground = text_alpha = 0;


  if(args->scale)
    if((float)args->scale <= 2.0)
      background = background->scale((float)args->scale);

  if(args->rotate)
  {
    string c;
    if(sscanf(args->rotate, "%*d,%s", c))
       background->setcolor(@parse_color(c));
    else
       background->setcolor(@bgcolor);
    background = background->rotate((float)args->rotate);
  }

  if(args->crop) background = background->autocrop();
  
  return background;
}


array(int)|string write_text(int _args, string text, int size,
			     object id)
{
  object img;
  mapping args = cached_args[_args];

  if(!args) return 0;

  text = replace(text, ({ "&lt;", "&gt;", "&amp;" }), ({ "<", ">", "&" }));

  // Check the cache first..
  if(!id || (!id->pragma["no-cache"]))
    if(mixed data = cache_lookup("font:"+_args, text))
    {
      if(size) return data[1];
      return data[0];
    }

  //  Nothing found in the cache. Generate a new image.

  data = cache_lookup("fonts:fonts",
		      args->font+args->justift+":"+
		      args->xpad+":"+args->ypad);
  if(!data)
  { 
    data = load_font(args->font, lower_case(args->talign||""),(int)args->xpad,(int)args->ypad);
    cache_set("fonts:fonts", args->font, data);
  }

  // Fonts and such are now initialized.

  img = make_text_image(args,data,text);

  // Now we have the image in 'img', or nothing.

  if(!img) return 0;
  
  // place in cache.
  int q = (int)args->quant || (args->background?256:16);
  img = img->map_closest(img->select_colors(q-1)+({parse_color(args->bg)}));
  if(args->fs)
    data=({ img->togif_fs(@(args->notrans?({}):parse_color(args->bg))),
	    ({img->xsize(),img->ysize()})});
  else
    data=({ img->togif(@(args->notrans?({}):parse_color(args->bg))),
	    ({img->xsize(),img->ysize()})});
  img=0;

  cache_set("font:"+_args, text, data);
  if(size) return data[1];
  return data[0];
}

  
mapping find_file(string f, object rid)
{
  string id;
  sscanf(f,"%d/%s", id, f);
  return http_string_answer(write_text((int)id,f,0,rid), "image/gif");
}

string quote(string in)
{
  string res="";
  for(int i=0; i<strlen(in); i++)
    switch(in[i])
    {
     case 'a'..'z':
     case 'A'..'Z':
     case '0'..'9':
     case '.':
     case ',':
     case '!':
      res += in[i..i];
      break;
     default:
      res += sprintf("%%%02x", in[i]);
    }
  return res;
}

int number=time(1);

int find_or_insert(mapping find)
{
  array a = indices(cached_args);
  array b = values(cached_args);
  int i;
  for(i=0; i<sizeof(a); i++)
    if(equal(find, b[i])) return a[i];
  cached_args[number]=find;
  return number++;
}


string magic_javascript_header(object id)
{
  if(!id->supports->javascript || !id->supports->images) return "";
  return
    ("<script>\n"
     "<!-- \n"
     "version = 1;\n"
     "browserName = navigator.appName;\n"
     "browserVer = parseInt(navigator.appVersion); \n"
     "if(browserName == \"Netscape\" && (browserVer == 3 || browserVer == 4 || browserVer == 5 || browserVer == 6)) \n"
     "  version = \"3\";\n"
     "else\n"
     " version= \"1\";\n"
     "\n"
     "function stat(txt)\n"
     "{\n"
     "  top.window.status = txt;\n"
     "}\n"
     "\n"
     "function img_act(imgName, txt)\n"
     "{\n"
     "  if (version == \"3\") \n"
     "  {\n"
     "    imgOn = eval(imgName + \"2.src\");\n"
     "    document [imgName].src = imgOn;\n"
     "  }\n"
     "  setTimeout(\"stat('\"+txt+\"')\", 100);\n"
     "}\n"
     "\n"
     "function img_inact(imgName)\n"
     "{\n"
     "  if (version == \"3\") \n"
     "  {\n"
     "    imgOff = eval(imgName + \".src\");\n"
     "    document [imgName].src = imgOff;\n"
     "  }\n"
     "}\n"
     "// -->\n"
     "</script>\n");
}


string magic_image(string url, int xs, int ys, string sn,
		   string image_1, string image_2, string alt,
		   string mess,object id,string input)
{
  if(!id->supports->images) return alt;
  if(!id->supports->javascript)
    return (!input)?
      ("<a href=\""+url+"\"><img src="+image_1+" name="+
       sn+" border=0 alt=\""+alt+"\" ></a>\n"):
    ("<input type=image src="+image_1+" name="+input+">");

  return
    ("<script>\n"
     "<!-- \n"
     "if(version == \"3\")\n"
     "{\n"
     "  "+sn+" = new Image("+xs+", "+ys+");\n"
     "  "+sn+".src = \""+image_1+"\";\n"
     "  "+sn+"2 = new Image("+xs+", "+ys+");\n"
     "  "+sn+"2.src = \""+image_2+"\";\n"
     "}\n"
     "// -->\n"
     "</script>\n"+
     ("<a href=\""+url+"\" "+(input?"onClick='document.forms[0].submit();' ":"")
      +"onMouseover=\"img_act('"+sn+"','"
      +(mess||url)+"');return true;\"\n"
      "\n"
      "onMouseout=\"img_inact('"+sn+"')\"><img \n"
      " src="+image_1+" name="+sn+" border=0 alt=\""+alt+"\" ></a>\n"));
}

string tag_graphicstext(string t, mapping arg, string contents,
			object id, object foo, mapping defines)
{
  if(!strlen(contents)) return ""; // There is no need to make this image.

  string pre, post, defalign, gt, rest, magic;
  int i, split;

  
 // No images here, let's generate an alternative..
  if(!id->supports->images || id->prestate->noimages)
  {
    if(!arg->split) contents=replace(contents,"\n", "\n<br>\n");
    if(arg->submit) return "<input type=submit value=\""+contents+"\">";
    switch(t)
    {
     case "gtext":
     case "anfang":
      if(arg->href)
	return "<a href=\""+arg->href+"\">"+contents+"</a>";
      return contents;
     default:
      if(sscanf(t, "%s%d", t, i)==2)
	rest="<h"+i+">"+contents+"</h"+i+">";
      else
	rest="<h1>"+contents+"</h1>";
      if(arg->href)
	return "<a href=\""+arg->href+"\">"+rest+"</a>";
      return rest;
      
    }
  }

  if(arg->magic)
  {
    magic=arg->magic;
    m_delete(arg,"magic");
  }

  int input;
  if(arg->submit)
  {
    input=1;
    m_delete(arg,"submit");
  }
  
  string lp, url;
  if(arg->href)
  {
    url = arg->href;
    lp = "<a href=\""+arg->href+"\">";
    if(!arg->fg) arg->fg=defines->link||"#0000ff";
    m_delete(arg,"href");
  }

  // Modify the 'arg' mapping...
  if(defines->fg && !arg->fg) arg->fg=defines->fg;
  if(defines->bg && !arg->bg) arg->bg=defines->bg;
  if(defines->font && !arg->font) arg->font=defines->font||QUERY(default_font);
  if(!arg->font) arg->font = QUERY(default_font);

  
  if(arg->split)
  {
    split=1;
    m_delete(arg,"split");
  }

  // Support for <gh 2> like things.
  for(i=2; i<10; i++) 
    if(arg[(string)i])
    {
      arg->scale = 1.0 / ((float)i*0.6);
      m_delete(arg, (string)i);
    }

  // Support for <gh1> like things.
  if(sscanf(t, "%s%d", t, i)==2)
    if(i > 1) arg->scale = 1.0 / ((float)i*0.6);


  string moreargs="";
  if(arg->hspace)
  {
    moreargs += "hspace="+arg->hspace+" ";
    m_delete(arg,"hspace");
  }

  if(arg->vspace)
  {
    moreargs += "vspace="+arg->vspace+" ";
    m_delete(arg,"vspace");
  }
  
  // Now the 'args' mapping is modified enough..
  int num = find_or_insert( arg );

  gt=contents;
  rest="";

  if(split)
  {
    string word;
    array res = ({});
    string pre = query_location()+num+"/";

    if(lp) res+=({ lp });
    
    gt=replace(gt, "\n", " ");
    
    foreach(gt/" "-({""}), word)
    {
      array size = write_text(num,word,1,0);
      res += ({ "<img border=0 alt=\""+replace(word,"\"","'")
		  +"\" src=\'"+pre+quote(word)+"\' width="+
		  size[0]+" height="+size[1]+" "+moreargs+">\n"
		  });
    }
    if(lp) res+=({ "</a>" });
    return res*"";
  }
  
  switch(t)
  {
   case "gh1": case "gh2": case "gh3": case "gh4":
   case "gh5": case "gh6": case "gh7":
   case "gh": pre="<p>"; post="<br>"; defalign="top"; break;
   case "gtext":
    pre="";  post=""; defalign="bottom";
    break;
   case "anfang":
    gt=contents[0..0]; rest=contents[1..];
    pre="<br clear=left>"; post=""; defalign="left";
    break;
  }

  array size = write_text(num,gt,1,0);

  if(magic)
  {
    string res = "";
    arg = mkmapping(indices(arg), values(arg));
    arg->fuzz = arg->fg;
    arg->fg = defines->alink||"#ff0000";
    if(arg->bevel) arg->pressed=1;
    int num2 = find_or_insert(arg);
    array size = write_text(num2,gt,1,0);
    if(!defines->magic_java) res = magic_javascript_header(id);
    defines->magic_java="yes";
    return res + magic_image(url||"", size[0], size[1],
			     "i"+(num+""+hash(gt,0x7fffffff))+"g",
			     query_location()+num+"/"+quote(gt),
			     query_location()+num2+"/"+quote(gt),
			     replace(gt, "\"","'"),(magic=="magic"?0:magic),
			     id,input?(arg->name||"submit"):0);
  }
  if(input && id->supports->images)
    return (pre+"<input type=image name=\""+arg->name+"\" border=0 alt=\""+
	    replace(gt,"\"","'")+"\" src="+query_location()+num+"/"+quote(gt)
	    +" align="+(arg->align?arg->align:defalign)+
	    " width="+size[0]+" height="+size[1]+">"+rest+post);
  return (pre+(lp?lp:"")+
	  "<img border=0  alt=\""+replace(gt,"\"","'")+"\" src="+
	  query_location()+num+"/"+quote(gt)
	  +" align="+(arg->align?arg->align:defalign)+
	  " width="+size[0]+" height="+size[1]+">"+rest+(lp?"</a>":"")+post);
}

string tag_body(string t, mapping args, object id, object file,
		mapping defines)
{
  int bg, text, link, alink, vlink, background;
//if(args->clink)     { defines->clink = args->clink;   
  if(args->bgcolor)   { defines->bg    = args->bgcolor;  bg=1;   }
  if(args->text)      { defines->fg    = args->text;     text=1; }
  if(args->link)      { defines->link  = args->link;     link=1; }
  if(args->background){ background=1; }
  if(args->alink)     { defines->alink = args->alink;    alink=1;}
  if(args->vlink)     { defines->vlink = args->vlink;    vlink=1;}
  if(bg+text+link+alink+vlink+background+bg&&
     (bg+text+link+alink+vlink+background+bg)<5)
  {
    if(!bg)   args->bgcolor=args->text  || "black";
    if(!text) args->text=args->bgcolor  || "white";
    if(!link) args->link=args->bgcolor  || "yellow";
    if(!vlink)args->vlink=args->bgcolor || "pink";
    if(!alink)args->alink=args->bgcolor || "red";
    return ("<body "+(background?"background="+args->background+" ":"")+
	    "bgcolor="+args->bgcolor+" text="+args->text+" link="+
	    args->link+" vlink="+args->vlink+" alink="+args->alink+">");
  }
}


  mapping query_tag_callers()
{
  return (["body":tag_body]);
}


mapping query_container_callers()
{
  return ([ "anfang":tag_graphicstext,
	    "gh":tag_graphicstext,
	    "gh1":tag_graphicstext,
	    "gh2":tag_graphicstext,
	    "gh3":tag_graphicstext,
	    "gh4":tag_graphicstext,
	    "gh5":tag_graphicstext,
	    "gh6":tag_graphicstext,
	    "gtext":tag_graphicstext, ]);
}




