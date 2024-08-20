class CompaniesController < ApplicationController
	def search_data
		return if params[:search_input].nil?
		web_scraper = WebScraperService.new(permit_params[:search_input])
		return render plain: web_scraper.response[:error] if web_scraper.response[:error].present?
		resp = web_scraper.call
		if resp.empty? || resp[:error].present?
			render plain: resp[:error], status: :not_found
		else
			respond_to do |format|
				format.csv {
					csv_data = web_scraper.generate_csv(resp)
					send_data csv_data, filename: "companies_data.csv", type: "text/csv", disposition: "attachment"
				}
			end
		end
	end

	private
	def permit_params
		params.permit(:search_input)
	end
end