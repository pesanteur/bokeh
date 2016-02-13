_ = require "underscore"

canvas_template = require "./canvas_template"
LayoutBox = require "./layout_box"

BokehView = require "../../core/bokeh_view"
{EQ} = require "../../core/layout/solver"
{logger} = require "../../core/logging"
{fixup_image_smoothing, fixup_line_dash, fixup_line_dash_offset, fixup_measure_text, get_scale_ratio} = require "../../core/util/canvas"

# TODO - This should only be on in testing
#require 'Canteen'

class CanvasView extends BokehView
  className: "bk-canvas-wrapper"
  template: canvas_template

  initialize: (options) ->
    super(options)

    html = @template({ map: @mget('map') })
    @$el.html(html)

    # for compat, to be removed
    @canvas_wrapper = @$el

    @canvas = @$('canvas.bk-canvas')
    @canvas_events = @$('div.bk-canvas-events')
    @canvas_overlay = @$('div.bk-canvas-overlays')
    @map_div = @$('div.bk-canvas-map') ? null

    # Create context. This is the object that gets passed around while drawing
    @ctx = @canvas[0].getContext('2d')
    @ctx.glcanvas = null  # init without webgl support (can be overriden in plot.coffee)

    # work around canvas incompatibilities
    fixup_line_dash(@ctx)
    fixup_line_dash_offset(@ctx)
    fixup_image_smoothing(@ctx)
    fixup_measure_text(@ctx)

    logger.debug("CanvasView initialized")

  render: (force=false) ->
    # normally we only want to render the canvas when the canvas dimensions change
    if not @model.new_bounds and not force
      return

    ratio = get_scale_ratio(@ctx, @mget('use_hidpi'))

    width = @mget('width')
    height = @mget('height')

    @$el.attr('style', "z-index: 50; width:#{width}px; height:#{height}px")
    @canvas.attr('style', "width:#{width}px;height:#{height}px")
    @canvas.attr('width', width*ratio).attr('height', height*ratio)
    @$el.attr("width", width).attr('height', height)

    @canvas_events.attr('style', "z-index:100; position:absolute; top:0; left:0; width:#{width}px; height:#{height}px;")
    @canvas_overlay.attr('style', "z-index:75; position:absolute; top:0; left:0; width:#{width}px; height:#{height}px;")

    @ctx.scale(ratio, ratio)
    @ctx.translate(0.5, 0.5)

    @model.new_bounds = false

class Canvas extends LayoutBox.Model
  type: 'Canvas'
  default_view: CanvasView

  initialize: (attr, options) ->
    super(attr, options)
    @new_bounds = true
    logger.debug("Canvas initialized")

  _doc_attached: () ->
    super()
    solver = @document.solver()
    solver.add_constraint(EQ(@_left))
    solver.add_constraint(EQ(@_bottom))
    @_set_dims([@get('canvas_width'), @get('canvas_height')])
    logger.debug("Canvas attached to document")

  # transform view coordinates to underlying screen coordinates
  vx_to_sx: (x) ->
    return x

  vy_to_sy: (y) ->
    # Note: +1 to account for 1px canvas dilation
    return @get('height') - (y + 1)

  # vectorized versions of vx_to_sx/vy_to_sy, these are mutating, in-place operations
  v_vx_to_sx: (xx) ->
    for x, idx in xx
      xx[idx] = x
    return xx

  v_vy_to_sy: (yy) ->
    canvas_height = @get('height')
    # Note: +1 to account for 1px canvas dilation
    for y, idx in yy
      yy[idx] = canvas_height - (y + 1)
    return yy

  # transform underlying screen coordinates to view coordinates
  sx_to_vx: (x) ->
    return x

  sy_to_vy: (y) ->
    # Note: +1 to account for 1px canvas dilation
    return @get('height') - (y + 1)

  # vectorized versions of sx_to_vx/sy_to_vy, these are mutating, in-place operations
  v_sx_to_vx: (xx) ->
    for x, idx in xx
      xx[idx] = x
    return xx

  v_sy_to_vy: (yy) ->
    canvas_height = @get('height')
    # Note: +1 to account for 1px canvas dilation
    for y, idx in yy
      yy[idx] = canvas_height - (y + 1)
    return yy

  _set_width: (width, update=true) ->
    solver = @document.solver()
    if @_width_constraint?
      solver.remove_constraint(@_width_constraint)
    @_width_constraint = EQ(@_width, -width)
    solver.add_constraint(@_width_constraint)
    if update
      solver.update_variables()
    @new_bounds = true

  _set_height: (height, update=true) ->
    solver = @document.solver()
    if @_height_constraint?
      solver.remove_constraint(@_height_constraint)
    @_height_constraint = EQ(@_height, -height)
    solver.add_constraint(@_height_constraint)
    if update
      solver.update_variables()
    @new_bounds = true

  _set_dims: (dims, trigger=true) ->
    @_set_width(dims[0], false)
    @_set_height(dims[1], false)
    @document.solver().update_variables(trigger)

  defaults: ->
    return _.extend {}, super(), {
      width: 300
      height: 300
      map: false
      mousedown_callbacks: []
      mousemove_callbacks: []
      use_hidpi: true
    }

module.exports =
  Model: Canvas
