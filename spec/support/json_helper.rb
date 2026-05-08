module JsonHelper
  def json_response
    JSON.parse(response.body, symbolize_names: true)
  end

  def json_data
    json_response[:data]
  end

  def json_errors
    json_response[:errors] || json_response[:error]
  end

  def json_message
    json_response[:message]
  end
end

