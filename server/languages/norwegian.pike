
// Norwegian language plugin
// Støtte for norsk på www-serveren.. morten@nvg.unit.no

inherit "abstract.pike";

constant cvs_version = "$Id$";
constant _id = ({ "no", "norwegian", "norsk" });
constant _aliases = ({ "no", "nor", "norwegian", "norsk" });

constant months = ({
  "januar", "februar", "mars", "april", "mai",
  "juni", "juli", "august", "september", "oktober",
  "november", "desember" });

constant days = ({
  "søndag","mandag","tirsdag","onsdag",
  "torsdag","fredag","lørdag" });

constant implode_conjunction = "og";

string ordered(int i)
{
    return "" + i + ".";
}

string date(int timestamp, mapping m)
{
  mapping t1=localtime(timestamp);
  mapping t2=localtime(time(0));

  if(!m) m=([]);

  if(!(m["full"] || m["date"] || m["time"]))
  {
    if(t1["yday"] == t2["yday"] && t1["year"] == t2["year"])
      return "i dag, klokken " + ctime(timestamp)[11..15];
  
    if(t1["yday"] == t2["yday"]-1 && t1["year"] == t2["year"])
      return "i går, klokken " + ctime(timestamp)[11..15];
  
    if(t1["yday"] == t2["yday"]+1 && t1["year"] == t2["year"])
      return "i morgen, ved "  + ctime(timestamp)[11..15];
  
    if(t1["year"] != t2["year"])
      return month(t1["mon"]+1) + " " + (t1["year"]+1900);
    else
      return "den " + t1["mday"] + " " + month(t1["mon"]+1);
  }
  if(m["full"])
    return sprintf("%s, den %s %s %d",
                   ctime(timestamp)[11..15],
                   ordered(t1["mday"]),
                   month(t1["mon"]+1), t1["year"]+1900);
  if(m["date"])
    return sprintf("den %s %s %d", ordered(t1["mday"]),
                   month(t1["mon"]+1), t1["year"]+1900);

  if(m["time"])
    return ctime(timestamp)[11..15];
}

string number(int num)
{
  if(!num)
    return "null";
  if(num<0)
    return "minus "+number(-num);
  switch(num)
  {
   case 0:  return "";
   case 1:  return "en";
   case 2:  return "to";
   case 3:  return "tre";
   case 4:  return "fire";
   case 5:  return "fem";
   case 6:  return "seks";
   case 7:  return "sju";
   case 8:  return "åtte";
   case 9:  return "ni";
   case 10: return "ti";
   case 11: return "elleve";
   case 12: return "tolv";
   case 13: return "tretten";
   case 14: return "fjorten";
   case 15: return "femten";
   case 16: return "seksten";
   case 17: return "sytten";
   case 18: return "atten";
   case 19: return "nitten";
   case 20: return "tjue";
   case 30: return "tretti";
   case 40: return "forti";
   case 50: return "femti";
   case 60: return "seksti";
   case 70: return "sytti";
   case 80: return "åtti";
   case 90: return "nitti";
   case 21..29: case 31..39: case 41..49:
   case 51..59: case 61..69: case 71..79:
   case 81..89: case 91..99:
     return number((num/10)*10)+number(num%10);
   case 100..999: return number(num/100)+"hundre"+number(num%100);
   case 1000..999999: return number(num/1000)+"tusen"+number(num%1000);
   case 1000000..999999999:
     return number(num/1000000)+"millioner"+number(num%1000000);
   default:
    return "ekstremt mange";
  }
}

protected void create()
{
  roxen.dump( __FILE__ );
}
