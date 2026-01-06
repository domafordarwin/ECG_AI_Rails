# Rails Backend - 핵심 기술 가이드

## 📋 프로젝트 개요

Backyard Brains SpikerBox 심전도 분석 시스템의 백엔드 API 구현 가이드입니다.
**주의**: 본 프로젝트는 Python FastAPI를 기본 백엔드로 권장하지만, Rails로 구현할 경우 본 문서를 참고하세요.

## 🎯 핵심 목표

- Stateless API 설계 (Zero-Retention Architecture)
- 5초 이내 WAV 파일 분석 처리
- 메모리 기반 처리 (디스크 I/O 최소화)
- CORS 설정으로 프론트엔드와 안전한 통신

## 🛠️ 기술 스택

### Core Framework
- **Ruby on Rails 7.x** (API Mode)
- **Ruby 3.x**
- **Puma** (Web Server)

### 필수 Gem

#### 1. WAV 파일 처리
```ruby
# Gemfile
gem 'wavefile', '~> 1.1'  # WAV 파일 파싱
```

#### 2. 신호 처리 (Python 라이브러리 호출)
Rails에서 직접 신호 처리는 제한적이므로, Python 스크립트를 호출하는 방식 권장:

```ruby
gem 'open3'  # 표준 라이브러리 (Python 스크립트 실행)
```

또는 Ruby 네이티브 FFT 라이브러리:
```ruby
gem 'numo-narray'  # NumPy 대체
gem 'numo-fftw'    # FFT 연산
```

#### 3. CORS
```ruby
gem 'rack-cors'
```

#### 4. 백그라운드 작업 (선택사항)
```ruby
gem 'sidekiq'  # 비동기 분석 처리 (선택)
```

## 📁 프로젝트 구조

```
Rails/
├── app/
│   ├── controllers/
│   │   └── api/
│   │       └── v1/
│   │           └── analyze_controller.rb   # 분석 API 엔드포인트
│   ├── services/
│   │   ├── wav_parser_service.rb           # WAV 파일 파싱
│   │   ├── signal_processor_service.rb     # 신호 처리 (필터링)
│   │   ├── anomaly_detector_service.rb     # 이상치 탐지
│   │   └── python_bridge_service.rb        # Python 스크립트 호출
│   ├── models/
│   │   └── system_log.rb                   # 시스템 로그 (선택)
│   └── lib/
│       └── python_scripts/
│           └── ecg_analyzer.py             # Python 신호 처리 스크립트
├── config/
│   ├── routes.rb
│   ├── initializers/
│   │   └── cors.rb
│   └── application.rb
├── db/
│   └── migrate/
│       └── 20260106_create_system_logs.rb  # 로그 테이블 (선택)
├── spec/                                   # RSpec 테스트
│   ├── requests/
│   │   └── api/v1/analyze_spec.rb
│   └── services/
│       └── anomaly_detector_service_spec.rb
└── docs/
    └── TECHNICAL_GUIDE.md                  # 본 문서
```

## 🚀 구현 가이드

### 1. Rails API 프로젝트 생성

```bash
# API 모드로 Rails 프로젝트 생성
rails new Rails --api --database=postgresql

cd Rails

# 필수 Gem 설치
bundle add wavefile rack-cors
bundle install
```

### 2. CORS 설정 (config/initializers/cors.rb)

```ruby
# config/initializers/cors.rb
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    # 프로덕션에서는 Vercel 도메인으로 변경
    origins 'http://localhost:3000', 'https://your-app.vercel.app'

    resource '/api/*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: false,
      max_age: 600
  end
end
```

### 3. 라우팅 설정 (config/routes.rb)

```ruby
# config/routes.rb
Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      post '/analyze', to: 'analyze#create'
      get '/health', to: 'analyze#health'  # 헬스체크
    end
  end
end
```

### 4. Analyze Controller (app/controllers/api/v1/analyze_controller.rb)

