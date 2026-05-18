# Analytics Project: Unit Economics & Product Metrics

## Business Context

Цей проєкт імітує аналітичну задачу для subscription-based продукту з paid acquisition.

Бізнес хоче зрозуміти, які acquisition channels є найбільш ефективними з точки зору unit economics: скільки коштує залучення користувача, скільки revenue генерує користувач після реєстрації, та чи окупається канал через LTV/CAC.

Основні канали аналізу:

- `meta`
- `tiktok`
- `google`

## Project Objective

Мета проєкту — дослідити якість даних, побудувати продуктові та monetization metrics, розрахувати LTV, CAC і LTV/CAC по каналах, а також візуалізувати результати у Tableau dashboard.

Ключові питання:

- Який канал має найнижчий CAC?
- Який канал має найкращий LTV/CAC?
- Чи виправданий більший spend у Meta?
- Де користувачі найбільше втрачаються у funnel?
- Як змінювався CAC по місяцях?
- Який канал найкращий для масштабування?

## Data Understanding

Аналіз базується на трьох джерелах даних:

- `product_events` — продуктові події користувачів;
- `orders` — revenue events;
- `marketing_ads_raw.csv` — рекламні дані з TikTok, Meta та Google.

`product_events` має milestone-level grain: один рядок показує, що користувач досягнув певного продуктового етапу.

`orders` має payment-event grain: один рядок відповідає одній revenue event, наприклад `purchase`, `rebill` або `upsell`.

`marketing_ads_raw.csv` має cumulative snapshot-level grain: один `ad_id` може мати кілька snapshot-ів протягом дня, тому перед розрахунком CAC дані були дедубліковані.

## Data Quality Checks

Перед аналізом були виконані перевірки:

- null values у ключових полях;
- дублікати за natural keys;
- валідність revenue amount;
- consistency price points;
- funnel consistency;
- paying users consistency;
- date coverage між datasets;
- cross-dataset consistency між product/revenue data та marketing ads data.

Під час cross-dataset check було виявлено, що absolute marketing metrics у `marketing_ads_raw.csv` збережені приблизно у масштабі x100. Тому для CAC-аналізу `spend`, `impressions`, `clicks`, `installs` та `registrations` були нормалізовані через `/100`.

## Metrics Framework

Основні метрики:

- `LTV per payer` — revenue на paying user за 6 місяців;
- `LTV per registered user` — revenue на registered user за 6 місяців;
- `CAC` — cost per registered user;
- `LTV/CAC` — співвідношення LTV до CAC;
- `CR Registration → Purchase`;
- `CR Click → Install`;
- `CR Install → Registration`;
- `Revenue Share`;
- `Monthly CAC`.

Оскільки CAC рахується як:
CAC = spend / registrations
LTV/CAC = LTV per registered user / CAC per registered user

## Analysis
SQL-запити розділені на логічні частини:

LTV та revenue by channel;
CAC by channel;
monthly CAC by channel;
acquisition та monetization funnels.

### Tableau dashboard візуалізує ключові частини аналізу:

KPI-картки: revenue за 6 місяців, marketing spend, CAC та LTV/CAC;
LTV/CAC по каналах із break-even лінією LTV/CAC = 1;
scatterplot CAC vs LTV на зареєстрованого користувача, де розмір bubble показує revenue scale;
динаміку CAC по місяцях;
воронку залучення;
воронку монетизації.

## Tableau Dashboard

Interactive dashboard is available on Tableau Public:

[Open Tableau Dashboard](https://public.tableau.com/app/profile/inna.myroshnichenko3475/viz/dashboard_17790857686770/UnitEconomicsDashboard?publish=yes)


# Key Findings
*tiktok* має найкращий LTV/CAC — 1.31. Це означає, що канал генерує приблизно $1.31 LTV на кожен $1 acquisition cost.
*google* має найвищий LTV per registered user — $16.80, але також найвищий CAC — $14.12.
*meta* має найнижчий CAC — $3.10 — і найбільший revenue scale: $41,034.56 або 52.20% усього revenue.
Водночас *meta* має LTV/CAC = 0.82, тобто канал нижче break-even.
Найнижчий CAC не гарантує найкращу unit economics.
Найвищий LTV також не гарантує найкращу unit economics.
Monthly CAC був відносно стабільним протягом кампанії, тому різниця між каналами виглядає системною.
# Recommendations
*tiktok* варто розглядати як основного кандидата для контрольованого масштабування, оскільки він має найкращий баланс між CAC та LTV.
*google* варто оптимізувати за CAC, не втрачаючи якість користувачів.
*meta* не варто вимикати одразу, оскільки він генерує найбільший revenue scale. Але канал потребує покращення traffic quality або conversion у purchase.
Для наступного етапу варто аналізувати marketing_ads_raw.csv на рівні campaign_id, adset_id та ad_id, щоб знайти сегменти з кращим CAC та funnel conversion.
Повний LTV/CAC на campaign/adset/ad level неможливий без user-level attribution між marketing data та product/revenue data.
## Limitations
Дані з product/revenue та marketing datasets не мають прямого user-level join.
LTV/CAC розраховано на channel level, тому результат є channel-level estimate, а не точним user-level attribution calculation.
Revenue window обмежений доступним періодом даних, тому 6-month LTV може бути observed LTV, а не повністю matured LTV для всіх користувачів.
Marketing metrics потребували нормалізації через /100, що було виявлено на етапі cross-dataset consistency checks.
CAC та LTV розраховані на рівні registered user, щоб забезпечити узгоджену базу порівняння.
