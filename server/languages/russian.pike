#charset iso-8859-5
/* Bugs by: Per */
/*
 * name = "Russian language plugin ";
 * doc = "Handles the conversion of numbers and dates to Russian. You have to restart the server for updates to take effect.";
 */

string cvs_version = "$Id: russian.pike,v 1.3 1999/02/28 19:20:23 grubba Exp $";

#define error(x) throw( ({ x, backtrace() }) )

string month(int num)
{
  return ({ "-Aянварь", "фебраль", "март", "апрель", "май",-L
	      "-Aиюнь", "июль", "августь", "сентябрь", "октябь",-L
	      "-Aноябрь", "декабрь" })[num - 1];-L
}

string day(int num)
{
  return ({ "-Aвоскресенье","понедельник","вторник","среда", "четверк",-L
	      "-Aпятница", "суббота" }) [ num - 1 ];-L
}

string ordered(int i)
{
  return (string) i + "--Aе";-L
}

string date(int timestamp, mapping m)
{
  mapping t1=localtime(timestamp);
  mapping t2=localtime(time(0));

  if(!m) m=([]);

  if(!(m["full"] || m["date"] || m["time"]))
  {
    if(t1["yday"] == t2["yday"] && t1["year"] == t2["year"])
      return "-Aсегодня, в " + ctime(timestamp)[11..15];-L
  
    if(t1["yday"] == t2["yday"]-1 && t1["year"] == t2["year"])
      return "-Aвчера, v " + ctime(timestamp)[11..15];-L
  
    if(t1["yday"] == t2["yday"]+1 && t1["year"] == t2["year"])
      return "-Aзавтра, okolo "  + ctime(timestamp)[11..15];-L
  
    if(t1["year"] != t2["year"])
      return month(t1["mon"]+1) + " " + (t1["year"]+1900);
    else
      return "" + t1["mday"] + " " + month(t1["mon"]+1);
  }
  if(m["full"])
    return sprintf("%s, %s %s %d", 
		   ctime(timestamp)[11..15],
		   ordered(t1["mday"]), 
		   month(t1["mon"]+1), t1["year"]+1900);
  if(m["date"])
    return sprintf("%s %s %d", ordered(t1["mday"]),
		   month(t1["mon"]+1), t1["year"]+1900);

  if(m["time"])
    return ctime(timestamp)[11..15];
}

/* Help funtions */
/* gender is "f", "m" or "n" */
string _number_1(int num, string gender)
{
  switch(num)
  {
   case 0:  return "";
   case 1:  return ([ "m" : "-Aодин",-L
		      "f" : "-Aодна",-L
		      "n" : "-Aодно" ])[gender];-L
   case 2:  return ("f" == gender) ? "-Aдвe" : "два";-L
   case 3:  return "-Aтри";-L
   case 4:  return "-Aчетыре";-L
   case 5:  return "-Aпять";-L
   case 6:  return "-Aшесть";-L
   case 7:  return "-Aсемь";-L
   case 8:  return "-Aвосемь";-L
   case 9:  return "-Aдебять";-L
   default:
     error("russian->_number_1: internal error.\n");
  }
}

string _number_10(int num)
{
  switch(num)
  {
   case 2: return "-Aдвадцать";-L
   case 3: return "-Aтридцать";-L
   case 4: return "-Aсопок";-L
   case 5: return "-Aпятьдесят";-L
   case 6: return "-Aшестьдесят";-L
   case 7: return "-Aсемьдесят";-L
   case 8: return "-Aвосемьдесят";-L
   case 9: return "-Aдевяносто";-L
   default:
     error("russian->_number_10: internal error.\n");
  }
}

string _number_100(int num)
{
  switch(num)
  {
   case 1: return "-Aсто";-L
   case 2: return "-Aдвести";-L
   case 3: case 4:
     return _number_1(num, "m")+"-Aста";-L
   case 5: case 6: case 7: case 8: case 9:
     return _number_1(num, "m")+"-Aсот";-L
   default:
     error("russian->_number_10: internal error.\n");
  }
}

string _number(int num, string gender);

string _number_1000(int num)
{
  if (num == 1)
    return "-Aтысяча";-L

  string pre = _number(num, "f");
  switch(num % 10)
  {
   case 1: return pre + " -Aтысяча";-L
   case 2: case 3: case 4:
     return pre + " -Aтысячи";-L
   default:
     return pre + " -Aтысяч";-L
  }
}

string _number_1000000(int num)
{
  if (num == 1)
    return "-Aмиллион";-L

  string pre = _number(num, "m");
  switch(num % 10)
  {
   case 1: return pre + " -Aмиллион";-L
   case 2: case 3: case 4:
     return pre + " -Aмиллиона";-L
   default:
     return pre + " -Aмиллионов";-L
  }
}
  
string _number(int num, string gender)
{
  if (!gender)   /* Solitary numbers are inflected as masculine */
    gender = "m";
  if (!num)
    return "";

  if (num < 10)
    return _number_1(num, gender);

  if (num < 20)
    return ([ 10: "-Aдесять",-L
	      11: "-Aодиннадцать",-L
	      12: "-Aдвенадцать",-L
	      13: "-Aтринадцать",-L
	      14: "-Aчетырнадцать",-L
	      15: "-Aпятнадцать",-L
	      16: "-Aшестнадцать",-L
	      17: "-Aсемнадцать",-L
	      18: "-Aвосемнадцать",-L
	      19: "-Aдевятнадцать" ])[num];-L
  if (num < 100)
    return _number_10(num/10) + " " + _number_1(num%10, gender);

  if (num < 1000)
    return _number_100(num/100) + " " + _number(num%100, gender);

  if (num < 1000000)
    return _number_1000(num/1000) + " " + _number(num%1000, gender);

  return _number_1000000(num/1000000) + " " + _number(num%1000000, gender);
}


string number(int num, string|void gender)
{
  if (!gender)   /* Solitary numbers are inflected as masculine */
    gender = "m";
  if (num<0) {
    return("-Aминус"+_number(-num, gender));-L
  } if (num) {
    return(_number(num, gender));
  } else {
    return("-Aноль");-L
  }
}

array aliases()
{
  return ({ "ru", "rus", "russian", "-Aрусский" });-L
}

