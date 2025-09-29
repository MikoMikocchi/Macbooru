# Macbooru — нативный Danbooru-клиент для macOS

Нативное приложение на Swift/SwiftUI для просмотра Danbooru на macOS с быстрым поиском, удобной сеткой, детальной карточкой поста, оффлайн‑кешем (базовый), управлением контентом и фокусом на производительности/UX.

> Минимальная поддерживаемая платформа: macOS 15/26 (Sequoia/Tahoe)

## Возможности

- Лента постов (recent / popular, по умолчанию recent; popular легко добавить `order:rank`)
- Поиск по тегам с поддержкой `rating:*` (G/S/Q/E)
- Адаптивная сетка с плавной прокруткой и постраничной подгрузкой
- Детальная карточка поста: панорамирование/масштабирование (трекпад/мышь), копирование тегов и ссылок, скачивание изображения
- Настройка «Blur NSFW (Q/E)» — безопасный просмотр в публичных местах
- Прогрессивная загрузка превью → large → original с заменой на более детальную версию
- Обработка ошибок загрузки с ненавязчивым тостом и Retry

## Архитектура

Проект следует принципам Clean Architecture (слои сверху вниз):

- Presentation (SwiftUI): экраны, навигация, стейт (`SearchState`)
- Domain: (зарезервировано) — юзкейсы/интеракторы; логика постепенно выносится из UI
- Data: `DanbooruClient` (HTTP, async/await), репозитории (`PostsRepository`)

Технологии:

- Swift 5.10+, SwiftUI, Concurrency (async/await)
- Сеть: `URLSession`, JSONDecoder (устойчивый ISO8601 разбор с/без миллисекунд)
- Изображения: собственный лёгкий загрузчик + `NSCache` + `URLCache` (планируется Nuke/DataCache)
- Логирование: стандартные принты (планируется `os.Logger` + `os_signpost`)
- DI: лёгкий через `Environment` (в процессе)
- Тесты: XCTest (юнит/базовые UI)

Папки:

- `Macbooru/Models` — модели (`Post`, `SearchState`)
- `Macbooru/Networking` — клиент, лоадер изображений, URL-хелперы
- `Macbooru/Repositories` — интерфейсы и реализации репозиториев
- `Macbooru/Views` — SwiftUI‑экраны (Sidebar, Grid, Post detail)
- `MacbooruTests`, `MacbooruUITests` — тесты
- `docs/` — архитектура/roadmap/API coverage (локально игнорируется в .gitignore)

## Сборка и запуск

Вариант 1 — Xcode (рекомендуется):

1. Откройте `Macbooru.xcodeproj`
2. Выберите схему `Macbooru`
3. Product → Run (⌘R)

Вариант 2 — командная строка (если настроен `xcode-select` на Xcode):

```bash
# Список схем
xcodebuild -list -project Macbooru.xcodeproj

# Сборка
xcodebuild -scheme Macbooru -project Macbooru.xcodeproj -destination 'platform=macOS' build

# Тесты
xcodebuild -scheme Macbooru -project Macbooru.xcodeproj -destination 'platform=macOS' test
```

## Тесты

- Юнит‑тесты: `MacbooruTests` (пример: декодирование `Post`, сборка URL)
- UI‑тесты: `MacbooruUITests` (запуск приложения, проверка базовых сценариев)

Запуск в Xcode: Product → Test (⌘U)

## Конфигурация и секреты

- Авторизация Danbooru (username + API key) поддерживается на уровне клиента (`DanbooruConfig`),
  но UI логина и хранение в Keychain пока не реализованы.
- До добавления UI можно передать креды программно при инициализации клиента.
- Соблюдайте ToS Danbooru и учитывайте rate limits.

## Безопасность контента (NSFW)

- В настройках сайдбара есть переключатель «Blur NSFW (Q/E)» — включён по умолчанию.
- Для `rating: q` и `rating: e` применяется повышенный блюр и затемнение.
- Иконка `eye.slash` поверх подчёркивает скрытый контент.

## Известные ограничения / TODO

- Нет экрана логина и хранения API ключа в Keychain
- Нет избранного/голосований/комментариев/пулов/тегов
- Нет Nuke/DataCache: текущий лоадер работает, но без дискового LRU политики для JSON
- Нет локализаций ru/en (M6), пока строки зашиты в коде
- Нет CI (GitHub Actions / Xcode Cloud) и SwiftLint/SwiftFormat (в планах)

## Вклад в проект

Мы рады PR’ам:

- Разбейте изменения на небольшие коммиты
- Пишите тесты для публичного поведения
- Соблюдайте стиль Swift 5.10, по возможности включайте SwiftLint (скоро добавим конфиг)

Советы по разработке:

- Держите зависимости «сверху вниз»: UI → Domain → Data
- Выносите логику в use cases/репозитории, UI — максимально декларативный
- Для сетевых изменений добавляйте юнит‑тесты формирования запросов и декодеров

## Лицензия

TBD

## Благодарности

- Danbooru за открытый JSON API
- Сообществу SwiftUI за многочисленные примеры и библиотеки (Nuke и др.)
