# DeepaMehta 4 client

A [DeepaMehta 4](http://github.com/jri/deepamehta) REST client library

## Requirements

  * DeepaMehta 4 with actived [dm4-webservice]
    (http://github.com/jri/deepamehta/tree/master/modules/dm4-webservice)
    module
  * Node.js and npm

## Installation

    npm install dm4client

## Usage

    dm4client = require './src/dm4client'
    client = dm4client.create 'http://localhost:8080/'

    client.getDataTypes (dataTypes) ->
      client.getTypes (typeList) ->
        console.log typeList

        client.getTopics 'dm4.contacts.person', (persons) ->
          for person in persons
            console.log person.value
