package com.roxen.roxen;

import java.net.URL;
import java.net.URLClassLoader;
import java.net.MalformedURLException;

import java.io.File;
import java.io.IOException;
import java.io.FileNotFoundException;

import java.util.StringTokenizer;
import java.util.jar.JarFile;
import java.util.jar.Manifest;
import java.util.jar.Attributes;
import java.util.jar.Attributes.Name;

/**
 * @author <a href="mailto:tomp@uk.uu.net">Tom Palmer</a>
 */
public class RoxenClassLoader extends URLClassLoader {
  public RoxenClassLoader(URL [] urls) {
    super(urls);
  }

  /**
   * Adds a JAR file to the class path for which this ClassLoader handles.
   * It will also attempt to read the manifest of the JAR file and add the
   * entries specified under 'Class-Path' to the class path handled by this
   * ClassLoader.
   *
   * @param jarFileName Path pointing to the JAR file
   * @throw FileNotFoundException when the JAR file cannot be found
   * @throw IOException when there is a problem reading the JAR file
   */
  public void addJarFile(String jarFileName) throws FileNotFoundException, IOException {
    File jarFile = new File(jarFileName);
    JarFile jar = new JarFile(jarFile);
    Manifest manifest = jar.getManifest();

    // Add the JAR file to the class path
    try {
      addURL(jarFile.toURL());
    }

    catch (MalformedURLException e) {
      // We don't expect this to happen
      e.printStackTrace();
    }

    if (manifest != null) {
      // Get the class path entry
      String classPath = manifest.getMainAttributes().getValue(Attributes.Name.CLASS_PATH);

      if (classPath != null) {
        // The spec states that each entry is relative so work out the current path
        String currentPath = jarFile.getParent();

        // Parse each entry and add it to the class path
        StringTokenizer st = new StringTokenizer(classPath, " ");
        while (st.hasMoreTokens()) {
          try {
            addURL(new File(currentPath, st.nextToken()).toURL());
          }

          catch (MalformedURLException e) {
            // Ignore this
          }
        }
      }
    }
  }

  /**
   * Attempts to examine the manifest of a JAR file for the main class
   *
   * @param jarFileName Path to the JAR file to read
   * @return The name of the main class specified in the manifest, otherwise null
   * @throw FileNotFoundException Thrown when the JAR file cannot be found
   * @throw IOException When the contents of the JAR file cannot be read
   */
  public static String getModuleClassName(String jarFileName) throws FileNotFoundException, IOException {
    JarFile jf = new JarFile(jarFileName);
    Manifest manifest = jf.getManifest();

    // Get the main class entry from the manifest
    String mainClass = null;
    if (manifest != null) {
      mainClass = manifest.getMainAttributes().getValue(Attributes.Name.MAIN_CLASS);
    }

    return mainClass;
  }
}

