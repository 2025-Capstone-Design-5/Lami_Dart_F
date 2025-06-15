# Lami - 스마트 교통 알람 앱

## 소개

Lami는 사용자의 일정과 교통 상황을 고려하여 최적의 출발 시간을 알려주는 스마트 교통 알람 앱입니다. Google Calendar와 연동하여 일정을 관리하고, 실시간 교통 정보를 활용하여 정확한 이동 시간을 계산합니다.

## 주요 기능

### 1. 스마트 알람 시스템
- 도착 시간과 준비 시간을 설정하면 최적의 출발 시간에 알람 제공
- 실시간 교통 상황을 반영한 알람 시간 조정
- 로컬 알림 및 소리/진동 알람 지원

### 2. 경로 검색 및 즐겨찾기
- TMap API를 활용한 정확한 경로 검색
- 자주 사용하는 경로 즐겨찾기 기능
- 카테고리별 즐겨찾기 관리

### 3. Google Calendar 연동
- Google 계정 로그인 및 캘린더 연동
- 캘린더 일정 기반 알람 설정
- 일정 관리 및 조회 기능

### 4. 개인화된 경험
- 사용자별 설정 저장
- 오프라인 모드 지원 (로컬 데이터 캐싱)
- 직관적인 UI/UX

## 기술 스택

- **프론트엔드**: Flutter (Dart)
- **백엔드 연동**: RESTful API
- **인증**: Google OAuth
- **지도 및 경로**: TMap API
- **캘린더**: Google Calendar API
- **로컬 알림**: flutter_local_notifications
- **상태 관리**: Provider

## 설치 및 실행

### 요구사항
- Flutter SDK 3.7.2 이상
- Dart SDK 3.7.2 이상
- Android Studio 또는 VS Code
- Android/iOS 개발 환경

### 환경 설정

1. 프로젝트 루트에 `.env` 파일을 생성하고 다음 환경변수를 설정합니다:

```
ANDROID_CLIENT_ID=your_android_client_id
IOS_CLIENT_ID=your_ios_client_id
REDIRECT_URI=your_redirect_uri
TMAP_API_KEY=your_tmap_api_key
BACKEND_URL=your_backend_url
BACKEND_URL_ANDROID=your_android_backend_url
BACKEND_URL_IOS=your_ios_backend_url
```

2. 필요한 패키지 설치:

```bash
flutter pub get
```

3. 앱 실행:

```bash
flutter run
```

## 프로젝트 구조

```
lib/
├── config/              # 서버 설정 및 환경 변수
├── models/              # 데이터 모델
├── pages/               # 화면 UI
│   ├── assistant/       # 어시스턴트 화면
│   ├── auth/            # 인증 관련 화면
│   ├── calendar/        # 캘린더 화면
│   ├── favorite/        # 즐겨찾기 화면
│   ├── home/            # 홈 화면
│   ├── my/              # 마이페이지
│   ├── route/           # 경로 화면
│   ├── search/          # 검색 화면
│   └── time_setting/    # 시간 설정 화면
├── services/            # API 서비스
│   ├── agent_service.dart
│   ├── alarm_api_service.dart
│   ├── auth_service.dart
│   ├── calendar_service.dart
│   ├── favorite_api_service.dart
│   ├── notification_service.dart
│   └── tmap_service.dart
└── widgets/             # 재사용 가능한 위젯
```


