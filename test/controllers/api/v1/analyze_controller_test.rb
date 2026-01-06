# frozen_string_literal: true

require "test_helper"

class Api::V1::AnalyzeControllerTest < ActionDispatch::IntegrationTest
  def setup
    @wav_path = Rails.root.join("spec", "fixtures", "files", "BYB_Recording_2025-05-17_12.44.35.wav")
  end

  def test_returns_analysis_result_for_valid_wav_upload
    file = Rack::Test::UploadedFile.new(@wav_path, "audio/wav", true)

    post "/api/v1/analyze", params: { file: file }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal true, body["success"], body
    assert body["sampling_rate"], "expected sampling_rate in response"
    assert body["data_points"].is_a?(Array), "expected data_points array"
  end

  def test_rejects_missing_file
    post "/api/v1/analyze"

    assert_response :bad_request
    body = JSON.parse(response.body)
    assert_equal false, body["success"]
  end
end
