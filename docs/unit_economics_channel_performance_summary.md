# Unit Economics & Channel Performance Summary

## Overview

Було розраховано channel-level unit economics для трьох acquisition channels: `tiktok`, `meta`, `google`.

Аналіз поєднує дві частини:

- `product_events` та `orders` — для розрахунку revenue, LTV per payer, LTV per registered user та monetization funnel;
- `marketing_ads_raw.csv` — для розрахунку spend, marketing funnel metrics, CAC, monthly CAC та LTV/CAC.

Оскільки CAC рахується як `spend / registrations`, LTV також приведено до тієї самої бази — `registered user`.

Фінальна логіка:

`LTV/CAC = LTV per registered user / CAC per registered user`

Інтерактивний dashboard доступний у Tableau Public:

[Open Tableau Dashboard](https://public.tableau.com/app/profile/inna.myroshnichenko3475/viz/dashboard_17790857686770/UnitEconomicsDashboard?publish=yes)

## LTV & Revenue Results

| Channel | Registered Users | Buyers | Total Revenue 6m | Revenue Share | CR Registration → Purchase | LTV 6m per Payer | LTV 6m per Registered User |
|---|---:|---:|---:|---:|---:|---:|---:|
| meta | 16,114 | 531 | $41,034.56 | 52.20% | 3.30% | $77.28 | $2.55 |
| tiktok | 2,790 | 282 | $19,664.86 | 25.02% | 10.11% | $69.73 | $7.05 |
| google | 1,066 | 194 | $17,905.62 | 22.78% | 18.20% | $92.30 | $16.80 |

## CAC & LTV/CAC Results

Перед розрахунком CAC таблиця `marketing_ads_raw.csv` була дедублікована: для кожного `ad_id + date` залишено останній cumulative snapshot за `timestamp`.

Під час cross-dataset consistency checks було виявлено, що absolute marketing metrics збережені приблизно у масштабі x100. Тому `spend`, `impressions`, `clicks`, `installs` та `registrations` були нормалізовані через `/100`.

| Channel | Total Spend | CPM | CTR | CR Click → Install | CR Install → Reg | CAC | LTV per Registered User | LTV/CAC |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| tiktok | $14,417.69 | $22.00 | 1.50% | 30.96% | 87.96% | $5.39 | $7.05 | 1.31 |
| google | $15,199.92 | $40.00 | 0.80% | 36.94% | 95.94% | $14.12 | $16.80 | 1.19 |
| meta | $49,921.41 | $14.00 | 1.20% | 39.99% | 93.98% | $3.10 | $2.55 | 0.82 |

## Dashboard View

Tableau dashboard візуалізує ключові частини аналізу:

- KPI-картки: revenue за 6 місяців, marketing spend, CAC та LTV/CAC;
- LTV/CAC по каналах із break-even лінією `LTV/CAC = 1`;
- scatterplot `CAC vs LTV на зареєстрованого користувача`, де розмір bubble показує revenue scale;
- динаміку CAC по місяцях;
- воронку залучення;
- воронку монетизації.


Dashboard допомагає одночасно оцінити три виміри:

- efficiency — чи окупається канал через LTV/CAC;
- scale — скільки revenue генерує канал;
- funnel quality — де користувачі втрачаються на шляху до покупки та монетизації.

## Main Observations

- `tiktok` має найкращий LTV/CAC — 1.31. Це означає, що канал генерує приблизно $1.31 LTV на кожен $1 acquisition cost.
- `google` має найвищий LTV per registered user — $16.80, але також найвищий CAC — $14.12. Через це його LTV/CAC нижчий, ніж у TikTok.
- `meta` має найнижчий CAC — $3.10 — і найбільший revenue scale: $41,034.56 або 52.20% усього revenue. Водночас LTV/CAC у Meta дорівнює 0.82, тобто канал нижче break-even.
- Найнижчий CAC не гарантує найкращу unit economics. Приклад — Meta: дешеве залучення, але слабка монетизація на registered user.
- Найвищий LTV також не гарантує найкращу unit economics. Приклад — Google: якісні користувачі, але дороге залучення.
- Monthly CAC chart показує, що CAC по каналах був відносно стабільним протягом кампанії. Отже різниця між каналами виглядає системною, а не наслідком одного аномального місяця.
- Acquisition та monetization funnels показують, що головна втрата користувачів відбувається до покупки. Саме conversion у paying users сильно впливає на LTV per registered user.

## Channel Interpretation

### TikTok

`tiktok` виглядає найкращим каналом з точки зору unit economics.

Канал має:

- LTV/CAC = 1.31;
- CAC = $5.39;
- LTV per registered user = $7.05;
- revenue share = 25.02%.

TikTok не є найбільшим revenue driver, але має найкращий баланс між acquisition cost та monetization. Канал варто розглядати як основного кандидата для контрольованого масштабування.

### Google

`google` приводить найякісніших користувачів з погляду monetization.

Канал має:

- найвищий LTV per registered user — $16.80;
- найвищий LTV per payer — $92.30;
- найвищу CR Registration → Purchase — 18.20%.

Водночас Google має найвищий CAC — $14.12. Тому головна задача для цього каналу — знижувати acquisition cost без втрати якості користувачів.

### Meta

`meta` є найбільшим каналом за масштабом.

Канал має:

- найбільший total revenue — $41,034.56;
- найбільший revenue share — 52.20%;
- найнижчий CAC — $3.10.

Але Meta має найнижчий LTV per registered user — $2.55 і LTV/CAC = 0.82. Це означає, що канал важливий для revenue scale, але за поточними даними не окупається на рівні unit economics.

## Business Takeaways

- Для фінального рішення не можна дивитися тільки на CAC, LTV або revenue окремо.
- `tiktok` має найкращий LTV/CAC, тому виглядає найкращим кандидатом для обережного масштабування.
- `google` має найкращу якість користувачів, але потребує оптимізації CAC.
- `meta` не варто оцінювати як просто “поганий канал”, бо він генерує понад половину revenue. Але канал потребує покращення traffic quality або conversion у purchase.
- Наступний крок — аналізувати CAC всередині `marketing_ads_raw.csv` на рівні campaign/adset/ad, щоб знайти сегменти з кращим CAC та funnel conversion.
- Повний LTV/CAC на campaign/adset/ad level неможливий без user-level attribution між marketing data та product/revenue data.
