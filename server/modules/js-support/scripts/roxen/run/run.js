(function() {

  ROXEN.run = {};

  /**
   * Executed after system load.
   * @method main
   */
  ROXEN.main = function(options) {
    ROXEN.AFS.init(options);
  };
})();
