root = exports ? this

export first-non-null = (...args) ->
  for x in args
    if x?
      return x

export getUrlParameters = ->
  url = window.location.href
  hash = url.lastIndexOf('#')
  if hash != -1
    url = url.slice(0, hash)
  map = {}
  parts = window.location.href.replace(/[?&]+([^=&]+)=([^&]*)/gi, (m,key,value) ->
    map[key] = decodeURI(value)
  )
  return map

export setvar = (varname, varval) ->
  if localStorage?
    localStorage.setItem varname, varval
  $.cookie varname, varval, {expires: 365, path: '/'}
  return

export getvar = (varname) ->
  if localStorage?
    output = localStorage.getItem varname
    if output?
      return output
  return $.cookie varname

export get-user-events = (callback) ->
  $.get '/getuserevents?' + $.param({username: get-user-name()}), (events) ->
    callback <| JSON.parse events

export get-condition = (callback) ->
  $.get '/conditionforuser?' + $.param({username: get-user-name()}), (condition) ->
    callback <| parseInt condition

export get-user-name = ->
  #if root.fullname?
  #  return root.fullname
  root.fullname = getvar 'fullname'
  if root.fullname?
    return root.fullname
  root.fullname = getvar 'username'
  if root.fullname?
    return root.fullname
  return 'Anonymous User'

export printcb = (...args) ->
  for x in args
    console.log x

export forcehttps = ->
  #if window.location.href.startsWith('http://feedlearn.herokuapp.com')
  if window.location.href.indexOf('http://feedlearn.herokuapp.com') == 0
    window.location.href = window.location.href.split('http://feedlearn.herokuapp.com').join('https://feedlearn.herokuapp.com')

export updatecookies = ->
  username = get-user-name()
  if not username? or username == 'Anonymous User' or username.length == 0
    return
  $.getJSON ('/cookiesforuser?' + $.param({username: username})), (cookies) ->
    #console.log cookies
    if not cookies.username?
      return
    if cookies.username != username
      return
    needrefresh = false
    for k,v of cookies
      #console.log k
      #console.log v
      if k == 'username'
        continue
      if not v?
        continue
      curv = getvar(k)
      if (not curv?) or v.toString() != curv.toString()
        needrefresh = true
        setvar k, v
    if needrefresh
      window.location = window.location
