# bmc-browser

Runs a BMC Web UI in a throwaway container and serves it to your browser, so the machine you view it from needs nothing installed. Java Web Start KVM consoles launched from the BMC UI run inside the same container.

Run it wherever the BMC is reachable, on your own machine or on a host in the management network.

## Run

```
docker run --rm -i -p 127.0.0.1:8080:8080 -e BMC_URL=https://10.0.0.12/ ghcr.io/zinrai/bmc-browser
```

Open http://localhost:8080/.

The container exits when Firefox exits, and `--rm` removes it. Keeping it in the foreground ties its lifetime to your terminal.

There is no VNC password. Publish the port on a loopback address, as above, and let whatever already controls access to the host control access to the console.

## Configuration

- `BMC_URL` (required) - URL of the BMC Web UI, for example `https://10.0.0.12/`. Passed to Firefox as given.
- `SCREEN_GEOMETRY` - screen width and height (default: 1280x1024)
- `SCREEN_DEPTH` - screen colour depth (default: 24)

## Notes

Self-signed BMC certificates show the standard Firefox warning page once per session. Accept it in the session under.

KVM consoles open as their own window on top of the browser. Use the task bar at the bottom of the screen to switch between them.

Copy and paste works in both directions through the clipboard panel in the sidebar, not by pressing Ctrl-C and Ctrl-V straight through. Paste into the panel to send text to the session, and read text copied inside the session out of the same panel. Whether a KVM console accepts pasted text is up to the vendor's viewer.

KVM applets run without a security prompt, and `.jnlp` files are handed to `javaws` without asking. This assumes you trust the BMC you point this at. The container runs as an unprivileged user and is discarded when it exits.

## License

This project is licensed under the [MIT License](LICENSE).
