inherit "module";
inherit "wizard";
#include <module.h>

object db;

array register_module()
{
  return ({ MODULE_LOCATION, "GText creator",
	    "GText creator allows easy point-and-click configuration "
	    "of gtext tag argument lists. You must have the graphic text "
	    " module installed on your server to use this module.",0,1 });
}

#define DB_IS(X) this_object()["db_is_not_"+(X)]

int db_is_not_sql(){ return query("db-type") != "sql"; }
int db_is_not_files(){ return query("db-type") != "files"; }
int db_is_not_pdb(){ return query("db-type") != "pdb"; }

void create()
{
  defvar( "welcome-message",
	  "Welcome to the GText creator. If you are a first-time"
	  " user, "
	  "<a href=initial>please use any name and "
	  " password to login</a>. If you have been here before, use "
	  "the same name and password to access your old gtext styles"
	  ,
	  "Welcome message",
	  TYPE_TEXT, "");
  defvar("db-type", "sql", "DB Type", TYPE_STRING_LIST, 
	 "The db type to use. Sql is prefered, but the others works as "
	 "well.",
	 ({ "sql", /*"files",*/ "pdb" }));


  defvar("location", "/gtext_creator/", "Location", TYPE_LOCATION,
	 "The module mountpoint");

  defvar("sql-host", "mysql://localhost/gtext", 
	 "DB; SQL database to connect to",
	 TYPE_STRING, "", 0, 
	 DB_IS( "sql" ));

//   defvar("directory", "gtext_composer_db", "DB; Directory to store files in",
// 	 TYPE_STRING, "", 0, DB_IS( "files" ));

  defvar("pdb-name", "gtext_composer_db", "DB; PDB database directory",
	 TYPE_STRING, "", 0, DB_IS( "pdb" ));
}

class SqlDB
{
  object db;

  void set(string s, mapping to)
  {
    string q = db->quote(encode_value( to ));
    if(!get(s))
      db->query("insert into foo values ('"+db->quote(s)+"','"+q+"')");
    else
      db->query("update foo set q='"+q+"' where id='"+db->quote(s)+"'");
  }

  void get(string s)
  {
    mapping r = db->query("select q from foo where id='"+db->quote(s)+"'");
    if(!r || !sizeof(r))
      return 0;
    return decode_value( r[0]->q );
  }

  void create(object d)
  {
    catch {
      d->query("create table foo ( id varchar(32) primary key, q blob )");
    };    
    db = d;
  }
}

object create_db()
{
  switch(query("db-type"))
  {
   case "sql":
     return SqlDB( Sql.sql( query("sql-host") ) );
     break;
//    case "files":
//      db = FilesDB( query("directory") );
//      break;
   case "pdb":
     return PDB( query("pdb-name"), "wcrz" );
     break;
  }
}

void start()
{
  catch(db = create_db());
}


string|void status()
{
  if(!db) return "<font color=red>No database available.</font>";
}

mapping login(object id)
{
  if(!id->realauth)
    return http_auth_required("GText Creator.");
  return 0;
}


class User
{
  static string name_pass;
  static mapping types;


  void save()
  {
    db->set( name_pass, encode_value( types ) );
  }

  void restore()
  {
    if(catch {
      types = decode_value( db->get( name_pass ) );
    })
      types = ([ ]);
  }


  void create(string np)
  {
    name_pass = np;
    restore();
  }


  string list_types(string pattern)
  {
    int i;
    mapping t = copy_value(types);
    m_delete(t,0);
    array a = indices(t);
    array b = values(t);
    sort(b->name, a, b);
    string res="";
    for(i=0; i<sizeof(a); i++)
      res+=replace(pattern, ({"%i", "%n", "%c"}), 
		   ({(string)a[i], b[i]->name||"unnamed", 
		     b[i]->comment||"" }));
    return res;
  }

#define SA(X) do{if(!form->X){if(!nodelete)m_delete(type,#X);}else type->X=form->X;}while(0)
#define SAT(X) do{if(!(form->X && form->X!="0")){if(!nodelete)m_delete(type,#X);}else type->X=#X;}while(0)

