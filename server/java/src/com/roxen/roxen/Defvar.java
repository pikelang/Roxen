/*
 * $Id: Defvar.java,v 1.2 2000/02/21 18:30:45 marcus Exp $
 *
 */

package com.roxen.roxen;

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


