// This file is part of ChiliMoon.
// Copyright © 1996 - 2001, Roxen IS.
// $Id: roxenlib.pike,v 1.222 2004/05/30 00:22:13 _cvs_stephen Exp $

//#pragma strict_types

#include <roxen.h>
#include <config.h>
#include <stat.h>
#include <variables.h>

inherit Roxen;

//! The old Roxen standard library. Everything defined in this class,
//! i.e. not the inherited, is to be considered deprecated. The
//! inherited functions are available directly from @[Roxen] instead.

//! Converted the integer @[color] into a six character hexadecimal
//! value prepended with "#", e.g. "#FF8C00". Does the same thing as
//! @code{
//!    sprintf("#%06X", color);
//! @}
static string conv_hex( int color )
{
  return sprintf("#%06X", color);
}

//! Creates a proxy authentication needed response (error 407)
//! if no authentication is given, access denied (error 403)
//! on failed authentication and 0 otherwise.
mapping proxy_auth_needed(RequestID id)
{
  int|mapping res = id->conf->check_security(proxy_auth_needed, id);
  if(res)
  {
    if(res==1) // Nope...
      return http_low_answer(403, "You are not allowed to access this proxy");
    if(!mappingp(res))
      return 0; // Error, really.
    res->error = 407;
    return [mapping]res;
  }
  return 0;
}

//! Figures out the filename of the file which defines the program
//! for this object. Please use __FILE__ instead if possible.
string program_filename()
{
  return master()->program_name(this)||"";
}

//! Returns the directory part of @[program_filename()].
string program_directory()
{
  array(string) p = program_filename()/"/";
  return (sizeof(p)>1? p[..sizeof(p)-2]*"/" : getcwd());
}

//! Creates an HTTP response string from the internal
//! file representation mapping @[file].
static string http_res_to_string( mapping file, RequestID id )
{
  mapping(string:string|array(string)) heads=
    ([
      "Content-type":[string]file["type"],
      "Server":replace(core.version(), " ", "·"),
      "Date":http_date([int]id->time)
      ]);

  if(file->encoding)
    heads["Content-Encoding"] = [string]file->encoding;

  if(!file->error)
    file->error=200;

  if(file->expires)
      heads->Expires = http_date([int]file->expires);

  if(!file->len)
  {
    if(objectp(file->file))
      if(!file->stat && !(file->stat=([mapping(string:mixed)]id->misc)->stat))
	file->stat = (array(int))file->file->stat();
    array fstat;
    if(arrayp(fstat = file->stat))
    {
      if(file->file && !file->len)
	file->len = fstat[1];

      heads["Last-Modified"] = http_date([int]fstat[3]);
    }
    if(stringp(file->data))
      file->len += strlen([string]file->data);
  }

  if(mappingp(file->extra_heads))
    heads |= file->extra_heads;

  if(mappingp(([mapping(string:mixed)]id->misc)->moreheads))
    heads |= ([mapping(string:mixed)]id->misc)->moreheads;

  array myheads=({id->prot+" "+
		  replace (file->rettext||errors[file->error], "\n", " ")});
  foreach(indices(heads), string h)
    if(arrayp(heads[h]))
      foreach([array(string)]heads[h], string tmp)
	myheads += ({ `+(h,": ", tmp)});
    else
      myheads +=  ({ `+(h, ": ", heads[h])});


  if(file->len > -1)
    myheads += ({"Content-length: " + file->len });
  string head_string = (myheads+({"",""}))*"\r\n";

  if(id->conf) {
    id->conf->hsent+=strlen(head_string||"");
    if(id->method != "HEAD")
      id->conf->sent+=(file->len>0 ? file->len : 1000);
  }
  if(id->method != "HEAD")
    head_string+=(file->data||"")+(file->file?file->file->read():"");
  return head_string;
}

//! Returns the dimensions of the file @[gif] as
//! a string like @tt{"width=17 height=42"@}. Use
//! @[Image.Dims] instead.
static string gif_size(Stdio.File gif)
{
  array(int) xy=Image.Dims.get(gif);
  return "width="+xy[0]+" height="+xy[1];
}

//! Returns @[x] to the power of @[y].
static int ipow(int x, int y)
{
  return (int)pow(x, y);
}

//! Compares @[a] with @[b].
//!
//! If both @[a] & @[b] contain only digits, they will be compared
//! as integers, and otherwise as strings.
//!
//! @returns
//!   @int
//!     @value 1
//!       a > b
//!     @value 0
//!       a == b
//!     @value -1
//!       a < b
//!   @endint
static int compare( string a, string b )
{
  if (!a)
    if (b)
      return -1;
    else
      return 0;
  else if (!b)
    return 1;
  else if ((string)(int)a == a && (string)(int)b == b)
    if ((int )a > (int )b)
      return 1;
    else if ((int )a < (int )b)
      return -1;
    else
      return 0;
  else
    if (a > b)
      return 1;
    else if (a < b)
      return -1;
    else
      return 0;
}

//! Works like @[Roxen.parse_rxml()], but also takes the optional
//! arguments @[file] and @[defines].
string parse_rxml(string what, RequestID id,
			 void|Stdio.File file,
			 void|mapping(string:mixed) defines)
{
  if(!objectp(id)) error("No id passed to parse_rxml\n");
  return id->conf->parse_rxml( what, id, file, defines );
}
