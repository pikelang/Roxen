// jshint esversion: 6

(function(window, document) {
  'use strict';

  // Handle all elements with a data-href attribute
  const handleDataHref = function(el, e) {
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
  const handleDataSubmit = function(el, e) {
    const name = el.getAttribute('name') || '';
    // In the old A-IF the buttons we're images and when an input#type=image
    // button is clicked *.x and *.y variables are added. Some code in
    // config_tags.pike rely on the *.x so lets emulate it.
    el.setAttribute('name', name + '.x');
    return true;
  };

  // Setup the js-popup site/module navigation
  const makeSiteNavJs = function(base) {
    let current = null;
    const mds = base.querySelectorAll('.module-group');
    // Not all browsers handle forEach on node lists
    [].forEach.call(mds, item => {
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

        const child = item.querySelector('ul');
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
  const handleResolvePathToggle = function(src, e) {
    const inner = src.parentNode.querySelector('.inner');
    inner.classList.toggle('hidden');
    src.classList.toggle('open');
    src.classList.toggle('closed');
  };

  // Trigger a custom `event` on `el`
  const trigger = function(el, event, options) {
    let ev;
    if (window.CustomEvent) {
      ev = new window.CustomEvent(event, options);
    }
    else {
      ev = document.createEvent('CustomEvent');
      ev.initCustomEvent(ev, true, true, options);
    }

    el.dispatchEvent(ev);
    return ev.returnValue;
  };

  // On DOM ready
  document.addEventListener('DOMContentLoaded',
    function() {
      let siteNavJs;

      // Delegate all click events
      document.addEventListener('click',
        function(e) {
          if (e.defaultPrevented) {
            e.stopPropagation();
            return false;
          }

          const src = e.srcElement || e.target;
          const ds  = src.dataset;

          if (siteNavJs) {
            const pop = siteNavJs.querySelector('.popup.open');

            if (pop) {
              return trigger(pop.parentNode.firstElementChild, 'click');
            }
          }

          if (ds.href) {
            return handleDataHref(src, e);
          }
          else if (ds.submit !== undefined) {
            return handleDataSubmit(src, e);
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

      const gotoSelects = document.querySelectorAll('select[data-goto]');
      if (gotoSelects) {
        gotoSelects.forEach(sel => {
          sel.addEventListener('change',
            e => {
              const my = e.srcElement || e.target;
              const url =  my.options[my.selectedIndex].value;

              if (url) {
                document.location.href = url;
              }
            });
        });
      }
    });

}(window, document));
