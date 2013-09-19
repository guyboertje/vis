class Range

  ###
  @constructor Range
  A Range controls a numeric range with a start and end value.
  The Range adjusts the range based on mouse events or programmatic changes,
  and triggers events when the range is changing or has been changed.
  @param {Object} [options]   See description at Range.setOptions
  @extends Controller
  ###
  constructor: (options) ->
    @id = util.randomUUID()
    @start = 0 # Number
    @end = 0 # Number
    @options =
      min: null
      max: null
      zoomMin: null
      zoomMax: null

    @listeners = []
    @setOptions options

  ###
  Static method to calculate the conversion offset and factor for a range,
  based on the provided start, end, and width
  @param {Number} start
  @param {Number} end
  @param {Number} width
  @returns {{offset: number, factor: number}} conversion
  ###
  @conversion: (start, end, width) ->
    if width isnt 0 and (end - start isnt 0)
      offset: start
      factor: width / (end - start)
    else
      offset: 0
      factor: 1

  ###
  Set options for the range controller
  @param {Object} options      Available options:
  {Number} start  Set start value of the range
  {Number} end    Set end value of the range
  {Number} min    Minimum value for start
  {Number} max    Maximum value for end
  {Number} zoomMin    Set a minimum value for
  (end - start).
  {Number} zoomMax    Set a maximum value for
  (end - start).
  ###
  setOptions: (options) ->
    util.extend @options, options
    @setRange options.start, options.end  if options.start? or options.end?


  ###
  Add listeners for mouse and touch events to the component
  @param {Component} component
  @param {String} event        Available events: 'move', 'zoom'
  @param {String} direction    Available directions: 'horizontal', 'vertical'
  ###
  subscribe: (component, event, direction) ->
    me = this
    listener = undefined
    throw new TypeError("Unknown direction \"" + direction + "\". " + "Choose \"horizontal\" or \"vertical\".")  if direction isnt "horizontal" and direction isnt "vertical"

    #noinspection FallthroughInSwitchStatementJS
    if event is "move"
      listener =
        component: component
        event: event
        direction: direction
        callback: (event) ->
          me._onMouseDown event, listener

        params: {}

      component.on "mousedown", listener.callback
      me.listeners.push listener
    else if event is "zoom"
      listener =
        component: component
        event: event
        direction: direction
        callback: (event) ->
          me._onMouseWheel event, listener

        params: {}

      component.on "mousewheel", listener.callback
      me.listeners.push listener
    else
      throw new TypeError("Unknown event \"" + event + "\". " + "Choose \"move\" or \"zoom\".")


  ###
  Event handler
  @param {String} event       name of the event, for example 'click', 'mousemove'
  @param {function} callback  callback handler, invoked with the raw HTML Event
  as parameter.
  ###
  on: (event, callback) ->
    events.addListener this, event, callback


  ###
  Trigger an event
  @param {String} event    name of the event, available events: 'rangechange',
  'rangechanged'
  @private
  ###
  _trigger: (event) ->
    events.trigger this, event,
      start: @start
      end: @end



  ###
  Set a new start and end range
  @param {Number} start
  @param {Number} end
  ###
  setRange: (start, end) ->
    changed = @_applyRange(start, end)
    if changed
      @_trigger "rangechange"
      @_trigger "rangechanged"


  ###
  Set a new start and end range. This method is the same as setRange, but
  does not trigger a range change and range changed event, and it returns
  true when the range is changed
  @param {Number} start
  @param {Number} end
  @return {Boolean} changed
  @private
  ###
  _applyRange: (start, end) ->
    newStart = (if (start?) then util.convert(start, "Number") else @start)
    newEnd = (if (end?) then util.convert(end, "Number") else @end)
    diff = undefined

    # check for valid number
    throw new Error("Invalid start \"" + start + "\"")  if isNaN(newStart)
    throw new Error("Invalid end \"" + end + "\"")  if isNaN(newEnd)

    # prevent start < end
    newEnd = newStart  if newEnd < newStart

    # prevent start < min
    if @options.min?
      min = @options.min.valueOf()
      if newStart < min
        diff = (min - newStart)
        newStart += diff
        newEnd += diff

    # prevent end > max
    if @options.max?
      max = @options.max.valueOf()
      if newEnd > max
        diff = (newEnd - max)
        newStart -= diff
        newEnd -= diff

    # prevent (end-start) > zoomMin
    if @options.zoomMin?
      zoomMin = @options.zoomMin.valueOf()
      zoomMin = 0  if zoomMin < 0
      if (newEnd - newStart) < zoomMin
        if (@end - @start) > zoomMin

          # zoom to the minimum
          diff = (zoomMin - (newEnd - newStart))
          newStart -= diff / 2
          newEnd += diff / 2
        else

          # ingore this action, we are already zoomed to the minimum
          newStart = @start
          newEnd = @end

    # prevent (end-start) > zoomMin
    if @options.zoomMax?
      zoomMax = @options.zoomMax.valueOf()
      zoomMax = 0  if zoomMax < 0
      if (newEnd - newStart) > zoomMax
        if (@end - @start) < zoomMax

          # zoom to the maximum
          diff = ((newEnd - newStart) - zoomMax)
          newStart += diff / 2
          newEnd -= diff / 2
        else

          # ingore this action, we are already zoomed to the maximum
          newStart = @start
          newEnd = @end
    changed = (@start isnt newStart or @end isnt newEnd)
    @start = newStart
    @end = newEnd
    changed


  ###
  Retrieve the current range.
  @return {Object} An object with start and end properties
  ###
  getRange: ->
    start: @start
    end: @end


  ###
  Calculate the conversion offset and factor for current range, based on
  the provided width
  @param {Number} width
  @returns {{offset: number, factor: number}} conversion
  ###
  conversion: (width) ->
    start = @start
    end = @end
    Range.conversion @start, @end, width

  ###
  Start moving horizontally or vertically
  @param {Event} event
  @param {Object} listener   Listener containing the component and params
  @private
  ###
  _onMouseDown: (event, listener) ->
    event = event or window.event
    params = listener.params

    # only react on left mouse button down
    leftButtonDown = (if event.which then (event.which is 1) else (event.button is 1))
    return  unless leftButtonDown

    # get mouse position
    params.mouseX = util.getPageX(event)
    params.mouseY = util.getPageY(event)
    params.previousLeft = 0
    params.previousOffset = 0
    params.moved = false
    params.start = @start
    params.end = @end
    frame = listener.component.frame
    frame.style.cursor = "move"  if frame

    # add event listeners to handle moving the contents
    # we store the function onmousemove and onmouseup in the timeaxis,
    # so we can remove the eventlisteners lateron in the function onmouseup
    me = this
    unless params.onMouseMove
      params.onMouseMove = (event) ->
        me._onMouseMove event, listener

      util.addEventListener document, "mousemove", params.onMouseMove
    unless params.onMouseUp
      params.onMouseUp = (event) ->
        me._onMouseUp event, listener

      util.addEventListener document, "mouseup", params.onMouseUp
    util.preventDefault event


  ###
  Perform moving operating.
  This function activated from within the funcion TimeAxis._onMouseDown().
  @param {Event} event
  @param {Object} listener
  @private
  ###
  _onMouseMove: (event, listener) ->
    event = event or window.event
    params = listener.params

    # calculate change in mouse position
    mouseX = util.getPageX(event)
    mouseY = util.getPageY(event)
    params.mouseX = mouseX  if params.mouseX is `undefined`
    params.mouseY = mouseY  if params.mouseY is `undefined`
    diffX = mouseX - params.mouseX
    diffY = mouseY - params.mouseY
    diff = (if (listener.direction is "horizontal") then diffX else diffY)

    # if mouse movement is big enough, register it as a "moved" event
    params.moved = true  if Math.abs(diff) >= 1
    interval = (params.end - params.start)
    width = (if (listener.direction is "horizontal") then listener.component.width else listener.component.height)
    diffRange = -diff / width * interval
    @_applyRange params.start + diffRange, params.end + diffRange

    # fire a rangechange event
    @_trigger "rangechange"
    util.preventDefault event


  ###
  Stop moving operating.
  This function activated from within the function Range._onMouseDown().
  @param {event} event
  @param {Object} listener
  @private
  ###
  _onMouseUp: (event, listener) ->
    event = event or window.event
    params = listener.params
    listener.component.frame.style.cursor = "auto"  if listener.component.frame

    # remove event listeners here, important for Safari
    if params.onMouseMove
      util.removeEventListener document, "mousemove", params.onMouseMove
      params.onMouseMove = null
    if params.onMouseUp
      util.removeEventListener document, "mouseup", params.onMouseUp
      params.onMouseUp = null

    #util.preventDefault(event);

    # fire a rangechanged event
    @_trigger "rangechanged"  if params.moved


  ###
  Event handler for mouse wheel event, used to zoom
  Code from http://adomas.org/javascript-mouse-wheel/
  @param {Event} event
  @param {Object} listener
  @private
  ###
  _onMouseWheel: (event, listener) ->
    event = event or window.event

    # retrieve delta
    delta = 0
    if event.wheelDelta # IE/Opera.
      delta = event.wheelDelta / 120
    # Mozilla case.

    # In Mozilla, sign of delta is different than in IE.
    # Also, delta is multiple of 3.
    else delta = -event.detail / 3  if event.detail

    # If delta is nonzero, handle it.
    # Basically, delta is now positive if wheel was scrolled up,
    # and negative, if wheel was scrolled down.
    if delta
      me = this
      zoom = ->

        # perform the zoom action. Delta is normally 1 or -1
        zoomFactor = delta / 5.0
        zoomAround = null
        frame = listener.component.frame
        if frame
          size = undefined
          conversion = undefined
          if listener.direction is "horizontal"
            size = listener.component.width
            conversion = me.conversion(size)
            frameLeft = util.getAbsoluteLeft(frame)
            mouseX = util.getPageX(event)
            zoomAround = (mouseX - frameLeft) / conversion.factor + conversion.offset
          else
            size = listener.component.height
            conversion = me.conversion(size)
            frameTop = util.getAbsoluteTop(frame)
            mouseY = util.getPageY(event)
            zoomAround = ((frameTop + size - mouseY) - frameTop) / conversion.factor + conversion.offset
        me.zoom zoomFactor, zoomAround

      zoom()

    # Prevent default actions caused by mouse wheel.
    # That might be ugly, but we handle scrolls somehow
    # anyway, so don't bother here...
    util.preventDefault event


  ###
  Zoom the range the given zoomfactor in or out. Start and end date will
  be adjusted, and the timeline will be redrawn. You can optionally give a
  date around which to zoom.
  For example, try zoomfactor = 0.1 or -0.1
  @param {Number} zoomFactor      Zooming amount. Positive value will zoom in,
  negative value will zoom out
  @param {Number} zoomAround      Value around which will be zoomed. Optional
  ###
  zoom: (zoomFactor, zoomAround) ->

    # if zoomAroundDate is not provided, take it half between start Date and end Date
    zoomAround = (@start + @end) / 2  unless zoomAround?

    # prevent zoom factor larger than 1 or smaller than -1 (larger than 1 will
    # result in a start>=end )
    zoomFactor = 0.9  if zoomFactor >= 1
    zoomFactor = -0.9  if zoomFactor <= -1

    # adjust a negative factor such that zooming in with 0.1 equals zooming
    # out with a factor -0.1
    zoomFactor = zoomFactor / (1 + zoomFactor)  if zoomFactor < 0

    # zoom start and end relative to the zoomAround value
    startDiff = (@start - zoomAround)
    endDiff = (@end - zoomAround)

    # calculate new start and end
    newStart = @start - startDiff * zoomFactor
    newEnd = @end - endDiff * zoomFactor
    @setRange newStart, newEnd


  ###
  Move the range with a given factor to the left or right. Start and end
  value will be adjusted. For example, try moveFactor = 0.1 or -0.1
  @param {Number}  moveFactor     Moving amount. Positive value will move right,
  negative value will move left
  ###
  move: (moveFactor) ->

    # zoom start Date and end Date relative to the zoomAroundDate
    diff = (@end - @start)

    # apply new values
    newStart = @start + diff * moveFactor
    newEnd = @end + diff * moveFactor

    # TODO: reckon with min and max range
    @start = newStart
    @end = newEnd
