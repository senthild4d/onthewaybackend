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
- `view_360_url` / `immersive_video_view_url` — full URL to the static A-Frame viewer when a video is present. Otherwise `null`.
- `has_360_view` — `true` only when `video_projection` is `equirectangular` and a video is attached.
- `view_360` — `{ available, projection, video_url, viewer_url }`.

When using the dedicated video upload endpoint, send one of these multipart fields with the file to mark it as 360:

- `video_projection=equirectangular`
- `property[video_projection]=equirectangular`
- `is_360=true`

There is also a dedicated one-step API for 360 uploads:

```
POST /api/v1/properties/:id/360_video
multipart/form-data:
  video=<equirectangular 2:1 mp4>
```

This endpoint automatically sets `video_projection` to `equirectangular`, replaces the previous property video, and returns `view_360_url`.

## Viewer (reuse Vibes venue page)

Same static file as venues:

```
GET {api_base}/venue_360_viewer.html?url={percent-encoded-mp4-url}
```

Optional `hotspots` query param works the same as [WEBVIEW_VENUE_360.md](./WEBVIEW_VENUE_360.md).

The app can open `view_360_url` / `immersive_video_view_url` from the API. Use `has_360_view` or `view_360.available` to decide whether to show the 360 UI.

## Form options

`GET /api/v1/properties/form_options` includes `video_projections` for picker labels/values.

## Notes

- **CORS**: if the MP4 is cross-origin, the bucket must allow the WebView origin (see venue 360 doc).
- **Processing**: this repo includes ffmpeg services used by **moments** (flat → equirectangular). Properties do **not** auto-convert uploads; owners should upload true equirectangular 360° footage or run conversion elsewhere.
