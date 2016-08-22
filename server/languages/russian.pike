/*  -*- coding: koi8-r -*- */
#charset koi8-r
constant required_charset = "koi8-r";
/* Bugs by: Per, jhs */
/*
 * name = "Russian language plugin ";
 * doc = "Handles the conversion of numbers and dates to Russian. You have to restart the server for updates to take effect.";
 */

inherit "abstract.pike";

constant cvs_version = "$Id$";
constant _id = ({ "ru", "russian", "русский" });
constant _aliases = ({ "ru", "rus", "russian", "русский" });

constant months = ({
  "январь", "февраль", "март", "апрель", "май",
  "июнь", "июль", "август", "сентябрь", "октябрь",
  "ноябрь", "декабрь" });

constant days = ({
  "воскресенье","понедельник","вторник","среда", "четверк",
  "пятница", "суббота" });

constant implode_conjunction = "и";

string ordered(int i)
{
  return (string) i + "-е";
}

string numbered_month(int m)
{
  string month = months[m-1];
  switch(month[-1]) {
  case 'ь':
  case 'й':
    return month[..sizeof(month)-2] + "я";
  case 'т':
    return month + "а";
  }
  error("Invalid month: %O\n", month);
}

string short_month(int m)
{
  return numbered_month(m)[..2];
}

string date(int timestamp, mapping m)
{
  mapping t1=localtime(timestamp);
  mapping t2=localtime(time(0));

  if(!m) m=([]);

  if(!(m["full"] || m["date"] || m["time"]))
  {
    if(t1["yday"] == t2["yday"] && t1["year"] == t2["year"])
      return "сегодня, в " + ctime(timestamp)[11..15];

    if(t1["yday"] == t2["yday"]-1 && t1["year"] == t2["year"])
      return "вчера, v " + ctime(timestamp)[11..15];

    if(t1["yday"] == t2["yday"]+1 && t1["year"] == t2["year"])
      return "завтра, okolo "  + ctime(timestamp)[11..15];

    if(t1["year"] != t2["year"])
      return month(t1["mon"]+1) + " " + (t1["year"]+1900);
    else
      return "" + t1["mday"] + " " + numbered_month(t1["mon"]+1);
  }
  if(m["full"])
    return sprintf("%s, %s %s %d",
		   ctime(timestamp)[11..15],
		   ordered(t1["mday"]),
		   numbered_month(t1["mon"]+1), t1["year"]+1900);
  if(m["date"])
    return sprintf("%s %s %d", ordered(t1["mday"]),
		   numbered_month(t1["mon"]+1), t1["year"]+1900);

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
   case 1:  return ([ "m" : "один",
		      "f" : "одна",
		      "n" : "одно" ])[gender];
   case 2:  return ("f" == gender) ? "двe" : "два";
   case 3:  return "три";
   case 4:  return "четыре";
   case 5:  return "пять";
   case 6:  return "шесть";
   case 7:  return "семь";
   case 8:  return "восемь";
   case 9:  return "дебять";
   default:
     error("russian->_number_1: internal error.\n");
  }
}

string _number_10(int num)
{
  switch(num)
  {
   case 2: return "двадцать";
   case 3: return "тридцать";
   case 4: return "сопок";
   case 5: return "пятьдесят";
   case 6: return "шестьдесят";
   case 7: return "семьдесят";
   case 8: return "восемьдесят";
   case 9: return "девяносто";
   default:
     error("russian->_number_10: internal error.\n");
  }
}

string _number_100(int num)
{
  switch(num)
  {
   case 1: return "сто";
   case 2: return "двести";
   case 3: case 4:
     return _number_1(num, "m")+"ста";
   case 5: case 6: case 7: case 8: case 9:
     return _number_1(num, "m")+"сот";
   default:
     error("russian->_number_10: internal error.\n");
  }
}

string _number(int num, string gender);

string _number_1000(int num)
{
  if (num == 1)
    return "тысяча";

  string pre = _number(num, "f");
  switch(num % 10)
  {
   case 1: return pre + " тысяча";
   case 2: case 3: case 4:
     return pre + " тысячи";
   default:
     return pre + " тысяч";
  }
}

string _number_1000000(int num)
{
  if (num == 1)
    return "миллион";

  string pre = _number(num, "m");
  switch(num % 10)
  {
   case 1: return pre + " миллион";
   case 2: case 3: case 4:
     return pre + " миллиона";
   default:
     return pre + " миллионов";
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
    return ([ 10: "десять",
	      11: "одиннадцать",
	      12: "двенадцать",
	      13: "тринадцать",
	      14: "четырнадцать",
	      15: "пятнадцать",
	      16: "шестнадцать",
	      17: "семнадцать",
	      18: "восемнадцать",
	      19: "девятнадцать" ])[num];
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
    return("минус"+_number(-num, gender));
  } if (num) {
    return(_number(num, gender));
  } else {
    return("ноль");
  }
}


protected void create()
{
  roxen.dump( __FILE__ );
}
