# create a client instance
client = require('./src/dm4client').create 'http://localhost:8080/'

# login in as user 'check' with password 'test'
client.login 'check', 'test', (session) ->

  # open the default DeepaMehta workspace
  client.openSpace 'de.workspaces.deepamehta', (workspaceId) ->

    # get all data types
    client.getDataTypes (dataTypes) ->

      # get all topic types
      client.getTypes (typeList) ->

        # get all person contacts
        client.getTopics 'dm4.contacts.person', (persons) ->
          for person in persons
            console.log person.value
