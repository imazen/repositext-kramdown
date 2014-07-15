class Repositext
  class Cli
    module Import

    private

      # Import from all sources and merge into /content
      def import_all(options)
        import_docx_specific_steps(options)
        import_folio_xml_specific_steps(options)
        import_idml_specific_steps(options)
        import_shared_steps(options)
      end

      # Import DOCX and merge into /content
      def import_docx(options)
        import_docx_specific_steps(options)
        import_shared_steps(options)
      end

      # Import FOLIO XML and merge into /content
      def import_folio_xml(options)
        import_folio_xml_specific_steps(options)
        import_shared_steps(options)
      end

      # Import IDML and merge into /content
      def import_idml(options)
        import_idml_specific_steps(options)
        import_shared_steps(options)
      end

      def import_subtitle(options)
        options['report_file'] = config.compute_glob_pattern(
          'subtitle_import_dir/validation_report_file'
        )
        options['append_to_validation_report'] = false
        reset_validation_report(options, 'validate_subtitle_import')
        validate_subtitle_import(options.merge('run_options' => %w[pre_import]))
        merge_subtitle_marks_from_subtitle_import_into_content_at(options)
        fix_normalize_subtitle_mark_before_gap_mark_positions(
          options.merge({ 'input' => 'content_dir/at_files' })
        )
        copy_subtitle_marker_csv_files_to_content(options) # and rename them to our file naming convention
        options['append_to_validation_report'] = true
        validate_subtitle_import(options.merge('run_options' => %w[post_import]))
      end

      def import_subtitle_tagging(options)
        options['report_file'] = config.compute_glob_pattern(
          'subtitle_tagging_import_dir/validation_report_file'
        )
        options['append_to_validation_report'] = false
        reset_validation_report(options, 'validate_subtitle_tagging_import')
        validate_subtitle_tagging_import(options.merge('run_options' => %w[pre_import]))
        merge_subtitle_marks_from_subtitle_tagging_import_into_content_at(options)
        fix_normalize_subtitle_mark_before_gap_mark_positions(
          options.merge({ 'input' => 'content_dir/at_files' })
        )
        copy_subtitle_marker_csv_files_to_content(options) # and rename them to our file naming convention
        options['append_to_validation_report'] = true
        validate_subtitle_tagging_import(options.merge('run_options' => %w[post_import]))
      end

      def import_test(options)
        # dummy method for testing
        puts 'import_test'
      end

      # -----------------------------------------------------
      # Helper methods for DRY process specs
      # -----------------------------------------------------

      def import_docx_specific_steps(options)
        # convert_docx_to_???(options)
        # validate_utf8_encoding(options.merge(input: 'import_docx_dir/repositext_files'))
      end

      def import_folio_xml_specific_steps(options)
        options['report_file'] = config.compute_glob_pattern(
          'folio_import_dir/validation_report_file'
        )
        options['append_to_validation_report'] = false
        reset_validation_report(options, 'import_folio_xml_specific_steps')
        validate_folio_xml_import(options.merge('run_options' => %w[pre_import]))
        convert_folio_xml_to_at(options)
        fix_remove_underscores_inside_folio_paragraph_numbers(options)
        fix_normalize_editors_notes(
          options.merge({ 'input' => 'folio_import_dir/at_files' })
        ) # has to be invoked before fix_convert_folio_typographical_chars
        fix_convert_folio_typographical_chars(options)
        options['append_to_validation_report'] = true
        validate_folio_xml_import(options.merge('run_options' => %w[post_import]))
      end

      def import_idml_specific_steps(options)
        options['report_file'] = config.compute_glob_pattern(
          'idml_import_dir/validation_report_file'
        )
        options['append_to_validation_report'] = false
        reset_validation_report(options, 'import_idml_specific_steps')
        validate_idml_import(options.merge('run_options' => %w[pre_import]))
        convert_idml_to_at(options)
        fix_adjust_gap_mark_positions(options)
        fix_normalize_editors_notes(
          options.merge({ 'input' => 'idml_import_dir/at_files' })
        )
        options['append_to_validation_report'] = true
        validate_idml_import(options.merge('run_options' => %w[post_import]))
      end

      # Specifies all shared steps that need to run after each import
      def import_shared_steps(options)
        merge_record_marks_from_folio_xml_at_into_idml_at(options)
        fix_adjust_merged_record_mark_positions(options)
        fix_convert_abbreviations_to_lower_case(options) # run after merge_record_marks...
        fix_normalize_subtitle_mark_before_gap_mark_positions(
          options.merge({ 'input' => 'staging_dir/at_files' })
        )
        move_staging_to_content(options)
        options['report_file'] = config.compute_glob_pattern(
          'content_dir/validation_report_file'
        )
        options['append_to_validation_report'] = false
        reset_validation_report(options, 'import_shared_steps')
        validate_content(options)
      end

    end
  end
end
