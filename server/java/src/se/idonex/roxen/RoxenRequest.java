/*
 * $Id: RoxenRequest.java,v 1.3 2000/01/12 04:50:36 marcus Exp $
 *
 */

package se.idonex.roxen;

import java.util.Set;
import java.util.Map;
import java.util.HashSet;
import java.util.TreeMap;

public class RoxenRequest {

  public final RoxenConfiguration conf;
  public final String rawURL, prot, clientprot, method;
  public final String realfile, virtfile, raw, query, notQuery, remoteaddr;

  private Map _variables, _requestHeaders;
  private Set _supports, _pragma;

  /* auth */

  private native Map getVariables();
  private native Map getRequestHeaders();
  private native Set getSupports();
  private native Set getPragma();

  public synchronized Map variables()
  {
    if(_variables == null)
      if((_variables = getVariables()) == null)
	_variables = new TreeMap();
    return _variables;
  }

  public synchronized Map requestHeaders()
  {
    if(_requestHeaders == null)
      if((_requestHeaders = getRequestHeaders()) == null)
	_requestHeaders = new TreeMap();
    return _requestHeaders;
  }

  public synchronized Set supports()
  {
    if(_supports == null)
      if((_supports = getSupports()) == null)
	_supports = new HashSet();
    return _supports;
  }

  public synchronized Set pragma()
  {
    if(_pragma == null)
      if((_pragma = getPragma()) == null)
	_pragma = new HashSet();
    return _pragma;
  }

  RoxenRequest(RoxenConfiguration _conf, String _rawURL, String _prot,
	       String _clientprot, String _method, String _realfile,
	       String _virtfile, String _raw, String _query,
	       String _notQuery, String _remoteaddr)
  {
    conf = _conf;
    rawURL = _rawURL;
    prot = _prot;
    clientprot = _clientprot;
    method = _method;
    realfile = _realfile;
    virtfile = _virtfile;
    raw = _raw;
    query = _query;
    notQuery = _notQuery;
    remoteaddr = _remoteaddr;
  }

}
