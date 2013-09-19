###
DataSet

Usage:
var dataSet = new DataSet({
fieldId: '_id',
convert: {
// ...
}
});

dataSet.add(item);
dataSet.add(data);
dataSet.update(item);
dataSet.update(data);
dataSet.remove(id);
dataSet.remove(ids);
var data = dataSet.get();
var data = dataSet.get(id);
var data = dataSet.get(ids);
var data = dataSet.get(ids, options, data);
dataSet.clear();

A data set can:
- add/remove/update data
- gives triggers upon changes in the data
- can  import/export data in various data formats
###
class DataSet
  ###
  @param {Object} [options]   Available options:
  {String} fieldId Field name of the id in the
  items, 'id' by default.
  {Object.<String, String} convert
  A map with field names as key,
  and the field type as value.
  @constructor DataSet
  ###

  # TODO: add a DataSet constructor DataSet(data, options)
  constructor: (options) ->
    @id = util.randomUUID()
    @options = options or {}
    @data = {} # map with data indexed by id
    @fieldId = @options.fieldId or "id" # name of the field containing id
    @convert = {} # field types by field name
    if @options.convert
      for field of @options.convert
        if @options.convert.hasOwnProperty(field)
          value = @options.convert[field]
          if value is "Date" or value is "ISODate" or value is "ASPDate"
            @convert[field] = "Date"
          else
            @convert[field] = value

    # event subscribers
    @subscribers = {}
    @internalIds = {} # internally generated id's

  ###
  Subscribe to an event, add an event listener
  @param {String} event        Event name. Available events: 'put', 'update',
  'remove'
  @param {function} callback   Callback method. Called with three parameters:
  {String} event
  {Object | null} params
  {String | Number} senderId
  ###
  subscribe: (event, callback) ->
    subscribers = @subscribers[event]
    unless subscribers
      subscribers = []
      @subscribers[event] = subscribers
    subscribers.push callback: callback


  ###
  Unsubscribe from an event, remove an event listener
  @param {String} event
  @param {function} callback
  ###
  unsubscribe: (event, callback) ->
    subscribers = @subscribers[event]
    if subscribers
      @subscribers[event] = subscribers.filter((listener) ->
        listener.callback isnt callback
      )


  ###
  Trigger an event
  @param {String} event
  @param {Object | null} params
  @param {String} [senderId]       Optional id of the sender.
  @private
  ###
  _trigger: (event, params, senderId) ->
    throw new Error("Cannot trigger event *")  if event is "*"
    subscribers = []
    subscribers = subscribers.concat(@subscribers[event])  if event of @subscribers
    subscribers = subscribers.concat(@subscribers["*"])  if "*" of @subscribers
    i = 0

    while i < subscribers.length
      subscriber = subscribers[i]
      subscriber.callback event, params, senderId or null  if subscriber.callback
      i++


  ###
  Add data.
  Adding an item will fail when there already is an item with the same id.
  @param {Object | Array | DataTable} data
  @param {String} [senderId] Optional sender id
  @return {Array} addedIds      Array with the ids of the added items
  ###
  add: (data, senderId) ->
    addedIds = []
    id = undefined
    me = this
    if data instanceof Array

      # Array
      i = 0
      len = data.length

      while i < len
        id = me._addItem(data[i])
        addedIds.push id
        i++
    else if util.isDataTable(data)

      # Google DataTable
      columns = @_getColumnNames(data)
      row = 0
      rows = data.getNumberOfRows()

      while row < rows
        item = {}
        col = 0
        cols = columns.length

        while col < cols
          field = columns[col]
          item[field] = data.getValue(row, col)
          col++
        id = me._addItem(item)
        addedIds.push id
        row++
    else if data instanceof Object

      # Single item
      id = me._addItem(data)
      addedIds.push id
    else
      throw new Error("Unknown dataType")
    if addedIds.length
      @_trigger "add",
        items: addedIds
      , senderId
    addedIds


  ###
  Update existing items. When an item does not exist, it will be created
  @param {Object | Array | DataTable} data
  @param {String} [senderId] Optional sender id
  @return {Array} updatedIds     The ids of the added or updated items
  ###
  update: (data, senderId) ->
    addedIds = []
    updatedIds = []
    me = this
    fieldId = me.fieldId
    addOrUpdate = (item) ->
      id = item[fieldId]
      if me.data[id]

        # update item
        id = me._updateItem(item)
        updatedIds.push id
      else

        # add new item
        id = me._addItem(item)
        addedIds.push id

    if data instanceof Array

      # Array
      i = 0
      len = data.length

      while i < len
        addOrUpdate data[i]
        i++
    else if util.isDataTable(data)

      # Google DataTable
      columns = @_getColumnNames(data)
      row = 0
      rows = data.getNumberOfRows()

      while row < rows
        item = {}
        col = 0
        cols = columns.length

        while col < cols
          field = columns[col]
          item[field] = data.getValue(row, col)
          col++
        addOrUpdate item
        row++
    else if data instanceof Object

      # Single item
      addOrUpdate data
    else
      throw new Error("Unknown dataType")
    if addedIds.length
      @_trigger "add",
        items: addedIds
      , senderId
    if updatedIds.length
      @_trigger "update",
        items: updatedIds
      , senderId
    addedIds.concat updatedIds


  ###
  Get a data item or multiple items.

  Usage:

  get()
  get(options: Object)
  get(options: Object, data: Array | DataTable)

  get(id: Number | String)
  get(id: Number | String, options: Object)
  get(id: Number | String, options: Object, data: Array | DataTable)

  get(ids: Number[] | String[])
  get(ids: Number[] | String[], options: Object)
  get(ids: Number[] | String[], options: Object, data: Array | DataTable)

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

  @throws Error
  ###
  get: (args) ->
    me = this

    # parse the arguments
    id = undefined
    ids = undefined
    options = undefined
    data = undefined
    firstType = util.getType(arguments_[0])
    if firstType is "String" or firstType is "Number"

      # get(id [, options] [, data])
      id = arguments_[0]
      options = arguments_[1]
      data = arguments_[2]
    else if firstType is "Array"

      # get(ids [, options] [, data])
      ids = arguments_[0]
      options = arguments_[1]
      data = arguments_[2]
    else

      # get([, options] [, data])
      options = arguments_[0]
      data = arguments_[1]

    # determine the return type
    type = undefined
    if options and options.type
      type = (if (options.type is "DataTable") then "DataTable" else "Array")
      throw new Error("Type of parameter \"data\" (" + util.getType(data) + ") " + "does not correspond with specified options.type (" + options.type + ")")  if data and (type isnt util.getType(data))
      throw new Error("Parameter \"data\" must be a DataTable " + "when options.type is \"DataTable\"")  if type is "DataTable" and not util.isDataTable(data)
    else if data
      type = (if (util.getType(data) is "DataTable") then "DataTable" else "Array")
    else
      type = "Array"

    # build options
    convert = options and options.convert or @options.convert
    filter = options and options.filter
    items = []
    item = undefined
    itemId = undefined
    i = undefined
    len = undefined

    # convert items
    unless id is `undefined`

      # return a single item
      item = me._getItem(id, convert)
      item = null  if filter and not filter(item)
    else unless ids is `undefined`

      # return a subset of items
      i = 0
      len = ids.length

      while i < len
        item = me._getItem(ids[i], convert)
        items.push item  if not filter or filter(item)
        i++
    else

      # return all items
      for itemId of @data
        if @data.hasOwnProperty(itemId)
          item = me._getItem(itemId, convert)
          items.push item  if not filter or filter(item)

    # order the results
    @_sort items, options.order  if options and options.order and id is `undefined`

    # filter fields of the items
    if options and options.fields
      fields = options.fields
      unless id is `undefined`
        item = @_filterFields(item, fields)
      else
        i = 0
        len = items.length

        while i < len
          items[i] = @_filterFields(items[i], fields)
          i++

    # return the results
    if type is "DataTable"
      columns = @_getColumnNames(data)
      unless id is `undefined`

        # append a single item to the data table
        me._appendRow data, columns, item
      else

        # copy the items to the provided data table
        i = 0
        len = items.length

        while i < len
          me._appendRow data, columns, items[i]
          i++
      data
    else

      # return an array
      unless id is `undefined`

        # a single item
        item
      else

        # multiple items
        if data

          # copy the items to the provided array
          i = 0
          len = items.length

          while i < len
            data.push items[i]
            i++
          data
        else

          # just return our array
          items

  ###
  Get ids of all items or from a filtered set of items.
  @param {Object} [options]    An Object with options. Available options:
  {function} [filter] filter items
  {String | function} [order] Order the items by
  a field name or custom sort function.
  @return {Array} ids
  ###
  getIds: (options) ->
    data = @data
    filter = options and options.filter
    order = options and options.order
    convert = options and options.convert or @options.convert
    i = undefined
    len = undefined
    id = undefined
    item = undefined
    items = undefined
    ids = []
    if filter

      # get filtered items
      if order

        # create ordered list
        items = []
        for id of data
          if data.hasOwnProperty(id)
            item = @_getItem(id, convert)
            items.push item  if filter(item)
        @_sort items, order
        i = 0
        len = items.length

        while i < len
          ids[i] = items[i][@fieldId]
          i++
      else

        # create unordered list
        for id of data
          if data.hasOwnProperty(id)
            item = @_getItem(id, convert)
            ids.push item[@fieldId]  if filter(item)
    else

      # get all items
      if order

        # create an ordered list
        items = []
        for id of data
          items.push data[id]  if data.hasOwnProperty(id)
        @_sort items, order
        i = 0
        len = items.length

        while i < len
          ids[i] = items[i][@fieldId]
          i++
      else

        # create unordered list
        for id of data
          if data.hasOwnProperty(id)
            item = data[id]
            ids.push item[@fieldId]
    ids

  ###
  Execute a callback function for every item in the dataset.
  The order of the items is not determined.
  @param {function} callback
  @param {Object} [options]    Available options:
  {Object.<String, String>} [convert]
  {String[]} [fields] filter fields
  {function} [filter] filter items
  {String | function} [order] Order the items by
  a field name or custom sort function.
  ###
  forEach: (callback, options) ->
    filter = options and options.filter
    convert = options and options.convert or @options.convert
    data = @data
    item = undefined
    id = undefined
    if options and options.order

      # execute forEach on ordered list
      items = @get(options)
      i = 0
      len = items.length

      while i < len
        item = items[i]
        id = item[@fieldId]
        callback item, id
        i++
    else

      # unordered
      for id of data
        if data.hasOwnProperty(id)
          item = @_getItem(id, convert)
          callback item, id  if not filter or filter(item)

  ###
  Map every item in the dataset.
  @param {function} callback
  @param {Object} [options]    Available options:
  {Object.<String, String>} [convert]
  {String[]} [fields] filter fields
  {function} [filter] filter items
  {String | function} [order] Order the items by
  a field name or custom sort function.
  @return {Object[]} mappedItems
  ###
  map: (callback, options) ->
    filter = options and options.filter
    convert = options and options.convert or @options.convert
    mappedItems = []
    data = @data
    item = undefined

    # convert and filter items
    for id of data
      if data.hasOwnProperty(id)
        item = @_getItem(id, convert)
        mappedItems.push callback(item, id)  if not filter or filter(item)

    # order items
    @_sort mappedItems, options.order  if options and options.order
    mappedItems


  ###
  Filter the fields of an item
  @param {Object} item
  @param {String[]} fields     Field names
  @return {Object} filteredItem
  @private
  ###
  _filterFields: (item, fields) ->
    filteredItem = {}
    for field of item
      filteredItem[field] = item[field]  if item.hasOwnProperty(field) and (fields.indexOf(field) isnt -1)
    filteredItem

  ###
  Sort the provided array with items
  @param {Object[]} items
  @param {String | function} order      A field name or custom sort function.
  @private
  ###
  _sort: (items, order) ->
    if util.isString(order)

      # order by provided field name
      name = order # field name
      items.sort (a, b) ->
        av = a[name]
        bv = b[name]
        (if (av > bv) then 1 else ((if (av < bv) then -1 else 0)))

    else if typeof order is "function"

      # order by sort function
      items.sort order

    # TODO: extend order by an Object {field:String, direction:String}
    #       where direction can be 'asc' or 'desc'
    else
      throw new TypeError("Order must be a function or a string")

  ###
  Remove an object by pointer or by id
  @param {String | Number | Object | Array} id Object or id, or an array with
  objects or ids to be removed
  @param {String} [senderId] Optional sender id
  @return {Array} removedIds
  ###
  remove: (id, senderId) ->
    removedIds = []
    i = undefined
    len = undefined
    removedId = undefined
    if id instanceof Array
      i = 0
      len = id.length

      while i < len
        removedId = @_remove(id[i])
        removedIds.push removedId  if removedId?
        i++
    else
      removedId = @_remove(id)
      removedIds.push removedId  if removedId?
    if removedIds.length
      @_trigger "remove",
        items: removedIds
      , senderId
    removedIds


  ###
  Remove an item by its id
  @param {Number | String | Object} id   id or item
  @returns {Number | String | null} id
  @private
  ###
  _remove: (id) ->
    if util.isNumber(id) or util.isString(id)
      if @data[id]
        delete @data[id]

        delete @internalIds[id]

        return id
    else if id instanceof Object
      itemId = id[@fieldId]
      if itemId and @data[itemId]
        delete @data[itemId]

        delete @internalIds[itemId]

        return itemId
    null

  ###
  Clear the data
  @param {String} [senderId] Optional sender id
  @return {Array} removedIds    The ids of all removed items
  ###
  clear: (senderId) ->
    ids = Object.keys(@data)
    @data = {}
    @internalIds = {}
    @_trigger "remove",
      items: ids
    , senderId
    ids

  ###
  Find the item with maximum value of a specified field
  @param {String} field
  @return {Object | null} item  Item containing max value, or null if no items
  ###
  max: (field) ->
    data = @data
    max = null
    maxField = null
    for id of data
      if data.hasOwnProperty(id)
        item = data[id]
        itemField = item[field]
        if itemField? and (not max or itemField > maxField)
          max = item
          maxField = itemField
    max

  ###
  Find the item with minimum value of a specified field
  @param {String} field
  @return {Object | null} item  Item containing max value, or null if no items
  ###
  min: (field) ->
    data = @data
    min = null
    minField = null
    for id of data
      if data.hasOwnProperty(id)
        item = data[id]
        itemField = item[field]
        if itemField? and (not min or itemField < minField)
          min = item
          minField = itemField
    min

  ###
  Find all distinct values of a specified field
  @param {String} field
  @return {Array} values  Array containing all distinct values. If the data
  items do not contain the specified field, an array
  containing a single value undefined is returned.
  The returned array is unordered.
  ###
  distinct: (field) ->
    data = @data
    values = []
    fieldType = @options.convert[field]
    count = 0
    for prop of data
      if data.hasOwnProperty(prop)
        item = data[prop]
        value = util.convert(item[field], fieldType)
        exists = false
        i = 0

        while i < count
          if values[i] is value
            exists = true
            break
          i++
        unless exists
          values[count] = value
          count++
    values


  ###
  Add a single item. Will fail when an item with the same id already exists.
  @param {Object} item
  @return {String} id
  @private
  ###
  _addItem: (item) ->
    id = item[@fieldId]
    unless id is `undefined`
      # check whether this id is already taken
      throw new Error("Cannot add item: item with id " + id + " already exists")  if @data[id]
    else
      # generate an id
      id = util.randomUUID()
      item[@fieldId] = id
      @internalIds[id] = item
    d = {}
    for field of item
      if item.hasOwnProperty(field)
        fieldType = @convert[field] # type may be undefined
        d[field] = util.convert(item[field], fieldType)
    @data[id] = d
    id

  ###
  Get an item. Fields can be converted to a specific type
  @param {String} id
  @param {Object.<String, String>} [convert]  field types to convert
  @return {Object | null} item
  @private
  ###
  _getItem: (id, convert) ->
    field = undefined
    value = undefined

    # get the item from the dataset
    raw = @data[id]
    return null  unless raw

    # convert the items field types
    converted = {}
    fieldId = @fieldId
    internalIds = @internalIds
    if convert
      for field of raw
        if raw.hasOwnProperty(field)
          value = raw[field]
          # output all fields, except internal ids
          converted[field] = util.convert(value, convert[field])  if (field isnt fieldId) or (value of internalIds)
    else
      # no field types specified, no converting needed
      for field of raw
        if raw.hasOwnProperty(field)
          value = raw[field]
          # output all fields, except internal ids
          converted[field] = value  if (field isnt fieldId) or (value of internalIds)
    converted

  ###
  Update a single item: merge with existing item.
  Will fail when the item has no id, or when there does not exist an item
  with the same id.
  @param {Object} item
  @return {String} id
  @private
  ###
  _updateItem: (item) ->
    id = item[@fieldId]
    throw new Error("Cannot update item: item has no id (item: " + JSON.stringify(item) + ")")  if id is `undefined`
    d = @data[id]

    # item doesn't exist
    throw new Error("Cannot update item: no item with id " + id + " found")  unless d

    # merge with current item
    for field of item
      if item.hasOwnProperty(field)
        fieldType = @convert[field] # type may be undefined
        d[field] = util.convert(item[field], fieldType)
    id

  ###
  Get an array with the column names of a Google DataTable
  @param {DataTable} dataTable
  @return {String[]} columnNames
  @private
  ###
  _getColumnNames: (dataTable) ->
    columns = []
    col = 0
    cols = dataTable.getNumberOfColumns()

    while col < cols
      columns[col] = dataTable.getColumnId(col) or dataTable.getColumnLabel(col)
      col++
    columns

  ###
  Append an item as a row to the dataTable
  @param dataTable
  @param columns
  @param item
  @private
  ###
  _appendRow: (dataTable, columns, item) ->
    row = dataTable.addRow()
    col = 0
    cols = columns.length

    while col < cols
      field = columns[col]
      dataTable.setValue row, col, item[field]
      col++