  void process_form( mapping form, mapping type, int|void nodelete )
  {
    SAT(nobgscale);SAT(crop);     SA(outline);  SA(name);       SA(fg);
    SA(bg);        SAT(verbatim); SA(font);     SA(font_size);  SAT(rescale);
    SA(textbelow); SAT(notrans);  SAT(split);   SA(quant);      SA(move);
    SAT(fs);       SA(border);    SA(xspacing); SA(yspacing);
    SA(size);      SA(bevel);     SAT(pressed); SA(talign);     SA(textbox);
    SA(xpad);      SA(ypad);      SA(shadow);   SA(bshadow);    SA(scolor);
    SA(ghost);     SA(glow);      SA(opaque);   SA(rotate);     SA(background);
    SA(alpha);     SA(texture);   SAT(tile);    SAT(mirrortile);SA(scroll);
    SA(fadein);    SA(textscale); SA(bgscale);  SAT(bold);      SAT(italic); 
    SAT(black);    SAT(light);    SA(encoding); SA(example_text); 

    SA(fgtype); SA(bgtype);
    
    if(form->glow_amount && form["glow_color.entered"])
      if((int)form->glow_amount)
	type->glow = form["glow_color.entered"]+","+form->glow_amount;
      else
	m_delete(type, "glow");

    if(form->move_x && form->move_y) 
      if(((int)form->move_x || (int)form->move_y))
	type->move = form->move_x+","+form->move_y;
      else
	m_delete(type, "move");

    if(form->size_x && form->size_y)
      if((int)form->size_x && (int)form->size_y)
	type->size = form->size_x+","+form->size_y;
      else
	m_delete(type, "size");

    if(form->textbox_opaque && form["textbox_color.entered"]
       && form->textbox_extrawidth)
      if((int)form->textbox_extrawidth)
	type->textbox = form->textbox_opaque+","+form["textbox_color.entered"]
	  +","+form->textbox_extrawidth;
      else
	m_delete(type, "textbox");

    if(form->border_width && form["border_color.entered"])
      if((int)form->border_width)
	type->border = form->border_width+","+form["border_color.entered"];
      else
	m_delete(type, "border");

    if(form->shadow_intensity && form->shadow_distance)
      if((int)form->shadow_intensity)
	type->shadow=form->shadow_intensity+","+((int)form->shadow_distance-1);
      else
	m_delete(type, "shadow");

    if(form->ghost_distance && form->ghost_blur&&form["ghost_color.entered"])
      if( (int)form->ghost_blur)
	type->ghost = form->ghost_distance+","+form->ghost_blur
	  +","+form["ghost_color.entered"];
      else
	m_delete(type, "ghost");

    if(form["textscale_c1.entered"] && form["textscale_c2.entered"] 
       && form["textscale_c3.entered"] && form["textscale_c4.entered"])
      type->textscale = form["textscale_c1.entered"]+","+
	form["textscale_c2.entered"]+","
	+form["textscale_c3.entered"]+","+form["textscale_c4.entered"];
    
    if(form["bgscale_c1.entered"] && form["bgscale_c2.entered"] 
       && form["bgscale_c3.entered"] && form["bgscale_c4.entered"])
      type->bgscale = form["bgscale_c1.entered"]+","+
	form["bgscale_c2.entered"]+","
	+form["bgscale_c3.entered"]+","+form["bgscale_c4.entered"];
    
    if(form->scroll_width && form->scroll_steps && form->scroll_delay)
      if((int)form->scroll_width)
	type->scroll = form->scroll_width+","+form->scroll_steps
	  +","+form->scroll_delay;
      else
	m_delete(type, "scroll");
      
    if(form->fadein_blur && form->fadein_steps && form->fadein_initdelay)
      if((int)type->fadein_steps)
	type->fadein = form->fadein_blur+","+form->fadein_steps
	  +","+form->fadein_initdelay;
      else
	m_delete(type, "fadein");

    if(form["outline_color.entered"] && form->outline_width)
      if((int)form->outline_width)
	type->outline =
	  form["outline_color.entered"]+","+(((int)form->outline_width)-1);
      else
	m_delete(type,"outline_width");
  }


