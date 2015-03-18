# Memoize module simply memoizes the values returned by lookup using
# a flat hash and can tremendously speed up the lookup process in a backend.
#
# To enable it you can simply include the Memoize module to your backend:
#
#   I18n::Backend::Simple.include(I18n::Backend::Memoize)
#
# Notice that it's the responsibility of the backend to define whenever the
# cache should be cleaned.
module I18n
  module Backend
    module Memoize
      def available_locales
        @memoized_locales ||= super
      end

      def store_translations(locale, data, options = {})
        reset_memoizations!(locale)
        super
      end

      def reload!
        reset_memoizations!
        super
      end
      
      def reload_entry!(locale, key, options = {})
        I18n.log_message :debug, "##### I18n::Backend::Memoize.reload_entry!"
        reset_memoization_entry!(locale, key, options[:scope], options[:separator])
        super
      end

      protected

        def lookup(locale, key, scope = nil, options = {})
          I18n.log_message :debug, "##### I18n::Backend::Memoize.lookup"
          #I18n.log_message :debug, "-- make flat_key"
          flat_key  = I18n::Backend::Flatten.normalize_flat_keys(locale,
            key, scope, options[:separator]).to_sym
          #I18n.log_message :debug, "-- flat_key: #{flat_key}"
          #I18n.log_message :debug, "-- make flat_hash"
          flat_hash = memoized_lookup[locale.to_sym]
          #I18n.log_message :debug, "-- flat_hash: #{flat_hash}"
          
          #I18n.log_message :debug, "-- check flat_hash for flat_key"
          if flat_hash.key?(flat_key) 
            #I18n.log_message :debug, "-- yes we have key"
            flat_hash[flat_key] 
          else
            #I18n.log_message :debug, "-- no we do not have key, call super"
            (flat_hash[flat_key] = super)
          end
        end

        def memoized_lookup
          @memoized_lookup ||= Hash.new { |h, k| h[k] = {} }
        end

        def reset_memoizations!(locale=nil)
          @memoized_locales = nil
          (locale ? memoized_lookup[locale.to_sym] : memoized_lookup).clear
        end
        
        def reset_memoization_entry!(locale, key, scope, separator)
          flat_key  = I18n::Backend::Flatten.normalize_flat_keys(locale, key, scope, separator).to_sym
          if @memoized_lookup[locale.to_sym].key?(flat_key)
            @memoized_lookup[locale.to_sym].delete(flat_key)
          end 
          true
        end
    end
  end
end
