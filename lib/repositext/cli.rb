class Repositext
  class Cli < Thor

    class RtfileError < RuntimeError; end

    FILE_SPEC_DELIMITER = '/'

    include Thor::Actions
    include Cli::RtfileDsl
    include Cli::LongDescriptionsForCommands

    include Cli::Compare
    include Cli::Convert
    include Cli::Fix
    include Cli::Init
    include Cli::Merge
    include Cli::Move
    include Cli::Report
    include Cli::Sync
    include Cli::Validate

    include Cli::Export
    include Cli::Import

    # For rtfile template loading
    def self.source_root
      File.dirname(__FILE__)
    end

    class_option :rtfile,
                 :type => :string,
                 :required => true,
                 :desc => 'Specifies which Rtfile to use. Defaults to the closest Rtfile found in the directory hierarchy.'
    class_option :input,
                 :type => :string,
                 :desc => 'Specifies the input file pattern. Expects an absolute path pattern that can be used with Dir.glob.'
    class_option :'changed-only',
                 :type => :boolean,
                 :default => true,
                 :desc => 'If true, only files that have been changed or added will be processed.'

    # Override original initialize so that the options hash is not frozen. We
    # need to modify it.
    def initialize(args=[], options={}, config={})
      super
      @options = @options.dup
    end


    # Basic commands


    desc "compare SPEC", "Compares files for consistency"
    long_desc long_description_for_compare
    # @param[String] command_spec Specification of the operation
    def compare(command_spec)
      invoke_repositext_command('compare', command_spec, options)
    end


    desc 'convert SPEC', 'Converts files from one format to another'
    long_desc long_description_for_convert
    # @param[String] command_spec Specification of the operation
    def convert(command_spec)
      invoke_repositext_command('convert', command_spec, options)
    end


    desc 'fix SPEC', 'Modifies files in place'
    long_desc long_description_for_fix
    # @param[String] command_spec Specification of the operation
    def fix(command_spec)
      invoke_repositext_command('fix', command_spec, options)
    end


    desc "init", "Generates a default Rtfile"
    long_desc long_description_for_init
    method_option :force,
                  :aliases => "-f",
                  :desc => "Flag to force overwriting an existing Rtfile"
    # TODO: allow specification of Rtfile path
    # @param[String, optional] command_spec Specification of the operation. This
    #     is used for testing (pass 'test' as command_spec)
    def init(command_spec = nil)
      if command_spec
        invoke_repositext_command('init', command_spec, options)
      else
        generate_rtfile(options)
      end
    end


    desc 'merge SPEC', 'Merges the contents of two files'
    long_desc long_description_for_merge
    method_option :input_1,
                  :type => :string,
                  :desc => 'Specifies the input file pattern for the first file. Expects an absolute path pattern that can be used with Dir.glob.'
    method_option :input_2,
                  :type => :string,
                  :desc => 'Specifies the base directory for the second file. Expects an absolute path to a directory.'
    # @param[String] command_spec Specification of the operation
    def merge(command_spec)
      invoke_repositext_command('merge', command_spec, options)
    end


    desc 'move SPEC', 'Moves files to another location'
    long_desc long_description_for_move
    # @param[String] command_spec Specification of the operation
    def move(command_spec)
      invoke_repositext_command('move', command_spec, options)
    end


    desc 'report SPEC', 'Generates a report'
    long_desc long_description_for_report
    # @param[String] command_spec Specification of the operation
    def report(command_spec)
      invoke_repositext_command('report', command_spec, options)
    end


    desc 'sync SPEC', 'Syncs data between different file types in /content'
    long_desc long_description_for_sync
    # @param[String] command_spec Specification of the operation
    def sync(command_spec)
      invoke_repositext_command('sync', command_spec, options)
    end

    desc 'validate SPEC', 'Validates files'
    long_desc long_description_for_validate
    method_option :report_file,
                  :type => :string,
                  :default => nil,
                  :desc => 'Specifies a file name to which a validation report will be written.'
    method_option :run_options,
                  :type => :array,
                  :default => %w[pre_import post_import],
                  :desc => 'Specifies which validations to run. Possible values: %w[pre_import post_import]'
    # @param[String] command_spec Specification of the operation
    # NOTE: --input option can only use named file_specs, not dir.glob patterns.
    #
    # TODO: implement these command line options:
    #
    # '-r', '--report_filename PATH', "optional, will write report to the file specified if given. Report will always be printed to STDOUT." do |arg|
    # '-l', '--logger LOGGER', "defaults to 'STDOUT'" do |arg|
    # '-v', '--log_level LOG_LEVEL', "optional, one of 'debug', 'info', 'warn' or 'error'. Defaults to 'info'." do |arg|
    # '-s', '--strictness STRICTNESS', "optional, one of 'strict' or 'loose'. Defaults to 'strict'." do |arg|
    def validate(command_spec)
      if options['report_file']
        new_options = options.dup # Thor options are a frozen Hash
        new_options['report_file'] = config.compute_glob_pattern(options['report_file'])
      else
        new_options = options
      end
      invoke_repositext_command('validate', command_spec, options)
    end


    # Higher level commands


    desc 'export SPEC', 'Exports files from /content'
    long_desc long_description_for_export
    # @param[String] command_spec Specification of the operation
    def export(command_spec)
      invoke_repositext_command('export', command_spec, options)
    end

    desc 'import SPEC', 'Imports files and merges changes into /content'
    long_desc long_description_for_import
    # @param[String] command_spec Specification of the operation
    def import(command_spec)
      invoke_repositext_command('import', command_spec, options)
    end

  private

    def config
      @config ||= Cli::Config.new
    end
    # This writer is used for testing to inject a mock config
    def config=(a_config)
      @config = a_config
    end

    # Invokes the command derived from main_command and command_spec
    # @param[String] main_command
    # @param[String] command_spec
    def invoke_repositext_command(main_command, command_spec, options)
      method_name = "#{ main_command }_#{ command_spec }"
      if respond_to?(method_name, true)
        self.send(method_name, options)
      else
        raise("The command you entered is not implemented. Missing method: #{ method_name.inspect }")
      end
    end


  end
end