```ruby
# app/controllers/api/v1/analyze_controller.rb
module Api
  module V1
    class AnalyzeController < ApplicationController
      # 파일 크기 제한: 50MB
      MAX_FILE_SIZE = 50.megabytes

      def create
        start_time = Time.current

        # 1. 파일 유효성 검사
        unless params[:file].present?
          return render json: {
            success: false,
            error: '어라? 파일이 없어요. 파일을 올려주세요! 📂'
          }, status: :bad_request
        end

        uploaded_file = params[:file]

        # 파일 크기 검증
        if uploaded_file.size > MAX_FILE_SIZE
          return render json: {
            success: false,
            error: '파일 크기가 너무 커요! 50MB 이하로 올려주세요.'
          }, status: :bad_request
        end

        # 파일 타입 검증
        unless uploaded_file.content_type == 'audio/wav'
          return render json: {
            success: false,
            error: 'WAV 파일만 올릴 수 있어요! 🎵'
          }, status: :bad_request
        end

        begin
          # 2. WAV 파일 파싱 (메모리에서만 처리)
          wav_data = WavParserService.parse(uploaded_file.tempfile)

          # 3. 신호 처리 (노이즈 필터링)
          filtered_data = SignalProcessorService.filter(wav_data)

          # 4. 이상치 탐지
          anomalies = AnomalyDetectorService.detect(filtered_data)

          # 5. 응답 생성
          result = {
            success: true,
            sampling_rate: wav_data[:sampling_rate],
            duration: wav_data[:duration],
            data_points: filtered_data[:data_points].first(1000),  # 프론트엔드 부하 방지
            anomalies: anomalies.map do |a|
              {
                start_time: a[:start_time],
                end_time: a[:end_time],
                anomaly_score: a[:score],
                message: generate_friendly_message(a[:score])
              }
            end
          }

          # 6. 로그 기록 (PII 없이)
          processing_time = ((Time.current - start_time) * 1000).to_i
          log_analysis(processing_time, 'SUCCESS')

          render json: result, status: :ok

        rescue => e
          # 에러 로그 (스택트레이스만, 파일 데이터 제외)
          log_analysis(0, 'ERROR', e.message)

          render json: {
            success: false,
            error: '분석 중 문제가 발생했어요. 다시 시도해주세요! 🤔'
          }, status: :internal_server_error

        ensure
          # 7. 메모리 즉시 해제
          GC.start
        end
      end

      def health
        render json: { status: 'OK', timestamp: Time.current }, status: :ok
      end

      private

      def generate_friendly_message(score)
        case score
        when 0.8..1.0
          "이 구간은 #{(score * 100).to_i}% 확률로 불규칙해요!"
        when 0.5..0.8
          "이 구간은 조금 이상한 패턴이 보여요."
        else
          "미세한 변동이 감지되었어요."
        end
      end

      def log_analysis(processing_time, status, error_detail = nil)
        # SystemLog 모델이 있을 경우에만 사용 (선택사항)
        # SystemLog.create(
        #   event_type: "ANALYZE_#{status}",
        #   processing_time_ms: processing_time,
        #   error_detail: error_detail
        # )
        Rails.logger.info("ANALYZE_#{status}: #{processing_time}ms")
      end
    end
  end
end
```

### 5. WAV Parser Service (app/services/wav_parser_service.rb)

```ruby
# app/services/wav_parser_service.rb
require 'wavefile'

class WavParserService
  class << self
    def parse(file_path)
      WaveFile::Reader.new(file_path).read do |reader|
        # SpikerBox 명세: 10kHz, Mono, 16-bit
        unless reader.format.channels == 1
          raise StandardError, 'Mono 채널 WAV 파일만 지원합니다.'
        end

        unless reader.format.sample_rate == 10_000
          raise StandardError, 'SpikerBox는 10kHz 샘플링 레이트를 사용합니다.'
        end

        buffer = reader.read(:all)
        samples = buffer.samples.flatten  # Mono이므로 1차원 배열

        {
          sampling_rate: reader.format.sample_rate,
          duration: samples.length.to_f / reader.format.sample_rate,
          data_points: samples,
          length: samples.length
        }
      end
    rescue => e
      raise StandardError, "WAV 파일 파싱 실패: #{e.message}"
    end
  end
end
```

### 6. Signal Processor Service (app/services/signal_processor_service.rb)

```ruby
# app/services/signal_processor_service.rb
class SignalProcessorService
  class << self
    def filter(wav_data)
      # 간단한 Moving Average 필터 (노이즈 제거)
      window_size = 5
      data = wav_data[:data_points]
      filtered = []

      data.each_cons(window_size) do |window|
        filtered << window.sum / window_size
      end

      {
        sampling_rate: wav_data[:sampling_rate],
        data_points: filtered
      }
    end

    # 고급 필터링이 필요하면 Python 스크립트 호출
    def filter_with_python(wav_data)
      PythonBridgeService.call_analyzer(wav_data)
    end
  end
end
```

