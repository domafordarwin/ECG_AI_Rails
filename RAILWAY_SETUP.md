# Railway 배포 가이드

## 필수 환경 변수 설정

Railway 대시보드에서 다음 환경 변수들을 설정해주세요:

### 1. 기본 Rails 환경 변수
```
RAILS_ENV=production
RAILS_LOG_TO_STDOUT=true
RAILS_SERVE_STATIC_FILES=true
```

### 2. Secret Key Base (필수)
```bash
# 로컬에서 생성:
rails secret
```
생성된 값을 Railway에 설정:
```
SECRET_KEY_BASE=<생성된_시크릿_키>
```

### 3. 데이터베이스 설정

#### Option A: Railway PostgreSQL 사용 (권장)
Railway에서 PostgreSQL 플러그인을 추가하면 자동으로 `DATABASE_URL`이 설정됩니다.

#### Option B: SQLite 사용 (Volume 필요)
SQLite를 계속 사용하려면 Railway Volume을 마운트해야 합니다:
1. Railway 대시보드에서 Volume 생성
2. 마운트 경로: `/rails/storage`

### 4. CORS 설정 (선택)
프론트엔드 도메인이 있다면:
```
CORS_ORIGINS=https://your-frontend-domain.com
```

그리고 `config/initializers/cors.rb`를 수정:
```ruby
origins ENV.fetch('CORS_ORIGINS', 'http://localhost:3000').split(',')
```

## PostgreSQL로 마이그레이션 (권장)

Railway에서는 PostgreSQL 사용을 강력히 권장합니다.

### 1. Gemfile에 pg gem 추가
```ruby
gem "pg", "~> 1.5"
```

### 2. bundle install 실행
```bash
bundle install
```

### 3. Railway PostgreSQL 플러그인 추가
Railway 대시보드에서:
- "New" → "Database" → "Add PostgreSQL"
- 자동으로 `DATABASE_URL` 환경 변수가 설정됩니다

### 4. 배포
변경사항을 커밋하고 푸시하면 자동으로 재배포됩니다.

## 문제 해결

### "config/environment.rb:5" 에러
원인:
- DATABASE_URL 환경 변수가 설정되지 않음
- SECRET_KEY_BASE가 설정되지 않음
- PostgreSQL 연결 실패

해결:
1. Railway 로그에서 정확한 에러 메시지 확인
2. 위의 환경 변수들이 모두 설정되었는지 확인
3. PostgreSQL 플러그인이 추가되고 연결되었는지 확인

### 이미지 처리 에러
libvips 관련 에러가 발생하면 Dockerfile에 이미 libvips가 포함되어 있으므로 무시해도 됩니다.

## 배포 확인

배포 후 Railway가 제공하는 URL로 접속해서 애플리케이션이 정상 작동하는지 확인하세요.
