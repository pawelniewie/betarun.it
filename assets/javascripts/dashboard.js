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
		appcast: function(appcastId) {
			return "/appcasts/" + appcastId;
		},
		versions: function(appcastId) {
			return this.appcast(appcastId) + "/versions";
		},
		version: function(appcastId, versionId) {
			return this.appcast(appcastId) + "/versions/" + versionId;
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

var VersionsCtrl = ['$scope', '$log', '$http', 'Appcasts', function VersionsCtrl($scope, $log, $http, Appcasts) {
	$scope.$log = $log;

	$scope.uploadComplete = function(e, data) {
	};

	$scope.uploadProgress = function(progress, e, data) {
		$scope.loadAppcast();
	};

	$scope.uploadError = function(e, data) {
	};

	$scope.saveAppcast = function() {
		$log.info("New value " + $scope.appcast.name);
		$http.put(Appcasts.appcast($scope.appcastId), {name: $scope.appcast.name}, function(data) {
			$scope.appcast = data;
		});
	};

	$scope.loadAppcast = function() {
		$http.get(Appcasts.appcast($scope.appcastId)).success(function(data) {
			$scope.appcast = data;
		});
	};

	$scope.init = function(appcastId) {
		$scope.appcastId = appcastId;
		$scope.appcastUrl = Appcasts.versions(appcastId);
		$scope.loadAppcast();
	};
}];

var EditVersionCtrl = ['$scope', '$log', '$http', '$routeParams', '$location', 'Appcasts', function($scope, $log, $http, $routeParams, $location, Appcasts) {
	$scope.$log = $log;
	$http.get(Appcasts.version($scope.appcastId, $routeParams.versionId)).success(function(data) {
		$scope.remote = data;
		$scope.version = angular.copy($scope.remote);
		$scope.isClean = function() {
			return angular.equals($scope.remote, $scope.version);
		};
		$scope.save = function() {
			$http.put(Appcasts.version($scope.appcastId, $scope.remote._id), $scope.version).success(function(result) {
				$location.path("/");
				$scope.loadAppcast();
			});
		};
		$scope.destroy = function() {
			$http.delete(Appcasts.version($scope.appcastId, $scope.remote._id)).success(function(result) {
				$location.path("/");
				$scope.loadAppcast();
			});
		};
	});
}];