  string parse_mform( string form, object id )
  {
    return 
      parse_html(form,(["var":wizard_tag_var,]),
		  (["cvar":wizard_tag_var]),id);
  }

  string|mapping make_type_form( mapping type, object id )
  {
    string res="";

    foreach(glob("goto-page-*", indices(id->variables)), string t)
    {
      sscanf(t, "goto-page-%s", id->variables->page);
      m_delete(id->variables, t);
    }
    foreach(glob("goto-subpage-*", indices(id->variables)), string t)
    {
      sscanf(t, "goto-subpage-%s", id->variables->subpage);
      m_delete(id->variables, t);
    }
    res += "<form action=edit-type method=GET>"
      "<input type=hidden name=page value="+id->variables->page+">\n"
      "<input type=hidden name=subpage value="+id->variables->subpage+">\n"
      "<input type=hidden name=type value="+id->variables->type+">\n";

#define BUTTON(X,T) do{if(id->variables->page==(X)) res+=(T);else res+="<input type=submit name=goto-page-"+(X)+" value='"+(T)+"'>";}while(0)
#define SBUTTON(X,T) do{if(id->variables->subpage==(X)) res+=(T);else res+="<input type=submit name=goto-subpage-"+(X)+" value='"+(T)+"'>";}while(0)
      res += "<p><hr noshade>";
    BUTTON("basic-settings", "Basic settings");
    BUTTON("render-options", "Render options");
    BUTTON("font",  "Font");
    BUTTON("background_fg",  "Background and text patterns");
    BUTTON("text-position",  "Text position");
    BUTTON("effects",        "Special effects");
    res += "<hr noshade><p>";

    switch(id->variables->page)
    {
     case "font":
       res += ("<h2>Base font to use for the text</h2>"+
	       "<var type=font name=font default=\"bitstream cyberbit\"><p>"
	       "<h2>Font size and style</h2>");
       catch {
	 multiset afv =
	   mkmultiset(available_font_versions(id->variables->font||
					      roxen->query("default_font"), 
					      32));
	  if( id->variables->light=="light" )
	    id->variables->light = "1";
	 if(afv->ln || afv->li)
	   res += "Light:  <var type=toggle name=light default=0><br>";
	  if( id->variables->bold=="bold" )
	    id->variables->bold = "1";
	 if(afv->bn || afv->bi)
	   res+="Bold:   <var type=toggle name=bold   default=0><br>";
	  if( id->variables->black=="black" )
	    id->variables->black = "1";
	 if(afv->Bn || afv->Bi)
	   res+="Black:  <var type=toggle name=black  default=0><br>";
	  if( id->variables->italic=="black" )
	    id->variables->italic = "1";
	 if(afv->li || afv->bi || afv->Bi)
	   res+="Italic: <var type=toggle name=italic default=0><br>";
       };
       res += "Size: <var name=font_size size=3 default=32> (~pixels)\n";
       break;
     case "background_fg":
       res += ("<h2>Background</h2>");
       res += ("Background type: <var type=select name=bgtype "
	       " options='color,image,crossfade' default=color><br>");
       res += "Color:<br><var type=color-small name=bg default=white><br>";
       if( id->variables->tile=="tile" )
	 id->variables->tile = "1";
       if( id->variables->mirrortile=="mirrortile" )
	 id->variables->mirrortile = "1";
       if( id->variables->rescale=="rescale" )
	 id->variables->rescale = "1";
       if(id->variables->bgtype == "image")
       {
	 m_delete(id->variables, "bgscale");
	 res += ("Image:       <var type=select name=image default='' "
		 "options=''><br>");
	 if(id->variables->mirrortile)
	   id->variables->tile=0;
	 res += "Tile:        <var type=toggle name=tile default=0><br>";
	 res += "MirrorTile:  <var type=toggle name=mirrortile default=0><br>";
	 res += ("Rescale the background image to the size of the text "
		 "<var name=rescale type=toggle default=1><p>");
 
       }
       else if(id->variables->bgtype == "crossfade")
       {
	 res += "Crossfade:";
	 if(id->variables->bgscale)
	   sscanf(id->variables->bgscale, "%s,%s,%s,%s",
		  id->variables->bgscale_c1,
		  id->variables->bgscale_c2,
		  id->variables->bgscale_c3,
		  id->variables->bgscale_c4);
	 res += "<table><tr><td>Upper left<br><var type=color-small name=bgscale_c1></td><td>" ;

	 res += "Upper right<br><var type=color-small name=bgscale_c2>"
	   "</td></tr><tr>" ;
	 res += "<td>Lower left<br><var type=color-small name=bgscale_c3></td>" ;
	 res += "<td>Lower right<br><var type=color-small name=bgscale_c4></td></tr></table>" ;
       } else {
	 m_delete(id->variables, "bgscale");
	 m_delete(id->variables, "background");
       }

       res += "<h2>Foreground</h2>";
       res += ("Foreground type: <var type=select name=fgtype "
	       " options='color,image,crossfade' default=color>");
       res += ("Opaqueness: <var type=select name=opaque default=100 options='"
	       "100,95,90,85,80,75,70,65,60,55,50,45,40,35,30,25,20,15,10'>");
       res += "Color:<br><var type=color-small name=fg default=black><br>";
       if(id->variables->fgtype == "image")
       {
         res += ("Image:       <var type=select name=texture default='' "
		 "options=''><br>");
	 if(id->variables->mirrortile)
	   id->variables->tile=0;
	 res += "Tile:        <var type=toggle name=tile default=0>";
	 res += "MirrorTile:  <var type=toggle name=mirrortile default=0>";
	 m_delete(id->variables, "textscale");
       }
       else if(id->variables->fgtype == "crossfade")
       {
	 if(id->variables->textscale)
	   sscanf(id->variables->textscale, "%s,%s,%s,%s",
		  id->variables->textscale_c1,
		  id->variables->textscale_c2,
		  id->variables->textscale_c3,
		  id->variables->textscale_c4);
	 res += "Crossfade:";
	 res += "<table><tr><td>Upper left<br><var type=color-small name=textscale_c1></td><td>" ;
	 res += "Upper right<br><var type=color-small name=textscale_c2>"
	   "</td></tr><tr>" ;
	 res += "<td>Lower left<br><var type=color-small name=textscale_c3></td>" ;
	 res += "<td>Lower right<br><var type=color-small name=textscale_c4></td></tr></table>" ;
       } else {
	 m_delete(id->variables, "textscale");
	 m_delete(id->variables, "texture");
       }

       id->variables->nobgscale = "nobgscale";
       break;

     case "render-options":
       res += "<h1>Render options</h1>";
//        res += "Place the text below the background
//        SA(textbelow); 
       if( id->variables->notrans=="notrans" )
	 id->variables->notrans = "1";

       res += ("Avoid making the background transparent "
	       "<var type=toggle name=notrans><p>");

       if( id->variables->split=="split" )
	 id->variables->split = "1";

       res += ("Generate a small image for each word instead of a big "
	       "image for the whole text <var type=toggle name=split><p>");
       
       res += ("Never use more than <var type=select name=quant options='"
	       "4,8,16,32,64,128,256' default=32> colors<p>");

       if( id->variables->fs=="fs" )
	 id->variables->fs = "1";
       res += ("Use dithering <var name=fs type=toggle><p>");

       if( id->variables->crop=="crop" )
	 id->variables->crop = "1";

       res += ("Remove all space around the text in the resulting image "
	       "<var name=crop type=toggle default=0><p>");

       if(!(int)id->variables->rotate)
	 m_delete(id->variables, "rotate");

       res += ("After rendering, rotate the image <var type=string "
	       "name=rotate default=0 size=4> degrees");

       if(search("iso-8859", id->variables->encoding)==-1)
	 id->variables->verbatim = "verbatim";
       else
	 m_delete(id->variables, "verbatim");
       break;


     case "text-position":
       res += "<h1>Text position</h1>";
       if(id->variables->move)
	 sscanf(id->variables->move, "%s,%s", 
		id->variables->move_x,
		id->variables->move_y);
//     SA(talign);
       res += ("Text alignment: <var type=select name=talign "
	       "options=left,center,right default=left><p>");
       res += ("Absolute offset: "
	       "<var type=int size=4 name=move_x>, "
	       "<var type=int size=4 name=move_y><p>");

       res+=("Horizontal spacing: <var type=int name=xspacing default=0><br>"
	     "Vertical spacing: <var type=int name=yspacing default=0><p>");
       if(id->variables->xspacing == "0")
	 m_delete(id->variables, "xspacing");
       if(id->variables->yspacing == "0")
	 m_delete(id->variables, "yspacing");
//     SA(size);
//     SA(xpad);
//     SA(ypad);
       break;

     case "anim-effects":
       if(id->variables->scroll) // either or...
	 m_delete(id->variables, "fadein");
//        SA(scroll);
//        SA(fadein);
       break;

     case "effects":
       res += "<h1>Misc text effects</h1>";
       SBUTTON("border", "Border");
       SBUTTON("bevel", "Bevel box");
       SBUTTON("ghost", "Ghost");
       SBUTTON("glow", "Glow");
       SBUTTON("outline", "Outline");
       SBUTTON("shadow", "Shadow");
       res += "<p>";
       switch(id->variables->subpage)
       {
	case "border":
	  if(id->variables->border_width == "0")
	  {
	    m_delete(id->variables, "border");
	    m_delete(id->variables, "border_width");
	  }
	  if(id->variables->border)
	    sscanf(id->variables->border, "%s,%s",
		   id->variables->border_width,
		   id->variables["border_color.entered"]);

	  res += "<h2>Border</h2>";
	  res += "Width: <var type=int default=0 name=border_width> "
	    "(0 for no border)<br>";
	  res += "Color: <br><var type=color-small default=black "
	    "name=border_color><p> ";
	  res += "<h2>Bevelbox</h2>";
	  break;
	  
	case "bevel":
	  if(id->variables->bevel == "0")
	    m_delete(id->variables, "bevel");
	  res += ("Width: <var type=int default=0 name=bevel> "
		  "(0 for no bevelbox)<br>");
	  if( id->variables->pressed=="pressed" )
	    id->variables->pressed = "1";
	  res += ("Pressed: <var type=toggle name=pressed default=0><br>");
	  break;

	case "ghost":
	  res += "<h2>'Ghost' outline</h2>";
	  if(id->variables->ghost_blur == "0")
	  {
	    m_delete(id->variables, "ghost");
	    m_delete(id->variables, "ghost_blur");
	  }
	  if(id->variables->ghost)
	    sscanf(id->variables->ghost, "%s,%s,%s",
		   id->variables->ghost_distance,
		   id->variables->ghost_blur,
		   id->variables["ghost_color.entered"]);
	  res += ("Amount: <var type=int name=ghost_blur default=0> (0 "
		  "for no ghosted outline)<br>"
		  "Distance: <var type=int name=ghost_distance default=0><br>"
		  "Color:<br><var type=color-small name=ghost_color "
		  "default=black><p>");
	  break;
	case "glow":
	  if(id->variables->glow_amount == "0")
	  {
	    m_delete(id->variables, "glow");
	    m_delete(id->variables, "glow_amount");
	  }
	  if(id->variables->glow)
	    sscanf(id->variables->glow, "%s,%s",
		   id->variables->glow_amount,
		   id->variables["glow_color.entered"]);
	  res += "<h2>Glow</h2>";
	  res += "Amount: <var type=int default=0 name=glow_amount> "
	    "(0 for no glow)<br>";
	  res += "Color: <br><var type=color-small default=black "
	    "name=glow_color><p> ";
	  break;
	case "outline":
	  if(id->variables->outline_width == "0")
	  {
	    m_delete(id->variables, "outline");
	    m_delete(id->variables, "outline_width");
	  }
	  if(id->variables->outline)
	  {
	    sscanf(id->variables->outline, "%s,%s",
		   id->variables["outline_color.entered"],
		   id->variables->outline_width);
	    id->variables->outline_width = 
	      (string)(((int)id->variables->outline_width)+1);
	  }
	  res += "<h2>Outline</h2>";
	  res += "Width: <var type=int default=0 name=outline_width> "
	    "(0 for no outline)<br>";
	  res += "Color: <br><var type=color-small default=black "
	    "name=outline_color><p> ";

	  break;
	case "shadow":
	  res += "<h2>Text shadow</h2>";
	  if(id->variables->shadow_intensity &&
	     !(int)id->variables->shadow_intensity)
	  {
	    m_delete(id->variables, "shadow");
	    m_delete(id->variables, "shadow_intensity");
	  }
	  if(id->variables->shadow)
	  {
	    sscanf(id->variables->shadow, "%s,%s",
		   id->variables->shadow_intensity,
		   id->variables->shadow_distance);
	    id->variables->shadow_distance = (string)
	      (((int)id->variables->shadow_distance)+1);
	  }
	  if(id->variables->bshadow && !id->variables->blured_shadow)
	    id->variables->blured_shadow="1";
	  if(id->variables->blured_shadow == "0")
	    m_delete(id->variables, "bshadow");

	  if(id->variables->shadow_intensity &&
	     id->variables->shadow_intensity!="0" &&
	     id->variables->blured_shadow &&
	     id->variables->blured_shadow!="0")
	    id->variables->bshadow = id->variables->shadow_intensity;
	  res += 
	    "Intensity (1-100): <var type=int name=shadow_intensity "
	    "default=0> (0 for no shadow)<br>";
	  res+="Distance from text: <var type=int name=shadow_distance default=1><br>";
	  res+="Color: <var type=color-small name=scolor default=black><br>";
	  res+="Blured: <var type=toggle name=blured_shadow><br>";
	  break;
       }
//        res += "<h2>Colored textbox</h2>";
//        SA(textbox);
       break;

     default:
       id->variables->page = "basic-settings";
       /* Basic stuff. */
       res += ("<h2>Basic settings</h2>"
	      "<pre>"
	      "Name:          <var type=string name=name>\n"
	      
	      "Text encoding: <var name=encoding type=select "
	      "options='ksc_5601,gb_2312-80,jis_x0208-1983,iso-2022,"
	       "iso-8859-1,iso-8859-2,iso-8859-3,"
	       "iso-8859-4,iso-8859-5,iso-8859-6,iso-8859-7,iso-8859-8,"
	      "iso-8859-9' default='iso-8859-1'>\n"
	      
	      "Example text:  <var type=string name=example_text "
	      "default='Example text'>"
	      "</pre>");
       break;
    }
    res += "<p><input type=submit value=\"Apply\">";
    res += "<input type=submit name=done_editing value=\"Done editing\">";
    return res;
  }

#define DEF(a,b)    if(args->a == #b) m_delete(args, #a);

