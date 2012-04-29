# async check helper

exports.aCheck = (message, test, timeout = 5000) ->
  isDone = false
  runs -> test -> isDone = true
  waitsFor (-> isDone), message, timeout

exports.aFail = (it, done) -> (msg) => it.fail msg; done()
