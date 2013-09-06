var kfz = angular.module('appcasts', [ 'drag-drop-upload']).
	factory('Appcasts', ['$http', function($http) {
		return {
			get: function(appcastId, callback) {
				$http.get('/appcasts/' + appcastId).success(function(data) {
					callback(data);
				});
			},
			put: function(appcastId, data, callback) {
				$http.put('/appcasts/' + appcastId, data).success(function(result) {
					callback(result);
				});
			}
		};
	}]).
	config(function($routeProvider) {
		$routeProvider.when('/', {controller: VersionsCtrl, templateUrl: 'versions.html'})
			.otherwise({ redirectTo: '/'});
	});

function VersionsCtrl($scope, $log, Appcasts) {
	$scope.appcast = {};
	$scope.$log = $log;

	$scope.init = function VersionsCtrlInit(appcastId) {
		$scope.appcastId = appcastId;
		Appcasts.get($scope.appcastId, function(data) {
			$scope.appcast = data;
		});
	};

	$scope.saveAppcast = function() {
		$log.info("New value " + $scope.appcast.name);
		Appcasts.put($scope.appcastId, {name: $scope.appcast.name}, function(data) {
			$scope.appcast = data;
		});
	}
};