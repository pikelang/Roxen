/* Bugs by: Per */
string cvs_version = "$Id: catala.pike,v 1.2 1996/12/01 19:18:40 per Exp $";
/* Trans by: jordi@lleida.net */

inline string month(int num)
{
  return ({ "Gener", "Febrer", "Març", "Abril", "Maig",
	    "Juny", "Juliol", "Agost", "Setembre", "Octubre",
	    "Novembre", "Decembre" })[ num - 1 ];
}

string ordered(int i)
{
  switch(i)
  {
    case 1: return "1er";
    case 2: return "2on";
    case 3: return "3er";
    case 4: return "4rt";
    default: 
            return i+"é";
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
      return "avui, "+ ctime(timestamp)[11..15];
  
    if(t1["yday"]+1 == t2["yday"] && t1["year"] == t2["year"])
      return "ahir, "+ ctime(timestamp)[11..15];
  
    if(t1["yday"]-1 == t2["yday"] && t1["year"] == t2["year"])
      return "dem&agrave;, "+ ctime(timestamp)[11..15];
  
    if(t1["year"] != t2["year"])
      return (month(t1["mon"]+1) + " " + (t1["year"]+1900));
    return (month(t1["mon"]+1) + " " + ordered(t1["mday"]));
  }
  if(m["full"])
    return ctime(timestamp)[11..15]+", "+
           month(t1["mon"]+1) + " the "
           + ordered(t1["mday"]) + ", " +(t2["year"]+1900);
  if(m["date"])
    return month(t1["mon"]+1) + " the "  + ordered(t1["mday"])
      + " del any " +(t2["year"]+1900);
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
   case 1:  return "un";
   case 2:  return "dos";
   case 3:  return "tres";
   case 4:  return "quatre";
   case 5:  return "cinq";
   case 6:  return "sis";
   case 7:  return "set";
   case 8:  return "vuit";
   case 9:  return "nou";
   case 10: return "deu";
   case 11: return "onze";
   case 12: return "dotze";
   case 13: return "tretze";
   case 14: return "catorze";
   case 15: return "quinze";
   case 16: return "setze";
   case 17: return "diset";
   case 18: return "divuit";
   case 19: return "dinou";
   case 20: return "vint";
   case 30: return "trenta";
   case 40: return "quaranta";
   case 50: return "cinquanta";
   case 60: return "seixanta";
   case 70: return "setanta";
   case 80: return "vuitanta";
   case 90: return "noranta";
   case 21..29: 
	return "vint-i-"+number(num-20);
   case 31..39: case 41..49:
   case 51..59: case 61..69: case 71..79: 
   case 81..89: case 91..99:  
     return number((num/10)*10)+ " " +number(num%10);
   case 100..199: return "cent "+number(num%100);
   case 200..999: return number(num/100)+" cents "+number(num%100);
   case 1000..1999: return "mil "+number(num%1000);
   case 2000..999999: return number(num/1000)+" mil "+number(num%1000);

   case 1000000..1999999: 
     return "un mil.lio "+number(num%1000000);

   case 2000000..999999999: 
     return number(num/1000000)+" mil.lions "+number(num%1000000);

   default:
    return "moltisim";
  }
}

string day(int num)
{
  return ({ "Diumenge","Dilluns","Dimarts","Dimecres",
	    "Dijous","Divendres","Disabte" })[ num - 1 ];
}

array aliases()
{
  return ({ "es_CA", "ca", "cat", "catala" });
}