  string make_gtexttag( mapping args, string text )
  {
    args = copy_value(args);
    foreach(glob("*_*", indices(args)), string d)
      if(d != "font_size")
	m_delete(args, d);

    if(args->bevel == "0")
      m_delete(args, "bevel");

    if(!args->shadow && !args->bshadow)
      m_delete(args, "scolor");
    
    if(!args->notrans)
    {
      m_delete(args, "bg");
      m_delete(args, "fg");
    }

    args->nocache = "nocache";
    
    DEF(rotate,0);
    DEF(encoding,iso-8859-1);
    DEF(yspacing,0);
    DEF(xspacing,0);
    DEF(opaque,100);
    DEF(quant,32);
    DEF(talign,left);

    if(!args->background)
      m_delete(args, "nobgscale");

    if(args->bshadow)
      m_delete(args, "shadow");

    if(args->font_size)
      args->font_size = (string)(((int)args->font_size)/2);
    DEF(font_size,32);
    if(args->encoding == "iso-8859-1") m_delete(args, "encoding");
    m_delete(args, "name");
    m_delete(args, "comment");
    m_delete(args, "bgtype");
    m_delete(args, "fgtype");

    if(args->textscale)
      m_delete(args, "fg");

    if(args->bgscale && args->notrans && args->bg)
      m_delete(args, "bg");
//     args->scale = "0.5";
//     werror("arg is %O\n", args);
    text = http_decode_string(text);
    return make_container("gtext", args, text);
  }

