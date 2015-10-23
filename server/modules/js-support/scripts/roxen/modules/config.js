/*global ROXEN */

/**
 * The configuration object.
 *
 * @module config
 * @class config
 * @namespace ROXEN
 * @static
 */
ROXEN.config = function () {
  /**
   * A client unique identifier.
   *
   * @property session
   * @type {String}
   */
  var session = Math.uuid();

  return {
    session: session
  };
}();
