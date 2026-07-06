# RollnWrite — Android

Modules: `:engine` (pure-JVM game engines, no Android deps, fast unit tests)
and `:app` (Compose UI, depends on `:engine`).

Build:

```
cd android && ./gradlew build
```

`:engine` tests validate the shared `spec/fixtures/**/*.json` golden fixtures
identically to the iOS engine tests, proving both platforms implement the
same Qwixx rules. See root `CLAUDE.md` for architecture and conventions.
