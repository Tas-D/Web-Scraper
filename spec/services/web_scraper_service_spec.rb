# spec/services/web_scraper_service_spec.rb
require 'rails_helper'
require 'selenium-webdriver'
require 'nokogiri'

RSpec.describe WebScraperService, type: :service do
  let(:valid_params) { '{"n": 1, "filters": {"industry": "tech"}}' }
  let(:invalid_params) { '{"n": 0, "filters": {"industry": "tech"}}' }
  let(:invalid_params1) { '{"n": 1, "filters": {"industry": "tech"' }
  let(:parsed_response) do
    {
      'Company Name' => {
        Location: 'New York',
        Desc: 'A leading tech company',
        Batch: '2024',
        Website: 'https://example.com',
        Founder: 'John Doe',
        Linkedin: 'https://linkedin.com/johndoe'
      }
    }
  end
  let(:service) { described_class.new(valid_params) }
  let(:service1) { described_class.new(invalid_params) }
  let(:service2) { described_class.new(invalid_params1) }
  let(:driver) { instance_double(Selenium::WebDriver::Driver) }
  let(:element) { instance_double(Selenium::WebDriver::Element) }
  let(:response) { {} }


  before do
    allow(SeleniumDriver).to receive(:setup).and_return(driver)
    allow(driver).to receive(:page_source).and_return('<html></html>')
    allow(SeleniumDriver).to receive(:fetch_data_from_driver).and_return([element])
    allow(driver).to receive(:execute_script).with('return document.body.scrollHeight').and_return(1000, 2000, 2000)
    allow(driver).to receive(:execute_script).with('window.scrollTo(0, document.body.scrollHeight)')
    allow(driver).to receive(:quit)
  end

  describe '#initialize' do
    context 'with valid params' do
      it 'initializes without error' do
        expect { service }.not_to raise_error
      end
    end

    context 'with invalid params' do
      it 'raises an error with invalid n value' do
        expect(service1.response[:error]).to eq("Please enter value of n greater than 0")
      end
      it 'raises an error with invalid json params' do
        expect(service2.response[:error]).to eq("Please enter valid JSON format")
      end
    end
  end
  
  describe '#call' do
    let(:first_page_html) do
      <<-HTML
        <html>
          <body>
            <a class="_company_86jzd_338" href="/companies/airbnb">
              <span class="_coName_86jzd_453">Airbnb</span>
              <span class="_coLocation_86jzd_469">San Francisco, CA</span>
              <span class="_coDescription_86jzd_478">Vacation rentals platform</span>
              <span class="pill _pill_86jzd_33">S09</span>
            </a>
          </body>
        </html>
      HTML
    end

    let(:second_page_html) do
      <<-HTML
        <html>
          <body>
            <h1 class="font-extralight">Airbnb Details</h1>
            <div class="text-linkColor">https://www.airbnb.com</div>
            <div class="leading-snug">
              <div class="font-bold">Brian Chesky</div>
              <a class="bg-image-linkedin" href="https://www.linkedin.com/in/brianchesky"></a>
            </div>
          </body>
        </html>
      HTML
    end

    let(:first_page_doc) { Nokogiri::HTML(first_page_html) }
    let(:second_page_doc) { Nokogiri::HTML(second_page_html) }

    before do
      allow(driver).to receive(:page_source).and_return(first_page_html, second_page_html)
      allow(SeleniumDriver).to receive(:fetch_data_from_driver).with(anything, 'a._company_86jzd_338', driver, anything).and_return(nil)
      allow(SeleniumDriver).to receive(:fetch_data_from_driver).with('airbnb', 'h1.font-extralight', driver, anything).and_return(nil)
      allow(Nokogiri::HTML).to receive(:parse).with(first_page_html).and_return(first_page_doc)
      allow(Nokogiri::HTML).to receive(:parse).with(second_page_html).and_return(second_page_doc)
    end
    it 'fetches data from both pages and returns a complete response' do
      result = service.call

      expect(result).to include('Airbnb')
      expect(result['Airbnb']).to include(
        Location: 'San Francisco, CA',
        Desc: 'Vacation rentals platform',
        Batch: 'S09',
        Website: 'https://www.airbnb.com',
        Founder: 'Brian Chesky',
        Linkedin: 'https://www.linkedin.com/in/brianchesky'
      )
    end
  end

  describe '#generate_csv' do
    it 'generates a CSV string from parsed data' do
      csv = service.generate_csv(parsed_response)
      expect(csv).to include('Company Name,Location,Description,Batch,Website,Founder,LinkedIn')
    end
  end

  describe '#scroll_page' do
  it 'scrolls the page to the bottom' do
    expect(driver).to receive(:execute_script).exactly(5).times

    service.send(:scroll_page, driver)
  end
  end
end
