# -*- coding: utf-8 -*-

require 'kramdown/parser'
require 'nokogiri'

module Kramdown
  module Parser

    class IDMLStory < Base

      class InvalidElementException < RuntimeError; end

      # Create an IDML parser with the given +options+.
      def initialize(source, options)
        super
        @stack = []
        @tree = nil
      end

      def with_stack(kd_el, xml_el)
        @stack.push([kd_el, xml_el])
        @tree = kd_el
        yield
      ensure
        @stack.pop
        @tree = @stack.last.first rescue nil
      end

      def parse #:nodoc:
        xml = Nokogiri::XML(@source) {|cfg| cfg.noblanks }
        xml.xpath('/idPkg:Story/Story').each do |story|
          with_stack(@root, story) { parse_story(story) }
        end
        update_tree
      end

      def parse_story(story)
        story.xpath('ParagraphStyleRange').each do |para|
          parse_para(para)
          # check for last element of CharacterStyleRange equal to <Br /> and therefore for an
          # invalid empty inserted element
          if @tree.children.last.children.length == 0 ||
              (@tree.children.last.children.length == 1 &&
               @tree.children.last.children.first.children.length == 0 &&
               @tree.children.last.children.first.type != :text)
            @tree.children.pop
          end
        end
      end

      def parse_para(para)
        el = add_element_for_ParagraphStyleRange(para)
        with_stack(el, para) { parse_para_children(para.children) }
      end

      def add_element_for_ParagraphStyleRange(para)
        el = case para['AppliedParagraphStyle']
             when "ParagraphStyle/Title of Sermon"
               Element.new(:header, nil, nil, :level => 1, :raw_text => para.text)
             when "ParagraphStyle/Sub-title"
               Element.new(:header, nil, nil, :level => 3, :raw_text => para.text)
             when "ParagraphStyle/Scripture"
               Element.new(:p, nil, {'class' => 'scr'})
             when "ParagraphStyle/Question1", "ParagraphStyle/Question2", "ParagraphStyle/Question3"
               Element.new(:p, nil, {'class' => 'q'})
             when "ParagraphStyle/Song stanza"
               Element.new(:p, nil, {'class' => 'stanza'})
             when "ParagraphStyle/Song"
               Element.new(:p, nil, {'class' => 'song'})
             when "ParagraphStyle/IDTitle1"
               Element.new(:p, nil, {'class' => 'id_title1'})
             when "ParagraphStyle/IDTitle2"
               Element.new(:p, nil, {'class' => 'id_title2'})
             when "ParagraphStyle/IDParagraph"
               Element.new(:p, nil, {'class' => 'id_paragraph'})
             when "ParagraphStyle/Reading"
               Element.new(:p, nil, {'class' => 'reading'})
             when "ParagraphStyle/Normal"
               Element.new(:p, nil, {'class' => 'normal'})
             when "ParagraphStyle/Horizontal rule"
               Element.new(:hr)
             when String
               Element.new(:p, nil, {'class' => normalize_style_name(para['AppliedParagraphStyle'])})
             else
               Element.new(:p)
             end
        @tree.children << el
        el
      end


      def parse_para_children(children)
        children.each do |child|
          case child.name
          when 'CharacterStyleRange'
            parse_char(child)
          when 'Properties'
            # ignore
          else
            raise InvalidElementException, "Found unexpected child element #{child.name} of ParagraphStyleRange"
          end
        end
      end

      def parse_char(char)
        el = add_element_for_CharacterStyleRange(char)
        with_stack(el || @tree, char) { parse_char_children(char.children) }
      end

      HANDLED_CHARACTER_STYLES = ['CharacterStyle/Bold', 'CharacterStyle/Italic',
                                  'CharacterStyle/Bold Italic',
                                  'CharacterStyle/Paragraph number',
                                  'CharacterStyle/Regular']

      def add_element_for_CharacterStyleRange(char)
        el = parent_el = nil
        char_style = :regular

        if char['AppliedCharacterStyle'] == 'CharacterStyle/Bold Italic'
          parent_el = Element.new(:strong)
          el = Element.new(:em)
          parent_el.children << el
          char_style = :bold_italic
        else
          if char['AppliedCharacterStyle'] == 'CharacterStyle/Bold' || char['FontStyle'] == 'Bold'
            el = parent_el = Element.new(:strong)
            char_style = :bold
          end

          if char['AppliedCharacterStyle'] == 'CharacterStyle/Italic' || char['FontStyle'] == 'Italic'
            if parent_el
              el = Element.new(:em)
              parent_el.children << el
            else
              el = parent_el = Element.new(:em)
            end
            char_style = :italic
          end
        end

        add_class = lambda do |css_class|
          parent_el = el = Element.new(:em) if el.nil?
          parent_el.attr['class'] = ((parent_el.attr['class'] || '') << " #{css_class}").lstrip
          parent_el.attr['class'] += case char_style
                                     when :regular then ''
                                     when :italic then ' italic'
                                     when :bold then ' bold'
                                     when :bold_italic then 'bold italic'
                                     end
        end

        add_class.call('underline') if char['Underline'] == 'true'
        add_class.call('smcaps') if char['Capitalization'] == 'SmallCaps'

        if char['FillColor'] == "Color/GAP RED"
          (el.nil? ? @tree : el).children << Element.new(:gap_mark)
        end

        if char['AppliedCharacterStyle'] == 'CharacterStyle/Paragraph number'
          @tree.attr['class'].sub!(/\bnormal\b/, 'normal-pn') if @tree.attr['class'] =~ /\bnormal\b/
          add_class.call('pn')
        end

        if !HANDLED_CHARACTER_STYLES.include?(char['AppliedCharacterStyle'])
          add_class.call(normalize_style_name(char['AppliedCharacterStyle']))
        end

        @tree.children << parent_el if !parent_el.nil?

        el
      end

      def parse_char_children(children)
        children.each do |child|
          case child.name
          when 'Content'
            text_elements = child.content.split("\u2028")
            while text_elements.length > 0
              add_text(text_elements.shift)
              @tree.children << Element.new(:br) if text_elements.length > 0
            end
          when 'Br'
            char_level = @stack.pop
            para_level = @stack.pop
            @tree = @stack.last.first

            para_el = add_element_for_ParagraphStyleRange(para_level.last)
            @stack.push([para_el, para_level.last])
            @tree = para_el

            char_el = add_element_for_CharacterStyleRange(char_level.last)
            @stack.push([char_el || @tree, char_level.last])
            @tree = char_el || @tree
          when 'Properties'
            # ignore this
          else
            raise InvalidElementException, "Found unexpected child element #{child.name} of CharacterStyleRange"
          end
        end
      end

      def normalize_style_name(name)
        name.gsub!(/^ParagraphStyle\/|^CharacterStyle\//, '')
        name.gsub!(/[^A-Za-z0-9_-]/, '-')
        name = "c-#{name}" unless name =~ /^[a-zA-Z]/
        name
      end

      def update_tree
        @stack = [@root]

        iterate_over_children = nil

        ### lambda for managing whitespace
        # index - the place where the whitespace text should be inserted
        # append - true if the whitespace should be appended to existing text
        # → return modified index of element
        add_whitespace = lambda do |el, index, text, append|
          if index == -1
            el.children.insert(0, Element.new(:text, text))
            1
          elsif index == el.children.length
            el.children.insert(index, Element.new(:text, text))
            index - 1
          elsif el.children[index].type == :text
            if append
              el.children[index].value << text
              index + 1
            else
              el.children[index].value.prepend(text)
              index - 1
            end
          else
            el.children.insert(index, Element.new(:text, text))
            index + (append ? 1 : -1)
          end
        end

        ### lambda for joining adjacent :em/:strong elements
        # parent - the parent element
        # index - index of the element that should be joined
        # → return modified index of last processed element
        try_join_elements = lambda do |el|
          index = 0
          while index < el.children.length - 1
            cur_el = el.children[index]
            next_el = el.children[index + 1]
            next_next_el = el.children[index + 2]
            if cur_el.type == next_el.type && cur_el.attr == next_el.attr && cur_el.options == next_el.options
              if cur_el.type == :text
                cur_el.value += next_el.value
              else
                cur_el.children.concat(next_el.children)
              end
              el.children.delete_at(index + 1)
            elsif next_next_el && [:em, :strong].include?(next_next_el.type) &&
                next_el.type == :text && next_el.value.strip.empty? &&
                next_next_el.type == cur_el.type && next_next_el.attr == cur_el.attr &&
                next_next_el.options == cur_el.options
              cur_el.children.push(next_el)
              cur_el.children.concat(next_next_el.children)
              el.children.delete_at(index + 1)
              el.children.delete_at(index + 2)
            else
              index += 1
            end
          end
        end

        ### postfix iteration
        # - ensures that whitespace from inner elements is pushed outside first
        process_child = lambda do |el, index|
          iterate_over_children.call(el)

          if el.type == :hr
            el.children.clear
          elsif el.type == :p && (el.attr['class'] =~ /\bnormal\b/ || el.attr['class'] =~ /\bq\b/) &&
              el.children.first.type == :text
            # remove leading tab from 'normal' and 'q' paragraphs
            el.children.first.value.sub!(/\A\t/, '')
          elsif (el.type == :em || el.type == :strong) && el.children.length == 0
            # check if element is empty and can be completely deleted
            @stack.last.children.delete_at(index)
            index -= 1
          elsif (el.type == :em || el.type == :strong)
            # manage whitespace
            if el.children.first.type == :text && el.children.first.value =~ /\A[[:space:]]+/
              index = add_whitespace.call(@stack.last, index - 1, Regexp.last_match(0), true)
              el.children.first.value.lstrip!
            end
            if el.children.last.type == :text && el.children.last.value =~ /[[:space:]]+\Z/
              index = add_whitespace.call(@stack.last, index + 1, Regexp.last_match(0), false)
              el.children.last.value.rstrip!
            end
          end
          index
        end

        iterate_over_children = lambda do |el|
          # join neighbour elements of same type
          try_join_elements.call(el) if el.children.first && ::Kramdown::Element.category(el.children.first) == :span

          @stack.push(el)
          index = 0
          while index < el.children.length
            index = process_child.call(el.children[index], index)
            index += 1
          end
          @stack.pop
        end

        iterate_over_children.call(@root)
      end

    end

  end
end