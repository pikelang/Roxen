/*
 * $Id: Defvar.java,v 1.1 1999/12/19 21:01:12 marcus Exp $
 *
 */

package se.idonex.roxen;

class Defvar {

  String var, name, doc;
  Object value;
  int type;

  Defvar(String _var, Object _value, String _name, int _type, String _doc)
  {
    var = _var;
    value = _value;
    name = _name;
    type = _type;
    doc = _doc;
  }

}


