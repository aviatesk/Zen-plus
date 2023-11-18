$ = require 'jquery'
# jquery used only to manipulate editor width
# we'd rather move away from this dependency than expand on it

module.exports =
  config:
    fullscreen:
      type: 'boolean'
      default: true
      order: 1
    hideDocks:
      type: 'boolean'
      default: true
      order: 2
    softWrap:
      description: 'Enables / Disables soft wrapping when Zen-plus is active.'
      type: 'boolean'
      default: atom.config.get 'editor.softWrap'
      order: 3
    gutter:
      description: 'Shows / Hides the gutter when Zen-plus is active.'
      type: 'boolean'
      default: false
      order: 4
    typewriter:
      description: 'Keeps the cursor vertically centered where possible.'
      type: 'boolean'
      default: false
      order: 5
    minimap:
      description: 'Enables / Disables the minimap plugin when Zen-plus is active.'
      type: 'boolean'
      default: false
      order: 6
    width:
      type: 'integer'
      default: atom.config.get 'editor.preferredLineLength'
      order: 7
    tabs:
      description: 'Determines the tab style used while Zen-plus is active.'
      type: 'string'
      default: 'hidden'
      enum: ['hidden', 'single', 'multiple']
      order: 8
    showWordCount:
      description: 'Show the word-count if you have the package installed.'
      type: 'string'
      default: 'Hidden'
      enum: [
        'Hidden',
        'Left',
        'Right'
      ]
      order: 9

  activate: (state) ->
    atom.commands.add 'atom-workspace', 'zen-plus:toggle', => @toggle()

  toggle: ->

    unless (editor = atom.workspace.getActiveTextEditor())
      # Prevent zen-plus mode for undefined editors, e.g. settings
      atom.notifications.addInfo 'Zen-plus cannot be achieved in this view.'
      return

    body = document.querySelector('body')
    editorElm = editor.element

    # should really check current fullsceen state
    fullscreen = atom.config.get 'Zen-plus.fullscreen'
    hideDocks = atom.config.get 'Zen-plus.hideDocks'
    width = atom.config.get 'Zen-plus.width'
    softWrap = atom.config.get 'Zen-plus.softWrap'
    minimap = atom.config.get 'Zen-plus.minimap'

    if body.getAttribute('data-zen-plus') isnt 'true'

      if atom.config.get 'Zen-plus.tabs'
        body.setAttribute 'data-zen-plus-tabs', atom.config.get 'Zen-plus.tabs'

      switch atom.config.get 'Zen-plus.showWordCount'
        when 'Left'
          body.setAttribute 'data-zen-plus-word-count', 'visible'
          body.setAttribute 'data-zen-plus-word-count-position', 'left'
        when 'Right'
          body.setAttribute 'data-zen-plus-word-count', 'visible'
          body.setAttribute 'data-zen-plus-word-count-position', 'right'
        when 'Hidden'
          body.setAttribute 'data-zen-plus-word-count', 'hidden'

      body.setAttribute 'data-zen-plus-gutter', atom.config.get 'Zen-plus.gutter'

      # Enter Mode
      body.setAttribute 'data-zen-plus', 'true'

      # Soft Wrap
      # Use zen-plus soft wrapping setting's to override the default settings
      if editor.isSoftWrapped() isnt softWrap
        editor.setSoftWrapped softWrap
        # restore default when leaving zen-plus mode
        @unSoftWrap = true

      # Set width
      requestAnimationFrame ->
        $('atom-text-editor:not(.mini)').css 'width', editor.getDefaultCharWidth() * width

      # Listen to font-size changes and update the view width
      @fontChanged = atom.config.onDidChange 'editor.fontSize', ->
        requestAnimationFrame ->
          $('atom-text-editor:not(.mini)').css 'width', editor.getDefaultCharWidth() * width

      # Listen for a pane change to update the view width
      @paneChanged = atom.workspace.onDidChangeActivePaneItem ->
        requestAnimationFrame ->
          $('atom-text-editor:not(.mini)').css 'width', editor.getDefaultCharWidth() * width

      if atom.config.get 'Zen-plus.typewriter'
        if not atom.config.get('editor.scrollPastEnd')
          atom.config.set('editor.scrollPastEnd', true)
          @scrollPastEndReset = true
        else
          @scrollPastEndReset = false
        @lineChanged = editor.onDidChangeCursorPosition ->
          halfScreen = Math.floor(editor.getRowsPerPage() / 2)
          cursor = editor.getCursorScreenPosition()
          editorElm.setScrollTop(editor.getLineHeightInPixels() * (cursor.row - halfScreen))

      @typewriterConfig = atom.config.observe 'Zen-plus.typewriter', =>
        if not atom.config.get 'Zen-plus.typewriter'
          if @scrollPastEndReset
            @scrollPastEndReset = false
            atom.config.set 'editor.scrollPastEnd', false
          @lineChanged?.dispose()
        else
          if not atom.config.get 'editor.scrollPastEnd'
            if not @scrollPastEndReset
              atom.config.set 'editor.scrollPastEnd', true
            @scrollPastEndReset = true
          else
            @scrollPastEndReset = false
          @lineChanged?.dispose()
          @lineChanged = editor.onDidChangeCursorPosition ->
            halfScreen = Math.floor(editor.getRowsPerPage() / 2)
            cursor = editor.getCursorScreenPosition()
            editorElm.setScrollTop editor.getLineHeightInPixels() * (cursor.row - halfScreen)

      # Hide docks
      if hideDocks
        if (left = atom.workspace.getLeftDock()) && left.isVisible && left.isVisible() && left.toggle
          left.toggle()
          @restoreLeft = true
        if (bottom = atom.workspace.getBottomDock()) && bottom.isVisible && bottom.isVisible() && bottom.toggle
          bottom.toggle()
          @restoreBottom = true
        if (right = atom.workspace.getRightDock()) && right.isVisible && right.isVisible() && right.toggle
          right.toggle()
          @restoreRight = true

      # Hide Minimap
      if $('atom-text-editor').find('atom-text-editor-minimap') and not minimap
        atom.commands.dispatch(
          atom.views.getView(atom.workspace),
          'minimap:toggle'
        )
        @restoreMinimap = true

      # Enter fullscreen
      atom.setFullScreen true if fullscreen

    else
      # Exit Mode
      body.setAttribute 'data-zen-plus', 'false'

      # Leave fullscreen
      atom.setFullScreen false if fullscreen

      # Restore previous soft wrap setting when leaving zen-plus mode
      if @unSoftWrap and editor isnt undefined
        editor.setSoftWrapped(atom.config.get('editor.softWrap'));
        @unSoftWrap = null

      # Unset the width
      $('atom-text-editor:not(.mini)').css 'width', ''

      # Hack to fix #55 - scrollbars on statusbar after exiting Zen-plus
      $('.status-bar-right').css 'overflow', 'hidden'
      requestAnimationFrame ->
        $('.status-bar-right').css 'overflow', ''

      # Restore docks
      if @restoreLeft && (left = atom.workspace.getLeftDock()) && left.toggle
        left.toggle()
        @restoreLeft = false
      if @restoreBottom && (bottom = atom.workspace.getBottomDock()) && bottom.toggle
        bottom.toggle()
        @restoreBottom = false
      if @restoreRight && (right = atom.workspace.getRightDock()) && right.toggle
        right.toggle()
        @restoreRight = false

      # Restore Minimap
      if @restoreMinimap and $('atom-text-editor').find('atom-text-editor-minimap') is true
        atom.commands.dispatch(
          atom.views.getView(atom.workspace),
          'minimap:toggle'
        )
        @restoreMinimap = false

      # Stop listening for pane or font change
      @fontChanged?.dispose()
      @paneChanged?.dispose()
      @lineChanged?.dispose()
      if @scrollPastEndReset
        atom.config.set('editor.scrollPastEnd', false)
        @scrollPastEndReset = false
      @typewriterConfig?.dispose()
