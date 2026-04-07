# Changelog

All notable changes to this project will be documented in this file.



## [0.43.0](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.42.0...v0.43.0) - 2026-04-07 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.43.0))

### ⚡ Performance

- Add 4 composite indexes for common query patterns ([bc407fc](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/bc407fcc48e8169556f1fcca516e80daa16ab3e4))
- Add Redis cache for episode detail with 5-minute TTL ([a5c500c](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/a5c500cc63898f82935f7d524008262e4afe5d6a))
- Add Redis caches for highlight dates (10m TTL) and playback rate (30m TTL) ([ef3f444](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/ef3f4448b28a4f88b74c89c9802d83e66428ab88))
- Migrate large ListView(children:) to ListView.builder for lazy rendering ([e826b64](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/e826b64af266e6b55582afa973476464dc613b76))

### 🎨 Styling

- Replace hardcoded BorderRadius.circular with AppRadius tokens ([6d7c936](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/6d7c9363d3fcd0a33ed32a26f6764e69b44fff92))

### 🐛 Bug Fixes

- *(security)* Remove partial API key from info-level log ([7309094](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/73090947dda6b400327b001577682036a77019b8))
- Narrow bare except Exception to specific types in service layer ([2553f40](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/2553f4077755d015da011fcd2360f1b0ed22b0b6))

### 📚 Documentation

- Add incremental optimization design spec ([640a9e8](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/640a9e80429c19787aa013ba99ad580c6d88f810))
- Add incremental optimization implementation plan ([bbf27ea](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/bbf27ea7a80100476eaa554da80c5522d73a841b))

### 🚀 Features

- Add typed response models for subscription delete/refresh/reparse endpoints ([cd6cc26](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/cd6cc2636dd61ce5fc46f7f39cd3b87f6bea9e73))

### 🚜 Refactor

- Split podcast_queue_sheet.dart into focused sub-widgets ([a467175](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/a467175911de0ebd37a2fbbad5a5ac04f36b0134))
- Split transcription_status_widget.dart into focused sub-widgets ([9fe7470](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/9fe74702354349f27def0c97f6b60f2050e6a0e7))



## [0.42.0](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.41.0...v0.42.0) - 2026-04-07 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.42.0))

### ⚙️ Miscellaneous Tasks

- Remove docs/superpowers from git tracking and add to gitignore ([780a52e](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/780a52e8d9e0f4481e34b6fa103d0ed8d21d3ef8))
- Create media and content domain directory structure ([2a0c3ed](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/2a0c3ed7b761f20fd61fe24e2e452750445db8d3))
- Remove unused openai dependency ([a1aa329](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/a1aa329bad07c21b26236567c8983066c789236a))

### ⚡ Performance

- Wrap blocking I/O with async alternatives in HTTP request paths ([17c3064](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/17c3064d186f2002587cb0a78a5f21acf31a1325))
- Fix N+1 query issues and add missing join indexes ([e17110a](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/e17110a9e98c65018324493e862dd706ae457290))

### 🐛 Bug Fixes

- Narrow bare except Exception to specific types in security and parsing ([9eb5683](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/9eb5683e53a8a0fe8a82586199f05cfea5816d14))
- Populate in-memory token cache after registration ([8a7c93e](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/8a7c93e96ee6140f638b5ad20e4ba4716bc0d948))
- Narrow remaining bare except Exception in service layer ([e907d4f](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/e907d4fbef19ceee74b6b624188479810b17e2c0))

### 🚀 Features

- Add Drift index on episodes_cache, eviction method, and filtered watch ([c48ee2d](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/c48ee2d44b5bf472378d25cad84cd78481f595c0))

### 🚜 Refactor

- Extract UrlNormalizer utility from 3 duplicated locations ([70cc9d8](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/70cc9d858324a22da93e295f374259fac922f573))
- Split podcast_list_page into focused sub-widget sections ([91efcd0](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/91efcd018eb9fe4d0403dd7396339eeec9fcb12e))
- Upgrade python-jose to PyJWT (maintained alternative) ([a500215](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/a500215a87567659d6b4216cc37c45698c579e1f))
- Replace passlib with direct bcrypt usage ([9100dd1](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/9100dd187124c229037423576c1633e059cc47bb))
- Migrate profile_page setState to Riverpod providers ([0150c8e](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/0150c8e0997d694baf6215a087c430b1118d2be2))
- Extract shared exception message parser from 7 fromDioError methods ([1ce8b8f](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/1ce8b8f958be8ac9bf1af04d945bb44b85b1b9b2))
- Migrate AI config cost/temperature columns from String to Float ([718f893](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/718f893ddc99b0af2d95c78a61b3dc8dc4f2e9cd))
- Decompose transcription.py into media/transcription/ package (7 modules) ([328f6bf](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/328f6bffd5254069b5c37104143dbc675e2bc5d3))
- Convert DownloadDao status from string to integer enum ([8d2b2f6](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/8d2b2f6e260486a93b8230883204a4ab6b51ef81))
- Migrate auth_verify_page setState to Riverpod providers ([1836606](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/1836606dfc473bc31b6a82a42f45bc4130cd579f))
- Add userMessage getter to AppException, consolidate error formatting ([b3cde92](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/b3cde92d18abf8031d71b6cab28a21a4b834286b))
- Replace PodcastFeedNotifier manual dedup with DeduplicatingNotifier mixin ([9bdb6dc](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/9bdb6dcdf85adc4a5c0a3cfdd256ee2489ad0ae1))
- Unify http error helpers to raise BaseCustomError subclasses ([f21557c](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/f21557c45f32009915ac833fbe63261269bb0d5c))
- Extract shared AI HTTP request helpers in ai_client ([3509fc4](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/3509fc4a2d44153c1b64b96d1d7a866de98d1d8e))
- Split podcast/models.py into per-domain model files ([7f3ebf1](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/7f3ebf1cc6b5c7e6e2bbed4261c65cad1a68475b))
- Add backward-compatible domain proxy files for media/content split ([7799bfd](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/7799bfdf6b700b243e23b674079b016d31d42b07))
- Extract DiscoverInteractionHandler from podcast_list_page ([dab2537](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/dab253715e07d60e6251fcf99ed205d8bf150bf8))

### 🧪 Testing

- Remove 3 redundant frontend test files ([7681e47](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/7681e4781f71c4f9c7aa41786d10776d4dfcb950))
- Merge 5 episode detail page tests into 2 files with shared helper ([8a2ab2c](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/8a2ab2cfdca3064e700445799b12c7acbe8c355b))
- Merge episode_description tests into simplified_episode_card_layout_test ([66b2573](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/66b257302460697dcea12e0a99fb2289c4f0e45e))
- Merge 2 podcast feed page tests into 1 file ([70ae583](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/70ae583327ebbe080a0756c6d9e90301e3c74695))
- Merge 6 podcast list page tests into 2 files with shared helper ([fa0f171](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/fa0f17110e0bd0aa9ff1382922e75786ccf0edde))
- Add unit tests for all 3 Drift DAOs ([7d8665c](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/7d8665ce0365712215a3a3a4cdb485f6549985f6))



## [0.41.0](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.40.0...v0.41.0) - 2026-04-06 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.41.0))

### Merge

- Feat/arc-linear-ui-redesign into main ([7d66df6](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/7d66df6b08d88e619c4743bd933d734fdb4eaf6b))

### ⚙️ Miscellaneous Tasks

- Apply dart fixes and remove old design system comments ([96ada14](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/96ada1475de6eef2e09a87166de8fd3e919f5c98))

### 🐛 Bug Fixes

- Clarify build number rule in release skill ([d2f9307](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/d2f93073e289c8f80ebde45b88d0d48c86e73528))
- *(glass)* Improve light mode contrast with lower fill opacity ([02a69cc](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/02a69cc3229b0af39849fdc25efca88d53b2e8c2))
- *(backend)* Pre-launch audit — resolve critical stability and security, and performance issues ([a696f88](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/a696f8812d259a33f12bffb9c69f5ad43988f16d))
- *(backend)* Pre-launch audit — resolve HIGH/MEDIUM/LOW issues across all layers ([9d87cc8](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/9d87cc8f62f418410df8b0021fd76a7abf5c89e6))
- *(alembic)* Mock security as package for sub-module imports ([1d68b4d](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/1d68b4dccda4eada361f99fc5fc0958d8bcbdf39))
- *(glass)* Fix compilation errors from agent migration ([6fcc355](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/6fcc355239662d64fab8116e94fb29323189b78a))
- *(admin)* Update TemplateResponse calls for Starlette 1.0 signature ([139dca6](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/139dca69d095f85d5f87ee3aa08642697491a049))
- *(backend)* Resolve audit findings — broken import, crashes, info leaks, N+1 query, test failures ([9eacbb7](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/9eacbb7ed912969a61eae45fe7c06958f2231b48))
- *(auth)* Widen session_token/refresh_token columns from VARCHAR(255) to TEXT ([8a0dd51](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/8a0dd51998e3b5509c6a0046b02e318d0ae42a69))
- *(podcast)* Eagerly load transcript to fix MissingGreenlet in Celery worker ([cd51ca5](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/cd51ca598ef9cb1ef74d5910ed9b5129fb844316))
- *(glass)* Fix AppleColors API and test compilation errors ([724f4f2](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/724f4f2df92be67cb56930675975adf471d71f7c))
- *(podcast)* Update remaining widget files with new tokens ([143b0fe](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/143b0fedea627fc2dc9112323f92d5a99c981f7c))
- *(podcast)* Update highlight detail sheet border radius values ([c524e1d](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/c524e1d89950082f3d08c0bcac977e5162e2946d))
- *(tests)* Fix compilation errors in test files ([424a28f](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/424a28f242cfcd19947523c5ee22aa69d0123c71))
- *(auth)* Prevent text overflow in register page ([7fed1d6](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/7fed1d6b15a873a38915cc83a612a1201251c057))
- *(tests)* Fix highlight_detail_sheet and register_page overflow ([1aaec03](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/1aaec03cfef57ef6ba150427637a728266b68b8d))

### 📚 Documentation

- Update README.md for v0.40.0 release ([dcf32d7](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/dcf32d7e1046a85c6f8b31c5117cbcbf311b691b))
- Add Liquid Glass redesign design spec ([0f70c54](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/0f70c5405fb3bf7cf2587b31984a4899ef4c8e67))
- Add Liquid Glass redesign design spec ([37213c3](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/37213c3937c4953a27f954189c7ef7cabce5930a))
- Add Liquid Glass redesign implementation plan ([26ffc4e](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/26ffc4ed47dcd2d3595a4e33e04f0b8661744d37))
- Add CLAUDE.md rewrite design spec ([7e6bd37](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/7e6bd3767092e69131969ce28ce0fdadad521b6c))
- Rewrite CLAUDE.md following Anthropic best practices ([917cdac](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/917cdac69eb8c5764c93c82940488eb6a6e83013))

### 🚀 Features

- *(ui)* Implement Apple Liquid Glass design system ([c4f858f](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/c4f858f501ca4e4aeabf7aecba60cf371cf57849))
- *(ui)* Integrate Liquid Glass into navigation and background ([b210c42](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/b210c4287008d38474d30ba58db0a7a5ae228b37))
- *(ui)* Migrate feature widgets to LiquidGlassContainer and enhance core glass effects ([91ce955](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/91ce955850f153cd91d4bec1247738f7301d9ae4))
- *(glass)* Add GlassTier enum and GlassTokens ([c0c278c](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/c0c278c6cb6fd7220a10448b18255dafbd5a2bc4))
- *(glass)* Add GlassStyle data class ([e1fb834](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/e1fb8344ce9a9b5d35fed2a8fbe00a54e289ec12))
- *(glass)* Add GlassBackground with dynamic gradient orbs ([3d4a998](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/3d4a99858b498369d4d993f4dde2d733aa32710e))
- *(glass)* Wire GlassBackground into app shells ([061e3e0](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/061e3e062ae39c34e9fe08907473f8c81e67c795))
- *(glass)* Implement Glass Painters and GlassContainer for Phase 2 ([7f4e975](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/7f4e9754e01cfddef040b6fd85d746f57c49e0ad))
- *(glass)* Migrate adaptive sheets and settings cards to GlassContainer ([3f5f723](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/3f5f72376d48ae9e2f7aab8bb3959f306b2125d0))
- *(glass)* Full glass migration — dialogs, sheets, drawers, containers ([6d17c55](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/6d17c556d2b95b6ea0b797ce85faff66dbb878ed))
- *(glass)* Apply liquid glass to all remaining pages + fix light mode readability ([d75171f](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/d75171feef591a01592ca07323f9a25eadc706ae))
- *(glass)* Add GlassBackground to 6 missing pages + fix test sigma values ([36a1444](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/36a1444e14d0395d6529c1468caeb364ff983594))
- *(glass)* Update glass tokens to Apple Liquid Glass spec ([64d4d14](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/64d4d148f549bb77e31a0790a0165e3148fff7da))
- *(glass)* Add Phase 5 interactive enhancements to GlassContainer ([3398def](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/3398deff510702420ca80dafc1ce8382797437d1))
- *(theme)* Add Arc+Linear design tokens to AppColors and AppThemeExtension ([65502fd](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/65502fd562cd2017146808fcbcc12b8e63372dc7))
- *(components)* Add 3-tier card system (surface/card/elevated) ([dfb119e](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/dfb119e1d6df36e7311e03aa3928e64a5573b7b9))
- *(player)* Redesign mini player with gradient background ([1292286](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/12922860077cc3800389fe9b01522bd338b27cde))
- *(chat)* Update message bubbles with Arc+Linear theme tokens ([e765c4a](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/e765c4a987f74143c9af288c8cb63eeb2722dc7a))
- *(chat)* Restyle chat bubbles with Arc+Linear theme ([9ee89ae](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/9ee89ae029fdf9342fed2e3cc2ef8ac561397c3d))
- *(ai-chat)* Redesign chat bubbles with Arc+Linear style ([0aa9dfb](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/0aa9dfb1854b8f0332c30a4bff93132c755df3ab))
- *(nav)* Redesign sidebar with Arc+Linear expandable style ([f9b4dad](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/f9b4dadb16eb3ffe0c33ba10394378154c43d713))
- *(podcast)* Add Linear-style section headers and episode card identity bar ([72c7e08](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/72c7e0873467c253570718e9fbda60bfbe881d57))
- *(podcast)* Update shared widgets with Arc+Linear tokens ([4c67360](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/4c67360f4a80e903401209c9c1e655de93b41028))
- *(podcast)* Update podcast widgets with Arc+Linear tokens ([f237b22](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/f237b22c9f7cc39df96836d2ed2927239c1779f2))
- *(podcast)* Update all podcast pages with Arc+Linear visual style ([84da71e](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/84da71ec9871e15a33d305633438bd54c7cbc0a0))
- *(ui)* Update shared podcast widgets with Arc+Linear style ([ca56b2c](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/ca56b2c4627cebe0c43d62a5b79e88f02f418551))
- *(ui)* Apply Arc+Linear design refinements and fix test suite ([19abc01](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/19abc01aa671cc1f9b026d34f87bade296c367fb))
- *(ui)* Finalize Arc+Linear redesign with downloads page and navigation refinements ([300f47e](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/300f47e34336b3bf933c4e01d5dc29f5d36b1dd2))

### 🚜 Refactor

- *(theme)* Update background colors for neutral glass palette ([19e62d8](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/19e62d80c140d3d6379918e6bc2edf3fc0db8122))
- *(podcast)* Migrate remaining podcast pages to new glass system ([24a6810](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/24a681082773b7dbdd006e7e978196d220fdc3c8))
- *(theme)* Add glass-style component theme overrides for full coverage ([4cbd30c](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/4cbd30c80f475d286b498d2465b7513a9ef6bb96))
- *(features)* Replace hardcoded surface colors with transparent for glass theme ([7e78a4d](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/7e78a4d64af9fdf22df01ea55efeef0adc730f6f))
- *(podcast)* Replace hardcoded surface colors with transparent for glass theme ([b49f3db](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/b49f3db17573d271341edc4e896fba4fa56f3fd3))
- *(glass)* Update glass components, tokens, and tests ([26b907b](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/26b907b79bbeee2f48d1735060559700bdb9435c))
- *(theme)* Merge apple_colors into app_colors, eliminate dual color system ([94c55a4](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/94c55a4f8daa6aaf882ee28cf14239315b2f877b))
- *(tokens)* Unify radius tokens for Arc+Linear design ([e14c637](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/e14c6378b96e021f144dea941b80f8e20abb7f4d))
- *(glass)* Simplify glass system - delete painters, 4->2 tiers, StatefulWidget->StatelessWidget ([6423a5b](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/6423a5b8c2bd4ba5f757a30458d63021efa20af0))
- *(glass)* Darken background orbs, update vibrancy for Arc+Linear theme ([cf6350b](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/cf6350bb5b66a85e6eb3b077f4d76418b0985156))
- *(transitions)* Simplify to 150ms fade, rename to Stella ([995211d](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/995211db7aaebb24d39944dd4a54300293d6877c))
- *(auth/profile/settings)* Remove unused glass imports ([d24f22b](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/d24f22bcd631dfcb9b41e290694172b6e3878fbc))
- *(transcript)* Use Arc+Linear theme tokens ([872d020](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/872d020a21035a4fb88ce8bd2282256205bdcc1a))
- *(podcast-pages)* Use Arc+Linear theme tokens ([ea3a76a](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/ea3a76a99963d4941e99c83ac16ec9562d23daa2))
- *(podcast)* Remove unused glass_container import from highlights_page ([2b57db0](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/2b57db03cbf620f0ca053062ceb0390949afa405))
- *(widgets)* Apply Arc+Linear theme tokens to remaining widgets ([dc4e6a7](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/dc4e6a70ca82fd75b45dc0707790e86d85c1bf06))
- *(cleanup)* Remove unused imports ([aa4a40d](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/aa4a40d3b45ac4e51d43294d65f9201137047bb0))

### 🧪 Testing

- Fix all test failures after Arc+Linear UI redesign ([ae5a3be](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/ae5a3be00c7877d17c514babf357e20745258a62))
- Fix unit test failures after UI redesign ([2688206](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/2688206d9918da1d7ccdd194cf1ff12b1940346e))
- Fix remaining widget and unit test failures after UI redesign ([5e9a7fa](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/5e9a7faaa613d7d8b28cdf6716772e9a6f06f657))



## [0.40.0](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.39.0...v0.40.0) - 2026-04-04 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.40.0))

### ⚙️ Miscellaneous Tasks

- Remove unused backend dependencies (starlette, prometheus-client) ([72ee6e7](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/72ee6e7a3f3e9db39b3c5c8c6f0a125b7643cabc))

### 🎨 Styling

- Apply ruff format to 58 files, remove stale api/ directory ([e928239](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/e928239b77803d02636616f6dd547eb87df04d4e))

### 🐛 Bug Fixes

