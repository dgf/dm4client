_ = require 'underscore'
rest = require 'restler'
async = require 'async'
http = require 'http'
url = require 'url'
util = require 'util'

createOnComplete = (onSuccess, onError, errorMessage) ->
  (result, response) ->
    if result instanceof Error
      onError 510, result
    else if response.statusCode is 200
      onSuccess result
    else
      onError response.statusCode, new Error errorMessage

GET = (getUrl, options, onSuccess, onError = (status, error) -> throw error) ->
  onComplete = createOnComplete onSuccess, onError, "requesting #{getUrl} failed"
  rest.get(getUrl, _.clone options).on 'complete', onComplete

DEL = (delUrl, options, onSuccess, onError = (status, error) -> throw error) ->
  onComplete = createOnComplete onSuccess, onError, "deleting #{delUrl} failed"
  rest.del(delUrl, _.clone options).on 'complete', onComplete

POST = (postUrl, data, options, onSuccess, onError = (status, error) -> throw error) ->
  onComplete = createOnComplete onSuccess, onError, "posting to #{postUrl} failed"
  rest.postJson(postUrl, data, _.clone options).on 'complete', onComplete

PUT = (putUrl, data, options, onSuccess, onError = (status, error) -> throw error) ->
  putOptions = _.extend data: JSON.stringify(data), options
  onComplete = createOnComplete onSuccess, onError, "put to #{putUrl} failed"
  rest.put(putUrl, putOptions).on 'complete', onComplete

dataTypeUri = 'dm4.core.data_type'
childTypeUri = 'dm4.core.child_type'
iconUri = 'dm4.webclient.icon'
assocDefChildTypes = ['dm4.core.aggregation_def', 'dm4.core.composition_def']

associationEndpoint = 'core/association'
associationInfo = associationEndpoint + '/'

topicEndpoint = 'core/topic'
topicInfo = topicEndpoint + '/'
topicsByType = topicEndpoint + '/by_type/'
fetchComposite = '?fetch_composite=true'

typesEndpoint = 'core/topictype'
typeInfo = typesEndpoint + '/'

defaultIcon = '/de.deepamehta.webclient/images/ball-gray.png'

detachDataType = (t) ->
  name: t.value
  uri: t.uri

createChildTypes = (assoc_defs) ->
  for assoc_def in assoc_defs
    if assoc_def.type_uri in assocDefChildTypes
      if assoc_def.role_1.role_type_uri is childTypeUri
        assoc_def.role_1.topic_uri
      else
        assoc_def.role_2.topic_uri

detachComposite = (composite) ->
  detachTopic part for typeUri, part of composite

detachAsscociation = (association) ->
  _.extend detachTopic(association), roles: [
    { id: association.role_1.topic_id, type: association.role_1.topic_id }
    { id: association.role_2.topic_id, type: association.role_2.topic_id }
  ]

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

# creates a DM4 client
exports.create = (serverUrl = 'http://localhost:8080/') ->

  httpOptions = url.parse serverUrl

  restOptions = {}
    #headers:
      #'Content-Type': 'application/json'

  associationCreateUrl = serverUrl + associationEndpoint

  associationUrl = (id) ->
    serverUrl + associationInfo + id

  topicCreateUrl = serverUrl + topicEndpoint

  topicUrl = (id) ->
    serverUrl + topicInfo + id

  topicsUrl = (uri) ->
    serverUrl + topicsByType + uri + fetchComposite

  typesUrl = serverUrl + typesEndpoint

  typeUrl = (uri) ->
    serverUrl + typeInfo + uri

  getTypeInfos = (types, onSuccess, onError = (error) -> throw error) ->
    typeInfos = []
    getTypeInfo = (uri, callback) ->
      addTypeInfo = (type) ->
        typeInfos.push type
        callback()
      GET typeUrl(uri), restOptions, addTypeInfo, onError
    async.forEachLimit types, 10, getTypeInfo, (err) ->
      if err?
        onError new Error err
      else
        onSuccess typeInfos

  createAssociation: (association, onSuccess, onError) ->
    POST associationCreateUrl, association, restOptions, onSuccess, onError

  createTopic: (topic, onSuccess, onError) ->
    POST topicCreateUrl, topic, restOptions, onSuccess, onError

  deleteAssociation: (id, onSuccess, onError) ->
    DEL associationUrl(id), restOptions, onSuccess, onError

  deleteTopic: (id, onSuccess, onError) ->
    DEL topicUrl(id), restOptions, onSuccess, onError

  getAssociation: (id, onSuccess, onError) ->
    detach = (data) -> onSuccess detachAsscociation data
    GET associationUrl(id) + fetchComposite, restOptions, detach, onError

  getDataTypes: (onSuccess, onError) ->
    detach = (data) -> onSuccess (detachDataType t for t in data.items)
    GET topicsUrl(dataTypeUri), restOptions, detach, onError

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
    detach = (data) ->
      onSuccess detachTopic data
    GET topicUrl(id) + fetchComposite, restOptions, detach, onError

  getTopics: (uri, onSuccess, onError) ->
    detach = (data) -> onSuccess (detachTopic t for t in data.items)
    GET topicsUrl(uri), restOptions, detach, onError

  getTypes: (onSuccess, onError) ->
    getAndDetachInfos = (data) ->
      detach = (typeInfos) ->
        onSuccess clarifyParents (detachType t for t in typeInfos)
      getTypeInfos data, detach, onError
    GET typesUrl, restOptions, getAndDetachInfos, onError

  login: (user, password, onSuccess, onError = (status, error) -> throw error) ->
    loginOptions =
      auth: user + ':' + password
      method: 'POST'
    _.extend loginOptions, httpOptions, path: '/accesscontrol/login'
    loginRequest = http.request loginOptions, (response) ->
      if response.statusCode isnt 204
        onError response.statusCode, new Error "login #{user} failed"
      else
        # get session ID and set header cookie of http and rest client
        sessionId = response.headers['set-cookie'][0].replace /;Path.*/, ''
        _.extend httpOptions, headers: Cookie: sessionId
        _.extend restOptions, headers: Cookie: sessionId
        onSuccess sessionId
    loginRequest.on 'error', (e) -> onError 500, e.message
    loginRequest.end()

  openSpace: (uri, onSuccess, onError) ->
    updateCookie = (data) ->
      httpOptions.headers.Cookie += '; dm4_workspace_id=' + data.id
      restOptions.headers.Cookie += '; dm4_workspace_id=' + data.id
      onSuccess data.id
    GET topicUrl('by_value/uri/' + uri), restOptions, updateCookie, onError

  # update an association, callback gets the resulting directives
  updateAssociation: (association, onSuccess, onError) ->
    PUT associationCreateUrl, association, restOptions, onSuccess, onError

  # update a topic, callback gets the resulting directives
  updateTopic: (topic, onSuccess, onError) ->
    PUT topicCreateUrl, topic, restOptions, onSuccess, onError
