/* */

/*
 * name = "Dutch language plugin ";
 * doc = "Handles the conversion of numbers and dates to Dutch. You have to restart the server for updates to take effect.";
 *
 * Rewritten by Stephen R. van den Berg <srb@cuci.nl>, 1998/06/16
 */

constant cvs_version="$Id: dutch.pike,v 1.6 1998/06/16 09:35:06 grubba Exp $";

string month(int num)
{
  return ({ "januari", "februari", "maart", "april", "mei",
	    "juni", "juli", "augustus", "september", "oktober",
	    "november", "december" })[ num - 1 ];
}

string ordered(int i)
{
  return i+"e";
}

string date(int timestamp, mapping|void m)
{
  mapping t1=localtime(timestamp);
  mapping t2=localtime(time(0));

  if(!m) m=([]);

  if(!(m["full"] || m["date"] || m["time"]))
  {
    if(t1["yday"] == t2["yday"] && t1["year"] == t2["year"])
      return "vandaag, "+ ctime(timestamp)[11..15];
  
    if(t1["yday"]+1 == t2["yday"] && t1["year"] == t2["year"])
      return "gisteren, "+ ctime(timestamp)[11..15];

    if(t1["yday"]+2 == t2["yday"] && t1["year"] == t2["year"])
      return "eergisteren, "+ ctime(timestamp)[11..15];
  
    if(t1["yday"]-1 == t2["yday"] && t1["year"] == t2["year"])
      return "morgen, "+ ctime(timestamp)[11..15];

    if(t1["yday"]-2 == t2["yday"] && t1["year"] == t2["year"])
      return "overmorgen, "+ ctime(timestamp)[11..15];
  
    if(t1["year"] != t2["year"])
      return (month(t1["mon"]+1) + " " + (t1["year"]+1900));
    return (month(t1["mon"]+1) + " " + ordered(t1["mday"]));
  }
  if(m["full"])
    return ctime(timestamp)[11..15]+", "+
           month(t1["mon"]+1) + " de "
           + ordered(t1["mday"]) + " in het jaar " +(t1["year"]+1900);
  if(m["date"])
    return month(t1["mon"]+1) + " de "  + ordered(t1["mday"])
      + " in het jaar " +(t1["year"]+1900);
  if(m["time"])
    return ctime(timestamp)[11..15];
}

#define        NUM_REDUCE(unit,name)   \
  if((unit)>0&&num>=(unit))            \
    return snumber(num/(unit))+(name)+snumber(num%(unit))
 

static string snumber(int num)
{
  if(num<0)
    return "min "+snumber(-num);
  if(1000000000000000000000000>0&&num>=1000000000000000000000000)
    return "veel";
  NUM_REDUCE(1000000000000000000000,"triljard");
  NUM_REDUCE(1000000000000000000,"triljoen");
  NUM_REDUCE(1000000000000000,"biljard");
  NUM_REDUCE(1000000000000,"biljoen");
  NUM_REDUCE(1000000000,"miljard");
  NUM_REDUCE(1000000,"miljoen");
  if(1000<=num&&num<2000)
    return "duizend"+snumber(num-1000);
  NUM_REDUCE(1000,"duizend");
  if(100<=num&&num<200)
    return "honderd"+snumber(num-100);
  NUM_REDUCE(100,"honderd");
  switch(num)
  {
  case 0:  return "";
  case 1:  return "een";
  case 2:  return "twee";
  case 3:  return "drie";
  case 4:  return "vier";
  case 5:  return "vijf";
  case 6:  return "zes";
  case 7:  return "zeven";
  case 8:  return "acht";
  case 9:  return "negen";
  case 10: return "tien";
  case 11: return "elf";
  case 12: return "twaalf";
  case 13: return "dertien";
  case 14: return "viertien";
  case 15: return "vijftien";
  case 16: return "zestien";
  case 17: return "zeventien";
  case 18: return "achttien";
  case 19: return "negentien";
  case 20: return "twintig";
  case 30: return "dertig";
  case 40: return "veertig";
  case 80: return "tachtig";
  case 50: case 60: case 70: case 90: 
    return snumber(num/10)+"tig";
  default:
    return snumber(num%10)+"en"+snumber((num/10)*10);
  }
}

string number(int num)
{
  return num?snumber(num):"nul";
}

string day(int num)
{
  return ({ "zondag", "maandag", "dinsdag", "woensdag",
	    "donderdag", "vrijdag", "zaterdag" }) [ num -1 ];
}

array aliases()
{
  return ({ "du", "nl", "ned", "dutch" });
}
