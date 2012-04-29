temp = require 'temp'
fs = require 'fs'
util = require 'util'
mime = require 'mime-magic'
{aCheck, aFail} = require './check'
dm4client = require('../src/dm4client').create()

compositeDataTypeUri = 'dm4.core.composite'
personTypeUri = 'dm4.contacts.person'
defaultIcon = '/images/ball-gray.png'

# stateful integration test
describe 'dm4client', ->
#
  it 'returns a data type list', ->
    aCheck 'get data type list', (done) ->
      dm4client.getDataTypes (list) ->
        expect(list.length > 0).toBeTruthy 'data types'
        uris = (t.uri for t in list)
        expect(uris).toContain compositeDataTypeUri, 'composite data type'
        done()

  it 'returns a type list', ->
    aCheck 'get type list', (done) ->
      dm4client.getTypes (list) ->
        expect(list.length > 0).toBeTruthy 'types'
        expect(t.uri for t in list).toContain personTypeUri, 'person type'
        done()

  it 'returns a resource stream', ->
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

      dm4client.getResource defaultIcon, handle, aFail(@, done)

describe 'person crudle', ->
#
  person =
    type_uri: personTypeUri
    composite:
      'dm4.contacts.person_name':
        'dm4.contacts.first_name': 'firstname'
        'dm4.contacts.last_name': 'lastname'

  it 'creates person', ->
    aCheck 'create person', (done) ->
      dm4client.createTopic person, (topic) ->
        expect(topic.id).toBeDefined 'person id'
        person = topic
        done()

  it 'changes the first name', ->
    aCheck 'update person firstname', (done) ->
      personName = person.composite['dm4.contacts.person_name']
      firstName = personName.composite['dm4.contacts.first_name']
      firstName.value = 'changed name'
      dm4client.updateTopic firstName, (list) ->
        expect(list.length > 0).toBeTruthy 'updated associations and topics'
        topic = list[list.length - 1]
        expect(topic.type).toBe 'UPDATE_TOPIC', 'last topic'
        expect(topic.arg.id).toBe firstName.id, 'person id'
        done()

  it 'returns the person', ->
    aCheck 'get person', (done) ->
      dm4client.getTopic person.id, (topic) ->
        expect(topic.id).toBe person.id, 'person id'
        done()

  it 'returns a person list', ->
    aCheck 'get person list', (done) ->
      assert = (persons) ->
        expect(persons.length > 0).toBeTruthy 'persons'
        actual = false
        for p in persons
          if p.id is person.id
            actual = p.value
        personName = person.composite['dm4.contacts.person_name']
        lastName = personName.composite['dm4.contacts.last_name']
        expect(actual).toContain lastName.value, 'contains lastname'
        done()
      dm4client.getTopics personTypeUri, assert

  it 'deletes a person', ->
    aCheck 'delete person', (done) ->
      dm4client.deleteTopic person.id, (list) ->
        expect(list.length > 0).toBeTruthy 'deleted associations and topics'
        topic = list[list.length - 1]
        expect(topic.type).toBe 'DELETE_TOPIC', 'last topic'
        expect(topic.arg.id).toBe person.id, 'person id'
        done()
