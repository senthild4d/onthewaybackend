# Property 360° video (same pattern as Vibes venues)

Property listings can attach one **video** (`has_one_attached :video`). For immersive 360° tours, use **equirectangular** MP4 (2:1 aspect), same as venue tours.

## API fields

On create/update, send inside `property`:

| Field | Values | Default |
|-------|--------|---------|
| `video_projection` | `flat` \| `equirectangular` | `flat` |

List/detail/map/favorites/admin responses include:

- `video` — URL of the attached MP4 (or `null`)
- `video_projection` — `flat` or `equirectangular`
- `immersive_video_view_url` — **only when** `video_projection` is `equirectangular` **and** `video` is present: full URL to the static A-Frame viewer with `url=` query param. Otherwise `null`.

## Viewer (reuse Vibes venue page)

Same static file as venues:

```
GET {api_base}/venue_360_viewer.html?url={percent-encoded-mp4-url}
```

Optional `hotspots` query param works the same as [WEBVIEW_VENUE_360.md](./WEBVIEW_VENUE_360.md).

The app can either open `immersive_video_view_url` from the API or build the URL itself from `video`.

## Form options

`GET /api/v1/properties/form_options` includes `video_projections` for picker labels/values.

## Notes

- **CORS**: if the MP4 is cross-origin, the bucket must allow the WebView origin (see venue 360 doc).
- **Processing**: this repo includes ffmpeg services used by **moments** (flat → equirectangular). Properties do **not** auto-convert uploads; owners should upload true equirectangular 360° footage or run conversion elsewhere.
