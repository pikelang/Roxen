#pike __REAL_VERSION__
#require constant(Concurrent)

#include "acme.h"

protected string directory_uri;
protected .Key key;
protected mapping(string:string|mapping(string:string)) directory;
protected array(string) nonces = ({});
protected .HTTP.Client http;


protected void create(string directory_uri, .Key key)
{
  this::http = .HTTP.Client();
  this::directory_uri = directory_uri;
  this::key = key;
}


protected string get_resource_from_uri(string uri)
{
  if (!directory) {
    return 0;
  }

  foreach (directory; string k; mixed v) {
    if (stringp(v) && v == uri) {
      return k;
    }
  }

  return 0;
}

public .Key get_key()
{
  return key;
}

public Concurrent.Future get_tos()
{
  if (!directory) {
    Concurrent.Promise p = Concurrent.Promise();

    fetch_directory()
      ->then(lambda (.HTTP.Success ok) {
        p->success(directory->meta && directory->meta["terms-of-service"]);
      })
      ->thencatch(lambda (.Error r) {
        p->failure(r);
      });

    return p->future();
  }

  return Concurrent.resolve(directory->meta &&
                            directory->meta["terms-of-service"]);
}


protected Concurrent.Future get_nonce(string uri)
{
  if (!sizeof(nonces)) {
    TRACE("Fetch nonce: %O\n", uri);
    return fetch_nonce(uri);
  }

  string n = nonces[0];
  nonces = nonces[1..];

  return Concurrent.resolve(n);
}


protected Concurrent.Future fetch_nonce(string uri)
{
  Concurrent.Promise p = Concurrent.Promise();

  http->do_method("HEAD", uri)
    ->then(lambda (.HTTP.Success ok) {
      save_nonce(ok);
      p->success(ok->headers["replay-nonce"]);
    })
    ->thencatch(lambda (.HTTP.Failure e) {
      TRACE("fetch_nonce() failed: %O\n", e);
      save_nonce(e);
      p->failure(.Error(e));
    });

  return p->future();
}


protected Concurrent.Future fetch_directory()
{
  Concurrent.Promise p = Concurrent.Promise();

  http->get_url(directory_uri)
    ->then(lambda (.HTTP.Success ok) {
      save_nonce(ok);
      directory = Standards.JSON.decode(ok->data);
      p->success(ok);
    })
    ->thencatch(lambda (.HTTP.Failure err) {
      save_nonce(err);
      p->failure(.Error(err));
    });

  return p->future();
}


public Concurrent.Future get_resource_uri(.Resource r)
{
  if (!directory) {
    Concurrent.Promise p = Concurrent.Promise();

    fetch_directory()
      ->then(lambda (.HTTP.Success ok) {
        if (directory[r]) {
          p->success(directory[r]);
        }
        else {
          p->failure(.Error("Unknown resource %O", r));
        }
      })
      ->thencatch(lambda (.HTTP.Failure err) {
        p->failure(.Error("Error resolving directory %O", directory_uri));
      });

    return p->future();
  }

  if (directory[r]) {
    return Concurrent.resolve(directory[r]);
  }
  else {
    return Concurrent.reject(.Error("Unknown resource %O", r));
  }
}


public Concurrent.Future post(string uri, mapping payload)
{
  Concurrent.Promise p = Concurrent.Promise();

  get_nonce(uri)
    ->then(lambda (string nonce) {
      return low_post(uri, payload, nonce);
    })
    ->then(lambda (.HTTP.Success ok) {
      p->success(ok);
    })
    ->thencatch(lambda (.Error err) {
      TRACE("post() error: %O\n", err);
      p->failure(err);
    });

  return p->future();
}


protected Concurrent.Future low_post(string uri, mapping payload,
                                     string nonce)
{
  Concurrent.Promise p = Concurrent.Promise();

  if (!payload->resource) {
    payload->resource = get_resource_from_uri(uri);
  }

  void do_query(string nonce, void|int retries) {
    TRACE("do_query(%s, %O)\n", nonce, payload);
    string j = key->sign(payload, ([ "nonce" : nonce, "url" : uri ]));

    http->post_url(uri, 0, j)
      ->then(lambda (.HTTP.Success res) {
        save_nonce(res);
        TRACE("Success: %O\n", res->headers);
        TRACE("Data: %O\n", res->data);
        TRACE("Status: %O : %O\n", res->status, res->status_description);

        if (res->valid) {
          p->success(res);
        }
        else {
          .AcmeError e = .AcmeError(res->data, res);

          if (e->is_bad_nonce()) {
            TRACE("Try again\n");
          }
          else {
            p->failure(e);
          }
        }
      })
      ->thencatch(lambda (.HTTP.Failure err) {
        TRACE("low_post error: %O\n", err);
        TRACE("low_post error headers: %O\n", err->headers);
        save_nonce(err);
        p->failure(.Error(err));
      });
  };


  do_query(nonce);

  return p->future();
}


protected void save_nonce(.HTTP.Result res)
{
  if (res && res->headers && res->headers["replay-nonce"]) {
    nonces += ({ res->headers["replay-nonce"] });
  }
}
