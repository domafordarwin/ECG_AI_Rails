# GitHub Copilot 개발 시작 가이드

ECG Analyzer - Rails 풀스택 프로젝트 개발 가이드

---

## 🎯 당신의 미션

안녕하세요, GitHub Copilot! 당신은 **ECG_AI_Rails** 프로젝트의 개발을 담당합니다.

**목표**: Ruby on Rails의 MVC 패턴을 활용하여 심전도 분석 웹 애플리케이션을 만들어주세요.

**저장소**: https://github.com/domafordarwin/ECG_AI_Rails

---

## 📦 현재 상태

### ✅ Rails 8 기본 구조 생성 완료
- Hotwire (Turbo + Stimulus) 설정됨
- SQLite3 데이터베이스 설정됨
- Puma 웹 서버 설정됨
- Kamal 배포 설정 포함됨

### ❌ 애플리케이션 로직 - 구현 필요
- Controllers (Pages, API)
- Services (WAV 파싱, 신호 처리, 이상치 탐지)
- Views (메인 페이지, 결과 페이지)
- JavaScript (Stimulus 컨트롤러)

---

## 🚀 개발 로드맵

### Phase 1: 라우팅 및 기본 컨트롤러 설정

#### 1-1. Routes 설정
**파일**: `config/routes.rb`

```ruby
Rails.application.routes.draw do
  # 메인 페이지 (파일 업로드)
  root "pages#index"

  # 분석 결과 페이지
  get "result", to: "pages#result"

  # API 엔드포인트
  namespace :api do
    namespace :v1 do
      post "analyze", to: "analyze#create"
      get "health", to: "analyze#health"
    end
  end

  # Health check (배포용)
  get "up" => "rails/health#show", as: :rails_health_check
end
```

#### 1-2. Pages Controller 생성
**파일**: `app/controllers/pages_controller.rb`

```ruby
class PagesController < ApplicationController
  def index
    # 메인 페이지 (파일 업로드 UI)
  end

  def result
    # 분석 결과 페이지
    # 세션 또는 쿼리 파라미터로 결과 전달
  end
end
```

**완료 기준**:
- [ ] Routes 설정 완료
- [ ] PagesController 생성
- [ ] `bin/rails routes` 명령어로 라우트 확인

---

### Phase 2: Service Objects 구현 (핵심 로직)

Rails의 Service Object 패턴을 사용하여 비즈니스 로직을 분리합니다.

#### 2-1. WAV Parser Service
**파일**: `app/services/wav_parser_service.rb`

```ruby
require 'wavefile'

class WavParserService
  MAX_FILE_SIZE = 50.megabytes

  def self.parse(file_path)
    raise "파일이 너무 커요! (최대 50MB)" if File.size(file_path) > MAX_FILE_SIZE

    reader = WaveFile::Reader.new(file_path)
    format = reader.format

    # WAV 파일 검증
    raise "PCM 포맷만 지원해요!" unless format.audio_format == 1
    raise "모노 채널만 지원해요!" unless format.channels == 1

    # 샘플 데이터 읽기
    samples = []
    reader.each_buffer do |buffer|
      samples.concat(buffer.samples)
    end

    {
      sampling_rate: format.sample_rate,
      duration: samples.length.to_f / format.sample_rate,
      data: samples.map(&:to_f)
    }
  ensure
    reader&.close
  end
end
```

**의존성 추가**:
```bash
bundle add wavefile
```

#### 2-2. Signal Processor Service
**파일**: `app/services/signal_processor_service.rb`

```ruby
class SignalProcessorService
  # Option 1: Ruby 네이티브 (numo-narray 사용)
  def self.filter_ruby(wav_data)
    # numo-narray, numo-fftw 사용한 Bandpass Filter 구현
    # 복잡도 높음, 성능은 Python보다 낮음
  end

  # Option 2: Python 브릿지 (추천) ⭐
  def self.filter_python(wav_data)
    # Python 스크립트 호출
    temp_file = Tempfile.new(['ecg', '.json'])
    temp_file.write(wav_data.to_json)
    temp_file.close

    # Python 스크립트 실행
    result = `python3 lib/python/bandpass_filter.py #{temp_file.path}`
    JSON.parse(result)
  ensure
    temp_file&.unlink
  end
