#pike __REAL_VERSION__

#include "acme.h"

//! Default Crypto module to use. Default is @[Crypto.RSA].
//!
//! @seealso
//!  @[set_crypto_module()], @[get_crypto_module()]
string crypto_module = "RSA";


//! Names of the various ACME services.
enum Resource {
  NEW_REGISTRATION     = "new-reg",
  RECOVER_REGISTRATION = "recover-reg",
  NEW_AUTHORIZATION    = "new-authz",
  NEW_CERTIFICATE      = "new-cert",
  REVOKE_CERTIFICATE   = "revoke-cert",
  REGISTRATION         = "reg",
  AUTHORIZATION        = "authz",
  CHALLENGE            = "challenge",
  CERTIFICATE          = "cert"
}


//! Set what Crypto module to use for the key.
public void set_crypto_module(string name)
{
  if (has_index(Crypto, name)) {
    crypto_module = name;
  }
  else {
    error("Unknown Crypto module: %O.\n", name);
  }
}


//! Returns the name of the crypto module being used.
public string get_crypto_module()
{
  return crypto_module;
}


//! Factory method for creating a @[.Service] object.
public .Service get_service(string directory_uri, .Key key)
{
  return .Service(.Client(directory_uri, key));
}


//! Generate a @[.Key] object. The key size is at least @tt{2048@} bits.
public .Key generate_key()
{
  return generate_key(2048);
}
public variant .Key generate_key(int bits)
{
  if (bits < 2048) {
    error("Keys must be at least 2048 bits.\n");
  }

  Crypto.Sign.State s = Crypto[crypto_module]();
  s->generate_key(bits);

  return .Key(s);
}


//! Encode a @[.Key] object into a Pike encoded string.
//!
//! @seealso
//!  @[.decode_key()]
public string encode_key(.Key key)
{
  Crypto.Sign.State state = key->state;

  mapping c = ([
    "n" : state->get_n(),
    "d" : state->get_d(),
    "e" : state->get_e(),
    "p" : state->get_p(),
    "q" : state->get_q()
  ]);

  return encode_value(c);
}


//! Decode a Pike encoded @[.Key] object into a @[.Key] object.
//!
//! @seealso
//!  @[.encode_key()]
public .Key decode_key(string data)
{
  mapping p = decode_value(data);
  return .Key(Crypto[crypto_module](p));
}


public string encode_account(.Account a)
{
  mapping x = ([
    "a"   : a->raw,
    "key" : encode_key(a->key)
  ]);

  return encode_value(x);
}


public .Account decode_account(string data)
{
  mapping a = decode_value(data);
  return .Account(a->a, decode_key(a->key));
}
