package com.roxen.roxen;

import java.util.zip.ZipInputStream;
import java.util.zip.ZipEntry;
import java.io.File;
import java.io.FileOutputStream;
import java.io.FileInputStream;
import java.net.URL;
import java.io.IOException;
import java.net.MalformedURLException;
import java.io.FileNotFoundException;


public class JarUtil {
    
    public static void expand(String sdir, String jar)
        throws MalformedURLException, IOException
    {
        File dir = new File(sdir);
        FileInputStream j = new FileInputStream(jar);

	ZipInputStream zis = new ZipInputStream(j);
	ZipEntry ze = null;
        
	while ((ze = zis.getNextEntry()) != null) {
            try {
		File f = new File(dir, ze.getName());
                
		if (ze.isDirectory()) {
		    f.mkdirs(); 
		} else {
		    byte[] buffer = new byte[1024];
		    int length = 0;
		    FileOutputStream fos = new FileOutputStream(f);
		    
		    while ((length = zis.read(buffer)) >= 0) {
			fos.write(buffer, 0, length);
		    }
		    
		    fos.close();
		}
	    } catch( FileNotFoundException ex ) {
		// XXX replace with a call to log() when available
		System.out.println("JarUtil: FileNotFoundException: " +  ze.getName() + " / " + jar );
                throw(ex);
	    }
	}

	zis.close();
    }

    /** Expand a WAR/Jar file into a directory.
     *  @param dir destination directory
     *  @param jar URL for the source JAR/WAR/ZIP file.
     *         Starting and ending "/" will be removed
     *
     */ 
    public static void expand(File dir, URL jar)
        throws MalformedURLException, IOException
    {
        String s = trim(jar.getFile(), "/");
	URL u = new URL(s);
	ZipInputStream zis = new ZipInputStream(u.openStream());
	ZipEntry ze = null;
        
	while ((ze = zis.getNextEntry()) != null) {
            try {
		File f = new File(dir, ze.getName());
                
		if (ze.isDirectory()) {
		    f.mkdirs(); 
		} else {
		    byte[] buffer = new byte[1024];
		    int length = 0;
		    FileOutputStream fos = new FileOutputStream(f);
		    
		    while ((length = zis.read(buffer)) >= 0) {
			fos.write(buffer, 0, length);
		    }
		    
		    fos.close();
		}
	    } catch( FileNotFoundException ex ) {
		// XXX replace with a call to log() when available
		System.out.println("JarUtil: FileNotFoundException: " +  ze.getName() + " / " + s );
	    }
	}

	zis.close();
    }

    private static String trim(String s, String t) {
	if (s.startsWith(t)) {
	    s = s.substring(t.length());
	}
	
	if (s.endsWith(t)) {
	    s = s.substring(0, s.length() - t.length());
	}
        
        return s;
    }

}
