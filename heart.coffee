shuffle = (array) ->
  """Shuffle an array in place."""
  # http://stackoverflow.com/questions/6274339/how-can-i-shuffle-an-array-in-javascript
  # Sensible language would have this in stdlib
  top = array.length

  if top
    while --top
      current = Math.floor(Math.random() * (top + 1))
      tmp = array[current]
      array[current] = array[top]
      array[top] = tmp

  array

getFauxBBox = (path) ->
  """HACK (Mispy): This function calculates a visual bounding box
     for an SVG path element without actually rendering it, by running
     along the path and looking for the edgiest points."""
  pathlen = path.getTotalLength()
  step = pathlen/100
  
  left = 0
  top = 0
  right = 0
  bottom = 0

  for i in [0..pathlen] by step
    point = path.getPointAtLength(i)
    if point.x < left then left = point.x
    if point.x > right then right = point.x
    if point.y < top then top = point.y
    if point.y > bottom then bottom = point.y

  return { left: left, top: top, right: right, bottom: bottom }

# Node particulation functions are adapted from fontbomb
# https://github.com/plehoux/fontBomb/tree/master/src/coffee
# Unlike fontbomb, we don't particulate characters, as
# this rapidly becomes inefficient.

particulateNodes = (nodes)->
  for node in nodes
    particulateNode(node)

particulateNode = (node)->
  for name in ['script','style','iframe','canvas','video','audio','textarea','embed','object','select','area','map','input']
    return if node.nodeName.toLowerCase() == name
  switch node.nodeType
    when 1 then particulateNodes(node.childNodes)
    when 3
      unless /^\s*$/.test(node.nodeValue)
        if node.parentNode.childNodes.length == 1
          node.parentNode.innerHTML = particulateText(node.nodeValue)
        else
          newNode           = document.createElement("particles")
          newNode.innerHTML = particulateText(node.nodeValue)
          node.parentNode.replaceChild newNode, node

particulateText = (string)->
  chars = for char, index in string.split ' '
    unless /^\s*$/.test(char) then "<word style='white-space:nowrap'>#{char}</word>" else char
  chars.join(' ')

