# frozen_string_literal: true

# Service to fetch data from third party api
class WebScraperService

  Selenium::WebDriver::Chrome::Service.driver_path = '/usr/bin/chromedriver'

  require 'nokogiri'
  require 'selenium_driver'
  require 'csv'

  attr_accessor :query, :no_of_companies, :response
  Driver = SeleniumDriver

  def initialize(params)
    @response = {}
    search_params(params)
  end

  def call
    driver = Driver.setup
    Driver.fetch_data_from_driver("?#{query}", 'a._company_86jzd_338', driver, response)
    return response unless response[:error].nil? 
    scroll_page(driver)
    doc = Nokogiri::HTML(driver.page_source)

    fetch_data_from_first_page(doc, driver)

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

  def search_params(params)
    search_data = JSON.parse(params)
    validate_search_data(search_data)
    rescue JSON::ParserError
      response[:error] = "Please enter valid JSON format" 
    rescue ArgumentError => e
      response[:error] = e.message
    ensure
      return response[:error] if response[:error]
      @no_of_companies = search_data["n"]
      @filters = search_data["filters"]&.to_query
  end

  def validate_search_data(data)
    raise ArgumentError, "Please enter value of n greater than 0" if data["n"] <= 0 || data["n"].nil?
  end

  def fetch_data_from_first_page(doc, driver)
    doc.css('a._company_86jzd_338').each do |resp|
      break if response.size >= no_of_companies || response.key?('span._coName_86jzd_453')

      fetch_company_info(resp, driver)
    end
  end

  def fetch_company_info(resp, driver)
    company_name = resp.css('span._coName_86jzd_453').first.content
    response[company_name] = {
      Location: resp.css('span._coLocation_86jzd_469').first.content,
      Desc: resp.css('span._coDescription_86jzd_478').first.content,
      Batch: resp.css('span.pill._pill_86jzd_33').first.text
    }
    fetch_data_from_second_page(driver, resp, company_name)
  end

  def fetch_data_from_second_page(driver, resp, company_name)
    Driver.fetch_data_from_driver(resp.attribute_nodes[1].value.remove("/companies"),
                           'h1.font-extralight', driver, response)
    doc1 = Nokogiri::HTML(driver.page_source)

    response[company_name][:Website] = doc1.css('div.text-linkColor').first.content
    fetch_founding_members(doc1, company_name)
  end

  def fetch_founding_members(doc, company_name)
    founding_members = []
    linkedin_urls = []
    founding_members, linkedin_urls = founding_member_details(doc, founding_members, linkedin_urls)
    response[company_name][:Founder] = founding_members.join(', ')
    response[company_name][:Linkedin] = linkedin_urls.join(', ')
  end

  def founding_member_details(doc, founding_members, linkedin_urls)
    doc.css('div.leading-snug').each do |member|
      founding_members << member&.css('div.font-bold')&.text
      linkedin_urls << member&.css('a.bg-image-linkedin')&.first['href']
    end
    [founding_members, linkedin_urls]
  end

  def scroll_page(driver)
    last_height = driver.execute_script('return document.body.scrollHeight')
    loop do
      driver.execute_script('window.scrollTo(0, document.body.scrollHeight)')
      sleep 2
      new_height = driver.execute_script('return document.body.scrollHeight')
      break if new_height == last_height

      last_height = new_height
    end
  end
end
