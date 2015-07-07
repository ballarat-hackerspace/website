$(document).ready(function() {

  /* ======= Twitter Bootstrap hover dropdown ======= */
  /* Ref: https://github.com/CWSpear/bootstrap-hover-dropdown */
  /* apply dropdownHover to all elements with the data-hover="dropdown" attribute */

  $('[data-hover="dropdown"]').dropdownHover();

  /* ======= jQuery Responsive equal heights plugin ======= */
  /* Ref: https://github.com/liabru/jquery-match-height */

  $('#who .item-inner').matchHeight();
  $('#testimonials .item-inner .quote').matchHeight();
  $('#latest-blog .item-inner').matchHeight();
  $('#services .item-inner').matchHeight();
  $('#team .item-inner').matchHeight();

  /* ======= jQuery Placeholder ======= */
  /* Ref: https://github.com/mathiasbynens/jquery-placeholder */

  $('input, textarea').placeholder();

  /* ======= jQuery FitVids - Responsive Video ======= */
  /* Ref: https://github.com/davatron5000/FitVids.js/blob/master/README.md */
  $(".video-container").fitVids();


  /* ======= Fixed Header animation ======= */

  $(window).on('scroll', function() {
    if ($(window).scrollTop() > 80) {
      $('#header').addClass('header-shrink');
    }
    else {
      $('#header').removeClass('header-shrink');
    }
  });
});
