###*
 * Kinetic scroll for Webkit-based browsers on mobile devices
 *
 * Copyright (c) 2012 Dmitriy Kubyshkin (http://kubyshkin.ru)
 *
 * Licensed under the MIT license:
 *   http://www.opensource.org/licenses/mit-license.php
###

# Helper function to draw rounded rectangles on canvas
drawRoundRect = (ctx, sx, sy, ex, ey, r) ->
  r2d = Math.PI / 180;
  if (ex - sx) - (2 * r) < 0 then r = (ex - sx) / 2
  if (ey - sy) - (2 * r) < 0 then r = (ey - sy) / 2
  ctx.beginPath()
  ctx.moveTo sx + r, sy
  ctx.lineTo ex - r, sy
  ctx.arc ex - r, sy + r, r, r2d * 270, r2d * 360, false
  ctx.lineTo ex, ey - r
  ctx.arc ex - r, ey - r, r, r2d * 0, r2d * 90, false
  ctx.lineTo sx + r, ey
  ctx.arc sx + r, ey - r, r, r2d * 90, r2d * 180, false
  ctx.lineTo sx, sy + r
  ctx.arc sx + r, sy + r, r, r2d * 180, r2d * 270, false
  ctx.closePath()

# Animation calculation constants
FRAME_RATE = 1000 / 60 # 60 FPS
CHECK_SIZE_RATE = 200 # 5 times per second
FRICTION = 0.96
PAGINATED_FRICTION = 0.99
BOUNCE_FRICTION = 0.75 # This for when we decelerate
BOUNCE_MOVE_FRICTION = 0.5 # and this is for move with finger
CHANGE_PAGE_VELOCITY = 4 # minimum velocity that is required to change page

# Making sure we have requestAnimationFrame
window.requestAnimationFrame ?= (->
  window.webkitRequestAnimationFrame or
  window.mozRequestAnimationFrame or
  window.oRequestAnimationFrame or
  window.msRequestAnimationFrame or
  (->
    # Holds all callbacks scheduled for next animation frame
    callbacks = []

    # Handle for frame timeout
    handle = null

    # Function that will call all callbacks each frame
    processCallbacks = ->
      # We need a copy here because callbacks may need to schedule themselves
      copy = callbacks.slice()
      callbacks = []
      handle = null
      callback.apply this for callback in copy

    # returning function that will receive callbacks
    (callback) ->
      callbacks.push callback if callbacks.indexOf(callback) is -1
      # schedule callbacks call if one hasn't been scheduled already 
      handle = setTimeout processCallbacks, FRAME_RATE unless handle
  )()
)()

# SCROLL BAR RENDERING
SCROLL_PADDING = 15
SCROLL_WIDTH = 6
SCROLL_VISIBLE_OPACTITY = 0.5
SCROLL_FADE_SPEED = 120 # ms

# Support high DPI displays
PIXEL_RATIO = window.devicePixelRatio or 1

# Support desktop events as well as touch events
if 'ontouchstart' of window
  EVENT_DOWN = 'touchstart'
  EVENT_MOVE  = 'touchmove'
  EVENT_UP   = 'touchend'
else
  EVENT_DOWN = 'mousedown'
  EVENT_MOVE  = 'mousemove'
  EVENT_UP   = 'mouseup'

class KineticScroll

  # Flag that shows whether we are scrolling right now
  scrolling: false

  # Flag for deceleration after finger was lifted
  decelerating: false

  # Canvas for horizontal scrollbar
  horizontalBar: null

  # Canvas for vertical scrollbar
  verticalBar: null

  # Thumb size for horizontal scrollbar
  horizontalThumbSize: 0

  # Thumb size for vertical scrollbar
  verticalThumbSize: 0

  # Current horizontal page when using pagination
  currentPageX: 0

  # Total horizontal pages count when using pagination
  pageCountX: 1

  # Current vertical page when using pagination
  currentPageY: 0

  # Total vertical pages count when using pagination
  pageCountY: 1

  # Current proportion of parent height to content height
  verticalProportion: 1

  # Current proportion of parent width to content width
  horizontalProportion: 1

  # Parent width
  parentSizeX: 0

  # Parent height
  parentSizeY: 0

  # Content width
  contentSizeX: 0

  # Content height
  contentSizeY: 0

  # Content adjusted width (not less than parent size)
  contentAdjustedSizeX: 0

  # Content adjusted height (not less than parent size)
  contentAdjustedSizeY: 0

  # Current velocity for horizontal scrolling
  velocityX: 0

  # Current velocity for vertical scrolling
  velocityY: 0

  # Current offset from left
  offsetX: 0

  # Current offset from top
  offsetY: 0

  # Minumum horizontal offset
  minOffsetX: 0

  # Minumum vertical offset
  minOffsetY: 0

  # Maximum horizontal offset
  maxOffsetX: 0

  # Maximum vertical offset
  maxOffsetY: 0

  # Last X coordinate
  lastX: 0

  # Last Y coordinate
  lastY: 0

  # Original target of EVENT_DOWN event. It's necessary to simulate click.
  originalTarget: null

  # Timout handle for checking content height
  checkSizesTimeout: null

  constructor: (el, options = {})->
    # Saving passed options 
    @options =
      vertical: true
      horizontal: false
      paginated: false
      ignoredSelector: 'input, textarea, select' 
    @options[name] = value for name, value of options

    # By default scrollbars are shown if we scroll in that direction
    @options.verticalBar ?= @options.vertical
    @options.horizontalBar ?= @options.horizontal

    # Making sure that parent element isn't scrollable
    @parent = el
    el.style.overflow = 'hidden'

    # Find first child element
    for node in @parent.childNodes
      if node.nodeType is Node.ELEMENT_NODE
        @content = node
        break

    # Helps with flickering
    @content.style.webkitTransform = 'translate3d(0,0,0)'

    # Create bars if necessary
    if @options.vertical and @options.verticalBar
      @createBar 'vertical'
    if @options.horizontal and @options.horizontalBar
      @createBar 'horizontal'

    # Finally starting to listen to user input
    @parent.addEventListener EVENT_DOWN, @down, true

    # Starting to monitor content size to update scroll position
    # This is necessary when content becomes smaller than window
    # It is also important to update scroll bar length
    @checkSizesTimeout = setTimeout @checkSizes, CHECK_SIZE_RATE

  destroy: ->
    @parent.removeEventListener EVENT_DOWN, @down, true
    clearTimeout @checkSizesTimeout

  # Creates a canvas
  createBar: (direction)->
    bar = document.createElement 'canvas'
    bar.style.position = "absolute"
    bar.style.zIndex = 10000
    bar.style.webkitTransition = "opacity #{SCROLL_FADE_SPEED}ms linear"
    if direction is 'vertical'
      bar.style.top = "#{SCROLL_PADDING}px"
      bar.style.width = "#{SCROLL_WIDTH}px"
      bar.style.right = "#{SCROLL_WIDTH}px"
    else
      bar.style.left = "#{SCROLL_PADDING}px"
      bar.style.height = "#{SCROLL_WIDTH}px"
      bar.style.bottom = "#{SCROLL_WIDTH}px"
    @parent.appendChild bar
    @["#{direction}Bar"] = bar

  checkSizes: =>
    return if @scrolling
    clearTimeout @checkSizesTimeout

    parentHeight = @parent.offsetHeight
    contentHeight = @content.offsetHeight
    parentWidth = @parent.offsetWidth
    contentWidth = @content.offsetWidth

    # If all dimensions are zero we assume that element has been removed
    # and we need to garbage collect current object
    unless parentHeight or contentHeight or parentWidth or contentWidth
      return @destroy()

    # Only need to do something if values have changed from previous time
    if parentWidth is @parentSizeX and parentHeight is @parentSizeY and
    contentWidth is @contentSizeX and contentHeight is @contentSizeY
      return @checkSizesTimeout = setTimeout @checkSizes, CHECK_SIZE_RATE

    # Saving new sizes if something changed
    @parentSizeX = parentWidth
    @parentSizeY = parentHeight
    @contentAdjustedSizeX = @contentSizeX = contentWidth
    @contentAdjustedSizeX >= @parentSizeX || (@contentAdjustedSizeX = @parentSizeX)
    @contentAdjustedSizeY = @contentSizeY = contentHeight
    @contentAdjustedSizeY >= @parentSizeY || (@contentAdjustedSizeY = @parentSizeY)

    # For paginated check that we are not outside content
    # and update @currentPageX and @currentPageY
    if @options.paginated
      @checkCurrentPage 'X' if @options.horizontal
      @checkCurrentPage 'Y' if @options.vertical
    else
      # For regular scroll we check for an empty space after shown content
      # if it is not already at the start (zero offset)
      if @options.horizontal and @offsetX isnt 0 and parentWidth > @contentAdjustedSizeX + @offsetX
        @calculateSizes()
        @bounce 'X'
      if @options.vertical and @offsetY isnt 0 and parentHeight > @contentAdjustedSizeY + @offsetY
        @calculateSizes()
        @bounce 'Y'

    # Scheduling next check
    @checkSizesTimeout = setTimeout @checkSizes, CHECK_SIZE_RATE

  setCurrentPage: (xOrY, page)->
    # Check page bounds
    page < @["pageCount#{xOrY}"] or (page = @["pageCount#{xOrY}"] - 1)
    page >= 0 or (page = 0)
    currentPage = @["currentPage#{xOrY}"]
    @["currentPage#{xOrY}"] = page
    if currentPage isnt page and typeof @options.onCurrentPageChange is 'function'
      @options.onCurrentPageChange.call this, @["currentPage#{xOrY}"], xOrY.toLowerCase()

  checkCurrentPage: (xOrY)->
    @calculatePages xOrY
    return unless @["currentPage#{xOrY}"] >= @["pageCount#{xOrY}"]
    @setCurrentPage xOrY, @["pageCount#{xOrY}"] - 1
    @bounce xOrY

  calculateSizes: ->
    if @options.horizontal
      # By default we limit offset based on content size
      @maxOffsetX = @contentAdjustedSizeX - @parentSizeX

      # Pagination may adjust that
      @calculatePages 'X' if @options.paginated

      if @options.horizontalBar
        trackWidth = @parentSizeX - 2 * SCROLL_PADDING
        @horizontalBar.style.width = "#{trackWidth}px"
        @horizontalBar.setAttribute 'width', trackWidth * PIXEL_RATIO
        @horizontalBar.setAttribute 'height', @horizontalBar.offsetHeight * PIXEL_RATIO
        @horizontalProportion = @parentSizeX / @contentAdjustedSizeX
        @horizontalThumbSize = @horizontalProportion * trackWidth * PIXEL_RATIO
        @horizontalProportion *= trackWidth / @parentSizeX

    if @options.vertical
      # By default we limit offset based on content size
      @maxOffsetY = @contentAdjustedSizeY - @parentSizeY

      # Pagination may adjust that
      @calculatePages 'Y' if @options.paginated

      if @options.verticalBar
        trackHeight = @parentSizeY - 2 * SCROLL_PADDING
        @verticalBar.style.height = "#{trackHeight}px"
        @verticalBar.setAttribute 'height', trackHeight * PIXEL_RATIO
        @verticalBar.setAttribute 'width', @verticalBar.offsetWidth * PIXEL_RATIO
        @verticalProportion = @parentSizeY / @contentAdjustedSizeY
        @verticalThumbSize = @verticalProportion * trackHeight * PIXEL_RATIO
        @verticalProportion *= trackHeight / @parentSizeY

  # Calculates min / max offsets and page count for pagination
  calculatePages: (xOrY, range = 1)->
    # Page count is calculated based on content and parent sizes
    newPageCount = Math.ceil @["contentAdjustedSize#{xOrY}"] / @["parentSize#{xOrY}"]
    if newPageCount isnt @["pageCount#{xOrY}"]
      @["pageCount#{xOrY}"] = newPageCount
      if typeof @options.onPageCountChange is 'function'
        @options.onPageCountChange.call this, newPageCount, @["currentPage#{xOrY}"], xOrY.toLowerCase()

    # Minimum offset is based on current page but can be less than zero
    @["minOffset#{xOrY}"] = (@["currentPage#{xOrY}"] - range) * @["parentSize#{xOrY}"]
    @["minOffset#{xOrY}"] >= 0 or (@["minOffset#{xOrY}"] = 0)

    # Maximum offset can't be more than necessary for last page
    @["maxOffset#{xOrY}"] = (@["pageCount#{xOrY}"] - 1) * @["parentSize#{xOrY}"]
    proposed = (@["currentPage#{xOrY}"] + range) * @["parentSize#{xOrY}"]
    @["maxOffset#{xOrY}"] = proposed if proposed < @["maxOffset#{xOrY}"]

  down: (e) =>
    originalEvent = e

    if e.touches then e = e.touches[0] # we need only first touch
    else return unless e.which is 1

    # Saving original target in case we need to simulate click
    @originalTarget = e.target

    # Form elements need special treatment
    return if @originalTarget.webkitMatchesSelector @options.ignoredSelector

    # If element isn't filtered prevent default action on it
    originalEvent.preventDefault()

    # This flag is used to stop decelerating / bouncing if there is one atm
    @scrolling = true

    # Starting to listen to move and end events
    document.addEventListener EVENT_MOVE, @move, true
    document.addEventListener EVENT_UP, @up, true

    # Listening to window blur event to avoid problems where mouse button
    # was lifted outside of active browser window / tab
    window.addEventListener 'blur', @windowBlur, true

    # Initializing necessary properties
    @velocityX = @velocityY = 0
    @lastX = e.clientX
    @lastY = e.clientY

    # Need to update here to avoid weird racing conditions
    @calculateSizes()  

  move: (e) =>
    e.preventDefault()
    if e.touches then e = e.touches[0] # we need only first touch

    # Calculating difference
    @velocityX = e.clientX - @lastX if @options.horizontal
    @velocityY = e.clientY - @lastY if @options.vertical

    # Saving new value
    @lastX = e.clientX
    @lastY = e.clientY

    # we are now moving and not clicking
    if @originalTarget
      @originalTarget = null
      # If we are scrolling after all we need to show scrollbars
      @verticalBar.style.opacity = SCROLL_VISIBLE_OPACTITY if @options.verticalBar
      @horizontalBar.style.opacity = SCROLL_VISIBLE_OPACTITY if @options.horizontalBar

    # When outside bounce we move slower
    if @options.horizontal and (-@offsetX < @minOffsetX or -@offsetX > @maxOffsetX)
      @velocityX *= BOUNCE_MOVE_FRICTION

    # When outside bounce we move slower
    if @options.vertical and (-@offsetY < @minOffsetY or -@offsetY > @maxOffsetY)
      @velocityY *= BOUNCE_MOVE_FRICTION

    # Adjusting offsets
    @offsetX += @velocityX if @options.horizontal
    @offsetY += @velocityY if @options.vertical

    # Moving content and redrawing scrollbar
    requestAnimationFrame @updateStyles

  up: (e) =>
    # Don't need to listen to these events for now
    document.removeEventListener EVENT_MOVE, @move, true
    document.removeEventListener EVENT_UP, @up, true
    window.removeEventListener 'blur', @windowBlur, true
    @scrolling = false

    # If we were scrolling or need to bounce trying to decelerate
    return if @originalTarget
    if @options.horizontal
      if @options.paginated then @deceleratePaginated 'X' else @decelerate 'X'
    if @options.vertical
      if @options.paginated then @deceleratePaginated 'Y' else @decelerate 'Y'

  windowBlur: =>
    @originalTarget = null
    @up()

  deceleratePaginated: (xOrY)->
    return if @scrolling

    # Save current value of current page
    currentPage = @["currentPage#{xOrY}"]

    # If we pulled page further than half
    calculatedPage = Math.round -@["offset#{xOrY}"] / @["parentSize#{xOrY}"]
    if calculatedPage isnt currentPage
      currentPage = calculatedPage
    # Or have enough velocity
    else if Math.abs(@["velocity#{xOrY}"]) > CHANGE_PAGE_VELOCITY
      currentPage += if @["velocity#{xOrY}"] < 0 then 1 else -1

    @setCurrentPage xOrY, currentPage

    # We don't decelerate normally when bouncing
    @["velocity#{xOrY}"] = 0

    # Now recalculating min / max offset for nice change effect via bouncing
    @calculatePages xOrY, 0

    # And then we just bounce given calculated min / max offset
    @bounce xOrY

  decelerate: (xOrY)=>
    # If we are scrolling then there's no need do decelerate just yet
    return if @scrolling

    shouldBounce = -@["offset#{xOrY}"] < @["minOffset#{xOrY}"] or
    -@["offset#{xOrY}"] > @["maxOffset#{xOrY}"]
    
    # If velocity is less than 1 px
    if Math.abs(@["velocity#{xOrY}"]) < 1
      @["velocity#{xOrY}"] = 0
      return if shouldBounce then @bounce xOrY else @finishScroll xOrY

    # Reducing velocity
    @["velocity#{xOrY}"] *= if shouldBounce
      BOUNCE_FRICTION * FRICTION
    else
      FRICTION

    # Calculating new offset
    @["offset#{xOrY}"] += @["velocity#{xOrY}"]

    # Scheduling next deceleration step
    requestAnimationFrame @updateStyles
    requestAnimationFrame => @decelerate xOrY

  bounce: (xOrY)=>
    # We don't need to bounce if we are scrolling
    return if @scrolling

    # When bouncing we have velocity based on how much is outside of bounds
    # so we need to calculate that first. We start by current offset
    realOffset = @["offset#{xOrY}"]

    # And then add min or max offset based on the direction to see how
    # much is outside of those bounds
    realOffset += if @["offset#{xOrY}"] < -@["minOffset#{xOrY}"]
      @["maxOffset#{xOrY}"]
    else
      @["minOffset#{xOrY}"]

    # Then we reduce offset by fraction of what's outside of bounds
    @["offset#{xOrY}"] -= realOffset * (1 - BOUNCE_FRICTION)

    # Stop if outside is less than 1 px
    if Math.abs(realOffset) < 1
      @finishScroll xOrY
    else
      requestAnimationFrame @updateStyles
      requestAnimationFrame => @bounce xOrY

  finishScroll: (xOrY)=>
    # Making sure we are aligned to pixels
    @["offset#{xOrY}"] = if Math.abs(@["offset#{xOrY}"] + @["minOffset#{xOrY}"]) < 1
      -@["minOffset#{xOrY}"]
    else
      Math.ceil @["offset#{xOrY}"]
    @content.style.webkitTransform = "translate3d(#{@offsetX}px,#{@offsetY}px,0)"

    unless @velocityX or @velocityY
      @checkSizesTimeout = setTimeout @checkSizes, CHECK_SIZE_RATE

    # Hiding scrollbar if they are present
    if xOrY is 'X'
      @horizontalBar.style.opacity = 0 if @options.horizontalBar
    else
      @verticalBar.style.opacity = 0 if @options.verticalBar

  updateStyles: =>
    # Moving content
    @content.style.webkitTransform = "translate3d(#{@offsetX}px,#{@offsetY}px,0)"
    
    # Drawing scroll bars
    r = SCROLL_WIDTH * PIXEL_RATIO

    # Vertical if necessary
    if @options.vertical and @options.verticalBar
      height = @verticalBar.offsetHeight * PIXEL_RATIO
      ctx = @verticalBar.getContext '2d'
      ctx.strokeStyle = '#fff'
      ctx.clearRect 0, 0, r, height
      offset = -@verticalProportion * @offsetY * PIXEL_RATIO
      bottom = @verticalThumbSize + offset

      # Making sure that respect bounds
      if bottom > height - 1 then bottom = height - 1
      if bottom < r then bottom = r
      if offset < 1 then offset = 1
      if offset > height - r then offset = height - r
    
      # And drow the rect
      drawRoundRect ctx, 0.5, offset, r - 0.5, bottom, r / 2 - 1
      ctx.fill()
      ctx.stroke()

    # Horizontal if necessary
    if @options.horizontal and @options.horizontalBar
      width = @horizontalBar.offsetWidth * PIXEL_RATIO
      ctx = @horizontalBar.getContext '2d'
      ctx.strokeStyle = '#fff'
      ctx.clearRect 0, 0, width, r
      offset = -@horizontalProportion * @offsetX * PIXEL_RATIO
      right = @horizontalThumbSize + offset

      # Making sure that respect bounds
      if right > width - 1 then right = width - 1
      if right < r then right = r
      if offset < 1 then offset = 1
      if offset > width - r then offset = width - r
    
      # And drow the rect
      drawRoundRect ctx, offset, 0.5, right, r - 0.5, r / 2 - 1
      ctx.fill()
      ctx.stroke()

if typeof module is 'object'
  module.exports = KineticScroll
else
  window['KineticScroll'] = KineticScroll
