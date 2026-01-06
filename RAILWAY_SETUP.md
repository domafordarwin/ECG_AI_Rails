# Railway 배포 가이드

## 🚀 단계별 Railway 배포 설정

### Step 1: Railway 프로젝트 준비

1. [Railway 웹사이트](https://railway.app) 로그인
2. **"New Project"** 클릭
3. **"Deploy from GitHub repo"** 선택
4. 해당 GitHub 저장소 선택
5. Railway가 자동으로 코드를 감지하고 빌드 시작

---

### Step 2: PostgreSQL 데이터베이스 추가 (필수)

1. Railway 프로젝트 대시보드에서 **"New"** 버튼 클릭
2. **"Database"** 선택
3. **"Add PostgreSQL"** 클릭
4. PostgreSQL 서비스가 생성되면 자동으로 연결됨
5. ✅ `DATABASE_URL` 환경 변수가 자동으로 설정됩니다

**중요**: PostgreSQL과 Rails 앱 서비스가 같은 프로젝트 내에 있어야 자동으로 연결됩니다.

---

### Step 3: 환경 변수 설정 (필수)

#### 3-1. Railway 서비스 선택
- Railway 대시보드에서 **Rails 앱 서비스** (GitHub 저장소 이름)를 클릭

#### 3-2. Variables 탭 열기
- 상단 탭에서 **"Variables"** 클릭

#### 3-3. 환경 변수 추가
**"New Variable"** 또는 **"Raw Editor"** 버튼을 클릭하여 다음 변수들을 추가:

```bash
# 필수 환경 변수 (Rails Credentials 방식 - 권장)
RAILS_MASTER_KEY=19c27d29800feef97ee796a9ff71ee55
RAILS_ENV=production
RAILS_LOG_TO_STDOUT=true
RAILS_SERVE_STATIC_FILES=true
```

#### 각 변수 설명:

| 변수 이름 | 값 | 설명 |
|---------|-----|-----|
| `RAILS_MASTER_KEY` | `19c27d29800feef97ee796a9ff71ee55` | Rails credentials 복호화 키 (`config/master.key` 내용) |
| `RAILS_ENV` | `production` | Rails 실행 환경 |
| `RAILS_LOG_TO_STDOUT` | `true` | Railway 로그에 출력 활성화 |
| `RAILS_SERVE_STATIC_FILES` | `true` | 정적 파일 제공 활성화 |

**중요**: `RAILS_MASTER_KEY`는 `config/master.key` 파일의 내용입니다. 이 키로 `config/credentials.yml.enc`를 복호화하여 `secret_key_base`를 포함한 모든 민감한 설정을 읽습니다.

#### 3-4. 변수 저장
- **Raw Editor 사용 시**: 위의 4줄을 모두 붙여넣고 **"Update Variables"** 클릭
- **개별 추가 시**: 각 변수를 하나씩 추가

---

### Step 4: 배포 확인

1. 환경 변수를 저장하면 **자동으로 재배포**가 시작됩니다
2. **"Deployments"** 탭에서 배포 진행 상황 확인
3. **"View Logs"** 클릭하여 빌드 및 실행 로그 확인
4. 배포 성공 시 **"Settings"** → **"Domains"**에서 URL 확인

---

### Step 5: 도메인 확인 및 테스트

1. **"Settings"** 탭 → **"Networking"** 섹션
2. **"Generate Domain"** 클릭 (아직 없다면)
3. 생성된 URL (예: `your-app.up.railway.app`) 복사
4. 브라우저에서 접속하여 앱 동작 확인

---

## 🔧 선택적 설정

### CORS 설정 (프론트엔드가 별도 도메인인 경우)

Variables 탭에서 추가:
```
CORS_ORIGINS=https://your-frontend-domain.com,https://another-domain.com
```

그리고 `config/initializers/cors.rb`를 수정:
```ruby
origins ENV.fetch('CORS_ORIGINS', 'http://localhost:3000').split(',')
```

---

## 🎯 환경 변수 설정 스크린샷 가이드

### Raw Editor 방법 (권장):
1. Variables 탭 → **"Raw Editor"** 버튼 클릭
2. 다음 내용을 **그대로 복사하여 붙여넣기**:
```
RAILS_MASTER_KEY=19c27d29800feef97ee796a9ff71ee55
RAILS_ENV=production
RAILS_LOG_TO_STDOUT=true
RAILS_SERVE_STATIC_FILES=true
```
3. **"Update Variables"** 클릭
4. 자동 재배포 시작

### 개별 추가 방법:
1. Variables 탭 → **"New Variable"** 클릭
2. Variable Name: `RAILS_MASTER_KEY`
3. Variable Value: `19c27d29800feef97ee796a9ff71ee55` (로컬의 `config/master.key` 내용)
4. **"Add"** 클릭
5. 나머지 3개 변수도 같은 방식으로 추가

## PostgreSQL로 마이그레이션 (권장)

Railway에서는 PostgreSQL 사용을 강력히 권장합니다.

**✅ pg gem은 이미 Gemfile에 추가되어 있습니다!**

### Railway PostgreSQL 플러그인 추가
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
