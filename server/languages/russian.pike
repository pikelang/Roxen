#charset iso-8859-5
constant required_charset = "iso-8859-5";
/* Bugs by: Per, jhs */
/*
 * name = "Russian language plugin ";
 * doc = "Handles the conversion of numbers and dates to Russian. You have to restart the server for updates to take effect.";
 */

inherit "abstract.pike";

constant cvs_version = "$Id: russian.pike,v 1.10 2008/08/15 12:33:54 mast Exp $";
constant _id = ({ "ru", "russian", ".LŽÀŽãŽáŽáŽÚŽØŽÙ" });
constant _aliases = ({ "ru", "rus", "russian", "ŽÒŽÕŽÓŽÓŽËŽÉŽÊ" });

#define error(x) throw( ({ x, backtrace() }) )

constant months = ({
  "ŽÑŽÎŽ×ŽÁŽÒŽØ", "ŽÆŽÅŽÂŽÒŽÁŽÌŽØ", "ŽÍŽÁŽÒŽÔ", "ŽÁŽÐŽÒŽÅŽÌŽØ", "ŽÍŽÁŽÊ",
  "ŽÉŽÀŽÎŽØ", "ŽÉŽÀŽÌŽØ", "ŽÁŽ×ŽÇŽÕŽÓŽÔŽØ", "ŽÓŽÅŽÎŽÔŽÑŽÂŽÒŽØ", "ŽÏŽËŽÔŽÑŽÂŽØ",
  "ŽÎŽÏŽÑŽÂŽÒŽØ", "ŽÄŽÅŽËŽÁŽÂŽÒŽØ" });

constant days = ({
  "Ž×ŽÏŽÓŽËŽÒŽÅŽÓŽÅŽÎŽØŽÅ","ŽÐŽÏŽÎŽÅŽÄŽÅŽÌŽØŽÎŽÉŽË","Ž×ŽÔŽÏŽÒŽÎŽÉŽË","ŽÓŽÒŽÅŽÄŽÁ", "ŽÞŽÅŽÔŽ×ŽÅŽÒŽË",
  "ŽÐŽÑŽÔŽÎŽÉŽÃŽÁ", "ŽÓŽÕŽÂŽÂŽÏŽÔŽÁ" });

string ordered(int i)
{
  return (string) i + "-ŽÅ";
}

string date(int timestamp, mapping m)
{
  mapping t1=localtime(timestamp);
  mapping t2=localtime(time(0));

  if(!m) m=([]);

  if(!(m["full"] || m["date"] || m["time"]))
  {
    if(t1["yday"] == t2["yday"] && t1["year"] == t2["year"])
      return "ŽÓŽÅŽÇŽÏŽÄŽÎŽÑ, Ž× " + ctime(timestamp)[11..15];

    if(t1["yday"] == t2["yday"]-1 && t1["year"] == t2["year"])
      return "Ž×ŽÞŽÅŽÒŽÁ, v " + ctime(timestamp)[11..15];

    if(t1["yday"] == t2["yday"]+1 && t1["year"] == t2["year"])
      return "ŽÚŽÁŽ×ŽÔŽÒŽÁ, okolo "  + ctime(timestamp)[11..15];

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
   case 1:  return ([ "m" : "ŽÏŽÄŽÉŽÎ",
		      "f" : "ŽÏŽÄŽÎŽÁ",
		      "n" : "ŽÏŽÄŽÎŽÏ" ])[gender];
   case 2:  return ("f" == gender) ? "ŽÄŽ×e" : "ŽÄŽ×ŽÁ";
   case 3:  return "ŽÔŽÒŽÉ";
   case 4:  return "ŽÞŽÅŽÔŽÙŽÒŽÅ";
   case 5:  return "ŽÐŽÑŽÔŽØ";
   case 6:  return "ŽÛŽÅŽÓŽÔŽØ";
   case 7:  return "ŽÓŽÅŽÍŽØ";
   case 8:  return "Ž×ŽÏŽÓŽÅŽÍŽØ";
   case 9:  return "ŽÄŽÅŽÂŽÑŽÔŽØ";
   default:
     error("russian->_number_1: internal error.\n");
  }
}