  mapping edit_type( int type, object id )
  {
    if(id->variables->done_editing)
      return http_redirect(fix_relative("edit-types", id), id);

    mapping current_type = types[type];
    string res="";

    werror("vars is now: %O\n", id->variables);
    process_form( id->variables, current_type, 1 );
    id->variables = current_type|id->variables;;
    res += parse_mform( make_type_form( current_type, id ), id );
    process_form( id->variables, current_type );
    werror("vars is now: %O\n", id->variables);
    save();
    string body;
    if(!current_type->notrans)
      body = "<body bgcolor=\""+(current_type->bg||"white")+
	"\" text=\""+(current_type->fg||"black")+"\">";
    else
      body = "<body bgcolor=white text=black>";
    string tag = make_gtexttag(current_type,
			       current_type->example_text?
			       current_type->example_text:
			       "Example, abcdefg");
    res += "<p><b>Example rendition:</b><p>"+
      tag+"<br>"+html_encode_string(body)+"<br>"+
      html_encode_string(replace(tag, "nocache", ""));
    return http_string_answer(parse_rxml( body+res, id ), "text/html");
  }

  mixed handle( string file, object id )
  {
    if(!name_pass) error("Internal server screwup!\n");
    string res;
    switch(file)
    {
//      case "render":
//        return render( (int)id->variables->type, id );

     case "initial":
       res +="<gtext font=default scale=0.5 encoding=iso-2022>"
	 "$(B$3$s$$$A$O(B and Welcome to the GText creator!\n"
         "Please select an action below</gtext><p>";
       res += "<ul>\n";
       res += "  <li><a href=edit-types>Edit image types</a>\n";
       res += "  <li><a href=edit-types>Render an image using an existing image type</a>\n";
       res += "  <li><a href=login>Log in as a new user</a>\n";
       res += "</ul>\n";
       return http_string_answer( parse_rxml("<title>GText Creator</title>"
      "<body bgcolor=white text=black>"+res,id), "text/html" );

     case "edit-types":
       res +="<gtext font_size=24 scale=0.5>Select which type to edit:</gtext><p><ul>";
       res += list_types( "<a href=edit-type?type=%i><font size=+1>"
			  "%n</font> <nobr><a href=delete-type?type="
			  "%i>Delete this type</a></nobr><br>%c<br>")+"</ul>";
       res += "<a href=new-type>Create a new image type</a>";
       return http_string_answer( parse_rxml("<title>GText Creator</title>"
      "<body bgcolor=white text=black>"+res,id), "text/html" );

     case "edit-type":
       if(!(int)id->variables->type)
	 return http_redirect( fix_relative("edit-types", id), id );
       return edit_type( (int)id->variables->type, id );

     case "delete-type":
       if((int)id->variables->type)
	 m_delete(types, id->variables->type);
       return http_redirect( fix_relative("edit-types", id), id );

     case "new-type":
       types[ ++types[0] ] = ([ ]);
       return http_redirect(fix_relative("edit-type?type="+types[0],id),id);

     default:
       return http_redirect( fix_relative("initial", id), id );
    }
  }
}

mapping users = ([]);

mapping|string find_file( string file, object id )
{
  mapping res;

  if(!strlen(file))
    return http_string_answer(query("welcome-message"), "text/html");

  if(res = login(id))
    return res;

  if( users[ id->realauth ] )
  {
    return users[ id->realauth ]->handle( file, id );
  }
  else
  {
    werror("create new user for '"+id->realauth+"'\n");
    users[id->realauth] = User( id->realauth );
    return find_file(file, id);
  }
  
}
