# Unit Economics & Channel Performance Summary


## Overview

Було розраховано LTV, revenue scale, CAC та LTV/CAC у розрізі acquisition channels: `tiktok`, `meta`, `google`.

Аналіз базується на двох частинах:

- `product_events` та `orders` — для розрахунку revenue, ARPPU / LTV per payer та LTV per registered user;
- `marketing_ads_raw.csv` — для розрахунку spend, marketing funnel metrics, CAC та LTV/CAC.

Оскільки CAC рахується як `spend / registrations`, LTV також приведено до бази `registered user`.

Фінальна логіка:

`LTV/CAC = LTV per registered user / CAC per registered user`

## LTV & Revenue Results

| Channel | Registered Users | Buyers | Total Revenue 6m | Revenue Share | CR Registration → Purchase | LTV 6m per Payer | LTV 6m per Registered User |
|---|---:|---:|---:|---:|---:|---:|---:|
| meta | 16,114 | 531 | $41,034.56 | 52.20% | 3.30% | $77.28 | $2.55 |
| tiktok | 2,790 | 282 | $19,664.86 | 25.02% | 10.11% | $69.73 | $7.05 |
| google | 1,066 | 194 | $17,905.62 | 22.78% | 18.20% | $92.30 | $16.80 |

## CAC & LTV/CAC Results

Перед розрахунком CAC дані `marketing_ads_raw.csv` були дедубліковані: для кожного `ad_id + date` залишено останній cumulative snapshot за `timestamp`.

Під час cross-dataset consistency checks було виявлено, що marketing metrics збережені приблизно у масштабі x100, тому absolute metrics були нормалізовані через `/100`.

| Source | Total Spend | CPM | CTR | CR Click → Install | CR Install → Reg | CAC | LTV per Registered User | LTV/CAC |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| tiktok | $14,417.69 | $22.00 | 1.50% | 30.96% | 87.96% | $5.39 | $7.05 | 1.31 |
| google | $15,199.92 | $40.00 | 0.80% | 36.94% | 95.94% | $14.12 | $16.80 | 1.19 |
| meta | $49,921.41 | $14.00 | 1.20% | 39.99% | 93.98% | $3.10 | $2.55 | 0.82 |

## Main Observations

- `meta` генерує найбільший revenue: $41,034.56 або 52.20% усього revenue. Водночас канал має найнижчий LTV per registered user — $2.55 — і найнижчий LTV/CAC — 0.82.
- `google` має найкращу якість користувачів: найвищий CR Registration → Purchase — 18.20%, найвищий LTV per payer — $92.30 і найвищий LTV per registered user — $16.80. Але CAC у Google також найвищий — $14.12.
- `tiktok` має найкращий баланс між вартістю залучення та LTV: CAC = $5.39, LTV per registered user = $7.05, LTV/CAC = 1.31.
- Найнижчий CAC не означає найкращу unit economics: `meta` має CAC $3.10, але LTV/CAC нижче 1.
- Найвищий LTV також не гарантує найкращу unit economics: `google` має найвищий LTV, але програє TikTok за LTV/CAC через дорожче залучення.
- Revenue scale і efficiency показують різну картину: `meta` найбільший за revenue, `google` найкращий за якістю користувачів, `tiktok` найкращий за LTV/CAC.

## Channel Interpretation

### TikTok

`tiktok` виглядає найсильнішим каналом з точки зору unit economics.

Канал має:

- LTV/CAC = 1.31;
- CAC = $5.39;
- LTV per registered user = $7.05;
- revenue share = 25.02%.

Це означає, що TikTok не є найбільшим revenue driver, але має найкращий баланс між acquisition cost та monetization. Канал варто розглядати як основного кандидата для контрольованого масштабування.

### Google

`google` приводить найякісніших користувачів з погляду monetization.

Канал має:

- найвищий LTV per registered user — $16.80;
- найвищий LTV per payer — $92.30;
- найвищу CR Registration → Purchase — 18.20%.

Водночас Google має найвищий CAC — $14.12. Тому головна задача для цього каналу — оптимізувати acquisition cost без втрати якості користувачів.

### Meta

`meta` є найбільшим каналом за масштабом.

Канал має:

- найбільший total revenue — $41,034.56;
- найбільший revenue share — 52.20%;
- найнижчий CAC — $3.10.

Але Meta має найнижчий LTV per registered user — $2.55 і LTV/CAC = 0.82. Це означає, що канал важливий для revenue scale, але за поточними даними не окупається на рівні unit economics.

## Business Takeaways

- Для фінального рішення недостатньо дивитися тільки на CAC, LTV або total revenue окремо.
- `tiktok` має найкращий LTV/CAC, тому виглядає найкращим кандидатом для обережного масштабування.
- `google` має найкращу якість користувачів, але потребує оптимізації CAC.
- `meta` не варто оцінювати як просто “поганий канал”, бо він генерує понад половину revenue. Але канал потребує покращення якості трафіку або conversion у purchase.
- На практиці продуктовий аналітик дивився б на три виміри одночасно: revenue scale, user quality та acquisition efficiency.
- Наступний крок — аналізувати CAC всередині `marketing_ads_raw.csv` на рівні campaign/adset/ad, щоб знайти сегменти з кращим CAC та funnel conversion. Повний LTV/CAC на цьому рівні неможливий без user-level attribution між marketing data та product/revenue data.
