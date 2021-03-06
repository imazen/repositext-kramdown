require_relative '../../helper'

class Repositext
  class Subtitle
    describe IdGenerator do

      let(:inventory_file) {
        FileLikeStringIO.new('_path', "1000000\n4567890\n9999999\n", 'r+')
      }

      let(:generator) { IdGenerator.new(inventory_file) }

      describe '#generate' do

        it "generates one new ID by default" do
          generator.generate.length.must_equal(1)
        end

        it "generates multiple new IDs if told so" do
          generator.generate(7).length.must_equal(7)
        end

      end

      describe '#compute_unique_stids' do

        it "returns a new stid" do
          generator.generate(0) # to initialize @existing_stids inventory file
          generator.send(:compute_unique_stids, 1).length.must_equal(1)
        end

        it "stops after a certain number of attempts if it can't find a non-existing stid" do
          # stub IdGenerator#exists? to always return true
          def generator.stid_exists_in_inventory_file?(_); true; end
          -> { generator.send(:compute_unique_stids, 1) }.must_raise(RuntimeError)
        end

      end

      describe "#add_stids_to_inventory" do

        it "adds stids to inventory file in ascending order" do
          generator.generate(0) # to initialize @existing_stids inventory file
          generator.send(:add_stids_to_inventory, ['9999998', '1000001'])
          generator.inventory_file.rewind
          generator.inventory_file.read.must_equal(
            "1000000\n1000001\n4567890\n9999998\n9999999\n"
          )
        end

      end

      describe "#generate_stid" do

        it "returns a valid stid" do
          r = generator.send(:generate_stid)
          r.is_a?(String).must_equal(true)
          r.length.must_equal(7)
        end

      end

      describe "#stid_exists_in_inventory_file?" do

        it "returns true if stid exists in inventory file" do
          generator.generate(0) # to initialize @existing_stids inventory file
          generator.send(:stid_exists_in_inventory_file?, '1000000').must_equal(true)
        end

        it "returns false if stid doesn't exist in inventory file" do
          generator.generate(0) # to initialize @existing_stids inventory file
          generator.send(:stid_exists_in_inventory_file?, '1000002').must_equal(false)
        end

      end

    end
  end
end
