# frozen_string_literal: true

RSpec.describe Hanami::Turbo::Request do
  def request(env = {})
    Hanami::Action::Request.new(env: Rack::MockRequest.env_for("/", env), params: {})
  end

  describe "#turbo_frame" do
    it "returns the Turbo-Frame header" do
      expect(request("HTTP_TURBO_FRAME" => "tray").turbo_frame).to eq "tray"
      expect(request("HTTP_TURBO_FRAME" => "tray")).to be_turbo_frame
    end

    it "is nil without the header" do
      expect(request.turbo_frame).to be_nil
      expect(request).not_to be_turbo_frame
    end
  end

  describe "#turbo_stream?" do
    it "is true when the stream media type is accepted" do
      expect(request("HTTP_ACCEPT" => "text/vnd.turbo-stream.html, text/html")).to be_turbo_stream
    end

    it "is false for wildcard and HTML accept headers" do
      expect(request("HTTP_ACCEPT" => "*/*")).not_to be_turbo_stream
      expect(request("HTTP_ACCEPT" => "text/html")).not_to be_turbo_stream
      expect(request).not_to be_turbo_stream
    end
  end
end
