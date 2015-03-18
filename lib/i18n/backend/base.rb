require 'yaml'
require 'i18n/core_ext/hash'
require 'i18n/core_ext/kernel/surpress_warnings'

module I18n
  module Backend
    module Base
      include I18n::Backend::Transliterator

      # Accepts a list of paths to translation files. Loads translations from
      # plain Ruby (*.rb) or YAML files (*.yml). See #load_rb and #load_yml
      # for details.
      def load_translations(*filenames)
        #I18n.log_message :debug, "##### I18n::Backend::Base.load_translations [#{self.class.to_s}]"
        filenames = I18n.load_path if filenames.empty?
        filenames.flatten.each { |filename| load_file(filename) }
      end

      # This method receives a locale, a data hash and options for storing translations.
      # Should be implemented
      def store_translations(locale, data, options = {})
        raise NotImplementedError
      end

      def translate(locale, key, options = {})
        I18n.log_message :debug, "##### I18n::Backend::Base.translate [#{self.class.to_s}]"
        raise InvalidLocale.new(locale) unless locale

        #I18n.log_message :debug, "-- create new translation object"
        translation = I18n::Backend::Translation.new(options.merge(:locale => locale, :key => key, :backend => self.class))
        #I18n.log_message :debug, "-- translation: #{translation.inspect}"
        
        I18n.log_message :debug, "-- apply filter before_lookup"
        translation = I18n.filter_chain.apply(:before_lookup, translation)
        I18n.log_message :debug, "-- translation: #{translation.inspect}"
        
        I18n.log_message :debug, "-- lookup translation data using translation data"
        if translation.key
          I18n.log_message :debug, "  -- we have a key, lets call lookup"
          translation.unparsed_content = lookup(translation.locale, translation.key, translation.scope, options)
          translation.interpolation_keys = I18n.get_interpolation_keys(translation.unparsed_content)
        end
        I18n.log_message :debug, "-- translation: #{translation.inspect}"
        
        I18n.log_message :debug, "-- check options and resolve"
        if options.empty?
          I18n.log_message :debug, "  -- options are empty, resolve translation"
          translation.content = resolve(translation.locale, translation.key, translation.unparsed_content, options)
        else
          I18n.log_message :debug, "  -- options are not empty, resolve translation (possibly with default)"
          if translation.unparsed_content.nil? && translation.default
            I18n.log_message :debug, "    -- unparsed_content is nil and we have default"
            translation.content = default(translation.locale, translation.key, translation.default, options)  
          else
            I18n.log_message :debug, "    -- unparsed_content is not nil or we do not have default"
            translation.content = resolve(translation.locale, translation.key, translation.unparsed_content, options) 
          end
        end
        I18n.log_message :debug, "-- translation: #{translation.inspect}"

        #I18n.log_message :debug, "-- throw MissingTranslation if content is nil"
        throw(:exception, I18n::MissingTranslation.new(translation.locale, translation.key, options)) if translation.content.nil?
        
        #I18n.log_message :debug, "-- dup content if it is a string"
        translation.content = translation.content.dup if translation.content.is_a?(String)
        #I18n.log_message :debug, "-- translation: #{translation.inspect}"
        
        #I18n.log_message :debug, "-- pluralize content if count"
        translation.content = pluralize(translation.locale, translation.content, translation.count) if translation.count
        #I18n.log_message :debug, "-- translation: #{translation.inspect}"
        
        #I18n.log_message :debug, "-- interpolate content if necessary"
        translation.content = interpolate(translation.locale, translation.content, translation.interpolations) if translation.interpolations
        #I18n.log_message :debug, "-- translation: #{translation.inspect}"
        
        I18n.log_message :debug, "-- apply filter after_lookup"
        translation = I18n.filter_chain.apply(:after_lookup, translation)
        #I18n.log_message :debug, "-- translation: #{translation.inspect}"
        
        #I18n.log_message :debug, "-- all done!"
        I18n.log_newline
        translation.content
      end
      
      def exists?(locale, key)
        lookup(locale, key) != nil
      end

      # Acts the same as +strftime+, but uses a localized version of the
      # format string. Takes a key from the date/time formats translations as
      # a format argument (<em>e.g.</em>, <tt>:short</tt> in <tt>:'date.formats'</tt>).
      def localize(locale, object, format = :default, options = {})
        I18n.log_message :debug, "##### I18n::Backend::Base.localize [#{self.class.to_s}]"
        raise ArgumentError, "Object must be a Date, DateTime or Time object. #{object.inspect} given." unless object.respond_to?(:strftime)

        if Symbol === format
          key  = format
          type = object.respond_to?(:sec) ? 'time' : 'date'
          options = options.merge(:raise => true, :object => object, :locale => locale)
          format  = I18n.t(:"#{type}.formats.#{key}", options)
        end

        # format = resolve(locale, object, format, options)
        format = format.to_s.gsub(/%[aAbBpP]/) do |match|
          case match
          when '%a' then I18n.t(:"date.abbr_day_names",                  :locale => locale, :format => format)[object.wday]
          when '%A' then I18n.t(:"date.day_names",                       :locale => locale, :format => format)[object.wday]
          when '%b' then I18n.t(:"date.abbr_month_names",                :locale => locale, :format => format)[object.mon]
          when '%B' then I18n.t(:"date.month_names",                     :locale => locale, :format => format)[object.mon]
          when '%p' then I18n.t(:"time.#{object.hour < 12 ? :am : :pm}", :locale => locale, :format => format).upcase if object.respond_to? :hour
          when '%P' then I18n.t(:"time.#{object.hour < 12 ? :am : :pm}", :locale => locale, :format => format).downcase if object.respond_to? :hour
          end
        end

        object.strftime(format)
      end

      # Returns an array of locales for which translations are available
      # ignoring the reserved translation meta data key :i18n.
      def available_locales
        raise NotImplementedError
      end

      def reload!
        @skip_syntax_deprecation = false
      end
      
      def reload_entry!(locale, key, options = {})
        I18n.log_message :debug, "##### CALLED I18n::Base.reload_entry! [#{self.class.to_s}]"
        true
      end

      protected

        # The method which actually looks up for the translation in the store.
        def lookup(locale, key, scope = [], options = {})
          I18n.log_message :debug, "##### CALLED I18n::Base.lookup [#{self.class.to_s}]"
          raise NotImplementedError
        end

        # Evaluates defaults.
        # If given subject is an Array, it walks the array and returns the
        # first translation that can be resolved. Otherwise it tries to resolve
        # the translation directly.
        def default(locale, object, subject, options = {})
          I18n.log_message :debug, "##### I18n::Backend::Base.default [#{self.class.to_s}]"
          options = options.dup.reject { |key, value| key == :default }
          case subject
          when Array
            subject.each do |item|
              result = resolve(locale, object, item, options) and return result
            end and nil
          else
            resolve(locale, object, subject, options)
          end
        end

        # Resolves a translation.
        # If the given subject is a Symbol, it will be translated with the
        # given options. If it is a Proc then it will be evaluated. All other
        # subjects will be returned directly.
        def resolve(locale, object, subject, options = {})
          I18n.log_message :debug, "##### I18n::Backend::Base.resolve [#{self.class.to_s}]"
          #I18n.log_message :debug, "-- return #{subject} if options[:resolve] == false"
          return subject if options[:resolve] == false
          
          #I18n.log_message :debug, "-- lets resolve!"
          result = catch(:exception) do
            case subject
            when Symbol
              #I18n.log_message :debug, "  -- subject is a symbol, call I18n.translate"
              I18n.translate(subject, options.merge(:locale => locale, :throw => true))
            when Proc
              #I18n.log_message :debug, "  -- subject is Proc, call it"
              date_or_time = options.delete(:object) || object
              resolve(locale, object, subject.call(date_or_time, options))
            else
              #I18n.log_message :debug, "  -- subject is something else!"
              subject
            end
          end
          #I18n.log_message :debug, "== result: #{result}"
          result unless result.is_a?(MissingTranslation)
        end

        # Picks a translation from a pluralized mnemonic subkey according to English
        # pluralization rules :
        # - It will pick the :one subkey if count is equal to 1.
        # - It will pick the :other subkey otherwise.
        # - It will pick the :zero subkey in the special case where count is
        #   equal to 0 and there is a :zero subkey present. This behaviour is
        #   not stand with regards to the CLDR pluralization rules.
        # Other backends can implement more flexible or complex pluralization rules.
        def pluralize(locale, entry, count)
          I18n.log_message :debug, "##### I18n::Backend::Base.pluralize [#{self.class.to_s}]"
          return entry unless entry.is_a?(Hash) && count

          key = :zero if count == 0 && entry.has_key?(:zero)
          key ||= count == 1 ? :one : :other
          raise InvalidPluralizationData.new(entry, count) unless entry.has_key?(key)
          entry[key]
        end

        # Interpolates values into a given string.
        #
        #   interpolate "file %{file} opened by %%{user}", :file => 'test.txt', :user => 'Mr. X'
        #   # => "file test.txt opened by %{user}"
        def interpolate(locale, string, values = {})
          I18n.log_message :debug, "##### I18n::Backend::Base.interpolate [#{self.class.to_s}]"
          if string.is_a?(::String) && !values.empty?
            I18n.interpolate(string, values)
          else
            string
          end
        end

        # Loads a single translations file by delegating to #load_rb or
        # #load_yml depending on the file extension and directly merges the
        # data to the existing translations. Raises I18n::UnknownFileType
        # for all other file extensions.
        def load_file(filename)
          type = File.extname(filename).tr('.', '').downcase
          raise UnknownFileType.new(type, filename) unless respond_to?(:"load_#{type}", true)
          data = send(:"load_#{type}", filename)
          unless data.is_a?(Hash)
            raise InvalidLocaleData.new(filename, 'expects it to return a hash, but does not')
          end
          data.each { |locale, d| store_translations(locale, d || {}) }
        end

        # Loads a plain Ruby translations file. eval'ing the file must yield
        # a Hash containing translation data with locales as toplevel keys.
        def load_rb(filename)
          eval(IO.read(filename), binding, filename)
        end

        # Loads a YAML translations file. The data must have locales as
        # toplevel keys.
        def load_yml(filename)
          begin
            YAML.load_file(filename)
          rescue TypeError, ScriptError, StandardError => e
            raise InvalidLocaleData.new(filename, e.inspect)
          end
        end
        
        alias_method :load_yaml, :load_yml

    end
  end
end
