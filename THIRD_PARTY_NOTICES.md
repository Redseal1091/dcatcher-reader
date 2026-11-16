# Third-Party Notices & Licenses

This project incorporates components from the following open-source projects:

---

## Mihon / Tachiyomi

- **Repository**: https://github.com/mihonapp/mihon
- **Pinned Upstream Commit**: `e588e04359fe1058206a2cbac1b01018ad787359`
- **License**: Apache License 2.0
- **Scope**:
  - `source-api` (API 1.6 compatible extension source interfaces, models, filters, Rx bridge)
  - `core/common` network, interceptor, and preference components adapted for standalone library runtime
- **License Text**: See [android/tachiyomi-runtime/LICENSE](android/tachiyomi-runtime/LICENSE)

```
Copyright 2015 Javier Tomás
Copyright 2024 Mihon Open Source Project

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```

---

## Injekt Core

- **Repository**: https://github.com/inorichi/injekt
- **Artifact**: `uy.kohesive.injekt:injekt-core:1.16.1`
- **License**: Apache License 2.0
- **Scope**: Dependency injection bridge used by Tachiyomi / Keiyoushi extensions

---

## Square OkHttp, OkHttp-Brotli, OkHttp-Zstd

- **Repository**: https://github.com/square/okhttp
- **Artifacts**: `com.squareup.okhttp3:okhttp:5.4.0`, `com.squareup.okhttp3:okhttp-brotli:5.4.0`, `com.squareup.okhttp3:okhttp-zstd:5.4.0`
- **License**: Apache License 2.0
- **Scope**: HTTP client, network logging, and CompressionInterceptor with Gzip, Deflate, Brotli, and Zstd codecs required by Keiyoushi KeiSource runtime
