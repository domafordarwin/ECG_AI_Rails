# ECG Analyzer - Rails 풀스택 프로젝트

Backyard Brains SpikerBox 심전도 분석 웹 애플리케이션 (교육용)

## 🎯 프로젝트 개요

이 프로젝트는 **Ruby on Rails의 MVC 패턴**을 활용한 풀스택 구조입니다.
프론트엔드(Hotwire)와 백엔드(Rails API)가 하나의 애플리케이션으로 통합되어 있습니다.

## 📁 프로젝트 구조

```
Rails/
├── app/
│   ├── controllers/
│   │   ├── application_controller.rb
│   │   ├── pages_controller.rb         # 메인 페이지 (파일 업로드)
│   │   └── api/
│   │       └── v1/
│   │           └── analyze_controller.rb  # WAV 분석 API
│   ├── models/
│   │   └── system_log.rb               # 시스템 로그 (선택)
│   ├── views/
│   │   └── pages/
│   │       ├── index.html.erb          # 메인 UI
│   │       └── result.html.erb         # 분석 결과
│   ├── services/
│   │   ├── wav_parser_service.rb       # WAV 파일 파싱
│   │   ├── signal_processor_service.rb # 신호 처리
│   │   └── anomaly_detector_service.rb # 이상치 탐지
│   ├── javascript/
│   │   ├── controllers/
│   │   │   └── upload_controller.js    # Stimulus 컨트롤러
│   │   └── application.js
│   └── assets/
│       └── stylesheets/
│           └── application.css
├── config/
│   ├── routes.rb
│   └── initializers/
│       └── cors.rb
├── db/
│   └── migrate/
├── docs/
│   └── TECHNICAL_GUIDE.md              # 기술 가이드
└── Gemfile
```

## 🚀 빠른 시작 (Quick Start)

### 사전 요구사항
- **Ruby 3.2+**
- **Bundler**
- **SQLite3**

### 1️⃣ 의존성 설치

```bash
# Ruby Gem 설치
bundle install

# 데이터베이스 준비
bin/rails db:prepare
```

### 2️⃣ 개발 서버 실행

```bash
# Rails 서버 실행 (포트 3000)
bin/rails server
```

브라우저에서 http://localhost:3000 접속

### 3️⃣ 추가 Gem 설치 (WAV 분석용)

```bash
# Gemfile에 추가
bundle add wavefile rack-cors

# 설치
bundle install
```

## 📦 기술 스택

### Frontend (내장)
- **Hotwire (Turbo + Stimulus)** - SPA 느낌의 인터랙션
- **Importmap** - JavaScript 모듈 관리
- **Tailwind CSS** (선택) - 스타일링
- **Chart.js** (선택) - 그래프 시각화

### Backend (Rails)
- **Ruby 3.2.9**
- **Rails 8.1.1** (MVC 프레임워크)
- **SQLite3** - 로그용 DB (선택)
- **Puma** - 웹 서버
- **wavefile** - WAV 파일 파싱

### 신호 처리 옵션
1. **Ruby 네이티브**: numo-narray, numo-fftw
2. **Python 브릿지**: Python 스크립트 호출 (SciPy 활용)

## 🎓 학습 목표

이 풀스택 프로젝트로 다음을 학습할 수 있습니다:

### 프론트엔드 (Hotwire)
- ✅ Stimulus 컨트롤러로 파일 업로드 UI
- ✅ Turbo Frame으로 부분 페이지 업데이트
- ✅ Chart.js로 그래프 시각화
- ✅ 반응형 디자인 (태블릿 최적화)

### 백엔드 (Rails)
- ✅ MVC 패턴 이해
- ✅ RESTful API 설계 (API::V1::AnalyzeController)
- ✅ Service Object 패턴 (WAV 파싱, 신호 처리)
- ✅ 파일 업로드 처리 (ActiveStorage 또는 Direct Upload)
- ✅ CORS 설정 (외부 API 호출 대비)

