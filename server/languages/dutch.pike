/* */

inline string month(int num)
{
  return ({ "Januari", "Februari", "Maart", "April", "Mei",
	    "Juni", "Juli", "Augustus", "September", "Oktober",
	    "November", "December" })[ num - 1 ];
}

string ordered(int i)
{
  switch(i)
  {
   case 1:
    return "1:st"; 
   default:
    return i+"de";
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
      return "vandaag, "+ ctime(timestamp)[11..15];
  
    if(t1["yday"]+1 == t2["yday"] && t1["year"] == t2["year"])
      return "gisteren, "+ ctime(timestamp)[11..15];
  
    if(t1["yday"]-1 == t2["yday"] && t1["year"] == t2["year"])
      return "morgen, "+ ctime(timestamp)[11..15];
  
    if(t1["year"] != t2["year"])
      return (month(t1["mon"]+1) + " " + (t1["year"]+1900));
    return (month(t1["mon"]+1) + " " + ordered(t1["mday"]));
  }
  if(m["full"])
    return ctime(timestamp)[11..15]+", "+
           month(t1["mon"]+1) + " de "
           + ordered(t1["mday"]) + " in het jaar " +(t2["year"]+1900);
  if(m["date"])
    return month(t1["mon"]+1) + " de "  + ordered(t1["mday"])
      + " in het jaar " +(t2["year"]+1900);
  if(m["time"])
    return ctime(timestamp)[11..15];
}


string number(int num)
{
  if(num<0)
    return "minus "+number(-num);
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
   case 80: return "tachtig";
   case 40: return "veertig";
   case 60: case 70: case 90: 
     return number(num/10)+"ty";
   case 50: return "vijftig";
   case 21..29: case 31..39: 
   case 51..59: case 61..69: case 71..79: 
   case 81..89: case 91..99: case 41..49: 
     return number((num/10)*10)+number(num%10);
   case 100..999: return number(num/100)+" honderd "+number(num%100);
   case 1000..999999: return number(num/1000)+" duizend "+number(num%1000);
   case 1000000..999999999: 
     return number(num/1000000)+"miljoen "+number(num%1000000);
   default:
    return "veel";
  }
}

string day(int num)
{
  return ({ "Zondag","Maandag","Dinsdag","Woensdag",
	    "Donderdag","Vrijdag","Zaterdag" }) [ num -1 ];
}

array aliases()
{
  return ({ "du", "ned", "dutch" });
}