end
```

**Python 스크립트**: `lib/python/bandpass_filter.py`
```python
import sys
import json
import numpy as np
from scipy import signal

def bandpass_filter(data, sampling_rate):
    nyquist = sampling_rate / 2
    low = 0.5 / nyquist
    high = 50.0 / nyquist
    b, a = signal.butter(4, [low, high], btype='band')
    filtered = signal.filtfilt(b, a, data)
    return filtered.tolist()

if __name__ == '__main__':
    with open(sys.argv[1], 'r') as f:
        wav_data = json.load(f)

    filtered_data = bandpass_filter(
        wav_data['data'],
        wav_data['sampling_rate']
    )

    print(json.dumps({'filtered_data': filtered_data}))
```

**의존성 설치 (Python)**:
```bash
pip install scipy numpy
```

#### 2-3. Anomaly Detector Service
**파일**: `app/services/anomaly_detector_service.rb`

```ruby
class AnomalyDetectorService
  def self.detect(filtered_data, sampling_rate)
    # R-peak 검출 (Python 스크립트 호출)
    temp_file = Tempfile.new(['ecg', '.json'])
    temp_file.write({
      filtered_data: filtered_data,
      sampling_rate: sampling_rate
    }.to_json)
    temp_file.close

    result = `python3 lib/python/detect_anomalies.py #{temp_file.path}`
    JSON.parse(result)['anomalies']
  ensure
    temp_file&.unlink
  end
end
```

**Python 스크립트**: `lib/python/detect_anomalies.py`
```python
import sys
import json
import numpy as np
from scipy import signal

def detect_anomalies(filtered_data, sampling_rate):
    data = np.array(filtered_data)

    # R-peak 검출
    threshold = np.max(data) * 0.6
    min_distance = int(0.3 * sampling_rate)
    peaks, _ = signal.find_peaks(data, height=threshold, distance=min_distance)

    # RR 간격 분석
    rr_intervals = np.diff(peaks) / sampling_rate
    mean_rr = np.mean(rr_intervals)
    std_rr = np.std(rr_intervals)

    anomalies = []
    for i, rr in enumerate(rr_intervals):
        deviation = abs(rr - mean_rr)
        if deviation > 2 * std_rr:
            start_time = peaks[i] / sampling_rate
            end_time = peaks[i + 1] / sampling_rate
            anomaly_score = min(deviation / (2 * std_rr), 1.0)

            anomalies.append({
                'start_time': round(start_time, 2),
                'end_time': round(end_time, 2),
                'anomaly_score': round(anomaly_score, 2),
                'message': f"이 구간은 {int(anomaly_score * 100)}% 확률로 불규칙해요!"
            })

    return anomalies

if __name__ == '__main__':
    with open(sys.argv[1], 'r') as f:
        data = json.load(f)

    anomalies = detect_anomalies(
        data['filtered_data'],
        data['sampling_rate']
    )

    print(json.dumps({'anomalies': anomalies}))
```

**완료 기준**:
- [ ] WavParserService 구현 및 테스트
- [ ] SignalProcessorService 구현 (Python 브릿지)
- [ ] AnomalyDetectorService 구현
- [ ] Python 스크립트 동작 확인

---

### Phase 3: API Controller 구현

#### 3-1. Analyze Controller
**파일**: `app/controllers/api/v1/analyze_controller.rb`

```ruby
module Api
  module V1
    class AnalyzeController < ApplicationController
      skip_before_action :verify_authenticity_token
      MAX_FILE_SIZE = 50.megabytes

      def create
        # 1. 파일 유효성 검증
        unless params[:file].present?
          return render json: { error: '어라? 파일이 없어요. 😅' }, status: :bad_request
        end

        uploaded_file = params[:file]

        unless uploaded_file.original_filename.end_with?('.wav')
          return render json: { error: 'WAV 파일만 올릴 수 있어요! 🎵' }, status: :bad_request
        end

        if uploaded_file.size > MAX_FILE_SIZE
          return render json: { error: '파일이 너무 커요! (최대 50MB)' }, status: :bad_request
        end

        # 2. WAV 파일 파싱
        wav_data = WavParserService.parse(uploaded_file.tempfile.path)

        # 3. 신호 처리 (노이즈 필터링)
        filtered_result = SignalProcessorService.filter_python(wav_data)
        filtered_data = filtered_result['filtered_data']

        # 4. 이상치 탐지
        anomalies = AnomalyDetectorService.detect(filtered_data, wav_data[:sampling_rate])

        # 5. 응답 반환
        render json: {
          success: true,
          sampling_rate: wav_data[:sampling_rate],
          duration: wav_data[:duration],
          data_points: filtered_data[0..999], # 첫 1000개만 (성능 고려)
          anomalies: anomalies
        }

      rescue StandardError => e
        Rails.logger.error("ECG 분석 오류: #{e.message}")
        render json: { error: '분석 중 오류가 발생했어요. 다시 시도해주세요! 🔧' }, status: :internal_server_error

      ensure
        # Zero-Retention: 메모리 즉시 해제
        GC.start
      end

      def health
        render json: { status: 'ok', timestamp: Time.now }
      end
    end
  end
