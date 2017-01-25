require "./sample"

module Crometheus
# Base class for individual metrics.
# You want to instantiate `Collector`(T), not this.
#
# If you want to create your own custom metric types, you'll need to
# subclass `Metric`. `#type` and `#samples(&block : Sample -> Nil)` are
# the only abstract methods you'll need to override; then you will also
# need to implement your custom instrumentation. The following is a
# perfectly serviceable, if useless, metric type:
#```
# require "crometheus/metric"
#
# class Randometric < Crometheus::Metric
#   def type
#     "gauge"
#   end
#
#   def samples(&block : Crometheus::Sample -> Nil)
#     yield make_sample(get_value())
#   end
#
#   def get_value()
#     rand(10).to_f64
#   end
# end
#```
# If your subclass's constructor needs to take arguments, make them
# keyword arguments. `Collector` will pass any unrecognized keyword
# arguments to the constructor of any `Metric` objects it instantiates.
# `Histogram` configures its buckets this way.
#
# See the `Counter`, `Gauge`, `Histogram`, and `Summary` classes for
# examples of how to subclass Metric.
  abstract class Metric
    @name : Symbol
    @labels : Hash(Symbol, String)

    def initialize(@name, @labels = {} of Symbol => String)
      @labels.each_key do |label|
        unless self.class.valid_label?(label)
          raise ArgumentError.new("Invalid label: #{label}")
        end
      end
    end

    # Returns the type of Prometheus metric this class represents.
    # Should be overridden to return exactly one of the following:
    # `"gauge"`, `"counter"`, `"summary"`, `"histogram"`, or
    # `"untyped"`.
    abstract def type : String

    # Yields a `Sample` object for each data point this metric returns.
    # This method should `yield` any number of `Sample` objects, one
    # sample per `yield`. See `#make_sample`.
    abstract def samples(&block : Sample -> Nil) : Nil

    # As `#samples(&block : Sample -> Nil)`, but appends `Sample`
    # objects to the given Array rather than yielding them. Don't
    # override this `samples`; it comes for free with the other one.
    def samples(ary : Array(Sample) = Array(Sample).new) : Array(Sample)
      samples {|ss| ary << ss}
      return ary
    end

    # Called by `#initialize` to validate that this `Metric`'s labels
    # do not violate any of Prometheus' naming rules. Returns `false`
    # under any of these conditions:
    # * the label is `:job` or `:instance`
    # * the label starts with `__`
    # * the label is not alphanumeric with underscores
    def self.valid_label?(label : Symbol) : Bool
      return false if [:job, :instance].includes?(label)
      ss = label.to_s
      return false if ss !~ /^[a-zA-Z_][a-zA-Z0-9_]*$/
      return false if ss.starts_with?("__")
      return true
    end

    # Convenience method for creating `Sample` objects.
    # This simply calls `Crometheus::Sample.new` with the same arguments
    # as are passed to it, except that `labels` gets merged into
    # `@labels` first. Call this from `#samples(&block : Sample)`.
    def make_sample(value : Float64, labels = {} of Symbol => String, suffix = "")
      Crometheus::Sample.new(value: value,
                             labels: @labels.merge(labels),
                             suffix: suffix)
    end
  end
end
