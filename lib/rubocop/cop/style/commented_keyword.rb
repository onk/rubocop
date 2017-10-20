# frozen_string_literal: true

module RuboCop
  module Cop
    module Style
      # This cop checks for comments put on the same line as some keywords.
      # These keywords are: `begin`, `class`, `def`, `end`, `module`.
      #
      # Note that some comments (such as `:nodoc:` and `rubocop:disable`) are
      # allowed.
      #
      # @example
      #   # bad
      #   if condition
      #     statement
      #   end # end if
      #
      #   # bad
      #   class X # comment
      #     statement
      #   end
      #
      #   # bad
      #   def x; end # comment
      #
      #   # good
      #   if condition
      #     statement
      #   end
      #
      #   # good
      #   class x # :nodoc:
      #     y
      #   end
      class CommentedKeyword < Cop
        MSG = 'Do not place comments on the same line as the ' \
              '`%s` keyword.'.freeze

        def investigate(processed_source)
          heredoc_lines = extract_heredoc_lines(processed_source.ast)

          processed_source.lines.each_with_index do |line, index|
            next if heredoc_lines.any? { |r| r.include?(index + 1) }
            next unless offensive?(line)

            range = source_range(processed_source.buffer,
                                 index + 1,
                                 (line.index('#'))...(line.length))

            add_offense(range, location: range)
          end
        end

        private

        KEYWORDS = %w[begin class def end module].freeze
        ALLOWED_COMMENTS = %w[:nodoc: rubocop:disable].freeze

        def offensive?(line)
          KEYWORDS.any? { |k| line =~ /^\s*#{k}\s+.*#/ } &&
            ALLOWED_COMMENTS.none? { |c| line =~ /#\s*#{c}/ } &&
            !all_sharp_in_body_string_literal?(line)
        end

        def all_sharp_in_body_string_literal?(line)
          sharp_positions = (0...line.length).select { |i| line[i, 1] == '#' }
          dstr_pos_ranges = parse(line).ast.each_child_node(:dstr).map do |node|
            node.source_range.begin_pos..node.source_range.end_pos
          end
          sharp_positions.all? do |pos|
            dstr_pos_ranges.any? { |range| range.cover?(pos) }
          end
        end

        def message(node)
          line = node.source_line
          keyword = /^\s*(\S+).*#/.match(line)[1]
          format(MSG, keyword)
        end

        def extract_heredoc_lines(ast)
          return [] unless ast
          ast.each_node.with_object([]) do |node, heredocs|
            next unless node.location.is_a?(Parser::Source::Map::Heredoc)
            body = node.location.heredoc_body
            heredocs << (body.first_line...body.last_line)
          end
        end
      end
    end
  end
end
