class Timeline
  ###
  Create a timeline visualization
  @param {HTMLElement} container
  @param {vis.DataSet | Array | DataTable} [items]
  @param {Object} [options]  See Timeline.setOptions for the available options.
  @constructor
  ###
  constructor: (container, items, options) ->
    me = this
    @options = util.extend(
      orientation: "bottom"
      min: null
      max: null
      zoomMin: 10 # milliseconds
      zoomMax: 1000 * 60 * 60 * 24 * 365 * 10000 # milliseconds
      # moveable: true, // TODO: option moveable
      # zoomable: true, // TODO: option zoomable
      showMinorLabels: true
      showMajorLabels: true
      autoResize: false
    , options)

    # controller
    @controller = new Controller()

    # root panel
    throw new Error("No container element provided")  unless container
    rootOptions = Object.create(@options)
    rootOptions.height = ->
      if me.options.height

        # fixed height
        me.options.height
      else

        # auto height
        me.timeaxis.height + me.content.height

    @rootPanel = new RootPanel(container, rootOptions)
    @controller.add @rootPanel

    # item panel
    itemOptions = Object.create(@options)
    itemOptions.left = ->
      me.labelPanel.width

    itemOptions.width = ->
      me.rootPanel.width - me.labelPanel.width

    itemOptions.top = null
    itemOptions.height = null
    @itemPanel = new Panel(@rootPanel, [], itemOptions)
    @controller.add @itemPanel

    # label panel
    labelOptions = Object.create(@options)
    labelOptions.top = null
    labelOptions.left = null
    labelOptions.height = null
    labelOptions.width = ->
      if me.content and typeof me.content.getLabelsWidth is "function"
        me.content.getLabelsWidth()
      else
        0

    @labelPanel = new Panel(@rootPanel, [], labelOptions)
    @controller.add @labelPanel

    # range
    now = moment().hours(0).minutes(0).seconds(0).milliseconds(0)
    @range = new Range(
      start: now.clone().add("days", -3).valueOf()
      end: now.clone().add("days", 4).valueOf()
    )

    # TODO: reckon with options moveable and zoomable
    @range.subscribe @rootPanel, "move", "horizontal"
    @range.subscribe @rootPanel, "zoom", "horizontal"
    @range.on "rangechange", ->
      force = true
      me.controller.requestReflow force

    @range.on "rangechanged", ->
      force = true
      me.controller.requestReflow force


    # TODO: put the listeners in setOptions, be able to dynamically change with options moveable and zoomable

    # time axis
    timeaxisOptions = Object.create(rootOptions)
    timeaxisOptions.range = @range
    timeaxisOptions.left = null
    timeaxisOptions.top = null
    timeaxisOptions.width = "100%"
    timeaxisOptions.height = null
    @timeaxis = new TimeAxis(@itemPanel, [], timeaxisOptions)
    @timeaxis.setRange @range
    @controller.add @timeaxis

    # create itemset or groupset
    @setGroups null
    @itemsData = null # DataSet
    @groupsData = null # DataSet

    # set data
    @setItems items  if items

  ###
  Set options
  @param {Object} options  TODO: describe the available options
  ###
  setOptions: (options) ->
    util.extend @options, options  if options
    @controller.reflow()
    @controller.repaint()


  ###
  Set items
  @param {vis.DataSet | Array | DataTable | null} items
  ###
  setItems: (items) ->
    initialLoad = (not (@itemsData?))

    # convert to type DataSet when needed
    newItemSet = undefined
    unless items
      newItemSet = null
    else newItemSet = items  if items instanceof DataSet
    unless items instanceof DataSet
      newItemSet = new DataSet(convert:
        start: "Date"
        end: "Date"
      )
      newItemSet.add items

    # set items
    @itemsData = newItemSet
    @content.setItems newItemSet
    if initialLoad and (@options.start is `undefined` or @options.end is `undefined`)

      # apply the data range as range
      dataRange = @getItemRange()

      # add 5% on both sides
      min = dataRange.min
      max = dataRange.max
      if min? and max?
        interval = (max.valueOf() - min.valueOf())
        min = new Date(min.valueOf() - interval * 0.05)
        max = new Date(max.valueOf() + interval * 0.05)

      # override specified start and/or end date
      min = new Date(@options.start.valueOf())  unless @options.start is `undefined`
      max = new Date(@options.end.valueOf())  unless @options.end is `undefined`

      # apply range if there is a min or max available
      @range.setRange min, max  if min? or max?


  ###
  Set groups
  @param {vis.DataSet | Array | DataTable} groups
  ###
  setGroups: (groups) ->
    me = this
    @groupsData = groups

    # switch content type between ItemSet or GroupSet when needed
    type = (if @groupsData then GroupSet else ItemSet)
    unless @content instanceof type

      # remove old content set
      if @content
        @content.hide()
        @content.setItems()  if @content.setItems # disconnect from items
        @content.setGroups()  if @content.setGroups # disconnect from groups
        @controller.remove @content

      # create new content set
      options = Object.create(@options)
      util.extend options,
        top: ->
          if me.options.orientation is "top"
            me.timeaxis.height
          else
            me.itemPanel.height - me.timeaxis.height - me.content.height

        left: null
        width: "100%"
        height: ->
          if me.options.height
            me.itemPanel.height - me.timeaxis.height
          else
            null

        maxHeight: ->
          if me.options.maxHeight
            throw new TypeError("Number expected for property maxHeight")  unless util.isNumber(me.options.maxHeight)
            me.options.maxHeight - me.timeaxis.height
          else
            null

        labelContainer: ->
          me.labelPanel.getContainer()

      @content = new type(@itemPanel, [@timeaxis], options)
      @content.setRange @range  if @content.setRange
      @content.setItems @itemsData  if @content.setItems
      @content.setGroups @groupsData  if @content.setGroups
      @controller.add @content


  ###
  Get the data range of the item set.
  @returns {{min: Date, max: Date}} range  A range with a start and end Date.
  When no minimum is found, min==null
  When no maximum is found, max==null
  ###
  getItemRange: ->

    # calculate min from start filed
    itemsData = @itemsData
    min = null
    max = null
    if itemsData

      # calculate the minimum value of the field 'start'
      minItem = itemsData.min("start")
      min = (if minItem then minItem.start.valueOf() else null)

      # calculate maximum value of fields 'start' and 'end'
      maxStartItem = itemsData.max("start")
      max = maxStartItem.start.valueOf()  if maxStartItem
      maxEndItem = itemsData.max("end")
      if maxEndItem
        unless max?
          max = maxEndItem.end.valueOf()
        else
          max = Math.max(max, maxEndItem.end.valueOf())
    min: (if (min?) then new Date(min) else null)
    max: (if (max?) then new Date(max) else null)
