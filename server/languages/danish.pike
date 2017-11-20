/*
 * name = "Danish language plugin ";
 * doc = "Handles the conversion of numbers and dates to Danish. You have to restart the server for updates to take effect.";
 */

inherit "abstract.pike";

constant cvs_version = "$Id$";
constant _id = ({ "dk", "danish", "dansk" });
constant _aliases = ({ "dk", "da", "dan", "dnk", "dansk", "danish" });

constant months = ({
  "januar", "februar", "marts", "april", "maj",
  "juni", "juli", "august", "september", "oktober",
  "november", "december" });

constant days = ({
  "søndag","mandag","tirsdag","onsdag", "torsdag","fredag",
  "lørdag" });

string ordered(int i)
{
  if (i%100 == 2)
    return i + ":n";
  return i + ":e";
}

string date(int timestamp, mapping|void m)
{
  mapping t1=localtime(timestamp);
  mapping t2=localtime(time(0));

  if(!m) m=([]);

  if(!(m["full"] || m["date"] || m["time"]))
  {
    if(t1["yday"] == t2["yday"] && t1["year"] == t2["year"])
      return "i dag, klokken " + ctime(timestamp)[11..15];

    if(t1["yday"] == t2["yday"]-1 && t1["year"] == t2["year"])
      return "igår, klokken " + ctime(timestamp)[11..15];

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
		   (string) t1["mday"],
		   month(t1["mon"]+1), t1["year"]+1900);
  if(m["date"])
    return sprintf("den %s %s %d", (string)t1["mday"],
		   month(t1["mon"]+1), t1["year"]+1900);

  if(m["time"])
    return ctime(timestamp)[11..15];
}

string _number(int num)
{
  switch(num)
  {
   case 0:  return "";
   case 1:  return "en";
   case 2:  return "to";
   case 3:  return "tre";
   case 4:  return "fire";
   case 5:  return "fem";
   case 6:  return "seks";
   case 7:  return "syv";
   case 8:  return "otte";
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
   case 20: return "tyve";
   case 30: return "tredive";
   case 40: return "fyrre";
   case 50: return "halvtreds";
   case 60: return "tres";
   case 70: return "halvfjerds";
   case 80: return "firs";
   case 90: return "halvfems";
   case 21..29: case 31..39: case 41..49:
   case 51..59: case 61..69: case 71..79:
   case 81..89: case 91..99:
    return _number(num%10)+"og"+_number((num/10)*10);

   case 100:
     return "et hundrede";
   case 200: case 300: case 400: case 500:
   case 600: case 700: case 800: case 900:
     return number(num/100)+" hundrede";
   case 101..199:
     return "et hundrede og "+number(num%100);
   case 201..299: case 301..399: case 401..499:
   case 501..599: case 601..699: case 701..799: case 801..899:
   case 901..999:
     return number(num/100)+" hundrede og "+number(num%100);
   case 1000:
     return "et tusind";
   case 1001..1099:
     return "et tusind og "+number(num%1000);
   case 1100..999999:
     return number(num/1000)+" tusind "+number(num%1000);
   case 1000000..1999999:
    return "en million "+_number(num%1000000);
   case 2000000..999999999:
     return _number(num/1000000)+" millioner "+_number(num%1000000);
   default:
    return "mange";
  }
}

string number(int num)
{
  if (num<0) {
    return("minus "+_number(-num));
  } if (num) {
    return(_number(num));
  } else {
    return("noll");
  }
}


protected void create()
{
  roxen.dump( __FILE__ );
}