### 7. Anomaly Detector Service (app/services/anomaly_detector_service.rb)

```ruby
# app/services/anomaly_detector_service.rb
class AnomalyDetectorService
  class << self
    def detect(filtered_data)
      data = filtered_data[:data_points]
      sampling_rate = filtered_data[:sampling_rate]
      anomalies = []

      # R-peak 검출 (간단한 임계값 기반)
      threshold = data.max * 0.6
      peaks = find_peaks(data, threshold)

      # RR 간격 계산
      rr_intervals = peaks.each_cons(2).map { |p1, p2| (p2 - p1).to_f / sampling_rate }

      return [] if rr_intervals.empty?

      # 평균과 표준편차 계산
      mean_rr = rr_intervals.sum / rr_intervals.length
      std_rr = Math.sqrt(rr_intervals.map { |rr| (rr - mean_rr)**2 }.sum / rr_intervals.length)

      # 이상치 탐지 (평균에서 2 표준편차 이상 벗어난 구간)
      rr_intervals.each_with_index do |rr, idx|
        if (rr - mean_rr).abs > 2 * std_rr
          start_idx = peaks[idx]
          end_idx = peaks[idx + 1] || data.length - 1

          anomalies << {
            start_time: start_idx.to_f / sampling_rate,
            end_time: end_idx.to_f / sampling_rate,
            score: [(rr - mean_rr).abs / (3 * std_rr), 1.0].min  # 0-1 정규화
          }
        end
      end

      anomalies
    end

    private

    def find_peaks(data, threshold)
      peaks = []
      data.each_with_index do |value, idx|
        next if idx == 0 || idx == data.length - 1

        if value > threshold && value > data[idx - 1] && value > data[idx + 1]
          peaks << idx
        end
      end
      peaks
    end
  end
end
```

### 8. Python Bridge Service (app/services/python_bridge_service.rb) - 선택사항

고급 신호 처리가 필요할 경우 Python 스크립트 호출:

```ruby
# app/services/python_bridge_service.rb
require 'open3'
require 'json'

class PythonBridgeService
  PYTHON_SCRIPT = Rails.root.join('lib', 'python_scripts', 'ecg_analyzer.py')

  class << self
    def call_analyzer(wav_data)
      # 데이터를 JSON으로 변환하여 Python 스크립트에 전달
      input_json = wav_data.to_json

      stdout, stderr, status = Open3.capture3(
        'python3', PYTHON_SCRIPT.to_s,
        stdin_data: input_json
      )

      unless status.success?
        raise StandardError, "Python 스크립트 실행 실패: #{stderr}"
      end

      JSON.parse(stdout, symbolize_names: true)
    end
  end
end
```

**Python 스크립트** (lib/python_scripts/ecg_analyzer.py):

```python
#!/usr/bin/env python3
import sys
import json
import numpy as np
from scipy import signal

def analyze_ecg(data):
    """
    ECG 데이터 분석 (Bandpass Filter + R-peak 검출)
    """
    sampling_rate = data['sampling_rate']
    data_points = np.array(data['data_points'])

    # Bandpass Filter (0.5Hz - 50Hz)
    nyquist = sampling_rate / 2
    low = 0.5 / nyquist
    high = 50 / nyquist
    b, a = signal.butter(4, [low, high], btype='band')
    filtered = signal.filtfilt(b, a, data_points)

    # R-peak 검출
    peaks, _ = signal.find_peaks(filtered, height=np.max(filtered) * 0.6, distance=sampling_rate * 0.5)

    return {
        'sampling_rate': sampling_rate,
        'data_points': filtered.tolist()[:1000],  # 프론트엔드 부하 방지
        'peaks': peaks.tolist()
    }

if __name__ == '__main__':
    input_data = json.load(sys.stdin)
    result = analyze_ecg(input_data)
    print(json.dumps(result))
```

## 🧪 테스트 가이드

### RSpec 설정

```ruby
# Gemfile
group :development, :test do
  gem 'rspec-rails'
  gem 'factory_bot_rails'
end
```

```bash
rails generate rspec:install
```

### Request Spec (spec/requests/api/v1/analyze_spec.rb)

