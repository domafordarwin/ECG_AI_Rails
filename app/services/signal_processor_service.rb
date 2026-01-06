# frozen_string_literal: true

class SignalProcessorService
  WINDOW_SIZE = 5

  class << self
    def filter(wav_data)
      data = wav_data[:data_points]
      return base_payload(wav_data, data) if data.length <= WINDOW_SIZE

      filtered = moving_average(data)
      base_payload(wav_data, filtered)
    end

    private

    def moving_average(data)
      sums = data.each_cons(WINDOW_SIZE).map { |window| window.sum.to_f / WINDOW_SIZE }
      head_padding = Array.new(WINDOW_SIZE - 1, sums.first || 0.0)
      head_padding + sums
    end

    def base_payload(wav_data, data_points)
      {
        sampling_rate: wav_data[:sampling_rate],
        data_points: data_points
      }
    end
  end
end
