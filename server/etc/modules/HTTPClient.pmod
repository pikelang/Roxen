//! A HTTP client that does async calls but waits for the result before
//! returning the result. If the request takes too long the client will abort.
//! The timeout can be set per request but is @tt{60@} seconds per default
//!
//! @example
//! @code
//! HTTPClient.Arguments args = HTTPClient.Arguments(([
//!   "variables" : ([ "a" : 1 ]),               // optional
//!   "maxtime"   : 30                           // optional
//! ]));
//!
//! HTTPClient.Result res = HTTPClient.sync_get("http://the.url/to/fetch", args);
//!
//! if (res->ok) {
//!   werror("Call to %s was ok: %s\n", res->url, res->data[0..50]);
//! }
//! else {
//!   werror("Call to %s failed with status %d %s\n",
//!          res->url, res->status, res->status_description);
//! }
//! @endcode
//!
//! You can also do completly async requests with callbacks
//!
//! @example
//! @code
//! HTTPClient.Arguments args = HTTPClient.Arguments();
//! args->on_success(lambda (HTTPClient.Result resp) {
//!   werror("Successful request for %O\n", resp->url);
//! });
//!
//! args->on_failure(lambda (HTTPClient.Result resp) {
//!   werror("Failed request for %O (%d %s)\n", resp->url,
//!          resp->status, resp->status_description);
//! });
//!
//! HTTPClient.async_get("http://domain.com", args);
//! @endcode

//#define HTTP_CLIENT_DEBUG

#ifdef HTTP_CLIENT_DEBUG
# define TRACE(X...)werror("%s:%d: %s",basename(__FILE__),__LINE__,sprintf(X))
#else
# define TRACE(X...)0
#endif

protected constant DEFAULT_MAXTIME = 60;


//! Do a HTTP GET request
public Result sync_get(Protocols.HTTP.Session.URL uri, void|Arguments args)
{
  return do_safe_method("GET", uri, args);
}


//! Do a HTTP POST request
public Result sync_post(Protocols.HTTP.Session.URL uri, void|Arguments args)
{
  return do_safe_method("POST", uri, args);
}


//! Do a HTTP PUT request
public Result sync_put(Protocols.HTTP.Session.URL uri, void|Arguments args)
{
  return do_safe_method("PUT", uri, args);
}


//! Do a HTTP DELETE request
public Result sync_delete(Protocols.HTTP.Session.URL uri, void|Arguments args)
{
  return do_safe_method("DELETE", uri, args);
}


//! Do an async HTTP GET request
public void async_get(Protocols.HTTP.Session.URL uri, void|Arguments args)
{
  do_safe_method("GET", uri, args, true);
}


//! Do an async HTTP POST request
public void async_post(Protocols.HTTP.Session.URL uri, void|Arguments args)
{
  do_safe_method("POST", uri, args, true);
}


//! Do an async HTTP PUT request
public void async_put(Protocols.HTTP.Session.URL uri, void|Arguments args)
{
  do_safe_method("PUT", uri, args, true);
}


//! Do an async HTTP DELETE request
public void async_delete(Protocols.HTTP.Session.URL uri, void|Arguments args)
{
  do_safe_method("DELETE", uri, args, true);
}


//! Fetch an URL with a timeout with the @[http_method] method.
public Result do_safe_method(string http_method,
                             Protocols.HTTP.Session.URL uri,
                             void|Arguments args,
                             void|bool async)
{
  if (!args) {
    args = Arguments();
  }

  Result res;
  Session s = Session();
  object /* Session.Request */ qr;
  Thread.Queue q;
  mixed co_maxtime;

  if (args->maxtime) s->maxtime = args->maxtime;
  if (args->timeout) s->timeout = args->timeout;

  if (!async) {
    q = Thread.Queue();
  }

  qr = s->async_do_method_url(http_method, uri,
                              args->variables,
                              args->data,
                              args->headers,
                              0, /* headers received callback */
                              lambda (Result ok) {
                                res = ok;
                                q && q->write("@");
                                if (async) {
                                  if (args->on_success) {
                                    args->on_success(res);
                                  }
                                  qr = 0;
                                  s = 0;
                                }
                              },
                              lambda (Result fail) {
                                res = fail;
                                q && q->write("@");
                                if (async) {
                                  if (args->on_failure) {
                                    args->on_failure(res);
                                  }
                                  qr = 0;
                                  s = 0;
                                }
                              },
                              ({}));

  if (!query_has_maxtime()) {
    TRACE("External timeout\n");
    co_maxtime = call_out(lambda () {
      TRACE("Timeout callback: %O\n", qr);

      res = Failure(([
        "status"      : 504,
        "status_desc" : "Gateway timeout",
        "host"        : qr->con->host,
        "headers"     : qr->con->headers,
        "url"         : qr->url_requested
      ]));

      qr->set_callbacks(0, 0, 0, 0);
      qr->con->set_callbacks(0, 0, 0);
      destruct(qr);
      destruct(s);

      q && q->write("@");

      if (async) {
        if (args->on_failure) {
          args->on_failure(res);
        }

        qr = 0;
        s = 0;
      }
    }, s->maxtime || DEFAULT_MAXTIME);
  }

  if (!async) {
    q->read();
  }

  if (co_maxtime && co_maxtime[0]) {
    TRACE("Remove timeout callout\n");
    remove_call_out(co_maxtime);
  }

  if (!async) {
    q  = 0;
    qr = 0;
    s  = 0;
  }

  return res;
}


