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

  // set minimum height
  var minHeight = $(window).height() - $('footer').height();
  $('.page').css('min-height', minHeight + 'px');

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
      canLogin: canLogin,
      login: login
    });

    activate();

    ////////

    function activate() {
      // autofocus email input on modal show
      $('#login').on('shown.bs.modal', function() {
        $('input[name=email]').focus();
      })
    }

    function canLogin() {
      return !vm.working && 
        (vm.email && vm.email.length > 3) &&
        (vm.password && vm.password.length > 0);
    }

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
        window.location.href = '/members/me';
      }, function(err) {
        vm.working = false;
        console.error(err);
      });
    }
  })
  .controller('ProfileController', function($http, $location) {
    var vm = angular.extend(this, {
    });

    angular.extend(this, {
    });


    ////////

  });
