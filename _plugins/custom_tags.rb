# frozen_string_literal: true

require 'date'

module Jekyll
  # Custom Liquid tag for including code files in _includes/
  # so that the solutions appear only when specified.
  #
  # Inherits from Jekyll's built-in include tag which does the heavy lifting
  # of reading the file:
  # https://github.com/jekyll/jekyll/blob/master/lib/jekyll/tags/include.rb
  #
  # TODO: figure out how to write tests for this
  # TODO: automatically wrap code tags inside a highlight/endhighlight block
  class CodeTag < Jekyll::Tags::IncludeTag
    BEGIN_SOLUTION = 'BEGIN SOLUTION'
    END_SOLUTION = 'END SOLUTION'
    SUPPORTED_LANGUAGES = {
      '.py': '#',
      '.java': '//',
      '.c': '//',
      '.rb': '#',
      '.go': '//',
      '.sql': '--'
    }.freeze

    class CodeTagError < StandardError
    end

    # Expected format of this tag:
    #   {% code file_name.ext show_solution_boolean %}
    #
    #   tag_name is "code"
    #   params   is " file_name.ext show_solution_boolean "
    #
    # Examples:
    # {% code questions/sample_question.py true %}
    # {% code questions/AnotherQuestion.java page.show_solution %}
    #
    # NOTE: the file name must be the path relative to the _includes/ directory
    def initialize(tag_name, params, tokens)
      parse_params(params)
      super(tag_name, @file_name, tokens)
    end

    def get_extension_and_comment_chars(file_name)
      SUPPORTED_LANGUAGES.each do |extension, comment_chars|
        next unless file_name.end_with?(extension.to_s)

        @file_extension = extension
        @comment_chars = comment_chars
        # rubocop:disable Lint/NonLocalExitFromIterator
        return
        # rubocop:enable Lint/NonLocalExitFromIterator
      end

      raise ArgumentError,
            "File extension not supported: #{file_name}. Supported extensions: #{SUPPORTED_LANGUAGES.join(', ')}"
    end

    def parse_params(params)
      file_name, show_solution = params.strip.split

      if file_name.nil?
        raise ArgumentError,
              'Missing first argument to code tag, which must be a file path relative to _includes directory'
      end

      if show_solution.nil?
        raise ArgumentError,
              'Missing second argument to code tag, which must be a boolean \
              representing whether solutions are displayed'
      end

      get_extension_and_comment_chars(file_name)

      @file_name = file_name
      @show_solution = show_solution
    end

    def string_boolean?(value)
      %w[true false].include?(value)
    end

    def boolean?(value)
      [true, false].include?(value)
    end

    def to_boolean(value)
      unless string_boolean?(value)
        raise ArgumentError,
              "value must be 'true' or 'false' not '#{value}' (type #{value.class})"
      end

      value == 'true'
    end

    # Parse the lines read from the file by IncludeTag, removing or keeping solutions.
    # Expect that solutions, if there are any, are within a BEGIN SOLUTION and END SOLUTION
    # block. For example, if @comment_chars is '//', then the solution(s) should be placed within
    # // BEGIN SOLUTION and // END SOLUTION
    def parse_file_lines(raw_lines)
      saw_begin = false
      saw_end = false
      parsed_lines = []
      full_begin_solution = "#{@comment_chars} #{BEGIN_SOLUTION}"
      full_end_solution = "#{@comment_chars} #{END_SOLUTION}"

      raw_lines.each_with_index do |line, index|
        if line.strip == full_begin_solution
          raise CodeTagError, "Duplicate '#{full_begin_solution}' at _includes/#{@file_name}:#{index + 1}" if saw_begin

          saw_begin = true
          saw_end = false
        elsif line.strip == full_end_solution
          unless saw_begin
            raise CodeTagError,
                  "'#{full_end_solution}' without preceding '#{full_begin_solution}' at \
                  _includes/#{@file_name}:#{index + 1}"
          end

          saw_begin = false
          saw_end = true
        elsif !saw_begin || (saw_begin && @show_solution)
          parsed_lines.push(line)
        end
      end

      raise CodeTagError, "'#{full_begin_solution}' without matching '#{full_end_solution}'" if saw_begin && !saw_end

      parsed_lines.join("\n")
    end

    # TODO: render placeholder code like "*** YOUR CODE HERE ***" if @show_solution is false?
    def render(context)
      # If the 2nd argument to the tag is a jekyll variable/front matter
      # (rather than boolean), attempt to retrieve it
      if string_boolean?(@show_solution)
        @show_solution = to_boolean(@show_solution)
      elsif !boolean?(@show_solution)
        jekyll_variable_value = context[@show_solution]

        unless boolean?(jekyll_variable_value)
          raise ArgumentError,
                "Second argument to code tag must be a boolean, not \
                '#{jekyll_variable_value}' (type #{jekyll_variable_value.class})"
        end

        @show_solution = jekyll_variable_value
      end

      raw_lines = super.split("\n")
      parse_file_lines(raw_lines)
    end
  end

  class DiscussionTag < Liquid::Tag
    def initialize(tag_name, number, tokens)
      super
      @number = number.strip
    end

    def render(_context)
      "**H195 DIS**{: .label .label-disc }"
    end
  end

  class HomeworkTag < Liquid::Tag
    def initialize(tag_name, number, tokens)
      super
      @number = number.strip
    end

    def render(_context)
      "**Homework #{@number}**{: .label .label-hw }"
    end
  end

  class LectureTag < Liquid::Tag
    def initialize(tag_name, number, tokens)
      super
      @number = number.strip
    end

    def render(context)
      lectures = context['site']['lectures']
      lecture = lectures[@number.to_i - 1] if lectures[@number.to_i - 1]
      lecture_title = lecture['title']
      date = lecture['date']
      # Directly grab the date string from the lecture data
      date_parts = lecture['date'].to_s.split('-')
      year = date_parts[0].to_i
      month = date_parts[1].to_i
      day = date_parts[2].to_i

      # Construct the date manually
      lecture_date = Date.new(year, month, day)

      current_date = Date.today
      # add leading 0 to number if less than 10
      num_index = @number.to_i < 10 ? "0#{@number}" : @number
      if lecture['released']
        return "**Lecture**{: .label .label-lec } [#{lecture_title}](lectures/#{num_index})"
      end
      return "**Lecture**{: .label .label-lec } #{lecture_title}"
    end
    
  end

  class SurveyTag < Liquid::Tag
    # surveys are numbered by lecture numbers.
    def initialize(tag_name, number, tokens)
      super
      @number = number.strip
    end

    def render(context)
      lectures = context['site']['lectures']
      lecture = lectures[@number.to_i - 1] if lectures[@number.to_i - 1]

      survey = lecture['files']['survey']
      survey_str = ""
      if survey['name']
        if survey['required']
          survey_str += "**Required**{: .label .label-req }"
        end
        if survey['link']
          survey_str += "[#{survey['name']}](#{survey['link']}){: target=\"_blank\"}"
        else
          survey_str += "#{survey['name']}"
        end
      end
      survey_str
    end
    
  end

  class ProjectTag < Liquid::Tag
    def initialize(tag_name, number, tokens)
      super
      @number = number.strip
    end

    def render(_context)
      "**Project #{@number}**{: .label .label-project }"
    end
  end

  class HomeworkDueTag < Liquid::Tag
    def initialize(tag_name, number, tokens)
      super
      @number = number.strip
    end

    def render(_context)
      "**Homework #{@number}**{: .label .label-hw-due }"
    end
  end

  class ProjectDueTag < Liquid::Tag

    def initialize(tag_name, number, tokens)
      super
      @number = number.strip
    end

    def render(context)
      "**Project #{@number}**{: .label .label-proj-due }"
    end
  end

end

Liquid::Template.register_tag('code', Jekyll::CodeTag)
Liquid::Template.register_tag('disc', Jekyll::DiscussionTag)
Liquid::Template.register_tag('hw', Jekyll::HomeworkTag)
Liquid::Template.register_tag('lec', Jekyll::LectureTag)
Liquid::Template.register_tag('survey', Jekyll::SurveyTag)
Liquid::Template.register_tag('proj', Jekyll::ProjectTag)
Liquid::Template.register_tag('hwDue', Jekyll::HomeworkDueTag)
Liquid::Template.register_tag('projDue', Jekyll::ProjectDueTag)
