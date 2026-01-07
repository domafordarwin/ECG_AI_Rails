# frozen_string_literal: true

class AnomalyDetectorService
  class << self
    def detect(filtered_data)
      data = filtered_data[:data_points]
      sampling_rate = filtered_data[:sampling_rate]
      return { anomalies: [], peaks: [], p_waves: [], q_waves: [], s_waves: [], t_waves: [] } if data.empty?

      # Find R Peaks with improved threshold
      mean_val = data.sum.to_f / data.length
      max_val = data.max.to_f
      # Use 70% of max for better peak detection
      threshold = mean_val + (max_val - mean_val) * 0.7
      r_peaks = find_peaks(data, threshold, sampling_rate)
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

    def find_peaks(data, threshold, sampling_rate)
      peaks = []
      # Minimum distance between peaks (in samples) - prevents duplicate detections
      # For 75 bpm, R-R interval is ~0.8s, use 0.4s as minimum
      min_distance = (0.4 * sampling_rate).to_i
      last_peak_idx = -min_distance

      data.each_index do |idx|
        next if idx.zero? || idx == data.length - 1
        next if (idx - last_peak_idx) < min_distance

        if data[idx] > threshold && data[idx] > data[idx - 1] && data[idx] > data[idx + 1]
          peaks << idx
          last_peak_idx = idx
        end
      end

      peaks
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

      min_val = data[start_idx]
      min_idx = start_idx

      (start_idx + 1...end_idx).each do |i|
        if data[i] < min_val
          min_val = data[i]
          min_idx = i
        end
      end

      min_idx
    end

    def find_max_index(data, start_idx, end_idx)
      return nil if start_idx >= end_idx

      max_val = data[start_idx]
      max_idx = start_idx

      (start_idx + 1...end_idx).each do |i|
        if data[i] > max_val
          max_val = data[i]
          max_idx = i
        end
      end

      max_idx
    end
  end
end
