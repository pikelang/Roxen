// -*- Pike -*-
// $Id: variables.h,v 1.16 2004/05/19 19:14:46 mast Exp $
// Fallback-resources, don't change here.

private static constant errors =
([
  100:"Continue",
  101:"Switching Protocols",
  102:"Processing",

  200:"OK",
  201:"Created",		// URI follows
  202:"Accepted",
  203:"Non-Authoritative Information",	// Provisional Information
  204:"No Content",
  205:"Reset Content",
  206:"Partial Content",	// Byte Ranges
  207:"Multi-Status",
  226:"IM Used",		// RFC 3229

  300:"Multiple Choices",	// Moved
  301:"Moved Permanently",	// Permanent Relocation
  302:"Found",
  303:"See Other",
  304:"Not Modified",
  305:"Use Proxy",
  // RFC 2616 10.3.7: 306 not used but reserved.
  307:"Temporary Redirect",

  400:"Bad Request",
  401:"Unauthorized",		// Access denied
  402:"Payment Required",
  403:"Forbidden",
  404:"Not Found",		// No such file or directory
  405:"Method Not Allowed",
  406:"Not Acceptable",
  407:"Proxy Authentication Required", // Proxy authorization needed
  408:"Request Timeout",
  409:"Conflict",
  410:"Gone",			// This document is no more. It has gone to meet its creator. It is gone. It will not be back. Give up. I promise. There is no such file or directory.",
  411:"Length Required",
  412:"Precondition Failed",
  413:"Request Entity Too Large",
  414:"Request-URI Too Long",
  415:"Unsupported Media Type",
  416:"Requested Range Not Satisfiable",
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
  502:"Bad Gateway",		// Gateway Timeout
  503:"Service Unavailable",
  504:"Gateway Timeout",
  505:"HTTP Version Not Supported",
  506:"Variant also negotiates",
  507:"Insufficient Storage",
]);

