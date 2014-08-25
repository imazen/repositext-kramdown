class Repositext
  class Validation
    class Validator
      # Depending on @options[:gap_mark_tagging_import_consistency_compare_mode], validates:
      # * 'pre_import':
      #   that the text contents in gap_mark_tagging_import still match those of content_at
      #   Purpose: To make sure that import is based on current content_at.
      # * 'post_import':
      #   that the gap_mark_tagging_import file is identical to a
      #   gap_mark_tagging_export generated from the new content AT (with updated gap_marks)
      #   Purpose: To make sure that the import worked correctly and nothing
      #   was changed inadvertently.
      class GapMarkTaggingImportConsistency < Validator

        class TextMismatchError < ::StandardError; end

        # Runs all validations for self
        def run
          errors, warnings = [], []

          catch(:abandon) do
            # @file_to_validate is an array with the paths to the content_at and
            # gap_mark_tagging_import files
            content_at_filename, gap_mark_tagging_import_filename = @file_to_validate
            outcome = contents_match?(
              ::File.read(content_at_filename),
              ::File.read(gap_mark_tagging_import_filename)
            )

            if outcome.fail?
              errors += outcome.errors
              warnings += outcome.warnings
              #throw :abandon
            end
          end

          log_and_report_validation_step(errors, warnings)
        end

      private

        # Checks if contents match (depending on @options[:gap_mark_tagging_import_consistency_compare_mode])
        # @param[String] content_at
        # @param[String] gap_mark_tagging_import
        # @return[Outcome]
        def contents_match?(content_at, gap_mark_tagging_import)
          # We have to export content_at in both cases to a temporary gap_mark_tagging_export
          # so that we can compare it with the gap_mark_tagging_import

          # Since the kramdown parser is specified as module in Rtfile,
          # I can't use the standard kramdown API:
          # `doc = Kramdown::Document.new(contents, :input => 'kramdown_repositext')`
          # We have to patch a base Kramdown::Document with the root to be able
          # to convert it.
          root, warnings = @options['kramdown_parser_class'].parse(content_at)
          doc = Kramdown::Document.new('')
          doc.root = root

          case @options[:gap_mark_tagging_import_consistency_compare_mode]
          when 'pre_import'
            # We re-export the existing content_at to gap_mark_tagging
            # and compare the result with gap_mark_tagging_import after removing
            # subtitle_marks and gap_marks in both since we expect them to change.
            tmp_gap_mark_tagging_export = doc.send(@options['gap_mark_tagging_converter_method_name'])
            string_1 = tmp_gap_mark_tagging_export.gsub(/[%@]/, '')
            string_2 = gap_mark_tagging_import.gsub(/[%@]/, '')
            error_message = "\n\nText mismatch between gap_mark_tagging_import and content_at in #{ @file_to_validate.last }."
          when 'post_import'
            # We re-export the new content_at to gap_mark_tagging and compare the result
            # with gap_mark_tagging_import. We remove subtitle_marks since they
            # are stripped during gap_mark_tagging export. We leave gap_marks in
            # place since they should be identical if everything works correctly.
            tmp_gap_mark_tagging_export = doc.send(@options['gap_mark_tagging_converter_method_name'])
            string_1 = gap_mark_tagging_import.gsub(/[@]/, '')
            string_2 = tmp_gap_mark_tagging_export.gsub(/[@]/, '')
            error_message = "\n\nText mismatch between gap_mark_tagging_import and gap_mark_tagging_export from content_at in #{ @file_to_validate.last }."
          else
            raise "Invalid compare mode: #{ @options[:gap_mark_tagging_import_consistency_compare_mode].inspect }"
          end

          diffs = Suspension::StringComparer.compare(string_1, string_2)

          if diffs.empty?
            Outcome.new(true, nil)
          else
            # We want to terminate an import if the text is not consistent.
            # Normally we'd return a negative outcome (see below), but in this
            # case we raise an exception.
            # Outcome.new(
            #   false, nil, [],
            #   [
            #     Reportable.error(
            #       [@file_to_validate.last], # gap_mark_tagging_import file
            #       [
            #         'Text mismatch between gap_mark_tagging_import and content_at:',
            #         diffs.inspect
            #       ]
            #     )
            #   ]
            # )
            raise TextMismatchError.new(
              [
                error_message,
                "Cannot proceed with import. Please resolve text differences first:",
                diffs.inspect
              ].join("\n")
            )
          end
        end

      end
    end
  end
end