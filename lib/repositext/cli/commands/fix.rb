class Repositext
  class Cli
    module Fix

    private

      # Move gap_marks (%) to the outside of
      # * asterisks
      # * quotes (primary or secondary)
      # * parentheses
      # * brackets
      # Those characters may be nested, move % all the way out if those characters
      # are directly adjacent.
      # If % directly follows an elipsis, move to the front of the ellipsis
      # (unless where elipsis and % are between two words like so: word…%word)
      def fix_adjust_gap_mark_positions(options)
        Repositext::Cli::Utils.change_files_in_place(
          config.compute_glob_pattern(
            options['base-dir'] || :idml_import_dir,
            options['file-selector'] || :all_files,
            options['file-extension'] || :at_extension
          ),
          options['file_filter'],
          "Adjusting :gap_mark positions",
          options
        ) do |contents, filename|
          outcome = Repositext::Fix::AdjustGapMarkPositions.fix(contents, filename)
          [outcome]
        end
      end

      # When merging AT imported from Folio XML with AT imported from IDML,
      # the :record_marks sometimes end up in the middle of a paragraph.
      # This happens when Folio and IDML have textual differences.
      # This script moves any :record_marks that are in an invalid position
      # to before the next paragraph so that they are guaranteed to be between
      # paragraphs, and that they are preceded by a blank line.
      # @param [Hash] options
      def fix_adjust_merged_record_mark_positions(options)
        Repositext::Cli::Utils.change_files_in_place(
          config.compute_glob_pattern(
            options['base-dir'] || :staging_dir,
            options['file-selector'] || :all_files,
            options['file-extension'] || :at_extension
          ),
          options['file_filter'],
          "Adjusting merged :record_mark positions",
          options
        ) do |contents, filename|
          outcome = Repositext::Fix::AdjustMergedRecordMarkPositions.fix(contents, filename)
          [outcome]
        end
      end

      # Converts A.M., P.M., A.D. and B.C. to lower case and wraps them in span.smcaps
      def fix_convert_abbreviations_to_lower_case(options)
        Repositext::Cli::Utils.change_files_in_place(
          config.compute_glob_pattern(
            options['base-dir'] || :staging_dir,
            options['file-selector'] || :all_files,
            options['file-extension'] || :at_extension
          ),
          options['file_filter'],
          "Converting abbreviations to lower case",
          options
        ) do |contents, filename|
          outcome = Repositext::Fix::ConvertAbbreviationsToLowerCase.fix(contents, filename)
          [outcome]
        end
      end

      # Convert -- and ... and " to typographically correct characters
      def fix_convert_folio_typographical_chars(options)
        Repositext::Cli::Utils.change_files_in_place(
          config.compute_glob_pattern(
            options['base-dir'] || :folio_import_dir,
            options['file-selector'] || :all_files,
            options['file-extension'] || :at_extension
          ),
          options['file_filter'],
          "Changing typographical characters in files",
          options
        ) do |contents, filename|
          outcome = Repositext::Fix::ConvertFolioTypographicalChars.fix(contents, filename)
          [outcome]
        end
      end

      # Set file permissions to standard permissions on all newly imported files
      def fix_import_file_permissions
        # set to 644
      end

      def fix_normalize_editors_notes(options)
        Repositext::Cli::Utils.change_files_in_place(
          # Don't set default file_spec since this gets called both in folio
          # and idml.
          config.compute_glob_pattern(
            options['base-dir'],
            options['file-selector'] || :all_files,
            options['file-extension'] || :at_extension
          ),
          options['file_filter'],
          "Normalizing editors notes",
          options
        ) do |contents, filename|
          outcome = Repositext::Fix::NormalizeEditorsNotes.fix(contents, filename)
          [outcome]
        end
      end

      def fix_normalize_subtitle_mark_before_gap_mark_positions(options)
        Repositext::Cli::Utils.change_files_in_place(
          # Don't set default file_spec. Needs to be provided. This could be called
          # from a number of places.
          config.compute_glob_pattern(
            options['base-dir'],
            options['file-selector'] || :all_files,
            options['file-extension'] || :at_extension
          ),
          options['file_filter'],
          "Normalizing subtitle_mark before gap_mark positions.",
          options
        ) do |contents, filename|
          outcome = Repositext::Fix::NormalizeSubtitleMarkBeforeGapMarkPositions.fix(contents, filename)
          [outcome]
        end
      end

      # Normalizes all text files to a single newline
      def fix_normalize_trailing_newlines(options)
        # This would use the input option, however that may not work since
        # we touch lots of directories as part of an import.
        # Repositext::Cli::Utils.change_files_in_place(
        #   config.compute_glob_pattern(
        #     options['base-dir'] || :content_type_dir,
        #     options['file-selector'] || :all_files,
        #     options['file-extension'] || :repositext_extensions
        #   ),
        #   /.\z/i,
        #   "Normalizing trailing newlines",
        #   options
        # ) do |contents, filename|
        #   [Outcome.new(true, { contents: contents.gsub(/(?<!\n)\n*\z/, "\n") }, [])]
        # end

        which_files = :all # :content_at_only or :all
        case which_files
        when :content_at_only
          input_base_dirs = %w[content_dir]
          input_file_extension_name = options['file-extension'] || :at_extension
        when :all
          # Process all subfolders of root. Don't touch files in root.
          input_base_dirs = %w[
            content_dir
            docx_import_dir
            folio_import_dir
            idml_import_dir
            plain_kramdown_export_dir
            reports_dir
            subtitle_export_dir
            subtitle_import_dir
            subtitle_tagging_export_dir
            subtitle_tagging_import_dir
          ]
          input_file_extension_name = options['file-extension'] || :repositext_extensions
        else
          raise "Invalid which_files: #{ which_files.inspect }"
        end
        input_file_selector = config.compute_file_selector(options['file-selector'] || :all_files)
        # TODO: parallelize this since it's a cartesian product of 9 directories and possibly
        # hundreds of entries in --file-selector
        input_base_dirs.each do |input_base_dir_name|
          input_base_dir = config.compute_base_dir(input_base_dir_name)
          input_file_extension = config.compute_file_extension(input_file_extension_name)
          input_file_glob_pattern = [input_base_dir, input_file_selector, input_file_extension].join
          Repositext::Cli::Utils.change_files_in_place(
            input_file_glob_pattern,
            options['file_filter'],
            "Normalizing trailing newlines",
            options
          ) do |contents, filename|
            [Outcome.new(true, { contents: contents.gsub(/(?<!\n)\n*\z/, "\n") }, [])]
          end
        end
      end

      def fix_remove_underscores_inside_folio_paragraph_numbers(options)
        Repositext::Cli::Utils.change_files_in_place(
          config.compute_glob_pattern(
            options['base-dir'] || :folio_import_dir,
            options['file-selector'] || :all_files,
            options['file-extension'] || :at_extension
          ),
          options['file_filter'],
          "Removing underscores inside folio paragraph numbers",
          options
        ) do |contents, filename|
          outcome = Repositext::Fix::RemoveUnderscoresInsideFolioParagraphNumbers.fix(contents, filename)
          [outcome]
        end
      end

      # Renumbers all paragraphs that contain a `*...*{: .pn}` span.
      def fix_renumber_paragraphs(options)
        Repositext::Cli::Utils.change_files_in_place(
          config.compute_glob_pattern(
            options['base-dir'] || :content_dir,
            options['file-selector'] || :all_files,
            options['file-extension'] || :at_extension
          ),
          options['file_filter'],
          "Renumbering paragraphs",
          options.merge(
            use_new_repositext_file_api: true,
            content_type: content_type,
          )
        ) do |content_at_file|
          outcome = Repositext::Process::Fix::RenumberParagraphs.fix(
            content_at_file.contents
          )
          [outcome]
        end
      end

      # Replaces invalid unicode locations according to unicode_replacement_mappings
      def fix_replace_invalid_unicode_locations(options)
        Repositext::Cli::Utils.change_files_in_place(
          config.compute_glob_pattern(
            options['base-dir'] || :content_dir,
            options['file-selector'] || :all_files,
            options['file-extension'] || :at_extension
          ),
          options['file_filter'],
          "Replacing invalid unicode locations",
          options.merge(
            use_new_repositext_file_api: true,
            content_type: content_type,
          )
        ) do |content_at_file|
          outcome = Repositext::Process::Fix::ReplaceInvalidUnicodeLocations.fix(
            content_at_file.contents
          )
          [outcome]
        end
      end

      def fix_test(options)
        # dummy method for testing
        puts 'fix_test'
      end

    end
  end
end
