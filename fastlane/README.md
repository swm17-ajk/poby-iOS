# fastlane

## TestFlight 배포

로컬에서 실행:

```sh
bundle install
bundle exec fastlane ios beta
```

GitHub Actions에서는 `main` 브랜치에 push되거나 수동 실행할 때 TestFlight로 업로드합니다.

## 필요한 값

App Store Connect에서 API 키를 만들고 아래 값을 CI secret 또는 로컬 환경변수로 설정합니다.

- `APP_STORE_CONNECT_KEY_ID`: API key ID
- `APP_STORE_CONNECT_ISSUER_ID`: issuer ID
- `APP_STORE_CONNECT_KEY_CONTENT`: `.p8` 키 파일 내용. GitHub Actions에서는 base64 인코딩 값을 넣습니다.
- `AMPLITUDE_API_KEY`: 앱 빌드에 필요한 Amplitude API 키

GitHub secret에 `.p8` 파일을 넣을 때:

```sh
base64 -i AuthKey_XXXXXXXXXX.p8 | pbcopy
```

로컬에서 raw `.p8` 내용을 그대로 넣는 경우 `APP_STORE_CONNECT_KEY_CONTENT_BASE64`를 설정하지 않아도 됩니다. base64 값을 넣는 경우에는 `APP_STORE_CONNECT_KEY_CONTENT_BASE64=true`를 함께 설정합니다.
