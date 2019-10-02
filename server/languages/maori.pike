/* Maaori (New Zealand) */
/* any bugs in this file were inserted by Jason Rumney <jasonr@pec.co.nz> */
/*
 * name = "Maaori (New Zealand) language plugin ";
 * doc = "Handles the conversion of numbers and dates to Maaori. You have "
"to restart the server for updates to take effect. Translation by Jason "
"Rumney (jasonr@pec.co.nz)";
 */

inherit "abstract.pike";

constant cvs_version = "$Id$";
constant _id = ({ "mi", "maori", "" });
constant _aliases = ({ "mi", "maori", "maaori" });

constant months = ({ 
  "Haanuere", "Pepuere", "Maehe", "Aaperira", "Mei",
  "Hune", "Huurae", "Aakuhata", "Hepetema", "Oketopa",
  "Nowema", "Tiihema" });


constant days = ({
  "Raatapu","Mane","Tuurei","Wenerei",
  "Taaite","Paraire","Haatarei" });

string number( int i ) ;

string ordered(int i)
     {
	return "tua" + number(i) ;
     }

string date(int timestamp, mapping|void m)
     {
	mapping t1=localtime(timestamp) ;
	mapping t2=localtime(time(0));

	if (!m) m=([]);

	if (!(m["full"] || m["date"] || m["time"]))
	  {
	     if(t1["year"] != t2["year"])
	       return (month(t1["mon"]+1) + " " + (t1["year"]+1900));
	     return (month(t1["mon"]+1) + " " + ordered(t1["mday"]));
	  }
	if(m["full"])
	  return ctime(timestamp)[11..15]+", "+
	month(t1["mon"]+1) + " te "
	+ ordered(t1["mday"]) + ", " +(t1["year"]+1900);
	if(m["date"])
	  return month(t1["mon"]+1) + " te "  + ordered(t1["mday"])
	+ " o te tau " +(t1["year"]+1900);
	if(m["time"])
	  return ctime(timestamp)[11..15];
     }


string number(int num)
{
  if(num<0)
    return number(-num)+" tango";
  switch(num)
  {
   case 0:  return "kore";
   case 1:  return "tahi";
   case 2:  return "rua";
   case 3:  return "toru";
   case 4:  return "whaa";
   case 5:  return "rima";
   case 6:  return "ono";
   case 7:  return "whitu";
   case 8:  return "waru";
   case 9:  return "iwa";
   case 10: return "tekau";
   case 11..19: return "tekau ma "+number(num-10) ; 
   case 20..99: return number(num/10)+" "+number(10+num%10) ;
   case 100: return "rau" ;
   case 101..199: return "rau ma "+number(num-100);
   case 200..999: return number(num/100)+" "+number(100+num%100) ;
   case 1000: return "mano" ;
   case 1001..1999: return "mano ma "+ number(num-1000);
   case 2000..999999: return number(num/1000)+" "+number(1000+num%1000); 
   default:
    return "tini ("+num+")";
  }
}

protected void create()
{
  roxen.dump( __FILE__ );
}
