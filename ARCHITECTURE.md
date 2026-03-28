# ZenVoyage — Architecture Design

## 技術棧

| 層級 | 技術 | 版本 |
|------|------|------|
| Frontend | Flutter Web | 3.x |
| Backend | Node.js + Express + TypeScript | ES2022 |
| Database | SQLite (better-sqlite3) | 3.x |
| 部署 | Same-origin (Express serve static + API) | port 6006 |
| Git | https://github.com/leejpjack-hue/travel-app.git | — |

### 部署架構
```
Express Server (:6006)
├── /api/*          → REST API (JSON)
├── /assets/*       → Flutter Web static assets
├── /*              → Flutter Web (index.html)
└── /uploads/*      → User uploads (photos, PDFs)
```

---

## 6 大模組架構

### Module 1: Pre-trip & Preferences (F1–F10)
行前設定、航班導入、天氣、簽證、打包清單

### Module 2: Timeline & Scheduling (F11–F20)
拖曳時間軸、衝突警告、智慧填補、雨天備案

### Module 3: Transportation & Routing (F21–F30)
多交通模式、TSP 最佳化、票券計算、IC 卡

### Module 4: POI & Content (F31–F39)
景點管理、標籤系統、人流預測、預訂 API

### Module 5: In-Trip Execution (F40–F46)
離線模式、GPS 追蹤、票券管理、記帳

### Module 6: Export & AI (F47–F50)
PDF 匯出、AI 對話修改、回憶錄生成、拆帳

---

## 資料庫設計

### users
| Column | Type | Notes |
|--------|------|-------|
| id | TEXT PK | UUID |
| email | TEXT UNIQUE | |
| name | TEXT | |
| password_hash | TEXT | |
| avatar_url | TEXT | |
| created_at | TEXT | ISO 8601 |

### collaborators
| Column | Type | Notes |
|--------|------|-------|
| id | TEXT PK | UUID |
| trip_id | TEXT FK | → trips.id |
| user_id | TEXT FK | → users.id |
| role | TEXT | owner/editor/viewer |
| invited_at | TEXT | |

### trips
| Column | Type | Notes |
|--------|------|-------|
| id | TEXT PK | UUID |
| title | TEXT | |
| destination | TEXT | |
| start_date | TEXT | |
| end_date | TEXT | |
| timezone | TEXT | |
| base_location | TEXT | NULL for multi-city |
| preferences | TEXT | JSON (transport, pace, budget) |
| template_id | TEXT | NULL |
| created_by | TEXT FK | → users.id |
| created_at | TEXT | |
| updated_at | TEXT | |

### days
| Column | Type | Notes |
|--------|------|-------|
| id | TEXT PK | UUID |
| trip_id | TEXT FK | → trips.id |
| day_number | INTEGER | 1-based |
| date | TEXT | |
| weather | TEXT | JSON (forecast data) |
| rain_backup_active | INTEGER | 0/1 |

### timeline_items
| Column | Type | Notes |
|--------|------|-------|
| id | TEXT PK | UUID |
| day_id | TEXT FK | → days.id |
| start_time | TEXT | HH:MM |
| end_time | TEXT | HH:MM |
| poi_id | TEXT FK NULL | → pois.id |
| transport_id | TEXT FK NULL | → transportation.id |
| item_type | TEXT | poi/transport/note/rest |
| title | TEXT | |
| is_locked | INTEGER | 0/1 |
| is_rain_backup | INTEGER | 0/1 |
| notes | TEXT | |
| sort_order | INTEGER | |

### pois
| Column | Type | Notes |
|--------|------|-------|
| id | TEXT PK | UUID |
| trip_id | TEXT FK | → trips.id |
| name_zh | TEXT | |
| name_ja | TEXT | |
| name_en | TEXT | |
| latitude | REAL | |
| longitude | REAL | |
| google_place_id | TEXT | |
| address | TEXT | |
| category | TEXT | shrine/temple/food/nature/museum/etc |
| tags | TEXT | JSON array |
| rating | REAL | 1-5 |
| stay_minutes | INTEGER | recommended |
| opening_hours | TEXT | JSON |
| admission | INTEGER | JPY |
| notes | TEXT | |
| photo_urls | TEXT | JSON array |

### transportation
| Column | Type | Notes |
|--------|------|-------|
| id | TEXT PK | UUID |
| trip_id | TEXT FK | → trips.id |
| from_poi_id | TEXT FK NULL | |
| to_poi_id | TEXT FK NULL | |
| mode | TEXT | walk/train/bus/car/ferry |
| duration_min | INTEGER | |
| cost | INTEGER | JPY |
| ic_card | INTEGER | 0/1 |
| route_detail | TEXT | JSON (stops, line, etc) |
| is_optimized | INTEGER | 0/1 |

### bookings
| Column | Type | Notes |
|--------|------|-------|
| id | TEXT PK | UUID |
| trip_id | TEXT FK | → trips.id |
| type | TEXT | flight/hotel/activity/restaurant |
| title | TEXT | |
| booking_ref | TEXT | |
| date | TEXT | |
| start_time | TEXT | NULL |
| end_time | TEXT | NULL |
| location | TEXT | |
| cost | INTEGER | JPY |
| currency | TEXT | |
| status | TEXT | confirmed/pending/cancelled |
| voucher_url | TEXT | |
| notes | TEXT | |

