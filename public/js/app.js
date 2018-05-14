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

angular.module('bhack', [])
  .controller('LoginController', function($http, $location) {
    var vm = angular.extend(this, {
      loggedIn: false,
      working: false,
      email: '',
      password: '',
    });

    angular.extend(this, {
      login: login
    });

    ////////

    function login() {
      vm.working = true;

      var data = {
        email: vm.email,
        password: vm.password,
      };

      var req = {
        method: 'POST',
        url: '/login',
        headers: { "Content-type": "application/json" },
        data: data
      }

      $http(req).then(function(data){
        window.location.href = '/members';
      }, function(err) {
        vm.working = false;
        console.error(err);
      });
    }
  });