end
```

#### 3-2. CORS 설정 (선택)
**파일**: `config/initializers/cors.rb`

```ruby
# 외부 프론트엔드에서 API 호출 시 필요
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins 'localhost:3000', 'your-vercel-app.vercel.app'
    resource '/api/*',
      headers: :any,
      methods: [:get, :post, :options]
  end
end
```

**의존성 추가**:
```bash
bundle add rack-cors
```

**완료 기준**:
- [ ] API Controller 구현
- [ ] 파일 업로드 처리 동작
- [ ] Service Objects 호출 성공
- [ ] JSON 응답 정상 반환

---

### Phase 4: Views 구현 (Hotwire)

#### 4-1. 메인 페이지 (파일 업로드)
**파일**: `app/views/pages/index.html.erb`

```erb
<div class="container mx-auto p-8">
  <h1 class="text-3xl font-bold mb-8">ECG Analyzer</h1>

  <div
    data-controller="upload"
    data-upload-url-value="<%= api_v1_analyze_path %>"
    class="border-4 border-dashed border-gray-300 rounded-lg p-12 text-center hover:border-blue-500"
  >
    <%= form_with url: api_v1_analyze_path, method: :post, multipart: true, data: { upload_target: "form" } do |f| %>
      <%= f.file_field :file, accept: ".wav", data: { upload_target: "input" }, class: "hidden" %>

      <div data-upload-target="dropzone" class="cursor-pointer">
        <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"></path>
        </svg>
        <p class="mt-4 text-lg text-gray-600">WAV 파일을 드래그하거나 클릭하세요</p>
        <p class="mt-2 text-sm text-gray-500">최대 50MB</p>
      </div>

      <div data-upload-target="loading" class="hidden">
        <p class="text-blue-600">분석 중... ⏳</p>
      </div>
    <% end %>
  </div>

  <!-- 결과 표시 영역 -->
  <div id="result" data-upload-target="result" class="mt-8 hidden">
    <!-- Turbo Frame으로 업데이트 -->
  </div>
</div>
```

#### 4-2. Stimulus Controller (JavaScript)
**파일**: `app/javascript/controllers/upload_controller.js`

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "form", "dropzone", "loading", "result"]
  static values = { url: String }

  connect() {
    // 드래그 앤 드롭 이벤트
    this.dropzoneTarget.addEventListener('dragover', this.preventDefaults)
    this.dropzoneTarget.addEventListener('drop', this.handleDrop.bind(this))
    this.dropzoneTarget.addEventListener('click', () => this.inputTarget.click())
  }

  preventDefaults(e) {
    e.preventDefault()
    e.stopPropagation()
  }

  handleDrop(e) {
    this.preventDefaults(e)
    const files = e.dataTransfer.files
    if (files.length > 0) {
      this.uploadFile(files[0])
    }
  }

  async uploadFile(file) {
    // 파일 검증
    if (!file.name.endsWith('.wav')) {
      alert('WAV 파일만 올릴 수 있어요! 🎵')
      return
    }

    if (file.size > 50 * 1024 * 1024) {
      alert('파일이 너무 커요! (최대 50MB)')
      return
    }

    // 로딩 상태 표시
    this.dropzoneTarget.classList.add('hidden')
    this.loadingTarget.classList.remove('hidden')

    // FormData 생성
    const formData = new FormData()
    formData.append('file', file)

    try {
      const response = await fetch(this.urlValue, {
        method: 'POST',
        body: formData,
        headers: {
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        }
      })

      if (!response.ok) {
        throw new Error('분석 실패')
      }

      const result = await response.json()
      this.displayResult(result)

    } catch (error) {
      alert('분석 중 오류가 발생했어요! 🔧')
      console.error(error)
    } finally {
      this.loadingTarget.classList.add('hidden')
      this.dropzoneTarget.classList.remove('hidden')
    }
  }

  displayResult(data) {
    // 결과 표시 (Chart.js 사용)
    this.resultTarget.classList.remove('hidden')
    this.renderChart(data)
  }

  renderChart(data) {
    // Chart.js로 그래프 그리기
    // 다음 Phase에서 구현
  }
}
```

