/* Bugs by: Mak */
/*
 * name = "Polish language plugin ";
 * doc = "Handles the conversion of numbers and dates to polish. You have to restart the server for updates to take effect.";
 *
 * Piotr Klaban <makler@man.torun.pl>
 *
 * Character encoding: ISO-8859-2
 */

string cvs_version = "$Id: polish.pike,v 1.1 1999/01/13 03:44:03 grubba Exp $";
string month(int num)
{
  return ({ "Styczeñ", "Luty", "Marzec", "Kwiecieñ", "Maj",
	    "Czerwiec", "Lipiec", "Sierpieñ", "Wrzesieñ", "Pa¼dziernik",
	    "Listopad", "Grudzieñ" })[ num - 1 ];
}

string ordered(int i)
{
  switch(i)
  {
   case 0:
    return "b³±d";
   default:
    return i+".";
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
      return "dzi¶, "+ ctime(timestamp)[11..15];
  
    if(t1["yday"]+1 == t2["yday"] && t1["year"] == t2["year"])
      return "wczoraj, "+ ctime(timestamp)[11..15];
  
    if(t1["yday"]-1 == t2["yday"] && t1["year"] == t2["year"])
      return "jutro, "+ ctime(timestamp)[11..15];
  
    if(t1["year"] != t2["year"])
      return (month(t1["mon"]+1) + " " + (t1["year"]+1900));
    return (ordered(t1["mday"]) + " " + month(t1["mon"]+1));
  }
  if(m["full"])
    return ctime(timestamp)[11..15]+", "+
	   ordered(t1["mday"]) + " " + 
           month(t1["mon"]+1) + " " +
           (t2["year"]+1900);
  if(m["date"])
    return (ordered(t1["mday"]) + " " + month(t1["mon"]+1) + " " +
       (t2["year"]+1900));
  if(m["time"])
    return ctime(timestamp)[11..15];
}


string number(int num)
{
  int tmp;

  if(num<0)
    return "minus "+number(-num);
  switch(num)
  {
   case 0:  return "";
   case 1:  return "jeden";
   case 2:  return "dwa";
   case 3:  return "trzy";
   case 4:  return "cztery";
   case 5:  return "piêæ";
   case 6:  return "sze¶æ";
   case 7:  return "siedem";
   case 8:  return "osiem";
   case 9:  return "dziewiêæ";
   case 10: return "dziesiêæ";
   case 11: return "jedena¶cie";
   case 12: return "dwana¶cie";
   case 13: return "trzyna¶cie";
   case 14: return "czterna¶cie";
   case 15: return "piêtna¶cie";
   case 16: return "szesna¶cie";
   case 17: return "siedemna¶cie";
   case 18: return "osiemna¶cie";
   case 19: return "dziewiêtna¶cie";
   case 20: return "dwadzie¶cia";
   case 30: return "trzydzie¶ci";
   case 40: return "czterdzie¶ci";
   case 60: case 70: case 80: case 90:
     return number(num/10)+"dziesi±t";
   case 21..29: case 31..39: 
   case 51..59: case 61..69: case 71..79: 
   case 81..89: case 91..99: case 41..49: 
     return number((num/10)*10)+" "+number(num%10);
   case 100: return "sto";
   case 200: return "dwie¶cie";
   case 300: return "trzysta";
   case 400: return "czterysta";
   case 500: case 600: case 700: case 800: case 900:
     return number(num/100)+"set";
   case 101..199: case 201..299: case 301..399: case 401..499:
   case 501..599: case 601..699: case 701..799: case 801..899:
   case 901..999:
     return number(num-(num%100))+" "+number(num%100);
   case 1000..1999: return "tisi±c "+number(num%1000);
   case 2000..4999: return number(num/1000)+" tisi±ce "+number(num%1000);
   case 5000..999999: return number(num/1000)+" tisiêcy "+number(num%1000);
   case 1000001..1999999:
     return number(num/1000000)+" million "+number(num%1000000);
   case 2000000..999999999:
     tmp = (num/1000000) - ((num/10000000)*10000000);
     switch (tmp)
     {
	case 2: case 3: case 4:
	     return number(num/1000000)+" milliony "+number(num%1000000);
	default:
	     return number(num/1000000)+" millionów "+number(num%1000000);
     }
   default:
    perror("foo\n"+ num +"\n");
    return "wiele";
  }
}

string day(int num)
{
  return ({ "Niedziela","Poniedzia³ek","Wtorek","¦roda",
	    "Czwartek","Pi±tek","Sobota" })[ num - 1 ];
}

array aliases()
{
  return ({ "pl", "po", "pol", "polish" });
}



