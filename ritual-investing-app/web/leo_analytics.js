(function () {
  'use strict';

  var measurementId = 'G-07JFEYSPTV';
  window.dataLayer = window.dataLayer || [];
  window.gtag = function () {
    window.dataLayer.push(arguments);
  };

  window.gtag('js', new Date());
  window.gtag('config', measurementId, { send_page_view: false });

  function trackPageView() {
    var route = window.location.hash.replace(/^#/, '');
    var basePath = window.location.pathname.replace(/\/$/, '');
    window.gtag('event', 'page_view', {
      page_title: document.title,
      page_location: window.location.href,
      page_path: basePath + (route || '/')
    });
  }

  trackPageView();
  window.addEventListener('hashchange', trackPageView);
})();
