require 'selenium-webdriver'
require 'webdrivers'

module SeleniumDriver
    
    BASE_URL = "https://www.ycombinator.com/companies".freeze
    def self.setup
        options = Selenium::WebDriver::Chrome::Options.new
        options.add_argument('--headless')
        driver = Selenium::WebDriver.for(:chrome, options:)
        driver
    end

    def self.fetch_data_from_driver(query, element, driver, response)
        driver.get("#{BASE_URL}#{query}")
    
        # Wait for the content to load
        wait = Selenium::WebDriver::Wait.new(timeout: 30)
        begin
          wait.until { driver.find_element(css: element) }
        rescue Exception => e
          return response[:error] = "No data found" 
        end
      end    
end