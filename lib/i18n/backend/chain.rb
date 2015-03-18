module I18n
  module Backend
    # Backend that chains multiple other backends and checks each of them when
    # a translation needs to be looked up. This is useful when you want to use
    # standard translations with a Simple backend but store custom application
    # translations in a database or other backends.
    #
    # To use the Chain backend instantiate it and set it to the I18n module.
    # You can add chained backends through the initializer or backends
    # accessor:
    #
    #   # preserves the existing Simple backend set to I18n.backend
    #   I18n.backend = I18n::Backend::Chain.new(I18n::Backend::ActiveRecord.new, I18n.backend)
    #
    # The implementation assumes that all backends added to the Chain implement
    # a lookup method with the same API as Simple backend does.
    class Chain
      module Implementation
        include Base

        attr_accessor :backends

        def initialize(*backends)
          self.backends = backends
        end
        
        def initialized?
          backends.all? { |backend| 
            ( backend.respond_to?(:initialized?) ? backend.initialized? : true )  
          }
        end

        def reload!
          backends.each { |backend| backend.reload! }
        end
        
        def reload_entry!(locale, key, options = {})
          I18n.log_message :debug, "##### I18n::Backend::Chain.reload_entry!"
          backends.each { |backend| backend.reload_entry!(locale, key, options) }
        end

        def store_translations(locale, data, options = {})
          backends.first.store_translations(locale, data, options)
        end

        def available_locales
          backends.map { |backend| backend.available_locales }.flatten.uniq
        end

        def translate(locale, key, default_options = {})
          I18n.log_message :debug, "##### I18n::Backend::Chain.translate"
          namespace = nil
          options = default_options.except(:default)

          backends.each do |backend|
            I18n.log_message :debug, "-- Chain checking backend #{backend.class.to_s}"
            catch(:exception) do
              options = default_options if backend == backends.last
              translation = backend.translate(locale, key, options)
              if namespace_lookup?(translation, options)
                namespace = translation.merge(namespace || {})
              elsif !translation.nil?
                return translation
              end
            end
            I18n.log_newline
          end
          
          I18n.log_newline
          return namespace if namespace
          throw(:exception, I18n::MissingTranslation.new(locale, key, options))
        end
        
        def exists?(locale, key)
          backends.any? do |backend|
            backend.exists?(locale, key)
          end
        end

        def exists?(locale, key)
          backends.any? do |backend|
            backend.exists?(locale, key)
          end
        end

        def localize(locale, object, format = :default, options = {})
          I18n.log_message :debug, "##### I18n::Backend::Chain.localize"
          backends.each do |backend|
            catch(:exception) do
              result = backend.localize(locale, object, format, options) and return result
            end
          end
          throw(:exception, I18n::MissingTranslation.new(locale, format, options))
        end

        protected
          def namespace_lookup?(result, options)
            result.is_a?(Hash) && !options.has_key?(:count)
          end
          
          def init_translations
            backends.each { |backend| backend.send(:init_translations) if backend.respond_to?(:init_translations) }
          end
          
          def translations
            backend = backends.select { |b| b.respond_to?(:translations) }.first
            if !backend.nil?
              return backend.send(:translations)
            else
              return nil  
            end
          end
      end

      include Implementation
    end
  end
end