- Rename summary_generation_service to summary_service, fix stale imports ([6be954d](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/6be954dec52d729c4821d102d4c436dbc884fccd))
- Stale imports in podcast tests after service rename ([d61e2eb](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/d61e2eb6aa6cd2a9ecd990c898aa332484526dbb))
- Repair broken test imports after service rename and projection removal ([6822e12](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/6822e12647aa75458508158a91c234222ccd67b9))
- Update tests to use dict access after projection removal ([4d7eb70](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/4d7eb7079a97be77c9ae27dcf815e9ce87c54819))
- Remove duplicate exception and fix stale 'from exc' in routes ([4ff728a](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/4ff728a3264aaef6b68f8f31e051028635912cf2))
- Add `from None` to HTTPException raises in except blocks (B904) ([5444652](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/54446524b11911996b895b3305e2222b10c62391))
- Correct build number to 100 ([211e154](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/211e154aa4d2067921e3b3736e44e7e40b24184a))

### 📚 Documentation

- Add codebase simplification design spec ([28fd23a](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/28fd23a3e244cdefa4cebd7ebef75f7904a2a1f8))
- Update CLAUDE.md to reflect simplified architecture ([a87e5ff](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/a87e5ffa4fa1236128c5325017b9f850788d59f2))

### 🚜 Refactor

- Remove circuit_breaker module and all references ([49afa3d](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/49afa3de6cabb8922c4d8bc3043251ec669b3696))
- Remove prometheus metrics and observability modules ([7a34787](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/7a34787ab87dbc574790f0dbd55240e4ff15e2f0))
- Remove distributed rate limiting middleware ([0880273](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/0880273d9cd70ad588b67808fd0c1c88862ca640))
- Remove response optimization middleware, simplify request logging ([26efee0](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/26efee0cdc89b9a4bd95138b354367da0b51ed24))
- Remove email.py stub module and all references ([364f6a3](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/364f6a3ec5eb56b800b1d17079c0bfc2b043707e))
- Remove ETag module and simplify response helpers ([794ad96](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/794ad9690ee7dddb8c3291bcad01b8c92dabd393))
- Remove performance test suite and locust dependency ([e315118](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/e31511841563caa6dfa68b423fa6086954e15299))
- Simplify redis module, remove unused metrics collector ([f9620c5](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/f9620c570ad33c67c24f2a03248c3ad0a6204018))
- Simplify exceptions.py, remove unused exception classes ([84aa62d](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/84aa62d34d7af00b60f5d34993ece3c49197bf1a))
- Simplify database.py, remove pool warmup and monitoring ([8ea1cfa](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/8ea1cfaa1683cc2073925ca7c3ef4893a760745b))
- Simplify Docker stack, merge celery workers, replace gunicorn with uvicorn ([5cbe796](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/5cbe79619c8526f7720b2cd2730d4e9c613311d6))
- Remove projection layer - replace with plain dicts in services ([e3d34ec](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/e3d34ec5e429503fcafe4e09058284718c049e06))
- Remove unused async_value_widget, lazy_indexed_stack, dartz dependency ([5e47328](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/5e473283d2b1546733c625944b475d9a45005034))
- Remove unused offline widgets and queue service ([55228da](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/55228da8a9e199059068e8b03e81a695ad02119c))
- Consolidate duplicate episode models ([9c85c89](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/9c85c894d84491b59949494fa53cd2e8b2b77fbb))
- Consolidate podcast states using PaginatedState<T> ([69bb7ee](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/69bb7ee634be75481c092ab8cb10f898275665a1))
- Remove provider/DI layer, use FastAPI native Depends() ([eb19dfe](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/eb19dfe8f7b78d0a572f967a7c60d5a947b134ad))
- Frontend playback cleanup and provider reduction ([e5b6319](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/e5b6319de73371c07319520235bd67f8b64e805d))
- Merge podcast task files (19→6) and simplify celery queues (4→2) ([21f5f7f](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/21f5f7f21ae166fab9c5e0d5e143221bc20765a0))
- Rename podcast/api to podcast/routes ([be18a1e](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/be18a1ee8344453a9c6cca0e0cc33b3a58a32cca))
- Merge podcast services ([c9e36e9](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/c9e36e91c1a72bc0134d5b61bcabdfe0e9f18e62))
- Remove gunicorn from Docker, clean up dependencies ([e869dff](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/e869dff4c20c2493d0ed10ed823c15b9d72eeef7))
- Simplify Redis (5→2) and exceptions (444→150 lines) ([43ca4a1](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/43ca4a189e850c44d749e1933ef03d2a8ca809bd))
- Replace bilingual error helpers with plain HTTPException and resolve merge conflict ([8385a42](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/8385a429ac034725aa4044ff5c8b9ff18f841eab))



## [0.39.0](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.38.0...v0.39.0) - 2026-04-04 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.39.0))

### Revert

- Remove AI tab page, restore 3-tab navigation ([a1e3864](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/a1e3864f98c611ac55614aaaf0f373f451970dc1))

### 🐛 Bug Fixes

- *(security)* Phase 1 security hardening ([9b9ad0d](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/9b9ad0dab21984f5dd9203c2fa31906a04ad7090))
- *(auth)* Correct SQLAlchemy boolean filter in password reset queries ([e6abacb](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/e6abacb14e9e64019a9277ab2d020fcb16b229c5))
- *(security)* Environment-gate password reset token in production ([86f531a](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/86f531a2a091befb6f5bea438c42ad87257a0fb2))
- *(security)* Normalize subscription route error handling with bilingual helpers ([ba7948d](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/ba7948d21465d1e748e90b33bb891939bb870d1b))
- *(security)* Bind admin session to client IP and fix error detail leak ([10a4035](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/10a40358c0af5bc4753c921af273cb9a3f15f0c5))
- *(core)* Add resource cleanup to DioClient provider ([ab6335a](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/ab6335aa63a6adb203e21effdcc81c51cb10895d))
- *(tests)* Clean up unused imports in backend test files ([53faabe](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/53faabe7a83f768925ab80fd4369b35905ecb005))
- *(ai)* Fix syntax errors and remove non-existent imports in AiTabPage ([7dc1893](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/7dc1893b6a99f3a9774454743662cd2accf03c88))
- *(frontend)* Resolve three compile errors in podcast listener and profile pages ([90f0b11](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/90f0b112b562c1fdfd383bbe37813c11560c926e))
- Complete remaining P1-P4 optimization tasks ([77164de](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/77164de672edea6cbef69732381022cf73538892))
- *(nav)* Handle empty navigation stack in daily report back button ([73856c7](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/73856c797884ca477f83ba066f9d3c6a53852457))
- *(nav)* Guard all context.pop() calls with canPop() check ([87a520f](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/87a520fc6ea83ac5d92500e89d2167891f352d56))

### 🚀 Features

- *(observability)* Restore runtime metrics with RuntimeMetricsCollector ([af6ba7e](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/af6ba7e2e767f2764034c6b0155eba24fcec9070))
- *(security)* Add JWT token revocation via Redis blacklist ([0c2f704](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/0c2f7046d74efc89bb3dd8620b043236af484bf2))
- *(user)* Complete UserRepository layer for user domain ([8c081e5](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/8c081e5ae03f817ad492bfdbd48dcc6e46d7e864))
- *(subscription)* Add Pydantic response models to all endpoints ([596cd5d](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/596cd5de23dfbac04a6c244943b7ea6b6f08a755))
- *(desktop)* Add landscape orientation and keyboard shortcuts ([030e2be](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/030e2bec7812e929a9f38f8e883887139a954869))
- *(ux)* Add onboarding, legal pages, PaginatedState, server config listener ([69a4426](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/69a4426938198262d1053985cdae438c4c082b20))
- *(ux)* Profile persistence, navigation updates, i18n expansion ([718ae55](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/718ae5539345274de4a11ba29de9f9e3e4e07f02))
- *(ai)* Add AI hub tab page with daily report, highlights, chat entry ([3cdeba2](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/3cdeba2b9d883992e635cb8223c727e58c073f85))
- *(nav)* Expand to 4-tab navigation with AI tab ([cd5b53f](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/cd5b53f76f50fbd08210f376ec812348a9c793a1))

### 🚜 Refactor

- *(core)* Split security.py into focused package + eliminate AppCache delegation boilerplate ([5938085](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/593808515b1c5392faafd5522ecf85676cbc9fea))
- *(core)* Unify AI invocation, split orchestrator, extract SettingsProvider ([15c572b](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/15c572b1d6b10b5208778996462d9e5f6ec33f5b))
- *(api)* Unify list endpoint response format with PaginatedResponse ([e0d229b](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/e0d229b08d72f7359b8ca2238c161feded3fb64f))
- Gate debug logs behind kDebugMode in production code ([4d12f8c](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/4d12f8c7fe94f5699fb445ddcf6a0dd67fb730f8))
- *(frontend)* Eliminate core-to-feature dependency violation via event bus ([acc6cf7](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/acc6cf76f529dd6557f579409da41c8aeed7bb6c))
- *(podcast)* Split AudioPlayerNotifier into focused part files ([054ea81](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/054ea812023d29d3f580376c343c66ef3adf1f64))

### 🧪 Testing

- *(user)* Add error-handling route tests for registration and login ([ff1a3cb](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/ff1a3cbf9a1e842cd63e3a9da6e5c16326321cea))



## [0.38.0](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.37.0...v0.38.0) - 2026-04-03 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.38.0))

### ⚡ Performance

- *(frontend)* Optimize downloads page, unify storage keys, add queue error handling ([c9c85ff](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/c9c85ff16f62f85c91d7115a5c87873ed457aac5))
- *(frontend)* Auto-load highlight data on provider init, add RepaintBoundary ([d7c4bbd](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/d7c4bbdc5a5bbf41dd3b6d45c304292bc548e47a))

### 🎨 Styling

- *(ui)* Adopt Cosmic Editorial palette with indigo-violet theme and entrance animations ([53f297b](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/53f297b203de71d78214ff605bad57e4a76dd00e))
- *(ui)* Polish widgets with cosmic theme tokens, animations, and design refinements ([80f1d64](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/80f1d64ec0f42070bcd8ed2d134814d93a78e121))

### 🐛 Bug Fixes

- *(frontend)* I18n hardcoded strings, extract auth helpers, remove legacy typedef ([3dec88b](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/3dec88b9ec4e67205e0d53be0db92adc90713e52))
- *(network)* Remove trailing slash from baseUrl to prevent double-slash 404 errors ([ec5fbab](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/ec5fbab103c5d7967d9cbc70340241043e537f2a))

### 🚀 Features

- *(theme)* Add controlRadius, sheetRadius, pillRadius tokens ([9131849](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/9131849d8cf6a66a3e0cbf74744a0b1265806a3c))

### 🚜 Refactor

- *(network)* Extract RetryInterceptor from DioClient ([6a9040e](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/6a9040e6dd188c934feba6600cb4297914579a12))

### 🧪 Testing

- *(network)* Add RetryInterceptor and request deduplication tests ([2923780](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/29237800ce935657d4a9dc45af7a86280b3782d0))



## [0.37.0](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.36.0...v0.37.0) - 2026-04-02 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.37.0))

### 🐛 Bug Fixes

- *(profile)* Improve edit profile dialog responsive layout ([3323314](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/332331484b570ec049b74a2b5bd6c6620ac2baf2))

### 🚀 Features

- *(settings)* Add font preview page for comparing typography combinations ([05dc166](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/05dc166cc3279ec6b75c293ee0ad6ca9342aeb82))
- *(theme)* Migrate typography to Space Grotesk + Inter with named style helpers ([594a802](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/594a802add47ef274df752fefa94846d19fff308))
- *(settings)* Add unified Appearance page with theme mode and font selection ([32411cf](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/32411cf5fc7c38e536bb9c265280a10b10ee99d6))
- *(settings)* Add font reset button and fix font persistence ([30a88f2](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/30a88f2d0e8c9d4d4a2b38c38da286212d361502))

### 🚜 Refactor

- *(core)* Replace hardcoded text styles with theme references in core and shared widgets ([6b66b53](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/6b66b5303430696d4faec4c9d73b525936ee37ba))
- *(podcast)* Replace hardcoded text styles in transcript and transcription widgets ([03693fd](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/03693fd7ed79cdf90615a7caa4dde7c57ba2f257))
- *(podcast)* Normalize text styles across remaining podcast presentation files ([be3c376](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/be3c37670f57077eb3e7de38fbee5c9af1694eee))
- Normalize text styles in auth, profile and settings features ([38b215f](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/38b215f3fe6e58a105832f5ff6fe1780e1f34397))
- *(settings)* Replace font card list with dropdown selector and add more font combinations ([1172013](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/117201361ab595ee553e803a636e2539fcb09391))



## [0.36.0](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.35.0...v0.36.0) - 2026-04-02 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.36.0))

### ⚙️ Miscellaneous Tasks

- *(frontend)* Regenerate l10n and code-generated files after adding offline downloads feature ([eb232ea](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/eb232eaaa5c6e58752964cb8460955d939355f2e))

### 🐛 Bug Fixes

- *(podcast)* Show episode title, podcast name and cover in downloads page ([f6da2c7](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/f6da2c75682f3cb29ee4d7f88264fcb2a66f2ab8))
- *(podcast)* Populate episode metadata in downloads page via cache ([23a4ed5](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/23a4ed54e43c3177484de1aa163defe5ed564f90))
- *(podcast)* Add primary key to EpisodesCache and fix downloads page metadata display ([45af44f](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/45af44f9dff1bafb386d0b44812eee51a343d8c3))

### 🚀 Features

- *(frontend)* Add local database with offline downloads, download UI, and offline playback ([e06a649](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/e06a6494d5ab7ade772698aa88d0583715d18e93))
- *(frontend)* Add local database with offline downloads, download UI, and offline playback ([3512ba4](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/3512ba451a07706c4b6696100ea731ac916b6ef2))
- *(podcast)* Integrate download buttons into episode UI with queue-based auto-download ([6e645dd](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/6e645ddda0bfb78b97acf283cc272ce7ba321d2c))



## [0.35.0](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.34.1...v0.35.0) - 2026-04-02 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.35.0))

### ⚙️ Miscellaneous Tasks

- *(release)* Regenerate changelog for v0.35.0 ([6908c59](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/6908c5924886043289b0539e96123616dd152ae7))

### 🐛 Bug Fixes

- *(podcast)* Fallback to TranscriptionTask when PodcastEpisodeTranscript is missing ([1dda54d](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/1dda54d3acb1624c14a3ec41e738d72a488132fe))
- *(core)* Improve HTTP exception log format and differentiate log levels ([638440f](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/638440f4ae092bafb9387eacd8a0d8e87f46dcb3))
- *(frontend)* Replace late fields in Riverpod notifiers with getters and add l10n coverage ([e21086d](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/e21086d7ad9539161d2de933f06343d915f3a4e1))
- *(frontend)* Email validation, nav feedback, password security, and Hero transitions ([81ab97f](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/81ab97fdcd24bd3a777d74b6b047a18f8e0eabf8))
- *(frontend)* Use double literal for skeleton cover border radius ([f7f0889](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/f7f0889cc4b830bf9b62caddd8ed18749ba34d58))
- *(frontend)* Pin connectivity_plus to <7.1.0 to avoid iOS build error ([a160284](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/a160284f4bef98d4998f6f839a207c81f036ef47))

### 🚀 Features

- *(frontend)* Error code enums, accessibility labels, and keyboard shortcuts ([5022c6f](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/5022c6f5e0a78c23c9acfb494138c93cd96699e9))

### 🚜 Refactor

- *(frontend)* Upgrade to very_good_analysis and add RepaintBoundary to list items ([d207c3e](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/d207c3e4ca4870eb57e4857b7d21ff9fbd8a29ee))
- *(frontend)* Convert all relative imports to package imports ([2aa353a](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/2aa353aa80ac342b38028066fd483fbf9db8e006))
- *(frontend)* Improve error states, user experience and retry buttons, skeleton screens, and cache cleanup ([f68f9d3](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/f68f9d3e29b5f40c8f2e82e5dd435b0a9c0517ad))



## [0.34.1](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.34.0...v0.34.1) - 2026-03-28 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.34.1))

### 🐛 Bug Fixes

- *(android)* Add dontwarn rule for bnd annotations to fix R8 minification ([4235852](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/42358528cf0dad9aad221755b0cefc8ecb304e54))



## [0.34.0](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.33.0...v0.34.0) - 2026-03-28 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.34.0))

### 🐛 Bug Fixes

- *(frontend)* Move flutter_native_splash back to dependencies for Android build ([d97960f](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/d97960f9b4053397bbdb2b38e88791adc2bf6fb6))

### 🚜 Refactor

- *(backend)* Simplify core infrastructure and remove unused abstractions ([492280e](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/492280eed9990a27ac27f0e5126a7295d5cbd18b))



## [0.33.0](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.32.0...v0.33.0) - 2026-03-28 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.33.0))

### ⚡ Performance

- *(frontend)* UI rendering optimizations ([c7dcbbe](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/c7dcbbee12acb10e4bb3306ec2518e85fc3701f8))
- *(frontend)* Isolate bottom player rebuilds with select() and Consumer splitting ([d7b40a3](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/d7b40a3fdb5ff64a586d4c68d01f9890a3e1a2ea))

### 🐛 Bug Fixes

- *(frontend)* Replace force-unwrap in playback queue controller ([7d19ac7](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/7d19ac76f3e4c8c42c78b35b11b70d1b3053eba4))
- *(frontend)* Null safety improvements in podcast providers ([21ba189](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/21ba18996a7e4a3001deedefb75fb896148857fb))
- *(frontend)* Clean up auth event stream dead code ([2f93483](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/2f934838799a4992439141656787cd10c6d12c50))
- *(frontend)* Network reliability improvements in dio_client ([b39f119](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/b39f1191c16696e9295a166c13df7a529ab9ab0d))
- *(frontend)* Resolve merge conflict in conversation_providers race condition fix ([422e5d4](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/422e5d4f24b6eb09dce17ba27bc1c11b4c82f543))
- *(frontend)* Error signaling in CachedAsyncNotifier + summary provider fixes ([fe0520e](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/fe0520e22bc8a45ce732506a4873708cba52a529))
- *(frontend)* Add clearError to copyWith in 3 state classes ([1dbc657](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/1dbc657a6a9fc2f7ff27faa0854532d766a8197c))
- *(frontend)* Resolve merge conflict in podcast_subscription_providers ([6330c19](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/6330c1974cc1e90165a7af44444de63ac8b7f79d))

### 📚 Documentation

- Update AGENTS.md and CLAUDE.md with new commands and structure ([1e08a5b](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/1e08a5b2435a47c4ad6452e28986cd98e4b3c1d5))
- Add frontend stability agent team design and deep scan report ([ce60b53](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/ce60b5307ae815ed476333b00142804f2bb0e587))



## [0.32.0](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.31.0...v0.32.0) - 2026-03-27 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.32.0))

### ⚙️ Miscellaneous Tasks

