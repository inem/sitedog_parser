require_relative 'test_helper'

class MultipleSitesTest < Minitest::Test
  def setup
    # Путь к тестовому файлу multiple.yaml
    @fixture_path = File.expand_path('../fixtures/multiple.yaml', __FILE__)

    # Загружаем YAML данные напрямую
    yaml_data = YAML.load_file(@fixture_path, symbolize_names: true)

    # Проверяем структуру
    assert yaml_data[:sites].is_a?(Hash), "Expected YAML with 'sites' key containing domain data"

    # Используем наш парсер для обработки данных
    @parsed_data = SitedogParser::Parser.parse(yaml_data[:sites])
  end

  def test_domains_count
    # Проверяем, что все домены были обработаны
    assert_equal 15, @parsed_data.keys.size

    # Проверяем наличие конкретных доменов
    domain_keys = @parsed_data.keys.map(&:to_s)
    assert_includes domain_keys, 'rbbr.io'
    assert_includes domain_keys, 'inem.at'
    assert_includes domain_keys, 'inem.at/jobs'
    assert_includes domain_keys, 'railshurts.com'
    assert_includes domain_keys, 'nemytchenko.ru'
    assert_includes domain_keys, 'app.setyl.com'
    assert_includes domain_keys, 'sitedock.my'
  end

  def test_service_types
    # Проверяем, что все типы сервисов были обнаружены
    all_service_types = []
    @parsed_data.each do |_domain, services|
      all_service_types.concat(services.keys)
    end
    unique_service_types = all_service_types.uniq

    expected_types = [:mail, :registrar, :dns, :hosting, :cdn, :managed_by, :repo,
                      :deploy, :monitoring, :ci, :environment, :project, :role, :bought_at]

    expected_types.each do |type|
      assert_includes unique_service_types, type, "Expected service type #{type} to be detected"
    end
  end

  def test_hosting_providers
    # Проверяем, что хостинг-провайдеры правильно определены
    hosting_services = SitedogParser::Parser.get_services_by_type(@parsed_data, :hosting)
    providers = hosting_services.map(&:service).uniq.sort

    assert_includes providers, 's3'
    assert_includes providers, 'carrd'
    assert_includes providers, 'vercel'
    assert_includes providers, 'tumblr'
    assert_includes providers, 'replit'
    assert_includes providers, 'hetzner'
    assert_includes providers, 'aws'
    assert_includes providers, 'medium'
  end

  def test_rbbr_io_services
    # Проверяем конкретный домен
    domain_services = get_domain_services(@parsed_data, 'rbbr.io')

    assert_equal 'gsuite', domain_services[:mail].first.service
    assert_equal 'aws', domain_services[:registrar].first.service
    assert_equal 'aws', domain_services[:dns].first.service
    assert_equal 's3', domain_services[:hosting].first.service
  end

  def test_complex_domain
    # Проверяем домен с большим количеством сервисов
    domain_services = get_domain_services(@parsed_data, 'painlessrails.com')

    assert_equal 7, domain_services.keys.size

    assert_equal 'aws', domain_services[:registrar].first.service
    assert_equal 'https://gitlab.com/nemytchenko/projects/painless-rails/painless-rails-group/painless-rails-site',
                 domain_services[:repo].first.url
    assert_equal 'ansible', domain_services[:deploy].first.service
    assert_equal 's3', domain_services[:hosting].first.service
    assert_equal 'cloudlfare', domain_services[:cdn].first.service
    assert_equal 'zoho', domain_services[:mail].first.service
    assert_equal 'terraform', domain_services[:managed_by].first.service
  end

  def test_bought_at_value
    # Проверяем обработку дат и других специальных значений
    domain_services = get_domain_services(@parsed_data, 'sitedock.my')

    assert_equal 'namecheap', domain_services[:registrar].first.service
    assert_equal 'Apr 1, 2025 01:27:35 AM', domain_services[:bought_at].first.service
  end

  def test_service_counts
    # Статистика по типам сервисов
    service_stats = {}
    [:hosting, :registrar, :dns, :mail, :managed_by].each do |type|
      services = SitedogParser::Parser.get_services_by_type(@parsed_data, type)
      service_stats[type] = services.size
    end

    assert_equal 14, service_stats[:hosting], "Expected 15 hosting services"
    assert_equal 9, service_stats[:registrar], "Expected 9 registrar services"
    assert_equal 4, service_stats[:dns], "Expected 6 DNS services"
    assert_equal 5, service_stats[:mail], "Expected 5 mail services"
    assert_equal 4, service_stats[:managed_by], "Expected 4 managed_by services"
  end

  # Вспомогательная функция для получения сервисов домена
  def get_domain_services(result, domain_name)
    # Try both symbols and strings for domain access
    if result.key?(domain_name.to_sym)
      result[domain_name.to_sym]
    else
      result[domain_name]
    end
  end
end