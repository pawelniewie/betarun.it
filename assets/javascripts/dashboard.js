//= require assets/js/jquery.ui.widget
//= require assets/js/jquery.knob
//= require assets/js/jquery.iframe-transport
//= require assets/js/jquery.fileupload
//= require directive
//= require "angular-filters"
//= require "ng-time-relative"
//= require "bootstrap-datetimepicker"
//= require "angular-datetimepicker"
var kfz = angular.module('appcasts', ['drag-drop-upload', 'frapontillo.ex.filters', 'timeRelative', '$strap.directives']).
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
}]);

var VersionsCtrl = ['$scope', '$log', '$http', '$location', 'Appcasts', function VersionsCtrl($scope, $log, $http, $location, Appcasts) {
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

	$scope.publishVersion = function(versionId, publish) {
		$http.put(Appcasts.version($scope.appcastId, versionId), {draft: !publish}).success(function(data) {
			$scope.loadAppcast();
		});
	};

	$scope.editVersion = function(versionId) {
		$location.path("/edit/" + versionId);
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
		if (data.pubDate) {
			data.pubDate = moment(data.pubDate).toDate();
		}
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