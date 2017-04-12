// Google reCAPTCHA module

inherit "module";
#include <module.h>

constant module_name = "Tags: Google reCAPTCHA";
string module_doc =
  #"<p>Google reCAPTCHA server side verification integration</p>";

constant module_type = MODULE_TAG;

#define RECAPTCHA_DEBUG

#ifdef RECAPTCHA_DEBUG
# define TRACE(X...)werror("%s:%d: %s",basename(__FILE__),__LINE__,sprintf(X))
#else
# define TRACE(X...)0
#endif

private string api_endpoint;
private mapping(string:string) key_pairs;

void create(Configuration conf)
{
  defvar("api_endpoint",
    Variable.String("https://www.google.com/recaptcha/api/siteverify", 0,
                    "API Endpoint", "Google's API endpoint for the server "
                    "verification"));

  defvar("key_pairs",
    Variable.Mapping(([]), 0, "Site key/Secret pairs",
                     "The \"Name\" column should contain the Site key, "
                     "the \"Value\" column the Secret key"));
}


void start(int when, Configuration conf)
{
  ::start(when, conf);

  key_pairs = query("key_pairs");
  api_endpoint = query("api_endpoint");
}


//! Verify the @[payload] against the Google verification service.
//!
//! @param secret
//!  The reCAPTCHA secret
//! @param payload
//!  The response from a reCAPTCHA
//! @param remote_ip
//!  The visitors ip address.
public bool recaptcha_verify(string secret, string payload,
                             void|string remote_ip)
{
  HTTPClient.Arguments httpargs =
    HTTPClient.Arguments(([
      "variables" : ([
        "secret"   : secret,
        "response" : payload
      ]),
      "maxtime" : 20
    ]));

  if (remote_ip) {
    httpargs->variables->remoteip = remote_ip;
  }

  HTTPClient.Result resp;
  resp = HTTPClient.sync_post(api_endpoint, httpargs);

  if (resp->ok && resp->status == 200) {
    mixed err = catch {
      mapping r = Standards.JSON.decode(resp->data);
      return !!r->success;
    };

    report_error("Failed decoding JSON response: %s\n",
                 describe_error(err));

    return false;
  }

  report_debug("Bad response from reCAPTCHA verification!\n"
               "Status: %s (%d)\n",
               resp->status_description||("Unknown"),
               resp->status);

  return false;
}


class TagIfreCaptchaVerify
{
  inherit RXML.Tag;
  constant name = "if";
  constant plugin_name = "recaptcha-verify";

  mapping(string:RXML.Type) opt_arg_types = ([
    "site-key" : RXML.t_text(RXML.PXml),
    "secret"   : RXML.t_text(RXML.PXml)
  ]);

  int eval(string a, RequestID id, mapping args)
  {
    if (!sizeof(a)) {
      RXML.run_error("Payload is empty!\n");
    }

    string secret;

    if (args->secret && sizeof(args->secret)) {
      secret = args->secret;
    }
    else if (args["site-key"]) {
      secret = key_pairs[args["site-key"]];
    }

    if (!secret) {
      RXML.parse_error("Unresolved \"secret\". Either pass it via the "
                       "\"secret\" attribute, or set up site key/secret "
                       "pairs in the module settings.\n");
    }

    return recaptcha_verify(secret, a, id->remoteaddr);
  }
}


TAGDOCUMENTATION;
#ifdef manual
constant tagdoc = ([

"if#recaptcha-verify" : #"
  <desc type='plugin'>
    <p>Verifies a reCAPTCHA response against Google's verification service.</p>

    <ex-box>
      <if recaptcha-verify='&form.g-recaptcha-response;' secret='...'>
        <!-- Handle form -->
      </if>
      <else>
        You'r a Bot!
      </else>
    </ex-box>

    <p>Either the <tt>site-key</tt> or <tt>secret</tt> attribute is required.</p>
  </desc>

  <attr name='recaptcha-verify' value='&amp;form.g-recaptcha-response;'
        required='1'>
    <p>The response code your form gets populated with when someone does a
     reCAPTCHA.</p>
  </attr>

  <attr name='secret' value='string'>
    <p>The secret key given on your reCAPTCHA settings page on Google.</p>
  </attr>

  <attr name='site-key' value='string'>
    <p>In the module settings you can set up site key/secret pairs. If so you
     don't have to have your secret in laying around in your RXML code, but
     instead give the site key here and the secret will be resolved within
     the module.</p>
  </attr>"

]);
#endif /* manual */
