/*
 * $Id: Defvar.java,v 1.6 2004/06/01 07:37:35 _cvs_stephen Exp $
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


