// -*- Pike -*-
// $Id: variables.h,v 1.7 1999/04/21 14:46:50 grubba Exp $
// Fallback-resources, don't change here.

private static constant errors=
([
  100:"100 Continue",
  101:"101 Switching Protocols",
  200:"200 OK",
  201:"201 URI follows",	// Created
  202:"202 Accepted",
  203:"203 Provisional Information",	// Non-Authoritative Information
  204:"204 No Content",
  205:"205 Reset Content",
  206:"206 Partial Content",
  
  300:"300 Moved",			// Multiple Choices
  301:"301 Permanent Relocation",
  302:"302 Temporary Relocation",
  303:"303 Temporary Relocation method and URI",
  304:"304 Not Modified",
  305:"305 Use Proxy",

  400:"400 Bad Request",
  401:"401 Access denied",		// Unauthorized
  402:"402 Payment Required",
  403:"403 Forbidden",
  404:"404 No such file or directory.",
  405:"405 Method not allowed",
  406:"406 Not Acceptable",
  407:"407 Proxy authorization needed",
  408:"408 Request timeout",
  409:"409 Conflict",
  410:"410 This document is no more. It has gone to meet its creator. It is gone. It will not be back. Give up. I promise. There is no such file or directory.",
  411:"411 Length Required",
  412:"412 Precondition Failed",
  413:"413 Request Entity Too Large",
  414:"414 Request-URI Too Large",
  415:"415 Unsupported Media Type",
  
  500:"500 Internal Server Error.",
  501:"501 Not Implemented",
  502:"502 Gateway Timeout",
  503:"503 Service unavailable",
  504:"504 Gateway Time-out",
  505:"505 HTTP Version not supported",
]);

