class TimeStep
  #/ enum scale
  [@MILLISECOND, @SECOND, @MINUTE, @HOUR, @DAY, @WEEKDAY, @MONTH, @YEAR] = [1..8]

  ###
  @constructor  TimeStep
  The class TimeStep is an iterator for dates. You provide a start date and an
  end date. The class itself determines the best scale (step size) based on the
  provided start Date, end Date, and minimumStep.

  If minimumStep is provided, the step size is chosen as close as possible
  to the minimumStep but larger than minimumStep. If minimumStep is not
  provided, the scale is set to 1 DAY.
  The minimumStep should correspond with the onscreen size of about 6 characters

  Alternatively, you can set a scale by hand.
  After creation, you can initialize the class by executing first(). Then you
  can iterate from the start date to the end date via next(). You can check if
  the end date is reached with the function hasNext(). After each step, you can
  retrieve the current date via getCurrent().
  The TimeStep has scales ranging from milliseconds, seconds, minutes, hours,
  days, to years.

  Version: 1.2

  @param {Date} [start]         The start date, for example new Date(2010, 9, 21)
  or new Date(2010, 9, 21, 23, 45, 00)
  @param {Date} [end]           The end date
  @param {Number} [minimumStep] Optional. Minimum step size in milliseconds
  ###
  constructor: (start, end, minimumStep) ->

    # variables
    @current = new Date()
    @_start = new Date()
    @_end = new Date()
    @autoScale = true
    @scale = TimeScale.DAY
    @step = 1

    # initialize the range
    @setRange start, end, minimumStep

  ###
  Set a new range
  If minimumStep is provided, the step size is chosen as close as possible
  to the minimumStep but larger than minimumStep. If minimumStep is not
  provided, the scale is set to 1 DAY.
  The minimumStep should correspond with the onscreen size of about 6 characters
  @param {Date} [start]      The start date and time.
  @param {Date} [end]        The end date and time.
  @param {int} [minimumStep] Optional. Minimum step size in milliseconds
  ###
  setRange: (start, end, minimumStep) ->

    #throw  "No legal start or end date in method setRange";
    return  if (start not instanceof Date) or (end not instanceof Date)
    @_start = (if (start isnt `undefined`) then new Date(start.valueOf()) else new Date())
    @_end = (if (end isnt `undefined`) then new Date(end.valueOf()) else new Date())
    @setMinimumStep minimumStep  if @autoScale


  ###
  Set the range iterator to the start date.
  ###
  first: ->
    @current = new Date(@_start.valueOf())
    @roundToMinor()


  ###
  Round the current date to the first minor date value
  This must be executed once when the current date is set to start Date
  ###
  roundToMinor: ->

    # round to floor
    # IMPORTANT: we have no breaks in this switch! (this is no bug)
    #noinspection FallthroughInSwitchStatementJS
    switch @scale
      when TimeScale.YEAR
        @current.setFullYear @step * Math.floor(@current.getFullYear() / @step)
        @current.setMonth 0
      when TimeScale.MONTH
        @current.setDate 1
      # intentional fall through
      when TimeScale.DAY, TimeScale.WEEKDAY
        @current.setHours 0
      when TimeScale.HOUR
        @current.setMinutes 0
      when TimeScale.MINUTE
        @current.setSeconds 0
      when TimeScale.SECOND
        @current.setMilliseconds 0

    #case TimeScale.MILLISECOND: // nothing to do for milliseconds
    unless @step is 1

      # round down to the first minor value that is a multiple of the current step size
      switch @scale
        when TimeScale.MILLISECOND
          @current.setMilliseconds @current.getMilliseconds() - @current.getMilliseconds() % @step
        when TimeScale.SECOND
          @current.setSeconds @current.getSeconds() - @current.getSeconds() % @step
        when TimeScale.MINUTE
          @current.setMinutes @current.getMinutes() - @current.getMinutes() % @step
        when TimeScale.HOUR
          @current.setHours @current.getHours() - @current.getHours() % @step
        # intentional fall through
        when TimeScale.WEEKDAY, TimeScale.DAY
          @current.setDate (@current.getDate() - 1) - (@current.getDate() - 1) % @step + 1
        when TimeScale.MONTH
          @current.setMonth @current.getMonth() - @current.getMonth() % @step
        when TimeScale.YEAR
          @current.setFullYear @current.getFullYear() - @current.getFullYear() % @step
        else


  ###
  Check if the there is a next step
  @return {boolean}  true if the current date has not passed the end date
  ###
  hasNext: ->
    @current.valueOf() <= @_end.valueOf()


  ###
  Do the next step
  ###
  next: ->
    prev = @current.valueOf()

    # Two cases, needed to prevent issues with switching daylight savings
    # (end of March and end of October)
    if @current.getMonth() < 6
      switch @scale
        when TimeScale.MILLISECOND
          @current = new Date(@current.valueOf() + @step)
        when TimeScale.SECOND
          @current = new Date(@current.valueOf() + @step * 1000)
        when TimeScale.MINUTE
          @current = new Date(@current.valueOf() + @step * 1000 * 60)
        when TimeScale.HOUR
          @current = new Date(@current.valueOf() + @step * 1000 * 60 * 60)

          # in case of skipping an hour for daylight savings, adjust the hour again (else you get: 0h 5h 9h ... instead of 0h 4h 8h ...)
          h = @current.getHours()
          @current.setHours h - (h % @step)
        # intentional fall through
        when TimeScale.WEEKDAY, TimeScale.DAY
          @current.setDate @current.getDate() + @step
        when TimeScale.MONTH
          @current.setMonth @current.getMonth() + @step
        when TimeScale.YEAR
          @current.setFullYear @current.getFullYear() + @step
        else
    else
      switch @scale
        when TimeScale.MILLISECOND
          @current = new Date(@current.valueOf() + @step)
        when TimeScale.SECOND
          @current.setSeconds @current.getSeconds() + @step
        when TimeScale.MINUTE
          @current.setMinutes @current.getMinutes() + @step
        when TimeScale.HOUR
          @current.setHours @current.getHours() + @step
        # intentional fall through
        when TimeScale.WEEKDAY, TimeScale.DAY
          @current.setDate @current.getDate() + @step
        when TimeScale.MONTH
          @current.setMonth @current.getMonth() + @step
        when TimeScale.YEAR
          @current.setFullYear @current.getFullYear() + @step
        else
    unless @step is 1

      # round down to the correct major value
      switch @scale
        when TimeScale.MILLISECOND
          @current.setMilliseconds 0  if @current.getMilliseconds() < @step
        when TimeScale.SECOND
          @current.setSeconds 0  if @current.getSeconds() < @step
        when TimeScale.MINUTE
          @current.setMinutes 0  if @current.getMinutes() < @step
        when TimeScale.HOUR
          @current.setHours 0  if @current.getHours() < @step
        # intentional fall through
        when TimeScale.WEEKDAY, TimeScale.DAY
          @current.setDate 1  if @current.getDate() < @step + 1
        when TimeScale.MONTH
          @current.setMonth 0  if @current.getMonth() < @step
        when TimeScale.YEAR # nothing to do for year
        else

    # safety mechanism: if current time is still unchanged, move to the end
    @current = new Date(@_end.valueOf())  if @current.valueOf() is prev


  ###
  Get the current datetime
  @return {Date}  current The current date
  ###
  getCurrent: ->
    @current


  ###
  Set a custom scale. Autoscaling will be disabled.
  For example setScale(SCALE.MINUTES, 5) will result
  in minor steps of 5 minutes, and major steps of an hour.

  @param {TimeScale} newScale
  A scale. Choose from SCALE.MILLISECOND,
  SCALE.SECOND, SCALE.MINUTE, SCALE.HOUR,
  SCALE.WEEKDAY, SCALE.DAY, SCALE.MONTH,
  SCALE.YEAR.
  @param {Number}     newStep   A step size, by default 1. Choose for
  example 1, 2, 5, or 10.
  ###
  setScale: (newScale, newStep) ->
    @scale = newScale
    @step = newStep  if newStep > 0
    @autoScale = false


  ###
  Enable or disable autoscaling
  @param {boolean} enable  If true, autoascaling is set true
  ###
  setAutoScale: (enable) ->
    @autoScale = enable


  ###
  Automatically determine the scale that bests fits the provided minimum step
  @param {Number} [minimumStep]  The minimum step size in milliseconds
  ###
  setMinimumStep: (minimumStep) ->
    return  if minimumStep is `undefined`
    stepYear = (1000 * 60 * 60 * 24 * 30 * 12)
    stepMonth = (1000 * 60 * 60 * 24 * 30)
    stepDay = (1000 * 60 * 60 * 24)
    stepHour = (1000 * 60 * 60)
    stepMinute = (1000 * 60)
    stepSecond = (1000)
    stepMillisecond = (1)

    # find the smallest step that is larger than the provided minimumStep
    if stepYear * 1000 > minimumStep
      @scale = TimeScale.YEAR
      @step = 1000
    if stepYear * 500 > minimumStep
      @scale = TimeScale.YEAR
      @step = 500
    if stepYear * 100 > minimumStep
      @scale = TimeScale.YEAR
      @step = 100
    if stepYear * 50 > minimumStep
      @scale = TimeScale.YEAR
      @step = 50
    if stepYear * 10 > minimumStep
      @scale = TimeScale.YEAR
      @step = 10
    if stepYear * 5 > minimumStep
      @scale = TimeScale.YEAR
      @step = 5
    if stepYear > minimumStep
      @scale = TimeScale.YEAR
      @step = 1
    if stepMonth * 3 > minimumStep
      @scale = TimeScale.MONTH
      @step = 3
    if stepMonth > minimumStep
      @scale = TimeScale.MONTH
      @step = 1
    if stepDay * 5 > minimumStep
      @scale = TimeScale.DAY
      @step = 5
    if stepDay * 2 > minimumStep
      @scale = TimeScale.DAY
      @step = 2
    if stepDay > minimumStep
      @scale = TimeScale.DAY
      @step = 1
    if stepDay / 2 > minimumStep
      @scale = TimeScale.WEEKDAY
      @step = 1
    if stepHour * 4 > minimumStep
      @scale = TimeScale.HOUR
      @step = 4
    if stepHour > minimumStep
      @scale = TimeScale.HOUR
      @step = 1
    if stepMinute * 15 > minimumStep
      @scale = TimeScale.MINUTE
      @step = 15
    if stepMinute * 10 > minimumStep
      @scale = TimeScale.MINUTE
      @step = 10
    if stepMinute * 5 > minimumStep
      @scale = TimeScale.MINUTE
      @step = 5
    if stepMinute > minimumStep
      @scale = TimeScale.MINUTE
      @step = 1
    if stepSecond * 15 > minimumStep
      @scale = TimeScale.SECOND
      @step = 15
    if stepSecond * 10 > minimumStep
      @scale = TimeScale.SECOND
      @step = 10
    if stepSecond * 5 > minimumStep
      @scale = TimeScale.SECOND
      @step = 5
    if stepSecond > minimumStep
      @scale = TimeScale.SECOND
      @step = 1
    if stepMillisecond * 200 > minimumStep
      @scale = TimeScale.MILLISECOND
      @step = 200
    if stepMillisecond * 100 > minimumStep
      @scale = TimeScale.MILLISECOND
      @step = 100
    if stepMillisecond * 50 > minimumStep
      @scale = TimeScale.MILLISECOND
      @step = 50
    if stepMillisecond * 10 > minimumStep
      @scale = TimeScale.MILLISECOND
      @step = 10
    if stepMillisecond * 5 > minimumStep
      @scale = TimeScale.MILLISECOND
      @step = 5
    if stepMillisecond > minimumStep
      @scale = TimeScale.MILLISECOND
      @step = 1


  ###
  Snap a date to a rounded value. The snap intervals are dependent on the
  current scale and step.
  @param {Date} date   the date to be snapped
  ###
  snap: (date) ->
    if @scale is TimeScale.YEAR
      year = date.getFullYear() + Math.round(date.getMonth() / 12)
      date.setFullYear Math.round(year / @step) * @step
      date.setMonth 0
      date.setDate 0
      date.setHours 0
      date.setMinutes 0
      date.setSeconds 0
      date.setMilliseconds 0
    else if @scale is TimeScale.MONTH
      if date.getDate() > 15
        date.setDate 1
        date.setMonth date.getMonth() + 1

      # important: first set Date to 1, after that change the month.
      else
        date.setDate 1
      date.setHours 0
      date.setMinutes 0
      date.setSeconds 0
      date.setMilliseconds 0
    else if @scale is TimeScale.DAY or @scale is TimeScale.WEEKDAY

      #noinspection FallthroughInSwitchStatementJS
      switch @step
        when 5, 2
          date.setHours Math.round(date.getHours() / 24) * 24
        else
          date.setHours Math.round(date.getHours() / 12) * 12
      date.setMinutes 0
      date.setSeconds 0
      date.setMilliseconds 0
    else if @scale is TimeScale.HOUR
      switch @step
        when 4
          date.setMinutes Math.round(date.getMinutes() / 60) * 60
        else
          date.setMinutes Math.round(date.getMinutes() / 30) * 30
      date.setSeconds 0
      date.setMilliseconds 0
    else if @scale is TimeScale.MINUTE

      #noinspection FallthroughInSwitchStatementJS
      switch @step
        when 15, 10
          date.setMinutes Math.round(date.getMinutes() / 5) * 5
          date.setSeconds 0
        when 5
          date.setSeconds Math.round(date.getSeconds() / 60) * 60
        else
          date.setSeconds Math.round(date.getSeconds() / 30) * 30
      date.setMilliseconds 0
    else if @scale is TimeScale.SECOND

      #noinspection FallthroughInSwitchStatementJS
      switch @step
        when 15, 10
          date.setSeconds Math.round(date.getSeconds() / 5) * 5
          date.setMilliseconds 0
        when 5
          date.setMilliseconds Math.round(date.getMilliseconds() / 1000) * 1000
        else
          date.setMilliseconds Math.round(date.getMilliseconds() / 500) * 500
    else if @scale is TimeScale.MILLISECOND
      step = (if @step > 5 then @step / 2 else 1)
      date.setMilliseconds Math.round(date.getMilliseconds() / step) * step


  ###
  Check if the current value is a major value (for example when the step
  is DAY, a major value is each first day of the MONTH)
  @return {boolean} true if current date is major, else false.
  ###
  isMajor: ->
    switch @scale
      when TimeScale.MILLISECOND
        @current.getMilliseconds() is 0
      when TimeScale.SECOND
        @current.getSeconds() is 0
      when TimeScale.MINUTE
        (@current.getHours() is 0) and (@current.getMinutes() is 0)

      # Note: this is no bug. Major label is equal for both minute and hour scale
      when TimeScale.HOUR
        @current.getHours() is 0
      # intentional fall through
      when TimeScale.WEEKDAY, TimeScale.DAY
        @current.getDate() is 1
      when TimeScale.MONTH
        @current.getMonth() is 0
      when TimeScale.YEAR
        false
      else
        false


  ###
  Returns formatted text for the minor axislabel, depending on the current
  date and the scale. For example when scale is MINUTE, the current time is
  formatted as "hh:mm".
  @param {Date} [date] custom date. if not provided, current date is taken
  ###
  getLabelMinor: (date) ->
    date = @current  if date is `undefined`
    switch @scale
      when TimeScale.MILLISECOND
        moment(date).format "SSS"
      when TimeScale.SECOND
        moment(date).format "s"
      when TimeScale.MINUTE
        moment(date).format "HH:mm"
      when TimeScale.HOUR
        moment(date).format "HH:mm"
      when TimeScale.WEEKDAY
        moment(date).format "ddd D"
      when TimeScale.DAY
        moment(date).format "D"
      when TimeScale.MONTH
        moment(date).format "MMM"
      when TimeScale.YEAR
        moment(date).format "YYYY"
      else
        ""


  ###
  Returns formatted text for the major axis label, depending on the current
  date and the scale. For example when scale is MINUTE, the major scale is
  hours, and the hour will be formatted as "hh".
  @param {Date} [date] custom date. if not provided, current date is taken
  ###
  getLabelMajor: (date) ->
    date = @current  if date is `undefined`

    #noinspection FallthroughInSwitchStatementJS
    switch @scale
      when TimeScale.MILLISECOND
        moment(date).format "HH:mm:ss"
      when TimeScale.SECOND
        moment(date).format "D MMMM HH:mm"
      when TimeScale.MINUTE, TimeScale.HOUR
        moment(date).format "ddd D MMMM"
      when TimeScale.WEEKDAY, TimeScale.DAY
        moment(date).format "MMMM YYYY"
      when TimeScale.MONTH
        moment(date).format "YYYY"
      when TimeScale.YEAR
        ""
      else
        ""
