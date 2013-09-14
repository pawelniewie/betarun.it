'use strict';
angular.module('$strap.directives').directive('bsDatetimepicker', [
  '$timeout',
  '$strapConfig',
  function ($timeout, $strapConfig) {
    var isAppleTouch = /(iP(a|o)d|iPhone)/g.test(navigator.userAgent);
    var regexpMap = function regexpMap(language) {
      language = language || 'en';
      return {
        '/': '[\\/]',
        '-': '[-]',
        '.': '[.]',
        ' ': '[\\s]',
        'dd': '(?:(?:[0-2]?[0-9]{1})|(?:[3][01]{1}))',
        'd': '(?:(?:[0-2]?[0-9]{1})|(?:[3][01]{1}))',
        'mm': '(?:[0]?[1-9]|[1][012])',
        'm': '(?:[0]?[1-9]|[1][012])',
        'DD': '(?:' + $.fn.datetimepicker.dates[language].days.join('|') + ')',
        'D': '(?:' + $.fn.datetimepicker.dates[language].daysShort.join('|') + ')',
        'MM': '(?:' + $.fn.datetimepicker.dates[language].months.join('|') + ')',
        'M': '(?:' + $.fn.datetimepicker.dates[language].monthsShort.join('|') + ')',
        'yyyy': '(?:(?:[1]{1}[0-9]{1}[0-9]{1}[0-9]{1})|(?:[2]{1}[0-9]{3}))(?![[0-9]])',
        'yy': '(?:(?:[0-9]{1}[0-9]{1}))(?![[0-9]])'
      };
    };
    var regexpForDateFormat = function regexpForDateFormat(format, language) {
      var re = format, map = regexpMap(language), i;
      i = 0;
      angular.forEach(map, function (v, k) {
        re = re.split(k).join('${' + i + '}');
        i++;
      });
      i = 0;
      angular.forEach(map, function (v, k) {
        re = re.split('${' + i + '}').join(v);
        i++;
      });
      return new RegExp('^' + re + '$', ['i']);
    };
    return {
      restrict: 'A',
      require: '?ngModel',
      link: function postLink(scope, element, attrs, controller) {
        var options = angular.extend({ autoclose: true }, $strapConfig.datetimepicker || {}), type = attrs.dateType || options.type || 'date';
        angular.forEach([
          'format',
          'formatType',
          'weekStart',
          'calendarWeeks',
          'startDate',
          'endDate',
          'daysOfWeekDisabled',
          'autoclose',
          'startView',
          'minViewMode',
          'todayBtn',
          'todayHighlight',
          'keyboardNavigation',
          'language',
          'forceParse',
          'linkFormat',
          'linkField',
          'todayHighlight'
        ], function (key) {
          if (angular.isDefined(attrs[key]))
            options[key] = attrs[key];
        });
        var language = options.language || 'en',
          format = isAppleTouch ? 'yyyy-mm-dd hh:mm' : (attrs.dateFormat || options.format || $.fn.datetimepicker.dates[language] && $.fn.datetimepicker.dates[language].format || 'mm/dd/yyyy hh:mm'),
          formatType = attrs.formatType || options.formatType || 'standard',
          linkFormat = attrs.linkFormat || options.format,
          dateFormatRegexp = regexpForDateFormat(format, language);
        if (controller) {
          controller.$formatters.unshift(function (modelValue) {
            return type === 'date' && angular.isString(modelValue) && modelValue ? $.fn.datetimepicker.DPGlobal.parseDate(modelValue, $.fn.datetimepicker.DPGlobal.parseFormat(linkFormat, formatType), language) : modelValue;
          });
          controller.$parsers.unshift(function (viewValue) {
            if (!viewValue) {
              controller.$setValidity('date', true);
              return null;
            } else if (type === 'date' && angular.isDate(viewValue)) {
              controller.$setValidity('date', true);
              return viewValue;
            } else if (angular.isString(viewValue) && dateFormatRegexp.test(viewValue)) {
              controller.$setValidity('date', true);
              if (isAppleTouch)
                return new Date(viewValue);
              return type === 'string' ? viewValue : $.fn.datetimepicker.DPGlobal.parseDate(viewValue, $.fn.datetimepicker.DPGlobal.parseFormat(format), language);
            } else {
              controller.$setValidity('date', false);
              return undefined;
            }
          });
          controller.$render = function ngModelRender() {
            if (isAppleTouch) {
              var date = controller.$viewValue ? $.fn.datetimepicker.DPGlobal.formatDate(controller.$viewValue, $.fn.datetimepicker.DPGlobal.parseFormat(format), language) : '';
              element.val(date);
              return date;
            }
            if (!controller.$viewValue)
              element.val('');
            return element.datetimepicker('update', controller.$viewValue);
          };
        }
        if (isAppleTouch) {
          element.prop('type', 'date').css('-webkit-appearance', 'textfield');
        } else {
          if (controller) {
            element.on('changeDate', function (ev) {
              scope.$apply(function () {
                controller.$setViewValue(type === 'string' ? element.val() : ev.date);
              });
            });
          }
          element.addClass("date");
          element.datetimepicker(angular.extend(options, {
            format: format,
            language: language
          }));
          scope.$on('$destroy', function () {
            var datetimepicker = element.data('datetimepicker');
            if (datetimepicker) {
              datetimepicker.picker.remove();
              element.data('datetimepicker', null);
            }
          });
          attrs.$observe('startDate', function (value) {
            element.datetimepicker('setStartDate', value);
          });
          attrs.$observe('endDate', function (value) {
            element.datetimepicker('setEndDate', value);
          });
        }
        var component = element.siblings('[data-toggle="datetimepicker"]');
        if (component.length) {
          component.on('click', function () {
            if (!element.prop('disabled')) {
              element.trigger('focus');
            }
          });
        }
      }
    };
  }
]);