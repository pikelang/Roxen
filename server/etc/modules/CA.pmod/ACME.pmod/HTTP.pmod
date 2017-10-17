#pike __REAL_VERSION__
#require constant(Concurrent)

#include "acme.h"

constant USER_AGENT = "Pike-ACME/0.1 Pike/"+__REAL_VERSION__+"."+__REAL_BUILD__;


//! HTTP result class. Consider internal.
//!
//! @seealso
//!  @[Success], @[Failure]
class Result
{
  //! Internal result mapping
  protected mapping result;

  //! Return @tt{true@} if scuccess, @tt{false@} otherwise
  public bool `ok();

  //! The HTTP response headers
  public mapping `headers()
  {
    return result->headers;
  }

  //! The host that was called in the request
  public Standards.URI `host()
  {
    return result->host;
  }

  //! Returns the requested URL
  public string `url()
  {
    return result->url;
  }

  //! The HTTP status of the response, e.g @tt{200@}, @tt{201@}, @tt{404@}
  //! and so on.
  public int `status()
  {
    return result->status;
  }

  //! The textual representation of @[status].
  public string `status_description()
  {
    return result->status_desc || "Unknown";
  }

  //! Extra arguments set in the @[Arguments] object.
  public array(mixed) `extra_args()
  {
    return result->extra_args;
  }

  //! @ignore
  protected void create(mapping _result)
  {
    result = _result;
  }

  protected string _sprintf(int t)
  {
    return sprintf("%O(%d %s)",
                   object_program(this), status, status_description);
  }
  //! @endignore
}


//! A class representing a successful request and its response. An instance of
//! this class will be given as argument to the
//! @[Concurrent.Future()->on_success()] callback registered on the returned
//! @[Concurrent.Future] object from @[get_url()], @[post_url()],
//! @[delete_url()], @[put_url()] or @[do_method()].
class Success
{
  inherit Result;

  public bool `ok() { return true; }

  public bool `valid()
  {
    if (content_type && search(content_type, "problem+json") > -1) {
      return false;
    }

    return true;
  }

  //! The response body, i.e the content of the requested URL
  public string `data()
  {
    string data = result->data;

    if (content_encoding && content_encoding == "gzip") {
      data = Gz.uncompress(data[10..<8], true);
    }

    return data;
  }

  //! Returns the value of the @tt{content-length@} header.
  public int `length()
  {
    return headers && (int)headers["content-length"];
  }

  //! Returns the content type of the requested document
  public string `content_type()
  {
    if (string ct = (headers && headers["content-type"])) {
      if (sscanf (ct, "%s;", string c) == 1) {
        return c;
      }

      return ct;
    }
  }

  //! Returns the charset of the requested document, if given by the
  //! response headers.
  public string `charset()
  {
    if (string ce = (headers && headers["content-type"])) {
      if (sscanf (ce, "%*s;%*scharset=%s", ce) == 3) {
        if (ce[0] == '"' || ce[0] == '\'') {
          ce = ce[1..<1];
        }
        return ce;
      }
    }
  }

  //! Returns the content encoding of the response if set by the remote server.
  public string `content_encoding()
  {
    if (string ce = (headers && headers["content-encoding"])) {
      return ce;
    }
  }
}


//! A class representing a failed request. An instance of
//! this class will be given as argument to the
//! @[Concurrent.Future()->on_failure()] callback registered on the returned
//! @[Concurrent.Future] object from @[get_url()], @[post_url()],
//! @[delete_url()], @[put_url()] or @[do_method()].
class Failure
{
  inherit Result;
  public bool `ok() { return false; }
}


class Client
{
  protected mapping(string:string) headers = ([
    "user-agent"      : USER_AGENT,
    "accept-language" : "en",
    "connection"      : "keep-alive"
  ]);
  protected Protocols.HTTP.Query con;
  protected int _timeout = 120;


  protected void create()
  {
    con = Protocols.HTTP.Query();
  }


  public void keep_alive(bool yes)
  {
    headers["connection"] = yes ? "keep-alive" : "close";
  }


  public int `timeout()
  {
    return _timeout;
  }


  public void `timeout=(int n)
  {
    if (n >= 0) {
      _timeout = n;
    }
  }


  protected string resolve_hostname(Standards.URI uri)
  {
    string r = uri->host;

    if ((uri->scheme == "http" && uri->port != 80) ||
        (uri->scheme == "https" && uri->port != 443))
    {
      r += ":" + uri->port;
    }

    return r;
  }


  public Concurrent.Future get_url(string|Standards.URI url, void|mapping vars)
  {
    return do_method("GET", url, vars);
  }


  public Concurrent.Future post_url(string|Standards.URI url, void|mapping vars,
                                    void|string data)
  {
    return do_method("POST", url, vars, data);
  }


  public Concurrent.Future do_method(string http_method,
                                     string|Standards.URI uri,
                                     void|mapping vars,
                                     void|string data)
  {
    if (stringp(uri)) {
      uri = Standards.URI(uri);
    }

    mapping(string:string) local_headers = headers + ([]);

    // Due to a bug in Query
    if (upper_case(http_method) == "HEAD") {
      local_headers["connection"] = "close";
    }

    local_headers["host"] = resolve_hostname(uri);

    if (data) {
      local_headers["content-length"] = (string) sizeof(data);
    }

    if (_timeout) {
      con->timeout = _timeout;
      con->data_timeout = _timeout;
    }

    TRACE("local_headers: %O\n", local_headers);

    Concurrent.Promise p = Concurrent.Promise();

    void handle_result(bool ok) {
      con->set_callbacks(0, 0);

      mapping ret = ([
        "host"        : con->host,
        "status"      : con->status,
        "status_desc" : con->status_desc,
        "headers"     : copy_value(con->headers),
        "url"         : uri
      ]);

      TRACE("handle_result(%O)\n", ret);

      if (ok) {
        ret->data = con->data();
        p->success(Success(ret));
      }
      else {
        p->failure(Failure(ret));
      }
    };

    con->set_callbacks(
      lambda (Protocols.HTTP.Query q) {
        con->set_callbacks(0, 0);
        con->timed_async_fetch(
          lambda (Protocols.HTTP.Query q) {
            handle_result(true);
          },
          lambda (Protocols.HTTP.Query q) {
            handle_result(false);
          }
        );
      },
      lambda (Protocols.HTTP.Query q) {
        handle_result(false);
      });

    Protocols.HTTP.do_async_method(http_method, uri, vars, local_headers, con,
                                   data);

    return p->future();
  }
}
