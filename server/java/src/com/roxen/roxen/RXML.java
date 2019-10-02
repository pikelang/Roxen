/*
 * $Id$
 *
 */

package com.roxen.roxen;

/**
 * RXML framework
 *
 * @version	$Version$
 * @author	marcus
 */

public class RXML {

  /** The object used to throw RXML errors. */
  public static class Backtrace extends Error
  {
    String type;	// Currently "run" or "parse".

    /**
     * Gets the type of RXML backtrace ("run" or "parse").
     *
     * @return    the type
     */
    public String getType()
    {
      return type;
    }

    Backtrace(String type, String msg)
    {
      super(msg);
      this.type = type;
    }
  }


  /**
   * Returns the value a variable in the specified scope.  Returns
   * null if there's no such variable (or it's nil).
   *
   * @param  var        the name of the variable
   * @param  scopeName  the name of the scope
   * @return            the value of the variable, or null
   */
  public static native Object getVar(String var, String scopeName);

  /**
   * Returns the value a variable in the current scope.  Returns null
   * if there's no such variable (or it's nil).
   *
   * @param  var        the name of the variable
   * @return            the value of the variable, or null
   */
  public static Object getVar(String var)
  {
    return getVar(var, null);
  }

  /**
   * Returns the value a variable in the specified scope.  Returns
   * null if there's no such variable (or it's nil).  The var string
   * is also parsed for scope and/or subindexes, e.g. "scope.var.1.foo".
   *
   * @param  var        the name of the variable
   * @param  scopeName  the name of the scope
   * @return            the value of the variable, or null
   */
  public static native Object userGetVar(String var, String scopeName);

  /**
   * Returns the value a variable in the current scope.  Returns null
   * if there's no such variable (or it's nil).  The var string is
   * also parsed for scope and/or subindexes, e.g. "scope.var.1.foo".
   *
   * @param  var        the name of the variable
   * @return            the value of the variable, or null
   */
  public static Object userGetVar(String var)
  {
    return userGetVar(var, null);
  }

  /**
   * Sets the value of a variable in the specified scope.  Returns
   * val.
   *
   * @param  var        the name of the variable
   * @param  val        the new value for the variable
   * @param  scopeName  the name of the scope
   * @return            the same value as was passed in
   */
  public static native Object setVar(String var, Object val,
				     String scopeName);

  /**
   * Sets the value of a variable in the current scope.  Returns val.
   *
   * @param  var        the name of the variable
   * @param  val        the new value for the variable
   * @return            the same value as was passed in
   */
  public static Object setVar(String var, Object val)
  {
    return setVar(var, val, null);
  }

  /**
   * Sets the value of a variable in the specified scope.  Returns
   * val.  The var string is also parsed for scope and/or subindexes,
   * e.g. "scope.var.1.foo".
   *
   * @param  var        the name of the variable
   * @param  val        the new value for the variable
   * @param  scopeName  the name of the scope
   * @return            the same value as was passed in
   */
  public static native Object userSetVar(String var, Object val,
					 String scopeName);

  /**
   * Sets the value of a variable in the current scope.  Returns val.
   * The var string is also parsed for scope and/or subindexes, e.g.
   * "scope.var.1.foo".
   *
   * @param  var        the name of the variable
   * @param  val        the new value for the variable
   * @return            the same value as was passed in
   */
  public static Object userSetVar(String var, Object val)
  {
    return userSetVar(var, val, null);
  }

  /**
   * Removes a variable in the specified scope.
   *
   * @param  var        the name of the variable
   * @param  scopeName  the name of the scope
   */
  public static native void deleteVar(String var, String scopeName);

  /**
   * Removes a variable in the current scope.
   *
   * @param  var        the name of the variable
   */
  public static void deleteVar(String var)
  {
    deleteVar(var, null); 
  }

  /**
   * Removes a variable in the specified scope.
   * The var string is also parsed for scope and/or subindexes,
   * e.g. "scope.var.1.foo".
   *
   * @param  var        the name of the variable
   * @param  scopeName  the name of the scope
   */
  public static native void userDeleteVar(String var, String scopeName);

  /**
   * Removes a variable in the current scope.
   * The var string is also parsed for scope and/or subindexes,
   * e.g. "scope.var.1.foo".
   *
   * @param  var        the name of the variable
   */
  public static void userDeleteVar(String var)
  {
    userDeleteVar(var, null); 
  }

  /**
   * Throws an RXML run error with a dump of the parser stack in the
   * current context. This is intended to be used by tags for errors
   * that can occur during normal operation, such as when the
   * connection to an SQL server fails.
   *   
   */
  public static void runError(String msg) throws Backtrace
  {
    throw new Backtrace("run", msg);
  }

  /**
   * Throws an RXML parse error with a dump of the parser stack in the
   * current context. This is intended to be used for programming
   * errors in the RXML code, such as lookups in nonexisting scopes and
   * invalid arguments to a tag.
   *
   */
  public static void parseError(String msg) throws Backtrace
  {
    throw new Backtrace("parse", msg);
  }

  /**
   * Writes the message to the debug log if the innermost tag being
   * executed has FLAG_DEBUG set.
   *
   */
  public static native void tagDebug(String msg);


  RXML() { }

}
