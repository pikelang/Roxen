/*
 * $Id$
 *
 */

package com.roxen.roxen;

import java.util.Vector;

/**
 * The base class for Roxen modules.  All modules must inherit this
 * class, directly or indirectly.
 * <P>
 * Each module should also implement one or more of the specific module
 * type interfaces.
 *
 * @see LocationModule
 * @see ParserModule
 * @see FileExtensionModule
 * @see LastResortModule
 * @see ProviderModule
 * @see ExperimentalModule
 * @see SecurityModule
 * @see UniqueModule
 *
 * @version	$Version$
 * @author	marcus
 */

public abstract class Module {

  /* Module variable types */

  /** Constant for string type module variables */
  public static final int TYPE_STRING = 1;
  /** Constant for file name type module variables */
  public static final int TYPE_FILE = 2;
  /** Constant for integer type module variables */
  public static final int TYPE_INT = 3;
  /** Constant for directory name type module variables */
  public static final int TYPE_DIR = 4;

  /** Constant for string list type module variables */
  public static final int TYPE_STRING_LIST = 5;
  /** The same as TYPE_STRING_LIST */
  public static final int TYPE_MULTIPLE_STRING = 5;

  /** Constant for integer list type module variables */
  public static final int TYPE_INT_LIST = 6;
  /** The same as TYPE_INT_LIST */
  public static final int TYPE_MULTIPLE_INT = 6;

  /** Constant for boolean type module variables */
  public static final int TYPE_FLAG = 7;
  /** The same as TYPE_FLAG */
  public static final int TYPE_TOGGLE = 7;

  // public static final int TYPE_ERROR = 8;  /* not used anymore */

  /** Constant for directory name list type module variables */
  public static final int TYPE_DIR_LIST = 9;

  /** Constant for file name list type module variables */
  public static final int TYPE_FILE_LIST = 10;

  /** Constant for URL path type module variables */
  public static final int TYPE_LOCATION = 11;

  // public static final int TYPE_COLOR = 12;  /* not implemented yet */

  /** Constant for free format text type module variables */
  public static final int TYPE_TEXT_FIELD = 13;
  /** The same as TYPE_TEXT_FIELD */
  public static final int TYPE_TEXT = 13;

  /** Constant for string type module variables */
  public static final int TYPE_PASSWORD = 14;

  /** Constant for floating point type module variables */
  public static final int TYPE_FLOAT = 15;

  // public static final int TYPE_PORTS = 16;  /* not used anymore */

  /** Constant for module type module variables */
  public static final int TYPE_MODULE = 17;
  // public static final int TYPE_MODULE_LIST = 18; /* somewhat buggy.. */
  // public static final int TYPE_MULTIPLE_MODULE = 18; /* somewhat buggy.. */

  /** Constant for font name type module variables */
  public static final int TYPE_FONT = 19;

  // public static final int TYPE_CUSTOM = 20;  /* not used anymore */
  // public static final int TYPE_NODE = 21;  /* not used anymore */

  /**
   * Constant for expert mode variable flag.
   * Set this flag to make the variable show only in expert mode.
   */
  public static final int VAR_EXPERT = 256;
  /**
   * Constant for advanced option variable flag.
   * Set this flag to make the variable show only when advanced options
   * are enabled.
   */
  public static final int VAR_MORE = 512;
  /**
   * Constant for developer option variable flag.
   * Set this flag to make the variable show only when developer options
   * are enabled.
   */
  public static final int VAR_DEVELOPER = 1024;
  /**
   * Constant for initial configuration variable flag.
   * Set this flag for variables that need to be configured when
   * the module is created.
   */
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

  // An administration interface module
  static final int MODULE_CONFIG          =  (1 << 17);

  // Flags.
  static final int MODULE_SECURITY        =  (1 << 29);
  static final int MODULE_EXPERIMENTAL    =  (1 << 30);


  private RoxenConfiguration configuration;

  private Vector defvars = null;

  /**
   * Returns the name of the module
   *
   * @return  the module's name
   */
  public abstract String queryName();

  /**
   * Returns the documentation for the module
   *
   * @return  an HTML string containing brief online documentation
   */
  public abstract String info();