- Remove 4 unused deps, move flutter_native_splash to dev_deps ([729d441](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/729d44110c90399f0a49f72609f73ea5e00223e5))
- Delete unused app_icons, error_handler, episode_provider_cache ([81e8361](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/81e8361364c8f0b8e852fa79d9e911cc0fbe997d))
- Delete unused core/performance monitoring module ([757a595](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/757a5958d32b3d0cd90283c13843b46f569acd14))
- Delete orphaned test files for removed error_handler and performance modules ([7ef5a4e](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/7ef5a4e6c3129ba82fa99104048fa45c6285feda))
- Update backend and frontend dependencies ([ad09a72](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/ad09a72ca52289b3b2157b8ea888c9a0f66e9386))

### 🐛 Bug Fixes

- *(frontend)* Resolve merge conflicts and source code compilation errors ([90d5298](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/90d52985a424f254ffe63b6ee0b6df6bb95683e6))
- *(frontend)* Remove unused imports after widget refactoring ([b8850ba](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/b8850baee6057663578e1e7a4862e75c632c100a))
- *(frontend)* Fix test compilation errors after refactoring ([00a8178](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/00a81789282aabb429efc4da017eead9aee28924))
- *(frontend)* Rewrite home navigation test to use StatefulShellRoute and fix warnings ([940f6f6](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/940f6f60f6d7c92268b382a51c1781b54321a33f))
- *(frontend)* Fix all remaining test failures after refactoring ([247a36c](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/247a36c66b56250fdcc618d10ece0e9afc6e0486))

### 🚜 Refactor

- Remove duplicate AppBreakpoints, use Breakpoints class ([ab18147](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/ab1814757fe76d2a347769b4c75166bf0cfa195d))
- Remove unused AppConfig constants and duplicate AppConstants wrapper ([dc75c2f](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/dc75c2f5cffd819b09b1313592ee724de211c258))
- Move auth_event from core to features/auth ([3163c92](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/3163c929ce63b7aba7d914553c8bb9cfca105605))
- Remove dartz from auth, use exception-based error handling ([2f4a688](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/2f4a688ccd9d521f39dd1d652b0fa545b8131438))
- Move formatDate to core/utils, fix data-presentation layer violation ([bb47c71](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/bb47c71b8a0c3f933f0c6e11c57f89eeed1b39d0))
- Extract shared sameDate utility ([d3086ba](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/d3086ba10242a953fa1349f87f48e82a6ea8fbe5))
- Replace 8 identical cache duration providers with CacheConstants ([0d7fd70](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/0d7fd70eea16a3fcd78716c33be07ad13f420663))
- Extract CachedAsyncNotifier base class from 4 providers ([2bf2fef](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/2bf2feff474c4ce868ec0ea095f0a6adaa387b1b))
- Extract _apiCall wrapper in podcast_repository ([e8a689f](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/e8a689f820bc694fc3290c542b0affa82ee9dfaa))
- Extract sub-widgets from conversation_chat_widget ([b96719d](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/b96719d3e3dccc7877c546d4983f317ce93625c4))
- Extract BaseEpisodeCard from episode card variants ([8575c2c](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/8575c2cfe2ee2da54d8b11e675b02902f1a48d90))
- Unify empty/error state widgets ([2f24e87](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/2f24e873491e981c3dbe55bcda4d69e30fd7593a))



## [0.31.0](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.30.0...v0.31.0) - 2026-03-27 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.31.0))

### ⚙️ Miscellaneous Tasks

- Add .worktrees/ to .gitignore ([8c34912](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/8c3491272385f5f7df1ec187b5670e0ad84e8e4e))

### ⚡ Performance

- *(frontend)* Optimize network, theme, state management, and caching ([7cbfa4a](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/7cbfa4ad7cfbbf49fc031ca48a70cff1b5356518))
- *(frontend)* Add debounce, fix stream leak, add autoDispose, remove dead dep ([88be730](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/88be730ab41a130af417adbf7cb845f50b0d6428))
- *(frontend)* Optimize MediaQuery usage, ETag cache memory, conversation dedup, and fix broken tests ([c56ecf8](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/c56ecf89b48690b34fb5173159f14febd7dc9539))

### 🐛 Bug Fixes

- *(redis)* Add wrapper methods for sorted set operations to fix missing client parameter ([08905c5](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/08905c5dae6159009cb6280b298961cad9adf754))
- *(redis)* Add release_lock wrapper to fix missing client parameter ([2adf8b3](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/2adf8b3124eb5dd503d891a44f4bfc10146b3d68))
- *(podcast)* Resolve highlight extraction failures after transcription ([057ec4b](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/057ec4b5bd4f6d8dd49fd7095089668ea55d89a6))
- *(router)* Fix auth refresh cascade, dead provider, and navigation anti-patterns ([a136976](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/a136976c1d9fe52c21b0614c36a623b1d4399fe7))
- *(celery)* Harden task retry logic and improve error observability ([0025e76](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/0025e76aeb6d73253033973bcea272270ed2eaa5))
- *(podcast)* Add missing joinedload for transcript relationship to prevent MissingGreenlet errors ([f1f7752](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/f1f77523b6877b002c5e5f7981b92ca5d0e724ca))

### 🚜 Refactor

- *(backend)* Apply typed exceptions, migrate transcript_content, and consolidate architecture ([2f2f15b](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/2f2f15b9d1705a51e8a477bb1b8782e5b48edefc))
- *(backend)* Convert middlewares to pure ASGI, harden security, and improve observability ([c4c8be2](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/c4c8be22c31473536f5a3e5183d494d295853947))



## [0.30.0](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.29.0...v0.30.0) - 2026-03-24 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.30.0))

### ⚙️ Miscellaneous Tasks

- *(frontend)* Update dependencies and generated files ([28198ea](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/28198eae74c1e5f062e8801d0d1d6aad5c337683))

### ⚡ Performance

- *(backend)* Optimize stability and performance with batched metrics and concurrent processing ([4857600](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/485760036755e8b3d635eaa71ecad213e24a9283))

### 🎨 Styling

- *(ui)* Remove borders and padding from content area cards ([78c5bf4](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/78c5bf4f20a9066c5358929b932a602b2332acfd))

### 🐛 Bug Fixes

- *(frontend)* Resolve null safety and unused variable warnings ([ebf20d3](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/ebf20d3f47f698d66ac96ad898e7650297a00c14))
- *(backend)* Resolve test failures and improve stability ([aa9cceb](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/aa9ccebd76c0c019f3b371f7b1b10eff87602fe7))

### 🚀 Features

- *(frontend)* Enhance stability and performance ([50061bb](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/50061bbbfa14cff63a10e596332b2caf2fcf7cee))

### 🚜 Refactor

- *(frontend)* Improve error handling and null safety ([9efd85e](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/9efd85e151883fd88b05c92c49f95ffbeb67f044))
- *(podcast)* Remove bulk import dialog and batch subscription functionality ([ec41ddb](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/ec41ddbe352e13a5cb19e1a9947a77d2128e5367))
- *(backend)* Modularize shared AI client and unify error handling patterns ([91605b4](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/91605b4a36446f3908a191969575fb33b9bbc69a))
- *(frontend)* Eliminate unsafe force unwrap operators for null safety ([752045f](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/752045f41d11c5ff3956b7f70664dc388993eaf5))
- *(frontend)* Improve null safety and remove unused bulk import dialog ([3a2c50a](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/3a2c50aec944d1b3c53b887e4b3fd81aa534fca6))



## [0.29.0](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.28.0...v0.29.0) - 2026-03-23 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.29.0))

### 🚀 Features

- *(podcast)* Integrate highlights view into transcript display with dual view mode ([79d035f](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/79d035fc4ed7838c44226bd5983dc2f39aae6b89))

### 🚜 Refactor

- *(redis,ui)* Simplify cache API and unify card styling ([b01e2fd](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/b01e2fdbceaaaa82281dacbbd06bb1bef3105266))



## [0.28.0](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.27.0...v0.28.0) - 2026-03-23 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.28.0))

### 🐛 Bug Fixes

- *(core)* Resolve database connection pool exhaustion and reduce API access frequency ([9858435](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/9858435c6c2762f69cad7ccd7ccb0db9ebabd4a3))
- *(redis)* Correct cache_delete function binding in invalidate methods ([461eaf3](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/461eaf3efdce7283b92c997b2b653dcf0c408cfd))
- *(test)* Use clearData: false in ServerConfigNotifier tests ([a2bc841](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/a2bc84107f7bcacbc3cd63e62c67dc5357fcd316))
- *(playback)* Prevent concurrent sync requests and fix cache invalidation binding ([5007ded](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/5007ded5c1814d0351a9670f0850ffe9deeb478b))

### 🚀 Features

- *(core)* Add cache penetration protection, warming, and migrate admin routes to API prefix ([9663868](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/96638688026512427eedc4c484aaba6e86bd0a7b))

### 🚜 Refactor

- *(core)* Restructure Redis module and add centralized cache TTL configuration ([c4073ae](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/c4073aeac34490b07d1e734abf82b83bcfd11790))
- *(core)* Remove deprecated files and inline sync service functionality ([a8a3fe9](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/a8a3fe9f6f26b22de3af3d1ea04c5e6f8b1cd761))
- *(core)* Simplify backend architecture - Phase 1 ([9a233f8](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/9a233f8dec516121811222fec211a9b12e8041a1))
- *(podcast)* Unify _get_subscription_models import ([6af7f2c](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/6af7f2c433d11bcd72ef5e68d1d1e4ce65e2637d))
- *(podcast)* Inline transcription helpers into workflow service ([7380ec7](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/7380ec7707ee6b7f30f0cc886b12b7e51d5e3622))
- *(podcast)* Remove unused recommendations feature ([1e89051](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/1e89051ca5eadffb9033ad4cc933e4ed82459750))
- *(frontend)* Remove unused widgets and utilities (~2,740 lines) ([7eb6264](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/7eb6264d364e549679995f08193aea172b1c8515))
- *(frontend)* Remove unused code and deprecated patterns ([9d335b4](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/9d335b4754bd640a26f38f4ccdd78a9e4295afb8))



## [0.27.0](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.26.0...v0.27.0) - 2026-03-22 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.27.0))

### ⚡ Performance

- *(backend)* Implement comprehensive performance optimizations ([948e743](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/948e743d4945b14facc67a02ccbd7187179d7cc3))
- *(backend)* Add observability metrics and transcript storage optimization ([3ec16e4](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/3ec16e405e0e543b3f290aacaeacf0d316c0aabb))

### 🐛 Bug Fixes

- *(migration)* Correct syntax error in migration 014 ([bd7fcfe](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/bd7fcfe859cc31f9c891503306442598d27c8421))
- *(migration)* Use correct column name published_at instead of published ([4f457b7](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/4f457b78ec66493bbbc83eea7857763b9dc29ebb))
- *(migration)* Use correct column for playback state index ([a816e18](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/a816e18fcb8a4cacb9dd42aeb63f27109d17f6a8))
- *(migration)* Use default GIN operator class for JSON columns ([ea3b15e](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/ea3b15e961dcabaea2fc6b7b87dbc308fd15c6f1))
- *(migration)* Convert JSON to JSONB and add GIN indexes ([19f92fb](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/19f92fba7fe058d2994f5ee531e4ad0b3e4e8323))
- *(migration)* Convert all JSON columns to JSONB before adding GIN indexes ([5c6fc27](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/5c6fc27ac46ce3aa025af1facacab1431defcdfa))
- *(core)* Convert middleware.py to package for rate_limit import ([33c1435](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/33c1435143bd59417416fa97012c167ad552316d))
- *(providers)* Import Depends from fastapi ([b9bfdb2](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/b9bfdb27becd3ef522368c2d114ed3fd2672f469))
- *(providers)* Add missing Depends import from FastAPI ([515a6d2](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/515a6d24bb94671cfb2c2521bd22b9d5436a6267))
- *(providers)* Use callable reference instead of string for Depends injection ([c365747](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/c36574723a02bb92e07025f66a6cdb225f1a258d))
- *(podcast)* Map transcript_content to renamed database column ([2333a27](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/2333a27a72ef8d8aff9b7d2f3d69c46f361820ae))
- *(core)* Prevent circular recursion in Redis health check ([c3bdd63](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/c3bdd63d2b6d02244132f04e5b166232bac40a7f))
- *(podcast)* Add missing subscription model import in feed repository ([0878df5](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/0878df5535ffec8843fafb1a36dae698ec1177c4))
- *(core)* Resolve FastAPI dependency injection and add missing Redis methods ([9c0fc48](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/9c0fc4890d8da58b3f0a1e9ebe078fac5745521b))

### 🚀 Features

- *(core)* Add comprehensive data clearing for server switching with user confirmation ([458921d](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/458921d86a6ed569fc643798ba32c0f0a05e17ad))

### 🚜 Refactor

- *(backend)* Complete Phase 3 architecture and performance optimizations ([e625aa2](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/e625aa297f66847e6bd70277a6121b3498e82e32))



## [0.26.0](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.25.0...v0.26.0) - 2026-03-22 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.26.0))

### ⚡ Performance

- *(frontend)* Optimize Flutter app performance and stability ([75d5bae](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/75d5bae718c2667a2060c312503dd1988d77347e))
- *(frontend)* Add scroll constants and optimize list rendering ([9743425](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/97434257bedeb3b4f47eaebfab99bf1feb7843ea))
- *(frontend)* Optimize memory management and fix widget tests ([866ea3e](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/866ea3edbc28b4d9590c258a1f281ff67b94858e))

### 🚜 Refactor

- *(podcast)* Extract state providers and add performance optimizations ([ac3967d](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/ac3967dfd0d0dc593f3c56057a094cfc3dc8a449))
- *(frontend)* Improve resource cleanup and state management ([597311d](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/597311d96ea2f64d46b6be19fd88a130c39c24b0))



## [0.25.0](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.24.1...v0.25.0) - 2026-03-22 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.25.0))

### ⚡ Performance

- *(podcast)* Optimize summary page scrolling with dedicated widget and state preservation ([dc0e611](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/dc0e611e627ff5b78e5484492b045f77124a32ea))

### 🎨 Styling

- *(ui)* Update header buttons to surfaceNeutral style and reposition back button ([212ba3d](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/212ba3d4bc093b8a361adaa1ccb5065fd090d275))



## [0.24.1](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.24.0...v0.24.1) - 2026-03-22 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.24.1))

### ⚡ Performance

- *(podcast)* Optimize animation and text processing performance ([ad975e8](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/ad975e8296cff470e090d400bc80c58696eff743))
- *(frontend)* Improve animation lifecycle and list rendering performance ([4e2b9ff](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/4e2b9ff7e3b90f5e8fdbaf2057feca86a9b5e545))

### 🐛 Bug Fixes

- *(podcast)* Improve highlight extraction task claiming and timeout handling ([b7134ba](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/b7134babfd53bf0fb2dac0a3e1b83a9797e85b27))
- *(podcast)* Fix profile highlights count and improve highlight card layout ([bde0422](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/bde0422b186065789c0362afc2f7dcfc315a70b9))

### 🚜 Refactor

- *(widgets)* Optimize animation memory usage in micro_interactions ([43cf1ae](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/43cf1ae44d0cb39374dfdb9320896ced03b974da))



## [0.24.0](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.23.0...v0.24.0) - 2026-03-21 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.24.0))

### 🎨 Styling

- *(ui)* Implement minimalist design system with refined colors and typography ([c003d24](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/c003d243f999d00705501f60aa5e2962a6cab7f8))
- *(ui)* Update Arctic Garden design system with refined typography and subtle effects ([a711ec1](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/a711ec198c2cb9efbc1e6013963aeba43789254d))

### 🚜 Refactor

- *(ui)* Redesign from Arctic Garden to Refined Minimal design system ([6b23301](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/6b23301833b1b31c7dbb9fb98363cdee2cdb4043))



## [0.23.0](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.22.2...v0.23.0) - 2026-03-21 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.23.0))

### 🐛 Bug Fixes

- *(podcast)* Add distributed lock and fix session management in highlight extraction ([b000e9a](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/b000e9a595eeb310b076763a15fbd2a08986828c))
- *(podcast)* Resolve highlight extraction infinite loop caused by self-checking in_progress status ([3fbda43](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/3fbda433d276505f43f5eca79252895dc13a2a63))

### 🚀 Features

- *(ui)* Add comprehensive design system with typography, animations and accessibility ([336a86c](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/336a86cb2bbbe711236e644e9206dfd4d841f114))



## [0.22.2](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.22.1...v0.22.2) - 2026-03-21 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.22.2))

### ⚡ Performance

- *(podcast)* Optimize highlight queries and loading performance ([c66360e](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/c66360e85aaf7545d70a17c70c00cb48ea28ad99))

### 🐛 Bug Fixes

- *(db)* Revert highlight extraction status to String type ([7eaa1be](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/7eaa1be7b4b7e300b76ee5873dab67e12fe8cdab))
- *(podcast)* Use UserSubscription table for user filtering in highlight queries ([159c24a](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/159c24abae63cc48ddff2a72c04bc711a3ea7e93))

### 🚜 Refactor

- *(profile)* Consolidate highlight stats into profile stats response ([9ec4568](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/9ec4568288165c31ccaf8c899057a84d623b872c))
- *(profile)* Add hideTitle option to AppSectionHeader for cleaner UI ([7b19180](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/7b191802892a8783e122539c2948e4ec7f7a1815))



## [0.22.1](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.22.0...v0.22.1) - 2026-03-21 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.22.1))

### 🐛 Bug Fixes

- *(core)* Update Redis client to use redis-py 5.0+ API ([e2b0706](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/e2b0706ce249802d4b2371f47ec86178f46ce9a5))
- *(db)* Add migration to correct highlight_extraction_tasks status type ([e6185b1](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/e6185b1581af8fc06bef8671abf07fd423584fc6))

### 🚜 Refactor

- *(ui)* Remove padding and margins from list views and cards ([dd898c4](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/dd898c46c8f34fe6b07ae06e3e458080b5e76dc3))



## [0.22.0](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.21.0...v0.22.0) - 2026-03-20 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.22.0))

### ⚙️ Miscellaneous Tasks

- *(agents)* Simplify configuration by removing redundant inline definitions ([f4346bb](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/f4346bb07d7dd03f8a4084fb0105cd1fa3b12221))
- *(frontend)* Remove outdated network layer tests ([215260c](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/215260c32f48bca317a413cbffec2edfa6d79e09))

### ⚡ Performance

- *(podcast)* Optimize polling intervals and add position debounce ([26c8d81](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/26c8d81be30ee914d2fd38695debb70cdc518ce9))

### 🐛 Bug Fixes

- *(backend)* Improve security, stability and performance ([31da14c](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/31da14c20b4b24ddea353d86c9f7993e395afb77))
- *(frontend)* Improve stability and performance ([7023116](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/702311617ac151170ebb83090b56962dc57680bb))
- *(i18n)* Replace hardcoded Chinese strings in highlights page ([c1b9b5d](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/c1b9b5dc28df792f427668275a7ea7eb7cd278a4))

