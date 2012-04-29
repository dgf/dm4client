_ = require 'underscore'
rest = require 'restler'
async = require 'async'
http = require 'http'
url = require 'url'
util = require 'util'

GET = (url, onSuccess) ->
  rest.get(url).on 'success', onSuccess

DEL = (url, onSuccess) ->
  rest.del(url).on 'success', onSuccess

POST = (url, data, onSuccess) ->
  rest.postJson(url, data).on 'success', onSuccess

PUT = (url, data, onSuccess) ->
  r = rest.put url,
    data: JSON.stringify data
    headers:
      'Content-Type':
        'application/json'
  r.on 'success', onSuccess

dataTypeUri = 'dm4.core.data_type'
iconUri = 'dm4.webclient.icon'
assocDefChildTypes = ['dm4.core.aggregation_def', 'dm4.core.composition_def']

topicEndpoint = 'core/topic'
topicInfo = topicEndpoint + '/'
topicsByType = topicEndpoint + '/by_type/'
fetchComposite = '?fetch_composite=true'

typesEndpoint = 'core/topictype'
typeInfo = typesEndpoint + '/'

defaultIcon = '/images/ball-gray.png'

detachDataType = (t) -> name: t.value, uri: t.uri

isChildType = (assoc_def) ->
  true if assoc_def.assoc_type_uri in assocDefChildTypes

createChildTypes = (assoc_defs) ->
  for assoc_def in assoc_defs
    assoc_def.uri if isChildType assoc_def

detachComposite = (composite) ->
  detachTopic part for typeUri, part of composite

detachTopic = (topic) ->
  id: topic.id
  type: topic.type_uri
  uri: topic.uri
  value: topic.value
  composite: detachComposite topic.composite

detachType = (type) ->
  for vc in type.view_config_topics
    type.icon = vc.composite?[iconUri]?.value
  id: type.id
  name: type.value
  uri: type.uri
  dataType: type.data_type_uri
  childTypes: createChildTypes type.assoc_defs
  icon: type.icon ? defaultIcon

clarifyParents = (types) ->
  parentsByChild = {}
  parentsByChild[type.uri] = [] for type in types
  for type in types
    for child in type.childTypes
      parentsByChild[child].push type.uri
  for type in types
    type.parentTypes = parentsByChild[type.uri]
  types

exports.create = (serverUrl = 'http://localhost:8080/') ->
#
  httpOptions = url.parse serverUrl

  topicCreateUrl = serverUrl + topicEndpoint

  topicUrl = (id) ->
    serverUrl + topicInfo + id + fetchComposite

  topicsUrl = (uri) ->
    serverUrl + topicsByType + uri + fetchComposite

  typesUrl = serverUrl + typesEndpoint

  typeUrl = (uri) ->
    serverUrl + typeInfo + uri

  getTypeInfos = (types, onSuccess) ->
    typeInfos = []
    getTypeInfo = (uri, callback) ->
      rest.get(typeUrl uri).on 'success', (type, status) ->
        typeInfos.push type
        callback()
    async.forEachLimit types, 10, getTypeInfo, (err) ->
      if err?
        throw new Error err
      else
        onSuccess typeInfos

  createTopic: (topic, onSuccess) ->
    POST topicCreateUrl, topic, onSuccess

  deleteTopic: (id, onSuccess) ->
    DEL topicUrl(id), onSuccess

  getDataTypes: (onSuccess) ->
    GET topicsUrl(dataTypeUri), (data) ->
      onSuccess (detachDataType t for t in data.items)

  getResource: (path, onSuccess, onError) ->
    options = _.extend httpOptions, path: path
    handle = (response) ->
      if response.statusCode is 200
        onSuccess response
      else
        onError url.format(options) + ' request failed: ' + response.statusCode
    http.get(options, handle).on 'error', (error) -> onError error.message

  getTopic: (id, onSuccess) ->
    GET topicUrl(id), (data) -> onSuccess detachTopic data

  getTopics: (uri, onSuccess) ->
    GET topicsUrl(uri), (data) ->
      onSuccess (detachTopic t for t in data.items)

  getTypes: (onSuccess) ->
    GET typesUrl, (data) ->
      getTypeInfos data, (typeInfos) ->
        onSuccess clarifyParents (detachType t for t in typeInfos)

  updateTopic: (topic, onSuccess) ->
    t =
      id: topic.id
      type_uri: topic.type_uri
      value: topic.value
    PUT topicCreateUrl, t, onSuccess
