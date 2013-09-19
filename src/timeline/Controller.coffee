class Controller
  ###
  @constructor Controller

  A Controller controls the reflows and repaints of all visual components
  ###
  constructor: ->
    @id = util.randomUUID()
    @components = {}
    @repaintTimer = `undefined`
    @reflowTimer = `undefined`

  ###
  Add a component to the controller
  @param {Component} component
  ###
  add: (component) ->

    # validate the component
    throw new Error("Component has no field id")  if component.id is `undefined`
    throw new TypeError("Component must be an instance of " + "prototype Component or Controller")  if (component not instanceof Component) and (component not instanceof Controller)

    # add the component
    component.controller = this
    @components[component.id] = component


  ###
  Remove a component from the controller
  @param {Component | String} component
  ###
  remove: (component) ->
    id = undefined
    for id of @components
      break  if id is component or @components[id] is component  if @components.hasOwnProperty(id)
    delete @components[id]  if id


  ###
  Request a reflow. The controller will schedule a reflow
  @param {Boolean} [force]     If true, an immediate reflow is forced. Default
  is false.
  ###
  requestReflow: (force) ->
    if force
      @reflow()
    else
      unless @reflowTimer
        me = this
        @reflowTimer = setTimeout(->
          me.reflowTimer = `undefined`
          me.reflow()
        , 0)


  ###
  Request a repaint. The controller will schedule a repaint
  @param {Boolean} [force]    If true, an immediate repaint is forced. Default
  is false.
  ###
  requestRepaint: (force) ->
    if force
      @repaint()
    else
      unless @repaintTimer
        me = this
        @repaintTimer = setTimeout(->
          me.repaintTimer = `undefined`
          me.repaint()
        , 0)


  ###
  Repaint all components
  ###
  repaint: ->

    # cancel any running repaint request
    repaint = (component, id) ->
      unless id of done

        # first repaint the components on which this component is dependent
        if component.depends
          component.depends.forEach (dep) ->
            repaint dep, dep.id

        repaint component.parent, component.parent.id  if component.parent

        # repaint the component itself and mark as done
        changed = component.repaint() or changed
        done[id] = true

    changed = false
    if @repaintTimer
      clearTimeout @repaintTimer
      @repaintTimer = `undefined`
    done = {}
    util.forEach @components, repaint

    # immediately reflow when needed
    @reflow()  if changed


  # TODO: limit the number of nested reflows/repaints, prevent loop

  ###
  Reflow all components
  ###
  reflow: ->

    # cancel any running repaint request
    reflow = (component, id) ->
      unless id of done

        # first reflow the components on which this component is dependent
        if component.depends
          component.depends.forEach (dep) ->
            reflow dep, dep.id

        reflow component.parent, component.parent.id  if component.parent

        # reflow the component itself and mark as done
        resized = component.reflow() or resized
        done[id] = true

    resized = false
    if @reflowTimer
      clearTimeout @reflowTimer
      @reflowTimer = `undefined`
    done = {}
    util.forEach @components, reflow

    # immediately repaint when needed
    @repaint()  if resized

  # TODO: limit the number of nested reflows/repaints, prevent loop
