class Dupe
  class Network #:nodoc:
    class Mock #:nodoc:
      class ResourceNotFoundError < StandardError; end

      attr_reader :url_pattern
      attr_reader :response

      def initialize(url_pattern, response_proc=nil)
        raise(
              ArgumentError,
              "The URL pattern parameter must be a type of regular expression."
              ) unless url_pattern.kind_of?(Regexp)

        @response = response_proc || proc {}
        @url_pattern = url_pattern
      end

      def match?(url)
        url_pattern =~ url ? true : false
      end

      def mocked_response(url, headers, body = nil)
        raise(
              StandardError,
              "Tried to mock a response to a non-matched url! This should never occur. My pattern: #{@url_pattern}. Url: #{url}"
              ) unless match?(url)

        grouped_results = url_pattern.match(url)[1..-1]
        grouped_results << body if body
        grouped_results << headers

        process_response(url) { @response.call *grouped_results }
      end

      def process_response(resp, url)
        raise NotImplementedError, "When you extend Dupe::Network::Mock, you must implement the #process_response instance method."
      end
    end
  end
end

class Dupe
  class Network
    class GetMock < Mock #:nodoc:
      def process_response(url)
        resp = yield
        case resp
        when NilClass
          raise ResourceNotFoundError, "Failed with 404: the request '#{url}' returned nil."
        when Dupe::Database::Record
          resp = Dupe.format.encode( resp.make_safe, :root => resp.__model__.name.to_s )
        when Array
          if resp.empty?
            resp = Dupe.format.encode( [], :root => 'results' )
          else
            resp = Dupe.format.encode(
                                      resp.map {|r| HashPruner.prune(r)},
                                      :root => resp.first.__model__.name.to_s.pluralize )
          end
        end
        resp = ActiveResource::Response.new(resp, 200, {}) if resp.is_a? String

        Dupe.network.log.add_request :get, url, resp
        resp
      end
    end
  end
end

class Dupe
  class Network
    class PostMock < Mock #:nodoc:

      # returns a tuple representing the encoded form of the processed entity, plus the url to the entity.
      def process_response(url)
        resp = yield

        case resp
        when NilClass
          raise StandardError, "Failed with 500: the request '#{url}' returned nil."

        when Dupe::Database::Record
          new_path = "/#{resp.__model__.name.to_s.pluralize}/#{resp.id}.#{Dupe.format.extension}"
          resp = Dupe.format.encode( resp.make_safe, :root => resp.__model__.name.to_s)
          resp = ActiveResource::Response.new(resp, 201, {"Location" => new_path})
          Dupe.network.log.add_request :post, url, resp
          return resp

        when ActiveResource::Response then resp
        else
          raise StandardError, "Unknown PostMock Response. Your Post intercept mocks must return a Duped resource object or nil"
        end
      rescue Dupe::UnprocessableEntity => e
        response_body =
          case Dupe.format
          when ActiveResource::Formats::JsonFormat
            Dupe.format.encode( {errors: e.errors}, :root => 'errors')
          else
            Dupe.format.encode( {error: e.errors}, :root => 'errors')
          end
        return ActiveResource::Response.new(response_body, 422,
                                            {"Content-Type" => Dupe.format.mime_type})
      end
    end
  end
end

class Dupe
  class Network
    class PutMock < Mock #:nodoc:

      # returns a tuple representing the encoded form of the processed entity, plus the url to the entity.
      def process_response(url)
        resp = yield
        case resp

        when NilClass
          raise StandardError, "Failed with 500: the request '#{url}' returned nil."

        when Dupe::Database::Record
          resp = ActiveResource::Response.new(nil, 204, {"Location" => url})
          Dupe.network.log.add_request :put, url, resp
          return resp
        when ActiveResource::Response then return resp

        else
          raise StandardError, "Unknown PutMock Response. Your Post intercept mocks must return a Duped resource object or nil"
        end
      rescue Dupe::UnprocessableEntity => e
        mocked_response =
          resp_body = case Dupe.format
                      when ActiveResource::Formats::JsonFormat
                        Dupe.format.encode( {errors: e.errors}, :root => 'errors')
                      else
                        Dupe.format.encode( {error: e.errors}, :root => 'errors')
                      end
        ActiveResource::Response.new(resp_body, 422, {"Content-Type" => Dupe.format.mime_type})
      end
    end
  end
end

class Dupe
  class Network
    class DeleteMock < Mock #:nodoc:
      # logs the request
      def process_response(url)
        resp = yield
        resp = case resp
               when ActiveResource::Response then resp
               else
                 ActiveResource::Response.new(nil, 200, {})
               end
        Dupe.network.log.add_request :delete, url, resp
        resp
      end
    end
  end
end
