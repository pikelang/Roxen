package se.idonex.servlet;

import javax.servlet.ServletOutputStream;
import java.io.IOException;

class HTTPOutputStream extends ServletOutputStream
{
  final int id;

  public native void close() throws IOException;
  public native void write(int b) throws IOException;
  public native void write(byte b[], int offs, int len) throws IOException;
  private native void forgetfd();
  protected void finalize() throws Throwable
  {
    forgetfd();
    super.finalize();
  }

  HTTPOutputStream(int id)
  {
    this.id = id;
  }
}
