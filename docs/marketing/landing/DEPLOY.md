# Деплой лендинга в AWS Amplify Hosting

Статический одностраничник без сборки: `index.html` + `og-image.png` (+ `amplify.yml`).
`og-image.html` — исходник превью-картинки, на хостинг не нужен.

## Вариант A — без git (drag & drop), самый быстрый
1. `cd docs/marketing/landing && zip site.zip index.html og-image.png`
2. AWS Console → **Amplify** → *Deploy without Git* (Host web app → Manual deploy).
3. Перетащить `site.zip` → Deploy. Получите адрес `https://<app>.amplifyapp.com`.

## Вариант B — из репозитория (авто-деплой на пуш)
1. Amplify → Host web app → GitHub → выбрать репозиторий и ветку.
2. В настройках monorepo указать **App root: `docs/marketing/landing`** —
   `amplify.yml` подхватится оттуда автоматически.

## Домен
Amplify → Domain management → добавить `gistit.10xt.tech` (CNAME в DNS зоны 10xt.tech).
Если фактический адрес будет другим — поменяйте в `index.html` четыре абсолютных URL
(`canonical`, `og:url`, `og:image`, `twitter:image`), иначе соцсети не покажут превью.

## Проверка превью после деплоя
- https://www.opengraph.xyz — вставить URL;
- Telegram: отправить ссылку боту `@WebpageBot` (сбрасывает кэш превью);
- Facebook Sharing Debugger → Scrape Again.
