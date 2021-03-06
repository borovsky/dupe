class Dupe
  class Network #:nodoc:
    class Log #:nodoc:
      include RestValidation     #:nodoc:
      attr_reader :requests    #:nodoc:
      
      class Request     #:nodoc:
        attr_reader :verb, :path, :headers, :response_body
        
        def initialize(verb, path, headers, response_body)
          @verb, @path, @headers, @response_body = verb, path, headers, response_body
        end
        
        def pretty_print
          "Request: #{@verb.to_s.upcase} #{@path} #{@headers}\n" +
          "Response:\n" + @response_body.indent
        end
      end
      
      def initialize     #:nodoc:
        @requests = []
      end
      
      def add_request(verb, path, headers, response_body='')     #:nodoc:
        validate_request_type verb
        @requests << Request.new(verb, path, headers, response_body)
      end
      
      def pretty_print
        "Logged Requests:\n" + requests.map {|r| r.pretty_print.indent }.join("\n\n") + "\n\n"
      end
      
      def reset #:nodoc:
        @requests = []
      end
    end
  end
end
