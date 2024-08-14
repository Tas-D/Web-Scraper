class CompaniesController < ApplicationController
	require 'csv'
	def search_data
		return if params[:search_input].nil?
		web_scraper = WebScraperService.new(search_params(permit_params))
		@resp = web_scraper.call
		if @resp.empty? || @resp[:error].present?
			render plain: "No data found", status: :not_found
		else
			respond_to do |format|
				format.csv {
					csv_data = web_scraper.generate_csv(@resp)
					send_data csv_data, filename: "companies_data.csv", type: "text/csv", disposition: "attachment"
				}
			end
		end
	end

	private
	def permit_params
		params.permit(:search_input)
	end

	def search_params(params)
		search_data = JSON.parse(params[:search_input])
		n = search_data["n"]
		filters = search_data["filters"]
		
		return n, filters
	end
end