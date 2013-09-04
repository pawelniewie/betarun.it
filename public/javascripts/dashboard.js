var kfz = angular.module('appcasts', []).
	factory('AppCasts', ['$http', function($http) {
		return {
			get: function(appcastId, callback) {
				$http.get('/appcasts/' + appcastId).success(function(data) {
					callback(data);
				});
			}
		};
	}]).
	config(function($routeProvider) {
		$routeProvider.when('/', {controller: VersionsCtrl, templateUrl: 'versions.html'})
			.otherwise({ redirectTo: '/'});
	});

function VersionsCtrl($scope, AppCasts) {
	$scope.init = function VersionsCtrlInit(appcastId) {
		$scope.appcastId = appcastId;
		AppCasts.get($scope.appcastId, function(data) {
			$scope.appcast = data;
		});
	};
};