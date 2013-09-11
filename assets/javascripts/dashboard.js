//= require assets/js/jquery.ui.widget
//= require assets/js/jquery.knob
//= require assets/js/jquery.iframe-transport
//= require assets/js/jquery.fileupload
//= require directive.js
//= require "angular-filters"
var kfz = angular.module('appcasts', [ 'drag-drop-upload', 'frapontillo.ex.filters']).
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
config(['$routeProvider', function($routeProvider) {
	$routeProvider
		.when('/', {controller: VersionsCtrl, templateUrl: 'versions.html'})
		.otherwise({ redirectTo: '/'});
}]);

var VersionsCtrl = ['$scope', '$log', 'Appcasts', function VersionsCtrl($scope, $log, Appcasts) {
	$scope.appcast = {};
	$scope.$log = $log;

	$scope.uploadComplete = function(e, data) {
	};

	$scope.uploadProgress = function(progress, e, data) {
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
		$scope.appcastUrl = "/appcasts/" + appcastId + "/items";
		$scope.getAppcast();
	};
}];