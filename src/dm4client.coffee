_ = require 'underscore'
rest = require 'restler'
async = require 'async'
http = require 'http'
url = require 'url'
util = require 'util'

createOnComplete = (onSuccess, onError, errorMessage) ->
  (result, response) ->
    if result instanceof Error
      onError 500, result
    else if response.statusCode is 200
      onSuccess result
    else
      onError response.statusCode, new Error errorMessage

GET = (getUrl, onSuccess, onError = (status, error) -> throw error) ->
  onComplete = createOnComplete onSuccess, onError, "requesting #{getUrl} failed"
  rest.get(getUrl).on 'complete', onComplete

DEL = (delUrl, onSuccess, onError = (status, error) -> throw error) ->
  onComplete = createOnComplete onSuccess, onError, "deleting #{delUrl} failed"
  rest.del(delUrl).on 'complete', onComplete

POST = (postUrl, data, onSuccess, onError = (status, error) -> throw error) ->
  onComplete = createOnComplete onSuccess, onError, "posting to #{postUrl} failed"
  rest.postJson(postUrl, data).on 'complete', onComplete

PUT = (putUrl, data, onSuccess, onError = (status, error) -> throw error) ->
  options =
    data: JSON.stringify data
    headers:
      'Content-Type': 'application/json'
  onComplete = createOnComplete onSuccess, onError, "put to #{putUrl} failed"
  rest.put(putUrl, options).on 'complete', onComplete

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
  icon: type.icon? defaultIcon

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
    serverUrl + topicInfo + id

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

  createTopic: (topic, onSuccess, onError) ->
    POST topicCreateUrl, topic, onSuccess, onError

  deleteTopic: (id, onSuccess, onError) ->
    DEL topicUrl(id), onSuccess, onError

  getDataTypes: (onSuccess, onError) ->
    detach = (data) -> onSuccess (detachDataType t for t in data.items)
    GET topicsUrl(dataTypeUri), detach, onError

  getResource: (path, onSuccess, onError = (status, error) -> throw error) ->
    options = _.extend httpOptions, path: path
    handle = (response) ->
      if response.statusCode is 200
        onSuccess response
      else
        rUrl = url.format(options)
        onError response.statusCode, new Error "requesting #{rUrl} failed"
    http.get(options, handle).on 'error', (error) -> onError 500, error

  getTopic: (id, onSuccess, onError) ->
    detach = (data) -> onSuccess detachTopic data
    GET topicUrl(id) + fetchComposite, detach, onError

  getTopics: (uri, onSuccess, onError) ->
    detach = (data) -> onSuccess (detachTopic t for t in data.items)
    GET topicsUrl(uri), detach, onError

  getTypes: (onSuccess, onError) ->
    detach = (data) ->
      getTypeInfos data, (typeInfos) ->
        onSuccess clarifyParents (detachType t for t in typeInfos)
    GET typesUrl, detach, onError

  updateTopic: (topic, onSuccess, onError) ->
    PUT topicCreateUrl, topic, onSuccess, onError
