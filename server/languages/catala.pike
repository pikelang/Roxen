/* Bugs by: Per */
string cvs_version = "$Id: catala.pike,v 1.3 1997/01/07 03:35:08 neotron Exp $";
/* Trans by: jordi@lleida.net 
 * This version revised by a catalan linguist. 
 */


inline string month(int num)
{
  return ({ "gener", "febrer", "març", "abril", "maig",
            "juny", "juliol", "agost", "setembre", "octubre",
            "novembre", "desembre" })[ num - 1 ];
}

string ordered(int i)
{
  switch(i)
  {
    case 1: return "1r";
    case 2: return "2n";
    case 3: return "3r";
    case 4: return "4t";
    default: 
            return i+"&egrave;";
  }
}

string d_apostrof(int i)
{
  switch(i)
  {
  case 4:
  case 8:
  case 10:
        return " d'";
  default:
        return " de ";
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
    return ( t1["mday"] + d_apostrof(t1["mon"]+1) + month(t1["mon"]+1) );
  }

  if(m["full"])
    return ctime(timestamp)[11..15]+ " del " +
           (t1["mday"]) + d_apostrof(t1["mon"]+1) + month(t1["mon"]+1) 
           + " de l'any " + (t2["year"]+1900);

  if(m["date"])
    return (t1["mday"]) + d_apostrof(t1["mon"]+1) + month(t1["mon"]+1)
           + " de " + (t2["year"]+1900);

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
   case 5:  return "cinc";
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
   case 17: return "disset";
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
     return number((num/10)*10)+ "-" +number(num%10);
   case 100..199: return "cent "+number(num%100);
   case 200..999: return number(num/100)+"-cents "+number(num%100);
   case 1000..1999: return "mil "+number(num%1000);
   case 2000..999999: return number(num/1000)+" mil "+number(num%1000);

   case 1000000..1999999: 
     return "un milio "+number(num%1000000);

   case 2000000..999999999: 
     return number(num/1000000)+" milions "+number(num%1000000);

   default:
    return "molt&iacute;ssim";
  }
}

string day(int num)
{
  return ({ "diumenge","dilluns","dimarts","dimecres",
            "dijous","divendres","dissabte" })[ num - 1 ];
}

array aliases()
{
  return ({ "ca", "cat", "catala", "es_CA" });
}
