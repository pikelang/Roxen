/* name="Japanese (Was Kanji) language plugin"; */
/* doc="Adds support for japanese";
 * Bugs by Marcus Comstedt <marcus@idonex.se> */

/* Tip: put <header name="Content-type" value="text/html; charset=iso-2022-jp">
 *      on the page since Netscape caches charsets.
 */

string cvs_version = "$Id: japanese.pike,v 1.8 1998/03/11 19:42:34 neotron Exp $";
string month(int num);

/* The following function is correct for -10**12 < n < 10**12 (I think...) */

string mknumber(int n)
{
  array(string) digit;
  string r;
  digit = ({ "", "0l", "Fs", ";0", ";M", "8^", "O;", "<7", "H,", "6e" }); 

  if(!n) return "%<%m";

  if(n<0) return "Ii"+mknumber(-n);

  if(n>=200000000)
    return mknumber(n/100000000)+"2/"+mknumber(n%100000000);
  else if(n>100000000)
    return "2/"+mknumber(n%100000000);
  else if(n==100000000)
    return "2/";

  if(n>=20000)
    return mknumber(n/10000)+"K|"+mknumber(n%10000);
  else if(n>10000)
    return "K|"+mknumber(n%10000);
  else if(n==10000)
    return "K|";

  r = "";

  if(n>=2000)
    r += digit[n/1000]+"@i";
  else if(n>=1000)
    r += "@i";

  n %= 1000;
  if(n>=200)
    r += digit[n/100]+"I4";
  else if(n>=100)
    r += "I4";

  n %= 100;
  if(n>=20)
    r += digit[n/10]+"==";
  else if(n>=10)
    r += "==";

  return r + digit[n%10];
}


string ordered(int i)
{
  return "\033$B"+mknumber(i)+"HV\033(B";
}

string date(int timestamp, mapping|void m)
{
  mapping t1=localtime(timestamp);
  mapping t2=localtime(time(0));

  if(!m) m=([]);

  if(!(m["full"] || m["date"] || m["time"]))
  {
    if(t1["yday"] == t2["yday"] && t1["year"] == t2["year"])
      return "\033$B:#F|\033(B";
  
    if(t1["yday"]+1 == t2["yday"] && t1["year"] == t2["year"])
      return "\033$B:rF|\033(B";
  
    if(t1["yday"]-1 == t2["yday"] && t1["year"] == t2["year"])
      return "\033$BL@F|\033(B";
  
    if(t1["year"] != t2["year"])
      return "\033$B"+mknumber(t1["year"]+1900)+"G/"+mknumber(t1["mon"]+1)+
         "7n"+mknumber(t1["mday"])+"F|\033(B";
    return "\033$B"+mknumber(t1["mon"]+1)+"7n"+mknumber(t1["mday"])+"F|\033(B";
  }
  if(m["full"])
    return ctime(timestamp)[11..15]+
      "\033$B"+mknumber(t1["year"]+1900)+"G/"+mknumber(t1["mon"]+1)+
       "7n"+mknumber(t1["mday"])+"F|\033(B";
  if(m["date"])
    return "\033$B"+mknumber(t1["year"]+1900)+"G/"+mknumber(t1["mon"]+1)+
       "7n"+mknumber(t1["mday"])+"F|\033(B";
  if(m["time"])
    return ctime(timestamp)[11..15];
}


string number(int num)
{
  return "\033$B"+mknumber(num)+"\033(B";
}

string month(int num)
{
  return "\033$B"+mknumber(num)+"7n\033(B";
}

string day(int num)
{
  return "\033$B"+({ "F|", "7n", "2P", "?e", "LZ", "6b", "EZ" })[ num - 1 ]+
	    "MKF|\033(B";
}

array aliases()
{
  return ({ "kj", "kanji", /* For backward compatibility */
	    "jp", "japanese", "nihongo" /* To keep Peter Evans happy */});
}