**완료 기준**:
- [ ] 메인 페이지 View 작성
- [ ] Stimulus Controller 구현
- [ ] 파일 드래그 앤 드롭 동작
- [ ] API 호출 성공

---

### Phase 5: 그래프 시각화 (Chart.js)

#### 5-1. Chart.js 설치
```bash
# Importmap에 추가
bin/importmap pin chart.js
```

#### 5-2. Chart 렌더링
**Stimulus Controller 수정**: `app/javascript/controllers/upload_controller.js`

```javascript
import Chart from 'chart.js/auto'

// ...

renderChart(data) {
  const canvas = document.getElementById('ecgChart')
  if (!canvas) return

  // 시계열 데이터 생성
  const chartData = data.data_points.map((value, index) => ({
    x: index / data.sampling_rate,
    y: value
  }))

  new Chart(canvas, {
    type: 'line',
    data: {
      datasets: [{
        label: 'ECG Signal',
        data: chartData,
        borderColor: 'rgb(37, 99, 235)',
        borderWidth: 1,
        pointRadius: 0
      }]
    },
    options: {
      scales: {
        x: { title: { display: true, text: '시간 (초)' } },
        y: { title: { display: true, text: '진폭 (mV)' } }
      },
      plugins: {
        // 이상 구간 표시 (annotation 플러그인 필요)
      }
    }
  })
}
```

**완료 기준**:
- [ ] Chart.js 설치
- [ ] ECG 그래프 표시
- [ ] 이상 구간 붉은색으로 강조 (annotation 플러그인)

---

### Phase 6: 테스트 작성

#### 6-1. RSpec 설정
```bash
bundle add rspec-rails --group development,test
bin/rails generate rspec:install
```

#### 6-2. Service Object Test
**파일**: `spec/services/wav_parser_service_spec.rb`

```ruby
require 'rails_helper'

RSpec.describe WavParserService do
  describe '.parse' do
    let(:sample_wav) { Rails.root.join('spec', 'fixtures', 'sample.wav') }

    it 'returns parsed WAV data' do
      result = WavParserService.parse(sample_wav)

      expect(result).to include(:sampling_rate, :duration, :data)
      expect(result[:sampling_rate]).to eq(10000)
    end

    it 'raises error for non-PCM format' do
      # 구현
    end
  end
end
```

#### 6-3. Controller Test
**파일**: `spec/controllers/api/v1/analyze_controller_spec.rb`

```ruby
require 'rails_helper'

RSpec.describe Api::V1::AnalyzeController, type: :controller do
  describe 'POST #create' do
    let(:wav_file) { fixture_file_upload('sample.wav', 'audio/wav') }

    it 'returns analysis result' do
      post :create, params: { file: wav_file }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['success']).to be true
      expect(json['anomalies']).to be_an(Array)
    end

    it 'returns error for non-WAV file' do
      pdf_file = fixture_file_upload('sample.pdf', 'application/pdf')
      post :create, params: { file: pdf_file }

      expect(response).to have_http_status(:bad_request)
    end
  end
end
```

**완료 기준**:
- [ ] RSpec 설치 완료
- [ ] Service Object 테스트 작성
- [ ] Controller 테스트 작성
- [ ] 테스트 통과 (`rspec` 명령어)

---

## 🌐 배포 가이드

### Kamal 배포 (Rails 8 기본)