class Heart
  # Heart can reconstruct any SVG path. An interesting exercise would be to
  # extend this to reconstruct an arbitrary number of SVG paths (and thus an
  # entire complex image)
  HEART_PATH = "M 297.29747,550.86823 C 283.52243,535.43191 249.1268,505.33855 220.86277,483.99412 C 137.11867,420.75228 125.72108,411.5999 91.719238,380.29088 C 29.03471,322.57071 2.413622,264.58086 2.5048478,185.95124 C 2.5493594,147.56739 5.1656152,132.77929 15.914734,110.15398 C 34.151433,71.768267 61.014996,43.244667 95.360052,25.799457 C 119.68545,13.443675 131.6827,7.9542046 172.30448,7.7296236 C 214.79777,7.4947896 223.74311,12.449347 248.73919,26.181459 C 279.1637,42.895777 310.47909,78.617167 316.95242,103.99205 L 320.95052,119.66445 L 330.81015,98.079942 C 386.52632,-23.892986 564.40851,-22.06811 626.31244,101.11153 C 645.95011,140.18758 648.10608,223.6247 630.69256,270.6244 C 607.97729,331.93377 565.31255,378.67493 466.68622,450.30098 C 402.0054,497.27462 328.80148,568.34684 323.70555,578.32901 C 317.79007,589.91654 323.42339,580.14491 297.29747,550.86823 z"

  constructor: ->
    # Make a ghostly SVG path element. This is not attached to the DOM 
    # anywhere; it's solely used for calculating coordinates.
    @path = document.createElementNS("http://www.w3.org/2000/svg", 'path')
    @path.setAttribute('d', HEART_PATH)
    @path.style['stroke-width'] = 2
    @path.style['stroke'] = 'none'
    @path.style['fill'] = 'none'

    # Calculate some dimensions for layout purposes
    @length = @path.getTotalLength()
    bbox = getFauxBBox(@path)
    @width = bbox.right - bbox.left
    @height = bbox.bottom - bbox.top

    # We need to do some initial reconstruction of the page
    # to make words manipulable elements in their own right.
    # This USUALLY leaves the page functionally and visually
    # intact.
    @body = document.getElementsByTagName('body')[0]
    particulateNodes(@body.childNodes)

    @pending = [] # Populated with nodes which need to be moved.

  tick: =>
    """Animation initiation loop for @pending nodes."""
    # It's structured like this to prevent too many setTimeouts
    # from being activated at once, because the browser doesn't
    # really enjoy that.
    return if @pending.length == 0

    count = 0
    while count < 3
      {node, dest} = @pending.pop() # Destructuring assignment <3
      if dest
        @fetch(node, dest)
      else
        @unfetch(node)
      count += 1

    setTimeout(@tick, 30)
    

  find_nodes: ->
    """Returns an array of word nodes that we want to manipuate."""
    nodes = Array.prototype.slice.call(document.getElementsByTagName('word'))
    # A picture is worth a thousand words but more than that
    # causes serious efficiency problems.
    if nodes.length > 1000
      nodes = nodes.slice(0, 1000)
    nodes

  fetch: (node, dest) ->
    """Starts a node flying towards dest."""

    # Switch the node to fixed positioning using offset
    # coordinates to keep it in its original visual location.
    bbox = node.getBoundingClientRect()
    width = bbox.right - bbox.left
    height = bbox.bottom - bbox.top
    node.style['position'] = 'fixed'
    node.style['z-index'] = 9999
    node.style['left'] = bbox.left+'px'
    node.style['top'] = bbox.top+'px'
    node.style['display'] = 'inline-block'

    # Target calculation needs to center the heart while accounting for
    # window size scaling.
    tx = (((@ww-@scale)/2 + ((@scale/@width) * dest.x)) - width/2)
    ty = (((@wh-@scale)/2 + ((@scale/@height) * dest.y)) + height/2)
    emile(node, "left: #{tx}px; top: #{ty}px;", {
      duration: 500
      after: =>
        @moving -= 1
    })

  form: ->
    """Commence heart formation."""

    # We calculate scaling here in case the window changed
    # size since the Heart was initialized.
    @ww = window.innerWidth-30
    @wh = window.innerHeight-50
    @scale = Math.min(@ww, @wh)

    nodes = @find_nodes()
    shuffle(nodes)
    interdist = @length / nodes.length # Distance between nodes along the heartline

    dests = []
    for node, i in nodes
      dests.push @path.getPointAtLength(i*interdist)
    # shuffle(dests) (uncomment this to make heart formation non-linear)

    @moving = nodes.length
    for node, i in nodes
      # Keep track of the node's original position so we know
      # how to put it back later.
      offset = node.getBoundingClientRect()
      node.setAttribute('data-origleft', offset.left)
      node.setAttribute('data-origtop', offset.top)
      dest = dests.pop()
      do (node, dest) =>
        @pending.push { node: node, dest: dest }

    @tick() # This is where animations actually happen.

    # We're not actually formed at this point; words have
    # only just started flying. But the toggle which looks
    # at this won't activate until @moving is at 0.
    @formed = true

  unfetch: (node) ->
    """Flies a node back to its original page position."""
    tx = node.getAttribute('data-origleft')
    ty = node.getAttribute('data-origtop')
    emile(node, "left: #{tx}px; top: #{ty}px;", {
      duration: 500
      after: =>
        # XXX (Mispy): We clobber any inline styles that might
        # have originated from other sources here. Fortunately,
        # sensible sites will use inline styles sparingly.
        node.style['position'] = ''
        node.style['z-index'] = ''
        node.style['display'] = ''
        @moving -= 1
    })

  unform: ->
    """Unform the heart and return nodes to their original places."""
    nodes = @find_nodes()
    nodes.reverse() # So the DOM flow looks sensible as it is built.
    @moving = nodes.length
    for node, i in nodes
      do (node) =>
        @pending.push { node: node }

    @tick()
    @formed = false

  toggle: ->
    """Switch between heart states, but only if no animation is
       currently in progress. This is what the bookmarklet calls."""
    if @moving > 0
      return
    if @formed
      @unform()
    else
      @form()

ready = (func) ->
  """Hacky $(document).ready() equivalent."""
  # http://stackoverflow.com/questions/799981/document-ready-equivalent-without-jquery 
  if /in/.test(document.readyState)
    setTimeout(ready, 9, func)
  else
    func()

ready -> 
  return if window.heartless # Don't run on the origin page :)
  unless window.heart?
    window.heart = new Heart()
  window.heart.toggle()
