// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "@deps/phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "@deps/phoenix"
import { LiveSocket } from "@deps/phoenix_live_view"
import topbar from "../vendor/topbar"
import Hooks from "./_hooks"
import { Storage } from "./Storage"

const fetchParams = () => {
  const csrfToken = document.querySelector("meta[name='csrf-token']")?.getAttribute("content")
  const params = { _csrf_token: csrfToken };

  try {
    const storedParams = Storage.load('params', {}, JSON.parse);
    Object.assign(params, storedParams);
  } catch (e) {
    console.error('Failed to load params from localStorage', e);
  }
  
  return params;
}
const liveSocket = new LiveSocket("/live", Socket, { params: fetchParams, hooks: Hooks })

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" })
window.addEventListener("phx:page-loading-start", info => topbar.show())
window.addEventListener("phx:page-loading-stop", info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect();

(window as any).liveSocket = liveSocket;