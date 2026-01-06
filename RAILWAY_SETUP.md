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
# 필수 환경 변수
SECRET_KEY_BASE=ae5886e431c9962d278e15fb3bddd35ebe98319dae7de6d5a1a7f0c8099c599399e61cfdf9d4343f489f8c73ac91dced65f7bb3a9fb789cd78e8e13bfec93501
RAILS_ENV=production
RAILS_LOG_TO_STDOUT=true
RAILS_SERVE_STATIC_FILES=true
```

#### 각 변수 설명:

| 변수 이름 | 값 | 설명 |
|---------|-----|-----|
| `SECRET_KEY_BASE` | 위의 긴 문자열 | Rails 세션 암호화 키 (위 값 그대로 복사) |
| `RAILS_ENV` | `production` | Rails 실행 환경 |
| `RAILS_LOG_TO_STDOUT` | `true` | Railway 로그에 출력 활성화 |
| `RAILS_SERVE_STATIC_FILES` | `true` | 정적 파일 제공 활성화 |

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
SECRET_KEY_BASE=ae5886e431c9962d278e15fb3bddd35ebe98319dae7de6d5a1a7f0c8099c599399e61cfdf9d4343f489f8c73ac91dced65f7bb3a9fb789cd78e8e13bfec93501
RAILS_ENV=production
RAILS_LOG_TO_STDOUT=true
RAILS_SERVE_STATIC_FILES=true
```
3. **"Update Variables"** 클릭
4. 자동 재배포 시작

### 개별 추가 방법:
1. Variables 탭 → **"New Variable"** 클릭
2. Variable Name: `SECRET_KEY_BASE`
3. Variable Value: `ae5886e431c9962d278e15fb3bddd35ebe98319dae7de6d5a1a7f0c8099c599399e61cfdf9d4343f489f8c73ac91dced65f7bb3a9fb789cd78e8e13bfec93501`
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

---

## ❌ 문제 해결 (Troubleshooting)

### 에러 1: `Missing 'secret_key_base' for 'production' environment`

**증상**:
```
ArgumentError: Missing `secret_key_base` for 'production' environment
```

**원인**: `SECRET_KEY_BASE` 환경 변수가 설정되지 않음

**해결**:
1. Railway 대시보드 → 해당 서비스 클릭
2. **"Variables"** 탭 클릭
3. `SECRET_KEY_BASE` 변수가 있는지 확인
4. 없다면 위의 **Step 3**을 따라 추가
5. 저장 후 자동 재배포 대기

---

### 에러 2: `Tasks: TOP => db:prepare => db:load_config => environment`

**증상**:
```
bin/rails aborted!
Tasks: TOP => db:prepare => db:load_config => environment
```

**원인**:
- PostgreSQL이 추가되지 않음
- `DATABASE_URL` 환경 변수가 없음
- `pg` gem이 설치되지 않음 (✅ 이미 해결됨)

**해결**:
1. Railway 대시보드에서 **PostgreSQL 서비스가 있는지 확인**
2. 없다면 **"New"** → **"Database"** → **"Add PostgreSQL"**
3. PostgreSQL 서비스를 클릭하여 **"Variables"** 탭 확인
4. `DATABASE_URL` 값을 복사
5. Rails 앱 서비스로 돌아가서 **"Variables"** 탭 확인
6. `DATABASE_URL`이 자동으로 추가되었는지 확인 (같은 프로젝트 내에서는 자동 연결됨)

---

### 에러 3: PostgreSQL 연결 실패

**증상**:
```
PG::ConnectionBad: could not connect to server
```

**원인**: PostgreSQL과 Rails 앱이 서로 연결되지 않음

**해결**:
1. Railway 프로젝트 대시보드에서 두 서비스가 **같은 프로젝트 내에** 있는지 확인
2. PostgreSQL 서비스 클릭 → **"Connect"** 탭
3. Rails 앱 서비스와 연결되어 있는지 확인
4. 연결되지 않았다면 **"Link to this service"** 클릭하여 Rails 앱 선택

---

### 에러 4: 빌드는 성공하지만 서버가 시작되지 않음

**증상**: Build 성공, 하지만 "Starting Container" 이후 에러

**확인 사항**:
1. **"Deployments"** 탭 → 최신 배포 클릭 → **"View Logs"**
2. 로그에서 실제 에러 메시지 확인
3. 대부분 환경 변수 누락 문제

**체크리스트**:
- [ ] `SECRET_KEY_BASE` 설정됨
- [ ] `RAILS_ENV=production` 설정됨
- [ ] `RAILS_LOG_TO_STDOUT=true` 설정됨
- [ ] `RAILS_SERVE_STATIC_FILES=true` 설정됨
- [ ] PostgreSQL 서비스 추가됨
- [ ] `DATABASE_URL` 자동 설정됨 (Variables 탭에서 확인)

---

### 에러 5: 이미지 처리 관련 경고

**증상**:
```
VIPS-WARNING: unable to load vips-heif.dll
```

**해결**: 이것은 **경고이지 에러가 아닙니다**. 무시해도 됩니다. Dockerfile에 이미 libvips가 포함되어 있으며, 기본 이미지 포맷(JPG, PNG)은 정상 작동합니다.

---

## ✅ 배포 완료 체크리스트

배포가 성공적으로 완료되었는지 확인:

1. [ ] Railway에서 PostgreSQL 서비스 추가됨
2. [ ] 4개의 필수 환경 변수 설정됨
   - [ ] `SECRET_KEY_BASE`
   - [ ] `RAILS_ENV`
   - [ ] `RAILS_LOG_TO_STDOUT`
   - [ ] `RAILS_SERVE_STATIC_FILES`
3. [ ] 빌드 성공 (Deployments 탭에서 초록색 체크)
4. [ ] 컨테이너 시작 성공 (로그에서 "Listening on" 확인)
5. [ ] 도메인 URL로 접속 가능
6. [ ] 앱 홈페이지 정상 표시

---

## 🔍 유용한 Railway 명령어

### 로그 실시간 확인
Railway 대시보드 → Deployments → View Logs → **"Follow"** 토글 활성화

### 환경 변수 확인
Variables 탭에서 모든 설정된 변수 확인 (값은 숨겨짐, 클릭하면 표시)

### 데이터베이스 연결 확인
PostgreSQL 서비스 → Connect 탭 → Connection String 복사하여 로컬에서 테스트 가능

---

## 📞 추가 도움이 필요한 경우

1. Railway 로그 전체 복사
2. 어떤 단계에서 막혔는지 설명
3. 환경 변수 설정 스크린샷 (값은 가려서)
