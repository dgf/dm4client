# integration test, a running DM4 instance is required

temp = require 'temp'
fs = require 'fs'
util = require 'util'
mime = require 'mime-magic'
{aCheck, aFail} = require './check'
dm4client = require('../src/dm4client')
dm4c = dm4client.create()

personTypeUri = 'dm4.contacts.person'
compositeDataTypeUri = 'dm4.core.composite'
defaultIcon = '/de.deepamehta.webclient/images/ball-gray.png'

describe 'dm4client', ->
  #
  describe 'login', ->
    #
    it 'authenticates', ->
      aCheck 'login', (done) ->
        dm4c.login 'check', 'test', (sessionId) ->
          expect(sessionId).toBeTruthy 'session'
          done()

    it 'changes the workspace', ->
      aCheck 'select DeepaMehta workspace', (done) ->
        dm4c.openSpace 'de.workspaces.deepamehta', (workspaceId) ->
          expect(workspaceId).toBeTruthy 'workspace'
          done()

  describe 'data types', ->
    #
    it 'calls onSuccess with a data type list', ->
      aCheck 'get data type list', (done) ->
        dm4c.getDataTypes (list) ->
          expect(list.length > 0).toBeTruthy 'data types'
          uris = (t.uri for t in list)
          expect(uris).toContain compositeDataTypeUri, 'composite data type'
          done()

    it 'calls onError with 510, if something went wrong', ->
      client = dm4client.create 'http://localhost:23/'
      aCheck 'get data types error', (done) =>
        assert = => aFail(@, done) 'request error expected'
        client.getDataTypes assert, (status, error) ->
          expect(error instanceof Error).toBeTruthy 'an error'
          expect(status).toBe 510, 'internal error'
          done()

  describe 'type list', ->
    #
    it 'calls onSuccess with a type list', ->
      aCheck 'get type list', (done) ->
        dm4c.getTypes (list) ->
          expect(list.length > 0).toBeTruthy 'types'
          expect(t.uri for t in list).toContain personTypeUri, 'person type'
          done()

    it 'calls onError with 510, if something went wrong', ->
      client = dm4client.create 'http://localhost:23/'
      aCheck 'get types error', (done) =>
        assert = => aFail(@, done) 'request error expected'
        client.getTypes assert, (status, error) ->
          expect(error instanceof Error).toBeTruthy 'an error'
          expect(status).toBe 510, 'internal error'
          done()

  describe 'topic access', ->
    #
    it 'calls onError with 404, if requested topic instance does not exist', ->
      aCheck 'get unknown topic', (done) =>
        assert = => aFail(@, done) 'request error expected'
        dm4c.getTopic 'UnknownTopicId', assert, (status, error) ->
          expect(error instanceof Error).toBeTruthy 'an error'
          expect(status).toBe 404, 'nothing found'
          done()

    it 'calls onError with 500, if URI of requested topic list does not exist', ->
      aCheck 'get unknown topic', (done) =>
        assert = => aFail(@, done) 'request error expected'
        dm4c.getTopics 'UnknownTopicTypeUri', assert, (status, error) ->
          expect(error instanceof Error).toBeTruthy 'an error'
          expect(status).toBe 500, 'internal error'
          done()

    it 'calls onError with 510, if something went wrong', ->
      client = dm4client.create 'http://localhost:23/'
      aCheck 'get topic on misconfigured client', (done) =>
        assert = => aFail(@, done) 'request error expected'
        client.getTopic 'UnknownTopicId', assert, (status, error) ->
          expect(error instanceof Error).toBeTruthy 'an error'
          expect(status).toBe 510, 'internal error'
          done()

    it 'fails on creating invalid topic instance', ->
      aCheck 'create invalid topic', (done) ->
        invalidTopic =
          type_uri: 'unknown.topic.uri'
          value: 'invalid topic value'
        assert = => aFail(@, done) 'request error expected'
        dm4c.createTopic invalidTopic, assert, (status, error) ->
          expect(error instanceof Error).toBeTruthy 'an error'
          expect(status).toBe 500, 'internal error'
          done()

    it 'fails on updating invalid topic instance', ->
      aCheck 'update invalid topic', (done) ->
        invalidTopic =
          id: 'UnknownTopicId'
          type_uri: 'unknown.topic.uri'
          value: 'invalid topic value'
        assert = => aFail(@, done) 'request error expected'
        dm4c.updateTopic invalidTopic, assert, (status, error) ->
          expect(error instanceof Error).toBeTruthy 'an error'
          expect(status).toBe 500, 'internal error'
          done()

    it 'throws an Error, if delete method is called with unknown topic', ->
      aCheck 'delete unknown topic', (done) ->
        assert = => aFail(@, done) 'request error expected'
        dm4c.deleteTopic 'UnknownTopicId', assert, (status, error) ->
          expect(error instanceof Error).toBeTruthy 'an error'
          expect(status).toBe 404, 'not found'
          done()

  describe 'resource stream access', ->
    #
    it 'proxies a resource stream', ->
      aCheck 'get resource stream', (done) =>
        tempFileName = temp.path { prefix: 'test', suffix: '.png' }
        tempFileStream = fs.createWriteStream tempFileName

        closeTempFile = (afterClose) ->
          tempFileStream.on 'close', -> afterClose()
          tempFileStream.end()

        handle = (response) =>
          response.on 'data', (chunk) -> tempFileStream.write chunk
          response.on 'close', (error) => aFail(@, done) error.message
          response.on 'end', -> closeTempFile -> assert response

        assert = (response) =>
          fileSize = fs.statSync(tempFileName).size
          actualSize = Number response.headers['content-length']
          expect(actualSize).toBe fileSize, 'resource length'

          actualType = response.headers['content-type']
          mime.fileWrapper tempFileName, (error, type) =>
            if error
              aFail(@, done) error.message
            else
              expect(actualType).toBe type, 'resource type'
              done()

        dm4c.getResource defaultIcon, handle, aFail(@, done)

    it 'calls onError with 404, if requested resource does not exist', ->
      aCheck 'get an unknown resource', (done) =>
        assert = => aFail(@, done) 'request error expected'
        dm4c.getResource 'UnknownResourceUri', assert, (status, error) ->
          expect(error instanceof Error).toBeTruthy 'an error'
          expect(status).toBe 404, 'nothing found'
          done()

    it 'calls onError with 500, if something went wrong', ->
      client = dm4client.create 'http://localhost:23/'
      aCheck 'get resource error', (done) =>
        assert = => aFail(@, done) 'request error expected'
        client.getResource defaultIcon, assert, (status, error) ->
          expect(error instanceof Error).toBeTruthy 'an error'
          expect(status).toBe 500, 'internal error'
          done()
