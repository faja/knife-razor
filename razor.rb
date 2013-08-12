module Razor
  class << self

    # retur uuid of razor object or nil if object doesn't exist
    def get_object_uuid(razor_api,slice,resource,value)
      uri = URI "http://#{razor_api}/razor/api/#{slice}?#{resource}=#{value}"
      res = Net::HTTP.get(uri)
      response_hash = JSON.parse(res)
      return nil if response_hash['response'].empty?
      return response_hash["response"].first["@uuid"]
    end

    # return uuid of tag's matcher or nil if matcher doesn't exist
    def get_matcher_uuid(razor_api,tag_uuid)
      uri = URI "http://#{razor_api}/razor/api/tag/#{tag_uuid}"
      res = Net::HTTP.get(uri)
      response_hash = JSON.parse(res)
      return nil if response_hash['response'].empty? or response_hash['response'].first['@tag_matchers'].empty?
      return response_hash["response"].first["@tag_matchers"].first['@uuid']
    end

    # create razor object and return uuid
    def create_object(razor_api,slice,json_hash)
      uri = URI "http://#{razor_api}/razor/api/#{slice}"
      json_string = JSON.generate(json_hash)
      res = Net::HTTP.post_form(uri, 'json_hash' => json_string)
      response_hash = JSON.parse(res.body)
      unless res.class == Net::HTTPCreated
        ui.fatal "Error creating new #{ui.color(slice,:red)}"
        exit 1
      end
      uuid = response_hash["response"].first["@uuid"]
      return uuid
    end

    # update razor object
    def update_object(razor_api,sliceuuid,json_hash)
      json_string = JSON.generate(json_hash)
      http = Net::HTTP.new(razor_api.split(':')[0],razor_api.split(':')[1])
      request = Net::HTTP::Put.new("/razor/api/#{sliceuuid}")
      request.set_form_data({"json_hash" => json_string})
      res = http.request(request)
      response_hash = JSON.parse(res.body)
      unless res.class == Net::HTTPAccepted
        ui.fatal "Error updating #{sliceuuid}"
        exit 1
      end
    end

  end
end
