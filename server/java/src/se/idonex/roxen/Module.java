/*
 * $Id: Module.java,v 1.5 2000/02/01 00:08:21 marcus Exp $
 *
 */

package se.idonex.roxen;

import java.util.Vector;

public abstract class Module {

  public static final int TYPE_STRING = 1;
  public static final int TYPE_FILE = 2;
  public static final int TYPE_INT = 3;
  public static final int TYPE_DIR = 4;

  public static final int TYPE_STRING_LIST = 5;
  public static final int TYPE_MULTIPLE_STRING = 5;

  public static final int TYPE_INT_LIST = 6;
  public static final int TYPE_MULTIPLE_INT = 6;

  public static final int TYPE_FLAG = 7;
  public static final int TYPE_TOGGLE = 7;

  public static final int TYPE_ERROR = 8;
  public static final int TYPE_DIR_LIST = 9;
  public static final int TYPE_FILE_LIST = 10;
  public static final int TYPE_LOCATION = 11;
  public static final int TYPE_COLOR = 12;
  public static final int TYPE_TEXT_FIELD = 13;
  public static final int TYPE_TEXT = 13;
  public static final int TYPE_PASSWORD = 14;
  public static final int TYPE_FLOAT = 15;
  public static final int TYPE_PORTS = 16;
  public static final int TYPE_MODULE = 17;
  public static final int TYPE_MODULE_LIST = 18; /* somewhat buggy.. */
  public static final int TYPE_MULTIPLE_MODULE = 18; /* somewhat buggy.. */

  public static final int TYPE_FONT = 19;

  public static final int TYPE_CUSTOM = 20;
  public static final int TYPE_NODE = 21;

  public static final int VAR_EXPERT = 256;
  public static final int VAR_MORE = 512;
  public static final int VAR_DEVELOPER = 1024;
  public static final int VAR_INITIAL = 2048;

  static final int MODULE_EXTENSION       =  (1 << 0);
  static final int MODULE_LOCATION        =  (1 << 1);
  static final int MODULE_URL	         =  (1 << 2);
  static final int MODULE_FILE_EXTENSION  =  (1 << 3);
  static final int MODULE_PARSER          =  (1 << 4);
  static final int MODULE_LAST            =  (1 << 5);
  static final int MODULE_FIRST           =  (1 << 6);
  
  static final int MODULE_AUTH            =  (1 << 7);
  static final int MODULE_MAIN_PARSER     =  (1 << 8);
  static final int MODULE_TYPES           =  (1 << 9);
  static final int MODULE_DIRECTORIES     =  (1 << 10);
  
  static final int MODULE_PROXY           =  (1 << 11);
  static final int MODULE_LOGGER          =  (1 << 12);
  static final int MODULE_FILTER          =  (1 << 13);

  // A module which can be called from other modules, protocols, scripts etc.
  static final int MODULE_PROVIDER	 =  (1 << 15);
  // The module implements a protocol.
  static final int MODULE_PROTOCOL        =  (1 << 16);

  // A configuration interface module
  static final int MODULE_CONFIG          =  (1 << 17);

  // Flags.
  static final int MODULE_SECURITY        =  (1 << 29);
  static final int MODULE_EXPERIMENTAL    =  (1 << 30);


  private RoxenConfiguration configuration;

  private Vector defvars = null;
  
  public abstract String queryName();

  public abstract String info();

  public String queryProvides()
  {
    return null;
  }

  final int queryType()
  {
    return (this instanceof LocationModule? MODULE_LOCATION : 0) |
      (this instanceof ParserModule? MODULE_PARSER : 0) |
      (this instanceof FileExtensionModule? MODULE_FILE_EXTENSION : 0) |
      (this instanceof SecurityModule? MODULE_SECURITY : 0) |
      (this instanceof ExperimentalModule? MODULE_EXPERIMENTAL : 0);
  }

  final boolean queryUnique()
  {
    return this instanceof UniqueModule;
  }

  public RoxenConfiguration myConfiguration()
  {
    return configuration;
  }

  protected String queryInternalLocation()
  {
    return configuration.queryInternalLocation(this);
  }

  protected RoxenResponse findInternal(String f, RoxenRequest id)
  {
    return null;
  }

  public String status()
  {
    return null;
  }

  void start()
  {    
  }

  void stop()
  {
  }

  private void addDefvar(Defvar dv)
  {
    if(defvars == null)
      defvars = new Vector();
    defvars.add(dv);
  }

  Defvar[] getDefvars()
  {
    if(defvars == null)
      return new Defvar[0];
    Defvar[] dvs = new Defvar[defvars.size()];
    dvs = (Defvar[])defvars.toArray(dvs);
    defvars = null;
    return dvs;
  }

  protected void defvar(String var, Object value, String name, int type,
			String doc)
  {
    addDefvar(new Defvar(var, value, name, type, doc));
  }

  protected void defvar(String var, Object value, String name, int type)
  {
    defvar(var, value, name, type, null);
  }

  public native Object query(String name);

  public int queryInt(String name)
  {
    return ((Integer)query(name)).intValue();
  }

  public String queryString(String name)
  {
    return (String)query(name);
  }

  protected native void set(String name, Object value);

  protected void set(String name, int value)
  {
    set(name, new Integer(value));
  }

  String checkVariable(String name, Object value)
  {
    return null;
  }

}

