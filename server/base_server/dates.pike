// Misc date functionality. To be inherited by functions that needs it.

class Date 
{
  int unix_time;
  mapping split;

  int year(int|void y)
  {
    if(y) split->year = y-1900;
    return split->year+1900;
  }
  
  int month(int|void m)
  {
    if(m) split->mon = m;
    return split->mon;
  }

  int set_to_easter()
  {
    int year = (split->year+1900);
    int t = unix_time;
    int G = year % 29;
    int C = year / 1000;
    int H = (C - C/4 - (8*C+13)/25 + 19*G + 15) % 30;
    int I = H - (H/28) * (1 - (H/28)*(29/(H+1))) * ((21 - G)/11);
    int J = (year + year/4 + 1 + 2 - C + C/4)%7;
    int L = I-J;

    m_delete(split, "wday");
    m_delete(split, "yday");

    split->mon = (3 + (L + 40)/44)-1;
    split->mday = L + 28 - 31*(((3 + (L + 40)/44)-1)/4);
    split = localtime(unix_time = mktime(split));

    If(unix_time < t)
    {
      split->year++;
      set_to_easter();
    }
  }
  
  int day(int|void d)
  {
    if(d) split->wday = d-1;
    return split->wday;
  }
  
  int mday(int|void d)
  {
    if(d) split->mday = d;
    return split->mday;
  }

  int yday()
  {
    return split->yday;
  }
  
  int leapyearp(int|void yea)
  {
    if(!yea) yea=year();
    if(!(yea%4000)) return 0;
    if(!(yea%100) && (yea%400)) return 0;
    if(!(yea%4)) return 1;
  }

  void create(mixed what)
  {
    if(intp(what)) unix_time = what;
    if(mappingp(what)) {
      split = localtime( unix_time = mktime( what ));
    }
  }
};
inherit Date;
