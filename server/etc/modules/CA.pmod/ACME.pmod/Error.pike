#pike __REAL_VERSION__

inherit Error.Generic;

protected void create(strict_sprintf_format format, sprintf_args ... args)
{
  ::create(sprintf(format, @args), backtrace());
}

protected variant void create(.HTTP.Failure err)
{
  string s = err->message;

  if (!s) {
    if (err->status) {
      s = err->status + " " + err->status_description;
    }
    else {
      s = "Unknown HTTP error";
    }

    if (err->url) {
      s += ": " + err->url;
    }
    else {
      s += ".";
    }
  }

  create(s);
}