```ruby
# spec/requests/api/v1/analyze_spec.rb
require 'rails_helper'

RSpec.describe 'Api::V1::Analyze', type: :request do
  describe 'POST /api/v1/analyze' do
    let(:valid_wav_file) do
      fixture_file_upload(Rails.root.join('spec', 'fixtures', 'sample.wav'), 'audio/wav')
    end

    context '정상적인 WAV 파일' do
      it 'HTTP 200과 분석 결과 반환' do
        post '/api/v1/analyze', params: { file: valid_wav_file }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['success']).to be true
        expect(json['sampling_rate']).to eq 10_000
        expect(json['anomalies']).to be_an(Array)
      end
    end

    context '파일이 없을 때' do
      it 'HTTP 400과 에러 메시지 반환' do
        post '/api/v1/analyze'

        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)
        expect(json['error']).to include('파일이 없어요')
      end
    end

    context '50MB 초과 파일' do
      it 'HTTP 400 반환' do
        large_file = double('file', size: 51.megabytes, content_type: 'audio/wav')
        allow(large_file).to receive(:present?).and_return(true)

        post '/api/v1/analyze', params: { file: large_file }

        expect(response).to have_http_status(:bad_request)
      end
    end
  end
end
```

## 🚀 배포 가이드

### 1. Heroku 배포 (추천)

```bash
# Heroku CLI 설치 후
heroku create your-app-name
heroku addons:create heroku-postgresql:mini

# 환경변수 설정
heroku config:set RAILS_ENV=production
heroku config:set RACK_ENV=production

# 배포
git push heroku main

# 마이그레이션 (로그 테이블 사용 시)
heroku run rails db:migrate
```

### 2. AWS Lambda + API Gateway (서버리스)

Rails를 Lambda에 배포하는 것은 복잡하므로, **FastAPI를 사용하는 것을 강력히 권장**합니다.

### 3. Google Cloud Run

```bash
# Dockerfile 작성 (Rails 7 기준)
# Dockerfile
FROM ruby:3.2
WORKDIR /app
COPY Gemfile Gemfile.lock ./
RUN bundle install
COPY . .
CMD ["rails", "server", "-b", "0.0.0.0", "-p", "8080"]
```

```bash
# Cloud Run 배포
gcloud builds submit --tag gcr.io/PROJECT_ID/ecg-analyzer
gcloud run deploy ecg-analyzer \
  --image gcr.io/PROJECT_ID/ecg-analyzer \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated
```

## 🔒 보안 체크리스트

- [ ] CORS 설정에서 프로덕션 도메인만 허용
- [ ] 파일 크기 제한 (50MB) 서버 측 검증
- [ ] WAV 파일 타입 검증 (Magic Number 확인)
- [ ] Rate Limiting 적용 (rack-attack gem)
- [ ] 환경변수로 민감정보 관리
- [ ] HTTPS 강제 (프로덕션)
- [ ] 메모리 누수 방지 (`GC.start` 명시적 호출)

### Rate Limiting (rack-attack)

```ruby
# Gemfile
gem 'rack-attack'

# config/initializers/rack_attack.rb
Rack::Attack.throttle('api/analyze', limit: 10, period: 60) do |req|
  req.ip if req.path == '/api/v1/analyze' && req.post?
end
```

## 🆘 트러블슈팅

### 문제 1: 메모리 부족 오류
**해결**: Puma 워커 수를 줄이고, `GC.start`를 명시적으로 호출하여 메모리 즉시 해제.

### 문제 2: WAV 파일 파싱 실패
**해결**: `wavefile` gem이 PCM 포맷만 지원. 압축된 WAV 파일은 거부.

### 문제 3: Python 스크립트 실행 느림
**해결**: Docker 이미지에 Python + SciPy를 미리 설치하여 콜드 스타트 최소화.

## 📚 참고 자료

- [Rails API 모드 공식 가이드](https://guides.rubyonrails.org/api_app.html)
- [wavefile gem GitHub](https://github.com/jstrait/wavefile)
- [rack-cors gem](https://github.com/cyu/rack-cors)

## 🔄 FastAPI 권장 이유

Rails 대신 **Python FastAPI**를 사용하면:
- SciPy, NumPy 네이티브 지원으로 신호 처리 간편
- 서버리스 배포 용이 (Lambda/Cloud Run)
- 더 빠른 처리 속도

Rails는 WAV 파일 처리와 신호 처리에서 제약이 많으므로, **FastAPI를 기본 백엔드로 권장합니다.**

---

**문의**: 구현 중 문제 발생 시 PRD, TRD, Prompt_Design.md 참고.
