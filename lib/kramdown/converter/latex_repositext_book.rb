module Kramdown
  module Converter
    class LatexRepositextBook < LatexRepositext

      include DocumentMixin

      # Configure page settings. All values are in inches
      # @param[Symbol, optional] key
      def page_settings(key = nil)
        ps = {
          english_bound: {
            paperwidth: 5.375,
            paperheight: 8.375,
            inner: 0.6875,
            outer: 0.5208,
            top: 0.7733,
            bottom: 0.471,
            headsep: 0.1,
          },
          english_regular: {
            paperwidth: 5.375,
            paperheight: 8.4375,
            inner: 0.4531,
            outer: 0.4844,
            top: 0.7733,
            bottom: 0.471,
            headsep: 0.1,
          },
          foreign_bound: {
            paperwidth: 5.375,
            paperheight: 8.375,
            inner: 0.6875,
            outer: 0.5208,
            top: 0.76,
            bottom: 0.5,
            headsep: 0.1,
          },
          foreign_regular: {
            paperwidth: 5.375,
            paperheight: 8.4375,
            inner: 0.625,
            outer: 0.6458,
            top: 0.76,
            bottom: 0.5,
            headsep: 0.1,
          },
        }
        ps = ps[key]  if key
        ps
      end

      def size_scale_factor
        1.0
      end

      def include_meta_info
        false
      end

    end
  end
end