### 풀스택 통합 (Rails 특유)
- ✅ 하나의 서버에서 프론트+백 제공
- ✅ Hotwire로 SPA 느낌 구현
- ✅ Zero-Retention 아키텍처 구현
- ✅ Kamal로 배포

## 📚 상세 문서

- **[Rails 기술 가이드](docs/TECHNICAL_GUIDE.md)** - Rails 구현 상세
- **[프로젝트 요구사항 (PRD)](../docs/PRD.md)** - 제품 정의
- **[기술 요구사항 (TRD)](../docs/TRD.md)** - 기술 스펙

## 🧪 테스트

```bash
# 전체 테스트 실행
bin/rails test

# 특정 컨트롤러 테스트
bin/rails test test/controllers/api/v1/analyze_controller_test.rb

# RSpec 사용 시 (추가 설치 필요)
bundle add rspec-rails --group development,test
bin/rails generate rspec:install
rspec
```

## 🌐 배포

### Kamal (추천 - Rails 8 기본)

```bash
# .kamal/deploy.yml 설정 후
kamal setup
kamal deploy
```

### Heroku

```bash
# Heroku CLI 설치 후
heroku create your-app-name
git push heroku main
heroku run rails db:migrate
```

### Docker

```bash
# Dockerfile 사용
docker build -t ecg-analyzer-rails .
docker run -p 3000:3000 ecg-analyzer-rails
```

## 🆘 문제 해결

### WAV 파일 파싱 오류
- `wavefile` gem 설치 확인: `bundle list | grep wavefile`
- PCM 포맷만 지원, 압축된 WAV 파일은 거부됨

### Python 스크립트 호출 실패
- Python 3가 설치되어 있는지 확인: `python3 --version`
- SciPy 설치: `pip install scipy numpy`

### CORS 오류 (외부 API 테스트 시)
- `config/initializers/cors.rb` 설정 확인
- `rack-cors` gem 설치 확인

### 메모리 부족
- Puma 워커 수를 줄이기: `config/puma.rb`에서 `workers` 값 조정
- `GC.start` 명시적 호출로 메모리 해제

## 🔄 Next.js 프로젝트와 비교

| 항목 | Next.js + FastAPI | Rails 풀스택 |
|------|------------------|-------------|
| **구조** | 프론트/백 분리 | MVC 통합 |
| **언어** | TypeScript + Python | Ruby |
| **프론트 기술** | React | Hotwire (Turbo/Stimulus) |
| **배포** | Vercel + Cloud Run | Kamal, Heroku |
| **학습 곡선** | 모던 웹 스택 | Rails Convention |
| **신호 처리** | SciPy 네이티브 ⭐ | Python 브릿지 필요 |

### 언제 Rails를 선택할까?
- Ruby 생태계를 선호할 때
- MVC 패턴을 배우고 싶을 때
- 빠른 프로토타이핑이 필요할 때
- Hotwire로 SPA 느낌을 원할 때

### 신호 처리는 Python이 유리
Rails로 구현할 경우, 복잡한 신호 처리(Bandpass Filter, R-peak 검출)는 Python 스크립트를 호출하는 것을 권장합니다.

## 📞 참고 링크

- [Rails 공식 가이드](https://guides.rubyonrails.org/)
- [Hotwire 공식 문서](https://hotwired.dev/)
- [wavefile gem](https://github.com/jstrait/wavefile)
- [Kamal 배포 가이드](https://kamal-deploy.org/)

## 💡 추가 개선 아이디어

- [ ] ActiveStorage로 파일 업로드 개선
- [ ] Turbo Stream으로 실시간 분석 진행률 표시
- [ ] Stimulus Reflex로 더 인터랙티브한 UI
- [ ] Chart.js 대신 Chartkick gem 사용
- [ ] Background Job (Solid Queue)로 대용량 파일 처리

