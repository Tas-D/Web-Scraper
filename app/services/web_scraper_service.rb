# frozen_string_literal: true

# Service to fetch data from third party api
class WebScraperService
  require 'nokogiri'
  require 'selenium-webdriver'
  require 'csv'

  Selenium::WebDriver::Chrome::Service.driver_path = '/usr/bin/chromedriver'

  attr_accessor :query, :no_of_companies

  def initialize(params)
    @no_of_companies = params[0]
    @query = params[1].to_query unless params[1].nil?
  end

  def call
    response = {}

    options = Selenium::WebDriver::Chrome::Options.new
    options.add_argument('--headless')
    driver = Selenium::WebDriver.for(:chrome, options:)

    fetch_data_from_driver("https://www.ycombinator.com/companies?#{query}", 'a._company_86jzd_338', driver, response)
    return response unless response[:error].nil? 
    scroll_page(driver)

    doc = Nokogiri::HTML(driver.page_source)

    fetch_data_from_first_page(doc, response, driver)

    driver.quit
    response
  end

  def generate_csv(data)
    CSV.generate do |csv|
      csv << ['Company Name', 'Location', 'Description', 'Batch', 'Website', 'Founder', 'LinkedIn']
      data.each do |company, details|
        csv << [company, details[:Location], details[:Desc],
                details[:Batch], details[:Website],
                details[:Founder], details[:Linkedin]]
      end
    end
  end

  private

  def fetch_data_from_driver(url, element, driver, response)
    driver.get(url)

    # Wait for the content to load
    wait = Selenium::WebDriver::Wait.new(timeout: 30)
    begin
      wait.until { driver.find_element(css: element) }
    rescue Exception => e
      return response[:error] = e.message 
    end
  end

  def fetch_data_from_first_page(doc, response, driver)
    doc.css('a._company_86jzd_338').each do |resp|
      break if response.size >= no_of_companies || response.key?('span._coName_86jzd_453')

      fetch_company_info(resp, response, driver)
    end
  end

  def fetch_company_info(resp, response, driver)
    company_name = resp.css('span._coName_86jzd_453').first.content
    response[company_name] = {
      Location: resp.css('span._coLocation_86jzd_469').first.content,
      Desc: resp.css('span._coDescription_86jzd_478').first.content,
      Batch: resp.css('span.pill._pill_86jzd_33').first.text
    }
    fetch_data_from_second_page(response, driver, resp, company_name)
  end

  def fetch_data_from_second_page(response, driver, resp, company_name)
    fetch_data_from_driver("https://www.ycombinator.com#{resp.attribute_nodes[1].value}",
                           'h1.font-extralight', driver, response)
    doc1 = Nokogiri::HTML(driver.page_source)

    response[company_name].tap do |company_data|
      company_data[:Website] = doc1.css('div.text-linkColor').first.content
      fetch_founding_members(doc1, company_data)
    end
  end

  def fetch_founding_members(doc, company_data)
    founding_members = []
    linkedin_urls = []
    founding_members, linkedin_urls = founding_member_details(doc, founding_members, linkedin_urls)
    company_data[:Founder] = founding_members.join(', ')
    company_data[:Linkedin] = linkedin_urls.join(', ')
  end

  def founding_member_details(doc, founding_members, linkedin_urls)
    doc.css('div.leading-snug').each do |member|
      founding_members << member&.css('div.font-bold')&.text
      linkedin_urls << member&.css('a.bg-image-linkedin')&.first&.attribute_nodes&.first&.value
    end
    [founding_members, linkedin_urls]
  end

  def scroll_page(driver)
    last_height = driver.execute_script('return document.body.scrollHeight')
    loop do
      driver.execute_script('window.scrollTo(0, document.body.scrollHeight);')
      sleep 2
      new_height = driver.execute_script('return document.body.scrollHeight')
      break if new_height == last_height

      last_height = new_height
    end
  end
end
