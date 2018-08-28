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
  .directive('bhTime', function() {
    return {
      restrict: 'E',
      scope: {
        epoch: '@',
        format: '@?'
      },
      template: '<span>{{time()}}</span>',
      link: function(scope, el, attrs) {
        scope.time = function() {
          var m = moment.unix(scope.epoch);
          var f = scope.format || 'YYYY-MM-DD HH:mm:ss (Z)';
          return m.format(f);
        }
      }
    };
  })
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
        window.location.href = '/members/profile/me';
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

  })
  .controller('StreamController', function($http, $timeout, $window) {
    var vm = angular.extend(this, {
      name: $window.streamName,
      stream: $window.streamJson.items,
      relative: [],
      showMore: false,
      connected: false,
    });

    angular.extend(this, {
      connect: connect,
      fetchMore: fetchMore,
      formatConnectedState: formatConnectedState,
    });

    activate();

    ////////

    function activate() {
      // initial fetch of at least 10 items
      vm.relative = !!$window.streamJson.relative ? $window.streamJson.relative : [];
      vm.showMore = vm.relative.length > 0 && vm.stream.length >= 10;

      connect();
    }

    function connect() {
      console.debug('WS: connecting ...');
      var url = 'ws://' + location.hostname + ':' + location.port + '/meta/streams-ws';
      var ws = new WebSocket(url);

      ws.onclose = function() {
        console.debug('WS: closed!');
        $timeout(function() {vm.connected = false;}, 0);
        $timeout(connect, 10000);
      };

      ws.onopen = function () {
        console.debug('WS: connected.');
        $timeout(function() {vm.connected = true;}, 0);
      };

      ws.onerror = function() {
        console.debug('WS: error!');
      };

      ws.onmessage = function (msg) {
        var res = JSON.parse(msg.data);

        if (res.hasOwnProperty('stream') && res.stream === vm.name) {
          $timeout(function() {
            vm.stream.unshift({
              data: res.data,
              timestamp: res.timestamp,
            });
          }, 0);
        }
      };
    }

    function fetchMore() {
      $http.get('/meta/streams/' + vm.name + '.json?relative_timestamp=' + vm.relative[0] + '&relative_id=' + vm.relative[1])
        .then(function(res) {
          // append our new results
          vm.stream.push.apply(vm.stream, res.data.items);

          // update
          if (res.data.hasOwnProperty('relative')) {
            vm.relative = res.data.relative;
          } else {
            vm.relative = [];
          }

          vm.showMore = vm.relative.length > 0 && res.data.items.length >= 10;
        }, function(err) {
          console.error(err);
        });
    }

    function formatConnectedState() {
      return vm.connected ? 'Online' : 'Offline';
    }
  })
  .controller('StreamsController', function($http, $timeout, $window) {
    var vm = angular.extend(this, {
      connected: false,
      streams: $window.streamsJson.items,
    });

    angular.extend(this, {
      connect: connect,
    });

    activate();

    ////////

    function activate() {
      connect();
    }

    function connect() {
      console.debug('WS: connecting ...');
      var url = 'ws://' + location.hostname + ':' + location.port + '/meta/streams-ws';
      var ws = new WebSocket(url);

      ws.onclose = function() {
        console.debug('WS: closed.');
        $timeout(function() {vm.connected = false;}, 0);
        $timeout(connect, 5000);
      };

      ws.onopen = function () {
        console.debug('WS: connected.');
        $timeout(function() {vm.connected = true;}, 0);
      };

      ws.onerror = function() {
        console.debug('WS: error!');
      };

      ws.onmessage = function (msg) {
        var res = JSON.parse(msg.data);

        $timeout(function() {
          vm.streams.unshift(res);

          // truncate size to 15 entries
          if (vm.streams.length > 15) {
            vm.streams.pop() 
          }
        }, 0);
      };
    }
  });