### 🚀 Features

- *(podcast)* Add episode highlights feature with AI extraction ([7ecdcc6](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/7ecdcc6b54b8f21cf73f781bfb49dc17d545517e))

### 🚜 Refactor

- *(frontend)* Simplify architecture and extract shared utilities ([cf39e36](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/cf39e3695449bc999a06fac824215843249620fb))
- *(frontend)* Simplify architecture and extract shared utilities ([e197952](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/e197952b5d99cf9372a7eb48ceefba0a6214d7a0))
- *(podcast)* Extract shared status_value helper and remove unused functions ([7aa6a7d](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/7aa6a7d9e7e0658619007c233d3338195f0f5116))
- Apply ruff formatting and extract shared time utilities ([428117c](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/428117ce892a0d749e530511bff16d12c69ded11))
- *(pdd)* Optimize skill with progressive disclosure and flexible modes ([9374068](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/9374068193655385c08e2b9e58cb14bc40dc5ec4))
- *(ai)* Remove unused AI model REST API endpoints ([ebd96fd](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/ebd96fdb1ec912c51c0c8e526a8949b5afeb7252))
- *(backend)* Centralize test fixtures and remove redundant TOTP wrapper ([d12c9d8](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/d12c9d856232b4af8b8f9d947ea17c430e282e55))
- *(backend)* Consolidate shared utilities and add error helpers (Phase 3) ([292454b](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/292454bc88ee1cc5f09cec522e38124f2f9912c8))
- *(backend)* Simplify services and consolidate shared utilities (Phase 4) ([561a7a7](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/561a7a77bc2eeecd6ed17e6d7779db9d545a88e1))
- Simplify frontend architecture and fix provider mixins (Phase 2) ([0cc2b8c](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/0cc2b8c912860ce3023c06c700e5c16c20d3b723))
- *(backend)* Simplify architecture and unify exception handling (Phase 5) ([349caba](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/349caba75f94038d0dc5d6904e88e93ac9855e37))

### 🧪 Testing

- *(skills)* Add PDD skill benchmark iteration 1 results ([36e7699](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/36e76993f537124b096b0d0449b575b81aca620f))
- Fix failing integration tests and add unified test helpers ([f26adf4](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/f26adf44468b37c42444d3d5ae4e7d1044efd87f))



## [0.21.0](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.20.1...v0.21.0) - 2026-03-14 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.21.0))

### 🚜 Refactor

- *(core)* Remove unused code and simplify server config provider ([581ae86](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/581ae86047481b106d6607437c144fc3d91f14d5))
- *(profile)* Simplify server config access and remove hidden features ([142ee30](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/142ee30e0883557ed4249cbd90e28695ddce23cd))
- *(frontend)* Extract widget parts and remove unused code ([b027578](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/b0275784bb8e8d643439f9e100b13e29faca7cc2))



## [0.20.1](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.20.0...v0.20.1) - 2026-03-14 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.20.1))

### 🚜 Refactor

- *(core)* Standardize breakpoints, add error logging, and remove unused code ([3ab20b5](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/3ab20b5057d180c3c94b6647c767083b4a07c626))
- *(core)* Add retry logic, shared HTTP session, and improve resource management ([a0290e1](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/a0290e114c0643516747b5a5c35b649e666f42fe))
- *(ui)* Extract reusable widgets and improve code organization ([3900ef0](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/3900ef037c4998a598ddcf983d88387c3b1f75d8))



## [0.20.0](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.19.1...v0.20.0) - 2026-03-12 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.20.0))

### 🚀 Features

- *(podcast)* Implement asynchronous AI summary generation with task queue ([5e2b998](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/5e2b998e499ea4ff07f01eaca3becd871022773d))

### 🚜 Refactor

- *(podcast)* Add glassmorphism gradient background and simplify expanded player layout ([01b15c9](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/01b15c960b44930d90008e01d796fe13340bc3dd))
- *(podcast)* Improve playback rate selection UX with instant sheet and async correction ([3704ec3](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/3704ec319f19ae66894041defbb7ab1a17f9d2e1))
- *(podcast)* Remove custom prompt feature from AI summary generation ([b59dcae](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/b59dcae7b3f4e38b055a398d94f6fd9332baf074))
- *(podcast)* Redesign mobile episode detail tabs as text with underline ([f34c47b](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/f34c47b474da4c066c7408c71b68e282a57cd33d))
- *(podcast)* Improve loading states and add widget tests for AI summary generation ([2b7f0c4](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/2b7f0c4cf37155731456e71125cc87a6702cbaff))
- *(profile)* Redesign cache management page with compact header and capsule actions ([51c797c](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/51c797c9e49acb4c937e40b5a5fead9f4db43047))



## [0.19.1](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.19.0...v0.19.1) - 2026-03-11 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.19.1))

### 🎨 Styling

- *(podcast)* Centralize navigation dock spacing constants and adjust mini player gap ([c700ece](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/c700eced1945cd576a4e876e07bdff6715f9cd03))

### 🐛 Bug Fixes

- *(podcast)* Remove queue sheet opening delay and add timeout handling ([55b2ab6](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/55b2ab6671b979e8e6aff04a4681b83d8c540551))

### 🚜 Refactor

- *(podcast)* Simplify episode detail header and remove hero/compact toggle ([bb592eb](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/bb592eb5be656afa6cffb44f382a81b20c434b58))
- *(podcast)* Sync playback rate with server and improve testability ([1dcc609](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/1dcc609a6404a6f5215149845223cc5bde08e67b))
- *(podcast)* Prevent duplicate queue sheet opens and disable playlist button while open ([b511bd8](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/b511bd8a71b4f908febed31c1ce639fd65c5219f))



## [0.19.0](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.18.0...v0.19.0) - 2026-03-11 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.19.0))

### 🎨 Styling

- *(podcast)* Simplify expanded player overlay and compact spacing ([4f2f195](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/4f2f195a9f0a53f46a580f8933a5d5028ad000c8))

### 🚜 Refactor

- *(podcast)* Separate audio state from UI state and remove standalone player page ([78474ca](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/78474ca4916ab9172c81f3518e91b8f228e60029))
- *(podcast)* Restructure player from overlay to layout-frame architecture ([5fe61c8](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/5fe61c856f7265f96e560bc9e90a446aef8245d6))
- *(podcast)* Redesign expanded player as overlay and add playback state badges ([16a431e](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/16a431e43bdc85861f878e35c50d96bac2761f99))



## [0.18.0](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.17.0...v0.18.0) - 2026-03-11 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.18.0))

### 🐛 Bug Fixes

- *(podcast)* Add backward compatibility for summary keys and improve error handling ([4d98ba1](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/4d98ba154ee5546f0314a3b0ed9c2543c5552e6f))

### 🚜 Refactor

- *(podcast)* Simplify header implementation with animation support and add density options ([f2bc9b4](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/f2bc9b4018c15cab8b508f208c22959ba3e0670e))



## [0.17.0](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.16.0...v0.17.0) - 2026-03-11 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.17.0))

### 🐛 Bug Fixes

- *(frontend)* Improve null-safety and race condition handling across auth and search features ([81a64c8](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/81a64c81531b2a25bcc73a92c94a99563310c645))
- *(frontend)* Add lifecycle guards and prevent race conditions in async operations ([20d6b89](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/20d6b89f7e3e15e98309a3434c53ac4d7bfac914))

### 📚 Documentation

- Restructure and consolidate project documentation ([df375ee](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/df375ee49ede6b3145bcd8e0b6ae37cb65acfe1f))

### 🚜 Refactor

- *(profile)* Add responsive horizontal padding to cache management page ([bb85b89](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/bb85b899b713f4101b9c7274f7c018d85354e2e4))
- *(podcast)* Extract granular audio playback selectors for optimized rebuilds ([030bccd](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/030bccdee50c8f121e86a9a4d9729c43203af694))
- *(podcast)* Implement global podcast player host with route-aware layout ([f6d4edb](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/f6d4edb69587c9162d97012e27facc78a044a861))
- *(podcast)* Optimize state management and add lifecycle guards for audio player ([3784e3b](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/3784e3b38d0b3e9566a1ad2c710a5d82b5376673))
- *(podcast)* Implement responsive layout modes with route-aware surface contexts ([073c8a0](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/073c8a0696c89aed7b0550aefa8fcffa9e1b2e6c))
- *(podcast)* Extract desktop rail width constant and make sidebar width dynamic ([6cc2918](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/6cc29181609282b6083102de43c1bef07a3e1bf6))



## [0.16.0](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.15.3...v0.16.0) - 2026-03-10 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.16.0))

### 🐛 Bug Fixes

- *(podcast,subscription)* Ensure parser cleanup and fix SQLAlchemy boolean filter ([1a1f177](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/1a1f177e756356b996915583d4eb8a630b5ed7c4))

### 🚀 Features

- *(summary)* Enhance default prompt for AI summary generation with detailed guidelines and structure in Chinese ([8e39de3](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/8e39de3a490e9217c3d35488c3098ce76f8b966c))
- *(datetime)* Ensure timezone awareness for last fetched and published dates in podcast orchestration ([5c12014](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/5c12014120fccc587cdf79f3e609f2adb7bd449a))
- *(core)* Add shared Redis lifecycle management and batch subscription operations ([4d14779](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/4d14779ed25ce1bf03169bc47b86f925fce898e1))
- *(core)* Add readiness probes and refactor observability middleware ([f29f757](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/f29f757cc85da7ec801e61ffd7cc6ef33b1a10a6))

### 🚜 Refactor

- *(core)* Migrate from pip to uv and upgrade Python to 3.11 ([66b25d4](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/66b25d454076c35e47414108bc4ae0a61e6b16b4))
- *(podcast)* Optimize transcription runtime with concurrent task handling and Redis sorted-set indexing ([d8002ef](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/d8002ef896f7c0af6ab1a31a2dc71ec1533ea374))
- *(frontend)* Clean up unused code and add polling for summary sync ([d11fc77](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/d11fc7791665570d006de98c35613225cc8c1213))



## [0.15.3](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.15.2...v0.15.3) - 2026-03-09 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.15.3))

### 🐛 Bug Fixes

- *(i18n)* Fix garbled Chinese text in error messages and logs ([bf5698f](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/bf5698f9f7b3f0f71ce4a0d9b2cbc1dc1307a8fd))
- *(mock)* Add get_settings method to mock config module ([ae7db38](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/ae7db382c45b6b63415cf635b9ce3fd705586f89))

### 🚀 Features

- *(datetime)* Add ensure_timezone_aware_fetch_time function and update related logic for timezone handling ([d9b0e27](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/d9b0e27cc7638801acc26be3b224bc6b4ef1b9f9))
- *(auth)* Add UTC expiration handling and server time to auth responses ([d9fa92d](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/d9fa92dd095f301b562a95c597ccd4d172caeb5d))

### 🚜 Refactor

- *(nginx)* Simplify template activation with direct envsubst rendering ([72c130b](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/72c130bec2c35d74a1196566b8bfd600cd8ad181))



## [0.15.2](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.15.1...v0.15.2) - 2026-03-08 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.15.2))

### 🐛 Bug Fixes

- *(podcast)* Fix revision tracking and callback signature issues ([c6a0876](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/c6a087623f219fd56125f3a2719435173e1d4500))

### 🚜 Refactor

- *(podcast)* Restructure queue header layout to vertical orientation ([cbeca80](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/cbeca8017891cebe7206e5f73aaeb60f2c25ad41))
- *(podcast)* Restructure queue header layout to improve spacing and fix state update timing ([62519ba](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/62519bab3074dd943da607052dd082f4cd021bf8))
- *(podcast)* Restructure queue header layout with vertical title and info/actions row ([92658f7](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/92658f75f51b7da2a056d26f19ef81546700588f))



## [0.15.1](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.15.0...v0.15.1) - 2026-03-07 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.15.1))

### 🐛 Bug Fixes

- *(core)* Fix UTF-8 encoding issues and improve encoding handling ([a04ccc5](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/a04ccc548f272da8beda8608fedc149d27572344))

### 🚜 Refactor

- *(podcast)* Redesign queue mutation logic and improve playback resolution ([787e288](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/787e28833c1fa70c4131b411ecbac9fe4eee07d6))
- *(core)* Implement lazy evaluation and centralized provider pattern ([d719033](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/d7190335367553e98447fad074cafcaa3575096b))
- *(backend)* Extract service layer and split podcast routes into focused modules ([ec0b7aa](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/ec0b7aa9773a2b5e8b9fdd98ed545292dddd42b4))
- *(backend)* Extract workflow services and reorganize podcast repositories ([18bfa0c](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/18bfa0c9d4e9a1d9d18f606fe51cee8868377b23))
- *(admin, podcast)* Centralize admin dependencies and reorganize podcast repositories ([c6060fb](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/c6060fbfec9f50e7b6aaa0ee43962a452a2909d2))
- *(backend)* Finalize dependency centralization and extract services from routes ([b30cf8c](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/b30cf8c06ea7067044e8a9cf069859c183a5d639))
- *(backend)* Convert single-file modules to packages and split podcast transcription services ([7daaee9](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/7daaee9d01178e8d06c03807e560a69ca8602c12))
- *(admin)* Move API keys and subscriptions business logic to service layer ([2153604](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/2153604a5ba64aaa2e785c9dbb38270e97809c43))
- *(core)* Centralize dependency providers and split podcast repositories into modules ([eb5db2a](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/eb5db2a482c858be059b634375cee4fc9648a6a1))
- *(services)* Split large service classes into focused single-responsibility modules ([5363ad3](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/5363ad3434d51c71246244cbcad41d17b56c002a))
- *(podcast)* Extract response assembly logic into dedicated module ([92ae85e](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/92ae85e75afd976d751ce9569a11bb9377d8a206))
- *(podcast)* Introduce projection pattern layer for service outputs ([e245792](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/e2457926cc9cfb4e87b1b3ee0cba1891c796ddce))
- *(podcast)* Remove backward compatibility shims and update tests ([7ae8c82](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/7ae8c82973543613533ff7a394b2ffe32bd32218))
- *(core)* Split large service classes into focused single-responsibility modules ([308ab4c](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/308ab4c2c06515872ae8920382cf89911dfc7ccc))
- *(podcast,subscription)* Consolidate split services and routes into unified modules ([921f265](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/921f265ee343ac7c0a0c88e130002add9a796211))



## [0.15.0](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.14.3...v0.15.0) - 2026-03-07 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.15.0))

### 🎨 Styling

- *(podcast)* Simplify border radius configuration for expanded player panel ([48f505c](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/48f505c4ca3be4d6219f3c561876d2005f9be4d2))
- *(auth)* Improve remember me checkbox styling with Material 3 design ([7a145be](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/7a145be5b7bb973e3b87682b6b06f73e05291d69))

### 🚜 Refactor

- *(podcast)* Redesign discover page header and search layout for compact UI ([b8f9f3e](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/b8f9f3efe279354c9de7d9d973399b3f6d092173))
- *(podcast)* Move play button to header row in episode cards ([5520f79](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/5520f79bda6fe09077459a9988f2dd75ab2b076d))



## [0.14.3](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.14.2...v0.14.3) - 2026-03-07 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.14.3))

### ⚙️ Miscellaneous Tasks

- *(deps)* Update Flutter dependencies ([7a8d16b](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/7a8d16b4064f0767899becd804e522f588778307))

### 🎨 Styling

- *(podcast)* Simplify FilterChip side border configuration ([7dcf917](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/7dcf917d27d2148175a6d4bbbc817769edd9c05f))
- *(podcast)* Add rounded top corners to expanded player panel ([55666ca](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/55666ca97c3260d857e41869ec403bf09fa9ca82))
- *(ui)* Hide back button on mobile for detail pages ([284053c](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/284053ca50dfdd2c974a71de3f498412a8bca658))



## [0.14.2](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.14.1...v0.14.2) - 2026-03-06 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.14.2))

### 🎨 Styling

- *(podcast)* Redesign play button in discover episode detail sheet ([5a63ed1](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/5a63ed19abb2cd1f8e02c058b705ac78851a2831))

### 🚀 Features

- *(podcast)* Add episode actions and consistent card design to discover sheet ([1c20ed1](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/1c20ed1447ce239139a25844c7f5bc6a1b0d3084))



## [0.14.1](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.14.0...v0.14.1) - 2026-03-06 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.14.1))

### 🎨 Styling

- *(core)* Disable inkwell splash effects on navigation items ([392024e](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/392024ec5edf5cc0145fa544ece44c963d71856e))
- *(podcast)* Adjust summary text style in daily report page ([217556d](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/217556dcc0429285b319eb89f4d7701acf5a8f01))

### 🚜 Refactor

- *(core)* Restructure profile shell layout for better scroll behavior ([f790515](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/f7905151c18b867d7750371786cdd5f29f53ff78))



## [0.14.0](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.13.6...v0.14.0) - 2026-03-06 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.14.0))

### 🐛 Bug Fixes

- *(podcast)* Fix row extraction after adding published_at to pending episodes query ([8e148d7](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/8e148d76c1b2b11668346dafeeae56e77a5326f1))

### 🚀 Features

- *(podcast)* Redesign queue sheet with improved state management and UI ([732be59](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/732be599f2df2a7f9037ae191ae5498615dcc9bc))

### 🚜 Refactor

- *(podcast)* Restructure expanded player into reusable components with modal overlay ([c75cde8](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/c75cde8dc50dc13d54448e9616c9f47c31a4e981))
- *(core)* Implement Mindriver glassmorphism design system with reusable app shells ([36db611](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/36db6118eaf08b09c2ff462115a09297e007f6b8))
- *(profile)* Enable podcast player on profile tab with improved spacing and positioning ([92ed51d](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/92ed51d80681b353394d3a07478dcfd355e92085))
- *(podcast)* Replace expand/collapse with scroll-based pagination for discover charts ([82fc419](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/82fc4196be61ce46ec19ff42c2c772766262ec7a))
- *(core)* Unify shell layouts with rounded viewport and remove compact variants ([b9d8dca](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/b9d8dca14c1cfbd4d670edd14ceb670e4d9a593e))
- *(core)* Apply glassmorphism design system to profile and podcast pages ([60cf340](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/60cf340b413a72f3cb57dbdc59fe281f83a1ffa4))
- *(core)* Extract reusable header components and simplify navigation elements ([220bdf8](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/220bdf85b9f7781945abc22be90bbfc519b01589))
- *(core)* Extract LoadingStatusContent and add circular button variant ([f068471](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/f06847183490ccc95e1524fc9b860c686476eb3e))
- *(core)* Unify system UI overlay and add bottom backdrop to mobile navigation ([9866f09](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/9866f09ac6aba57e5651dc1e9848b6622364c597))
- *(settings)* Improve update dialog platform handling and navigation bar design ([3cb5c34](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/3cb5c345a54d3e9ce3fce7647e49c7debc935f56))



