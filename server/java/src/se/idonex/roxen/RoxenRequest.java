/*
 * $Id: RoxenRequest.java,v 1.2 2000/01/10 20:32:27 marcus Exp $
 *
 */

package se.idonex.roxen;

public class RoxenRequest {

  public final RoxenConfiguration conf;
  public final String rawURL, prot, clientprot, method;
  public final String realfile, virtfile, raw, query, notQuery, remoteaddr;
  /* variables */
  /* request_headers */
  /* supports */
  /* pragma */
  /* auth */

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
