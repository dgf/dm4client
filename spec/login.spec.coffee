# DM 4 HTTP login

_ = require 'underscore'
rest = require 'restler'
http = require 'http'
{aCheck, aFail} = require './check'

host = 'localhost'
port = 8080
user = 'check'
password = 'test'

describe 'authorization', ->
  #
  describe 'http', ->
    #
    it 'provides HTTP basic auth', ->
      fail = (done) => aFail(@, done)
      options = hostname: host, port: port

      aCheck 'login', (done) ->
        loginOptions =
          auth: user + ':' + password
          method: 'POST'
          path: '/accesscontrol/login'
        loginRequest = http.request _.extend(loginOptions, options), (loginResponse) ->
          expect(loginResponse.statusCode).toBe 204, 'OK no content'
          sessionId = loginResponse.headers['set-cookie'][0].replace /;Path.*/, ''
          searchOptions =
            method: 'GET'
            headers:
              Cookie: sessionId
            path: '/webclient/search/by_type/dm4.accesscontrol.user_account'
          searchRequest = http.request _.extend(searchOptions, options), (searchResponse) ->
            expect(searchResponse.statusCode).toBe 200, 'OK'
            done()
          searchRequest.on 'error', fail done
          searchRequest.end()
        loginRequest.on 'error', fail done
        loginRequest.end()

  describe 'restler', ->
    #
    it 'provides HTTP basic auth', ->
      aCheck 'login', (done) ->
        url = 'http://' + host + ':' + port
        rest.post(url + '/accesscontrol/login',
          username: user
          password: password
          headers:
            'Content-Type': 'application/json'
        ).on 'complete', (loginData, loginResponse) ->
          expect(loginResponse.statusCode).toBe 204, 'OK no content'
          sessionId = loginResponse.headers['set-cookie'][0].replace /;Path.*/, ''
          rest.get(url + '/webclient/search/by_type/dm4.accesscontrol.user_account',
            headers:
              Cookie: sessionId
          ).on 'complete', (searchData, searchResponse) ->
            expect(searchResponse.statusCode).toBe 200, 'OK'
            expect(searchData.type_uri).toBe 'dm4.webclient.search', 'type of search topic'
            done()
