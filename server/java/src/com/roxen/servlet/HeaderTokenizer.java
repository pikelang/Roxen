package com.roxen.servlet;

class HeaderTokenizer
{
  String header;
  int pos, len;

  protected final void skipComment()
  {
    int pc=0;
    while(pos<len) {
      switch(header.charAt(pos)) {
       case '(': pc++; break;
       case ')': if(--pc == 0) return; break;
       case '\\': if(pos+1<len) pos++; break;
      }
      pos++;
    }
  }
  
  protected final void skipWS()
  {
    for(;;) {
      while(pos<len && header.charAt(pos)<=' ')
	pos++;
      if(pos<len && header.charAt(pos)=='(')
	skipComment();
      else
	break;
    }
  }
  
  public boolean lookingAt(char c)
  {
    skipWS();
    return pos<len && header.charAt(pos)==c;
  }
  
  public void discard(char c)
  {
    if(!lookingAt(c))
      throw new IllegalArgumentException ("header: "+header);
    pos++;
  }
  
  protected static final boolean badTokenChar(char c)
  {
    return c<=32 || c==127 || c=='(' || c==')' || c=='[' || c==']' ||
      c=='"' || c==',' || c=='\\' || c=='/' || c=='{' || c=='}' ||
      (c>=':' && c<='@');
  }

  public String getToken()
  {
    skipWS();
    int p0=pos;
    while(pos<len && !badTokenChar(header.charAt(pos)))
      pos++;
    if(pos==p0)
      throw new IllegalArgumentException ("header: "+header);
    return header.substring(p0, pos).toLowerCase();
  }
  
  public String getValue()
  {
    if(!lookingAt('"'))
      return getToken();
    int p0=++pos;
    while(pos<len && header.charAt(pos)!='"')
      if(header.charAt(pos)=='\\')
	pos+=2;
      else
	pos++;
    if(pos>=len)
      throw new IllegalArgumentException ("header: "+header);
    String v = header.substring(p0, pos++);
    for(p0=0; (p0=v.indexOf('\\', p0))>=0; p0++)
      v = v.substring(0, p0)+v.substring(p0+1);
    return v;
  }
  
  public boolean more()
  {
    skipWS();
    return pos<len;
  }
  
  public HeaderTokenizer(String h)
  {
    header = h;
    pos = 0;
    len = h.length();
  }
}

