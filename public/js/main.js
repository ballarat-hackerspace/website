$(document).ready(function() {
  // initialise header animation
  $(window).on('scroll', function() {
    if ($(window).scrollTop() > 80) {
      $('#header').addClass('header-shrink');
    }
    else {
      $('#header').removeClass('header-shrink');
    }
  });

  // initialise tooltips
  $('[data-toggle="tooltip"]').tooltip();
});
