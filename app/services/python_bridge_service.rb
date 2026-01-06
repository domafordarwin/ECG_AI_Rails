# frozen_string_literal: true

require "open3"
require "json"

class PythonBridgeService
  PYTHON_SCRIPT = Rails.root.join("lib", "python_scripts", "ecg_analyzer.py")

  class << self
    def call_analyzer(wav_data)
      raise StandardError, "Python 스크립트를 찾을 수 없습니다." unless File.exist?(PYTHON_SCRIPT)

      stdout, stderr, status = Open3.capture3("python", PYTHON_SCRIPT.to_s, stdin_data: wav_data.to_json)
      raise StandardError, "Python 스크립트 실행 실패: #{stderr}" unless status.success?

      JSON.parse(stdout, symbolize_names: true)
    end
  end
end
