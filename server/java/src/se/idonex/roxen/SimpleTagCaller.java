/*
 * $Id: SimpleTagCaller.java,v 1.1 2000/02/07 17:00:56 marcus Exp $
 *
 */

package se.idonex.roxen;

import java.util.Map;

/**
 * The interface for handling a single specific RXML tag
 *
 * @see ParserModule
 *
 * @version	$Version$
 * @author	marcus
 */

public interface SimpleTagCaller {

  /** The no-flags flag. In case you think 0 is too ugly. */
  public static final int FLAG_NONE = 0x00000000;

  /** If set, the tag accepts non-empty content. */
  public static final int FLAG_CONTAINER = 0x00000001;

  /** Never apply any prefix to this tag. */
  public static final int FLAG_NO_PREFIX = 0x00000002;

  /** Declare the tag to be a socket tag, which accepts plugin tags. */
  public static final int FLAG_SOCKET_TAG = 0x0000004;

  /** Don't preparse the content with the PHtml parser. */
  public static final int FLAG_DONT_PREPARSE = 0x00000040;

  /** Postparse the result with the PHtml parser. */
  public static final int FLAG_POSTPARSE = 0x00000080;

  /** If set, the result will be interpreted in the scope of the
   *  parent tag, rather than in the current one.                */
  public static final int FLAG_PARENT_SCOPE = 0x00000100;

  /** If set, the parser won't apply any implicit arguments. */
  public static final int FLAG_NO_IMPLICIT_ARGS = 0x00000200;

  /** If set, the <tt>tagCalled</tt> method will be called repeatedly until
   *  it returns <tt>null</tt> or no more content is wanted.       */
  public static final int FLAG_STREAM_RESULT = 0x00000400;

  /** If set, the tag supports getting its content in streaming mode:
   *  <tt>tagCalled</tt> will be called repeatedly with successive
   *  parts of the content then.
   *  <p>
   *  <b>Note:</b> It might be obvious, but using streaming is significantly
   *  less effective than nonstreaming, so it should only be done when
   *  big delays are expected.
   */
  public static final int FLAG_STREAM_CONTENT = 0x00000800;

  /** The same as specifying both FLAG_STREAM_RESULT and FLAG_STREAM_CONTENT */
  public static final int FLAG_STREAM = FLAG_STREAM_RESULT|FLAG_STREAM_CONTENT;

  /** If set, the arguments to the tag need not be the same as
   *  the cached args to enable caching.                        */
  public static final int FLAG_CACHE_DIFF_ARGS = 0x00010000;

  /** If set, the content need not be the same to enable caching. */
  public static final int FLAG_CACHE_DIFF_CONTENT = 0x00020000;

  /** If set, the result type need not be the same to enable caching. */
  public static final int FLAG_CACHE_DIFF_RESULT_TYPE = 0x00040000;

  /** If set, the variables with external scope need not have the
   *  same values as the actual variables to enable caching.      */
  public static final int FLAG_CACHE_DIFF_VARS = 0x00080000;

  /** If set, the stack of call frames needs to be the same
   *  to enable caching                                     */
  public static final int FLAG_CACHE_SAME_STACK = 0x00100000;

  /** 
   * If set, the result will be stored in the frame instead of
   * the final result. On a cache hit it'll be executed like the return
   * value from <tt>tagCalled</tt> to produce the result.
   */
  public static final int FLAG_CACHE_EXECUTE_RESULT = 0x00200000;


  /**
   * Return the name of the tag handled by this caller object
   *
   * @return the name of the tag
   */
  public String queryTagName();

  /**
   * Return the mode flags for the tag handled by this caller object
   *
   * @return bitwise or of all flags that apply
   */
  public int queryTagFlags();

  /**
   * Handle a call to the tag handled by this caller object
   *
   * @param  tag       the name of the tag
   * @param  args      any attributes given to the tag
   * @param  contents  the contents of the tag
   * @param  id        the request object
   * @return           the result of handling the tag
   */
  public String tagCalled(String tag, Map args, String contents, RoxenRequest id);

}