## [0.13.6](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.13.5...v0.13.6) - 2026-03-02 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.13.6))

### 🐛 Bug Fixes

- *(ai)* Increase API key validation timeout to handle slow model responses ([41ff87f](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/41ff87f20e6f4fd8ef02973a7861b950275e62bf))
- *(ai)* Use exact matching for invalid API key detection to avoid false positives ([68714f5](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/68714f5daafca1b97622521204b74ac18431f90b))
- *(podcast)* Handle Redis client lifecycle across Celery event loops and refactor lock ownership ([6a61f4f](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/6a61f4fa625be377929df670656d519278cacdaf))
- *(podcast)* Prevent play_count inflation on heartbeat updates and add per-user playback snapshot isolation ([5b9da86](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/5b9da86bcbe0e5ce848c2dd41f441886cb839f94))
- *(podcast)* Defer queue expiration until after logging to prevent accessing stale items ([8b46490](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/8b46490fe5b94e4ce3db52f38fe9e2ffa7a64938))

### 🚀 Features

- *(admin)* Support testing stored API keys directly from database ([ba32f15](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/ba32f15233b0e17224edd43e88e4fec29de35a76))
- *(podcast)* Add pending transcription backlog processing with scheduled dispatch ([80fd3b2](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/80fd3b2af4f5fdb9c96c76b490750d548278ddbe))

### 🚜 Refactor

- *(podcast)* Filter missing transcripts before applying processing limit and add comprehensive tests ([4858726](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/4858726b76524d0e790108c68f8fd6873123e447))
- *(podcast)* Improve Celery task routing and transcription pipeline handling ([1047688](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/10476884e526598daa52a45bc64cd34a894cf922))
- *(podcast)* Consolidate transcription and summary pipeline with centralized locking ([f2a5c67](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/f2a5c67a694c740a43fd7ce3a793391edb7989c1))



## [0.13.5](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.13.4...v0.13.5) - 2026-03-01 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.13.5))

### 🎨 Styling

- *(profile, settings)* Standardize dialog colors using onSurfaceVariant token ([83d035b](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/83d035bb3a47ec1f35c993e17c95b36459cd8522))
- *(profile)* Further refine cache management page colors with Material 3 tokens ([994abc3](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/994abc3dad2c20828b6342be8dd39fc9d03bbfb0))

### 🚜 Refactor

- *(podcast)* Extract shared utilities and optimize repository queries ([8e73515](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/8e73515ac46dd8cc34e71f9dbc42c4583c372950))
- *(podcast)* Use window function for playback history total count and remove unused batch method ([6adf195](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/6adf195842df891485c4a92123e5773e81cd6965))



## [0.13.4](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.13.3...v0.13.4) - 2026-02-28 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.13.4))

### 🎨 Styling

- *(frontend)* Standardize color tokens using onSurfaceVariant for consistent UI elements ([4d71477](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/4d71477ae0ca027152478d46484c45dbcb2dcf0e))

### 🚜 Refactor

- *(frontend)* Extract widgets, add performance optimizations, and improve code organization ([c7687ff](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/c7687ff42794fa6ccbfbcb51eb23238d70aea444))
- *(podcast)* Extract widgets, add selectors, and improve code organization ([0683171](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/0683171a1794006b65742b2e96992b308a933e7d))



## [0.13.3](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.13.2...v0.13.3) - 2026-02-27 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.13.3))

### 🚀 Features

- *(podcast)* Add latest daily report date to profile stats and consolidate provider calls ([5bc3cbd](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/5bc3cbdad5031778e1a5cf031d77e31ee74492d7))



## [0.13.2](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.13.1...v0.13.2) - 2026-02-27 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.13.2))

### 🐛 Bug Fixes

- *(podcast)* Fix queue state synchronization issues and add optimistic removal ([9a06b30](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/9a06b305efcacde8b9eb0adca247d95e70ee4bb3))



## [0.13.1](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.13.0...v0.13.1) - 2026-02-26 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.13.1))

### 🐛 Bug Fixes

- *(podcast)* Prevent queue wrap-around on last episode completion and improve add-to-queue positioning ([551e4a5](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/551e4a53d2f686c9a5cd44a7e2585fcc80a4e150))

### 🚜 Refactor

- *(core, podcast, ai)* Centralize ORM registration and remove unused schemas ([66b1ff9](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/66b1ff919e48de3309179b809d68e3e181c2eaf1))



## [0.13.0](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.12.5...v0.13.0) - 2026-02-26 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.13.0))

### ⚙️ Miscellaneous Tasks

- *(frontend)* Update dependencies to latest versions ([b3cba60](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/b3cba6054de6367d3ce4eb0a73614489ec5ac954))

### 🚜 Refactor

- *(core, podcast, frontend)* Fix deprecations, reduce code duplication, and clean up unused code ([dc49a78](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/dc49a78d30f71b4eb6a787f4c27dd744bbd9bb6e))
- Fix deprecations, reduce code duplication, and clean up unused code ([bb1a33b](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/bb1a33b26e09e5269aef8af0e90a211b1de83b4a))
- Remove deprecated features and legacy code ([302f260](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/302f260b133428113afb1b72916ea2747f40c158))



## [0.12.5](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.12.4...v0.12.5) - 2026-02-26 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.12.5))

### 🐛 Bug Fixes

- *(podcast)* Correct garbled Chinese text in bilingual error messages ([a7ddc30](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/a7ddc306111899645293f9b206a08750738f1ada))

### 🚜 Refactor

- *(core, network, podcast)* Standardize logging, improve DioClient initialization, and extract episode detail page parts ([0bec966](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/0bec9668e935d9e44932cb85e1542b6611c767dc))
- *(ai, podcast, core)* Remove deprecated features and clean up unused code ([9434a85](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/9434a8576d74c7aeba5cb1eac6e841f7262f6770))



## [0.12.4](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.12.3...v0.12.4) - 2026-02-24 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.12.4))

### 🚀 Features

- *(podcast)* Prefer AI one-line summary in feed and improve HTML sanitization ([4751b9f](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/4751b9f284a20ef6abe7bcad3f8153a9c8cb7585))



## [0.12.3](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.12.2...v0.12.3) - 2026-02-24 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.12.3))

### 🚀 Features

- *(podcast)* Implement lightweight feed query path with fast refresh ([5a6e144](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/5a6e1446087bd41ecbafeeccb74c76df0a5d1726))

### 🚜 Refactor

- *(podcast)* Implement unified queue activation with position-based ordering and revision guards ([424cdeb](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/424cdebcaf58d42ea69f3bb45df45415aeffea80))



## [0.12.2](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.12.1...v0.12.2) - 2026-02-23 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.12.2))

### 🎨 Styling

- *(ui)* Reduce top floating notice gap and add precise positioning test ([6825e09](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/6825e09934bcb64f8f412610ad2fe773a15a72c2))

### 🚜 Refactor

- *(auth)* Restructure token refresh with failure classification and expiry tracking ([515f632](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/515f632854e5804bab710bc0440cdfb208349f1e))



## [0.12.1](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.12.0...v0.12.1) - 2026-02-22 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.12.1))

### 🎨 Styling

- Improve exception chaining and update deprecated APIs ([f13c8cf](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/f13c8cfa1f15e0429d6ff402cecb2802ecfa3969))
- *(backend)* Migrate from deprecated Pydantic v1 to v2 APIs ([0158657](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/0158657f0ccc06bb79d7a0663cc089dcd00a7b71))

### 🚜 Refactor

- *(podcast)* Replace monolithic PodcastService with specific service dependencies and cleanup unused code ([76c01fd](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/76c01fdf4d9ba3c31af684857a65394a938b64ca))
- Remove unused code across backend and frontend ([eb8a41e](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/eb8a41e31e866bf7b7d39fa0a2e36b7e39b28381))
- Remove unused code across backend and frontend ([fdce996](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/fdce99608c2c4c1559f72520e85fdaf7936a74b3))



## [0.12.0](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.11.3...v0.12.0) - 2026-02-22 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.12.0))

### ⚡ Performance

- *(podcast)* Optimize ETag caching, add query indexes and improve middleware performance ([5c0eec6](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/5c0eec6919843e4202ccb3c8ad6530b5ae6354b7))
- *(core)* Add runtime metrics tracking for DB, Redis and middleware ([a9d0abf](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/a9d0abf76437d7442e8707f25fea229e674185b3))
- *(podcast)* Add filter-aware subscription list caching with v2 keys ([9649b7f](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/9649b7f11e0670ea27904446966f078126f52fc6))
- *(subscription)* Optimize repository queries and add selector-based rebuild reduction ([2e91ecb](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/2e91ecb75dffe7f5f044c40e215dd52352140081))
- *(podcast)* Add selector-based state watching to reduce widget rebuilds ([429ed8b](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/429ed8b013ba2e2bbf2e80a6b6fa0c2771faec49))

### 🚀 Features

- *(monitoring)* Add observability infrastructure with admin dashboard and alert thresholds ([2552512](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/25525122440ba330a6d05989ed3974e831b2f53c))

### 🚜 Refactor

- *(podcast)* Extract core providers and add null-safe localization fallback ([920f200](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/920f200f055d0feb2553160f40903fac357f8209))
- *(podcast)* Extract modular providers and add API compatibility improvements ([ffe5378](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/ffe53782ac573e79f752e138adea344734f1fec8))
- *(podcast)* Swap header layout to show date on left and action on right ([c8dc49c](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/c8dc49c19adc95086492207e280e6513f4b188e4))

### 🧪 Testing

- *(etag_cache_service)* Add unit tests for ETagCacheService functionality ([e357df7](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/e357df78844bcbd83e7e208aedd313116c752905))



## [0.11.3](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.11.2...v0.11.3) - 2026-02-22 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.11.3))

### 🐛 Bug Fixes

- *(podcast)* Fix background prefetch loading state and improve daily report layout ([4f369ed](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/4f369ed9ea4d23bb6a02cbe34ac6c8f43680b783))

### 🚀 Features

- *(podcast)* Add HTTP max-age caching support and refactor daily report calendar ([ed34c4b](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/ed34c4b3cca19475f4595d93048188b54a954797))

### 🚜 Refactor

- *(podcast)* Remove per-item expansion and consolidate regenerate button ([9caeb87](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/9caeb872b23bce5681e27c5a3925c246ea95ddc8))



## [0.11.2](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.11.1...v0.11.2) - 2026-02-21 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.11.2))

### 🐛 Bug Fixes

- *(ci)* Replace grep -P with sed for portable build number extraction ([4936d1c](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/4936d1c7e9f1ad5773f8537335db3c945ef1255a))



## [0.11.1](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.11.0...v0.11.1) - 2026-02-21 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.11.1))

### 🎨 Styling

- *(ui)* Replace hardcoded white with theme onPrimary for loading indicators ([e79c3a8](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/e79c3a8a7ddc491fef420e421a5b72f9256315f5))

### 🐛 Bug Fixes

- *(ci)* Fix Android version code extraction from pubspec.yaml instead of tag ([02d6e1e](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/02d6e1e997756d761bce402928fc0322cdc2936e))



## [0.11.0](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.10.5...v0.11.0) - 2026-02-21 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.11.0))

### 🎨 Styling

- *(ui)* Remove borders from cards, dropdowns, and activity indicators ([3dea840](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/3dea840695624e75f9ecdee533d53557d0d859de))

### 🐛 Bug Fixes

- *(podcast)* Improve daily report error handling and add scrollable items view ([5488bfa](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/5488bfaff9ebee33d3f0fe09ba52bf266e993bf0))

### 🚀 Features

- *(podcast)* Add daily report feature with automatic generation and history ([2a82477](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/2a82477f00d0db29da4d55e3f4796787df6eab8a))
- *(podcast)* Add rebuild flag for daily reports and improve UX ([5ab07ea](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/5ab07ea6dcdbf88ee6f3a2cc65ecc9c099ea5359))
- *(podcast)* Add inline calendar UI and progressive date loading for daily reports ([7ac29d8](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/7ac29d89ee9aa44352effeb5d5b2fd925d54614c))

### 🚜 Refactor

- *(podcast)* Move daily report to dedicated page accessible from profile ([442627d](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/442627dd48a1a5cef25b774ebd4f4a8854b53a42))



## [0.10.5](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.10.4...v0.10.5) - 2026-02-16 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.10.5))

### ⚙️ Miscellaneous Tasks

- *(release)* Update release workflow and remove standalone scripts ([3c253cf](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/3c253cf432ac23cf82b42f70bdd19d82970cbe48))
- Remove unused CI workflow, task board docs, and desktop pubspec ([eef03bd](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/eef03bd8363f84b93a2b754d6f816cfbccc33e80))

### 🚜 Refactor

- *(ui)* Replace profile user selector pill button with circular avatar ([de34f70](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/de34f700f8b7a681ae394859f27a6c75fa8ba928))



## [0.10.4](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.10.3...v0.10.4) - 2026-02-15 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.10.4))

### 🚜 Refactor

- *(ui)* Add collapsible desktop sidebar and adaptive sheet helper ([c6777e5](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/c6777e5737239f61939a39be6df4daf5b1839623))



## [0.10.3](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.10.2...v0.10.3) - 2026-02-15 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.10.3))

### 🚜 Refactor

- *(core)* Move audio service initialization from app state to main function ([6ca8731](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/6ca8731c896d2e60a5d979bdc40896b7ee9cd011))



## [0.10.2](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.10.1...v0.10.2) - 2026-02-15 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.10.2))

### 🚀 Features

- *(podcast)* Add episode search to podcast discovery ([10eb705](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/10eb70540a70d67d5948b28779803c234453f555))

### 🚜 Refactor

- *(core,ui)* Move audio service init and improve UI components ([465f292](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/465f292acd6de3c25fd52c29c9ce82baec07259b))



## [0.10.1](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.10.0...v0.10.1) - 2026-02-14 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.10.1))

### ⚡ Performance

- *(ui,podcast)* Optimize app startup and add local caching for playback and episodes ([e47c380](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/e47c380f7db232afd8ce9f57904e4d3d2238cce1))

### 🐛 Bug Fixes

- *(ui)* Fix top floating notice theme context and dense layout detection ([d61906a](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/d61906a7375f3fe46169f979b41b611ee89e35d5))

### 🚀 Features

- *(podcast)* Add dense layout mode for power users and improve dark mode visibility ([1ed0a9c](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/1ed0a9c86da105ee8da42ae9aa5d1278ab1a65d7))

### 🚜 Refactor

- *(podcast)* Force dense layout and simplify initialization ([88d3dff](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/88d3dff5c2b522f2528b59e935a061f6136e3961))



## [0.10.0](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.9.0...v0.10.0) - 2026-02-14 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.10.0))

### 🎨 Styling

- *(podcast)* Redesign discover page with custom chips and tab selector ([09da603](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/09da6039898164cd9632602b4f902a42dbe5c522))
- *(podcast)* Reorganize navigation labels and swap tab positions ([b825206](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/b825206138d42a2b8e3f8a607044cd89181538a0))
- *(podcast)* Improve navigation labels and icons for better UX ([092d967](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/092d967db3cc9d747fa9ee2376918195a6df728e))

### 🚀 Features

- *(podcast)* Add Apple Podcast RSS discover feature with top charts ([9b7186d](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/9b7186d125716fa769ce3e5b9b32a1e02f679d35))
- *(podcast)* Add cache layer and optimize data loading strategy ([053f505](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/053f505d90e14a42b224dc3792208df4b4c5b7d3))
- *(podcast)* Add cache layer to profile stats and history providers with filter caching ([365fed0](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/365fed025d58b2c46473f791a07f4eca54df14f0))
- *(podcast)* Add iTunes episode lookup and in-app preview for discover chart ([3712b00](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/3712b00ccc81d24ecfd626ea42cfd7318f3e44b6))
- *(podcast)* Add auto-expand on scroll and hydration for discover charts ([0497221](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/04972215fb7a9c9544c98c7cfefc0a9eb026cc01))

### 🚜 Refactor

- *(podcast)* Move episode restore logic to HomePage for single execution ([829eacb](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/829eacbf4e686518d880a0f029761cf9f5c06c03))



## [0.9.0](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.8.0...v0.9.0) - 2026-02-14 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.9.0))

### 🎨 Styling

- *(profile)* Switch dark theme to pure black and add cache item count display ([bdac20f](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/bdac20f32fec02e2149964d8aca90874ad01c54d))
- *(core)* Fix splash screen flash and improve theme consistency ([0ee403d](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/0ee403dd1067cc9cb34d3a0bc1d61b09393d776f))

### 🚀 Features

- *(profile)* Add clear cache functionality with integrated media cache service ([e19662c](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/e19662c5c0c02dffe13748d4452b60af178ce43c))
- *(profile)* Add dedicated cache management page with category selection ([dd2b7b5](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/dd2b7b5cda75cba293a2710037f0631644d4fb25))

### 🚜 Refactor

- *(podcast)* Consolidate image handling and reorganize subscription actions ([db9493f](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/db9493f3f7849262075dd1325e9fc8776d011667))



## [0.8.0](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.7.0...v0.8.0) - 2026-02-14 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.8.0))

### ⚡ Performance

- *(podcast)* Optimize queue operations and add loading states to add-to-queue ([1a10a5a](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/1a10a5a87928652943898fb6670c994f0a3a2a27))

### 🚀 Features

- *(core)* Add top floating notice widget and integrate across app ([ef467ce](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/ef467ce2670498ad39cf7820ce72a2d2fbc4cfda))

### 🚜 Refactor

- *(profile)* Replace logout button with user dropdown menu and update localization ([0675179](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/067517925fc55f00bd4d192b6e707741388eaff6))
- *(podcast)* Improve queue sheet UI styling and localization ([c87284e](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/c87284eeac73d7d7f73e69556a222f05e5239451))
- *(profile)* Move subscriptions to profile section and add dedicated subscriptions page ([83e3e5f](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/83e3e5fe795998eaf0c564fcd17912848184e9c9))



## [0.7.0](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.6.0...v0.7.0) - 2026-02-13 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.7.0))

### 🐛 Bug Fixes

- *(podcast)* Make mobile bottom spacer transparent when player collapsed ([f277036](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/f2770362de2bddb45381a13a4a2083736c878f26))

### 📚 Documentation

- Update README.md with current features, API endpoints, and testing requirements ([5c96024](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/5c96024eabfa497320c63d476b3c801a47ad2c39))

### 🚀 Features

- *(home)* Auto-collapse audio player when navigating away from podcast tabs ([5a57dab](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/5a57dab6df460bdf0eaaeb5a83eadf4d611b2115))
- *(podcast)* Add mobile bottom spacer and redesign expanded player controls ([9c0f7c4](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/9c0f7c416b47a86b52b49a165f4b01acff5463ad))
- *(podcast)* Redesign podcast list page with Discover New section ([200faa6](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/200faa604f5243603c934a5849cff2a87cda0bb5))

### 🚜 Refactor

