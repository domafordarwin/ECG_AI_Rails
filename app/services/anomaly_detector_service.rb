# frozen_string_literal: true

class AnomalyDetectorService
  class << self
    def detect(filtered_data)
      data = filtered_data[:data_points]
      sampling_rate = filtered_data[:sampling_rate]
      return { anomalies: [], peaks: [] } if data.empty?

      threshold = data.max.to_f * 0.6
      peaks = find_peaks(data, threshold)
      return { anomalies: [], peaks: peaks } if peaks.length < 2

      rr_intervals = peaks.each_cons(2).map { |p1, p2| (p2 - p1).to_f / sampling_rate }
      mean_rr = rr_intervals.sum / rr_intervals.length
      variance = rr_intervals.map { |rr| (rr - mean_rr)**2 }.sum / rr_intervals.length
      std_rr = Math.sqrt(variance)

      anomalies = rr_intervals.each_with_index.filter_map do |rr, idx|
        next unless std_rr.positive?
        next unless (rr - mean_rr).abs > 2 * std_rr

        start_idx = peaks[idx]
        end_idx = peaks[idx + 1] || data.length - 1

        {
          start_time: start_idx.to_f / sampling_rate,
          end_time: end_idx.to_f / sampling_rate,
          score: [(rr - mean_rr).abs / (3 * std_rr), 1.0].min
        }
      end

      { anomalies: anomalies, peaks: peaks }
    end

    private

    def find_peaks(data, threshold)
      data.each_index.select do |idx|
        next false if idx.zero? || idx == data.length - 1

        data[idx] > threshold && data[idx] > data[idx - 1] && data[idx] > data[idx + 1]
      end
    end
  end
end
