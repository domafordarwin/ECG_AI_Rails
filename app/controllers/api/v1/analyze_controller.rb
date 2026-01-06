# frozen_string_literal: true

module Api
  module V1
    class AnalyzeController < ApplicationController
      skip_before_action :verify_authenticity_token
      MAX_FILE_SIZE = 50.megabytes

      def create
        start_time = Time.current
        uploaded_file = params[:file]

        unless uploaded_file.present?
          return render json: { success: false, error: "파일이 첨부되지 않았습니다." }, status: :bad_request
        end

        if uploaded_file.size > MAX_FILE_SIZE
          return render json: { success: false, error: "파일 크기는 50MB 이하여야 합니다." }, status: :bad_request
        end

        unless uploaded_file.content_type == "audio/wav"
          return render json: { success: false, error: "WAV 파일만 허용됩니다." }, status: :bad_request
        end

        wav_data = WavParserService.parse(uploaded_file.tempfile)
        filtered_data, detection_result = process_signal(wav_data)

        processing_time_ms = ((Time.current - start_time) * 1000).to_i
        log_analysis(processing_time_ms, "SUCCESS")

        render json: build_success_response(wav_data, filtered_data, detection_result, processing_time_ms), status: :ok
      rescue StandardError => e
        log_analysis(0, "ERROR", e.message)
        render json: { success: false, error: "분석 중 오류가 발생했습니다: #{e.message}" }, status: :internal_server_error
      ensure
        GC.start
      end

      def health
        render json: { status: "OK", timestamp: Time.current }, status: :ok
      end

      private

      def build_success_response(wav_data, filtered_data, detection_result, processing_time_ms)
        {
          success: true,
          sampling_rate: wav_data[:sampling_rate],
          duration: wav_data[:duration],
          data_points: filtered_data[:data_points],
          peaks: detection_result[:peaks],
          anomalies: format_anomalies(detection_result[:anomalies]),
          processing_time_ms: processing_time_ms
        }
      end

      def process_signal(wav_data)
        filtered_data = SignalProcessorService.filter(wav_data)
        detection_result = AnomalyDetectorService.detect(filtered_data)

        return [filtered_data, detection_result] unless use_python_bridge?

        python_result = PythonBridgeService.call_analyzer(wav_data)
        bridged_filtered = python_result[:filtered_data]
        bridged_anomalies = python_result[:anomalies]
        bridged_peaks = python_result[:peaks]

        final_filtered = bridged_filtered || filtered_data
        final_detection = {
          anomalies: bridged_anomalies || detection_result[:anomalies],
          peaks: bridged_peaks || detection_result[:peaks]
        }

        [final_filtered, final_detection]
      rescue StandardError => e
        Rails.logger.warn("PYTHON_BRIDGE_FALLBACK: #{e.message}")
        [filtered_data, detection_result]
      end

      def format_anomalies(anomalies)
        Array(anomalies).map do |anomaly|
          score = anomaly[:score].to_f
          {
            start_time: anomaly[:start_time],
            end_time: anomaly[:end_time],
            anomaly_score: score,
            message: friendly_message(score)
          }
        end
      end

      def friendly_message(score)
        case score
        when 0.8..1.0
          "이 구간은 #{(score * 100).to_i}% 확률로 불규칙합니다."
        when 0.5..0.8
          "불규칙 패턴이 관측됩니다."
        else
          "미세한 변동이 감지되었습니다."
        end
      end

      def log_analysis(processing_time_ms, status, error_detail = nil)
        Rails.logger.info(
          "ANALYZE_#{status} process=#{processing_time_ms}ms error='#{error_detail}'"
        )
      end

      def use_python_bridge?
        Rails.configuration.x.processing.use_python_bridge
      end
    end
  end
end
