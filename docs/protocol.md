# İstemci ↔ Sunucu Protokolü

Tek bir WebSocket bağlantısı (`/ws`), JSON metin mesajları. Her mesajın bir `type` alanı vardır.
Fotoğraflar base64 kodlu JPEG olarak gönderilir (en uzun kenar 1024 px).

## İstemci → Sunucu

| type | alanlar | kim | açıklama |
|---|---|---|---|
| `create_room` | `name`, `age_band` | herkes | Oda kurar, kuran kişi "host" olur |
| `join_room` | `code`, `name`, `age_band` | herkes | 4 harfli kodla katılır |
| `set_age_band` | `age_band` | herkes | Sadece lobide |
| `start_game` | `hider_id?` | host | Boşsa saklayan rastgele seçilir |
| `back_to_lobby` | — | host | Tur bitince ya da iptal için |
| `hider_submit` | `images: [b64, ...]` (1–3) | saklayan | AI nesneyi tanır |
| `hider_confirm` | `accept: bool` | saklayan | Onaylanınca ipuçları üretilir, arama başlar |
| `hint_request` | — | ebe | Sunucu bir bulmaca gönderir |
| `puzzle_answer` | `puzzle_id`, `answer` | ebe | Doğruysa sıradaki ipucu açılır |
| `seeker_scan` | `image: b64` | ebe | AI aday nesneyi referansla karşılaştırır |
| `ping` | — | herkes | `pong` döner |

`age_band`: `child` (7-10), `teen` (11-15), `adult` (16-55), `senior` (56-70).

## Sunucu → İstemci

| type | alanlar |
|---|---|
| `welcome` | `player_id`, `code` |
| `room_state` | `code`, `phase` (lobby/hiding/seeking/finished), `host_id`, `hider_id`, `winner_id`, `players[]`, `object` (yalnızca finished) |
| `busy` | `message` — AI çalışırken gösterilecek metin |
| `identify_result` | `valid`, `summary`, `name`, `color` **veya** `valid=false`, `message` (yalnızca saklayana) |
| `puzzle` | `puzzle_id`, `puzzle_type` (matrix/rotation/assembly), `time_limit` (0 = süresiz), `data` |
| `puzzle_result` | `correct`, `hint: {level, text}` **veya** `cooldown`, `expired` |
| `scan_result` | `match`, `message`, `cooldown` |
| `game_over` | `winner_id`, `winner_name`, `object`, `seconds` |
| `notice` | `message` |
| `error` | `message`, `for` (hatayı doğuran mesaj türü) |

## Bulmaca verileri

- **matrix**: `cells` (8 hücre, satır satır; 9. hücre eksik), `options[]`. Hücre: `{shape, color, count}`.
  Cevap: seçenek indeksi.
- **rotation**: `shape`, `sequence[]` (4 adım), `options[]`. Adım: `{angle, color}`. Cevap: seçenek indeksi.
- **assembly**: `width`, `height`, `allow_rotation`, `pieces[]` (`{cells: [[x,y],...], color}`).
  Cevap: `[{piece, rotation (0-3), x, y}, ...]`. Döndürme: `(x,y) → (-y,x)`, ardından (0,0)'a kaydırma.

Doğru cevap hiçbir zaman istemciye gönderilmez; doğrulama sunucudadır.

## Adil kazanan kuralı

"İlk bulan kazanır" taramanın **gönderildiği ana** göre uygulanır. AI'ın cevap süresi
değişken olduğundan, eşleşen bir tarama geldiğinde ondan önce gönderilmiş ve hâlâ kontrol
edilen taramalar beklenir.
