{print} = require 'util'
{spawn} = require 'child_process'
jasmineBinary = './node_modules/.bin/jasmine-node'

green = '\033[0;32m'
reset = '\033[0m'
red = '\033[0;31m'

log = (message, color) ->
  console.log color + message + reset

call = (name, options, callback) ->
  proc = spawn name, options
  proc.stdout.on 'data', (data) -> print data.toString()
  proc.stderr.on 'data', (data) -> log data.toString(), red
  proc.on 'exit', callback

build = (callback) ->
  call 'coffee', ['-c', '-o', 'lib', 'src'], callback

spec = (callback) ->
  call jasmineBinary, ['spec', '--coffee', '--verbose'], callback

logSuccess = (status) ->
  log ":)", green if status is 0

task 'build', 'build coffee', -> build logSuccess

task 'spec', 'run specifications', -> spec logSuccess
