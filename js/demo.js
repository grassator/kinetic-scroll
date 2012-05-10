(function(){
  // Vertical scroll only (default)
  new KineticScroll(document.getElementById('vertical'), {
    vertical: true,
    horizontal: false,
  });

  // Horizontal scroll only
  new KineticScroll(document.getElementById('horizontal'), {
    vertical: false,
    horizontal: true,
  });

  // Both directions
  new KineticScroll(document.getElementById('both'), {
    vertical: true,
    horizontal: true,
  });

  // Paginated scroll
  new KineticScroll(document.getElementById('paginated'), {
    vertical: false,
    horizontal: true,
    horizontalBar: false,
    paginated: true,
    onPageCountChange: function(pageCount, currentPage) {
      var html = '';
      for (var i = 0; i < pageCount; i++) {
        if (i === currentPage) {
          html += '<span class="current"></span>';
        } else {
          html += '<span></span>';
        }
      }
      document.getElementById('pager').innerHTML = html;
    },
    onCurrentPageChange: function(currentPage) {
      pages = document.querySelectorAll('#pager > span');
      Array.prototype.slice.apply(pages).forEach(function(page) {
        page.className = '';
      });
      pages[currentPage].className = 'current';
    }
  });
})();