require 'rails_helper'

RSpec.describe CompaniesController, type: :controller do
  describe '#search_data' do
    let(:valid_params) { { search_input: '{"n": 1, "filters": {"industry": "tech"}}' } }
    let(:invalid_params) { { search_input: '{"n": 0, "filters": {"industry": "tech"}}' } }
    let(:web_scraper_service) { instance_double(WebScraperService) }

    before do
      allow(WebScraperService).to receive(:new).and_return(web_scraper_service)
    end

    context 'when search_input is nil' do
      it 'returns without performing any action' do
        get :search_data
        expect(response).to have_http_status(:success)
      end
    end

    context 'when WebScraperService returns an error' do
      it 'renders the error message' do
        allow(web_scraper_service).to receive(:response).and_return({ error: 'Please enter value of n greater than 0' })
        
        get :search_data, params: invalid_params
        
        expect(response.body).to eq('Please enter value of n greater than 0')
      end
    end

    context 'when WebScraperService returns empty response' do
      it 'renders not found status' do
        allow(web_scraper_service).to receive(:response).and_return({})
        allow(web_scraper_service).to receive(:call).and_return({})
        
        get :search_data, params: valid_params
        
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when WebScraperService returns valid data' do
      let(:response_data) { { 'Company' => { 'Location' => 'New York' } } }
      let(:csv_data) { "Company,Location\nCompany,New York\n" }

      before do
        allow(web_scraper_service).to receive(:response).and_return(response_data)
        allow(web_scraper_service).to receive(:call).and_return(response_data)
        allow(web_scraper_service).to receive(:generate_csv).and_return(csv_data)
      end

      it 'generates and sends CSV data' do
        get :search_data, params: valid_params, format: :csv
        
        expect(response.header['Content-Type']).to include('text/csv')
        expect(response.header['Content-Disposition']).to include('attachment; filename="companies_data.csv"')
        expect(response.body).to eq(csv_data)
      end
    end
  end
end
