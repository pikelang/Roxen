/* name="Czech language support for Roxen";
   doc="Author: Jan Petrous 16.10.1997<br>"
   "Based on Slovenian language module by Iztok Umek<br>"
   "E-mail: hop@unibase.cz<br>";

   You can do enything you want this code.
   Please consult me before modifying czech.pike.
*/
string cvs_version = "$Id: czech.pike,v 1.2 1997/11/19 15:38:51 grubba Exp $";
inline string month(int num)
{
  return ({ "Leden", "Unor", "Brezen", "Duben", "Kveten",
	    "Cerven", "Cervenec", "Srpen", "Zari", "Rijen",
	    "Listopad", "Prosinec" })[ num - 1 ];
}

string ordered(int i)
{
  switch(i)
  {
   case 0:
    return ("buggy");
   default:
      return (i+".");
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
      return ("dnes, "+ ctime(timestamp)[11..15]);
  
    if(t1["yday"]+1 == t2["yday"] && t1["year"] == t2["year"])
      return ("vcera, "+ ctime(timestamp)[11..15]);
  
    if((t1["yday"]-1) == t2["yday"] && t1["year"] == t2["year"])
      return ("zitra, "+ ctime(timestamp)[11..15]);
  
    if(t1["year"] != t2["year"])
      return (month(t1["mon"]+1) + " " + (t1["year"]+1900));
    return (ordered(t1["mday"]) + " " + month(t1["mon"]+1));
  }
  if(m["full"])
    return (ctime(timestamp)[11..15]+", "+
	   ordered(t1["mday"]) +
           month(t1["mon"]+1) +
           (t2["year"]+1900));
  if(m["date"])
    return (ordered(t1["mday"]) + month(t1["mon"]+1) + " " +
       (t2["year"]+1900));
  if(m["time"])
    return (ctime(timestamp)[11..15]);
}


string number(int num)
{
  if(num<0)
    return ("minus "+number(-num));
  switch(num)
  {
   case 0:  return ("");
   case 1:  return ("jedna");
   case 2:  return ("dve");
   case 3:  return ("tri");
   case 4:  return ("ctyri");
   case 5:  return ("pet");
   case 6:  return ("sest");
   case 7:  return ("sedm");
   case 8:  return ("osm");
   case 9:  return ("devet");
   case 10: return ("deset");
   case 11: return ("jedenact");
   case 12: return ("dvanact");
   case 13: case 16..18: return (number(num-10)+"nact");
   case 14: return ("ctrnact");
   case 15: return ("patnast");
   case 19: return ("devatenact");
   case 20: return ("dvacet");
   case 30: return ("tricet");
   case 40: return ("ctyricet");
   case 50: return ("padesat");
   case 60: return ("sedesat");
   case 70: return ("sedmdesat");
   case 80: return ("osmdesat");
   case 90: return ("devadesat");
   case 21..29: case 31..39: 
   case 51..59: case 61..69: case 71..79: 
   case 81..89: case 91..99: case 41..49: 
     return (number((num/10)*10)+number(num%10));
   case 100..199: return ("sto"+number(num%100));
   case 200..299: return ("dveste "+number(num%100));
   case 300..499: return (number(num/100)+"sta "+number(num%100));
   case 500..999: return (number(num/100)+"set "+number(num%100));
   case 1000..1999: return ("tisic "+number(num%1000));
   case 2000..2999: return ("dva tisice "+number(num%1000));
   case 3000..999999: return (number(num/1000)+" tisic "+number(num%1000));
   case 1000000..999999999: 
     return (number(num/1000000)+" milion "+number(num%1000000));
   default:
    perror("foo\n"+ num +"\n");
    return ("hodne");
  }
}

string day(int num)
{
  return ({ "Nedele","Pondeli","Utery","Streda",
	    "Ctvrtek","Patek","Sobota" })[ num - 1 ];
}

array aliases()
{
  return ({ "cs", "cz", "cze", "czech" });
}