  final int queryType()
  {
    return (this instanceof LocationModule? MODULE_LOCATION : 0) |
      (this instanceof ParserModule? MODULE_PARSER : 0) |
      (this instanceof FileExtensionModule? MODULE_FILE_EXTENSION : 0) |
      (this instanceof SecurityModule? MODULE_SECURITY : 0) |
      (this instanceof ExperimentalModule? MODULE_EXPERIMENTAL : 0) |
      (this instanceof ProviderModule? MODULE_PROVIDER : 0) |
      (this instanceof LastResortModule? MODULE_LAST : 0);
  }

  final boolean queryUnique()
  {
    return this instanceof UniqueModule;
  }

  /**
   * Returns the configuration object of the virtual server in which
   * this module is enabled
   *
   * @return  the configuration
   */
  public RoxenConfiguration myConfiguration()
  {
    return configuration;
  }

  /**
   * Returns the URL path of the internal mount point that has been
   * created for this module.
   *
   * @return  the URL path
   */
  protected String queryInternalLocation()
  {
    return configuration.queryInternalLocation(this);
  }

  /**
   * Request an internal resource from this module.
   *
   * @param  f   the path of the resource relative to the location of
   *             this module
   * @param  id  the request object
   * @return     a response, or <code>null</code> if no such
   *             file exists.
   */
  protected RoxenResponse findInternal(String f, RoxenRequest id)
  {
    return null;
  }

  /**
   * Produce information about the current status of the module
   *
   * @return  a status message, or <code>null</code> if no
   *          information is available
   */
  public String status()
  {
    return null;
  }

  /**
   * Prepare the module for servicing requests
   *
   */
  protected void start()
  {    
  }

  /**
   * Inform the module that it is about to be taken out of service
   *
   */
  protected void stop()
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

  /**
   * Create a module varible.
   * This method must be called from the modules constructor.
   *
   * @param  var   a name by which this variables is identified internally
   * @param  value the default value for this variable
   * @param  name  a human-readable name for this variable
   * @param  type  a <code>TYPE_</code>-constant selecting the type of
   *               this variable, optionally ORed with any <code>VAR_</code>
   *               flags
   * @param  doc   an HTML string containing brief documentation for the
   *               variable
   */
  protected void defvar(String var, Object value, String name, int type,
			String doc)
  {
    addDefvar(new Defvar(var, value, name, type, doc));
  }

  /**
   * Create an undocumented module varible.
   * This method must be called from the modules constructor.
   *
   * @param  var   a name by which this variables is identified internally
   * @param  value the default value for this variable
   * @param  name  a human-readable name for this variable
   * @param  type  a <code>TYPE_</code>-constant selecting the type of
   *               this variable, optionally ORed with any <code>VAR_</code>
   *               flags
   */
  protected void defvar(String var, Object value, String name, int type)
  {
    defvar(var, value, name, type, null);
  }

  /**
   * Get the current value of a module variable
   *
   * @param  name  the internal name of the variable
   * @return       the value of the variable
   */
  public native Object query(String name);

  /**
   * Get the current value of a <code>TYPE_INT</code> or
   * <code>TYPE_FLAG</code> module variable
   *
   * @param  name  the internal name of the variable
   * @return       the value of the variable
   */
  public int queryInt(String name)
  {
    Object n = query(name);
    return (n==null? 0 : ((Integer)n).intValue());
  }

  /**
   * Get the current value of a module variable of one of
   * the string types.
   *
   * @param  name  the internal name of the variable
   * @return       the value of the variable
   */
  public String queryString(String name)
  {
    return (String)query(name);
  }

  /**
   * Set the contents of a module variable to a new value
   *
   * @param  name  the internal name of the variable
   * @param  value the new value
   */
  protected native void set(String name, Object value);

  /**
   * Set the contents of a <code>TYPE_INT</code> or <code>TYPE_FLAG</code>
   * module variable to a new value
   *
   * @param  name  the internal name of the variable
   * @param  value the new value
   */
  protected void set(String name, int value)
  {
    set(name, new Integer(value));
  }

  /**
   * Check whether a new value is suitable for a module variable
   *
   * @param  name  the internal name of the variable
   * @param  value the new value
   * @return       <code>null</code> if the new value is OK, an error
   *               message otherwise.
   */
  String checkVariable(String name, Object value)
  {
    return null;
  }

}

