inherit "wizard";

constant name = "Ad Add Wizard";
constant doc = "Add an ad.";

#define V id->variables

string page_0(object id)
{
  return "Ad Type: <var type=select name=type options=graphic,html>";
}

int verify_0(object id)
{
  if (V->type == "graphic")
    return 0;
  else
    return 1;
}

string page_1(object id)
{
  if (V->type == "graphic")
    return 
	"<TABLE CELLSPACING=0 CELLPADDING=0>"
        "<TR><TD>Image source:</TD><TD><var type=string name=src size=40></TD></TR>"
        "<TR><TD>Image width:</TD><TD><var type=int name=width default=468></TD></TR>"
        "<TR><TD>Image height:</TD><TD><var type=int name=height default=60></TD></TR>"
        "<TR><TD>Clickthrough URL:</TD><TD><var type=string name=url size=40></TD></TR>"
        "<TR><TD>Target frame:</TD><TD><var type=string name=target size=40></TD></TR>"
        "<TR><TD>ALT text:</TD><TD><var type=string name=alt size=40></TD></TR>"
	"<TR><TD>JavaScript:</TD><TD><var type=checkbox name=js default=on></TD></TR>"
	"</TABLE>";
  else
    return "That ad type is not supported.";
}

int verify_1(object id)
{
  if (!V->src || !sizeof(V->src))
    return 1;
  if (!V->width || V->width == 0)
    return 1;
  if (!V->height || V->height == 0)
    return 1;
  if (!V->url || sizeof(V->url) < 7)
    return 1;
}

string page_2(object id)
{
  return "This is what the ad will look like:<P>" +
	Advert.Ad.display_graphic_ad(V) + "<P>"
        "If this OK, click on Next to ad the add. Otherwise click "
	"on Back to change the ad before adding it.";
}

string page_3(object id, object db)
{
  if (V->type == "graphic")
  {
    if ((V->js/"\0")[0] == "on")
      V->js = "Y";
    else
      V->js = "N";
  }
  Advert.Ad.add_ad(V, db);
  return "Ad has been added.";
}

