/*
 * $Id: RoxenRequest.java,v 1.7 2000/02/21 18:30:46 marcus Exp $
 *
 */

package com.roxen.roxen;

import java.util.Set;
import java.util.Map;
import java.util.HashSet;
import java.util.TreeMap;

/**
 * A class representing requests from clients.
 *
 * @version	$Version$
 * @author	marcus
 */

public class RoxenRequest {

  /** The virtual server which is handling this request */
  public final RoxenConfiguration conf;

  /** The requested URL path, exactly as sent by the client */
  public final String rawURL;

  /** The protocol used when talking to the client,
   *  such as "HTTP/1.1" or "FTP"                   */
  public final String prot;

  /** The protocol actually requested by the client */
  public final String clientprot;

  /** The method of the request, such as "GET" or "POST" */
  public final String method;

  /** The filename of the file in the host filesystem used to
   *  satisfy this request, if any                            */
  public final String realfile;

  /** The pathname of the resource in the namespace of
   *  the virtual server used to satisfy this request, if any */
  public final String virtfile;

  /** The exact text of the client's request, if available */
  public final String raw;

  /** The query part of the requested URL path, if any */
  public final String query;

  /** The requested URL path, without any query part */
  public final String notQuery;

  /** The IP address of the client system */
  public final String remoteaddr;

  private Map _variables, _requestHeaders;
  private Set _supports, _pragma;

  /* auth */

  private native Map getVariables();
  private native Map getRequestHeaders();
  private native Set getSupports();
  private native Set getPragma();

  /**
   * Returns the configuration object of the virtual server by which
   * this request is handled
   *
   * @return      the configuration
   */
  public final RoxenConfiguration configuration()
  {
    return conf;
  }

  /**
   * Returns a Map with all the query variables of the request
   *
   * @return      the query variables
   */
  public synchronized Map variables()
  {
    if(_variables == null)
      if((_variables = getVariables()) == null)
	_variables = new TreeMap();
    return _variables;
  }

  /**
   * Returns a Map with all the headers of the request
   *
   * @return      the headers
   */
  public synchronized Map requestHeaders()
  {
    if(_requestHeaders == null)
      if((_requestHeaders = getRequestHeaders()) == null)
	_requestHeaders = new TreeMap();
    return _requestHeaders;
  }

  /**
   * Returns a Set with all known supported features of the client
   *
   * @return      the feature set
   */
  public synchronized Set supports()
  {
    if(_supports == null)
      if((_supports = getSupports()) == null)
	_supports = new HashSet();
    return _supports;
  }

  /**
   * Returns a Set with all pragmas sent by the client
   *
   * @return      the pragmas
   */
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
