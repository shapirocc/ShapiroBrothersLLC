require 'rubygems'
require 'open-uri'
require 'hpricot'
require 'csv'

class Address
	attr_accessor :street, :city, :state, :zip, :mls, :price, :sqft, :lotsqft, :house_num, :house_dir, :cross_street_num, :cross_street_dir, :serial_num, :serial_num_latest, :tax_price

	def initialize(street, city, state, zip, mls)
		@street = street
		@city = city
		@state = state
		@zip = zip
		@mls = mls
		/^(\d+)\s+(\w+)\s+(\d+)\s+(\w+)/.match(@street)
		@house_num = $1
		@house_dir = $2
		@cross_street_num = $3
		@cross_street_dir = $4

	end
end


NUM_PAGES = 14

@url = "http://www.realtor.com/realestateandhomes-search/Provo_UT/beds-2/baths-1/price-50000-150000/listingtype-single-family-home#/pg-"
@response = ''

@properties = []
1.upto(NUM_PAGES) do |pageNum|
	# open-uri RDoc: http://stdlib.rubyonrails.org/libdoc/open-uri/rdoc/index.html
	#	open(@url + pageNum.to_s, "User-Agent" => "Ruby/#{RUBY_VERSION}",
	#	     "From" => "email@addr.com") { |f|
	#		     @response = f.read
	#	     }

	puts "Running phantom js"
	system("phantomjs.exe waitfor.js #{pageNum}")

	puts "Done running phantom js"

	@response = File.read("pg#{pageNum}.html")

	doc = Hpricot(@response)


	(doc/"//div").each do |div|
		if (div.attributes["class"] =~ /resultsItem  property dListData/)
			html = div.inner_html
			html.match(/([\w|:|\s]+)\s*,\s*(\w+)\s*,\s*(\w+)\s*(\d+)\s*\(MLS #:\s*(\d+)\)/)

			prop = Address.new($1, $2, $3, $4, $5)

			if (prop.street == nil || prop.cross_street_num == nil || prop.street =~ /Unit:/ || prop.cross_street_num.to_s == '')
				if (prop.street != nil)
					puts 'Skipping ' + prop.street
				else
					puts "Skipping blank property with " + html
				end
				next
			end

			prop.price = html.match(/\$\d+,\d+/)[0]
			prop.sqft = html.match(/\d*,?\d{3}\s+Sq Ft/)[0]
			#prop[:lotsqft] = html.match(/[\d|,]+\s+Sq Ft Lot/)[0]

			begin

				root_tax_url = "http://www.co.utah.ut.us/LandRecords/"
				search_tax_url = "AddressSearch.asp?av_house=#{prop.house_num}&av_dir=#{prop.house_dir}&av_street=#{prop.cross_street_num}+#{prop.cross_street_dir}&av_location=%25&av_valid=%25&Submit=Search"

				tax_url = root_tax_url + search_tax_url
				tax_response = ''


				# open-uri RDoc: http://stdlib.rubyonrails.org/libdoc/open-uri/rdoc/index.html
				open(tax_url, "User-Agent" => "Ruby/#{RUBY_VERSION}",
				     "From" => "email@addr.com") { |f|
					     # Save the response body
					     tax_response = f.read
				     }
				     prop.serial_num = /\d+:\d+:\d+/.match(tax_response)[0]

				     tax_url = root_tax_url + "SerialVersions.asp?av_serial=#{prop.serial_num}"
				     tax_response = ''

				     # open-uri RDoc: http://stdlib.rubyonrails.org/libdoc/open-uri/rdoc/index.html
				     open(tax_url, "User-Agent" => "Ruby/#{RUBY_VERSION}",
					  "From" => "email@addr.com") { |f|
						  # Save the response body
						  tax_response = f.read
					  }
					  /property.asp\?av_serial=(\d+)/.match(tax_response)
					  prop.serial_num_latest = $1


					  final_tax_url = "http://www.utahcountyonline.org/LandRecords/Property.asp?av_serial=#{prop.serial_num_latest}"
					  final_tax_response = ''


					  # open-uri RDoc: http://stdlib.rubyonrails.org/libdoc/open-uri/rdoc/index.html
					  open(final_tax_url, "User-Agent" => "Ruby/#{RUBY_VERSION}",
					       "From" => "email@addr.com") { |f|
						       # Save the response body
						       final_tax_response = f.read
					       }

					       tax_doc = Hpricot(final_tax_response)

					       (tax_doc/"//a").each do |a|
						       html = a.attributes['href']

						       if (html =~/PropertyValues.asp\?av_serial=\d+&av_year=2011/)
							       html = a.parent.parent.inner_html
							       values = html.scan(/\$\d+,\d{3}/)
							       prop.tax_price = values[values.length - 1]
						       end
					       end
					       puts "Address = #{prop.street} Price = #{prop.price} Tax = #{prop.tax_price} Sqft = #{prop.sqft}"

					       @properties << prop
			rescue
				puts "Failed to get address = #{prop.street}"

			end
		end
	end
end

CSV.open('result.csv', 'wb') do |csv|
	csv << ['Street', 'City', 'State', 'ZIP', 'MLS', 'Price', 'TaxPrice', 'SqFt']
	@properties.each do |prop|
		csv << [prop.street, prop.city, prop.state, prop.zip, prop.mls, prop.price, prop.tax_price, prop.sqft]
	end	
end

