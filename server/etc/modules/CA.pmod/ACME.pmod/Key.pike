//! This class represents the key that's used to sign request to an ACME server.

#pike __REAL_VERSION__

#include "acme.h"

// Web.encode_jws isn't really used here, but if it's available then so is
// Crypto.Sign.State->jwk
#require constant(Web.encode_jws)

private Crypto.Sign.State _state;

//! Constructor
//!
//! @param state
//!  Obtain via @[.generate_key()] or @[.decode_key()]
protected void create(Crypto.Sign.State state)
{
  this::_state = state;
}

//! Sign the @[payload] into a JWS message.
public string sign(mixed payload, void|mapping extra_headers)
{
  mapping headers = ([
    "typ" : "JWS",
    "jwk" : _state->jwk()
  ]);

  if (extra_headers) {
    headers |= extra_headers;
  }

  TRACE("Sign headers: %O\n", headers);

  // if (!payload->iat) {
  //   payload->iat = time();
  // }

  // TRACE("Sign payload: %O\n", payload);

  string message = string_to_utf8(Standards.JSON.encode(payload));
  return _state->jose_sign(message, headers);
}

//! Getter for the state object
public Crypto.Sign.State `state()
{
  return _state;
}
