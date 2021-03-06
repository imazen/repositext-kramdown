class Repositext
  class Services

    # This service extracts parts from a file's id page:
    #
    # Usage:
    #  outcome = ExtractContentAtIdParts.call(content_at)
    #  id_parts = outcome.result
    #
    class ExtractContentAtIdParts

      # @param content_at [String]
      def self.call(content_at, parts_to_extract=nil)
        new(content_at, parts_to_extract).call
      end

      # @param content_at [String]
      def initialize(content_at, parts_to_extract)
        @content_at = content_at
        @parts_to_extract = parts_to_extract || %w[id_title1 id_title2 id_paragraph]
      end

      # @return Hash with keys for each part found
      def call
        parts_collector = @parts_to_extract.inject({}) { |m,part_class|
          found_part = @content_at[/^[^\n]+(?=\n\{: \.#{ part_class }\})/]
          if found_part
            m[part_class] ||= []
            m[part_class] << found_part
          end
          m
        }
        Outcome.new(true, parts_collector, [])
      end

    end
  end
end
