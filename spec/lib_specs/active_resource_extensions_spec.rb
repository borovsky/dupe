require 'spec_helper'

shared_examples "requests processing" do
    describe "#get" do
      before do
        @book = Dupe.create :book, :title => 'Rooby', :label => 'rooby'
      end

      it "should pass a request off to the Dupe network if the original request failed" do
      Dupe.network.should_receive(:request).with(:get, "/books.#{@format}", {"X-Test" => "42"}).once.
        and_return(ActiveResource::Response.new(Dupe.find(:books).send("to_#{@format}", :root => 'books')))
        books = Book.find(:all)
      end

      it "should parse the #{@format} and turn the result into active resource objects" do
        books = Book.find(:all)
        books.length.should == 1
        books.first.id.should == 1
        books.first.title.should == 'Rooby'
        books.first.label.should == 'rooby'
      end

      it "passes headers to GET mock" do
        Get %r{/books\.#{@format}} do |headers|
          headers["X-Test"].should == "42"
          Dupe.find :books
        end
        Book.find(:all)
      end
    end

    describe "#post" do
      before do
        @book = Dupe.create :book, :label => 'rooby', :title => 'Rooby'
        @book.delete(:id)
      end

      it "should pass a request off to the Dupe network if the original request failed" do
        Dupe.network.should_receive(:request).
          with(:post, "/books.#{@format}", {"X-Test" => "42"},
               Hash.from_json(@book.to_json) ).once.
          and_return(build_response("", 201))
        book = Book.create({:label => 'rooby', :title => 'Rooby'})
      end

      it "should parse the xml and turn the result into active resource objects" do
        book = Book.create({:label => 'rooby', :title => 'Rooby'})
        book.id.should == 2
        book.title.should == 'Rooby'
        book.label.should == 'rooby'
      end

      it "should make ActiveResource throw an unprocessable entity exception if our Post mock throws a Dupe::UnprocessableEntity exception" do
        Post %r{/books\.#{@format}} do |post_data|
          raise Dupe::UnprocessableEntity.new(:title => "must be present.") if post_data["title"].blank?
          Dupe.create :book, post_data
        end

        b = Book.create(title: "")
        b.new?.should be_true
        b.errors.should_not be_empty
        b.errors[:title].should_not be_empty
        b = Book.create(:title => "hello")
        b.new?.should be_false
        b.errors.should be_empty
      end

      it "passes headers to mock" do
        Post %r{/books\.xml} do |post_data, headers|
          headers["X-Test"].should == "42"
          Dupe.create :book, post_data
        end
        Book.create(title: "test")
      end

      it "should handle request with blank body" do
        class SubscribableBook < ActiveResource::Base
          self.site = 'http://www.example.com'
          self.format = :xml

          def self.send_update_emails
            post(:send_update_emails)
          end
        end

        Post %r{/subscribable_books/send_update_emails\.xml} do |post_data|
          Dupe.create :email, post_data
        end

        response = SubscribableBook.send_update_emails
        response.code.should == 201
      end
    end

    describe "#put" do
      before do
        @book = Dupe.create :book, :label => 'rooby', :title => 'Rooby'
        @ar_book = Book.find(1)
      end

      it "should pass a request off to the Dupe network if the original request failed" do
        Dupe.network.should_receive(:request).
          with(:put, "/books/1.#{@format}", {"X-Test" => "42"},
               Hash.from_xml(@book.merge(:title => "Rails!").
                             to_xml(:root => 'book'))["book"].
               symbolize_keys!).once.and_return(build_response(nil, 204,
                                                               "Location" => "/books/1.#{@format}"))
        @ar_book.title = 'Rails!'
        @ar_book.save
      end

      context "put methods that return HTTP 204" do
        before(:each) do
          req_format = @format.to_sym
          class ExpirableBook < ActiveResource::Base
            self.site   = 'http://www.example.com'
            attr_accessor :state

            def expire_copyrights!
              put(:expire)
            end
          end
          ExpirableBook.class_eval do
            self.format = req_format
          end

          Put %r{/expirable_books/(\d)+/expire.#{@format}} do |id, body|
            Dupe.find(:expirable_book) { |eb| eb.id == id.to_i }.tap { |book|
              book.state = 'expired'
            }
          end

          @e = Dupe.create :expirable_book, :title => 'Impermanence', :state => 'active'
        end

        it "should handle no-content responses" do
          response = ExpirableBook.find(@e.id).expire_copyrights!
          response.body.should be_blank
          response.code.to_s.should == "204"
        end
      end

      it "should parse the xml and turn the result into active resource objects" do
        @book.title.should == "Rooby"
        @ar_book.title = "Rails!"
        @ar_book.save
        @ar_book.new?.should == false
        @ar_book.valid?.should == true
        @ar_book.id.should == 1
        @ar_book.label.should == "rooby"
        @book.title.should == "Rails!"
        @book.id.should == 1
        @book.label.should == 'rooby'
      end

      it "should make ActiveResource throw an unprocessable entity exception if our Put mock throws a Dupe::UnprocessableEntity exception" do
        Put %r{/books/(\d+)\.#{@format}} do |id, put_data|
          raise Dupe::UnprocessableEntity.new(:title => "must be present.") if put_data[:title].blank?
          Dupe.find(:book) {|b| b.id == id.to_i}.merge!(put_data)
        end

        @ar_book.title = ""
        @ar_book.save.should == false
        @ar_book.errors[:title].should_not be_empty

        @ar_book.title = "Rails!"
        @ar_book.save.should == true
        # the following line should be true, were it not for a bug in active_resource 2.3.3 - 2.3.5
        # i reported the bug here: https://rails.lighthouseapp.com/projects/8994-ruby-on-rails/tickets/4169-activeresourcebasesave-put-doesnt-clear-out-errors
        # @ar_book.errors.should be_empty
      end

      it "passes headers to Put mock" do
        Put %r{/books/(\d+)\.json} do |id, put_data, headers|
          headers["X-Test"].should == "42"
          Dupe.find(:book) {|b| b.id == id.to_i}.merge!(put_data)
        end

        @ar_book.save
      end
    end

    describe "#delete" do
      before do
        @book = Dupe.create :book, :label => 'rooby', :title => 'Rooby'
        @ar_book = Book.find(1)
      end

      it "should pass a request off to the Dupe network if the original request failed" do
        Dupe.network.should_receive(:request).with(:delete, "/books/1.#{@format}",
                                                   {"X-Test" => "42"}).once.
          and_return(build_response("", 200, {}))
        @ar_book.destroy
      end

      it "trigger a Dupe.delete to delete the mocked resource from the duped database" do
        Dupe.find(:books).length.should == 1
        @ar_book.destroy
        Dupe.find(:books).length.should == 0
      end

      it "should allow you to override the default DELETE intercept mock" do
        Delete %r{/books/(\d+)\.#{@format}} do |id|
          raise StandardError, "Testing Delete override"
        end

        proc {@ar_book.destroy}.should raise_error(StandardError, "Testing Delete override")
      end

      it "passes headers to DELETE mock" do
        Delete %r{/books/(\d+)\.json} do |id, headers|
          headers["X-Test"].should == "42"
        end

        @ar_book.destroy
      end
    end
end

describe ActiveResource::Connection do
  describe "using xml " do
    before do
      Dupe.reset
      Dupe.format = ActiveResource::Formats::XmlFormat

      class Book < ActiveResource::Base
        self.site   = 'http://www.example.com'
        self.format = :xml

        def self.headers
          super.merge("X-Test" => "42")
        end
      end
      @format = "xml"
    end

    it_behaves_like "requests processing"
  end

  describe "using json " do
    before do
      Dupe.reset
      Dupe.format = ActiveResource::Formats::JsonFormat

      class Book < ActiveResource::Base
        self.site   = 'http://www.example.com'
        self.format = :json

        def self.headers
          super.merge("X-Test" => "42")
        end
      end

      @format = "json"
    end

    it_behaves_like "requests processing"
  end
end
