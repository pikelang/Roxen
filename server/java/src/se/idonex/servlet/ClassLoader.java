package se.idonex.servlet;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.net.URL;
import java.net.MalformedURLException;

class ClassLoader extends java.lang.ClassLoader
{
  File dir;

  protected Class findClass(String name) throws ClassNotFoundException {
    File f = new File(dir, name.replace('.', File.separatorChar)+".class");
    if(!f.isFile())
      throw new ClassNotFoundException(name);
    byte[] b = new byte[(int)f.length()];
    try {
      return defineClass(name, b, 0, new FileInputStream(f).read(b));
    } catch(IOException ex) {
      throw new ClassNotFoundException(name);
    }
  }

  protected URL findResource(String name)
  {
    File f = new File(dir, name);
    if(!f.isFile())
      return null;
    try {
      return f.toURL();
    } catch(MalformedURLException e) {
      return null;
    }
  }

  public ClassLoader(String dir)
  {
    this.dir = new File(dir);
  }

}
