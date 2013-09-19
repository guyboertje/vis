class DataView
  ###
  DataView

  a dataview offers a filtered view on a dataset or an other dataview.

  @param {DataSet | DataView} data
  @param {Object} [options]   Available options: see method get

  @constructor DataView
  ###
  constructor: (data, options) ->
    @id = util.randomUUID()
    @data = null
    @ids = {} # ids of the items currently in memory (just contains a boolean true)
    @options = options or {}
    @fieldId = "id" # name of the field containing id
    @subscribers = {} # event subscribers
    me = this
    @listener = ->
      me._onEvent.apply me, arguments_

    @setData data

  # copy subscription functionality from DataSet
  subscribe: DataSet::subscribe
  unsubscribe: DataSet::unsubscribe
  _trigger: DataSet::_trigger

  ###
  Set a data source for the view
  @param {DataSet | DataView} data
  ###
  setData: (data) ->
    ids = undefined
    dataItems = undefined
    i = undefined
    len = undefined
    if @data

      # unsubscribe from current dataset
      @data.unsubscribe "*", @listener  if @data.unsubscribe

      # trigger a remove of all items in memory
      ids = []
      for id of @ids
        ids.push id  if @ids.hasOwnProperty(id)
      @ids = {}
      @_trigger "remove",
        items: ids

    @data = data
    if @data

      # update fieldId
      @fieldId = @options.fieldId or (@data and @data.options and @data.options.fieldId) or "id"

      # trigger an add of all added items
      ids = @data.getIds(filter: @options and @options.filter)
      i = 0
      len = ids.length

      while i < len
        id = ids[i]
        @ids[id] = true
        i++
      @_trigger "add",
        items: ids


      # subscribe to new dataset
      @data.subscribe "*", @listener  if @data.subscribe


  ###
  Get data from the data view

  Usage:

  get()
  get(options: Object)
  get(options: Object, data: Array | DataTable)

  get(id: Number)
  get(id: Number, options: Object)
  get(id: Number, options: Object, data: Array | DataTable)

  get(ids: Number[])
  get(ids: Number[], options: Object)
  get(ids: Number[], options: Object, data: Array | DataTable)

  Where:

  {Number | String} id         The id of an item
  {Number[] | String{}} ids    An array with ids of items
  {Object} options             An Object with options. Available options:
  {String} [type] Type of data to be returned. Can
  be 'DataTable' or 'Array' (default)
  {Object.<String, String>} [convert]
  {String[]} [fields] field names to be returned
  {function} [filter] filter items
  {String | function} [order] Order the items by
  a field name or custom sort function.
  {Array | DataTable} [data]   If provided, items will be appended to this
  array or table. Required in case of Google
  DataTable.
  @param args
  ###
  get: (args) ->
    me = this

    # parse the arguments
    ids = undefined
    options = undefined
    data = undefined
    firstType = util.getType(arguments_[0])
    if firstType is "String" or firstType is "Number" or firstType is "Array"

      # get(id(s) [, options] [, data])
      ids = arguments_[0] # can be a single id or an array with ids
      options = arguments_[1]
      data = arguments_[2]
    else

      # get([, options] [, data])
      options = arguments_[0]
      data = arguments_[1]

    # extend the options with the default options and provided options
    viewOptions = util.extend({}, @options, options)

    # create a combined filter method when needed
    if @options.filter and options and options.filter
      viewOptions.filter = (item) ->
        me.options.filter(item) and options.filter(item)

    # build up the call to the linked data set
    getArguments = []
    getArguments.push ids  unless ids is `undefined`
    getArguments.push viewOptions
    getArguments.push data
    @data and @data.get.apply(@data, getArguments)


  ###
  Get ids of all items or from a filtered set of items.
  @param {Object} [options]    An Object with options. Available options:
  {function} [filter] filter items
  {String | function} [order] Order the items by
  a field name or custom sort function.
  @return {Array} ids
  ###
  getIds: (options) ->
    ids = undefined
    if @data
      defaultFilter = @options.filter
      filter = undefined
      if options and options.filter
        if defaultFilter
          filter = (item) ->
            defaultFilter(item) and options.filter(item)
        else
          filter = options.filter
      else
        filter = defaultFilter
      ids = @data.getIds(
        filter: filter
        order: options and options.order
      )
    else
      ids = []
    ids


  ###
  Event listener. Will propagate all events from the connected data set to
  the subscribers of the DataView, but will filter the items and only trigger
  when there are changes in the filtered data set.
  @param {String} event
  @param {Object | null} params
  @param {String} senderId
  @private
  ###
  _onEvent: (event, params, senderId) ->
    i = undefined
    len = undefined
    id = undefined
    item = undefined
    ids = params and params.items
    data = @data
    added = []
    updated = []
    removed = []
    if ids and data
      switch event
        when "add"

          # filter the ids of the added items
          i = 0
          len = ids.length

          while i < len
            id = ids[i]
            item = @get(id)
            if item
              @ids[id] = true
              added.push id
            i++
        when "update"

          # determine the event from the views viewpoint: an updated
          # item can be added, updated, or removed from this view.
          i = 0
          len = ids.length

          while i < len
            id = ids[i]
            item = @get(id)
            if item
              if @ids[id]
                updated.push id
              else
                @ids[id] = true
                added.push id
            else
              if @ids[id]
                delete @ids[id]

                removed.push id
              else
            i++

        # nothing interesting for me :-(
        when "remove"

          # filter the ids of the removed items
          i = 0
          len = ids.length

          while i < len
            id = ids[i]
            if @ids[id]
              delete @ids[id]

              removed.push id
            i++
      if added.length
        @_trigger "add",
          items: added
        , senderId
      if updated.length
        @_trigger "update",
          items: updated
        , senderId
      if removed.length
        @_trigger "remove",
          items: removed
        , senderId

