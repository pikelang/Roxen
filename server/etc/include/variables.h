// -*- Pike -*-
// $Id: variables.h,v 1.13 2004/03/02 20:01:01 mast Exp $
// Fallback-resources, don't change here.

private static constant errors =
([
  100:"Continue",
  101:"Switching Protocols",
  102:"Processing",

  200:"OK",
  201:"URI follows",	// Created
  202:"Accepted",
  203:"Provisional Information",	// Non-Authoritative Information
  204:"No Content",
  205:"Reset Content",
  206:"Partial Content", // Byte Ranges
  207:"Multi-Status",
  226:"IM Used",		// RFC 3229

  300:"Moved",			// Multiple Choices
  301:"Permanent Relocation",
  302:"Found",
  303:"See Other",
  304:"Not Modified",
  305:"Use Proxy",
  // RFC 2616 10.3.7: 306 not used but reserved.
  307:"Temporary Redirect",

  400:"Bad Request",
  401:"Access denied",		// Unauthorized
  402:"Payment Required",
  403:"Forbidden",
  404:"No such file or directory.",
  405:"Method not allowed",
  406:"Not Acceptable",
  407:"Proxy authorization needed",
  408:"Request timeout",
  409:"Conflict",
  410:"This document is no more. It has gone to meet its creator. It is gone. It will not be back. Give up. I promise. There is no such file or directory.",
  411:"Length Required",
  412:"Precondition Failed",
  413:"Request Entity Too Large",
  414:"Request-URI Too Large",
  415:"Unsupported Media Type",
  416:"Requested range not satisfiable",
  417:"Expectation Failed",
  418:"I'm a teapot",
  // FIXME: What is 419?
  420:"Server temporarily unavailable",
  421:"Server shutting down at operator request",
  422:"Unprocessable Entity",
  423:"Locked",
  424:"Failed Dependency",

  500:"Internal Server Error.",
  501:"Not Implemented",
  502:"Gateway Timeout",
  503:"Service unavailable",
  504:"Gateway Time-out",
  505:"HTTP Version not supported",
  506:"Variant aldo negotiates",
  507:"Insufficient Storage",
]);