//! If the Protocols.HTTP.Query class doesn't have the maxtime property
//! we need to take care of the maxtime timeout from the outside
protected int(-1..1) _query_has_maxtime = -1;
protected bool query_has_maxtime()
{
  if (_query_has_maxtime != -1) {
    return _query_has_maxtime == 1;
  }

  Protocols.HTTP.Query q = Protocols.HTTP.Query();
  _query_has_maxtime = (int) has_index(q, "maxtime");
  destruct(q);
  return _query_has_maxtime;
}


class Arguments
{
  //! Data fetch timeout
  int timeout;

  //! Request timeout
  int maxtime;

  //! The URL to fetch
  Protocols.HTTP.Session.URL url;

  //! Additional request headers
  mapping(string:string) headers;

  //! Query variables
  mapping(string:mixed) variables;

  //! POST data
  void|string|mapping data;

  //! Callback to call on successful async request
  function(Result:void) on_success;

  //! Callback to call on failed async request
  function(Result:void) on_failure;

  //! If @[args] is given the indices that match any of this object's
  //! members will set those object members to the value of the
  //! corresponding mapping index.
  protected void create(void|mapping(string:mixed) args)
  {
    if (args) {
      foreach (args; string key; mixed val) {
        if (has_index(this, key)) {
          this[key] = val;
        }
      }
    }
  }
}


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
  public string `host()
  {
    return result->host;
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
    return result->status_desc;
  }

  //! Returns the requested URL
  public string `url()
  {
    return result->url;
  }

  //! @ignore
  protected void create(mapping _result)
  {
    //TRACE("this_program(%O)\n", _result->headers);
    result = _result;
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

  //! The response body, i.e the content of the requested URL
  public string `data() { return result->data; }

  //! Returns the value of the @tt{content-length@} header.
  public int `length()
  {
    return headers && (int)headers["content-length"];
  }

  //! Returns the content type of the requested document
  public string `content_type()
  {
    if (string ct = (headers && headers["content-type"])) {
      sscanf (ct, "%s;", ct);
      return ct;
    }
  }

  //! Returns the content encoding of the requested document, if given by the
  //! response headers.
  public string `content_encoding()
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


//! Internal class for the actual HTTP requests
protected class Session
{
  inherit Protocols.HTTP.Session : parent;

  public int(0..) maxtime, timeout;
  public int maximum_connections_per_server = 20;

  Request async_do_method_url(string method,
                              URL url,
                              void|mapping query_variables,
                              void|string|mapping data,
                              void|mapping extra_headers,
                              function callback_headers_ok,
                              function callback_data_ok,
                              function callback_fail,
                              array callback_arguments)
  {
    return ::async_do_method_url(method, url, query_variables, data,
                                 extra_headers, callback_headers_ok,
                                 callback_data_ok, callback_fail,
                                 callback_arguments);
  }


  class Request
  {
    inherit parent::Request;

    protected void async_fail(object q)
    {
      TRACE("fail q: %O\n", q);

      mapping ret = ([
        "status"      : q->status,
        "status_desc" : q->status_desc,
        "host"        : q->host,
        "headers"     : copy_value(q->headers),
        "url"         : ::url_requested
      ]);

      // clear callbacks for possible garbation of this Request object
      con->set_callbacks(0, 0);

      function fc = fail_callback;
      set_callbacks(0, 0, 0); // drop all references
      extra_callback_arguments = 0;

      if (fc) {
        fc(Failure(ret));
      }
    }


    protected void async_ok(object q)
    {
      TRACE("async_ok: %O -> %s!\n", q->host, ::url_requested);

      ::check_for_cookies();

      if (con->status >= 300 && con->status < 400 &&
          con->headers->location && follow_redirects)
      {
        Standards.URI loc = Standards.URI(con->headers->location,url_requested);
        TRACE("New location: %O\n", loc);

        if (loc->scheme == "http" || loc->scheme == "https") {
          destroy(); // clear
          follow_redirects--;
          do_async(prepare_method("GET", loc));
          return;
        }
      }

      // clear callbacks for possible garbation of this Request object
      con->set_callbacks(0, 0);

      if (data_callback) {
        con->timed_async_fetch(async_data, async_fail); // start data downloading
      }
      else {
        extra_callback_arguments = 0; // to allow garb
      }
    }


    protected void async_data()
    {
      mapping ret = ([
        "host"        : con->host,
        "status"      : con->status,
        "status_desc" : con->status_desc,
        "headers"     : copy_value(con->headers),
        "data"        : con->data(),
        "url"         : ::url_requested
      ]);

      // clear callbacks for possible garbation of this Request object
      con->set_callbacks(0, 0);

      if (data_callback) {
        data_callback(Success(ret));
      }

      extra_callback_arguments = 0;
    }

    void destroy()
    {
      TRACE("Destructor called in Request: %O\n", ::url_requested);
      ::set_callbacks(0, 0, 0, 0);
      ::destroy();
    }
  }


  class SessionQuery
  {
    inherit parent::SessionQuery;

    protected void create()
    {
      #if constant (this::maxtime)
      TRACE("# Query has maxtime\n");
      if (Session::maxtime) {
        this::maxtime = Session::maxtime;
      }
      #endif

      if (Session::timeout) {
        this::timeout = Session::timeout;
      }
    }
  }
}
