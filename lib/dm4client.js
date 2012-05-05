(function() {
  var DEL, GET, POST, PUT, assocDefChildTypes, async, clarifyParents, createChildTypes, createOnComplete, dataTypeUri, defaultIcon, detachComposite, detachDataType, detachTopic, detachType, fetchComposite, http, iconUri, isChildType, rest, topicEndpoint, topicInfo, topicsByType, typeInfo, typesEndpoint, url, util, _,
    __indexOf = Array.prototype.indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

  _ = require('underscore');

  rest = require('restler');

  async = require('async');

  http = require('http');

  url = require('url');

  util = require('util');

  createOnComplete = function(onSuccess, onError, errorMessage) {
    return function(result, response) {
      if (result instanceof Error) {
        return onError(500, result);
      } else if (response.statusCode === 200) {
        return onSuccess(result);
      } else {
        return onError(response.statusCode, new Error(errorMessage));
      }
    };
  };

  GET = function(getUrl, onSuccess, onError) {
    var onComplete;
    if (onError == null) {
      onError = function(status, error) {
        throw error;
      };
    }
    onComplete = createOnComplete(onSuccess, onError, "requesting " + getUrl + " failed");
    return rest.get(getUrl).on('complete', onComplete);
  };

  DEL = function(delUrl, onSuccess, onError) {
    var onComplete;
    if (onError == null) {
      onError = function(status, error) {
        throw error;
      };
    }
    onComplete = createOnComplete(onSuccess, onError, "deleting " + delUrl + " failed");
    return rest.del(delUrl).on('complete', onComplete);
  };

  POST = function(postUrl, data, onSuccess, onError) {
    var onComplete;
    if (onError == null) {
      onError = function(status, error) {
        throw error;
      };
    }
    onComplete = createOnComplete(onSuccess, onError, "posting to " + postUrl + " failed");
    return rest.postJson(postUrl, data).on('complete', onComplete);
  };

  PUT = function(putUrl, data, onSuccess, onError) {
    var onComplete, options;
    if (onError == null) {
      onError = function(status, error) {
        throw error;
      };
    }
    options = {
      data: JSON.stringify(data),
      headers: {
        'Content-Type': 'application/json'
      }
    };
    onComplete = createOnComplete(onSuccess, onError, "put to " + putUrl + " failed");
    return rest.put(putUrl, options).on('complete', onComplete);
  };

  dataTypeUri = 'dm4.core.data_type';

  iconUri = 'dm4.webclient.icon';

  assocDefChildTypes = ['dm4.core.aggregation_def', 'dm4.core.composition_def'];

  topicEndpoint = 'core/topic';

  topicInfo = topicEndpoint + '/';

  topicsByType = topicEndpoint + '/by_type/';

  fetchComposite = '?fetch_composite=true';

  typesEndpoint = 'core/topictype';

  typeInfo = typesEndpoint + '/';

  defaultIcon = '/images/ball-gray.png';

  detachDataType = function(t) {
    return {
      name: t.value,
      uri: t.uri
    };
  };

  isChildType = function(assoc_def) {
    var _ref;
    if (_ref = assoc_def.assoc_type_uri, __indexOf.call(assocDefChildTypes, _ref) >= 0) {
      return true;
    }
  };

  createChildTypes = function(assoc_defs) {
    var assoc_def, _i, _len, _results;
    _results = [];
    for (_i = 0, _len = assoc_defs.length; _i < _len; _i++) {
      assoc_def = assoc_defs[_i];
      if (isChildType(assoc_def)) {
        _results.push(assoc_def.uri);
      } else {
        _results.push(void 0);
      }
    }
    return _results;
  };

  detachComposite = function(composite) {
    var part, typeUri, _results;
    _results = [];
    for (typeUri in composite) {
      part = composite[typeUri];
      _results.push(detachTopic(part));
    }
    return _results;
  };

  detachTopic = function(topic) {
    return {
      id: topic.id,
      type: topic.type_uri,
      uri: topic.uri,
      value: topic.value,
      composite: detachComposite(topic.composite)
    };
  };

  detachType = function(type) {
    var vc, _i, _len, _ref, _ref2, _ref3;
    _ref = type.view_config_topics;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      vc = _ref[_i];
      type.icon = (_ref2 = vc.composite) != null ? (_ref3 = _ref2[iconUri]) != null ? _ref3.value : void 0 : void 0;
    }
    return {
      id: type.id,
      name: type.value,
      uri: type.uri,
      dataType: type.data_type_uri,
      childTypes: createChildTypes(type.assoc_defs),
      icon: typeof type.icon === "function" ? type.icon(defaultIcon) : void 0
    };
  };

  clarifyParents = function(types) {
    var child, parentsByChild, type, _i, _j, _k, _l, _len, _len2, _len3, _len4, _ref;
    parentsByChild = {};
    for (_i = 0, _len = types.length; _i < _len; _i++) {
      type = types[_i];
      parentsByChild[type.uri] = [];
    }
    for (_j = 0, _len2 = types.length; _j < _len2; _j++) {
      type = types[_j];
      _ref = type.childTypes;
      for (_k = 0, _len3 = _ref.length; _k < _len3; _k++) {
        child = _ref[_k];
        parentsByChild[child].push(type.uri);
      }
    }
    for (_l = 0, _len4 = types.length; _l < _len4; _l++) {
      type = types[_l];
      type.parentTypes = parentsByChild[type.uri];
    }
    return types;
  };

  exports.create = function(serverUrl) {
    var getTypeInfos, httpOptions, topicCreateUrl, topicUrl, topicsUrl, typeUrl, typesUrl;
    if (serverUrl == null) serverUrl = 'http://localhost:8080/';
    httpOptions = url.parse(serverUrl);
    topicCreateUrl = serverUrl + topicEndpoint;
    topicUrl = function(id) {
      return serverUrl + topicInfo + id;
    };
    topicsUrl = function(uri) {
      return serverUrl + topicsByType + uri + fetchComposite;
    };
    typesUrl = serverUrl + typesEndpoint;
    typeUrl = function(uri) {
      return serverUrl + typeInfo + uri;
    };
    getTypeInfos = function(types, onSuccess) {
      var getTypeInfo, typeInfos;
      typeInfos = [];
      getTypeInfo = function(uri, callback) {
        return rest.get(typeUrl(uri)).on('success', function(type, status) {
          typeInfos.push(type);
          return callback();
        });
      };
      return async.forEachLimit(types, 10, getTypeInfo, function(err) {
        if (err != null) {
          throw new Error(err);
        } else {
          return onSuccess(typeInfos);
        }
      });
    };
    return {
      createTopic: function(topic, onSuccess, onError) {
        return POST(topicCreateUrl, topic, onSuccess, onError);
      },
      deleteTopic: function(id, onSuccess, onError) {
        return DEL(topicUrl(id), onSuccess, onError);
      },
      getDataTypes: function(onSuccess, onError) {
        var detach;
        detach = function(data) {
          var t;
          return onSuccess((function() {
            var _i, _len, _ref, _results;
            _ref = data.items;
            _results = [];
            for (_i = 0, _len = _ref.length; _i < _len; _i++) {
              t = _ref[_i];
              _results.push(detachDataType(t));
            }
            return _results;
          })());
        };
        return GET(topicsUrl(dataTypeUri), detach, onError);
      },
      getResource: function(path, onSuccess, onError) {
        var handle, options;
        if (onError == null) {
          onError = function(status, error) {
            throw error;
          };
        }
        options = _.extend(httpOptions, {
          path: path
        });
        handle = function(response) {
          var rUrl;
          if (response.statusCode === 200) {
            return onSuccess(response);
          } else {
            rUrl = url.format(options);
            return onError(response.statusCode, new Error("requesting " + rUrl + " failed"));
          }
        };
        return http.get(options, handle).on('error', function(error) {
          return onError(500, error);
        });
      },
      getTopic: function(id, onSuccess, onError) {
        var detach;
        detach = function(data) {
          return onSuccess(detachTopic(data));
        };
        return GET(topicUrl(id) + fetchComposite, detach, onError);
      },
      getTopics: function(uri, onSuccess, onError) {
        var detach;
        detach = function(data) {
          var t;
          return onSuccess((function() {
            var _i, _len, _ref, _results;
            _ref = data.items;
            _results = [];
            for (_i = 0, _len = _ref.length; _i < _len; _i++) {
              t = _ref[_i];
              _results.push(detachTopic(t));
            }
            return _results;
          })());
        };
        return GET(topicsUrl(uri), detach, onError);
      },
      getTypes: function(onSuccess, onError) {
        var detach;
        detach = function(data) {
          return getTypeInfos(data, function(typeInfos) {
            var t;
            return onSuccess(clarifyParents((function() {
              var _i, _len, _results;
              _results = [];
              for (_i = 0, _len = typeInfos.length; _i < _len; _i++) {
                t = typeInfos[_i];
                _results.push(detachType(t));
              }
              return _results;
            })()));
          });
        };
        return GET(typesUrl, detach, onError);
      },
      updateTopic: function(topic, onSuccess, onError) {
        return PUT(topicCreateUrl, topic, onSuccess, onError);
      }
    };
  };

}).call(this);
