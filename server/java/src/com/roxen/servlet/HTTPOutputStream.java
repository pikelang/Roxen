package com.core.servlet;

import javax.servlet.ServletOutputStream;
import java.io.IOException;

class HTTPOutputStream extends ServletOutputStream
{
  final int id;

  private native void low_close() throws IOException;
  private native void low_write(byte b[], int offs, int len) throws IOException;
  private native void forgetfd();
  protected void finalize() throws Throwable
  {
    forgetfd();
    super.finalize();
  }

  protected boolean isCommitted = false;
  protected int bufused = 0, bufsize = 1024;
  protected byte[] buf = new byte[bufsize];

  protected ServletResponse response;

  void setResponse(ServletResponse r)
  {
    response = r;
  }

  public synchronized void write(int b) throws IOException
  {
    buf[bufused++]=(byte)b;
    if(bufused >= bufsize)
      flush();
  }

  public synchronized void write(byte b[], int offs, int len) throws IOException
  {
    if(len <= 0)
      return;
    if(len >= bufsize) {
      flush();
      low_write(b, offs, len);
    } else if(bufused+len > bufsize) {
      int first = bufsize-bufused;
      if(first>0) {
	System.arraycopy(b, offs, buf, bufused, first);
	bufused += first;
      } else
	first = 0;
      flush();
      System.arraycopy(b, offs+first, buf, 0, bufused = len-first);
      if(bufused >= bufsize)
	flush();
    } else {
      System.arraycopy(b, offs, buf, bufused, len);
      if((bufused += len) >= bufsize)
	flush();
    }
  }

  public synchronized void flush() throws IOException
  {
    int to_write = bufused;
    bufused = 0;
    if(!isCommitted) {
      isCommitted = true;
      byte[] oldbuf = buf;
      buf = new byte[(bufsize==0? 1:bufsize)];
      response.commitRequest(this);
      flush();
      buf = oldbuf;
    }
    if(to_write > 0)
      low_write(buf, 0, to_write);
    if(bufsize > 0 && buf.length>bufsize)
      buf = new byte[(bufsize==0? 1:bufsize)];
  }

  public synchronized void close() throws IOException
  {
    flush();
    low_close();
  }

  synchronized void setBufferSize(int size)
  {
    if(size<0)
      return;
    if(bufused==0) {
      buf = new byte[(bufsize==0? 1:bufsize)];      
      return;
    }
    if(size>bufsize) {
      byte[] newbuf = new byte[size];
      System.arraycopy(buf, 0, newbuf, 0, bufused);
      buf = newbuf;
    } else
      bufsize = size;
  }

  int getBufferSize()
  {
    return bufsize;
  }
  
  synchronized void reset()
  {
    if(isCommitted)
      throw new IllegalStateException();
    bufused = 0;
  }

  boolean isCommitted()
  {
    return isCommitted;
  }

  HTTPOutputStream(int id)
  {
    this.id = id;
  }
}
