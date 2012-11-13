-- @author Nils Nordman <nino at nordman.org>
-- @copyright 2012
-- @license MIT (see LICENSE)

import Gtk from lgi
import Window, Editor, theme from lunar.ui
import Buffer, Settings, mode, bundle, keyhandler, keymap, signal from lunar
import File from lunar.fs

class Application

  new: (root_dir, args) =>
    @root_dir = root_dir
    @args = args
    @windows = {}
    @editors = {}
    @buffers = {}

    bundle.dirs = { @root_dir / 'bundles' }

  new_window: (properties) =>
    props =
      title: 'Lunar'
      default_width: 640
      default_height: 480
      on_destroy: (window) ->
        for k, win in ipairs @windows
          if win\to_gobject! == window
            @windows[k] = nil

        Gtk.main_quit! if #@windows == 0

    props[k] = v for k, v in pairs(properties or {})
    window = Window props
    append @windows, window
    window

  new_buffer: (buffer_mode) =>
    buffer_mode or= mode.by_name 'default'
    buffer = Buffer buffer_mode
    append @buffers, buffer
    buffer

  new_editor: (buffer, window = _G.window) =>
    editor = Editor buffer
    window\add_view editor
    append @editors, editor
    editor

  close_buffer: (buffer) =>
    @buffers = [b for b in *@buffers when b != buffer]

    shown_buffers = {}
    for editor in *@editors
      shown_buffers[editor.buffer] = true

    hidden_buffers = [b for b in *@buffers when not shown_buffers[b]]

    if #shown_buffers == 0 and #hidden_buffers == 0
      append hidden_buffers, @new_buffer!

    for editor in *@editors
      if editor.buffer == buffer
        candidate = table.remove hidden_buffers, 1
        if candidate
          append shown_buffers, candidate
        else
          candidate = shown_buffers[1]

        editor.buffer = candidate

    buffer\destroy!


  open_file: (file, editor = _G.editor) =>
    buffer = @new_buffer mode.for_file file
    buffer.file = file
    if editor
      editor.buffer = buffer
    else
      @new_editor buffer

  run: =>
    keyhandler.keymap = keymap
    @settings = Settings!
    @_load_variables!
    @_load_completions!
    @_load_commands!
    bundle.load_all!
    @_set_theme!
    @settings\load_user!

    window = @new_window!
    _G.window = window

    if #@args > 1
      @open_file(File(path)) for path in *@args[2,]
    else
      @new_editor @new_buffer!, window

    @editors[1]\focus!
    window\show_all!
    @_set_initial_status window
    Gtk.main!

  quit: =>
    win\destroy! for win in * moon.copy @windows

  _set_initial_status: (window) =>
    if log.last_error
      window.status\error log.last_error.message
    else
      window.status\info 'Lunar 0.0 ready.'

  _set_theme: =>
    theme.current = 'Tomorrow Night Blue'

  _load_variables: =>
    require 'lunar.variables.core_variables'

  _load_completions: =>
    require 'lunar.completion.samebuffercompleter'

  _load_commands: =>
    require 'lunar.inputs.projectfile_input'
    require 'lunar.inputs.file_input'
    require 'lunar.inputs.buffer_input'
    require 'lunar.inputs.variable_assignment_input'
    require 'lunar.inputs.search_inputs'
    require 'lunar.commands.file_commands'
    require 'lunar.commands.app_commands'
    require 'lunar.commands.ui_commands'
    require 'lunar.commands.search_commands'

return Application