string _number_10(int num)
{
  switch(num)
  {
   case 2: return "ŽÄŽ×ŽÁŽÄŽÃŽÁŽÔŽØ";
   case 3: return "ŽÔŽÒŽÉŽÄŽÃŽÁŽÔŽØ";
   case 4: return "ŽÓŽÏŽÐŽÏŽË";
   case 5: return "ŽÐŽÑŽÔŽØŽÄŽÅŽÓŽÑŽÔ";
   case 6: return "ŽÛŽÅŽÓŽÔŽØŽÄŽÅŽÓŽÑŽÔ";
   case 7: return "ŽÓŽÅŽÍŽØŽÄŽÅŽÓŽÑŽÔ";
   case 8: return "Ž×ŽÏŽÓŽÅŽÍŽØŽÄŽÅŽÓŽÑŽÔ";
   case 9: return "ŽÄŽÅŽ×ŽÑŽÎŽÏŽÓŽÔŽÏ";
   default:
     error("russian->_number_10: internal error.\n");
  }
}

string _number_100(int num)
{
  switch(num)
  {
   case 1: return "ŽÓŽÔŽÏ";
   case 2: return "ŽÄŽ×ŽÅŽÓŽÔŽÉ";
   case 3: case 4:
     return _number_1(num, "m")+"ŽÓŽÔŽÁ";
   case 5: case 6: case 7: case 8: case 9:
     return _number_1(num, "m")+"ŽÓŽÏŽÔ";
   default:
     error("russian->_number_10: internal error.\n");
  }
}

string _number(int num, string gender);

string _number_1000(int num)
{
  if (num == 1)
    return "ŽÔŽÙŽÓŽÑŽÞŽÁ";

  string pre = _number(num, "f");
  switch(num % 10)
  {
   case 1: return pre + " ŽÔŽÙŽÓŽÑŽÞŽÁ";
   case 2: case 3: case 4:
     return pre + " ŽÔŽÙŽÓŽÑŽÞŽÉ";
   default:
     return pre + " ŽÔŽÙŽÓŽÑŽÞ";
  }
}

string _number_1000000(int num)
{
  if (num == 1)
    return "ŽÍŽÉŽÌŽÌŽÉŽÏŽÎ";

  string pre = _number(num, "m");
  switch(num % 10)
  {
   case 1: return pre + " ŽÍŽÉŽÌŽÌŽÉŽÏŽÎ";
   case 2: case 3: case 4:
     return pre + " ŽÍŽÉŽÌŽÌŽÉŽÏŽÎŽÁ";
   default:
     return pre + " ŽÍŽÉŽÌŽÌŽÉŽÏŽÎŽÏŽ×";
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
    return ([ 10: "ŽÄŽÅŽÓŽÑŽÔŽØ",
	      11: "ŽÏŽÄŽÉŽÎŽÎŽÁŽÄŽÃŽÁŽÔŽØ",
	      12: "ŽÄŽ×ŽÅŽÎŽÁŽÄŽÃŽÁŽÔŽØ",
	      13: "ŽÔŽÒŽÉŽÎŽÁŽÄŽÃŽÁŽÔŽØ",
	      14: "ŽÞŽÅŽÔŽÙŽÒŽÎŽÁŽÄŽÃŽÁŽÔŽØ",
	      15: "ŽÐŽÑŽÔŽÎŽÁŽÄŽÃŽÁŽÔŽØ",
	      16: "ŽÛŽÅŽÓŽÔŽÎŽÁŽÄŽÃŽÁŽÔŽØ",
	      17: "ŽÓŽÅŽÍŽÎŽÁŽÄŽÃŽÁŽÔŽØ",
	      18: "Ž×ŽÏŽÓŽÅŽÍŽÎŽÁŽÄŽÃŽÁŽÔŽØ",
	      19: "ŽÄŽÅŽ×ŽÑŽÔŽÎŽÁŽÄŽÃŽÁŽÔŽØ" ])[num];
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
    return("ŽÍŽÉŽÎŽÕŽÓ"+_number(-num, gender));
  } if (num) {
    return(_number(num, gender));
  } else {
    return("ŽÎŽÏŽÌŽØ");
  }
}


protected void create()
{
  roxen.dump( __FILE__ );
}
