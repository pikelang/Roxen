/*global ROXEN, YAHOO, escape, unescape, document, console */

(function () {

  var lib = {

    /**
     * Returns the object as an array.
     * @method array2object
     * @param  {Array}  a  The array.
     * @return {Object}    The result.
     */
    array2object: function (a) {
      var res = {};
      for (var i = 0; i < a.length; i++) {
        res[a[i]] = true;
      }
      return res;
    },

    /**
     * Binds a function to a scope.
     * @method bind
     * @param  {Object}   o Scope.
     * @param  {Function} f Function.
     * @return {Function}   The scoped function.
     */
    bind: function (o, f) {
      return function() {
        return f.apply(o, arguments);
      };
    },

    /**
     * Clones an object.
     * @method clone
     * @param  {Object}   o Object to clone.
     * @return {Object}   The cloned object.
     */
    clone: function (o) {
      function F() {}
      F.prototype = o;
      return new F();
    },

    /**
     * Performs a deep copy of an object or array.
     * @method deepCopy
     * @param  {Object}    obj The array/object to deep copy.
     * @return {Object}    The copy.
     */
    deepCopy: function(obj) {
      //  Borrowed from
      //  http://james.padolsey.com/javascript/deep-copying-of-objects-and-arrays/
      //
      //  FIXME: Replace with clone() in YUI3?
      var out, i, len;
      if (Object.prototype.toString.call(obj) === "[object Array]") {
	out = [ ];
	len = obj.length;
	for (i = 0 ; i < len; i++)
	  out[i] = arguments.callee(obj[i]);
	return out;
      } else if (typeof obj === "object") {
	out = { };
	for (i in obj)
	  out[i] = arguments.callee(obj[i]);
	return out;
      }
      return obj;
    },

    /**
     * Creates a HTMLElement
     * @method createElement
     * @param  {String}      type        Element type.
     * @param  {String}      className   Class name.
     * @param  {Array}       attributes  Array of attributes
     * @return {HTMLElement}             The result.
     */
    createElement: function (type, className, attributes) {
      var el = document.createElement(type);
      if (ROXEN.isString(className)) {
        YAHOO.util.Dom.addClass(el, className);
      }
      for (var i in attributes) {
        if (attributes.hasOwnProperty(i)) {
          el.setAttribute(i, attributes[i]);
        }
      }
      return el;
    },

    /**
     * Creates an object from two arrays
     * The two arrays must be of equal length.
     * @method createObject
     * @param {Array} indices Array of indices.
     * @param {Array} values  Array of values.
     * @return {Object}       The result.
     */
    createObject: function (indices, values) {
      var res = {};
      for (var i = 0; i < indices.length; i++) {
        res[indices[i]] = values[i];
      }
      return res;
    },

    /**
     * Creates an array of objects from from two arrays,
     * where the second array is an array of arrays of values.
     * Indices array and the he arrays of values and must be of equal length.
     * @method createObjects
     * @param {Array} indices Array of indices.
     * @param {Array} values  Array of arrays of values.
     * @return {Array}        The result.
     */
    createObjects: function (indices, values) {
      var res = [];
      for (var i = 0; i < values.length; i++) {
        res.push(ROXEN.createObject(indices, values[i]));
      }
      return res;
    },

    /**
     * Outputs string to Roxen Webserver debug log.
     * @method debugLog
     * @param  {String} s  The string.
     */
    debugLog: function (s) {
      ROXEN.AFS.call("debug-log", {message: s});
    },

    /**
     * Escapes a string for use as an URI component. Like
     * encodeURIComponent, but also encodes ! ' ( ) * which are part
     * of the reserved set in RFC 3987.
     *
     * @method escape
     * @param  {String} s String to encode.
     * @return {String}   The result.
     */
    escapeURIComponent: function (s) {
      return encodeURIComponent (s).
	replace(/!/g, "%21").
	replace(/\x27/g, "%27"). // ' escaped to avoid unbalanced quotes.
	replace(/\(/g, "%28").
	replace(/\)/g, '%29').
	replace(/\*/g, '%2A');
    },

    /**
     * Escapes a string for use in HTML.
     * @method escapeHTML
     * @param  {String} s String to encode.
     * @return {String}   The result.
     */
    escapeHTML: function(s) {
      return s.replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;").
	     replace(/\x27/g,"&apos;").replace(/\x22/g,"&quot;");
    },
    
    /**
     * Unescapes a string for use in HTML.
     * @method unescapeHTML
     * @param  {String} s String to decode.
     * @return {String}   The result.
     */
    unescapeHTML: function(s) {
      return s.replace(/&amp;/g,"&").replace(/&lt;/g,"<").replace(/&gt;/g,">").
             replace(/&apos;/g, "'").replace(/&quot;/g,'"');
    },
    
    /**
     * Filter an array by executing a filter function on each array element
     * and return the result.
     * @method filter
     * @param {Array}    a Array of elements.
     * @param {Function} f Applied function to each element.
     *                     f's argument list is (element, index, array).
     * @param {Object}   o Scope correction.
     * @retrun {Array}     The result.
     */
    filter: function (a, f, o) {
      var result = [];
      for (var i = 0; i < a.length; i++) {
        var r = f.call(o, a[i], i, a);
        if (r) {
          result.push(a[i]);
        }
      }
      return result;
    },

    /**
     * Decode string from UTF8.
     * @method fromUTF8
     * @param  {String} s String to decode.
     * @return {String}   The result.
     */
    fromUTF8: function (s) {
      return decodeURIComponent(escape(s));
    },

    /**
     * Generates an unique id for DOM nodes.
     * @method generateId
     * @return  {String} The result.
     */
    generateId: function () {
      // YUI may warn about "batch called with invalid arguments",
      // but there is no convenient way to avoid it.
      return YAHOO.util.Dom.generateId(null, "roxen-");
    },

    /**
     * Returns a ISO time string from a date object.
     * @method getISOTimeString
     * @param  {Date}   date  Date object (optional).
     * @return {String}       The result.
     */
    getISOTimeString: function (date) {
      function pad(n){
        return n < 10 ? "0" + n : n;
      }
      if (ROXEN.isUndefined(date)) {
        date = new Date();
      }
      return pad(date.getUTCHours()) + ":" +
             pad(date.getUTCMinutes()) + ":" +
             pad(date.getUTCSeconds());
    },

    /**
     * Check if array has any of the object properties.
     * @method hasValue
     * @param  {Array}   a The haystack.
     * @param  {Object}  o The needle.
     * @return {Boolean}   The result.
     */
    hasValue: function (a, o) {
      for (var i = 0; i < a.length; i++) {
        if (o[a[i]]) {
          return true;
        }
      }
      return false;
    },

    /**
     * Check if a value exist in a array.
     * @method inArray
     * @param {Array}   a The haystack.
     * @param {any}     o The needle.
     * @param {boolean}   The result.
     */
    inArray: function (a, o) {
      for (var i = 0; i < a.length; i++) {
        if (a[i] === o) {
          return true;
        }
      }
      return false;
    },

    /**
     * Outputs all arguments to client log.
     * @method log
     */
    log: function () {
      if (typeof console !== "undefined" && console.log) {
        var args = [ ROXEN.getISOTimeString() + ": " ].
          concat(Array.prototype.slice.call(arguments));
        console.log.apply(console, args);
      }
    },

    /**
     * Determines wheather or not the provided object is an array.
     * This an alias for YAHOO.lang.isArray().
     * @method isArray
     * @param {any} o The object being testing
     * @return {boolean} the result
     */
    isArray: YAHOO.lang.isArray,

    /**
     * Determines whether or not the provided object is a boolean.
     * This an alias for YAHOO.lang.isBoolean().
     * @method isBoolean
     * @param {any} o The object being testing
     * @return {boolean} the result
     */
    isBoolean: YAHOO.lang.isBoolean,

    /**
     * Determines whether or not the provided object is a function.
     * This an alias for YAHOO.lang.isFunction().
     * @method isFunction
     * @param {any} o The object being testing
     * @return {boolean} the result
     */
    isFunction: YAHOO.lang.isFunction,

    /**
     * Determines whether or not the provided object is null
     * This an alias for YAHOO.lang.isNull().
     * @method isNull
     * @param {any} o The object being testing
     * @return {boolean} the result
     */
    isNull: YAHOO.lang.isNull,

    /**
     * Determines whether or not the provided object is a legal number.
     * This an alias for YAHOO.lang.isNumber().
     * @method isNumber
     * @param {any} o The object being testing
     * @return {boolean} the result
     */
    isNumber: YAHOO.lang.isNumber,

    /**
     * Determines whether or not the provided object is of type object
     * or function.
     * This an alias for YAHOO.lang.isObject().
     * @method isObject
     * @param {any} o The object being testing
     * @return {boolean} the result
     */
    isObject: YAHOO.lang.isObject,

    /**
     * Determines whether or not the provided object is a string.
     * This an alias for YAHOO.lang.isString().
     * @method isString
     * @param {any} o The object being testing
     * @return {boolean} the result
     */
    isString: YAHOO.lang.isString,

    /**
     * Determines whether or not the provided object is undefined.
     * This an alias for YAHOO.lang.isUndefined().
     * @method isUndefined
     * @param {any} o The object being testing
     * @return {boolean} the result
     */
    isUndefined: YAHOO.lang.isUndefined,

    /**
     * A convenience method for detecting a legitimate non-null value.
     * Returns false for null/undefined/NaN, true for other values,
     * including 0/false/''
     * This an alias for YAHOO.lang.isValue().
     * @method isValue
     * @param o {any} the item to test
     * @return {boolean} true if it is not null/undefined/NaN || false
     */
    isValue: YAHOO.lang.isValue,

    /**
     * Test if string only has US ASCII characters.
     * @method isUSASCII
     * @param  {String} s  The string.
     * @return {Boolean}   The result.
     */
    isUSASCII: function (s) {
      for (var i = 0; i < s.length; i++) {
        var c = s.charCodeAt(i);
        if ((c < 32) || (c > 126)) {
          return false;
        }
      }
      return true;
    },

    /**
     * Trims whitespaces from the beginning of a given string.
     * @method ltrim
     * @param  {String} s The string to trim.
     * @return {String}   The result.
     */
    ltrim: function (s) {
      return s.replace(/^\s+/g, "");
    },

    /**
     * Execute a function on each array element and return the result.
     * @method map
     * @param {Array}    a Array of elements.
     * @param {Function} f Applied function to each element.
     *                     f's argument list is (element, index, array).
     * @param {Object}   o Scope correction.
     * @retrun {Array}     The result.
     */
    map: function (a, f, o) {
      var result = [];
      for (var i = 0; i < a.length; i++) {
        result.push(f.call(o, a[i], i, a));
      }
      return result;
    },

   /**
     * Takes an object and return it as a query string.
     * @method queryify
     * @param  {Object} o The object to queryify.
     * @return {String}   The result
     */
    queryify: function (args) {
      var a = ["?"];
      for (var i in args) {
        if (args.hasOwnProperty(i) &&
            !ROXEN.isUndefined(args[i])) {
	  if (a.length > 1)
	    a.push("&");
          a.push(i.toString());
          a.push("=");
          if (ROXEN.isArray(args[i])) {
            var b = [];
            for (var j = 0; j < args[i].length; j++)
	      b.push(ROXEN.escapeURIComponent(args[i][j]));
            a.push(b.join(","));
          }
          else {
	    a.push(ROXEN.escapeURIComponent(args[i]));
          }
        }
      }
      return a.join("");
    },

    /**
     * Trims whitespaces from the end of a given string.
     * @method rtrim
     * @param  {String} s The string to trim.
     * @return {String}   The result.
     */
    rtrim: function (s) {
      return s.replace(/\s+$/g, "");
    },

    /**
     * Encode string to UTF8.
     * @method toUTF8
     * @param  {String} s String to encode.
     * @return {String}   The result.
     */
    toUTF8: function (s) {
      return unescape(encodeURIComponent(s));
    },

    /**
     * Trims whitespaces from both the beginning and end of a given string.
     * @method trim
     * @param  {String} s The string to trim.
     * @return {String}   The result.
     */
    trim: function (s) {
      return s.replace(/^\s+|\s+$/g, "");
    },

    richtextToPlaintext: function(rich_text) {
      //  Make sure adjacent paragraphs and <br> leaves a space after
      //  removal.
      var tmp_div = document.createElement("div");
      rich_text = rich_text.replace(/<\/div>/gi, " </div>");
      rich_text = rich_text.replace(/<br/gi, " <br");
      tmp_div.innerHTML = rich_text;
      var plain_text = tmp_div.innerText || tmp_div.textContent;
      plain_text = plain_text.replace(/\r\n/g, "\n");
      return ROXEN.trim(plain_text);
    },

    /**
     * Returns type for object.
     * @method typeOf
     * @param  {any} o  The object to test.
     * @return {String} The objects type.
     */
    typeOf: function (o) {
      var s = typeof o;
      if (s === "object") {
        if (o) {
          if (ROXEN.isArray(o)) {
            s = "array";
          }
        } else {
          s = "null";
        }
      }
      return s;
    },

    /**
     * Does variable substitution on a string. It scans through the string
     * looking for expressions enclosed in { } braces. If an expression
     * is found, it is used a key on the object.  If there is a space in
     * the key, the first word is used for the key and the rest is provided
     * to an optional function to be used to programatically determine the
     * value (the extra information might be used for this decision). If
     * the value for the key in the object, or what is returned from the
     * function has a string value, number value, or object value, it is
     * substituted for the bracket expression and it repeats.  If this
     * value is an object, it uses the Object's toString() if this has
     * been overridden, otherwise it does a shallow dump of the key/value
     * pairs.
     * This an alias for YAHOO.lang.substitute().
     * @method substitute
     * @param s {String} The string that will be modified.
     * @param o {Object} An object containing the replacement values
     * @param f {Function} An optional function that can be used to
     *                     process each match.  It receives the key,
     *                     value, and any extra metadata included with
     *                     the key inside of the braces.
     * @return {String} the substituted string
     */
    substitute: YAHOO.lang.substitute,

    /**
     * Enables various debuging options.
     */
    debug: false,

    /**
     * YUI Logger Control object.
     */
    logger: null,
    logger_visible: true,

    /**
     * Toggle the visibility state of the YUI Logger.
     */
    toggle_logger: function () {
      if (this.logger_visible) {
	this.logger.hide();
	this.logger_visible = false;
      } else {
	this.logger.show();
	this.logger_visible = true;
      }
    },

    /**
      * Return a short readable date and time string similar to
      * Sitebuilder.mtime_to_str().
      * @method shortDateTime
      * @param timestamp {Int or Date}
      */
    shortDateTime: function (timestamp, force_include_time, am_pm) {
      var tm;
      if (typeof (timestamp) === "number") tm = new Date(timestamp*1000);
      else tm = timestamp;

      var today = new Date();
      var fmt = "";
      // YUI date formats:
      // http://developer.yahoo.com/yui/docs/YAHOO.util.Date.html
      // FIXME - Use user setting
      var locale = "en-US";
      var date_fmt = "%b %e, %Y";
      var time_fmt = am_pm ? "%l:%M %P" : "%H:%M";

      // The following simplistic calculation is bogus, but the only
      // effect is that we'll return a date instead of "yesterday" if
      // today is the first day of a month where the preceding month
      // was shorter than 31 days.
      var tm_yday = (tm.getMonth() + 1) * 31 + tm.getDate();
      var today_yday = (today.getMonth() + 1) * 31 + today.getDate();

      if (tm.getYear() != today.getYear()) {
        //  Feb 23, 2010
	fmt = date_fmt;
	if (force_include_time)
	  fmt += ", " + time_fmt;
      } else if (tm_yday < today_yday - 1 ||
                 tm_yday > today_yday) {
        //  Feb 23, 14:30
        fmt = date_fmt.replace(", %Y", "");
        fmt = fmt.replace(" %Y", "");
	fmt = fmt + ", " + time_fmt;
      } else if (tm_yday == today_yday - 1) {
        //  Yesterday, 14:30
	fmt = "yesterday, " + time_fmt;
      } else {
        //  Today, 14:30
	fmt = "today, " + time_fmt;
      }
      return YAHOO.util.Date.format(tm, { format: fmt }, locale);
    }
  };

  // Alias for REP compat only. This function used to call the global
  // JS escape() function and additionally encode +. That means it
  // used %uXXXX for wide chars, which isn't valid in URI:s.
  lib.escape = lib.escapeURIComponent;

  YAHOO.lang.augmentObject(ROXEN, lib);
})();
