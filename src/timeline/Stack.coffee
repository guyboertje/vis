
class Stack

  ###
  @constructor Stack
  Stacks items on top of each other.
  @param {ItemSet} parent
  @param {Object} [options]
  ###
  constructor: (parent, options) ->
    @parent = parent
    @options = options or {}
    @defaultOptions =
      order: (a, b) ->

        #return (b.width - a.width) || (a.left - b.left);  // TODO: cleanup
        # Order: ranges over non-ranges, ranged ordered by width, and
        # lastly ordered by start.
        if a instanceof ItemRange
          if b instanceof ItemRange
            aInt = (a.data.end - a.data.start)
            bInt = (b.data.end - b.data.start)
            (aInt - bInt) or (a.data.start - b.data.start)
          else
            -1
        else
          if b instanceof ItemRange
            1
          else
            a.data.start - b.data.start

      margin:
        item: 10

    @ordered = [] # ordered items

  ###
  Set options for the stack
  @param {Object} options  Available options:
  {ItemSet} parent
  {Number} margin
  {function} order  Stacking order
  ###
  setOptions: (options) ->
    util.extend @options, options


  # TODO: register on data changes at the connected parent itemset, and update the changed part only and immediately

  ###
  Stack the items such that they don't overlap. The items will have a minimal
  distance equal to options.margin.item.
  ###
  update: ->
    @_order()
    @_stack()

  ###
  Order the items. The items are ordered by width first, and by left position
  second.
  If a custom order function has been provided via the options, then this will
  be used.
  @private
  ###
  _order: ->
    items = @parent.items
    throw new Error("Cannot stack items: parent does not contain items")  unless items

    # TODO: store the sorted items, to have less work later on
    ordered = []
    index = 0

    # items is a map (no array)
    util.forEach items, (item) ->
      if item.visible
        ordered[index] = item
        index++


    #if a customer stack order function exists, use it.
    order = @options.order or @defaultOptions.order
    throw new Error("Option order must be a function")  unless typeof order is "function"
    ordered.sort order
    @ordered = ordered


  ###
  Adjust vertical positions of the events such that they don't overlap each
  other.
  @private
  ###
  _stack: ->
    i = undefined
    iMax = undefined
    ordered = @ordered
    options = @options
    orientation = options.orientation or @defaultOptions.orientation
    axisOnTop = (orientation is "top")
    margin = undefined
    if options.margin and options.margin.item isnt `undefined`
      margin = options.margin.item
    else
      margin = @defaultOptions.margin.item

    # calculate new, non-overlapping positions
    i = 0
    iMax = ordered.length

    while i < iMax
      item = ordered[i]
      collidingItem = null
      loop

        # TODO: optimize checking for overlap. when there is a gap without items,
        #  you only need to check for items from the next item on, not from zero
        collidingItem = @checkOverlap(ordered, i, 0, i - 1, margin)
        if collidingItem?

          # There is a collision. Reposition the event above the colliding element
          if axisOnTop
            item.top = collidingItem.top + collidingItem.height + margin
          else
            item.top = collidingItem.top - item.height - margin
        break unless collidingItem
      i++


  ###
  Check if the destiny position of given item overlaps with any
  of the other items from index itemStart to itemEnd.
  @param {Array} items     Array with items
  @param {int}  itemIndex  Number of the item to be checked for overlap
  @param {int}  itemStart  First item to be checked.
  @param {int}  itemEnd    Last item to be checked.
  @return {Object | null}  colliding item, or undefined when no collisions
  @param {Number} margin   A minimum required margin.
  If margin is provided, the two items will be
  marked colliding when they overlap or
  when the margin between the two is smaller than
  the requested margin.
  ###
  checkOverlap: (items, itemIndex, itemStart, itemEnd, margin) ->
    collision = @collision

    # we loop from end to start, as we suppose that the chance of a
    # collision is larger for items at the end, so check these first.
    a = items[itemIndex]
    i = itemEnd

    while i >= itemStart
      b = items[i]
      return b  unless i is itemIndex  if collision(a, b, margin)
      i--
    null


  ###
  Test if the two provided items collide
  The items must have parameters left, width, top, and height.
  @param {Component} a     The first item
  @param {Component} b     The second item
  @param {Number} margin   A minimum required margin.
  If margin is provided, the two items will be
  marked colliding when they overlap or
  when the margin between the two is smaller than
  the requested margin.
  @return {boolean}        true if a and b collide, else false
  ###
  collision: (a, b, margin) ->
    (a.left - margin) < (b.left + b.width) and
    (a.left + a.width + margin) > b.left and
    (a.top - margin) < (b.top + b.height) and
    (a.top + a.height + margin) > b.top
