package com.core.servlet;

import javax.servlet.ServletInputStream;
import java.io.IOException;

class HTTPInputStream extends ServletInputStream
{
  String data;
  int pos = 0;

  public int read() throws IOException
  {
    if(data != null)
      if(pos<data.length())
	return data.charAt(pos++);
      else
	data = null;
    return -1;
  }

  HTTPInputStream(String data)
  {
    this.data = data;
  }
}
