// This is a roxen module. Copyright © 1996 - 2000, Roxen IS.
//

constant cvs_version="$Id: graphic_text.pike,v 1.212 2000/03/16 00:32:53 nilsson Exp $";

#include <module.h>
inherit "module";
inherit "roxenlib";


// ------------------- Module registration ---------------------

constant module_type   = MODULE_PARSER;
constant module_name   = "Graphics text";
constant module_doc    = "Generates graphical texts.";
constant thread_safe   = 1;

void create()
{
  defvar("colorparse", 1, "Parse tags for document colors", TYPE_FLAG,
	 "If set, parse the specified tags for document colors.");

  defvar("deflen", 300, "Default maximum text-length", TYPE_INT|VAR_MORE,
	 "The module will, per default, not try to render texts "
	 "longer than this. This is a safeguard for things like "
	 "&lt;gh1&gt;&lt;/gh&gt;, which would otherwise parse the"
	 " whole document. This can be overrided with maxlen=... in the "
	 "tag.");

  defvar("ext", 0, "Append .fmt (gif, jpeg etc) to all images",
	 TYPE_FLAG|VAR_MORE,
	 "Append .gif, .png, .gif etc to all images made by gtext. "
         "Normally this will only waste bandwidth");
}

TAGDOCUMENTATION;
#ifdef manual
constant gtextargs=#"
<attr name=afont>

</attr>

<attr name=alpha value=path>
 Use the specified image as an alpha channel, together with the
 background attribute.
</attr>

<attr name=background value=path>
 Specifies the image to use as background.
</attr>

<attr name=bevel value=width>
 Draws a bevel box.
</attr>

<attr name=bgcolor value=color>
 Sets the background color. Normally taken from the normal HTML tags
 in your document (Currently: body, table, tr or td).

 <p>If you set the background color, it is probably best to add the
 notrans attribute as well.</p>
 <ex type=vert>
<gtext notrans=\"\" bgcolor=\"pink\">Pink</gtext>
<gtext notrans=\"\" bgcolor=\"#ff0000\">Red</gtext>
<gtext notrans=\"\" bgcolor=\"%50,0,100,0\">%50,0,100,0</gtext>
 </ex>
</attr>

<attr name=bgturbulence value=frequency,color;frequency,color...>
 Apply a turbulence effect.
</attr>

<attr name=black>
 Use a black, or heavy, version of the font, if available.
</attr>

<attr name=bold>
 Use a bold version of the font, if available.
</attr>

<attr name=bshadow value=distance>
 Draw a blured black drop-shadow behind the text. Using 0 as distance
 does not currently place the shadow directly below the text. Using
 negative values for distance is possible, but you might have to add
 'spacing'.
 <ex type=vert>
<gtext scale=\"0.8\" fgcolor=\"#FF6600\" quant=\"200\" bshadow=\"1\">&lt;gtext bshadow=1&gt;</gtext><br />
<gtext scale=\"0.8\" fgcolor=\"#FF6600\" quant=\"200\" bshadow=\"2\">&lt;gtext bshadow=2&gt;</gtext>
 </ex>
</attr>

<attr name=chisel>
 Make the text look like it has been cut into the background.
 <ex type=vert>
<gtext bold=\"\" quant=\"200\" ypad=\"-40%\" xpad=\"-20%\" chisel=\"\" talign=\"center\"
opaque=\"70\" fgcolor=\"gold\" bevel=\"2\" background=\"tiles.jpg\"> Chisel
opaque=70</gtext>
 </ex>
</attr>

<attr name=crop>
 Remove all white-space around the image
</attr>

<attr name=encoding>

</attr>

<attr name=fadein value=blur,steps,delay,initialdelay>
 Generates an animated GIF file of a fade-in effect.
</attr>

<attr name=fgcolor value=color>
 Sets the text color.

 <ex type=vert>
<gtext fgcolor=\"#0080FF\">#0080FF</gtext>
 </ex>
</attr>

<attr name=font>

</attr>

<attr name=font_size>

</attr>

<attr name=format>

</attr>

<attr name=fs>
 Apply floyd-steinberg dithering to the resulting image. Most of the
 time it is much better to increase the number of colors, instead of
 dithering the image, but sometimes when using very complex background
 images dithering is O.K.
