root = exports ? this

J = $.jade

{find-index} = require \prelude-ls

{first-non-null, getUrlParameters} = root # commonlib.ls
{addlog} = root # logging_client.ls
{flashcard_sets, language_names, language_codes, flashcard_name_aliases} = root # flashcards.ls

export setvar = (varname, varval) ->
  if localStorage?
    localStorage.setItem varname, varval
  $.cookie varname, varval
  return

export getvar = (varname) ->
  if localStorage?
    output = localStorage.getItem varname
    if output?
      return output
  return $.cookie varname

set-flashcard-set = (new_flashcard_set) ->
  new_flashcard_set = first-non-null flashcard_name_aliases[new_flashcard_set.toLowerCase()], new_flashcard_set
  if new_flashcard_set != getvar('lang')
    setvar('lang', new_flashcard_set)
  root.current_flashcard_set = new_flashcard_set
  root.current_language_name = language_names[new_flashcard_set]
  root.current_language_code = language_codes[current_language_name]
  root.vocabulary = flashcard_sets[new_flashcard_set]

select-idx = (list) ->
  return Math.random() * list.length |> Math.floor

select-elem = (list) ->
  return list[select-idx(list)]

select-n-elem = (list, n) ->
  output = []
  seenidx = {}
  while output.length < n
    newidx = select-idx list
    if not seenidx[newidx]?
      seenidx[newidx] = true
      output.push list[newidx]
  return output

select-n-elem-except-elem = (list, elem, n) ->
  output = []
  seenidx = {}
  seenidx[elem.idx] = true
  while output.length < n
    newidx = select-idx list
    if not seenidx[newidx]?
      seenidx[newidx] = true
      output.push list[newidx]
  return output

swap-idx-in-list = (list, idx1, idx2) ->
  tmp = list[idx1]
  list[idx1] = list[idx2]
  list[idx2] = tmp
  return

shuffle-list = (origlist) ->
  list = origlist[to]
  for i in [0 til list.length]
    randidx = select-idx list
    swap-idx-in-list list, i, randidx
  return list

deep-copy = (elem) ->
  return elem |> JSON.stringify |> JSON.parse

root.current-word = null
root.curq-allwords = null
root.curq-langname = null
root.qnum = 0
root.numtries = 0

export new-question = ->
  word = select-elem root.vocabulary |> deep-copy
  word.correct = true
  root.current-word = word
  otherwords = select-n-elem-except-elem root.vocabulary, word, 3 |> deep-copy
  for let elem in otherwords
    elem.correct = false
  allwords = [word] ++ otherwords |> shuffle-list
  langname = ['English', current_language_name ]|> select-elem
  root.curq-allwords = allwords
  root.curq-langname = langname
  addlog {type: 'newquestion', questiontype: root.curq-langname, allwords: root.curq-allwords, word: root.current-word, qnum: root.qnum}
  root.qnum += 1
  root.numtries = 0
  root.showedanswers = false
  refresh-question()

export refresh-question = ->
  $('#showanswersbutton').attr('disabled', false)
  question-with-words root.curq-allwords, root.curq-langname

export play-sound = (word) ->
  #srcurl = 'http://translate.google.com/translate_tts?ie=UTF-8&q=' + word + '&tl=' + root.current_language_code
  $('#speechsynth')[0].pause()
  srcurl = 'https://speechsynth.herokuapp.com/speechsynth?' + $.param({lang: root.current_language_code, word: word})
  $('#speechsynth').attr('src', srcurl)
  #$('audio').attr('src', 'error.mp3')
  #$('#speechsynth').unbind('canplay')
  #$('#speechsynth').bind 'canplay', ->
  #$('#speechsynth')[0].currentTime = 0
  $('#speechsynth')[0].play()

export play-sound-current-word = ->
  play-sound root.current-word.kanji
  #$('audio')[0].pause()
  #$('audio').attr('src', 'error.mp3')
  #$('audio')[0].currentTime = 0
  #$('audio')[0].play()


