{{flutter_js}}
{{flutter_build_config}}

// The deprecated worker stub has a constant version across app builds.
// Refresh the entrypoint URL on page load so an old app cannot hide new controls.
const meteryaBuildVersion = Date.now().toString();
for (const build of _flutter.buildConfig.builds) {
  if (build.mainJsPath) {
    // Older Flutter workers normalize ?v= and can still serve their old cache.
    build.mainJsPath += `?meterya=${encodeURIComponent(meteryaBuildVersion)}`;
  }
}
async function startMeterya() {
  if ('serviceWorker' in navigator) {
    try {
      const workerURL = new URL('flutter_service_worker.js', document.baseURI).href;
      for (const registration of await navigator.serviceWorker.getRegistrations()) {
        const worker = registration.active ?? registration.waiting ?? registration.installing;
        if (worker?.scriptURL.split('?')[0] === workerURL) await registration.unregister();
      }
    } catch (_) {
      // The versioned entrypoint also works when worker access is unavailable.
    }
  }
  _flutter.loader.load();
}
startMeterya();
