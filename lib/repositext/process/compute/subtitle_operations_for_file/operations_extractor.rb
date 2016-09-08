class Repositext
  class Process
    class Compute
      class SubtitleOperationsForFile
        class OperationsExtractor

          # @param aligned_subtitle_pairs [Array<AlignedSubtitlePair>]
          # @param file_date_code [String]
          def initialize(aligned_subtitle_pairs, file_date_code)
            @aligned_subtitle_pairs = aligned_subtitle_pairs
            @file_date_code = file_date_code
          end

          # Takes all the file's aligned_subtitle_pairs, and extracts subtitle
          # operations.
          # @param aligned_subtitle_pairs [Array<AlignedSubtitlePair>]
          # @return [Array<Subtitle::Operation>]
          def extract
            init_context

            until @current_asp.nil? do
              process_current_asp
              advance_to_next_asp
            end

            @ops_in_file
          end

          def init_context
            @current_asp_index = 0
            @current_asp = @aligned_subtitle_pairs[0]
            @file_operation_index = 0
            @next_asp = @aligned_subtitle_pairs[1]
            @ops_in_file = []
            @prev_stid = 'new_file'
            reset_current_capture_group
          end

          def process_current_asp

            curr = @current_asp

            @asp_group_cumulative_content_change += curr[:content_length_change]
            @asp_group_cumulative_content_length_to += curr[:to][:content].length

            if debug
              puts "P"  if curr[:first_in_para]
              puts " - #{ curr[:type] }"
              just_method = case curr[:type]
              when :right_aligned
                :rjust
              when :left_aligned, :fully_aligned
                :ljust
              when :unaligned, :st_added, :st_removed
                :center
              else
                raise "Handle this: #{ curr[:type] }"
              end
              para_boundaries_reporter = ->(st_attrs) {
                [
                  (st_attrs[:first_in_para] ? 'first_ip' : nil),
                  (st_attrs[:last_in_para] ? 'last_ip' : nil)
                ].compact.join(', ')
              }
              puts "   From: #{ curr[:from][:content].strip.send(just_method, 130) }   #{ para_boundaries_reporter.call(curr[:from]) }"
              puts "   To:   #{ curr[:to][:content].strip.send(just_method, 130) }   #{ para_boundaries_reporter.call(curr[:to]) }"
              puts([
                "   ",
                "clc:#{ curr[:content_length_change] } ",
                "ccc:#{ @asp_group_cumulative_content_change } ",
                "sl:#{ curr[:sim_left] } ",
                "sa:#{ curr[:sim_abs] } ",
                "sr:#{ curr[:sim_right] } ",
              ].join)
            end

            case @prev_right_edge
            when :aligned
              # The right edge of the previous ASP is aligned:
              # Start a new capture group.
              case curr[:type]
              when :fully_aligned
                # Current ASP is self contained: Not a subtitle operation.
                if curr[:from][:content] == curr[:to][:content]
                  capture_op(:no_op)
                else
                  capture_op(:content_change)
                end
                reset_current_capture_group
              when :left_aligned, :unaligned
                if current_right_edge_aligned?
                  capture_op(:content_change)
                  reset_current_capture_group
                else
                  @prev_right_edge = :unaligned
                end
              when :right_aligned
                # Current ASP is self contained: Not a subtitle operation.
                capture_op(:content_change)
                reset_current_capture_group
              when :st_added
                # Added subtitle, not connected to previous: insert.
                capture_op(:insert)
                if current_right_edge_aligned?
                  reset_current_capture_group
                else
                  @prev_right_edge = :unaligned
                end
              when :st_removed
                # Removed subtitle, not connected to previous: delete.
                capture_op(:delete)
                if current_right_edge_aligned?
                  reset_current_capture_group
                else
                  @prev_right_edge = :unaligned
                end
              else
                raise "Handle this! #{ curr.inspect }"
              end

            when :unaligned
              # The right edge of the previous ASP is not aligned:
              # Continue capture group.
              case curr[:type]
              when :fully_aligned, :left_aligned
                raise "Should never get here! #{ curr.inspect }"
              when :right_aligned
                # It's a move, determine direction
                capture_op(compute_move_direction)
                reset_current_capture_group
              when :st_added
                if :st_added == @prev_asp[:type] && :insert == @ops_in_group.last.operationType
                  # This is a subsequent :insert
                  capture_op(:insert)
                else
                  # It's a split
                  capture_op(:split)
                end
                if current_right_edge_aligned?
                  reset_current_capture_group
                else
                  @prev_right_edge = :unaligned
                end
              when :st_removed
                if :st_removed == @prev_asp[:type] && :delete == @ops_in_group.last.operationType
                  # This is a subsequent :delete
                  capture_op(:delete)
                else
                  # It's a merge
                  capture_op(:merge)
                end
                if current_right_edge_aligned?
                  reset_current_capture_group
                else
                  @prev_right_edge = :unaligned
                end
              when :unaligned
                capture_op(compute_move_direction)
                if current_right_edge_aligned?
                  reset_current_capture_group
                else
                  @prev_right_edge = :unaligned
                end
              else
                raise "Handle this! #{ curr.inspect }"
              end
            else
              raise "Handle this! #{ @prev_right_edge }"
            end

            puts "P"  if debug && curr[:last_in_para]
          end

          def advance_to_next_asp
            @prev_asp = @current_asp
            @current_asp = @aligned_subtitle_pairs[@current_asp_index += 1]
            @next_asp = @aligned_subtitle_pairs[@current_asp_index + 1]
            @prev_stid = if @prev_asp[:subtitle_object].nil?
              'new_file'
            else
              @prev_asp[:subtitle_object].persistent_id
            end
          end

          def reset_current_capture_group
            @prev_right_edge = :aligned
            @asp_group_cumulative_content_change = 0
            @asp_group_cumulative_content_length_to = 0
            @ops_in_group = []
          end

          def current_right_edge_aligned?
            cur = @current_asp
            nxt = @next_asp
            if nxt.nil?
              # current_asp is the last in file
              return true
            elsif [:fully_aligned, :left_aligned].include?(nxt[:type])
              # next_asp has clear left boundary
              return true
            elsif [:right_aligned, :unaligned].include?(nxt[:type])
              # next_asp has no left boundary
              return false
            elsif [:st_added, :st_removed].include?(nxt[:type])
              # next_asp may be connected to current_asp
              return false
            else
              raise "Should never get here!"
            end
          end

          def capture_op(op_type)
            op = case op_type
            when :content_change
              # Nothing to do
              nil
            when :delete
              if(prev_op = @ops_in_group.last) && :delete == prev_op.operationType
                # Don't record separate operation, just add @current_asp to
                # affectedStids
                prev_op.affectedStids << @current_asp[:subtitle_object]
                nil
              else
                # record new operation
                Subtitle::Operation.new_from_hash(
                  affectedStids: [@current_asp[:subtitle_object]],
                  operationId: compute_operation_id,
                  operationType: :delete,
                )
              end
            when :insert
              if(prev_op = @ops_in_group.last) && :insert == prev_op.operationType
                # Don't record separate operation, just add @current_asp to
                # affectedStids
                prev_op.affectedStids << @current_asp[:subtitle_object]
                nil
              else
                # record new operation
                Subtitle::Operation.new_from_hash(
                  affectedStids: [@current_asp[:subtitle_object]],
                  operationId: compute_operation_id,
                  operationType: :insert,
                  afterStid: @prev_stid,
                )
              end
            when :merge
              if(prev_op = @ops_in_group.last) && :merge == prev_op.operationType
                # Don't record separate operation, just add @current_asp to
                # affectedStids
                prev_op.affectedStids << @current_asp[:subtitle_object]
                nil
              else
                # record new operation
                Subtitle::Operation.new_from_hash(
                  affectedStids: [@prev_asp, @current_asp].map { |e| e[:subtitle_object] },
                  operationId: compute_operation_id,
                  operationType: :merge,
                )
              end
            when :move_left
              Subtitle::Operation.new_from_hash(
                affectedStids: [@prev_asp, @current_asp].map { |e| e[:subtitle_object] },
                operationId: compute_operation_id,
                operationType: :move_left,
              )
            when :move_right
              Subtitle::Operation.new_from_hash(
                affectedStids: [@prev_asp, @current_asp].map { |e| e[:subtitle_object] },
                operationId: compute_operation_id,
                operationType: :move_right,
              )
            when :no_op
              # Nothing to do
              nil
            when :split
              if(prev_op = @ops_in_group.last) && :split == prev_op.operationType
                # Don't record separate operation, just add @current_asp to
                # affectedStids
                prev_op.affectedStids << @current_asp[:subtitle_object]
                nil
              else
                # record new operation
                Subtitle::Operation.new_from_hash(
                  affectedStids: [@prev_asp, @current_asp].map { |e| e[:subtitle_object] },
                  operationId: compute_operation_id,
                  operationType: :split,
                )
              end
            else
              raise "Handle this: #{ op_type.inspect }"
            end
            if op
              @ops_in_group << op
              @ops_in_file << op
            end
            puts "   OP: #{ op_type }".color(:blue)  if debug
          end

          def compute_move_direction
            ccc_before_current_asp = @asp_group_cumulative_content_change - @current_asp[:content_length_change]
            if ccc_before_current_asp < 0
              # Capture group has gotten shorter up to @current_asp => move left
              :move_left
          # @param asp_index [Integer] index of ASP in file
          def compute_operation_id
            [@file_date_code, @file_operation_index += 1].join('_')
          end

            else
              # Capture group has gotten longer up to @current_asp => move right
              :move_right
            end
          end

          def debug
            true
          end
        end
      end
    end
  end
end
