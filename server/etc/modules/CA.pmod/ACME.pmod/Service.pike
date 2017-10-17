#pike __REAL_VERSION__
#require constant(Concurrent)

#include "acme.h"

protected .Client client;

protected void create(.Client client)
{
  this::client = client;
}


public Concurrent.Future check_account(.Key key)
{
  mapping payload = ([ "only-return-existing" : true ]);
  Concurrent.Promise p = Concurrent.Promise();

  client->get_resource_uri(.NEW_REGISTRATION)
    ->then(lambda (string uri) {
      return client->post(uri, payload);
    })
    ->then(lambda (.HTTP.Success ok) {
      TRACE("OK: %O\n", ok);
      p->success(ok);
    })
    ->thencatch(lambda (.Error e) {
      if (object_program(e) == .AcmeError) {
        if (e->status == Protocols.HTTP.HTTP_CONFLICT &&
            e->headers->location)
        {
          p->success(e->headers->location);
          return;
        }
      }

      TRACE("Error: %O\n", e);
      p->failure(e);
    });

  return p->future();
}


public Concurrent.Future register(string email, void|string agreement)
{
  mapping payload = ([ "contact" : ({ "mailto:" + email }) ]);

  Concurrent.Promise p = Concurrent.Promise();

  // void low_registration(string uri, void|string agreement) {
  //   payload->resource = .REGISTRATION;

  //   if (agreement) {
  //     payload->agreement = agreement;
  //   }

  //   TRACE("low_registration(%O, %O)\n", uri, payload);

  //   client->post(uri, payload)
  //     ->then(lambda (.HTTP.Success ok) {
  //       TRACE("Got ok from low_registration(%O)\n", ok->headers);
  //       TRACE("Data: %O\n", ok->data);
  //       p->success(ok);
  //     })
  //     ->thencatch(lambda (.Error err) {
  //       p->failure(err);
  //     });
  // };

  void low_new_registration(void|string agreement) {
    if (agreement) {
      payload->agreement = agreement;
    }

    client->get_resource_uri(.NEW_REGISTRATION)
      ->then(lambda (string uri) {
        // Request a new registration
        return client->post(uri, payload);
      })
      ->then(lambda (.HTTP.Success ok) {
        TRACE("Second then: %O\n", ok);
        TRACE("Headers: %O\n", ok->headers);
        TRACE("Data: %O\n", ok->data);

        // exit(1);

        if (ok->status == Protocols.HTTP.HTTP_CREATED) {
          mixed data = Standards.JSON.decode(ok->data);
          TRACE("Data2: %O\n", data);

          if (ok->headers->link) {
            payload = Standards.JSON.decode(ok->data);
            string location = ok->headers->location;
            sscanf(ok->headers->link, "<%s>", string link);
            payload->agreement = link;
            payload->url = location;
            TRACE("Payload is: %O\n", payload);
            p->success(.Account(payload, client->get_key()));
            return;
          }
          else {
            TRACE("***** MAYBE WE ARE GOOD! %O *****\n",
              Standards.JSON.decode(ok->data));
          }
        }

        p->failure(.Error("Unable to create account\n"));

      })
      ->thencatch(lambda (.Error err) {
        if (object_program(err) == .AcmeError) {
          if (err->status == Protocols.HTTP.HTTP_CONFLICT &&
              err->headers->location)
          {
            p->success(err->headers->location);
            return;
          }
        }

        p->failure(err);
      });
  };

  // low_new_registration(agreement);

  client->get_tos()
    ->then(lambda (string agreement) {
      TRACE("Got agreement URL: %s\n", agreement);
      low_new_registration(agreement);
    })
    ->thencatch(lambda (.Error e) {
      TRACE("Failed getting terms of service\n");
      p->failure(e);
    });

  return p->future();
}

