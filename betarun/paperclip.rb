module Paperclip
  class SinatraFileAdapter < AbstractAdapter
    def initialize(target)
      @target = target
      cache_current_values
    end

    def cache_current_values
      self.original_filename = @target[:filename]
      @tempfile = copy_to_tempfile(@target[:tempfile])
      @content_type = @target[:type]
      @size = File.size(@tempfile)
    end

  end
end

Paperclip.io_adapters.register Paperclip::SinatraFileAdapter do |target|
  target.class == Hash && !target[:tempfile].nil? && (File === target[:tempfile] || Tempfile === target[:tempfile])
end