</attr>

<attr name=ghost value=dist,blur,color>
 Apply a ghost effect. Cannot be used together with shadow or magic
 coloring.
 <ex type=vert>
<gtext spacing=\"2\" crop=\"\" quant=\"200\" ghost=\"1,1,red\">ghost=1,1,red</gtext>
<gtext spacing=\"2\" crop=\"\" quant=\"200\" ghost=\"1,3,blue\">ghost=1,3,blue</gtext>
<gtext spacing=\"2\" crop=\"\" bshadow=\"1\" opaque=\"90\" ghost=\"-1,1,yellow\">ghost=-1,1,yellow opaque=90 bshadow=1</gtext>
 </ex>
</attr>

<attr name=glow value=color>
 Apply a 'glow' filter to the image. Quite a CPU eater. Looks much
 better on a dark background, where a real 'glow' effect can be
 achieved.
 <ex type=vert>
<gtext quant=\"200\" glow=\"red\">&lt;gtext glow=red&gt;</gtext>
 </ex>
</attr>

<attr name=italic>
 Use an italic version of the font, if available.
</attr>

<attr name=light>
 Use a light version of the font, if available.
</attr>

<attr name=maxlen value=number>
 Sets the maximum length of the text that will be rendered into an
 image, by default 300.
</attr>

<attr name=mirrortile>
 Tiles the background and foreground images around x-axis and y-axis
 for odd frames, creating seamless textures.
</attr>

<attr name=move value=x,y>
 Moves the text relative to the upper left corner of the background
 image. This will not change the size of the image.
</attr>

<attr name=narrow>

</attr>

<attr name=nfont value=fontname>
 Select a font using somewhat more memonic font-names. You can get a
 font-list by accessing the configuration interface.

 <p>There are several modifiers available: bold, italic, black and light.
 If the requested version of the font is available, it will be used to
 render the text, otherwise the closest match will be used.</p>

 <ex type=vert>
<gtext nfont=\"futura\" light=\"\"            >Light</gtext>
<gtext nfont=\"futura\" light=\"\" italic=\"\">Italic</gtext>
<gtext nfont=\"futura\"                       >Normal</gtext>
<gtext nfont=\"futura\" italic=\"\"           >Italic</gtext>
<gtext nfont=\"futura\" bold=\"\"             >Bold</gtext>
<gtext nfont=\"futura\" bold=\"\"  italic=\"\">Italic</gtext>
<gtext nfont=\"futura\" black=\"\"            >Black</gtext>
<gtext nfont=\"futura\" black=\"\" italic=\"\">Italic</gtext>
 </ex>
</attr>

<attr name=notrans>
 Do not make the background transparent. Useful when making 'boxes' of
 color around the text.
 <ex type=vert>
<gtext bgcolor=\"red\">&lt;gtext bgcolor=red&gt;</gtext>
<gtext bgcolor=\"red\" notrans=\"\">&lt;gtext bgcolor=red notrans&gt;</gtext>
 </ex>
</attr>

<attr name=nowhitespace>

</attr>

<attr name=opaque value=percentage>
 Generate text with this amount of opaqueness. 100% is default.
 <ex>
<gtext fgcolor=\"blue\" opaque=\"50\">Opaque</gtext>
 </ex>
</attr>

<attr name=outline>

</attr>

<attr name=pressed>
 Inverts the direction of the bevel box, to make it look like a button
 that is pressed down.
</attr>

<attr name=quant value=number>
 Use this number of colors in the generated image. For GIF images,
 fewer colors implies smaller images but also aliasing effects. It is
 advisable to use powers of 2 to optimize the palette allocation.
</attr>

<attr name=rescale>
 Rescale the background to fill the whole image.
</attr>

<attr name=rotate value=angle>
 Rotates the image this number of degrees counter-clockwise.
</attr>

<attr name=scale value=number>
 Sets the scale of the image. Larger than 1.0 is enlargement.
 <ex type=vert>
<gtext scale=\"1.0\">&lt;gtext scale=1.0&gt;</gtext>
<gtext scale=\"0.5\">&lt;gtext scale=0.5&gt;</gtext>
 </ex>
