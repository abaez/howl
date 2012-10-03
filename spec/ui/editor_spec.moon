import Gtk from lgi

import Buffer, config from lunar
import Window, Editor from lunar.ui

import Spy from lunar.spec

describe 'Editor', ->
  buffer = nil
  editor = Editor Buffer {}
  cursor = editor.cursor
  window = Gtk.OffscreenWindow!
  window\add editor\to_gobject!
  window\show_all!

  before ->
    buffer = Buffer {}
    editor.buffer = buffer

  it '.current_line is a shortcut for the current buffer line', ->
    buffer.text = 'hello\nworld'
    cursor.pos = 2
    assert_equal editor.current_line, buffer.lines[1]

  it '.newline() adds a newline at the current position', ->
    buffer.text = 'hello'
    cursor.pos = 2
    editor\newline!
    assert_equal buffer.text, 'h\nello'

  describe '.newline_and_indent()', ->
    context "when the buffer's mode provides an .indent_after", ->
      it 'adds a new line and indents it by the amount returned by indent_after', ->
        indent_after = -> 6
        buffer.mode = :indent_after
        buffer.text = 'line'
        cursor.pos = 5
        editor\newline_and_indent!
        assert_equal buffer.text, 'line\n' .. string.rep(' ', 6)

    context "when the mode.indent_after is missing or returns nil", ->
      it 'uses the indentation of the current line', ->
        buffer.text = '  line'
        cursor.pos = 7
        editor\newline_and_indent!
        assert_equal buffer.text, '  line\n  '

        buffer.mode = indent_after: -> nil
        buffer.text = '  line'
        cursor.pos = 7
        editor\newline_and_indent!
        assert_equal buffer.text, '  line\n  '

    it 'does the whole shebang as a one undo', ->
      buffer.text = '  line'
      cursor.pos = 7
      editor\newline_and_indent!
      editor.buffer\undo!
      assert_equal buffer.text, '  line'

    it 'positions the cursor at the end of the indentation', ->
      buffer.text = '  line'
      cursor.pos = 7
      editor\newline_and_indent!
      assert_equal editor.cursor.line, 2
      assert_equal editor.cursor.column, 3

    it 'passes (mode, line-up-to-break, editor) to indent_after', ->
      indent_after = Spy with_return: 2
      buffer.mode = :indent_after
      buffer.text = 'line'
      cursor.pos = 3
      editor\newline_and_indent!
      called_with = indent_after.called_with
      assert_equal called_with[1], buffer.mode
      assert_equal called_with[2], 'li'
      assert_equal called_with[3], editor

    it 'indent_after return values "->" and "<-" means indent and unindent, relatively', ->
      config.set 'indent', 2, buffer
      buffer.text = 'line'
      cursor.pos = 5

      buffer.mode = indent_after: -> '->'
      editor\newline_and_indent!
      assert_equal buffer.text, 'line\n  '

      buffer.mode = indent_after: -> '<-'
      editor\newline_and_indent!
      assert_equal buffer.text, 'line\n  \n'

  it 'insert(text) inserts the text at the cursor, and moves cursor after text', ->
    buffer.text = 'hello'
    cursor.pos = 6
    editor\insert ' world'
    assert_equal buffer.text, 'hello world'
    assert_equal cursor.pos, 12

  it 'paste pastes the contents of the clipboard at the current position', ->
    buffer.text = 'hello'
    editor.selection\set 1, 2
    editor.selection\copy!
    editor\paste!
    assert_equal buffer.text, 'hhello'

  it 'delete_line deletes the current line', ->
    buffer.text = 'hello\nworld!'
    cursor.pos = 1
    editor\delete_line!
    assert_equal buffer.text, 'world!'

  it 'copy_line copies the current line', ->
    buffer.text = 'hello\n'
    cursor.pos = 1
    editor\copy_line!
    editor\paste!
    assert_equal buffer.text, 'hello\nhello\n'

  it 'delete_to_end_of_line deletes text from cursor up to end of line', ->
    buffer.text = 'hello world!'
    cursor.pos = 6
    editor\delete_to_end_of_line!
    assert_equal buffer.text, 'hello'

  it 'join_lines joins the current line with the one after', ->
    buffer.text = 'hello\n    world!'
    cursor.pos = 1
    editor\join_lines!
    assert_equal buffer.text, 'hello world!'
    assert_equal cursor.pos, 6

  context 'indentation, tabs, spaces and backspace', ->

    it 'defines a "tab_width" config variable, defaulting to 2', ->
      assert_equal config.tab_width, 2

    it 'defines a "use_tabs" config variable, defaulting to false', ->
      assert_equal config.use_tabs, false

    it 'defines a "indent" config variable, defaulting to 2', ->
      assert_equal config.indent, 2

    it 'defines a "tab_indents" config variable, defaulting to true', ->
      assert_equal config.tab_indents, true

    it 'defines a "backspace_unindents" config variable, defaulting to true', ->
      assert_equal config.backspace_unindents, true

    describe '.tab()', ->
      it 'inserts a tab character if use_tabs is true', ->
        config.use_tabs = true
        buffer.text = 'hello'
        cursor.pos = 2
        editor\tab!
        assert_equal buffer.text, 'h\tello'

      it 'inserts spaces to move to the next tab if use_tabs is false', ->
        config.use_tabs = false
        buffer.text = 'hello'
        cursor.pos = 1
        editor\tab!
        assert_equal buffer.text, string.rep(' ', config.tab_width) .. 'hello'

      it 'inserts a tab move to the next tab if use_tabs is true', ->
        config.use_tabs = true
        buffer.text = 'hello'
        cursor.pos = 1
        editor\tab!
        assert_equal buffer.text, '\thello'

      it 'indents the current line if in whitespace and tab_indents is true', ->
        config.use_tabs = false
        config.tab_indents = true
        indent = string.rep ' ', config.indent
        buffer.text = indent .. 'hello'
        cursor.pos = 2
        editor\tab!
        assert_equal buffer.text, string.rep(indent, 2) .. 'hello'

    describe '.backspace()', ->
      it 'deletes back by one character', ->
        buffer.text = 'hello'
        cursor.pos = 2
        editor\backspace!
        assert_equal buffer.text, 'ello'

      it 'unindents if in whitespace and backspace_unindents is true', ->
        config.indent = 2
        buffer.text = '  hello'
        cursor.pos = 3
        config.backspace_unindents = true
        editor\backspace!
        assert_equal buffer.text, 'hello'

      it 'deletes back if in whitespace and backspace_unindents is false', ->
        config.indent = 2
        buffer.text = '  hello'
        cursor.pos = 3
        config.backspace_unindents = false
        editor\backspace!
        assert_equal buffer.text, ' hello'

    describe '.indent()', ->
      it 'indents the lines included in a selection if any', ->
        config.indent = 2
        buffer.text = 'hello\nselected\nworld!'
        editor.selection\set 2, 10
        editor\indent!
        assert_equal buffer.text, '  hello\n  selected\nworld!'

      it 'indents the current line when nothing is selected, remembering column', ->
        config.indent = 2
        buffer.text = 'hello\nworld!'
        cursor.pos = 3
        editor\indent!
        assert_equal buffer.text, '  hello\nworld!'
        assert_equal cursor.pos, 5

    describe '.unindent()', ->
      it 'unindents the lines included in a selection if any', ->
        config.indent = 2
        buffer.text = '  hello\n  selected\nworld!'
        editor.selection\set 4, 12
        editor\unindent!
        assert_equal buffer.text, 'hello\nselected\nworld!'

      it 'unindents the current line when nothing is selected, remembering column', ->
        config.indent = 2
        buffer.text = '    hello\nworld!'
        cursor.pos = 4
        editor\unindent!
        assert_equal buffer.text, '  hello\nworld!'
        assert_equal cursor.pos, 2
