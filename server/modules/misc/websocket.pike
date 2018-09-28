// Protocol support for RFC 6455
//
// $Id$
//
// 2018-09-27 Henrik Grubbström

inherit "module";

#include <module.h>
#include <request_trace.h>

constant cvs_version = "$Id$";
constant thread_safe = 1;
constant module_name = "WebSockets: Protocol support";
constant module_type = MODULE_FIRST;
constant module_doc  = "Adds support for the HTTP extension defined "
  "in <a href='http://rfc.roxen.com/6455'>RFC 6455 (WebSocket)</a>.";
constant module_unique = 1;

#ifdef WS_DEBUG
#define WS_WERROR(X...)	werror(X)
#else /* !WS_DEBUG */
#define WS_WERROR(X...)
#endif /* WS_DEBUG */

Configuration conf;

void create()
{
}

void start(int q, Configuration c)
{
  conf = c;
}

// Operation:
//
// * For syntactically valid WebSocket requests, the
//   method field in the RequestID is set to "WebSocketOpen",
//   the default error_code set to HTTP_BAD and zero returned.
//
// * For requests that don't seem to be WebSocket requests
//   nothing is done, and zero is returned.
//
// * For requests that are upgrade requests to other than
//   websockets, the default error_code is set to HTTP_BAD,
//   and zero returned.
//
// * For other invalid requests an appropriate HTTP_BAD
//   error status is returned.
//
// This means that modules implementing support for WebSockets
// need to check for the method "WebSocketOpen", and then
// return Roxen.upgrade_to_websocket() if appropriate.

mapping(string:mixed)|int(-1..0) first_try(RequestID id)
{
  TRACE_ENTER("Checking if this is a valid websocket request...", this);
  if (id->misc->internal_get) {
    TRACE_LEAVE("No - internal request.");
    return 0;
  }

  if (id->method != "GET") {
    TRACE_LEAVE("No - wrong method.");
    return 0;
  }

  if (!has_prefix(id->prot, "HTTP/") ||
      (id->prot[sizeof("HTTP/")..] < "1.1")) {
    // HTTP/1.1 or later required.
    TRACE_LEAVE("No - not HTTP/1.1 or later.");
    return 0;
  }

  if (!has_value(lower_case(id->request_headers->connection||"")/",",
		 "upgrade")) {
    TRACE_LEAVE("No - no connection: upgrade.");
    return 0;
  }

  if (!has_value(lower_case(id->request_headers->upgrade||"")/",",
		 "websocket")) {
    // Unsupported upgrade header.
    id->misc->error_code = id->misc->error_code || Protocols.HTTP.HTTP_BAD;
    TRACE_LEAVE("No - Unsupported or missing upgrade header.");
    return 0;
  }

  if (id->request_headers["sec-websocket-version"] !=
      (string)13/*Protocols.WebSocket.websocket_version*/) {
    // Unsupported WebSocket version.
    TRACE_LEAVE("No - Unsupported websocket version.");
    return Roxen.http_status(Protocols.HTTP.HTTP_BAD,
			     "Unsupported WebSocket version.") + ([
      "extra_heads": ([
	"Sec-WebSocket-Version": (string)13/*Protocols.WebSocket.websocket_version*/,
      ]),
    ]);
  }

  string raw_key = "";
  catch {
    raw_key = MIME.decode_base64(id->request_headers["sec-websocket-key"]);
  };
  if (sizeof(raw_key) < 16) {
    // Invalid Sec-WebSocet-Key.
    TRACE_LEAVE("No - Invalid Sec-WebSocket-Key.");
    return Roxen.http_status(Protocols.HTTP.HTTP_BAD,
			     "Invalid Sec-WebSocket-Key.");
  }

  TRACE_LEAVE("Yes.");

  // NB: The mixed case in the method ensures that it can't be
  //     set directly from the http request.
  id->method = "WebSocketOpen";
  id->misc->error_code = Protocols.HTTP.HTTP_BAD;

  // Continue request processing.
  return 0;
}