- *(podcast)* Consolidate audio player into bottom player widget ([35d975c](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/35d975c9d5420403d43f822a0551e373282d43bd))
- *(podcast)* Extract UI constants and reorganize podcast layout code ([b5d5c5a](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/b5d5c5a5d76c0b2a9d5ccbc58cc86f45d4cc65ac))
- *(podcast)* Restructure simplified episode card layout and add widget tests ([0ff6459](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/0ff6459cc28bd7ae8bdd5b1c2612f5cb2fdd440f))
- *(podcast)* Restructure desktop player position and update player visibility logic ([261081d](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/261081d4d12e48d0a098126f7afeb9fa69b56e40))
- *(profile)* Apply feed-style card layout to history page and responsive card styling ([e945297](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/e9452977ccdc0ad72496ab53f1f22ea45951327b))
- *(profile)* Restructure profile page and remove settings page ([a98737f](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/a98737f574642901b0cd4ab4a80c57744aad7a21))



## [0.6.0](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.5.5...v0.6.0) - 2026-02-13 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.6.0))

### 🚀 Features

- *(podcast)* Restore last played episode on authenticated startup ([5b39617](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/5b39617fe4e05837d3ec66e5554a39102f55003f))
- *(podcast)* Add playback position display to queue items ([5f23220](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/5f2322090c73a3d59ca4cbb5f8040242bca7a1cd))

### 🚜 Refactor

- *(podcast)* Format code, refactor tests and adjust tab bar padding ([3e9e4d3](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/3e9e4d3cccdf0ecb3e2577740496d4ba72d38fe8))
- *(podcast)* Optimize card layout spacing and add widget layout tests ([87ee2f6](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/87ee2f65330c2ef6de778112f4d692f92e9f5a2b))
- *(podcast)* Remove unused code and add config image_url fallback ([b138132](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/b138132b8aa1f4541979795f5b471553baf6c03a))



## [0.5.5](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.5.4...v0.5.5) - 2026-02-13 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.5.5))

### ⚙️ Miscellaneous Tasks

- *(claude)* Add smart commit command for automated commit message generation ([6a13f10](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/6a13f1044ec4461745a0f1c5d4580df22bfd9d42))

### 📚 Documentation

- *(claude)* Translate commit.md command from Chinese to English ([18dfd76](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/18dfd76e5a027db66abd3e9c35c8e8144fe00051))

### 🚀 Features

- *(settings)* Render release notes as Markdown and improve update dialog flow ([bc2ba43](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/bc2ba4395e5d948622adae7b9408d29146e049ef))
- *(podcast)* Add profile stats API and lightweight playback history endpoint ([d6ab74b](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/d6ab74b5f79bc4f844d5b0e9188576c387f7fa4e))



## [0.5.4](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.5.3...v0.5.4) - 2026-02-12 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.5.4))

### 🚀 Features

- Hide bottom player when switching to chat tab; add tests for player behavior ([dcd00e7](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/dcd00e77aaa7fd94b54c67503c5fa885738408ec))

### 🚜 Refactor

- Improve layout and styling of podcast episode detail page tabs; enhance logging for better debugging ([c8b650b](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/c8b650b6d080cffdf0bf783066b859632dbd8779))



## [0.5.2](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.5.1...v0.5.2) - 2026-02-11 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.5.2))

### 🚀 Features

- Refactor image export behavior and update related tests; remove unused message count badge in chat widget ([f4109cb](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/f4109cbbce7a0b7f1d4f5a51c67c45482344a8aa))



## [0.5.1](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.5.0...v0.5.1) - 2026-02-11 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.5.1))

### 🚀 Features

- Add localization for podcast share image preparation and in-progress messages ([9f7cd79](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/9f7cd79f944b68315748639d55ede36c65a9f8ea))
- Enhance ConversationChatWidget with new chat and history buttons, update message count logic, and improve UI responsiveness ([3753ece](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/3753ece38d64860788db60a5c914ec093ad19689))
- Update ConversationChatWidget UI and add tests for message selection and icon behavior ([9ea36b2](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/9ea36b2b24182bfb184c8111517cf23d86b80829))



## [0.5.0](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.4.1...v0.5.0) - 2026-02-11 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.5.0))

### 🚀 Features

- Track episode views and add playback history feature ([353606b](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/353606b990bde5ccb26ec7a03856dc71b364f894))
- Enhance share card width resolution logic and update max character limit for sharing ([592b779](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/592b77969d6a42502817f72dde3d9641c95f8b32))
- Refactor exception handling to use CustomJSONResponse for consistent JSON formatting ([37c9962](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/37c996255222548f80cf7936bc9766173b3c5742))
- Update localization strings for podcast play button and enhance UI for collapsed actions ([15579c0](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/15579c0b75979082b5027ba4d3f56462fb50bfb5))



## [0.4.1](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.4.0...v0.4.1) - 2026-02-10 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.4.1))

### 🚀 Features

- *(localization)* Enhance localization for authentication, podcast, and transcription features ([e634eb2](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/e634eb2f3fad357b7b0485b62ce4b39a72d2fefb))



## [0.4.0](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.3.1...v0.4.0) - 2026-02-10 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.4.0))

### 🚀 Features

- Enhance podcast stats retrieval and improve profile page with dynamic episode and summary counts ([ccaac75](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/ccaac75b27321b318ac9dddd0e0c246c35196f20))
- Add sleep timer functionality with UI integration for audio player ([299ec54](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/299ec540c38975e72ba5a4592e39fed7bdc1abee))
- Refactor audio player and bottom player to integrate player settings, replacing sleep timer button with settings button ([021bb65](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/021bb65dec45a4f69d6b39d4e6949f6e01034423))
- Enhance bottom player widget with animated size transition and update home page to manage audio player state ([03b275c](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/03b275c63001fa6227a89839a5331ddb2bc931c4))
- Add conversation sessions management ([7de2f29](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/7de2f29ad0f32aec9db4ecfd873920b22edc0329))



## [0.3.1](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.3.0...v0.3.1) - 2026-02-10 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.3.1))

### 🚀 Features

- Improve layout and responsiveness of the expanded bottom player ([a82f1b0](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/a82f1b036afa29fde6cdc2410e12ae2cee6db8fd))
- Enhance audio player interactions and improve UI responsiveness ([774a803](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/774a80370558de628bfe0a6b559f383d01e414d3))



## [0.3.0](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.2.0...v0.3.0) - 2026-02-09 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.3.0))

### 🐛 Bug Fixes

- Add missing base tables migration and fix foreign key dependencies ([0561999](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/056199946f569402c13a5cee1364224773f6a152))
- Add check for existing enum in transcription task migration ([fff56f7](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/fff56f795e8dee25523f7cb12064b9c888c8ccfd))
- Use raw SQL for enum creation to avoid duplicate type error ([917b182](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/917b1823fc6d768e37a201542ba63f47c61bdf6d))
- Update podcast episode processing logic to skip auto-processing for old episodes ([5e01998](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/5e019988c3a637c37548176adf1cf092a5c2508a))
- Improve error handling for OPML import response in the frontend ([2af8faf](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/2af8faf4e157bbb70fa77579f27df0703cf302ff))

### 🚀 Features

- Update episode status filtering index to improve performance and address TEXT column limitations ([707ea2d](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/707ea2db5122eaf9efe810bd4cb9628c76a805d8))
- Add image_url field to subscriptions and update related logic for podcast handling ([c539380](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/c539380c0f8eadac10bd019497f72053882f644a))
- Enhance subscription metadata handling with fallback for image_url and additional fields ([617128d](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/617128df18867400f60a2f505c6bba59e6d482c7))
- Enhance OPML import to parse podcast episodes and store image URLs ([0bcd1c1](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/0bcd1c114381a262f11f8ec46cf06e2637892f28))
- Implement concurrent feed fetching with duplicate checks in OPML import ([967ab80](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/967ab800fd61c37826b36d399262e1c2ce7b519b))
- Implement OPML subscription episode processing with status safety checks ([8aa2363](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/8aa236347b8a607963944b81fcc444af4ae3b6b3))
- Add podcast queue functionality with backend support ([8d3c505](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/8d3c505b94e0a4d78604b790b0cc24fc494a992b))
- Enhance podcast player with playlist functionality and UI improvements ([d951030](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/d9510301b806c199dc602870773b22782d0fb883))
- Enhance podcast summary handling and playback synchronization ([575c4cf](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/575c4cf74f22104b3f9ad4c295ec1ef0f954162e))
- Add playback rate preferences and constraints ([c23f86c](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/c23f86c1fc8caed42ae4c7217b280b1eeec2aa16))

### 🚜 Refactor

- Consolidate initial migration and remove obsolete image_url migration ([c2ccf57](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/c2ccf5757c455d5b8358fd52509b16f7ce38a065))
- Replace inline onclick handlers with event delegation for subscription actions ([971a4ba](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/971a4ba4af203a44314fc7ab8a067d16ff713700))



## [0.2.0](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.1.10...v0.2.0) - 2026-02-08 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.2.0))

### 🎨 Styling

- Apply consistent import ordering and formatting ([78a4fd6](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/78a4fd65b946316027179f8b8a13a192255cf91f))

### 🚀 Features

- *(performance)* Implement comprehensive performance optimization ([900d0df](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/900d0dfa5c09117cfd6bec7bf099d2f72380b2f1))
- Add performance optimizations, security enhancements and type safety ([01d1209](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/01d12097adf1a0873bc04e451c2ef550542e999e))
- Remove knowledge domain and related functionality ([f81bc74](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/f81bc74d5434cf23214dd2152036630b99a31f35))
- Add server config runtime update and speed ruler control specifications ([66c8203](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/66c820370f10d3db0bffc1ac60a8720a489e7606))
- Implement ETag caching for podcast API responses ([1808f23](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/1808f23090cd0d422d67e7c115fa76f9b7bcc3d0))
- Enhance podcast subscription handling with direct access and metadata updates ([f16736c](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/f16736cc6c4e18f218f0594214cccb3fb8065da9))
- Refactor subscription handling and cleanup duplicates ([0fc802e](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/0fc802e81c3f971d52c8167a1193c5f173c9e3cc))
- Refactor podcast services and introduce dedicated stats service ([6cfc060](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/6cfc0608f7504e7a0486d1c0acf4c0f544b0df4d))
- *(subscription)* Add podcast subscription API routes and service dependencies ([33c324c](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/33c324cd36174c7071b6c0cceda318cfdf5c1f90))
- *(auth)* Enhance 2FA handling and session management ([5b2f5d2](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/5b2f5d232ecd1f6dff65a0d9982562879b034227))
- Update datetime columns to be timezone-aware and enhance podcast subscription image URL extraction ([6d3bd2f](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/6d3bd2fc733cae7e30083b2ec854ba515bf2365b))

### 🚜 Refactor

- *(podcast)* Split monolithic service into specialized services and add dependency injection ([a8ff5cf](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/a8ff5cfd643351fdaa2144939e3fe35dedef1e97))
- Move podcast integration to domain and clean up unused files ([e8de58a](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/e8de58aea01619f9e30304f2b18bc348cce6b8f2))
- Slim backend batch1 dead code and shims ([da21280](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/da212801f94832d33490876bb5dc66cb5bea60ed))
- Slim backend batch2 rewrite podcast task system ([3e9e40d](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/3e9e40dc98ff6f24b68d797897e4ec3b3c8c1a33))
- Slim backend batch3 modularize admin routes ([0c1b6d6](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/0c1b6d6625a7b4d3412092ee611a3acb90c6dafc))



## [0.1.10](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.1.9...v0.1.10) - 2026-01-24 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.1.10))

### ⚙️ Miscellaneous Tasks

- Clean up unused code and update dependencies ([5c0ccef](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/5c0ccef090fd0af76657586deccb11d43d5d0e01))
- Update dependencies and remove debug logs ([0880ac8](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/0880ac843da6ffce3a62d35816ff670e457b5f00))
- Remove unused imports and add analyzer exclusions ([0ea06e0](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/0ea06e0eec94af09e04524be685f86690a850289))

### 🚜 Refactor

- Clean up unused imports and improve type safety ([77c76d4](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/77c76d43ddca856c0d8ab09b0494f63407cdf948))
- Replace debugPrint with AppLogger for conditional logging ([a603155](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/a603155831d043ac14e70c1c6d0f5df04976ccac))
- Improve code quality and remove unused platform badges ([2df3b67](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/2df3b672a18bd90e3749907e0a2c33f507b48086))
- Rename full_name to account_name and add database index ([a17e3ef](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/a17e3ef0e9c3f1161807dec9de1eab04f78b4416))



## [0.1.9](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.1.8...v0.1.9) - 2026-01-18 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.1.9))

### Ci

- *(release)* Optimize build workflow and configurations ([87a456a](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/87a456a886f392d3e9f3e64d86d42327bca8d13e))
- *(release)* Add actions write permission and disable cache read-only ([3007f4d](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/3007f4de37484e71aeaa35f6a254892e150684c4))
- *(gradle)* Specify build root directory for accurate caching ([52c6edf](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/52c6edf4869b6682ed47dbf82dcd73420526e1fc))

### ⚙️ Miscellaneous Tasks

- *(release)* Update CHANGELOG.md for v0.1.9 ([fc31366](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/fc31366e800d12bcaf7837c627dcd45fde7c6941))

### 🐛 Bug Fixes

- *(deps)* Move flutter_native_splash to dependencies ([a6a706d](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/a6a706d8f86f60bcf208ba3f261b5b503f5b15bd))
- *(release)* Fix awk regexp syntax in changelog extraction ([35b6e3c](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/35b6e3cdf916006aee05bba73bab91f6fb51e214))
- *(release)* Use prefix match to find version in CHANGELOG.md ([31481fa](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/31481fa0afb43495424d74471907c5e057be3019))
- *(release)* Add consistent header and version info to changelog ([5dfc340](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/5dfc340f353f2b1253822c179c492154f84df68e))
- *(changelog)* Skip all version update commits in git-cliff ([d197b56](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/d197b566333b7bae9392b8fff1bfc73e4890d0d2))

### 📚 Documentation

- *(release)* Add release command documentation and git-cliff config ([fe5acb1](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/fe5acb1e1d3d13118708039a0436c9c323ab65ab))

### 🚀 Features

- *(auth)* Implement auth event system and fix token handling ([d05bff0](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/d05bff07b7650f5ab421e6c6c4fa45c94f4f1c1e))
- *(auth)* Improve error handling and message display in auth flow ([44bc937](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/44bc9379f58ef0c28a03ddbf4130e3a0f0ed2bc5))

### 🚜 Refactor

- *(admin)* Move csrf exception handler to dedicated module ([5a568d2](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/5a568d2a1afe36fec43d46fc02c5ce1617b8f55d))
- *(release)* Improve changelog generation and template ([2bcc3bf](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/2bcc3bf48e92218d5e5729f58f1a34184801bafd))



## [0.1.8](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.1.7...v0.1.8) - 2026-01-17 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.1.8))

### ⚙️ Miscellaneous Tasks

- *(version)* Bump version to 0.1.8+21 ([fd50b90](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/fd50b90460bcb8ae288d68998a0caf2718f3ffe0))

### 🐛 Bug Fixes

- *(main)* Comment out security headers middleware for XSS protection ([d17ece5](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/d17ece512db3c62dc915c0bbab9cfd8a9ecc0a77))

### 🚀 Features

- *(ai)* Add thinking content filter for AI model responses ([43b55ab](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/43b55ab3ab5b5c016e25203cbd4198f2935e53d9))
- *(podcast)* Enhance transcription and summary services with retry and stats ([f4477a1](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/f4477a10d15b1ac7056d5c18b328448a7f0a7c37))
- *(ai)* Filter thinking tags from AI responses ([c1bf4af](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/c1bf4af933b6946e774b4afc9070d0fdf45d6583))
- *(subscription)* Add latest item published timestamp tracking ([edb9395](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/edb9395be1a71cdc87a940f638be48a2ef861724))
- *(auth)* Implement sliding session and security enhancements ([55eba96](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/55eba965d8f9a5a73603823e73ae4acee49c99e5))
- *(podcast)* Enhance summary generation prompt for improved readability and structure ([59b1426](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/59b1426f4e00645f1a8b13a5e5b1e062357b335b))



## [0.1.7](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.1.6...v0.1.7) - 2026-01-17 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.1.7))

### 🐛 Bug Fixes

- *(db)* Add cascade delete to podcast foreign keys ([f6b1626](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/f6b162649b97961498f907049bee7c9ea934fce3))
- *(podcast)* Ensure proper deletion order for subscription data ([a6c06d6](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/a6c06d6c1feeff16025169086bcf20aba43263d9))
- *(admin)* Handle podcast subscription deletion with proper data cleanup ([a79b050](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/a79b050b5b8efa58ddb3b51cf818d7be9ac3bd43))
- *(apikeys)* Improve form validation and field consistency ([5156b03](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/5156b031f3345d6f5fcbf921ad517091b3acf4b6))
- *(dio_client)* Enhance token retry logic and error handling ([12b0b30](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/12b0b30bc636fb2c856145b0edcc00cf0970519e))

### 📚 Documentation

- Update readme with detailed feature descriptions and architecture ([dd7f623](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/dd7f623b9918092ba219fb4714b565b1d50302c4))

### 🚀 Features

- *(subscription)* Enhance duplicate detection with title and URL matching ([1fbe87a](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/1fbe87a5d2dde93a2759d5112919893baa0f4d7b))
- *(subscription)* Add OPML export for RSS subscriptions ([736d5ae](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/736d5aefe1a50f2d9c9969bf05f60bcd2f4a51d2))

### 🚜 Refactor

- *(podcast)* Improve subscription deletion with atomic transaction ([bc35637](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/bc3563785c53f9d3e27880c8692d42c491538fcf))
- *(subscription)* Improve podcast subscription deletion flow ([ddbd504](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/ddbd504d0a1b4972a9a67010ba6feb06978fa438))
- *(network)* Simplify request retry logic using copyWith ([dd42aee](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/dd42aee3a19269b7efc4b29aa4d2c1681be4c3b4))



## [0.1.6](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.1.5...v0.1.6) - 2026-01-13 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.1.6))

### 🐛 Bug Fixes

- *(auth)* Improve JWT token handling in logging middleware ([7143c68](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/7143c681d2160553dcbbaee2734b0962e6e5b7e0))
- Remove redundant guid field from subscription response ([3beac2d](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/3beac2d4501891dc06ba16702f15a10d91b26401))
- *(podcast)* Handle duplicate episodes in database migration ([08f3ee4](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/08f3ee43132bbbdd02fcb46070995050943a327b))
- *(database)* Handle transcription tasks when removing duplicate episodes ([25e3f85](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/25e3f850dd824ea1c3af7a0823fa225d7727d563))
- *(podcast)* Handle async context in celery tasks and improve db session management ([dd288dd](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/dd288ddf9b38e4e77fb524351ae428f8afe5ac8f))

### 🚀 Features

