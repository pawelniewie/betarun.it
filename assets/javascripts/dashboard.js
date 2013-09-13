//= require assets/js/jquery.ui.widget
//= require assets/js/jquery.knob
//= require assets/js/jquery.iframe-transport
//= require assets/js/jquery.fileupload
//= require directive
//= require "angular-filters"
//= require "ng-time-relative"
var kfz = angular.module('appcasts', ['drag-drop-upload', 'frapontillo.ex.filters', 'timeRelative']).
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
}])
.config(['$routeProvider', function($routeProvider) {
	$routeProvider
		.when('/', {controller: VersionsCtrl, templateUrl: '/partials/versions'})
		.when('/edit/:versionId', {controller: EditVersionCtrl, templateUrl: '/partials/edit-version'})
		.otherwise({ redirectTo: '/'});
}])
.filter('bytes', function() {
	return function(bytes, precision) {
		if (isNaN(parseFloat(bytes)) || !isFinite(bytes)) return '-';
		if (typeof precision === 'undefined') precision = 1;
		var units = ['bytes', 'kB', 'MB', 'GB', 'TB', 'PB'],
			number = Math.floor(Math.log(bytes) / Math.log(1024));
		return (bytes / Math.pow(1024, Math.floor(number))).toFixed(precision) +  ' ' + units[number];
	};
});

var VersionsCtrl = ['$scope', '$log', 'Appcasts', function VersionsCtrl($scope, $log, Appcasts) {
	$scope.$log = $log;

	$scope.uploadComplete = function(e, data) {
	};

	$scope.uploadProgress = function(progress, e, data) {
		$scope.getAppcast();
	};

	$scope.uploadError = function(e, data) {
	};

	$scope.getAppcast = function getAppcast() {
		Appcasts.get($scope.appcastId, function(data) {
			$scope.appcast = data;
		});
	};

	$scope.saveAppcast = function saveAppcast() {
		$log.info("New value " + $scope.appcast.name);
		Appcasts.put($scope.appcastId, {name: $scope.appcast.name}, function(data) {
			$scope.appcast = data;
		});
	};

	$scope.init = function VersionsCtrlInit(appcastId) {
		$scope.appcastId = appcastId;
		$scope.appcastUrl = "/appcasts/" + appcastId + "/versions";
		$scope.getAppcast();
	};
}];

var EditVersionCtrl = ['$scope', '$log', '$http', '$routeParams', '$location', function($scope, $log, $http, $routeParams, $location) {
	$scope.$log = $log;
	$http.get('/appcasts/' + $scope.appcastId + "/versions/" + $routeParams.versionId).success(function(data) {
		$scope.remote = data;
		$scope.version = angular.copy($scope.remote);
		$scope.isClean = function() {
			return angular.equals($scope.remote, $scope.version);
		};
		$scope.save = function() {
			$http.put('/appcasts/' + $scope.appcastId + "/versions/" + $scope.remote._id, $scope.version).success(function(result) {
				$location.path("/");
			});
		};
		$scope.destroy = function() {
			$http.delete('/appcasts/' + $scope.appcastId + "/versions/" + $scope.remote._id).success(function(result) {
				$location.path("/");
			});
		};
	});
}];