</attr>

<attr name=scolor value=color>
 Use this color for the shadow. Used with the shadow attribute.
</attr>

<attr name=scroll value=width,steps,delay>
 Generate an animated GIF image of the text scrolling.
</attr>

<attr name=shadow value=intensity,distance>
 Draw a drop-shadow with the specified intensity and distance. The
 intensity is specified as a percentage.
</attr>

<attr name=size value=width,height>
 Set the size of the image.
</attr>

<attr name=spacing value=number>
 Add space around the text.
</attr>

<attr name=talign value=left,right,center>
 Adjust the alignment of the text.
</attr>

<attr name=textbelow value=color>
 Place the text in a colored box.
</attr>

<attr name=textbox value=opaque,color>
 Draw a box with an opaque value below the text of the specified color.
</attr>

<attr name=texture value=path>
 Uses the specified images as a field texture.
</attr>

<attr name=tile>
 Tiles the background and foreground images if they are smaller than
 the actual image.
</attr>

<attr name=verbatim>
 Allows the gtext parser to not be typographically correct.
</attr>

<attr name=xpad value=percentage>
 Increases padding between characters.
</attr>

<attr name=xsize value=number>
 Sets the width.
</attr>

<attr name=xspacing value=number>
 Sets the horizontal spacing.
</attr>

<attr name=ypad>

</attr>

<attr name=ysize value=number>
 Sets the height.
</attr>

<attr name=yspacing value=number>
 Sets the vertical spacing.
