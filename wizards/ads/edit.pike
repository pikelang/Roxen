inherit "wizard";

constant name = "Ad Edit Wizard";
constant doc = "Edit an ad.";

#define V id->variables

string page_0(object id, object db)
{
  string ret;
  array(mapping) ads;

  ads = Advert.Ad.get_ads(db);
  if (sizeof(ads) == 0)
    return "Sorry. The are no ads to edit.";

  ret = "Select the ad you wish to edit:<P><TABLE>";
  foreach(ads, mapping m)
    ret +=  "<TR><TD><var type=radio name=ad value="+m->id+"></TD>"
	    "<TD>"+Advert.Ad.display_ad(m, db)+"</TD></TR>";
  ret += "</TABLE>";

  return ret;
}

int verify_0(object id)
{
  if (!V->ad || V->ad == "0")
    return 1;
}

string page_1(object id, object db)
{
  mapping m;

  m = Advert.Ad.get_info((int)V->ad, db);

  if (m->type == "graphic")
  {
    m = Advert.Ad.get_graphic_info(m, db);
    return 
	"<var type=hidden name=ad value="+m->ad+">"
	"<var type=hidden name=type value='"+m->type+"'>"
	"<TABLE CELLSPACING=0 CELLPADDING=0>"
        "<TR><TD>Image source:</TD><TD>"
	"<var type=string name=src size=40 default='"+html_encode_string(m->src)+"'></TD></TR>"
        "<TR><TD>Image width:</TD><TD>"
	"<var type=int name=width default="+m->width+"></TD></TR>"
        "<TR><TD>Image height:</TD><TD>"
	"<var type=int name=height default="+m->height+"></TD></TR>"
        "<TR><TD>Clickthrough URL:</TD><TD>"
	"<var type=string name=url size=40 default='"+html_encode_string(m->url)+"'></TD></TR>"
        "<TR><TD>Target frame:</TD><TD>"
	"<var type=string name=target size=40 default='"+html_encode_string(m->target)+"'></TD></TR>"
        "<TR><TD>ALT text:</TD><TD>"
	"<var type=string name=alt size=40 default='"+html_encode_string(m->alt)+"'></TD></TR>"
	"<TR><TD>JavaScript:</TD><TD>"
	"<var type=checkbox name=js default='"+(m->js=="Y"?"on":"off")+"'></TD></TR>"
	"</TABLE>";
  }
  else
    return "That ad type is not supported.";
}

int verify_1(object id)
{
  if (!V->ad || V->ad == "0")
    return 1;
  if (!V->type || V->type != "graphic")
    return 1;
  if (!V->src || !sizeof(V->src))
    return 1;
  if (!V->width || V->width == "0")
    return 1;
  if (!V->height || V->height == "0")
    return 1;
  if (!V->url || sizeof(V->url) < 7)
    return 1;
}

string page_2(object id, object db)
{
  if (V->type == "graphic")
  {
    if ((V->js/"\0")[0] == "on")
      V->js = "Y";
    else
      V->js = "N";
    Advert.Ad.set_graphic_info(db, V);
  }
  return "The ad has been updated.";
}

