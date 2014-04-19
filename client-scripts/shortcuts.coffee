(->
  debug = false
  _dbg = -> console.log "Shortcuts DEBUG -", arguments...
  dbg = -> _dbg arguments... if debug
  dbg "Debug-mode is set."

  inputNames = ['TEXTAREA', 'INPUT']

  convertKeyCodeToChar = (code) ->
    code = +code
    if code >= 48 && code <= 90
      String.fromCharCode(code).toUpperCase()
    else if code >= 112 && code <= 123
      "F#{code - 111}"
    else
      switch code
        when 8 then 'Backspace'
        when 9 then 'Tab'
        when 13 then 'Enter'
        when 27 then 'Escape'
        when 37 then 'Left'
        when 38 then 'Up'
        when 39 then 'Right'
        when 40 then 'Down'
        when 45 then 'Insert'
        when 46 then 'Delete'
        when 187 then '='
        when 189 then '-'
        when 190 then '.'
        when 191 then '/'
        when 219 then '['
        when 220 then '\\'
        when 221 then ']'
        else "##{code}"

  class KeyAction
    keyCode: false
    keyString: ''
    action: null
    constructor: (keyName, actionName) ->
      ctrl = false
      alt = false
      shift = false
      meta = false
      this.action = actionName
      parts = keyName.split '-'
      this.keyCode = +parts[parts.length - 1]
      for k,i in parts when i != parts.length - 1
        switch k.toUpperCase()
          when 'C' then this.keyString += "Ctrl"; ctrl = true
          when 'A' then this.keyString += "Alt"; alt = true
          when 'S' then this.keyString += "Shift"; shift = true
          when 'M' then this.keyString += "Meta"; meta = true
          else
        this.keyString += "+"
      this.keyString += convertKeyCodeToChar this.keyCode
      this.matches = (event, key, input) ->
        event.ctrlKey == ctrl && event.altKey == alt && event.shiftKey == shift && event.metaKey == meta &&
          key == this.keyCode && (!input || ctrl || alt || meta || key == 27)

  class Shortcuts
    addAction = (target, actions, keyAction) ->
      target.push keyAction
      actions[keyAction.action]?.bindings?.push keyAction
    parseBindings = (target, actions, cfg, key) ->
      action.bindings = [] for action in actions
      key += '_' if key
      for name, keyName of cfg
        fullName = key + name
        if keyName instanceof Array
          addAction target, actions, new KeyAction(kN, fullName) for kN in keyName
        else if keyName instanceof Object
          parseBindings target, actions, keyName, fullName
        else
          addAction target, actions, new KeyAction(keyName, fullName)
    version: ''
    bindings: []
    actions: {}
    helpMessages: {}
    parseCfg: (cfg) ->
      this.version = cfg.version
      this.helpMessages = cfg.descriptions
      parseBindings this.bindings = [], this.actions, cfg.actions, ''
    passEvent: (e, key) ->
      scopes = getActionScopes()
      dbg "Scopes matching event-target: " + scopes
      # get all key-bindings that match the key-event and are within any searched scope
      matchingBindings = []
      input = inputNames.indexOf(e.target.tagName) >= 0
      for kA in this.bindings
        if kA.matches e, key, input
          for i in [0..scopes.length - 1]
            if kA.action.search(scopes[i]) == 0
              kA.priority = i
              matchingBindings.push kA
              break
      # sort by scope-position
      matchingBindings.sort (kA1, kA2) ->
        kA1.priority - kA2.priority
      delete kA.priority for kA in matchingBindings
      # run key-actions in sorted order and stop if any action returns non-false value
      if debug && matchingBindings.length
        str = '['
        str += "#{kA.action}, " for kA in matchingBindings
        dbg "#{str[..str.length - 3]}] match" + (if matchingBindings.length == 1 then "es" else '') + ' the key-event'
      for kA in matchingBindings
        if this.actions[kA.action]?.cb?.call(e.target, this, e) != false
          dbg "'#{kA.action}' got triggered"
          return;
      dbg 'No action got triggered'
    addActions: (obj) ->
      for k, v of obj
        for name, action of v
          actionName = "#{k}_#{name}"
          this.actions[actionName] =
            cb: action
            bindings: b for b in this.bindings when b.action == actionName
    help: ->
      if document.querySelector '#shortcuts_help_body'
        $('.bootbox-close-button', d).click() for d in getActiveDialogs()
        return;
      height = window.innerHeight - 150
      height = 100 if !height || height < 100
      msg = "<div id='shortcuts_help_body' style='height:#{height}px'><div>"
      for scope, obj of this.helpMessages
        msg += "<h4>#{obj._title}</h4><ul>"
        for name, description of obj when name != '_title'
          keys = (kA.keyString for kA in this.actions["#{scope}_#{name}"]?.bindings)
          if keys
            keys = keys.join ' | '
            msg += "<li class='clearfix'><div class='description'>#{description}</div><div class='keys'>#{keys}</div></li>"
        msg += "</ul>"
      msg += "</ul></div></div>"
      bootbox.dialog
        title: "NodeBB Shortcuts <small>#{this.version}</small>"
        message: msg

  getActiveComposer = ->
    for c in document.querySelectorAll '.composer'
      return c if $(c).css('visibility') == 'visible'
    null

  getActiveDialogs = ->
    dialogs = []
    $('.modal-dialog').each (i, d) -> dialogs.push d if $(d).height()
    dialogs

  # Returns an array of action-prefixes to enable those actions
  getActionScopes = ->
    # dialog, composer, taskbar, breadcrumb, selection, navPills, scroll, header, topic, category
    scopes = []
    return ['dialog', 'body'] if getActiveDialogs().length
    if getActiveComposer()
      scopes.push 'composer'
    else if $('.taskbar li[data-module="composer"]').length
      scopes.push 'composer_closed'
    scopes.push 'taskbar' if $('.taskbar li').length
    scopes.push 'breadcrumb', 'topic', 'category', 'selection', 'navPills', 'header', 'body'
    scopes

  window.shortcuts = new Shortcuts()

  $(document).ready ->
    socket.emit 'modules.shortcutsCfg', null, (err, data) ->
      if err?
        console.error err
        return;
      shortcuts.parseCfg data
      $(document).keydown (event) ->
        event = event || window.event
        key = event.which || event.keyCode || event.key
        _dbg "Key Down: " + (if event.ctrlKey then 'C-' else '') + (if event.altKey then 'A-' else '') +
          (if event.shiftKey then 'S-' else '') + (if event.metaKey then 'M-' else '') + key if debug
        shortcuts.passEvent event, key
      $(document).keypress (event) ->
        event = event || window.event
        return if inputNames.indexOf(event.target.tagName) >= 0
        key = event.which || event.keyCode || event.key
        shortcuts.help() if key == 63
#
)()