</attr>";
constant tagdoc=([
"anfang":#"<desc cont></desc>"+gtextargs,

"gh":#"<desc cont></desc>"+gtextargs,

"gh1":#"<desc cont></desc>"+gtextargs,

"gh2":#"<desc cont></desc>"+gtextargs,

"gh3":#"<desc cont></desc>"+gtextargs,

"gh4":#"<desc cont></desc>"+gtextargs,

"gh5":#"<desc cont></desc>"+gtextargs,

"gh6":#"<desc cont></desc>"+gtextargs,

"gtext":#"<desc cont>
 Renders a GIF image of the contents.

 <p>Note: If the background and text colors are not set in the
 <tag>body</tag>> tag of the page, the bg and fg attributes must be
 set, otherwise the <tag>gtext</tag>> tag will only render a \"Please
 reload this page\" message.</p>
</desc>

<attr name=alt value=string>
 Sets the alt attribute of the generated <tag>img</tag> tag. By
 default the alt attribute will be set to the contents of the
 <tag>gtext</tag> tag.
 <ex type=vert>
<gtext fgcolor=\"blue\" alt=\"Hello!\">Welcome!</gtext>
 </ex>
</attr>

<attr name=border value=width,color>
 Draws a border around the text of the specified width and color.
 <ex type=vert>
<gtext fgcolor=\"blue\" border=\"2,red\">Red border</gtext>
 </ex>
</attr>

<attr name=href value=URL>
 Link the image to the specified URL. The link color of the document
 will be used as the default foreground rather than the foreground
 color.
</attr>

<attr name=magic value=message>
 Used together with the href attribute to generate a JavaScript that
 will highlight the image when the mouse is moved over it. The message
 is shown in the browser's status bar.
 <ex type=vert>
<gtext href=\"http://www.roxen.com\" magic=\"Roxen\">www.roxen.com</gtext>
 </ex>
</attr>

<attr name=magic-attribute value=value> Same as for any
 <tag>gtext</tag> attribute, except for the highlighted image.
 <ex type=vert>
<gtext fgcolor=\"blue\" magic-fgcolor=\"darkgreen\" magic=\"\">Magic_attribute</gtext>
 </ex>
</attr>

<attr name=noxml>

</attr>

<attr name=split>
 <gtext scale=0.4 split>Make each word into a separate gif image.
 Useful if you are writing a large text, and word wrap at the edges of
 the display is desired. This text is an example (try resisizing your
 browser window, the images should move just like normal text
 would)</gtext>

 <p>This will allow the browser to word-wrap the text, but will disable certain attributes like magic.</p>

 <ex type=vert>
<gtext scale=\"0.4\" split=\"\">Make each word..</gtext>
 </ex>
</attr>

<attr name=submit>
 Creates a submit-button for forms. Does not work together with split
 or magic arguments.
</attr>"+gtextargs,

"gtext-id":#"<desc tag></desc>
<attr name=href value=URL>
 Link the image to the specified URL. The link color of the document
 will be used as the default foreground rather than the foreground
 color.
</attr>

<attr name=short>

</attr>"+gtextargs,

"gtext-url":#"<desc cont></desc>

<attr name=href value=URL>
 Link the image to the specified URL. The link color of the document
 will be used as the default foreground rather than the foreground
 color.
</attr>

<attr name=short>

</attr>"+gtextargs,]);
#endif


// -------------------- Image cache functions --------------------

roxen.ImageCache image_cache;

string status() {
  array s=image_cache->status();
  return sprintf("<b>Images in cache:</b> %d images<br>\n<b>Cache size:</b> %s",
		 s[0]/2, sizetostring(s[1]));
}

void start(int num, Configuration conf)
{
  image_cache = roxen.ImageCache( "gtext", draw_callback );
  roxen.dump( "etc/modules/GText.pmod" );
  if(query("colorparse")) module_dependencies(conf, ({ "wiretap" }) );
}

constant nbsp = iso88591["&nbsp;"];
constant replace_from = indices( iso88591 )+ ({"&ss;","&lt;","&gt;","&amp;",});
constant replace_to   = values( iso88591 ) + ({ nbsp, "<", ">", "&", });

#define simplify_text( from ) replace(from,replace_from,replace_to)

mixed draw_callback(mapping args, string text, RequestID id)
{
  array data;
  Image.Font font;
  Image.Image img;

  if( objectp( text ) )
  {
    if( !args->text )
      error("Failed miserably to find a text to draw. That's not"
	    " good.\n");
    id = (object)text;
    text = args->text;
  }

  if(!args->verbatim) // typographically correct...
  {
    text = replace(text, nbsp, " ");
    text = simplify_text( text );
    string res="",nspace="",cspace="";
    foreach(text/"\n", string line)
    {
      cspace="";
      nspace="";
      foreach(line/" ", string word)
      {
        string nonum;
        if(strlen(word) &&
           (nonum = replace(word,
                            ({"1","2","3","4","5","6","7","8","9","0","."}),
                            ({"","","","","","","","","","",""}))) == "") {
          cspace=nbsp+nbsp;
          if((strlen(word)-strlen(nonum)<strlen(word)/2) &&
             (upper_case(word) == word))
            word=((word/"")*nbsp);
        }
        else if(cspace!="")
          cspace=" ";

        res+=(nspace==cspace?nspace:" ")+word;

        if(cspace!="")
          nspace=cspace;
        else
          nspace=" ";
      }
      res+="\n";
    }
    text=replace(res[..strlen(res)-2], ({"!","?",": "}),({ nbsp+"!",nbsp+"?",nbsp+": "}));
    text=replace(replace(replace(text,({". ",". "+nbsp}),
                                 ({"\000","\001"})),".","."+nbsp+nbsp),
                 ({"\000","\001"}),({". ","."+nbsp}));
  }

  if( args->afont )
    font = resolve_font((args->afont||args->font)+" "+(args->font_size||32));
  else
  {
    int bold=0, italic=0;
    if(args->nfont) args->font = args->nfont;
    if(args->bold) bold=1;
    if(args->light) bold=-1;
    if(args->black) bold=2;
    if(args->italic) italic=1;
    font = get_font(args->font||"default",
                    (int)(args->font_size||args["font-size"])||32,
                    bold,
                    italic,
                    lower_case(args->talign||"left"),
                    (float)args->xpad,
                    (float)args->ypad);
  }
  if(!font)
    font = resolve_font(0);

  if (!font)
    error("gtext: No font (tried "+
          (args->afont||args->font||args->nfont)+ ")!\n");

  // Fonts and such are now initialized.
  [img, Image.Image alpha] = GText.make_text_image(args, font, text, id);

  // Now we have the image in 'img'.

  if( !args->scroll && !args->fadein )
  {
    if(!args->notrans)
    {
      return ([ "img":img, "alpha":alpha ]);
    }
    return img;
  }

  if(args->fadein)
  {
    int amount=2, steps=10, delay=10, initialdelay=0, ox;
    string res = img->gif_begin();
    sscanf(args->fadein,"%d,%d,%d,%d", amount, steps, delay, initialdelay);
    if(initialdelay)
    {
      Image.Image foo=Image.Image(img->xsize(),img->ysize(),@parse_color(args->bgcolor));
      res += foo->gif_add(0,0,initialdelay);
    }
    for(int i = 0; i<(steps-1); i++)
    {
      Image.Image foo=img->clone();
      foo = foo->apply_matrix(GText.make_matrix(( (int)((steps-i)*amount))));
      res += foo->gif_add(0,0,delay);
    }
    res += img->gif_add(0,0,delay);
    res += img->gif_end();
    data = ({ res, ({ img->xsize(), img->ysize() }) });
  }
  else
  {
    int len=100, steps=30, delay=5, ox;
    string res = img->gif_begin() + img->gif_netscape_loop();
    sscanf(args->scroll, "%d,%d,%d", len, steps, delay);
    img=img->copy(0,0,(ox=img->xsize())+len-1,img->ysize()-1);
    img->paste(img, ox, 0);
    for(int i = 0; i<steps; i++)
    {
      int xp = i*ox/steps;
      res += img->copy(xp, 0, xp+len, img->ysize(),
                       @parse_color(args->bgcolor))->gif_add(0,0,delay);
    }
    res += img->gif_end();
    data = ({ res, ({ len, img->ysize() }) });
  }

  return
  ([
    "data":data[0],
    "meta":
    ([
      "xsize":data[1][0],
      "ysize":data[1][1],
      "type":(args->format?id->conf->type_from_filename("x."+args->format):"image/gif"),
    ])
  ]);
}

mapping find_internal(string f, RequestID id)
{
  if( strlen(f)>4 && query("ext") && f[-4]=='.') // Remove .ext
    f = f[..strlen(f)-5];
  if( strlen(f) && f[0]=='$' )
  {
    array id_text = f/"/";
    if( sizeof(id_text)==2 )
    {   // It's a gtext-id
      string second_key = roxen->argcache->store( (["":id_text[1]]) );
      return image_cache->http_file_answer( id_text[0][1..] +"$"+ second_key, id );
    }
  }
  return image_cache->http_file_answer( f, id );
}


// -------------- helpfunctions to gtext tags and containers -----------------

constant filearg=({"background","texture","alpha","magic-texture","magic-background","magic-alpha"});
constant textarg=({"afont",
		   "alpha",
		   "bevel",
		   "bgcolor",
		   "bgturbulence",
		   "black",
		   "bold",
		   "bshadow",
		   "chisel",
		   "crop",
		   "encoding",
		   "fadein",
		   "fgcolor",
		   "fs",
		   "font",
		   "font_size",
                   "format",
		   "ghost",
		   "glow",
		   "italic",
		   "light",
		   "mirrortile",
		   "move",
		   "narrow",
		   "nfont",
		   "notrans",
		   "opaque",
		   "outline",
		   "pressed",
		   "quant",
		   "rescale",
		   "rotate",
		   "scale",
		   "scolor",
		   "scroll",
		   "shadow",
		   "size",
		   "spacing",
		   "talign",
		   "tile",
		   "textbox",
		   "textbelow",
		   "textscale",
		   "verbatim",
		   "xpad",
		   "xsize",
		   "xspacing",
		   "ypad",
		   "ysize",
		   "yspacing"
});

constant theme=({"fgcolor","bgcolor","font"});

constant hreffilter=(["split":1,"magic":1,"noxml":1,"alt":1]);

mapping mk_gtext_arg(mapping arg, RequestID id) {

  mapping p=([]); //Picture rendering arguments.

  m_delete(arg,"src");
  m_delete(arg,"width");
  m_delete(arg,"height");

  foreach(filearg, string tmp)
    if(arg[tmp]) {
      p[tmp]=fix_relative(arg[tmp],id);
      m_delete(arg,tmp);
    }

  if(arg->border && search(arg->border,",")) {
    p->border=arg->border;
    m_delete(arg,"border");
  }

  foreach(textarg, string tmp)
    if(arg[tmp]) {
      p[tmp]=arg[tmp],id;
      m_delete(arg,tmp);
    }

  foreach(theme, string tmp)
    if( (id->misc->defines[tmp] || id->misc->defines["theme_"+tmp]) && !p[tmp])
      p[tmp]=id->misc->defines["theme_"+tmp] || id->misc->defines[tmp];

  if(id->misc->defines->nfont && !p->nfont) p->nfont=id->misc->gtext_nfont;
  if(id->misc->defines->afont && !p->afont) p->afont=id->misc->gtext_afont;
  if(id->misc->defines->bold && !p->bold) p->bold=id->misc->gtext_bold;
  if(id->misc->defines->italic && !p->italic) p->italic=id->misc->gtext_italic;
  if(id->misc->defines->black && !p->black) p->black=id->misc->gtext_black;
  if(id->misc->defines->narrow && !p->narrow) p->narrow=id->misc->gtext_narrow;

  return p;
}

string fix_text(string c, mapping m, RequestID id) {

  if(m->nowhitespace)
  {
    c=String.trim_all_whites(c);
    m_delete(m, "nowhitespace");
  }

  m_delete(m, "noparse");
  m_delete(m, "preparse");

  c=replace(c, replace_entities+({"   ","  ", "\n\n\n", "\n\n", "\r"}),
	    replace_values+({" ", " ", "\n", "\n", ""}));

  if(m->maxlen) {
    c = c[..(((int)m->maxlen||QUERY(deflen))-1)];
    m_delete(m, "maxlen");
  }

  return c;
}


// ----------------- gtext tags and containers -------------------

string simpletag_gtext_url(string t, mapping arg, string c, RequestID id) {
  c=fix_text(c,arg,id);
  mapping p=mk_gtext_arg(arg,id);
  if(arg->href && !p->fgcolor) p->fgcolor=id->misc->gtext_link||"#0000ff";
  string ext="";
  if(query("ext")) ext="."+(p->format || "gif");
  if(!arg->short)
    return query_internal_location()+image_cache->store( ({p,c}), id )+ext;
  return "+"+image_cache->store( ({p,c}), id )+ext;
}

string simpletag_gtext_id(string t, mapping arg, string c, RequestID id) {
  mapping p=mk_gtext_arg(arg,id);
  if(arg->href && !p->fgcolor) p->fgcolor=id->misc->gtext_link||"#0000ff";
  if(!arg->short)
    return query_internal_location()+"$"+image_cache->store(p, id)+"/";
  return "+"+image_cache->store(p, id )+"/foo";
}

string simpletag_gtext(string t, mapping arg, string c, RequestID id)
{
  if((c-" ")=="") return "";

  c=fix_text(c,arg,id);
  mapping p=mk_gtext_arg(arg,id);

  string ext="";
  if(query("ext")) ext="."+(p->format || "gif");

  string lp="%s", url="", ea="";

  int input=0;
  if(arg->submit)
  {
    input=1;
    m_delete(arg,"submit");
  }

  if(arg->href)
  {
    url = arg->href;
    lp = replace(make_tag("a",arg-hreffilter),"%","%%")+"%s</a>";
    if(!p->fgcolor) p->fgcolor=id->misc->gtext_link||"#0000ff";
    m_delete(arg, "href");
  }

  if(!arg->noxml) { arg["/"]="/"; m_delete(arg, "noxml"); }
  if(!arg->border) arg->border=arg->border||"0";

  if(arg->split)
  {
    string res="",split=arg->split;
    if(lower_case(split)=="split") split=" ";
    m_delete(arg,"split");
    c=replace(c, "\n", " ");
    int setalt=!arg->alt;
    foreach(c/split-({""}), string word)
    {
      string fn = image_cache->store( ({ p, word }),id );
      mapping size = image_cache->metadata( fn, id, 1 );
      if(setalt) arg->alt=word;
      arg->src=query_internal_location()+fn+ext;
      if( size )
      {
        arg->width  = (string)size->xsize;
        arg->height = (string)size->ysize;
      }
      res+=make_tag( "img", arg )+" ";
    }
    return sprintf(lp,res);
  }

  string num = image_cache->store( ({ p, c }), id );
  mapping size = image_cache->metadata( num, id, 1 );
  if(!arg->alt) arg->alt=replace(c,"\"","'");

  arg->src=query_internal_location()+num+ext;
  if(size) {
    arg->width=(string)size->xsize;
    arg->height=(string)size->ysize;
  }

  if(arg->magic)
  {
    string magic=replace(arg->magic,"'","`");
    m_delete(arg,"magic");

    if(p->bevel) p->pressed=1;

    m_delete(p, "fgcolor");
    foreach(glob("magic-*", indices(arg)), string q)
    {
      p[q[6..]]=arg[q];
      m_delete(arg, q);
    }

    if(!p->fgcolor) p->fgcolor=id->misc->defines->theme_alink||
			id->misc->defines->alink||"#ff0000";

    string num2 = image_cache->store( ({ p, c }),id );
    size = image_cache->metadata( num2, id );
    if(size) {
      arg->width=(string)max(arg->xsize,size->xsize);
      arg->height=(string)max(arg->ysize,size->ysize);
    }

    if(!id->supports->images) return sprintf(lp,arg->alt);

    string sn="i"+id->misc->gtext_mi++;
    if(!id->supports->js_image_object) {
      return (!input)?
        ("<a "+ea+"href=\""+url+"\">"+make_tag("img",arg+(["name":sn]))+"</a>"):
        make_tag("input",arg+(["type":"image"]));
    }

    arg->name=sn;
    string res="\n<script>\n";
    if(!id->misc->gtext_magic_java) {
      res += "function i(ri,hi,txt)\n"
        "{\n"
        "  document.images[ri].src = hi.src;\n"
        "  setTimeout(\"top.window.status = '\"+txt+\"'\", 100);\n"
	"}\n";
    }
    id->misc->gtext_magic_java="yes";

    return
      res+
      " "+sn+"l = new Image("+arg->width+", "+arg->height+");"+sn+"l.src = \""+arg->src+"\";\n"
      " "+sn+"h = new Image("+arg->width+", "+arg->height+");"+sn+"h.src = \""+query_internal_location()+num2+ext+"\";\n"
      "</script>\n"+
      "<a "+ea+"href=\""+url+"\" "+
      (input?"onClick='document.forms[0].submit();' ":"")
      +"onMouseover=\"i('"+sn+"',"+sn+"h,'"+(magic=="magic"?url:magic)+"'); return true;\" "
      "onMouseout=\"top.window.status='';document.images['"+sn+"'].src = "+sn+"l.src;\">"
      +make_tag("img",arg)+"</a>";
  }

  if(input)
    return make_tag("input",arg+(["type":"image"]));

  return sprintf(lp,make_tag("img",arg));
}

array(string) simpletag_gh(string t, mapping m, string c, RequestID id) {
  int i;
  if(sscanf(t, "%s%d", t, i)==2 && i>1)
    m->scale = (string)(1.0 / ((float)i*0.6));
  if(!m->valign) m->valign="top";
 return ({ "<p>"+simpletag_gtext("",m,c,id)+"<br>" });
}

array(string) simpletag_anfang(string t, mapping m, string c, RequestID id) {
  if(!m->align) m->align="left";
  return ({ "<br clear=\"left\">"+simpletag_gtext("",m,c[0..0],id)+c[1..] });
}


// --------------- tag and container registration ----------------------

mapping query_simpletag_callers() {
  return ([ "gtext-id" : ({ RXML.FLAG_EMPTY_ELEMENT, simpletag_gtext_id }),
	    "gtext-url" : ({ 0, simpletag_gtext_url }),
	    "anfang" : ({ 0, simpletag_anfang }),
	    "gh1" : ({ 0, simpletag_gh }),
	    "gh2" : ({ 0, simpletag_gh }),
	    "gh3" : ({ 0, simpletag_gh }),
	    "gh4" : ({ 0, simpletag_gh }),
	    "gh5" : ({ 0, simpletag_gh }),
	    "gh6" : ({ 0, simpletag_gh }),
	    "gtext" : ({ 0, simpletag_gtext }),
  ]);
}
