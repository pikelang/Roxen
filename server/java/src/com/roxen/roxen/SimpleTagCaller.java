/*
 * $Id: SimpleTagCaller.java,v 1.4 2000/02/21 18:30:46 marcus Exp $
 *
 */

package com.roxen.roxen;

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

  /** If set, the tag doesn't accept content. */
  public static final int FLAG_EMPTY_ELEMENT = 0x00000001;

  /** Never apply any prefix to this tag. */
  public static final int FLAG_NO_PREFIX = 0x00000002;

  /** Don't preparse the content with the PHtml parser. */
  public static final int FLAG_DONT_PREPARSE = 0x00000040;

  /** Postparse the result with the PHtml parser. */
  public static final int FLAG_POSTPARSE = 0x00000080;

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
   * @param  frame     the parse frame
   * @return           the result of handling the tag
   */
  public String tagCalled(String tag, Map args, String contents,
			  RoxenRequest id, Frame frame);

}
