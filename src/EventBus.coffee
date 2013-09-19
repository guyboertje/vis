class EventBus

  ###
  An event bus can be used to emit events, and to subscribe to events
  @constructor EventBus
  ###
  constructor: ->
    @subscriptions = []

  ###
  Subscribe to an event
  @param {String | RegExp} event   The event can be a regular expression, or
  a string with wildcards, like 'server.*'.
  @param {function} callback.      Callback are called with three parameters:
  {String} event, {*} [data], {*} [source]
  @param {*} [target]
  @returns {String} id    A subscription id
  ###
  on: (event, callback, target) ->
    regexp = (if (event instanceof RegExp) then event else new RegExp(event.replace("*", "\\w+")))
    subscription =
      id: util.randomUUID()
      event: event
      regexp: regexp
      callback: (if (typeof callback is "function") then callback else null)
      target: target

    @subscriptions.push subscription
    subscription.id


  ###
  Unsubscribe from an event
  @param {String | Object} filter   Filter for subscriptions to be removed
  Filter can be a string containing a
  subscription id, or an object containing
  one or more of the fields id, event,
  callback, and target.
  ###
  off: (filter) ->
    i = 0
    while i < @subscriptions.length
      subscription = @subscriptions[i]
      match = true
      if filter instanceof Object
        # filter is an object. All fields must match
        for prop of filter
          match = false  if filter[prop] isnt subscription[prop]  if filter.hasOwnProperty(prop)
      else
        # filter is a string, filter on id
        match = (subscription.id is filter)
      if match
        @subscriptions.splice i, 1
      else
        i++

  ###
  Emit an event
  @param {String} event
  @param {*} [data]
  @param {*} [source]
  ###
  emit: (event, data, source) ->
    i = 0

    while i < @subscriptions.length
      subscription = @subscriptions[i]
      subscription.callback event, data, source  if subscription.callback  if subscription.regexp.test(event)
      i++
