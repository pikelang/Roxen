/*

string cvs_version = "$Id$";
Created by:

---------------------+--------------------------------------------------
Patrick KREMER       | U.c. de Louvain (Belgium)  Institute of Geography
kremer@geog.ucl.ac.be| Xin1-Lu3wen4 Da4xue2 (Bi3li4shi2)  Di4li3xue2 Xi4
fax:++32-10/472877   | Pl. Pasteur,3   B-1348 Louvain-la-Neuve   Belgium
---------------------+--------------------------------------------------
http://ftp.geog.ucl.ac.be/~patrick/


*/

/*
 * name = "French language plugin ";
 * doc = "Handles the conversion of numbers and dates to French. You have to restart the server for updates to take effect. Translation by Patrick Kremer.";
 */

inherit "abstract.pike";

constant _id = ({ "fr", "french", "français" });
constant _aliases = ({ "fr", "fra", "français", "french" });

constant months = ({
  "janvier", "février", "mars", "avril", "mai",
  "juin", "juillet", "août", "septembre", "octobre",
  "novembre", "décembre" });

constant days = ({
  "dimanche", "lundi", "mardi", "mercredi",
  "jeudi", "vendredi", "samedi" });

string ordered(int i)
{
  switch(i)
  {
   case 1:
    return "1:ier"; 
   default:
    return (string)i;
  }
}

string date(int timestamp, mapping|void m)
{
  mapping t1=localtime(timestamp);
  mapping t2=localtime(time(0));

  if(!m) m=([]);

  if(!(m["full"] || m["date"] || m["time"]))
  {
    if(t1["yday"] == t2["yday"] && t1["year"] == t2["year"])
      return "aujourd'hui, "+ ctime(timestamp)[11..15];
  
    if(t1["yday"]+1 == t2["yday"] && t1["year"] == t2["year"])
      return "hier, "+ ctime(timestamp)[11..15];
  
    if(t1["yday"]-1 == t2["yday"] && t1["year"] == t2["year"])
      return "demain, "+ ctime(timestamp)[11..15];
  
    if(t1["year"] != t2["year"])
      return (month(t1["mon"]+1) + " " + (t1["year"]+1900));
    return (ordered(t1["mday"]) + " " + month(t1["mon"]+1));
  }
  if(m["full"])
    return ctime(timestamp)[11..15]+", le "+
      ordered(t1["mday"]) + " "  + month(t1["mon"]+1) 
      + " de l'année " +(t1["year"]+1900);
  if(m["date"])
    return ordered(t1["mday"]) + " "  + month(t1["mon"]+1) 
      + " " +(t1["year"]+1900);
  if(m["time"])
    return ctime(timestamp)[11..15];
}


string number(int num)
{
  if(!num)
    return "zéro";
  if(num<0)
    return "moins "+number(-num);
  switch(num)
  {
   case 0:  return "";
   case 1:  return "une";
   case 2:  return "deux";
   case 3:  return "trois";
   case 4:  return "quatre";
   case 5:  return "cinq";
   case 6:  return "six";
   case 7:  return "sept";
   case 8:  return "huit";
   case 9:  return "neuf";
   case 10: return "dix";
   case 11: return "onze";
   case 12: return "douze";
   case 13: return "treize";
   case 14: return "quatorze";
   case 15: return "quinze";
   case 16: return "seize";
   case 17: return "dix-sept";
   case 18: return "dix-huit";
   case 19: return "dix-neuf";
   case 20: return "vingt";
   case 30: return "trente";
   case 40: return "quarante";
   case 50: return "cinquante";
   case 60: return "soixante";
   case 80: return "quatre-vingt";
   case 21: case 31: case 41:
   case 51: case 61:
     return number((num/10)*10)+"-et-un";
   case 71: case 91:
     return number((num/10)*10-10)+"-et-onze";
   case 22..29: case 32..39: case 42..49:
   case 52..59: case 62..69: case 81..89: 
     return number((num/10)*10)+"-"+number(num%10);
   case 70: case 72..79: case 90: case 92..99:
      return number((num/10)*10-10)+"-"+number((num%10)+10);
   case 200: case 300: case 400: case 500:
   case 600: case 700: case 800: case 900:
     return number(num/100)+" cents";
   case 100..199:
    return "cent "+number(num%100);
   case 201..299: case 301..399:
   case 401..499: case 501..599: case 601..699:
   case 701..799: case 801..899: case 901..999: 
     return number(num/100)+" cent "+number(num%100);
   case 1000..1999: return "mille "+number(num%1000);
   case 2000..999999: return number(num/1000)+" mille "+number(num%1000);
   case 1000000:
     return "un million";
   case 1000001..1999999:
     return number(num/1000000)+" million "+number(num%1000000);
   case 2000000..999999999:
     if(num%1000000 == 0)
       return number(num/1000000)+" millions de ";
     return number(num/1000000)+" millions "+number(num%1000000);
   default:
    return "beaucoup";
  }
}

protected void create()
{
  roxen.dump( __FILE__ );
}
