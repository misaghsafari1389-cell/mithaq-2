# Edge Functions

`mithaq-bootstrap-admin` was used once to create the initial administrator and then replaced with a disabled 410 response. It must not be re-enabled without a new one-time secret and an explicit security review. The public site uses database RPCs and does not expose a service role key.

## Web Push

`mithaq-notify-push` is deployed in Supabase and sends standards-based Web Push notifications using the private VAPID key held server-side by the deployed function. The browser only receives the public VAPID key from `js/push-config.js`. The manager taps «اعلان مرورگر: فعال‌سازی», grants phone permission, and the service worker subscription is stored through `mithaq_save_push_subscription`. After a public report has a registered audio file, the client calls the function with the report proof; the function validates the proof and sends the notification to subscribed devices.

On Android, Chrome notifications work after permission. On iPhone/iPad, iOS 16.4+ requires the site to be added to the Home Screen as a web app before Web Push permission is available. The admin page must be activated once on each phone/browser that should receive notifications.
