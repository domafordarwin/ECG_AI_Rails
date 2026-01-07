# frozen_string_literal: true

require 'streamio-ffmpeg'

class AudioConverterService
  class << self
    # Convert MP3 (or other audio formats) to WAV
    def to_wav(input_file)
      # Create temporary WAV file
      temp_wav = Tempfile.new(['converted', '.wav'])
      temp_wav.close

      begin
        movie = FFMPEG::Movie.new(input_file.path)

        # Convert to mono WAV with automatic sample rate detection
        options = {
          audio_codec: 'pcm_s16le',  # 16-bit PCM
          audio_channels: 1,          # Mono
          custom: %w[-ar 44100]       # Force 44100 Hz sample rate
        }

        movie.transcode(temp_wav.path, options)

        # Return File object
        File.open(temp_wav.path, 'rb')
      rescue StandardError => e
        temp_wav.unlink if temp_wav
        raise StandardError, "오디오 변환 실패: #{e.message}"
      end
    end

    def supported_format?(filename)
      extension = File.extname(filename).downcase
      %w[.mp3 .wav .m4a .aac .ogg .flac].include?(extension)
    end
  end
end