#### 1. deploy.yml 설정
**파일**: `config/deploy.yml` (이미 생성되어 있음)

주요 수정 사항:
- 서버 IP 주소 설정
- Docker 이미지 레지스트리 설정
- 환경변수 설정

#### 2. 배포 실행
```bash
# 초기 설정
kamal setup

# 배포
kamal deploy

# 로그 확인
kamal app logs
```

### Heroku 배포 (대안)

```bash
# Heroku CLI 설치 후
heroku create ecg-analyzer-rails
git push heroku main
heroku run rails db:migrate
heroku open
```

---

## 📋 체크리스트

### 기능 구현
- [ ] FEAT-1: 파일 업로드 (드래그 앤 드롭)
- [ ] FEAT-2: WAV 파싱 (wavefile gem)
- [ ] FEAT-2: 신호 처리 (Python 브릿지)
- [ ] FEAT-2: 이상치 탐지 (R-peak, RR 간격)
- [ ] FEAT-2: 그래프 시각화 (Chart.js)
- [ ] FEAT-2-1: 가이드 메시지 (말풍선)
- [ ] FEAT-3: 이미지 다운로드

### 코드 품질
- [ ] Rubocop 경고 없음 (`bundle exec rubocop`)
- [ ] Service Objects 패턴 적용
- [ ] Zero-Retention 메모리 관리
- [ ] 친절한 에러 메시지 (한글)

### 테스트
- [ ] RSpec 테스트 작성
- [ ] 전체 테스트 통과 (`rspec`)
- [ ] 실제 SpikerBox WAV 파일로 테스트

### 배포
- [ ] Kamal 또는 Heroku 배포 완료
- [ ] HTTPS 강제 확인
- [ ] Health check 엔드포인트 동작

---

## 🆘 예상되는 문제와 해결 방법

### 문제 1: Python 스크립트 실행 실패
**증상**: `python3: command not found`

**해결**:
1. Python 3 설치 확인: `python3 --version`
2. PATH 환경변수 확인
3. 프로덕션 환경에서는 Docker 이미지에 Python 포함

### 문제 2: wavefile gem 설치 실패
**증상**: `native extension` 빌드 오류

**해결**:
```bash
# 개발 도구 설치 (Ubuntu)
sudo apt-get install build-essential

# macOS
xcode-select --install
```

### 문제 3: 메모리 부족
**증상**: 대용량 파일 처리 시 서버 다운

**해결**:
1. Puma 워커 수 줄이기 (`config/puma.rb`)
2. 파일 크기 제한 강제 (50MB)
3. GC.start 호출로 즉시 메모리 해제

---

## 📚 참고 문서

### 필수 읽어야 할 문서
1. [Rails/README.md](README.md) - 프로젝트 개요
2. [docs/TECHNICAL_GUIDE.md](docs/TECHNICAL_GUIDE.md) - Rails 구현 가이드
3. [../docs/PRD.md](../docs/PRD.md) - 제품 요구사항
4. [../docs/Prompt_Design.md](../docs/Prompt_Design.md) - AI 개발 마일스톤

### 외부 문서
- [Rails 공식 가이드](https://guides.rubyonrails.org/)
- [Hotwire 문서](https://hotwired.dev/)
- [wavefile gem](https://github.com/jstrait/wavefile)
- [Chart.js](https://www.chartjs.org/)
- [Kamal 배포](https://kamal-deploy.org/)

---

## 🎯 최종 목표

**완성된 Rails 애플리케이션의 모습**:

1. Hotwire로 SPA 느낌의 빠른 인터랙션
2. Service Objects로 깔끔한 비즈니스 로직 분리
3. Python 브릿지로 강력한 신호 처리
4. MVC 패턴 준수로 유지보수 용이
5. Kamal로 간편한 배포

**성공 기준**:
- RSpec 테스트 전체 통과
- 10MB 파일 처리 5초 이내
- Rails Convention 준수
- Zero-Retention 아키텍처 구현

---

**행운을 빕니다, GitHub Copilot!** 🚀

질문이 있으면 [AI_COORDINATION_GUIDE.md](../AI_COORDINATION_GUIDE.md)의 이슈 보고 형식을 사용해주세요.

**작업 시작 날짜**: 2025-01-06
**PM**: ChatGPT