### expenses
| Column | Type | Notes |
|--------|------|-------|
| id | TEXT PK | UUID |
| trip_id | TEXT FK | → trips.id |
| day_id | TEXT FK NULL | → days.id |
| category | TEXT | food/transport/shopping/activity/accommodation/other |
| amount | REAL | |
| currency | TEXT | |
| jpy_amount | REAL | |
| paid_by | TEXT FK NULL | → users.id |
| split_among | TEXT | JSON array of user IDs |
| description | TEXT | |
| receipt_url | TEXT | |
| created_at | TEXT | |

---

## API 設計

### Auth
- `POST /api/auth/register`
- `POST /api/auth/login`
- `GET /api/auth/me`

### Trips (Module 1)
- `GET /api/trips` — List user's trips
- `POST /api/trips` — Create trip
- `GET /api/trips/:id` — Get trip detail
- `PUT /api/trips/:id` — Update trip
- `DELETE /api/trips/:id` — Delete trip
- `POST /api/trips/:id/collaborators` — Add collaborator
- `GET /api/trips/:id/collaborators` — List collaborators
- `POST /api/trips/:id/import-flight` — Import flight info
- `GET /api/trips/:id/weather` — Weather forecast
- `GET /api/trips/:id/visa-info` — Visa requirements
- `POST /api/trips/:id/packing-list` — Generate packing list
- `GET /api/templates` — List templates
- `POST /api/trips/from-template/:templateId` — Create from template

### Days & Timeline (Module 2)
- `GET /api/trips/:id/days` — List days
- `POST /api/trips/:id/days` — Add day
- `GET /api/days/:id/timeline` — Get timeline
- `POST /api/days/:id/timeline` — Add timeline item
- `PUT /api/timeline/:id` — Update item
- `DELETE /api/timeline/:id` — Delete item
- `POST /api/timeline/reorder` — Drag-reorder items
- `POST /api/days/:id/conflicts` — Check conflicts
- `POST /api/days/:id/auto-fill` — Smart fill gaps
- `GET /api/days/:id/walking-distance` — Total walking distance
- `POST /api/days/:id/toggle-rain` — Toggle rain backup

### Transportation (Module 3)
- `GET /api/trips/:id/transport` — List transport segments
- `POST /api/trips/:id/transport` — Add transport
- `PUT /api/transport/:id` — Update transport
- `POST /api/trips/:id/optimize-route` — TSP optimization
- `GET /api/transport/passes/calculate` — Pass cost calculator
- `GET /api/stations/:id/exits` — Station exit guide
- `GET /api/stations/:id/lockers` — Station lockers
- `GET /api/routes/realtime` — Real-time rail schedule

### POIs (Module 4)
- `GET /api/trips/:id/pois` — List POIs
- `POST /api/trips/:id/pois` — Add POI
- `PUT /api/pois/:id` — Update POI
- `DELETE /api/pois/:id` — Delete POI
- `GET /api/pois/search` — Search POIs (Google Places)
- `GET /api/pois/:id/nearby` — Nearby toilets/convenience stores
- `GET /api/pois/:id/crowd-prediction` — Crowd prediction
- `POST /api/pois/:id/photos` — Upload photo
- `POST /api/pois/:id/reviews` — Add review
- `GET /api/pois/:id/booking-options` — Klook/KKday options

### In-Trip (Module 5)
- `GET /api/trips/:id/offline-pack` — Download offline data
- `POST /api/trips/:id/gps-track` — Upload GPS point
- `GET /api/trips/:id/tickets` — List digital tickets
- `POST /api/trips/:id/tickets` — Upload ticket
- `POST /api/reminders` — Set reminder
- `GET /api/trips/:id/emergency` — Emergency info
- `GET /api/trips/:id/expenses` — List expenses
- `POST /api/trips/:id/expenses` — Add expense
- `PUT /api/expenses/:id` — Update expense

### Export & AI (Module 6)
- `POST /api/trips/:id/export-pdf` — Generate travel handbook PDF
- `POST /api/trips/:id/ai-chat` — AI chat for itinerary modification
- `GET /api/trips/:id/memories` — Generate travel memories
- `GET /api/trips/:id/split-bill` — Calculate split bill

### Utilities
- `GET /api/exchange-rate` — Exchange rate query

---

## UI 設計方向

- **App 名稱:** ZenVoyage
- **主色調:** 清新薄荷綠 (#4ECDC4) + 白色 (#FFFFFF)
- **輔助色:** 深灰文字 (#2D3436)、淡灰背景 (#F8F9FA)、強調橘 (#FF6B6B)
- **風格:** 卡片式佈局、圓角設計、Q 版交通圖示
- **時間軸:** 拖曳式垂直時間軸，支持手機/平板/桌面
- **字體:** Noto Sans TC (繁中) + Noto Sans JP (日文)

---

## 外部 API 整合

| API | 用途 | 模組 |
|-----|------|------|
| Google Maps Places API | 景點搜尋、附近設施 | M4 |
| Google Maps Directions API | 路線規劃、步行距離 | M2, M3 |
| Google Flights API | 航班資訊導入 | M1 |
| Yahoo 乗換案内 API | 日本交通時刻表、票券 | M3 |
| OpenWeather API | 天氣預報 | M1, M2 |
| Klook API | 在地體驗預訂 | M4 |
| KKday API | 活動預訂 | M4 |
| Exchange Rate API | 匯率換算 | M5 |
| OpenAI API | AI 行程修改 | M6 |
