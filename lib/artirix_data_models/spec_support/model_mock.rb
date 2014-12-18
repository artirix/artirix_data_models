def mock_partial_fields_mode(model_name, partial_mode_list = [:_timestamp, :slug, :name])
  path     = "/partial_fields/#{model_name}"
  response = partial_mode_list.to_json
  mock_gateway_get_response response: response, path: path
end

def mock_yacht_gateway(yacht)
  mock_partial_fields_mode :yacht, yacht.compact_data_hash.keys
  mock_gateway_get_response response: yacht.compact_data_hash.to_json, path: "/yachts/partial/#{yacht.primary_key}"
  mock_gateway_get_response response: yacht.compact_data_hash.to_json, path: "/yachts/full/#{yacht.primary_key}"
end

def mock_sale_listing_gateway(sale_listing)
  mock_partial_fields_mode :sale_listing, sale_listing.compact_data_hash.keys
  mock_gateway_get_response response: sale_listing.compact_data_hash.to_json, path: "/sale_listings/partial/#{sale_listing.primary_key}"
  mock_gateway_get_response response: sale_listing.compact_data_hash.to_json, path: "/sale_listings/full/#{sale_listing.primary_key}"
end

def mock_charter_listing_gateway(charter_listing)
  mock_partial_fields_mode :charter_listing, charter_listing.compact_data_hash.keys
  mock_gateway_get_response response: charter_listing.compact_data_hash.to_json, path: "/charter_listings/partial/#{charter_listing.primary_key}"
  mock_gateway_get_response response: charter_listing.compact_data_hash.to_json, path: "/charter_listings/full/#{charter_listing.primary_key}"
end

def mock_article_gateway(article)
  mock_partial_fields_mode :article, article.compact_data_hash.keys
  mock_gateway_get_response response: article.compact_data_hash.to_json, path: "/articles/partial/#{article.primary_key}"
  mock_gateway_get_response response: article.compact_data_hash.to_json, path: "/articles/full/#{article.primary_key}"

  mock_gateway_get_response path: "/articles/search?from=0&size=10&search_term=#{article.name.parameterize}", response: ArtirixDataModels::FakeResponseFactory.response_single_model(article).to_json
end

def mock_editorial_hub_gateway(editorial_hub)
  mock_partial_fields_mode :editorial_hub, editorial_hub.compact_data_hash.keys
  mock_gateway_get_response response: editorial_hub.compact_data_hash.to_json, path: "/editorial_hubs/partial/#{editorial_hub.primary_key}"
  mock_gateway_get_response response: editorial_hub.compact_data_hash.to_json, path: "/editorial_hubs/full/#{editorial_hub.primary_key}"
end



