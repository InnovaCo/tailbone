(function() {
  var _ref,
    __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

  if ((_ref = window.Inn) == null) {
    window.Inn = {};
  }

  Inn.ViewsCollection = (function() {

    function ViewsCollection() {
      this._list = [];
    }

    ViewsCollection.prototype.add = function(view) {
      if (__indexOf.call(this._list, view) < 0) {
        this._list.push(view);
      }
      return this;
    };

    ViewsCollection.prototype.render = function() {
      var view, _i, _len, _ref1, _results;
      _ref1 = this._list;
      _results = [];
      for (_i = 0, _len = _ref1.length; _i < _len; _i++) {
        view = _ref1[_i];
        view.on('destroy', this.viewDestroyHandler);
        view.on('ready', this.viewReadyHandler, this);
        _results.push(view.render());
      }
      return _results;
    };

    ViewsCollection.prototype.viewDestroyHandler = function(view) {
      return this.trigger('destroy', view);
    };

    ViewsCollection.prototype.viewReadyHandler = function() {
      if (this.isRendered()) {
        this.trigger('ready');
        return this.off('ready');
      }
    };

    ViewsCollection.prototype.isRendered = function() {
      return _.filter(this._list, function(view) {
        return !view.ready;
      }).length === 0;
    };

    ViewsCollection.prototype.get = function(id, recursive) {
      if (recursive == null) {
        recursive = false;
      }
      return _.find(this._list, function(view) {
        return view.id === id;
      });
    };

    ViewsCollection.prototype.reset = function() {
      var view, _i, _len, _ref1, _results;
      _ref1 = this._list;
      _results = [];
      for (_i = 0, _len = _ref1.length; _i < _len; _i++) {
        view = _ref1[_i];
        _results.push(view.ready = false);
      }
      return _results;
    };

    ViewsCollection.prototype.destroy = function() {
      var view, _i, _len, _ref1;
      _ref1 = this._list;
      for (_i = 0, _len = _ref1.length; _i < _len; _i++) {
        view = _ref1[_i];
        view.destroy();
      }
      return this;
    };

    ViewsCollection.prototype.isEmpty = function() {
      return !this._list.length;
    };

    _.extend(ViewsCollection.prototype, Backbone.Events);

    return ViewsCollection;

  })();

}).call(this);