# stateful CRUD integration test

{aCheck, aFail} = require './check'
dm4c = require('../src/dm4client').create()

personTypeUri = 'dm4.contacts.person'

describe 'person crudle and web resource association', ->
  #
  person =
    type_uri: personTypeUri
    composite:
      'dm4.contacts.person_name':
        'dm4.contacts.first_name': 'firstname'
        'dm4.contacts.last_name': 'lastname'
      'dm4.contacts.phone_entry': [
        { 'dm4.contacts.phone_number': '030 / 1234567' },
        { 'dm4.contacts.phone_number': '0173 / 1234567' }
      ],
      'dm4.contacts.email_address': [ 'dev@deeepamehta.de' ],
      'dm4.webbrowser.url': [ 'http://www.deeepamehta.de' ]

  webResource =
    type_uri: 'dm4.webbrowser.web_resource'
    composite:
      'dm4.webbrowser.url': 'http://trac.deeepamehta.de'
      'dm4.webbrowser.web_resource_description': 'DeepaMehta Trac'

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

  it 'creates person', ->
    aCheck 'create person', (done) ->
      dm4c.createTopic person, (topic) ->
        expect(topic.id).toBeDefined 'person id'
        person = topic
        done()

  it 'changes the first name', ->
    aCheck 'update person firstname', (done) ->
      personName = person.composite['dm4.contacts.person_name']
      firstName = personName.composite['dm4.contacts.first_name']
      firstName.value = 'changed name'
      dm4c.updateTopic firstName, (list) ->
        expect(list.length > 0).toBeTruthy 'updated associations and topics'
        topic = list[list.length - 1]
        expect(topic.type).toBe 'UPDATE_TOPIC', 'last topic'
        expect(topic.arg.id).toBe firstName.id, 'person id'
        done()

  it 'returns a person topic by id', ->
    aCheck 'get person', (done) ->
      dm4c.getTopic person.id, (topic) ->
        expect(topic.id).toBe person.id, 'person id'
        done()

  it 'returns a list of person topics', ->
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
      dm4c.getTopics personTypeUri, assert

  it 'creates a web resource topic', ->
    aCheck 'create a web resource', (done) ->
      dm4c.createTopic webResource, (topic) ->
        expect(topic.id).toBeDefined 'web resource id'
        webResource = topic
        done()

  associationId = null

  it 'associates a person with a web resource', ->
    # @todo create a association composite
    aCheck 'create an association', (done) ->
      a =
        type_uri: 'dm4.core.association'
        role_1:
          role_type_uri: 'dm4.core.default'
          topic_id: person.id
        role_2:
          role_type_uri: 'dm4.core.default'
          topic_id: webResource.id
      dm4c.createAssociation a, (assoc) ->
        expect(assoc.id).toBeDefined 'association id'
        associationId = assoc.id
        expect(assoc.role_1.topic_id).toBe person.id, 'person node'
        expect(assoc.role_2.topic_id).toBe webResource.id, 'web resource node'
        done()

  it 'returns an association', ->
    aCheck 'get assocication', (done) ->
      dm4c.getAssociation associationId, (assoc) ->
        expect(assoc.id).toBe(associationId, 'association id')
        expect(assoc.roles[0].id).toBe person.id, 'person node'
        done()

  it 'changes an association partially', ->
    # @todo the call should'nt depend on role IDs
    aCheck 'update association role type URIs', (done) ->
      association =
        id: associationId
        role_1:
          topic_id: person.id
          role_type_uri: 'dm4.core.parent'
        role_2:
          topic_id: webResource.id
          role_type_uri: 'dm4.core.child'
      dm4c.updateAssociation association, (list) ->
        expect(list.length).toBe 1, 'updated association'
        expect(list[0].type).toBe 'UPDATE_ASSOCIATION', 'update association'
        expect(list[0].arg.id).toBe associationId, 'association id'
        done()

  it 'deletes an association', ->
    aCheck 'delete an association', (done) ->
      dm4c.deleteAssociation associationId, (list) ->
        expect(list.length > 0).toBeTruthy 'deleted associations'
        topic = list[list.length - 1]
        expect(topic.type).toBe 'DELETE_ASSOCIATION', 'last association'
        expect(topic.arg.id).toBe associationId, 'association id'
        done()

  it 'deletes a web resource', ->
    aCheck 'delete web resource', (done) ->
      dm4c.deleteTopic webResource.id, (list) ->
        expect(list.length > 0).toBeTruthy 'deleted associations and topics'
        topic = list[list.length - 1]
        expect(topic.type).toBe 'DELETE_TOPIC', 'last topic'
        expect(topic.arg.id).toBe webResource.id, 'resource id'
        done()

  it 'deletes a person', ->
    aCheck 'delete person', (done) ->
      dm4c.deleteTopic person.id, (list) ->
        expect(list.length > 0).toBeTruthy 'deleted associations and topics'
        topic = list[list.length - 1]
        expect(topic.type).toBe 'DELETE_TOPIC', 'last topic'
        expect(topic.arg.id).toBe person.id, 'person id'
        done()
