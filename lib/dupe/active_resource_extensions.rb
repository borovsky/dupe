ActiveResource::HttpMock.instance_eval do #:nodoc:
  def delete_mock(http_method, path) #:nodoc:
    responses.reject! {|r| r[0].path == path && r[0].method == http_method}
  end
end

module ActiveResource #:nodoc:
  class Connection #:nodoc:
    def get(path, headers = {}) #:nodoc:
      begin
        response = request(:get, path, build_request_headers(headers, :get, self.site.merge(path)))
      rescue ActiveResource::InvalidRequestError
        mocked_resp = Dupe.network.request(:get, path, headers)
        ActiveResource::HttpMock.respond_to(false) do |mock|
          mock.get(path, headers, mocked_resp.body, mocked_resp.code, mocked_resp.headers)
        end
        begin
          response = request(:get, path, build_request_headers(headers, :get, self.site.merge(path)))
        ensure
          ActiveResource::HttpMock.delete_mock(:get, path)
        end
      end

      if ActiveResource::VERSION::MAJOR == 3 && ActiveResource::VERSION::MINOR >= 1
        response
      else
        Dupe.format.decode(response.body)
      end
    end

    def post(path, body = '', headers = {}) #:nodoc:
      begin
        response = request(:post, path, body.to_s, build_request_headers(headers, :post, self.site.merge(path)))

      # if the request threw an exception
      rescue ActiveResource::InvalidRequestError
        unless body.blank?
          resource_hash = Dupe.format.decode(body)
        end
        mocked_response, new_path = Dupe.network.request(:post, path, headers, resource_hash)

        ActiveResource::HttpMock.respond_to(false) do |mock|
          mock.post(path, headers, mocked_response.body, mocked_response.code,
                    mocked_response.headers)
        end
        begin
          response = request(:post, path, body.to_s, build_request_headers(headers, :post, self.site.merge(path)))
        ensure
          ActiveResource::HttpMock.delete_mock(:post, path)
        end
      end
      response
    end

    def put(path, body = '', headers = {}) #:nodoc:
      begin
        response = request(:put, path, body.to_s, build_request_headers(headers, :put, self.site.merge(path)))

      # if the request threw an exception
      rescue ActiveResource::InvalidRequestError
        unless body.blank?
          resource_hash = Dupe.format.decode(body)
        end
        resource_hash.symbolize_keys! if resource_hash.kind_of?(Hash)

        mocked_response = Dupe.network.request(:put, path, headers, resource_hash)
        ActiveResource::HttpMock.respond_to(false) do |mock|
          mock.put(path, headers, mocked_response.body, mocked_response.code,
                   mocked_response.headers)
        end
        begin
          response = request(:put, path, body.to_s, build_request_headers(headers, :put, self.site.merge(path)))
        ensure
          ActiveResource::HttpMock.delete_mock(:put, path)
        end
      end
      response
    end

    def delete(path, headers = {})
      begin
        response = request(:delete, path, build_request_headers(headers, :delete, self.site.merge(path)))
      rescue ActiveResource::InvalidRequestError
        mocked_response = Dupe.network.request(:delete, path, headers)

        ActiveResource::HttpMock.respond_to(false) do |mock|
          mock.delete(path, headers, mocked_response.body, mocked_response.code,
                      mocked_response.headers)
        end
        begin
          response = request(:delete, path, build_request_headers(headers, :delete, self.site.merge(path)))
        ensure
          ActiveResource::HttpMock.delete_mock(:delete, path)
        end
      end
      response
    end
  end
end
