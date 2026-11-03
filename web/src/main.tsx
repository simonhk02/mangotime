import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import App from "./App";
import ProtoApp from "./ProtoApp";
import "./style.css";

// ?proto=1 → 全畫面原型模式（static mock，唔掂後台）
const proto = new URLSearchParams(location.search).has("proto");

createRoot(document.getElementById("root")!).render(
  <StrictMode>{proto ? <ProtoApp /> : <App />}</StrictMode>,
);