- Implement auto cache cleanup feature in admin settings ([b869828](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/b869828c1a2a6f3fa2f1d53c2f5f889825e47fc8))
- Update storage cleanup service to remove timezone info from updated_at and enhance manual cleanup button layout ([36fcc50](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/36fcc50f84919d2764e85cc0dd684e97e0f36171))
- Ensure last_fetched_at is treated as an aware datetime for accurate scheduling ([3c6caf3](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/3c6caf3a6e91d665bfbcce848d145dc0bc64ac4e))
- *(logging)* Add admin session authentication to logging middleware ([a6f3fb5](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/a6f3fb5e102aa000fac18f2a688eeb75e91ba4b3))
- *(subscriptions)* Add bulk reparse functionality for RSS feeds ([28a70d9](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/28a70d967bc045f405d8e18d1a84b2143f62a9d8))
- *(podcast)* Add scroll-to-top functionality to all tabs ([0d88452](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/0d88452945ae4cd21fdc76e5105fe0b0b8210646))

### 🚜 Refactor

- *(podcast)* Implement model priority-based fallback mechanism ([fbdbbce](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/fbdbbce96dd2804c81cb9a7055c5d61847622c76))
- *(logging_middleware)* Move imports to module level for better readability ([43cd5b8](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/43cd5b8d450bd41ff0f622c6cb77489562195608))
- *(podcast)* Replace guid with item_link as unique identifier ([a259522](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/a2595221eb541185e17be032cc29479325efbd88))
- *(database)* Remove duplicate podcast episodes before setting unique constraint ([45907ed](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/45907ed523fbb439575ad410f5bd323a090e7ae5))



## [0.1.5](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.1.4...v0.1.5) - 2026-01-13 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.1.5))

### 🚀 Features

- Enhance episode description handling by adding HTML stripping and fallback mechanisms ([a5ea9f4](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/a5ea9f468839ba6405e623fe52356a884a93d92d))
- Implement podcast feed URL normalization and enhance subscription state management ([2e97885](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/2e97885cd5ce2218028b5f22751424a6a525e037))
- Improve loading and status display in podcast episode and transcription widgets with responsive design ([ed31338](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/ed31338ccd6faecb334b08a6b03571d07b1792ce))



## [0.1.4](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.1.3...v0.1.4) - 2026-01-12 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.1.4))

### 🚀 Features

- *(admin-panel)* Implement user management interface and two-factor authentication utilities ([ac51d80](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/ac51d80cb8886acd8a0079aaa5f92381eed58ca0))
- Add system settings page for audio processing configuration and update subscriptions management with frequency settings ([f218138](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/f2181382b4485ddae59123cd4aca068a932c4f12))
- Add RSS feed URL testing functionality and error handling in admin panel ([e152933](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/e152933cee52dfabd0ccca383d83bcb124d4e9cd))
- Enhance RSS feed URL testing with improved error handling and add API key testing functionality in admin panel ([79ddee8](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/79ddee852abe08e20036774478c52d576d7b1fa4))
- *(monitoring)* Implement system monitoring service with detailed metrics collection ([a5c430a](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/a5c430a0d4a0865a217c3776a82abf1e21b374a0))
- Add database migration step in entrypoint script and configure RUN_MIGRATIONS in docker-compose ([32b9859](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/32b98595d9f1d8819fadc2828db309c368775a3a))
- Update upgrade function to safely drop indexes and table in admin audit log migration ([52c9bd8](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/52c9bd8fcc27aaa6c3a5f2274436dae62b592402))
- Refactor upgrade function to safely drop indexes and table in admin audit log migration ([07a62e3](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/07a62e396cdfa440d4ae595c47064c7f01aaa82b))
- Enhance system settings table migration to check for existing table and indexes before creation ([206e8b5](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/206e8b5ac855315e6e26013de1869ff5d88de143))
- Remove automatic migration execution from Docker Compose configuration ([35d703f](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/35d703facac571aeea95f5b05c48fef464f1c1fe))
- Add admin panel 2FA toggle configuration ([e0eb119](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/e0eb11971ea8b28242eb93c65004985df34994d3))
- Update User-Agent strings for improved compatibility and testing ([b35367d](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/b35367d1f752167fcfcf5817c8f81136b24b2b42))
- Add search functionality to RSS subscriptions management page and enhance connection timeout settings ([fca7027](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/fca702746a49d8c368d53eeb170305b5d083becf))



## [0.1.3](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.1.2...v0.1.3) - 2026-01-10 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.1.3))

### 🚀 Features

- Add localization for podcast transcript search and results ([30330cb](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/30330cb698c4d194e53df869fb059d0526f1b1de))
- Enhance podcast feed refresh and transcription task handling with independent database engines ([ae253ab](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/ae253ab9a8ad0fd14ec4fb5ba7abb02d3f63d247))
- Increase maximum podcast subscriptions limit to unlimited; enhance bulk import dialog with URL validation and OPML support ([1b019f9](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/1b019f99dee18dd83b836402dde3ba669e878a13))
- Enhance podcast RSS parsing and UI for bulk import ([3f3d9ca](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/3f3d9cad4fb9cb80aa3932035f5a55837b7e3bce))
- Change Celery worker hook from worker_ready to worker_init for API configuration validation ([23eaf60](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/23eaf604b87f40cd408541c8e965fbd96c4a2d59))
- Update Celery worker hook to validate API configuration on worker initialization ([ef3a22f](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/ef3a22f1e8bdb16a42358d414758036ac02cc4e8))
- Increase maximum RSS size to support very large podcast feeds; update localization for transcription test messages ([2d5f4e4](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/2d5f4e43ed47502b7c45e7067263f27111037643))
- Enhance model validation in worker hook to fallback on active models if default is not set ([c5146a9](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/c5146a97e3f699f0e5b43104e289e8b59edea01b))
- Enhance API key retrieval with validation and fallback for podcast models ([a78789c](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/a78789cfd17d7602091fe69cc5750a1cb3c5059d))



## [0.1.2](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.1.1...v0.1.2) - 2026-01-10 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.1.2))

### ⚙️ Miscellaneous Tasks

- *(release)* Bump version to v0.1.2 ([f5b9693](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/f5b9693d319b4823ec57c644065d9c91e8d18046))

### 🚀 Features

- Add shownotes copy functionality and implement sticky tab bar for improved user experience ([857ce50](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/857ce50b7cc757ec530fdc5c9aea761508553297))



## [0.1.1](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.1.0...v0.1.1) - 2026-01-08 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.1.1))

### 🚀 Features

- Implement transcription task deletion and cleanup of Redis locks; enhance error handling and logging ([8e16f5e](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/8e16f5ebf75dba9804d1fd5fc19cf6d62d6797cb))

### 🚜 Refactor

- Update logging levels for improved clarity and reduced noise in podcast services ([a792f0a](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/a792f0ac12343bc352c7555212ce348c6445b182))



## [0.1.0](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.0.9...v0.1.0) - 2026-01-08 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.1.0))

### 🚀 Features

- Rename application to "Stella" and update related metadata; enhance splash screen and localization ([8e6887b](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/8e6887ba69077fcc4c40b62d4cbe4b3a3938b598))



## [0.0.9](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.0.8...v0.0.9) - 2026-01-07 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.0.9))

### 🚀 Features

- *(build)* Update signing configuration for debug builds to use release signing if available ([31341e0](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/31341e0720d0af61cc265505807b6a76bce3324e))
- *(audio)* Refactor PodcastAudioHandler to use just_audio's automatic interruption handling and manage audio focus manually ([5ca7e87](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/5ca7e87f57816c6a5126b37a4c42ec4977002176))
- Refactor audio handling for cross-platform compatibility ([edc67aa](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/edc67aacaafd97ef9ca3594daeec86060d518644))



## [0.0.8](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.0.7...v0.0.8) - 2026-01-07 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.0.8))

### 🚀 Features

- Adjust header padding to align with device's top safe area ([1c98fc1](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/1c98fc1f04f49799afb45db610cbbcd0b982204d))
- *(audio-player)* Completed migration of the audio player to `just_audio` and `audio_service`, fixed Android system media controls, and implemented state synchronization ([2ac2d26](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/2ac2d261505a337440217113b222817cf1900483))
- *(audio-handler)* Optimize PodcastAudioHandler for Android 15 + Vivo OriginOS with manual audio focus management and improved state synchronization ([eb365d0](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/eb365d05fcd43c715731478fbdbd5ddd6a90eea8))
- *(side-floating-player)* Enhance draggable functionality and position snapping for the floating player ([d16ede8](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/d16ede866317f09807c3a54b7fc898e63a4df31f))
- Implement Speed Ruler Control with comprehensive widget tests and documentation ([5fe4e32](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/5fe4e32000199d36d744663dd83cb2d8ddf05732))
- Add localization support for podcast features ([87959f4](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/87959f4980bb04a9ee09f198ae59d831707bf87c))
- *(theme)* Implement theme mode management with localization support ([9d341a1](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/9d341a1333bee2518bff6344e3ae1feccddc7071))
- *(update)* Implement background APK download service with installation support ([b38d06d](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/b38d06df42cf8f760f969f1fbe2ac02d2e7c1c58))



## [0.0.7](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.0.6...v0.0.7) - 2026-01-04 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.0.7))

### 🚀 Features

- Adjust header padding to account for top safe area in podcast episode detail page ([befdf16](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/befdf16f5f85cfffc9327fb4c04855cb22796081))
- Update localization strings for podcast summaries and play buttons ([27956cf](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/27956cf09a806a4522dbe01b0e9e59ddd7442a8b))
- Implement episode description display optimization using AI summaries and HTML cleaning ([5520d6e](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/5520d6e0e0922f1768702085762c4c96d7f68445))
- Remove debug logging for episode database commit confirmation ([c51a0c5](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/c51a0c536e6f3a0811e348d6bde8851f7685e1c6))



## [0.0.6](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.0.5...v0.0.6) - 2026-01-03 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.0.6))

### 🐛 Bug Fixes

- Correct down_revision identifiers in migration scripts ([e633226](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/e6332267ec41aff5024590d5cc23c7a166f3c857))
- Use explicit logger access to avoid scoping issues in error handling ([fcde8b8](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/fcde8b8d970670f8c1045de89944cab502abc074))

### 🚀 Features

- Update API key retrieval to read uniformly from the database and enhance User-Agent header for CDN bypass ([0580a63](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/0580a63abaf8ff35803970cec58c75aaaf55cbcf))
- Add logging for HTTP request URL and headers in AudioDownloader ([994e2f3](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/994e2f308f3aa9bf500921d5147beab6c2f0d8d9))
- Enhance logging in AudioDownloader and simplify PodcastSearchResultCard layout ([eeaf2d1](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/eeaf2d1ef61f839f3bdc6183a6effed57227cf5d))
- Adjust country selector overlay positioning and width based on search bar dimensions ([994e6ed](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/994e6ed7f5e03e6a4decdd7e6406a5cc966004b7))
- Add product verification report for podcast audio download fallback implementation ([f148391](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/f1483913c2b0bf9f3051ffae0ef026247e9fb864))
- Remove ai_model_configs table migration script ([07f9fec](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/07f9fec39f668c5919a80d350989af4c63253f32))
- Enhance browser fallback logic by checking Playwright availability ([57ad7ee](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/57ad7eea2b6aa62340866c464b565733f08cf01a))
- Enhance audio download process by implementing fetch API in browser context ([bb67418](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/bb6741825321e4379e98aa89b58daa0428d6cf56))
- Update Dockerfile for Playwright browser path and install dependencies; refactor audio fetch script to use IIFE ([f3704ea](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/f3704ea3504d45052b194c3e13736591ef8a7c6c))
- Refactor BrowserAudioDownloader to use context.request.get() for HTTP requests ([6443582](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/644358234199d074e200679f4ddcc20173bd922d))
- Enhance error logging for BrowserAudioDownloader with detailed 403 response information ([ec9ba75](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/ec9ba7522d0919a9a131c74db77572e4a1f180b6))
- Remove browser fallback mechanism from AudioDownloader; switch to direct aiohttp downloads ([051b8fa](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/051b8fab83a3e4d378e5559fc03bb77de206e0a7))
- Enhance AudioDownloader to handle lizhi.fm CDN URLs and add Referer header ([dc30e09](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/dc30e09e941dc1a63e76c4d96845ba2eb6b5823c))
- Add item link functionality to podcast episodes, including backend support and frontend integration ([4f672ee](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/4f672ee83c7cf2d6640aa126cfe90b8132a82d44))
- Add item_link column and index to podcast_episodes table with existence checks ([cdcdf2c](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/cdcdf2c94d397d61840cd4bd30fbb60eb0abf990))
- Add download_method column to transcription_tasks with default and constraints ([d540bd1](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/d540bd12b0cc62cf0c38bf1079ad9474a1d1fad9))
- Remove download_method column from transcription_tasks and associated constraints ([27c453e](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/27c453ec62e9842c1eac993e2a15d02b67889251))
- Add reparse functionality for podcast episodes with localization support ([60d9add](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/60d9adde48cb548e3e3d9727fb9f3eb043ea57ee))
- Enhance logging for item link processing in podcast RSS parser ([2abdb0b](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/2abdb0b62978c6349c600d0e32082566f471b2ca))
- Add logging setup to PodcastRepository for improved debugging ([7b7f49e](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/7b7f49ebe8b3d59c8757f64b23dff89d4787ed3d))
- Add item link to podcast episode details for improved accessibility ([25aa140](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/25aa140b996cd5c3e7ad8e4c1f58ba2438674204))
- Implement floating podcast player with collapsed and expanded states ([9b348b8](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/9b348b8ee29fbe66f4ab1055c303a586fbc8eafb))
- Enhance audio player functionality with close button and clear current episode option ([2373b2d](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/2373b2d50f54a2a201a4e5be075d9f555374c7af))
- Improve layout responsiveness of expanded podcast player content ([2f76395](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/2f76395ed6837ea79d8e4674f7b23e50fb95e1cf))



## [0.0.5](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.0.4...v0.0.5) - 2026-01-02 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.0.5))

### 🚀 Features

- *(logging)* Enhance batch logging for PII detection; increase log frequency and add initial log info ([d826747](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/d826747ffd92f792875158fba2fb58fa431e7c35))
- Update .gitignore to exclude docker storage; modify Dockerfile for improved package source configuration; enhance summary_manager and transcription service with better logging and progress handling ([0ee33d5](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/0ee33d53147349889e4ca1d71f755779e6ba3d86))
- Add podcast search task tracking and subscription status indicator specifications ([624ffba](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/624ffba641807170756944a25a722f620f85e5ae))
- Enhance podcast subscription status indicator with Material 3 icons and improved UI ([064f8d6](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/064f8d61a9d95a6513c5a554addf9d5869c19208))
- *(localization)* Add unknown author label and country names for podcasts ([d46c58b](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/d46c58bb56b1c312104d594b3a16a7cfec272c83))
- Refactor DioClient to initialize baseUrl synchronously and enhance server URL loading in main ([1979eb0](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/1979eb04f7f1b758fadf0f1760bde7c58ad79689))
- Add missing transcript_content field to PodcastTranscriptionResponse and update core providers for baseUrl invalidation ([330733b](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/330733be810628f5dfbf82025704b3b98b04bdd7))
- Enhance country selection with a dropdown menu and integrate popular regions in PodcastCountry enum ([e657f8d](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/e657f8d14007e09c1a8e351cb931d02f0aa5f491))



## [0.0.4](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.0.3...v0.0.4) - 2025-12-31 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.0.4))

### ⚙️ Miscellaneous Tasks

- Bump version to 0.0.4+1 in pubspec.yaml ([169df32](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/169df329d2184e7cdc0997296fec783bbd5a6d23))

### 🚀 Features

- Enhance release date formatting in changelog; add timezone support and improve UI for update dialog actions ([0e68254](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/0e682544e10487c7cc23441875d65d38cb7cf3ce))
- *(localization)* Update Chinese localization strings and improve usage across the app ([426049c](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/426049cc45180caa82351410ab1af76fa31b77d8))



## [0.0.3](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.0.2...v0.0.3) - 2025-12-30 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.0.3))

### 🚀 Features

- Display app version on profile page and update version to 0.0.2+4 ([39d9d64](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/39d9d64aa079a9ef3425fa9b9d9694eedd4e7cfa))
- Implement robust RSS/Atom feed parser with enhanced error handling and data normalization ([fb1fbe6](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/fb1fbe68f24df6a67fdb482b2108eb036a12456b))
- Enhance server address settings functionality ([ec53e2f](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/ec53e2fb17633a026f41f2ce71b8c2612d5cff61))
- Update Java and Kotlin compatibility to version 21, enhance UI responsiveness and button styles in settings and server config dialogs ([bd5d823](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/bd5d8237d837082a494ea48dcbf59199b31bd96f))
- Enhance episode data structure with image URL and transcript content fallback ([670cf2d](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/670cf2dd99426b8f88d8d0ac460657eb0d100757))
- Enhance error handling and logging in DioClient and podcast providers; improve episode loading logic ([c2d1c67](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/c2d1c67709e7ba34c2624672c94d02df4c890a7f))
- Implement batch logging for PII detection and progress updates; reduce log frequency in transcription service ([bdab714](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/bdab714b64af56dbc55ab836a5795f5099cfbe77))



## [0.0.2](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.0.1...v0.0.2) - 2025-12-30 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.0.2))

### 🐛 Bug Fixes

- *(android)* Resolve Gradle build errors - add Properties import and migrate to new Kotlin DSL ([abc3f6a](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/abc3f6abba0b742929ca98933a4b79cc055d5e45))
- *(ci)* Add flutter clean step to Windows build for fresh compilation ([5575f71](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/5575f710a6d196dc87b75dd3f8116c32cb026fb9))
- *(i18n)* Add missing update_* localization keys to .arb templates ([915facd](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/915facdfb4b923490ab00719bb5e6e604b44e238))
- Update version number to 0.0.2+2 and add ProGuard rules for Woodstox and StAX ([41d9375](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/41d9375d9de34c2b2f478cc0c064055fc6d0812b))

### 🚀 Features

- Add app update notification feature with task tracking documentation ([adc7604](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/adc76041aad33f6a5aa85876f37a710f7a78f115))
- Update release workflow to use new keystore secrets and add documentation for generating release.keystore ([bd4330c](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/bd4330c60cdf91159786d620207f4e6e1f740bf6))
- Add XML StAX API dependency and ProGuard rules for XML parsing ([00ffedb](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/00ffedb128b173c880ff8fbcda4bb61cad904c82))
- Update app version to 0.0.2+3, enhance version retrieval, and improve settings UI with update check functionality ([ec1ded8](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/ec1ded804c7a83cc075a2884bf82fdade54ec824))



## [0.0.1](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.0.1-rc...v0.0.1) - 2025-12-29 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.0.1))

### 🐛 Bug Fixes

