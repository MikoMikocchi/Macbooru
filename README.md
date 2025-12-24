<div align="center">

# Macbooru

![CI](https://github.com/MikoMikocchi/Macbooru/actions/workflows/ci.yml/badge.svg)
![Swift](https://img.shields.io/badge/Swift-6.2-orange?logo=swift)
![Platform](https://img.shields.io/badge/platform-macOS-black?logo=apple)

<img src="Macbooru/Assets.xcassets/MacbooruAppIcon-iOS-Default-1024x1024@1x.png" alt="Macbooru icon" width="140" height="140" style="border-radius:20px" />

Нативный клиент Danbooru для macOS

<sub>Требует macOS 15+ (Sequoia)</sub>

</div>

## Скриншоты

<div align="center">

<img src="docs/images/Macbooru-1.png" alt="Главный экран" width="900" />
<img src="docs/images/Macbooru-2.png" alt="Карточка поста" width="900" />

</div>

## Возможности

- Поиск по тегам и рейтингам (`rating:E/Q/S/G`)
- История и избранные запросы
- Адаптивная сетка с постраничной навигацией
- Просмотр и управление изображениями (панорама, масштабирование, сохранение)
- Комментарии к постам
- Синхронизация с API Danbooru через ключ доступа

## Запуск

Откройте `Macbooru.xcodeproj` в Xcode и нажмите Product → Run (⌘R)

## Конфигурация и секреты

- Авторизация Danbooru (username + API key) поддерживается: откройте `Macbooru` → `Settings…` (⌘,) и заполните раздел _Danbooru Credentials_. Данные сохраняются в системном Keychain и автоматически проверяются (отображается текущий пользователь или ошибка).
- Очистка полей и сохранение удаляет значения из Keychain.
- Соблюдайте ToS Danbooru и учитывайте rate limits.

## Безопасность контента (NSFW)

- В настройках сайдбара есть переключатель «Blur NSFW (Q/E)» — включён по умолчанию.
- Для `rating: q` и `rating: e` применяется повышенный блюр и затемнение.
- Иконка `eye.slash` поверх подчёркивает скрытый контент.

## Вклад в проект

Мы рады PR’ам:

- Разбивайте изменения на небольшие PR
- Пишите тесты для публичного поведения
- Соблюдайте стиль Swift 6.x; SwiftLint/SwiftFormat — опционально

Советы по разработке:

- Держите зависимости «сверху вниз»: UI → Domain → Data
- Выносите логику в use cases/репозитории, UI — максимально декларативный
- Для сетевых изменений добавляйте юнит‑тесты формирования запросов и декодеров

## Лицензия

TBD

## Благодарности

- Danbooru за открытый JSON API
- Сообществу SwiftUI за многочисленные примеры и библиотеки (Nuke и др.)
