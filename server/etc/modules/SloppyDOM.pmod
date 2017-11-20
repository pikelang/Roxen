// Once we were here..
inherit Parser.XML.SloppyDOM;

class DocumentWrapper
//! Class designed to emulate SloppyDOM.Document, but without cyclic
//! references. So, when an instance of this class is destructed
//! (e.g. because it loses the last reference) the wrapped
//! SloppyDOM.Document will be destructed automatically, thereby
//! wiping the cyclic structures contained in it.
{
  Document wrapped;

  protected mixed `->(mixed idx)
  {
    return predef::`->(wrapped, idx);
  }

  protected mixed `[](mixed idx)
  {
    return predef::`[](wrapped, idx);
  }

  protected mixed `->=(mixed idx, mixed value)
  {
    return predef::`->=(wrapped, idx, value);
  }

  protected mixed `[]=(mixed idx, mixed value)
  {
    return predef::`[]=(wrapped, idx, value);
  }

  protected array(string) _indices()
  {
    return indices (wrapped);
  }

  protected string _sprintf (int flag)
  {
    return sprintf ("DocumentWrapper(%s)", wrapped->_sprintf (flag));
  }

  protected void create (object _wrapped)
  {
    wrapped = _wrapped;
  }

  protected void destroy()
  {
    destruct (wrapped);
  }
}

Document|DocumentWrapper parse (string source, void|int raw_values)
{
  return DocumentWrapper (::parse (source, raw_values));
}
