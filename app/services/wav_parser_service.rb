# frozen_string_literal: true

require "wavefile"

class WavParserService
  ALLOWED_SAMPLE_RATES = [10_000, 5_000].freeze

  class << self
    def parse(file_path)
      io_path = normalize_path(file_path)
      reader = nil
      reader = WaveFile::Reader.new(io_path)
      format = reader.format
      validate_format!(format)

      samples = []
      reader.each_buffer(4_096) do |buffer|
        samples.concat(buffer.samples.flatten)
      end

      {
        sampling_rate: format.sample_rate,
        duration: samples.length.to_f / format.sample_rate,
        data_points: samples,
        length: samples.length
      }
    rescue WaveFile::InvalidFormatError, SystemCallError => e
      raise StandardError, "WAV 파일 파싱 실패: #{e.message}"
    ensure
      reader&.close
      file_path.rewind if file_path.respond_to?(:rewind)
    end

    private

    def normalize_path(file)
      file.rewind if file.respond_to?(:rewind)
      return file.path if file.respond_to?(:path)

      file
    end

    def validate_format!(format)
      raise StandardError, "모노 채널 WAV 파일만 지원합니다." unless format.channels == 1
      return if ALLOWED_SAMPLE_RATES.include?(format.sample_rate)

      raise StandardError, "지원하지 않는 샘플링 레이트입니다: #{format.sample_rate}Hz"
    end
  end
end
