// jshint esversion: 5

(function(window, document, R) {
  'use strict';

  // Handle all elements with a data-href attribute
  var handleDataHref = function(el, e) {
    e.preventDefault();
    var url = el.dataset.href;

    if (el.getAttribute('disabled')) {
      return false;
    }

    if (el.dataset.target) {
      // window[el.dataset.target].location.href = url;
      window.open(url, el.dataset.target);
    }
    else {
      document.location.href = url;
    }

    return false;
  };

  // Handle all elements with a data-submit attribute
  var handleDataSubmit = function(el, e) {
    var name = el.getAttribute('name') || '';
    // In the old A-IF the buttons were images and when an input#type=image
    // button is clicked *.x and *.y variables are added. Some code in
    // config_tags.pike (and else where) rely on the *.x var, so let's
    // emulate it.
    el.setAttribute('name', name + '.x');
    return true;
  };

  // Setup the js-popup site/module navigation
  var makeSiteNavJs = function(base) {
    var current = null;
    var mds = base.querySelectorAll('.module-group');
    // Not all browsers handle forEach on node lists
    [].forEach.call(mds, function(item) {
        var mainA = item.firstElementChild;

        if (item.classList.contains('unfolded')) {
          // No click action on unfolded section
          mainA.addEventListener('click', function(e) {
            e.stopPropagation();
            e.preventDefault();
            return false;
          });

          return;
        }

        var child = item.querySelector('ul');
        child.classList.add('popup');

        mainA.addEventListener('click', function(e) {
          e.preventDefault();
          // e.stopPropagation();

          if (current && current !== child) {
            current.classList.remove('open');
          }

          child.classList.toggle('open');
          current = child.classList.contains('open') ? child : null;

          e.returnValue = false;
          return e.returnValue;
        });
      });
  };

  // Handle toggleing of li's in Resolve Path
  var handleResolvePathToggle = function(src, e) {
    var inner = src.parentNode.querySelector('.inner');
    inner.classList.toggle('hidden');
    src.classList.toggle('open');
    src.classList.toggle('closed');
  };

  var handleToggleNext = function(src, e) {
    var type = src.dataset.toggleNext;
    var next = R.next(src, type);

    if (next) {
      if (!src.classList.contains('toggle-open')) {
        src.classList.add('toggle-open');
      }

      src.classList.toggle('toggle-closed');
      next.classList.toggle('closed');
    }
  };

  var handleToggleCheckbox = function(src, e) {
    var label = R.closest(src, 'label');

    if (src.checked) {
      label.classList.add('checked');
    }
    else {
      label.classList.remove('checked');
    }

    return false;
  };

  var main = function(ctx) {
    ctx = ctx || document;

    R.every(ctx, 'select[data-goto]', function(i, el) {
      el.addEventListener('change', function(e) {
        var url = this.options[this.selectedIndex].value;
        if (url) {
          document.location.href = url;
        }
      });
    });

    R.every(ctx, 'select[data-auto-submit]', function(i, el) {
      el.addEventListener('change', function(e) {
        var f = R.closest(this, 'form');
        if (f) {
          f.submit();
        }
      });
    });

    R.every(ctx, '[data-toggle-cb-event]', function(i, el) {
      el.addEventListener('keydown', function(e) {
        if (e.code === 'Space' || e.code === 'Enter') {
          var c = this.querySelector('[data-toggle-cb]');

          if (c) {
            c.checked = !c.checked;
            handleToggleCheckbox(c, e);
          }
          e.preventDefault();
          return false;
        }
      });
    });

    R.every(ctx, '[data-toggle-submit]', function(i, el) {
      el.addEventListener('change', function(e) {
        R.closest(this, 'form').submit();
      });
    });
  };

  // On DOM ready
  R.domready(
    function() {
      var siteNavJs;

      // Delegate all click events
      document.addEventListener('click',
        function(e) {
          if (e.defaultPrevented) {
            e.stopPropagation();
            return false;
          }

          var src = e.srcElement || e.target;
          var ds  = src.dataset;

          if (siteNavJs) {
            var pop = siteNavJs.querySelector('.popup.open');

            if (pop) {
              return R.trigger(pop.parentNode.firstElementChild, 'click');
            }
          }

          // window.console.log('src: ', src, ds);

          if (ds.href) {
            return handleDataHref(src, e);
          }
          else if (ds.submit !== undefined) {
            return handleDataSubmit(src, e);
          }
          else if (ds.toggleCb !== undefined) {
            return handleToggleCheckbox(src, e);
          }
          else if (ds.toggleNext) {
            handleToggleNext(src, e);
          }
          else if (src.nodeName === 'SPAN' &&
                   src.classList.contains('toggle'))
          {
            return handleResolvePathToggle(src, e);
          }
        });

      siteNavJs = document.querySelector('.site-nav.js');
      if (siteNavJs) {
        makeSiteNavJs(siteNavJs);
      }

      main();
    });

  R.main = main;

}(window, document, rxnlib));
