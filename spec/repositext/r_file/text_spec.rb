require_relative '../../helper'

class Repositext
  class RFile
    describe Text do
      let(:contents) { 'text contents' }
      let(:language) { Language::English.new }
      let(:filename) { '/path/to/file/name.txt' }
      let(:default_rfile) { RFile::Text.new(contents, language, filename) }

      # This class only includes mixins, so we're just testing one method
      # to make sure the class loads.
      describe 'filename' do
        it 'responds' do
          default_rfile.must_respond_to(:filename)
        end
      end
    end
  end
end
