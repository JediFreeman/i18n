module I18n
  module Backend
    class Translation
      attr_accessor :locale, :key, :content, :scope, :default, :interpolations, :context, :backend, :unparsed_content, :interpolation_keys

      def initialize(args)
        I18n.log_message :debug, "##### I18n::Backend::Translation.initialize"
        I18n.log_message :debug, "-- args: #{args}"
        @locale             = args.delete :locale
        @key                = args.delete :key
        @scope              = args.delete :scope
        @default            = args.delete :default
        @backend            = args.delete :backend
        @interpolations     = args.except(*RESERVED_KEYS)
        @content            = nil
        @unparsed_content   = nil
        @interpolation_keys = []

        # Context should be a reserved key
        # Not deleting this arg here so as not to break the existing API
        @context            =  args[:context]
      end

      def count
        interpolations[:count]
      end
    end
  end
end