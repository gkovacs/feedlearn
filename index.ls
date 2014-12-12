root = exports ? this

J = $.jade

{find-index} = require \prelude-ls

{first-non-null, getUrlParameters, getvar, setvar, forcehttps, updatecookies} = root # commonlib.ls
{addlog} = root # logging_client.ls
{flashcard_sets, language_names, language_codes, flashcard_name_aliases} = root # flashcards.ls

root.srs_words = null # kanji -> bucket num 1 -> inf, word reviewed with probability proportional to 1 / bucket num

values_over_1 = (dict) ->
  output = {}
  for k,v of dict
    output[k] = 1.0 / v
  return output

normalize_values_to_sum_to_1 = (dict) ->
  output = {}
  current_sum = 0
  for k,v of dict
    current_sum += v
  if current_sum == 0
    return
  for k,v of dict
    output[k] = v / current_sum
  return output

export word_wrong = (kanji) ->
  curbucket = root.srs_words[kanji]
  if not curbucket?
    curbucket = 1
  root.srs_words[kanji] = Math.max(1, curbucket - 1)
  localStorage.setItem ('srs_' + getvar('lang')), JSON.stringify(root.srs_words)
  return

export word_correct = (kanji) ->
  curbucket = root.srs_words[kanji]
  if not curbucket?
    curbucket = 1
  root.srs_words[kanji] = curbucket + 1
  localStorage.setItem ('srs_' + getvar('lang')), JSON.stringify(root.srs_words)
  return

is_srs_correct = (srs_words) ->
  for wordinfo in flashcard_sets[getvar('lang')]
    if not srs_words[wordinfo.kanji]?
      return false
  return true

load-srs-words = ->
  if localStorage?
    stored_srs = localStorage.getItem('srs_' + getvar('lang'))
    if stored_srs?
      try
        root.srs_words = JSON.parse stored_srs
        if is_srs_correct root.srs_words
          console.log 'srs_' + getvar('lang') + ' loaded successfully'
          return
      catch
        root.srs_words = null
  console.log 'rebuildling srs_' + getvar('lang')
  root.srs_words = {}
  for wordinfo in flashcard_sets[getvar('lang')]
    root.srs_words[wordinfo.kanji] = 1
  localStorage.setItem ('srs_' + getvar('lang')), JSON.stringify(root.srs_words)
  return


set-flashcard-set = (new_flashcard_set) ->
  new_flashcard_set = first-non-null flashcard_name_aliases[new_flashcard_set.toLowerCase()], new_flashcard_set
  if new_flashcard_set != getvar('lang')
    setvar('lang', new_flashcard_set)
  root.current_flashcard_set = new_flashcard_set
  root.current_language_name = language_names[new_flashcard_set]
  root.current_language_code = language_codes[current_language_name]
  root.vocabulary = flashcard_sets[new_flashcard_set]
  load-srs-words()

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

get_kanji_probabilities = ->
  return normalize_values_to_sum_to_1 values_over_1(root.srs_words)

export select_kanji_from_srs = ->
  randval = Math.random()
  cursum = 0
  for k,v of get_kanji_probabilities()
    cursum += v
    if cursum >= randval
      return k
  return k

export select_word_from_srs = ->
  kanji = select_kanji_from_srs()
  if not kanji?
    # hrrm seems something is going wrong if we are here
    console.log 'did not find kanji from srs'
    return select-elem root.vocabulary
  for wordinfo in root.vocabulary
    if wordinfo.kanji == kanji
      return wordinfo
  # hrrm seems something is going wrong if we are here
  console.log 'selected kanji was not in vocabulary'
  return select-elem root.vocabulary

export new-question = ->
  #console.log select_kanji_from_srs()
  #word = select-elem root.vocabulary |> deep-copy
  word = select_word_from_srs() |> deep-copy
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
        if root.numtries == 0 and not root.showedanswers
          word_correct(elem.kanji)
        else
          word_wrong(elem.kanji)
      else
        #optiondiv.remove-class 'btn-default'
        #optiondiv.add-class 'btn-danger'
        if not optiondiv.data('showed')
          show-answer optiondiv
          root.numtries += 1

export goto-quiz-page = ->
  $('.mainpage').hide()
  $('#quizpage').show()
  #hideoption = getvar('hideoption')
  #if hideoption? and hideoption != 'false' and hideoption != false
  if true
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
  $('#langselect').val(getvar('lang'))
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

export show-controlpage = ->
  $('#mainviewpage').hide()
  $('#controlviewpage').show()
  lang = getvar('lang')
  langname = language_names[lang]
  if lang? and langname?
    langname = language_names[lang]
    $('#previewdisplay').attr 'src', 'preview-' + langname.toLowerCase() + '.png'
    #$('#previewdisplay').css({
    #  width: \290px
    #  display: \table-cell
    #})
    $('#langdisplay').text langname

export openfeedlearnlink = ->
  addlog {type: 'linkopen', linkopen: 'link'}
  window.open('https://feedlearn.herokuapp.com')

shallow-copy = (dict) ->
  return $.extend {}, dict

exclude-param = (...params) ->
  output = shallow-copy getUrlParameters()
  for param in params
    delete output[param]
  return output

$(document).ready ->
  forcehttps()
  param = getUrlParameters()
  root.fullname = first-non-null param.fullname, param.username, param.user, param.name
  if root.fullname?
    setvar 'fullname', root.fullname
    window.location = '/?' + $.param(exclude-param('fullname', 'username', 'user', 'name'))
    return
  if not getvar('fullname')?
    window.location = '/study1'
    return
  set-flashcard-set <| first-non-null param.lang, param.language, param.quiz, param.lesson, param.flashcard, param.flashcardset, getvar('lang'), 'chinese1'
  set-insertion-format <| first-non-null param.format, param.condition, getvar('format'), 'none'
  #set-full-name <| first-non-null param.fullname, param.username, getvar('fullname'), 'Anonymous User'
  set-script-format <| first-non-null param.script, param.scriptformat, getvar('scriptformat'), 'show romanized only'
  updatecookies()
  if param.facebook? and param.facebook != 'false' and param.facebook != false
    root.qcontext = 'facebook'
    condition = getvar('format')
    addlog {type: 'feedinsert'}
    if condition? and condition == 'link'
      #window.location = '/control'
      show-controlpage()
      return
  else if param.email? and param.email != 'false' and param.email != false
    root.qcontext = 'emailvisit'
    addlog {type: 'emailvisit'}
  else
    root.qcontext = 'website'
    addlog {type: 'webvisit'}
  goto-page <| first-non-null param.page, 'quiz'
