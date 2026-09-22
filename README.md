# Roostify

Roostify monitors poultry-house sensors and cloud-delivered V380 video. The
mobile app runs YOLOv8 locally; the edge device only transports video.

## Runtime architecture

```text
V380 camera --RTSP--> Python edge gateway --outbound relay--> video server
                                                               |
                                                               v
Roostify mobile app <--HLS / RTSP / RTMP playback---------------+
        |
        +-- on-device YOLOv8 --> normal / abnormal + confidence

V380 camera --V380 Cloud relay--> C# decoder --private RTSP--> MediaMTX
                                                                    |
Roostify mobile app <---------------HTTPS WebRTC/WHEP---------------+

V380 camera --local RTSP over farm Wi-Fi--> Roostify mobile app

DHT11 + MQ135 --> ESP32 --Wi-Fi--> Supabase <--Wi-Fi/HTTPS-- Roostify app
                    |
                    +--BLE (setup only)--> Roostify app
```

The boundary is intentional:

- For remote viewing, the camera's private RTSP URL and credentials are
  configured in `python_tmp/config.json` through the `ROOSTIFY_CAMERA_URL`
  environment variable.
- **V380 Cloud camera** sends the device ID to the long-lived C# service in
  `cs_tmp/v380connectorbackend`. The backend reads camera credentials from its
  protected VPS environment, discovers and decrypts the relay stream, publishes
  private RTSP to MediaMTX, and returns a public HTTPS WebRTC/WHEP URL.
- While connected to the farm Wi-Fi, the mobile app can alternatively scan the
  local subnet for RTSP cameras and connect to one directly. Optional camera
  credentials and a preferred stream path can be supplied before scanning.
- The Python gateway maintains the camera connection, relays with FFmpeg,
  reconnects with bounded backoff, and exposes local health information.
- The video server converts or exposes the ingest as a playback endpoint that
  the phone can reach. Its playback URL can be HLS/HTTP, RTSP, or RTMP.
- The app decodes the delivered stream, captures frames, and runs the bundled
  `assets/best_float32.tflite` model on the device.
- Supabase remains for authentication, profiles, ESP32 readings, alerts, and
  application data—not continuous CCTV transport. See `SUPABASE_SETUP.md`.
- The ESP32 posts DHT11/MQ135 readings straight to Supabase over its own
  Wi-Fi connection (see `ino_tmp/sketch_sep19a.ino` and the
  `ingest-sensor-reading` Edge Function); the phone only ever reads Postgres,
  live via Supabase Realtime. Bluetooth (BLE) is used solely to configure
  that Wi-Fi connection and the owning account, and to reset it ("forget
  Wi-Fi") - it never carries live sensor data.

The gateway's `ROOSTIFY_OUTPUT_URL` is normally an ingest/publishing URL. Do
not paste it into the app unless the media server explicitly uses that same URL
for playback. Publishing keys should remain on the edge gateway.

## Run the edge gateway

See `python_tmp/README.md` for Linux, FFmpeg, configuration, health checks, and
systemd installation. At minimum:

```bash
export ROOSTIFY_CAMERA_URL='rtsp://user:password@camera-lan-ip/stream-path'
export ROOSTIFY_OUTPUT_URL='rtmp://video-server/live/publishing-key'
python3 python_tmp/main.py --check
python3 python_tmp/main.py
```

After the video server exposes that ingest for viewers, sign in to Roostify,
open CCTV Monitoring, choose **Cameras**, and add the server's playback URL.
To connect through V380 Cloud, start the decoder backend and MediaMTX as
described in `cs_tmp/v380connectorbackend/README.md`, then build or run the app
with its public HTTPS API URL:

```bash
flutter run \
  --dart-define=V380_BACKEND_URL=https://api.roostify.com \
  --dart-define=V380_BACKEND_API_KEY=change-me
```

`V380_BACKEND_URL` defaults to `https://api.roostify.com` and can be overridden
for another deployment. `V380_BACKEND_API_KEY` may be omitted only when the
backend has no API key. Android emulators can reach a development backend with
`http://10.0.2.2:8080`. For production, set `Backend__PublicWebRtcBaseUrl` to
the HTTPS MediaMTX proxy (for example `https://stream.roostify.com`) and keep
RTSP ports private. Put `Backend__DefaultUsername` and
`Backend__DefaultPassword` in `/etc/roostify/v380decoder.env`; the app stores
only the numeric camera ID. Once configured, expand **V380 Cloud camera** and
enter that ID.

The build-time API key is an interim service credential. Before exposing the
API to untrusted users, replace it with user authentication and camera
ownership authorization as described in the backend deployment notes.
To connect locally instead, expand **Scan local network** while the phone is on
the same Wi-Fi as the camera.

For an existing router port-forward, open **Port-forwarded camera** and enter
the router's public hostname/IP, external TCP port, camera credentials, and
optional RTSP path. Roostify probes that one endpoint before offering to add
it. The app does not change router settings: map the external TCP port to the
camera's internal RTSP port first. Prefer a VPN or the edge gateway where
possible, because exposing RTSP directly to the internet increases risk.

## Flutter development

```bash
flutter pub get
flutter analyze
flutter test
```

Live playback, the V380 decoder-backend integration, and local RTSP discovery
are enabled on Android and iOS. The edge-gateway and cloud-video-server path
remains available for installations that keep camera credentials off mobile
devices.

## License

All rights reserved. See [LICENSE](LICENSE).
