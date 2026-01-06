# frozen_string_literal: true

class AnomalyDetectorService
  class << self
    def detect(filtered_data)
      data = filtered_data[:data_points]
      sampling_rate = filtered_data[:sampling_rate]
      return { anomalies: [], peaks: [], p_waves: [], q_waves: [], s_waves: [], t_waves: [] } if data.empty?

      # Find R Peaks
      threshold = data.max.to_f * 0.6
      r_peaks = find_peaks(data, threshold)
      return { anomalies: [], peaks: r_peaks, p_waves: [], q_waves: [], s_waves: [], t_waves: [] } if r_peaks.empty?

      # Detect P, Q, S, T waves relative to R peaks
      waves = detect_pqst_waves(data, r_peaks, sampling_rate)

      # Anomaly Detection based on RR interval
      anomalies = []
      if r_peaks.length >= 2
        rr_intervals = r_peaks.each_cons(2).map { |p1, p2| (p2 - p1).to_f / sampling_rate }
        mean_rr = rr_intervals.sum / rr_intervals.length
        variance = rr_intervals.map { |rr| (rr - mean_rr)**2 }.sum / rr_intervals.length
        std_rr = Math.sqrt(variance)

        anomalies = rr_intervals.each_with_index.filter_map do |rr, idx|
          next unless std_rr.positive?
          next unless (rr - mean_rr).abs > 2 * std_rr

          start_idx = r_peaks[idx]
          end_idx = r_peaks[idx + 1] || data.length - 1

          {
            start_time: start_idx.to_f / sampling_rate,
            end_time: end_idx.to_f / sampling_rate,
            score: [(rr - mean_rr).abs / (3 * std_rr), 1.0].min
          }
        end
      end

      { 
        anomalies: anomalies, 
        peaks: r_peaks,
        p_waves: waves[:p],
        q_waves: waves[:q],
        s_waves: waves[:s],
        t_waves: waves[:t]
      }
    end

    private

    def find_peaks(data, threshold)
      data.each_index.select do |idx|
        next false if idx.zero? || idx == data.length - 1
        data[idx] > threshold && data[idx] > data[idx - 1] && data[idx] > data[idx + 1]
      end
    end

    def detect_pqst_waves(data, r_peaks, sampling_rate)
      # Search windows in seconds
      q_search = 0.05
      s_search = 0.05
      p_search = 0.2
      t_search = 0.4

      p_waves = []
      q_waves = []
      s_waves = []
      t_waves = []

      r_peaks.each do |r|
        # Q Wave: Minimum before R within 0.05s
        q_win_size = (q_search * sampling_rate).to_i
        q_start = [0, r - q_win_size].max
        q_idx = find_min_index(data, q_start, r)
        q_waves << q_idx if q_idx

        # S Wave: Minimum after R within 0.05s
        s_win_size = (s_search * sampling_rate).to_i
        s_end = [data.length - 1, r + s_win_size].min
        s_idx = find_min_index(data, r, s_end)
        s_waves << s_idx if s_idx

        # P Wave: Maximum before Q within 0.1s
        if q_idx
          p_win_size = (p_search * sampling_rate).to_i
          p_start = [0, q_idx - p_win_size].max
          p_idx = find_max_index(data, p_start, q_idx)
          p_waves << p_idx if p_idx
        end

        # T Wave: Maximum after S within 0.3s
        if s_idx
          t_win_size = (t_search * sampling_rate).to_i
          t_end = [data.length - 1, s_idx + t_win_size].min
          t_idx = find_max_index(data, s_idx, t_end)
          t_waves << t_idx if t_idx
        end
      end

      { p: p_waves.uniq, q: q_waves.uniq, s: s_waves.uniq, t: t_waves.uniq }
    end

    def find_min_index(data, start_idx, end_idx)
      return nil if start_idx >= end_idx
      data[start_idx...end_idx].each_with_index.min[1] + start_idx
    end

    def find_max_index(data, start_idx, end_idx)
      return nil if start_idx >= end_idx
      data[start_idx...end_idx].each_with_index.max[1] + start_idx
    end
  end
end
