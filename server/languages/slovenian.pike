/* Slovenian language support for Roxen 
   Author: Iztok Umek 2. 7. 1997
   E-mail: iztok.umek@snet.fri.uni-lj.si
   You can do anything you want with this code.
   Please consult me before upgrading slovenian.pike.
*/

string cvs_version = "$Id: slovenian.pike,v 1.1 1997/07/09 15:43:32 grubba Exp $";
inline string month(int num)
{
  return ({ "Januar", "Februar", "Marec", "April", "Maj",
	    "Junij", "Julij", "Avgust", "September", "Oktober",
	    "November", "December" })[ num - 1 ];
}

string number(int num)
{
  if(num<0)
    return "minus "+number(-num);
  switch(num)
  {
   case 0:  return "";
   case 1:  return "ena";
   case 2:  return "dva";
   case 3:  return "tri";
   case 4:  return "stiri";
   case 5:  return "pet";
   case 6:  return "sest";
   case 7:  return "sedem";
   case 8:  return "osem";
   case 9:  return "devet";
   case 10: return "deset";
   case 11..19: return number(num%10)+"najst";
   case 20: return "dvajset";
   case 30: case 40: case 50: case 60: case 70: case 80: case 90:
     return number(num/10)+"deset";
   case 21..29: case 31..39: case 41..49: case 51..59: case 61..69:
   case 71..79: case 81..89: case 91..99:
     return number(num%10)+"in"+number((num/10)*10);
   case 100: return "sto";
   case 101..199: return "sto "+number(num%100);
   case 200: return "dvesto";
   case 201..299: return "dvesto "+number(num%100);
   case 300..999: return number(num/100)+"sto"+(num%100?(" "+number(num%100)):"");
   case 1000..1999: return "tisoc"+(num%1000?(" "+number(num%1000)):"");
   case 2000..999999: return number(num/1000)+"tisoc"+(num%1000?(" "+number(num%1000)):"");
   case 1000000: return("milion");
   case 1000001..1999999:
     return "milion"+(num%1000000?(" "+number(num%1000000)):"");
   case 2000000..2999999: 
     return number(num/1000000)+" miliona"+(num%1000000?(" "+number(num%1000000)):"");
   case 3000000..4999999:
     return number(num/1000000)+" milione"+(num%1000000?(" "+number(num%1000000)):"");
   case 5000000..999999999:
     return number(num/1000000)+" milionov"+(num%1000000?(" "+number(num%1000000)):"");
   default:
     if ( ((num%10000000)/1000000)==1 ) return number(num/1000000)+" milion "+number(num%1000000);
   return "veliko";
  }
}

mapping(int:string) small_orders = ([ 1: "prvi", 2: "drugi", 3: "tretji",
				      4: "cetrti", 7: "sedmi", 8: "osmi" ]);

string ordered(int i)
{
  int rest = i%100;
  int base = i-rest;
  if (!i) {
    return("napacen");
  }
  if ((!rest) && (base%1000)) {
    return number(i)+"ti";
  }
  if (small_orders[rest]) {
    return (base ? (number(base)+" ") : "")+small_orders[rest];
  } else
    return number(i)+"i";
}


string date(int timestamp, mapping|void m)
{
  mapping t1=localtime(timestamp);
  mapping t2=localtime(time(0));

  if(!m) m=([]);

  if(!(m["full"] || m["date"] || m["time"]))
  {
    if(t1["yday"] == t2["yday"] && t1["year"] == t2["year"])
      return "danes, "+ ctime(timestamp)[11..15];
  
    if(t1["yday"]+1 == t2["yday"] && t1["year"] == t2["year"])
      return "vceraj, "+ ctime(timestamp)[11..15];
  
    if(t1["yday"]-1 == t2["yday"] && t1["year"] == t2["year"])
      return "danes, "+ ctime(timestamp)[11..15];
  
    if(t1["year"] != t2["year"])
      return (month(t1["mon"]+1) + " " + (t1["year"]+1900));
    return (month(t1["mon"]+1) + " " + ordered(t1["mday"]));
  }
  if(m["full"])
    return ctime(timestamp)[11..15]+", "+
           ordered(t1["mday"]) + " "
           + month(t1["mon"]+1) + " " +(t1["year"]+1900) + ".";
  if(m["date"])
    return ordered(t1["mday"]) + " " + month(t1["mon"]+1)
      + " " + (t1["year"]+1900) + ".";
  if(m["time"])
    return ctime(timestamp)[11..15];
}



string day(int num)
{
  return ({ "Nedelja","Ponedeljek","Torek","Sreda",
	    "Cetrtek","Petek","Sobota" })[ num - 1 ];
}

array aliases()
{
  return ({ "si", "svn", "slovenian" });
}