question-with-words = (allwords, langname) ->
  word-idx = find-index (.correct), allwords
  word = allwords[word-idx]
  if langname == 'English'
    $('#questionmessage').html "What does this word mean" # in #{current_language_name}:
    if root.scriptformat == 'show romanized only' or word.romaji == word.kanji
      $('#questionword').html "<b>#{word.romaji}</b>"
    else
      $('#questionword').html "<b>#{word.romaji} (#{word.kanji})</b>"
    $('#questionwordaudio').show()
  else
    $('#questionmessage').html "How would you say this in #{current_language_name}"
    $('#questionword').html "<b>#{word.english}</b>"
    $('#questionwordaudio').hide()
  $('#answeroptions').html('')
  for let elem,idx in allwords
    outeroptiondiv = J('div').css({
      width: \100%
    })
    optiondivwidth = '100%'
    if langname != 'English'
      optiondivwidth = 'calc(100% - 40px)'
    optiondiv = J('button.btn.btn-default.answeroption#option' + idx).css({
      width: optiondivwidth
      'font-size': \20px
    }).attr('type', 'button')
    worddiv = J('span.answeroptionword#optionword' + idx)
    notediv = J('span.answeroptionnote#optionnote' + idx)
    optiondiv.append [ worddiv, notediv ]
    if langname == 'English'
      worddiv.text(elem.english)
    else if root.scriptformat == 'show romanized only' or word.romaji == word.kanji
      worddiv.text(elem.romaji)
    else
      worddiv.text(elem.romaji + ' (' + elem.kanji + ')')
    outeroptiondiv.append optiondiv
    if langname != 'English'
      outeroptiondiv.append J('div.glyphicon.glyphicon-volume-up').css({
        font-size: \32px
        padding-left: \5px
        margin-top: \-10px
        vertical-align: \middle
        cursor: \pointer
        top: \5px
      }).click ->
        play-sound(elem.kanji)
    $('#answeroptions').append outeroptiondiv
    #if idx == 1
    #  $('#answeroptions').append '<br>'
    $('#option' + idx).data({
      wordinfo: elem
      langname: langname
      idx: idx
    })
    optiondiv.click ->
      if not (!elem.correct and optiondiv.data('showed'))
        addlog {type: 'answered', iscorrect: elem.correct, wordclicked: elem, questiontype: root.curq-langname, wordtested: word, allwords: allwords, qnum: root.qnum, numtries: root.numtries, showedanswers: root.showedanswers}
      if elem.correct
        optiondiv.remove-class 'btn-default'
        optiondiv.add-class 'btn-success'
        show-answer optiondiv
        play-sound-current-word()
        set-timeout ->
          new-question()
        , 1300
      else
        #optiondiv.remove-class 'btn-default'
        #optiondiv.add-class 'btn-danger'
        if not optiondiv.data('showed')
          show-answer optiondiv
          root.numtries += 1

export goto-quiz-page = ->
  $('.mainpage').hide()
  $('#quizpage').show()
  hideoption = getvar('hideoption')
  if hideoption? and hideoption != 'false' and hideoption != false
    $('#optionbutton').hide()
    $('#showanswersbutton').css({margin-right: '0px', width: '100%'})
  if not root.current-word?
    new-question()
  else
    refresh-question()
  return

export goto-option-page = ->
  $('.mainpage').hide()
  $('#optionpage').show()
  $('#langselect').val(root.current_flashcard_set)
  $('#formatselect').val(getvar('format'))
  $('#fullnameinput').val(getvar('fullname'))
  $('#scriptselect').val(getvar('scriptformat'))
  return

export goto-chat-page = ->
  $('.mainpage').hide()
  $('#chatpage').show()
  $('#currentanswer').text root.current-word.romaji + ' = ' + root.current-word.english
  return

export change-lang = ->
  newlang = $('#langselect').val()
  set-flashcard-set newlang
  new-question()
  return

export set-insertion-format = (newformat) ->
  if newformat == 'interactive' or newformat == 'link' or newformat == 'none'
    setvar('format', newformat)
  return

export change-feed-insertion-format = ->
  newformat = $('#formatselect').val()
  set-insertion-format newformat
  return

export set-full-name = (newfullname) ->
  if newfullname? and newfullname.length > 0
    setvar('fullname', newfullname)
    localStorage
  return

export change-full-name = ->
  newfullname = $('#fullnameinput').val()
  set-full-name newfullname
  return

export set-script-format = (scriptformat) ->
  $('#scriptselect').val(scriptformat)
  setvar 'scriptformat', scriptformat
  root.scriptformat = scriptformat
  return

export change-script-format = ->
  scriptformat = $('#scriptselect').val()
  set-script-format scriptformat
  return

show-answer = (optiondiv) ->
  optiondiv.data 'showed', true
  langname = optiondiv.data 'langname'
  elem = optiondiv.data 'wordinfo'
  notediv = optiondiv.find '.answeroptionnote'
  if langname == 'English'
    notediv.html(' = ' + elem.romaji)
  else
    notediv.html(' = ' + elem.english)
  return

root.showedanswers = false

export show-answers = ->
  $('#showanswersbutton').attr('disabled', true)
  for option in $('.answeroption')
    show-answer $(option)
  root.showedanswers = true
  addlog {type: 'showanswers', wordtested: root.current-word, langname: root.curq-langname, allwords: root.curq-allwords, qnum: root.qnum, numtries: root.numtries}
  return

goto-page = (page) ->
  switch page
  | \quiz => goto-quiz-page()
  | \option => goto-option-page()
  | \chat => goto-chat-page()

root.qcontext = null

$(document).ready ->
  param = getUrlParameters()
  set-flashcard-set <| first-non-null param.lang, param.language, param.quiz, param.lesson, param.flashcard, param.flashcardset, getvar('lang'), 'chinese1'
  set-insertion-format <| first-non-null param.format, param.condition, getvar('format'), 'interactive'
  set-full-name <| first-non-null param.fullname, getvar('fullname'), 'Anonymous User'
  set-script-format <| first-non-null param.script, param.scriptformat, getvar('scriptformat'), 'show romanized only'
  if param.facebook? and param.facebook != 'false' and param.facebook != false
    root.qcontext = 'facebook'
    condition = getvar('format')
    addlog {type: 'feedinsert'}
    if condition? and condition == 'link'
      window.location = '/control'
      return
  else
    root.qcontext = 'website'
    addlog {type: 'webvisit'}
  goto-page <| first-non-null param.page, 'quiz'
