#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = ProjectFileScanner.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'TextScanner'

class TaskJuggler

  # This class specializes the TextScanner class to detect the tokens of the
  # TJP syntax.
  class ProjectFileScanner < TextScanner

    def initialize(masterFile, messageHandler)
      super

      tokenPatterns = [
        # Any white spaces
        [ nil, /\s+/, :tjp, method('newPos') ],
        # Single line comments starting with #
        [ nil, /#.*\n?/, :tjp, method('newPos') ],
        # C++ style single line comments starting with //
        [ nil, /\/\/.*\n?/, :tjp, method('newPos') ],
        # C style single line comment /* .. */.
        [ nil, /\/\*.*\*\//, :tjp, method('newPos') ],
        # C style multi line comment
        [ nil, /\/\*([^*]*[^\/]|.*)\n/, :tjp, method('startComment') ],
        [ nil, /.*\*\//, :cppComment, method('endComment') ],
        [ nil, /^.*\n/, :cppComment ],
        #[ nil, /\*[^\/]/, :comment, newPos ],
        [ 'TIME', /\d{1,2}:\d{2}/, :tjp, method('to_time') ],
        [ 'DATE', /\d{4}-\d{1,2}-\d{1,2}(-\d{1,2}:\d{1,2}(:\d{1,2})?(-[-+]?\d{4})?)?/, :tjp, method('to_date') ],
        [ 'FLOAT', /\d*\.\d+/, :tjp, method('to_f') ],
        [ 'INTEGER', /\d+/, :tjp, method('to_i') ],
        # Multi line string enclosed with double quotes.
        [ 'nil', /"(\\"|[^"])*/, :tjp, method('startStringDQ') ],
        [ 'nil', /^(\\"|[^"])*\n/, :dqString, method('midStringDQ') ],
        [ 'STRING', /(\\"|[^"])*"/, :dqString, method('endStringDQ') ],
        # Multi line string enclosed with single quotes.
        [ 'nil', /'(\\'|[^'])*/, :tjp, method('startStringSQ') ],
        [ 'nil', /^(\\'|[^'])*\n/, :sqString, method('midStringSQ') ],
        [ 'STRING', /(\\'|[^'])*'/, :sqString, method('endStringSQ') ],
        # Scizzors marked string -8<- ... ->8-
        [ 'nil', /-8<-.*\n/, :tjp, method('startStringSZR') ],
        [ 'STRING', /\s*->8-/, :szrString1, method('endStringSZR') ],
        [ 'STRING', /\s*->8-/, :szrString, method('endStringSZR') ],
        [ 'nil', /.*\n/, :szrString1, method('firstStringSZR') ],
        [ 'nil', /.*\n/, :szrString, method('midStringSZR') ],
        # An ID with a colon suffix: foo:
        [ 'ID_WITH_COLON', /[a-zA-Z_]\w*:/, :tjp, method('chop') ],
        # An absolute ID: a.b.c
        [ 'ABSOLUTE_ID', /[a-zA-Z_]\w*(\.[a-zA-Z_]\w*)+/ ],
        # A normal ID: bar
        [ 'ID', /[a-zA-Z_]\w*/ ],
        # Single line macro definition
        [ 'MACRO', /\[.*\]\n/, :tjp, method('chop2nl') ],
        # Multi line macro definition
        [ nil, /\[.*\n/, :tjp, method('startMacroDef') ],
        [ 'MACRO', /.*\]\n/, :macroDef, method('endMacroDef') ],
        [ nil, /.*\n/, :macroDef, method('midMacroDef') ],
        # Macro Call
        [ nil, /\$\{\s*([a-zA-Z_]\w*)(\s*"(\\"|[^"])*")*/, :tjp, method('startMacroCall') ],
        [ nil, /(\s*"(\\"|[^"])*")*\s*\}/, :macroCall, method('endMacroCall') ],
        [ nil, /.*\n/, :macroCall, method('midMacroCall') ],
        # Some multi-char literals.
        [ 'LITERAL', /<=?/ ],
        [ 'LITERAL', />=?/ ],
        [ 'LITERAL', /!=?/ ],
        # Everything else is returned as a single-char literal.
        [ 'LITERAL', /./ ]
      ]

      tokenPatterns.each do |pat|
        type = pat[0]
        regExp = pat[1]
        mode = pat[2] || :tjp
        postProc = pat[3]
        addPattern(type, regExp, mode, postProc)
      end
      self.mode = :tjp
    end

    private

    def tjpMode(type, match)
      self.mode = :tjp
      [ type, match ]
    end

    def commentMode(type, match)
      self.mode = :comment
      [ type, match ]
    end

    def to_i(type, match)
      [ type, match.to_i ]
    end

    def to_f(type, match)
      [ type, match.to_f ]
    end

    def to_time(type, match)
      h, m, s = match.split(':')
      h = h.to_i
      m = m.to_i
      s = 0 if s.nil?
      [ type, h * 3600 + m * 60 + s ]
    end

    def to_date(type, match)
      [ type, TjTime.new(match) ]
    end

    def newPos(type, match)
      @startOfToken = sourceFileInfo
      [ nil, '' ]
    end

    def chop(type, match)
      [ type, match[0..-2] ]
    end

    def chop2(type, match)
      # Remove first and last character.
      [ type, match[1..-2] ]
    end

    def chop2nl(type, match)
      # remove first and last 2 characters.
      [ type, match[1..-3] ]
    end

    def cleanStringDQ(type, match)
      [ type, match[1..-2].gsub(/\\"/, '"') ]
    end

    def cleanStringSQ(type, match)
      [ type, match[1..-2].gsub(/\\'/, "'") ]
    end

    def startComment(type, match)
      self.mode = :cppComment
      [ nil, '' ]
    end

    def endComment(type, match)
      self.mode = :tjp
      [ nil, '' ]
    end

    def startStringDQ(type, match)
      self.mode = :dqString
      @string = match[1..-1].gsub(/\\"/, '"')
      [ nil, '' ]
    end

    def midStringDQ(type, match)
      @string += match.gsub(/\\"/, '"')
      [ nil, '' ]
    end

    def endStringDQ(type, match)
      self.mode = :tjp
      @string += match[0..-2].gsub(/\\"/, '"')
      [ 'STRING', @string ]
    end

    def startStringSQ(type, match)
      self.mode = :sqString
      @string = match[1..-1].gsub(/\\'/, "'")
      [ nil, '' ]
    end

    def midStringSQ(type, match)
      @string += match.gsub(/\\'/, "'")
      [ nil, '' ]
    end

    def endStringSQ(type, match)
      self.mode = :tjp
      @string += match[0..-2].gsub(/\\'/, "'")
      [ 'STRING', @string ]
    end

    def startStringSZR(type, match)
      # There should be a line break after the cut mark, but we allow some
      # spaces between the mark and the line break as well.
      if match.length != 5 && /-8<-\s*\n$/.match(match).nil?
        @lineDelta = 1
        error('junk_after_cut',
              'The cut mark -8<- must be immediately followed by a ' +
              'line break.')
      end
      self.mode = :szrString1
      @startOfToken = sourceFileInfo
      @string = ''
      [ nil, '' ]
    end

    def firstStringSZR(type, match)
      self.mode = :szrString
      foo, @indent, @string = */(\s*)(.*\n)/.match(match)
      [ nil, '' ]
    end

    def midStringSZR(type, match)
      # Ignore all the characters from the begining of match that are the same
      # in @indent.
      i = 0
      @indent.each_utf8_char do |ic|
        if match[i] == ic
          i += 1
        else
          break
        end
      end
      @string += match[i..-1]
      [ nil, '' ]
    end

    def endStringSZR(type, match)
      self.mode = :tjp
      [ 'STRING', @string ]
    end

    def startMacroDef(type, match)
      self.mode = :macroDef
      # Remove the opening '['
      @macroDef = match[1..-1]
      [ nil, '' ]
    end

    def midMacroDef(type, match)
      @macroDef += match
      [ nil, '' ]
    end

    def endMacroDef(type, match)
      self.mode = :tjp
      # Remove "]\n"
      @macroDef += match[0..-3]
      [ 'MACRO', @macroDef ]
    end

    def startMacroCall(type, match)
      self.mode = :macroCall
      @macroCall = match
      [ nil, '' ]
    end

    def midMacroCall(type, match)
      @macroCall += match
      [ nil, '' ]
    end

    def endMacroCall(type, match)
      self.mode = :tjp
      @macroCall += match
      # Remove '${' and '}'
      argsStr = @macroCall[2..-2]
      # Extract the macro name.
      if (nameEnd = argsStr.index(' ')).nil?
        expandMacro([ argsStr ])
      else
        macroName = argsStr[0, argsStr.index(' ')]
        # Remove the name part from argsStr
        argsStr = argsStr[macroName.length..-1]
        # Array to hold the arguments
        args = []
        # We use another StringScanner to clean the double quotes.
        scanner = StringScanner.new(argsStr)
        while (scanner.scan(/\s*"/))
          args << scanner.scan(/(\\"|[^"])*/).gsub(/\\"/, '"')
          scanner.scan(/"\s*/)
        end

        unless scanner.eos?
          raise "Junk found at end of macro: #{argsStr[scanner.pos..-1]}"
        end

        # Expand the macro and inject it into the scanner.
        expandMacro([ macroName ] + args)
      end

      [ nil, '' ]
    end

  end

end

