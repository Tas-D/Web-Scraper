require 'rails_helper'
require 'selenium_driver'
require 'selenium-webdriver'
require 'webdrivers'

RSpec.describe SeleniumDriver do

  BASE_URL = "https://www.ycombinator.com/companies".freeze
  Selenium::WebDriver::Chrome::Service.driver_path = '/usr/bin/chromedriver'

  let(:driver) { instance_double(Selenium::WebDriver::Driver) }
  let(:wait) { instance_double(Selenium::WebDriver::Wait) }
  let(:element_found) { instance_double(Selenium::WebDriver::Element) }

  before do
    allow(Selenium::WebDriver::Chrome::Options).to receive(:new).and_return(double('options', add_argument: nil))
    allow(Selenium::WebDriver).to receive(:for).with(:chrome, options: anything).and_return(driver)
    allow(Selenium::WebDriver::Wait).to receive(:new).with(timeout: 30).and_return(wait)
  end

  describe '.setup' do
    it 'sets up the Chrome driver with headless option' do
      expect(SeleniumDriver.setup).to eq(driver)
    end
  end

  describe '.fetch_data_from_driver' do
    let(:query) { '?jobs' }
    let(:element) { 'job-listing' }
    let(:response) { {} }
  
    before do
      allow(Selenium::WebDriver::Wait).to receive(:new).with(timeout: 30).and_return(wait)
      allow(driver).to receive(:get)
    end
  
    context 'when the element is found' do
      it 'does not set an error in the response' do
        allow(wait).to receive(:until).and_yield
        allow(driver).to receive(:find_element).with(css: element)
  
        SeleniumDriver.fetch_data_from_driver(query, element, driver, response)
  
        expect(driver).to have_received(:get).with("#{SeleniumDriver::BASE_URL}#{query}")
        expect(response[:error]).to be_nil
      end
    end
  
    context 'when the element is not found' do
      it 'sets an error message in the response' do
        allow(wait).to receive(:until).and_raise(Selenium::WebDriver::Error::TimeoutError.new)
  
        SeleniumDriver.fetch_data_from_driver(query, element, driver, response)
  
        expect(driver).to have_received(:get).with("#{SeleniumDriver::BASE_URL}#{query}")
        expect(response[:error]).to eq("No data found")
      end
    end
  end
end