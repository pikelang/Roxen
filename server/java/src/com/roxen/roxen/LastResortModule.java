package com.chilimoon.chilimoon;

/**
 * @author <a href="mailto:tomp@uk.uu.net">Tom Palmer</a>
 */
public interface LastResortModule {
  /**
   * This method is called when all previous modules have failed to return a response.
   *
   * @param id Request Information object associated with the request.
   * @return null if you didn't handle the request, otherwise your result
   */
  public ChiliMoonResponse last_resort(ChiliMoonRequest id);
}
