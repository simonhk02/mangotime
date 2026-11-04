import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import App from "./App";
import ProtoApp from "./ProtoApp";
import PublicView from "./PublicView";
import "./style.css";

// ?proto=1 → 全畫面原型模式（static mock，唔掂後台）
// /public/<slug> → 公開唯讀月曆（唔使登入）
const proto = new URLSearchParams(location.search).has("proto");
const pubMatch = location.pathname.match(/^\/public\/([A-Za-z0-9_-]+)/);

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    {pubMatch ? <PublicView slug={pubMatch[1]} /> : proto ? <ProtoApp /> : <App />}
  </StrictMode>,
);
