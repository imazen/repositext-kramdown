class Repositext
  class Process
    class Compute
      class SubtitleContentChangesForFile
        # Uses stid to compute the score.
        class SubtitleAligner < NeedlemanWunschAligner

          # Get score for alignment pair of subtitle attrs.
          #
          # @param left_el [Subtitle]
          # @param right_el [Subtitle]
          # @param row_index [Integer] in score matrix
          # @param col_index [Integer] in score matrix
          # @return [Float]
          def compute_score(left_el, right_el, row_index, col_index)
            # To improve performance, we only look at cells adjacent to
            # the matrix' diagonal. We can do this because we know the maximum
            # misalignment of subtitles from @options[:diagonal_band_range].
            # For cells outside of this band we return a very small negative
            # number as score so they are not considered when finding optimal
            # alignment.
            if (row_index - col_index).abs > @options[:diagonal_band_range]
              return default_gap_penalty * 2
            end

            # We compute score based on stid only
            Repositext::Service::ScoreSubtitleAlignmentUsingStid.call(
              left_stid: left_el.persistent_id,
              right_stid: right_el.persistent_id,
              default_gap_penalty: default_gap_penalty,
            )[:result]
          end

          def default_gap_penalty
            -10
          end

          def gap_indicator
            nil
          end

          def element_for_inspection_display(element, col_width = nil)
            element.persistent_id
          end

        end
      end
    end
  end
end
