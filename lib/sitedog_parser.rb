require "sitedog_parser/version"
require 'yaml'
require 'date'
require 'json'

require_relative "service"
require_relative "dictionary"
require_relative "url_checker"
require_relative "service_factory"

module SitedogParser
  class Error < StandardError; end

  # Main parser class that provides a high-level interface to the library
  class Parser
    # By default, fields that should not be processed as services
    DEFAULT_SIMPLE_FIELDS = [:project, :role, :environment, :bought_at]

    # Parse a YAML file and convert it to structured Ruby objects
    #
    # @param file_path [String] path to the YAML file
    # @param symbolize_names [Boolean] whether to symbolize keys in the YAML file
    # @param simple_fields [Array<Symbol>] fields that should remain as simple strings without service wrapping
    # @param dictionary_path [String, nil] path to the dictionary file (optional)
    # @param options [Hash] дополнительные опции
    # @option options [Logger] :logger логгер для вывода сообщений
    # @return [Hash] hash containing parsed services by type and domain
    def self.parse_file(file_path, symbolize_names: true, simple_fields: DEFAULT_SIMPLE_FIELDS, dictionary_path: nil, options: {})
      yaml = YAML.load_file(file_path, symbolize_names: symbolize_names)
      parse(yaml, simple_fields: simple_fields, dictionary_path: dictionary_path, options: options)
    end

    # Parse YAML data and convert it to structured Ruby objects
    #
    # @param yaml [Hash] YAML data as a hash
    # @param simple_fields [Array<Symbol>] fields that should remain as simple strings without service wrapping
    # @param dictionary_path [String, nil] path to the dictionary file (optional)
    # @param options [Hash] дополнительные опции
    # @option options [Logger] :logger логгер для вывода сообщений
    # @return [Hash] hash containing parsed services by type and domain
    def self.parse(yaml, simple_fields: DEFAULT_SIMPLE_FIELDS, dictionary_path: nil, options: {})
      result = {}
      logger = options[:logger]

      yaml.each do |domain_name, items|
        services = {}

        # Process each service type and its data
        items.each do |service_type, data|
          # Проверяем, является ли это поле "простым", имеет суффикс _at, или данные - экземпляр DateTime
          if simple_fields.include?(service_type) || service_type.to_s.end_with?('_at') || data.is_a?(DateTime)
            # Если данные уже DateTime, сохраняем как есть
            if data.is_a?(DateTime)
              services[service_type] = data
            # Для полей _at пробуем преобразовать строку в DateTime
            elsif service_type.to_s.end_with?('_at') && data.is_a?(String)
              begin
                services[service_type] = DateTime.parse(data)
              rescue Date::Error
                # Если не удалось преобразовать, оставляем как строку
                services[service_type] = data
              end
            else
              # Для обычных простых полей просто сохраняем значение
              services[service_type] = data
            end
          else
            # Для обычных полей создаем сервис
            service = ServiceFactory.create(data, service_type, dictionary_path, options)

            # Debug output
            if logger
              logger.debug "ServiceFactory.create for #{service_type}: #{service.inspect}"
            end

            if service
              services[service_type] ||= []
              services[service_type] << service
            elsif logger
              logger.debug "Service for #{service_type} is nil, field will be skipped"
            end
          end
        end

        # Create a structure with all the services
        result[domain_name] = services
      end

      result
    end

    # Преобразует YAML файл в хеш, где объекты Service преобразуются в хеши
    # @param file_path [String] путь к YAML файлу
    # @param options [Hash] дополнительные опции
    # @option options [Logger] :logger логгер для вывода сообщений
    # @return [Hash] хеш с сервисами
    def self.to_hash(file_path, options = {})
      data = parse_file(file_path, options: options)

      # Преобразуем объекты Service в хеши
      result = {}

      data.each do |domain, services|
        domain_key = domain.to_sym  # Преобразуем ключи доменов в символы
        result[domain_key] = {}

        services.each do |service_type, service_data|
          service_type_key = service_type.to_sym  # Преобразуем ключи типов сервисов в символы

          if service_data.is_a?(Array) && service_data.first.is_a?(Service)
            # Преобразуем массив сервисов в массив хешей
            result[domain_key][service_type_key] = service_data.map do |service|
              service_hash = {
                'service' => service.service,
                'url' => service.url
              }

              # Добавляем image_url если он есть
              if service.image_url
                service_hash['image_url'] = service.image_url
              end

              # Добавляем children только если они есть
              if service.children && !service.children.empty?
                service_hash['children'] = service.children.map do |child|
                  child_hash = {
                    'service' => child.service,
                    'url' => child.url
                  }

                  # Добавляем image_url для детей если он есть
                  if child.image_url
                    child_hash['image_url'] = child.image_url
                  end

                  # Добавляем properties для children если они есть
                  if child.properties && !child.properties.empty?
                    child_hash['properties'] = child.properties
                  end

                  # Добавляем value для children если оно есть
                  if child.value
                    child_hash['value'] = child.value
                  end

                  child_hash
                end
              end

              # Добавляем properties, если они есть
              if service.properties && !service.properties.empty?
                service_hash['properties'] = service.properties
              end

              service_hash
            end
          else
            # Сохраняем простые поля как есть
            result[domain_key][service_type_key] = service_data
          end
        end
      end

      result
    end

    # Преобразует данные из YAML файла в JSON формат
    #
    # @param file_path [String] путь к YAML файлу
    # @param options [Hash] дополнительные опции
    # @option options [Logger] :logger логгер для вывода сообщений
    # @return [String] форматированная JSON строка
    def self.to_json(file_path, options = {})
      JSON.pretty_generate(to_hash(file_path, options))
    end
  end
end