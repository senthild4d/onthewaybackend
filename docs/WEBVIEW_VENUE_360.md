# Venue 360° WebView (A-Frame)

Static page for **venue** equirectangular tours — **not** story/moment clips.

## URL

```
GET https://<your-api-host>/venue_360_viewer.html?url=<percent-encoded-mp4-url>&hotspots=<percent-encoded-json>
```

Legacy redirect: **`/360_viewer.html`** → **`/venue_360_viewer.html`** (query string preserved).

**`url`** — venue **equirectangular** MP4 (2:1), not flat phone video.

**`hotspots`** (optional) — JSON array of pins the user can look at and **click**; each opens a **full-screen image** modal.

```json
[
  { "yaw": -25, "pitch": -8, "image": "https://cdn.example.com/venue/stage.jpg", "label": "Main stage" },
  { "yaw": 42, "pitch": 2, "image": "https://cdn.example.com/venue/bar.jpg", "label": "Bar" }
]
```

- **`yaw`** — horizontal angle in degrees (negative = left, positive = right; `0` = straight ahead).
- **`pitch`** — vertical angle (positive = up, negative = down).
- **`image`** — **HTTPS** URL of the photo to show when the pin is clicked (must be loadable in a browser; configure CORS if you read pixels client-side; plain `<img src>` usually works for display).
- **`label`** — optional; shown under the expanded image.

## Flutter (`webview_flutter`)

Video only:

```dart
final uri = Uri.parse('$apiBaseUrl/venue_360_viewer.html').replace(
  queryParameters: {'url': venueEquirectangularVideoUrl},
);
await controller.loadRequest(uri);
```

Video + hotspots (build JSON on the server or in the app):

```dart
import 'dart:convert';

final hotspots = [
  {'yaw': -25, 'pitch': -8, 'image': 'https://…/a.jpg', 'label': 'Stage'},
  {'yaw': 40, 'pitch': 3, 'image': 'https://…/b.jpg', 'label': 'Bar'},
];
final uri = Uri.parse('$apiBaseUrl/venue_360_viewer.html').replace(
  queryParameters: {
    'url': venueEquirectangularVideoUrl,
    'hotspots': jsonEncode(hotspots),
  },
);
await controller.loadRequest(uri);
```

## CORS

If the MP4 is on another origin (S3, ActiveStorage, etc.), that bucket must allow **`crossorigin`** requests from the WebView origin (see `crossorigin="anonymous"` on the viewer’s `<video>`).

## Local test

```
http://localhost:3000/venue_360_viewer.html?url=https://example.com/venue-tour.mp4
```
