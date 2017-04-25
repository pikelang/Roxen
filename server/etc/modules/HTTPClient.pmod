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

// #define HTTP_CLIENT_DEBUG

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
  if (args && args->follow_redirects > -1) {
    s->follow_redirects = args->follow_redirects;
  }
  object /* Session.Request */ qr;
  Thread.Queue q;
  mixed co_maxtime;

  if (args->maxtime) s->maxtime = args->maxtime;
  if (args->timeout) s->timeout = args->timeout;

  if (!async) {
    q = Thread.Queue();
  }

  function(Result:void) cb = lambda (Result r) {
    TRACE("Got callback: %O\n", r);
    res = r;
    q && q->write("@");
    if (async) {
      if (r->ok && args->on_success) {
        args->on_success(res);
      }
      else if (!r->ok && args->on_failure) {
        args->on_failure(r);
      }
      qr = 0;
      s = 0;
    }
  };

  qr = s->async_do_method_url(http_method, uri,
                              args->variables,
                              args->data,
                              args->headers,
                              0,  // headers received callback
                              cb, // ok callback
                              cb, // fail callback
                              args->extra_args || ({}));

  if (!query_has_maxtime()) {
    TRACE("No maxtime in Protocols.HTTP.Query. Set external max timeout: %O\n",
          s->maxtime || DEFAULT_MAXTIME);
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
  return _query_has_maxtime == 1;
}


class Arguments
{
  //! Data fetch timeout
  int timeout;

  //! Request timeout
  int maxtime;

  //! Number of times to follow redirects. A negative value will result in a
  //! default value being used.
  int follow_redirects = -1;

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

  //! Extra arguments that will end up in the @[Result] object
  array(mixed) extra_args;

  //! If @[args] is given the indices that match any of this object's
  //! members will set those object members to the value of the
  //! corresponding mapping member.
  protected void create(void|mapping(string:mixed) args)
  {
    if (args) {
      foreach (args; string key; mixed value) {
        if (has_index(this, key)) {
          if ((< "variables", "headers" >)[key]) {
            // Cast all values to string
            value = mkmapping(indices(value), map(values(value),
                                                  lambda (mixed s) {
                                                    return (string) s;
                                                  }));
          }

          this[key] = value;
        }
        else {
          error("Unknown argument %O!\n", key);
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

  //! Extra arguments set in the @[Arguments] object.
  public array(mixed) `extra_args()
  {
    return result->extra_args;
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
      sscanf (ct, "%s;", ct);
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
    if (stringp(url)) {
      url = Standards.URI(url);
    }

    // Due to a bug in Protocols.HTTP.Session which is fixed in Pike 8.1
    // but not yet in 8.0. (2016-05-20)
    if (!extra_headers || !extra_headers->host || !extra_headers->Host) {
      extra_headers = extra_headers || ([]);

      TRACE("Set host in headers: %O\n", url);

      if (url->scheme == "http") {
        extra_headers->host = url->host;
        if (url->port != 80) {
          extra_headers->host += ":" + url->port;
        }
      }
      else if (url->scheme == "https") {
        extra_headers->host = url->host;
        if (url->port != 443) {
          extra_headers->host += ":" + url->port;
        }
      }

      if (!sizeof(extra_headers)) {
        extra_headers = 0;
      }

      TRACE("Host header set?: %O\n", extra_headers);
    }

    if (upper_case(method) == "POST") {
      TRACE("Got post request: %O, %O, %O, %O\n",
            url, query_variables, data, extra_headers);
      // In Pike < 8.1 the content-length header isn't auotmatically added so
      // we have to take care of that explicitly
      bool has_content_len = false;
      bool has_content_type = false;

      if (extra_headers) {
        array(string) lc_headers = map(indices(extra_headers), lower_case);

        if (has_value(lc_headers, "content-length")) {
          has_content_len = true;
        }

        if (has_value(lc_headers, "content-type")) {
          has_content_type = true;
        }
      }

      if (!has_content_len) {
        mapping(string:string) qvars = url->get_query_variables();
        data = data||"";

        if (qvars && sizeof(qvars)) {
          if (!query_variables) {
            query_variables = qvars;
          }
          else {
            query_variables |= qvars;
          }
        }

        if (sizeof(data) && query_variables) {
          data += "&" + Protocols.HTTP.http_encode_query(query_variables);
        }
        else if (query_variables) {
          data = Protocols.HTTP.http_encode_query(query_variables);
        }

        if (!extra_headers) {
          extra_headers = ([]);
        }

        extra_headers["Content-Length"] = (string) sizeof(data);

        if (!has_content_type) {
          extra_headers["Content-Type"] = "application/x-www-form-urlencoded";
        }

        query_variables = 0;
      }
    }

    TRACE("Request: %O\n", url);

    return ::async_do_method_url(method, url, query_variables, data,
                                 extra_headers, callback_headers_ok,
                                 callback_data_ok, callback_fail,
                                 callback_arguments);
  }


  class Request
  {
    inherit parent::Request;

    protected void set_extra_args_in_result(mapping(string:mixed) r)
    {
      if (extra_callback_arguments && sizeof(extra_callback_arguments) > 1) {
        r->extra_args = extra_callback_arguments[1..];
      }
    }

    protected void async_fail(SessionQuery q)
    {
      TRACE("fail q: %O -> %O\n", q, ::url_requested);

      mapping ret = ([
        "status"      : q->status,
        "status_desc" : q->status_desc,
        "host"        : q->host,
        "headers"     : copy_value(q->headers),
        "url"         : ::url_requested
      ]);

      TRACE("Ret: %O\n", ret);

      set_extra_args_in_result(ret);

      // clear callbacks for possible garbation of this Request object
      con->set_callbacks(0, 0);

      function fc = fail_callback;
      set_callbacks(0, 0, 0); // drop all references
      extra_callback_arguments = 0;

      if (fc) {
        fc(Failure(ret));
      }
    }


    protected void async_ok(SessionQuery q)
    {
      TRACE("async_ok: %O -> %s!\n", q->host, ::url_requested);

      ::check_for_cookies();

      if (con->status >= 300 && con->status < 400 &&
          con->headers->location && follow_redirects)
      {
        Standards.URI loc = Standards.URI(con->headers->location,url_requested);
        TRACE("New location: %O -> %O (%O)\n", url_requested, loc, con->headers);

        if (loc->scheme == "http" || loc->scheme == "https") {
          con->set_callbacks(0, 0);
          ::destroy(); // clear
          follow_redirects--;
          do_async(prepare_method("GET", loc));
          return;
        }
      }

      // clear callbacks for possible garbation of this Request object
      con->set_callbacks(0, 0);

      if (data_callback) {
        con->async_fetch(async_data); // start data downloading
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

      set_extra_args_in_result(ret);

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
      ::set_callbacks(0, 0, 0);
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