- Revert version number to 0.0.1+1 in pubspec.yaml ([97e3e8b](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/97e3e8b49ddee19cd40e3c29f14a07f5ef801eb4))
- *(ios)* Use debug mode for iOS simulator build ([5d4dce3](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/5d4dce34fc0f7d0db9c59ac3b9b211e36c781857))
- *(ios)* Build iOS device with --no-codesign instead of simulator ([254ce09](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/254ce095313ce9e5333a7117cbad01037c55c141))
- *(ios)* Fix zip command path error in IPA packaging ([bd87ec2](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/bd87ec237336a992a9dcc4dbf5643f6efb8078dd))
- *(theme)* Adjust font sizes and spacing for improved readability across podcast pages ([0f0405f](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/0f0405f21ab10e16a886c04eca46dd3d543af10f))

### 🚀 Features

- Implement floating player control for podcast playback ([d55c91d](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/d55c91d3899af2ac59623dfa4b536d05605f0d75))
- Add iOS Simulator build job to release workflow ([01a3c51](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/01a3c51bd7d4192528bbd6b795183b49e8111933))
- Add podcast subscription bulk delete feature specification ([73a487a](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/73a487a04926a6082ee7586b3784805473ca94fc))
- *(podcast)* Implement lazy loading for podcast subscriptions and optimize button text ([b6a198e](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/b6a198e1cc93b11f2768bfeda3b4587820d58ff8))
- *(docs)* Update CLAUDE.md with current feature status and recent major updates ([56bf28d](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/56bf28db9a9a5877953c34b7a5e4798a7f62e219))



## [0.0.1-rc](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.0.1-beta...v0.0.1-rc) - 2025-12-28 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.0.1-rc))

### 🐛 Bug Fixes

- *(docker)* Update Docker Compose to include env_file for services ([f7452e0](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/f7452e03e7414feca6b4327a5fdb6c1af3f70f5d))
- *(android)* Allow cleartext HTTP traffic for remote server connections ([d3ac83c](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/d3ac83c5e1292d02062e5ac24c5fe4b52fc09679))
- *(android)* Use debug signing for release builds to support overwrite installation ([3806ae8](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/3806ae8c6d0c9fd83b908b15fd4dec22c6ab9a38))
- *(android)* Add comprehensive permissions to AndroidManifest ([50d6fa7](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/50d6fa77d8f55c11ad7154b01560eaf9dcad7f4e))

### 🚀 Features

- *(docker)* Update Docker configuration and environment files for improved setup ([c7144b6](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/c7144b696a9380d577b9bd8e50cbb338db321402))
- *(docker)* Update environment configuration and Docker Compose for improved local development setup ([809e9b6](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/809e9b650a624b1a8a763ec2771f0a5063b4454c))
- *(redis)* Update Redis command to conditionally require password based on environment variable ([490242d](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/490242d61d8af896c3d10dd798d768be568b29eb))
- *(auth)* Add remember me functionality for login and registration ([ac9425d](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/ac9425daa4dcbb28209a1858f6b9341a69ea7465))
- *(docker)* Refactor environment configurations for local and production setups ([b747240](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/b747240a205ca712a9e2f22e7f4e8bb08ac29100))
- *(docker)* Update environment configuration for local and production setups ([f5bb302](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/f5bb30223f43312b716f4443bb439d723a580c9b))
- *(docker)* Create multiple directories with proper permissions in Dockerfile ([41420e0](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/41420e046e48b23378729053a043526ced394fcf))
- *(api)* Add root endpoint for welcome message and update health check proxy path ([cac92a7](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/cac92a7b8988a6a19633a982a25cd84373f7f5d1))
- *(nginx)* Add HTTPS configuration and auto-configuration script for Nginx ([e81e2e6](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/e81e2e65c527333c636ca849e909f666aa433057))
- *(docker)* Remove HTTPS configuration files and update Nginx settings for domain configuration ([8c67697](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/8c676970c583befb6646f90859a9059e3cff3c81))
- *(nginx)* Add auto-configuration script and HTTPS template for Nginx ([dadae8b](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/dadae8b204374a66b5ebe737b2d59fb1b757ebd4))
- *(nginx)* Update Nginx configuration for auto-configuration script and entrypoint handling ([1aaf61b](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/1aaf61ba1fee4d6a69a9da5a51e88287cd7b1c2f))
- Implement dynamic server configuration and connection testing ([3b736f8](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/3b736f8eb3f027f76b5724fc1b3099f93f104e40))
- *(docker)* Add entrypoint script for permission management and update dependencies ([4234a73](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/4234a73ef36a727229bdcac7d9fa4c40e60d8412))
- *(docker)* Enhance entrypoint script to use setpriv for user execution ([0c4973b](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/0c4973b7a453d25d791af0b8230b92124b44439c))
- *(nginx)* Remove default Nginx configuration for development environment ([ba95bda](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/ba95bda7f21973dfe2372bcb251c378fbbbd5367))
- *(docker)* Clean up default Nginx configuration files to avoid conflicts ([bdf24fb](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/bdf24fb89e46e34d9c6aa43fe269cc0f66cfbce6))
- Update error logging to include response data and upgrade dependencies ([83c72e1](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/83c72e1ebdcaa09ffecab5a4c3bd408157c7c21d))
- Update provider constructors to be constant and adjust build methods ([4edd902](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/4edd902329b0ae44c941aa9007640a73382243c1))



## [0.0.1-beta](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/v0.0.1-alpha...v0.0.1-beta) - 2025-12-27 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.0.1-beta))

### 🐛 Bug Fixes

- *(ui)* Enhance UI components for better accessibility and usability ([0526127](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/0526127700e1ddad09cd558c734e4410294a0328))

### 🚀 Features

- *(docker)* Add comprehensive Docker setup for production and development environments ([1451d41](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/1451d41032f87dd6b0cd075eee4617318e4f6724))
- Add Mindriver theme configuration with light and dark variants ([7c46457](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/7c46457e78dd392dc315c1e2092074b9ec07d092))



## [0.0.1-alpha](https://github.com/BingqiangZhou/Personal-AI-Assistant/compare/...v0.0.1-alpha) - 2025-12-27 ([📥](https://github.com/BingqiangZhou/Personal-AI-Assistant/releases/tag/v0.0.1-alpha))

### Refactor

- Remove old main files and implement new podcast episode cards ([2187ac0](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/2187ac08b9465c05675d595a042e7f5a34d5da50))

### ⚡ Performance

- *(ci)* Optimize Android build speed ([6d31d05](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/6d31d059585b0a9e0334db4c2ccf50f47308b212))
- *(ci)* Improve Android Gradle caching strategy ([668051e](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/668051e0e2649e10f3b230fa2f70089453ad6a4f))
- *(ci)* Optimize Windows build workflow ([53a8572](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/53a8572ac822a091d5203473029cadb927406ccd))
- *(ci)* Optimize Linux build workflow ([3f996f1](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/3f996f102e01f6404a5609e90e7249229877138e))
- *(ci)* Optimize macOS build workflow ([d885c68](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/d885c6875673f69cac41a8d7e24260b28bb1d39c))
- *(ci)* Add pub-cache caching to Android and Windows ([1b32e9d](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/1b32e9d769368042d4b0487e84013230cf759f35))
- *(ci)* Skip Finder beautification in macOS DMG creation ([9f31a22](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/9f31a22f04972e93be927b84092482bd8265fcef))
- *(ci)* Optimize cache keys and use system tools ([aa1e33a](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/aa1e33a2f9ed7fa60cc6a4384bcd207d63b6b04b))

### 🐛 Bug Fixes

- *(release)* Simplify changelog generation and add verification step ([357ad12](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/357ad127f651149edceefb14d94bcf42151da995))
- *(release)* Correct working directories for desktop builds ([ea29b37](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/ea29b3743644b1b7c4129b8db91fa88643312170))
- *(ci)* Update Flutter to use latest stable version ([c175eda](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/c175edaf1a5aa00b3164c50e40c28d623db5515d))
- *(deps)* Resolve dependency conflicts and update packages ([2b428ec](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/2b428ecd49c6d214225fcc37b10b12dbe3c1349c))
- *(ci)* Add gstreamer dependencies for Linux build ([22b6df8](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/22b6df8d6e560b50a7bb19e039012621d03a3112))
- *(ci)* Use bash shell for Windows build commands ([dc9cc9f](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/dc9cc9f78b2ab81537a92486a62640dbbd8f256b))
- *(ci)* Build Android APK for arm64 only ([5d48d02](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/5d48d024d4eed1849d6e18ddcb153dc169d55718))
- Add placeholder files to empty asset directories ([85eae96](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/85eae96042745d5e287cdbdec66278179b9edfff))
- Remove empty assets declarations from pubspec.yaml ([449a957](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/449a957cbc281ec3e93e89b686a25fe79a3fbe14))
- *(ci)* Add libsecret-1-dev for Linux secure storage ([5c76594](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/5c76594d39929d426c86d5fe71d1e4b13fd0a483))
- *(ci)* Add build cache cleanup for Windows build ([cddca5d](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/cddca5d0daa32465311a16fea9e33dbee6e94c0a))
- *(ci)* Fix Linux tar archive creation command ([730b658](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/730b6584b5b2251a40770c798ae37f76cd407a25))
- *(ci)* Use bash and zip for Windows archive creation ([7eb9e8e](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/7eb9e8e084124097ea89bfe570e143e05718f0d4))
- *(deps)* Upgrade audio_service to fix build warnings ([afc26be](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/afc26bea75b5e646a54a062cbbfb69ddcf38a220))
- *(ci)* Correct Windows build output path ([8ef8483](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/8ef8483acd404f7d6bce9be2b470902ea1dcba26))
- *(ci)* Extract numeric build number from version ([6c7fb66](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/6c7fb66368d67bbff201a0b43b1d428b7ea7b4eb))
- *(ci)* Use PowerShell Compress-Archive for Windows ([30cc884](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/30cc884ba96098d4b184617fe9af341d2480d3fc))
- *(backend)* Correct User model attribute in podcast task ([9228f6e](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/9228f6e608b7fd8bd234dab3417702153e138743))
- *(ci)* Add bash shell for Windows build step ([9213b57](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/9213b57daa7c6782d174cee3ac4640761d4d4a87))
- *(ci)* Correct macOS archive path ([9c9fe68](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/9c9fe68025e7749e5aff4922799c33707bb64fc6))
- *(ci)* Correct release condition and unify cache keys ([b99ae2b](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/b99ae2b4a518f37529a9b854692398de4f446fe5))
- *(ci)* Correct macOS DMG creation path handling ([f3b83a4](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/f3b83a4da18d119f1505b93d8ceb2afd60808af5))
- *(deps)* Update flutter_markdown to flutter_markdown_plus and adjust related imports ([0ae64ee](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/0ae64ee0dff3f5e53d6cb40b1530e972aea49ec9))
- *(ui)* Add SafeArea to ResponsiveContainer for mobile to prevent status bar overlap ([7ed316b](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/7ed316b20ce0af5cc81534d246ebbbd51d2c0b5e))

### 📚 Documentation

- Add CHANGELOG.md for v0.0.1 and update README with bilingual features ([581c5d6](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/581c5d6b9368c1b6ee629b4dfeb706fc3deb9bb8))

### 🚀 Features

- Implement comprehensive multi-agent collaboration system with workflows for feature development, bug fixing, and architecture review ([3224cb8](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/3224cb897301d571a143ea7749edfc8863b3d95f))
- Enhance database and security modules with production-ready optimizations and health checks ([aeae44a](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/aeae44a4ca5e0c885815a8d9c2a7a39caf677fb1))
- *(docker)* Add comprehensive deployment documentation and scripts for podcast feature ([a26422a](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/a26422a34932d7bc4a125a5d65ec18d39903e29a))
- Add metadata headers to agent documentation files and create devtools options configuration ([e3eaacd](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/e3eaacd68242bdc79630a97fb7dabd4b996c92c5))
- Add generated plugin registrant files for Linux and Windows platforms ([be828af](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/be828af4c388c0b9c7460ab023185c7671ce8e67))
- Update Flutter dependencies and configurations for Windows desktop support ([48c70ed](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/48c70edcf4d2c8eb74ec38d0b4025ebee422d54a))
- Update Flutter dependencies and improve plugin registrations for macOS ([1fb9df4](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/1fb9df4e00fb5b90665c037d64bee1285a25b16a))
- Enhance Flutter widget testing guidelines and enforce mandatory usage for page functionality ([1efc13e](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/1efc13efc07ba8d9105e3cb5717519e1c32dd022))
- Add UI structure validation tests and functional test reports for podcast feature ([c81838e](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/c81838ef346441944b64454528c5409f8a9f428d))
- Add comprehensive authentication test report and fix login API field mismatch ([da579ba](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/da579ba910516de4d4729b14abd479ed071d51e4))
- Enhance podcast player UI and functionality ([e070c6a](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/e070c6a8360c34b3ec96bf72e39964aabbdcfc81))
- Implement podcast platform detection and validation ([61f9c47](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/61f9c47cd40e36b3c496f3449bc72fe94e329968))
- Add comprehensive workflow documentation and templates for requirement-driven development ([a2df0cc](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/a2df0cc26f863676e2ce7a9bfa6c99696db59859))
- Implement podcast feed feature with lazy loading and error handling ([b62362c](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/b62362c7430704b1b36dee425ee5ec686ddd7c21))
- Enhance product-driven development workflow with mandatory actions and validation checks ([2e0b95c](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/2e0b95c9e6cb6c49e7a4f27447d2c6c2c077d1f4))
- Add default values for boolean fields in API response models and update podcast feed provider references ([15ab3bc](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/15ab3bcd7188e5fb4dab1e475174135d2a0eda4e))
- Implement podcast feed page optimization and UI translation ([424ea77](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/424ea77c8515cb436a46cf8833fa8227992494d5))
- Complete Material 3 UI refactoring (Phases 1 & 2), refactor all 17 pages, and implement responsive layouts ([4315768](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/43157681a588e313de05f2a0d7d80ad143fcf011))
- Implement podcast audio player enhancements ([71419d6](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/71419d6cc787c7a0dff56f6c6cb525039c88854d))
- Add image URL field to podcast episodes and update related models and services ([993de86](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/993de8604833c8b3a91b4dbb12df21021bc3abc9))
- Add adaptive menu components and tests ([dd6d254](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/dd6d254d1e34dfcef563199ee358809c6132bddd))
- Update product-driven development workflow and enhance MCP tools guidance ([4e5a981](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/4e5a98153516eb734dae2d33a6598f4b0a36fe5a))
- Implement podcast transcription feature with shownotes display ([e449e96](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/e449e960a62f9aafac3d6a30145bb31c520dfa5f))
- Add model creation, editing, listing, and testing dialogs for AI models ([e7eb07e](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/e7eb07e22b284d3b5830ee1ba5dd24dbdccbff43))
- Implement adaptive navigation and loading page for Material Design 3 ([a1215e6](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/a1215e6ac27da33070ea2c9e2732be93fd774553))
- Implement Knowledge Management API and Models ([7bde4c3](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/7bde4c376d2af77a7188155a72c337c094c48051))
- Implement Assistant, Subscription, and Multimedia domains ([5e5ae3b](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/5e5ae3b1b6168dcefb812491317f67f519ccf834))
- *(transcription)* Add current_step field to transcription_tasks and enhance transcription state management ([9fd53cd](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/9fd53cdcd317d5569a4a99dbe34655ef47afcdd5))
- *(security)* Implement RSA key management and encryption for API keys ([f9ac2e2](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/f9ac2e2387fabee9f983944b30c2d4ff493c7eed))
- Implement AI summary feature for podcast episodes ([97482d8](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/97482d8b4248b319e46a7231b1c35519e3972a46))
- *(api)* Add API key validation endpoint and enhance model retrieval with optional decryption ([febe0c2](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/febe0c28cd864038202fce31e3b30a4afe81474e))
- Enhance AI Summary functionality and improve UI components ([cdc2810](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/cdc2810558bb52d3d48f5616555aef0e3faa0196))
- Add podcast conversations table and implement conversation service ([263e748](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/263e748d183358416f6c22f1b002de70771c39ec))
- Integrate flutter_markdown for enhanced summary display and update UI text to English ([846696a](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/846696af1637975dc6d75394664d7932bcd02f42))
- Implement global schedule provider and schedule configuration provider ([7bca8a3](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/7bca8a3f4836e3646ba4258037bfe0046ebd3c26))
- Implement bulk podcast subscription feature ([82bcf23](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/82bcf23271df08fb167a6c50792d89dead698bcf))
- Add Celery Beat service and implement subscription checking functionality ([7d4bf33](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/7d4bf338948cf54a569be99b3935cce7f673af8d))
- Enhance database connection handling and add test script for SimpleModel ([c4e250c](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/c4e250c1503ece5e576cdc22ba5789593c537d6c))
- Refactor subscription update logic and remove obsolete files ([a1a0d08](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/a1a0d08a641c4e6af814b8231ee0a2b87a2f5b9d))
- Revise README to enhance clarity on features and technical architecture ([343b80d](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/343b80ddab473639c336a98ee337c9a5f50f4db3))
- *(logging)* Implement unified logging configuration and middleware ([c76b054](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/c76b054d7dfa7af350afb059bf068f17dfa4f5ef))
- Enhance bilingual support across agents and workflows, including language matching and documentation requirements ([ee5da93](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/ee5da93c289ac84d819c9d30edd9cdeaf94accbc))
- *(localization)* Add Chinese translations for backend API settings and UI elements ([ac32db9](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/ac32db912797ac5f97b734e744c46a16a51951b8))
- Add CI and release workflows for multi-platform builds and automated testing ([406a8fc](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/406a8fcb60f17f0935d305d06b53720bebeb0f18))
- Add GitHub Actions quick reference documentation ([d71c3ae](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/d71c3ae031c2e28fd0def67a4bb3129b885abce7))
- *(ci)* Reintroduce CI workflow for backend and frontend with comprehensive testing and coverage ([f43eee8](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/f43eee863b28cdad72fa0c220341dd8604aac9ad))
- Add screen retriever and window manager plugins for all platforms ([f13f6a1](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/f13f6a14d9b1c71fcf3dec300f1b39763f4e60ef))
- *(ci)* Add flutter config for Windows desktop ([b8d0417](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/b8d0417fe20c1d8036ff6a8f4b3f1cfc02ad76e5))
- *(ci)* Change macOS packaging from ZIP to DMG ([7ef31c9](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/7ef31c986ba713c3e4be3acb16b9b7ac9b6a4d4b))

### 🚜 Refactor

- *(ci)* Optimize release workflow based on best practices ([f29e484](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/f29e4841753b48432f26dfaf2c15c3805646f77d))
- *(ci)* Optimize Android build artifacts ([43d7429](https://github.com/BingqiangZhou/Personal-AI-Assistant/commit/43d7429c60b81250aeeef50df402cb54d2e0691b))

---
*This changelog was automatically generated by [git-cliff](https://github.com/orhun/git-cliff)*
