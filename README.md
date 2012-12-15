[![build status](https://secure.travis-ci.org/dgf/dm4client.png)](http://travis-ci.org/dgf/dm4client)
# DeepaMehta 4 client

A [DeepaMehta 4](http://github.com/jri/deepamehta) REST client library

## Requirements

  * DeepaMehta 4 with active [dm4-webservice]
    (http://github.com/jri/deepamehta/tree/master/modules/dm4-webservice)
    module
  * Node.js and npm

## Installation

```shell
npm install dm4client
```

## Usage

```coffeescript
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
```
