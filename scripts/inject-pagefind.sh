#!/bin/bash
# inject-pagefind.sh - 在Mintlify静态导出产物中注入Pagefind搜索功能
set -e
SITE_DIR="${1:-static_site}"

echo "=== Step 1: Running Pagefind ==="
cd "$SITE_DIR"
npx -y pagefind@latest --site . --output-subdir pagefind
echo "Pagefind index created"

echo "=== Step 2: Injecting search into HTML files ==="

# 用Python处理所有HTML文件
python3 - "$SITE_DIR" << 'PYEOF'
import sys, os, glob

SITE_DIR = "."

INJECT_STYLE = """<style>
/* Hide Mintlify search modal */
[data-radix-popper-content-wrapper],
div[role="dialog"][data-state="open"],
[data-radix-dialog-overlay],
[data-radix-portal] > div[role="dialog"] {
  display: none !important;
}
/* Logo subtitle - force inline on same line */
.nav-subtitle {
  font-size: 12px;
  color: #6b7280;
  margin-left: 8px;
  white-space: nowrap;
  font-weight: 500;
  letter-spacing: 0.02em;
  display: inline !important;
  vertical-align: middle;
  line-height: 28px;
}
.nav-subtitle::before {
  content: "|";
  margin-right: 8px;
  color: #d1d5db;
}
/* Ensure logo link and subtitle are on same line */
.flex.items-center:has(img.nav-logo) {
  flex-wrap: nowrap !important;
}
a:has(img.nav-logo) {
  display: inline-flex !important;
  align-items: center;
  flex-wrap: nowrap;
  white-space: nowrap;
}
/* DO NOT override img.nav-logo display — preserve Tailwind light/dark switching */
/* Hide "Powered by Mintlify" footer */
a[href*="mintlify.com"],
a[href*="mintlify.com"] *,
footer a[href*="mintlify"],
div:has(> a[href*="mintlify"]) {
  display: none !important;
}
:root[data-page-mode="dark"] .nav-subtitle {
  color: #9ca3af;
}
:root[data-page-mode="dark"] .nav-subtitle::before {
  color: #4b5563;
}
</style>"""

INJECT_SCRIPT = """<script>
(function(){
  window.__pfOpen = false;
  function openSearch() {
    window.__pfOpen = true;
    var o = document.getElementById("pf-overlay");
    if (o) {
      o.style.display = "flex";
      var i = o.querySelector("input");
      if (i) setTimeout(function(){ i.focus(); }, 150);
    }
  }
  function closeSearch() {
    window.__pfOpen = false;
    var o = document.getElementById("pf-overlay");
    if (o) o.style.display = "none";
  }
  /* Intercept search clicks at document capture phase (works with React SPA) */
  document.addEventListener("click", function(e) {
    var t = e.target;
    var btn = t.closest("#search-bar-entry, #search-bar-entry-mobile, button[aria-label='Open search']");
    console.log("[Pagefind] click target:", t.tagName, t.className, t.id, "| btn:", btn ? btn.id + " " + btn.tagName : "none");
    if (btn) {
      e.preventDefault(); e.stopPropagation(); e.stopImmediatePropagation();
      openSearch();
      console.log("[Pagefind] search opened");
    }
  }, true);
  document.addEventListener("keydown", function(e) {
    if ((e.metaKey || e.ctrlKey) && e.key === "k") {
      e.preventDefault(); e.stopPropagation(); e.stopImmediatePropagation();
      openSearch();
    }
    if (e.key === "Escape" && window.__pfOpen) {
      e.stopPropagation(); e.stopImmediatePropagation();
      closeSearch();
    }
  }, true);
  /* MutationObserver to kill Mintlify modal */
  var obs = new MutationObserver(function(ms) {
    ms.forEach(function(m) {
      m.addedNodes.forEach(function(n) {
        if (n.nodeType !== 1) return;
        if (n.querySelector && (n.querySelector('[role="dialog"]') || n.querySelector('[data-radix-popper-content-wrapper]'))) {
          var d = n.querySelector('[data-radix-popper-content-wrapper]') || n.querySelector('[role="dialog"]');
          if (d) d.remove();
        }
        if (n.getAttribute && (n.getAttribute("role") === "dialog" || n.hasAttribute("data-radix-popper-content-wrapper"))) {
          n.remove();
        }
      });
    });
  });
  obs.observe(document.documentElement, { childList: true, subtree: true });
  /* Load Pagefind */
  var link = document.createElement("link");
  link.rel = "stylesheet";
  link.href = "/pagefind/pagefind-ui.css";
  document.head.appendChild(link);
  var scr = document.createElement("script");
  scr.src = "/pagefind/pagefind-ui.js";
  scr.onload = function() {
    var ov = document.createElement("div");
    ov.id = "pf-overlay";
    ov.style.cssText = "display:none;position:fixed;inset:0;z-index:99999;background:rgba(0,0,0,0.5);backdrop-filter:blur(4px);align-items:flex-start;justify-content:center;padding-top:15vh";
    var bx = document.createElement("div");
    bx.style.cssText = "background:white;border-radius:12px;width:90%;max-width:580px;max-height:60vh;overflow:hidden;box-shadow:0 25px 50px -12px rgba(0,0,0,0.25)";
    bx.id = "pf-container";
    ov.appendChild(bx);
    document.body.appendChild(ov);
    try { new PagefindUI({ element: "#pf-container", showImages: false }); } catch(e) {}
    ov.addEventListener("click", function(e) { if (e.target === ov) closeSearch(); });
    /* Search buttons handled by capture-phase listener above */
  };
  document.body.appendChild(scr);
  /* Add subtitle after logo - insert after the <a> tag, not inside */
  function addSubtitle() {
    var logos = document.querySelectorAll("img.nav-logo");
    logos.forEach(function(logo) {
      var link = logo.closest("a");
      if (link && !link.nextElementSibling?.classList?.contains("nav-subtitle")) {
        var sub = document.createElement("span");
        sub.className = "nav-subtitle";
        sub.textContent = "AI\u8F85\u52A9\u7F16\u7A0B\u7814\u7A76";
        link.parentNode.insertBefore(sub, link.nextSibling);
      }
    });
  }
  addSubtitle();
  setInterval(addSubtitle, 3000);
  /* Sidebar "文档中心" tab → navigate to root */
  function hijackSidebarTab() {
    document.querySelectorAll('nav button, nav a, [role="tablist"] button, [role="tablist"] a').forEach(function(el) {
      if (el.dataset.tabRoot) return;
      if (el.textContent.trim().indexOf('\u6587\u6863\u4E2D\u5FC3') !== -1) {
        el.dataset.tabRoot = "1";
        el.style.cursor = "pointer";
        el.addEventListener("click", function(e) {
          e.preventDefault(); e.stopPropagation(); e.stopImmediatePropagation();
          window.location.href = "/";
        }, true);
      }
    });
  }
  hijackSidebarTab();
  setInterval(hijackSidebarTab, 3000);
})();
</script>"""

count = 0
for htmlfile in glob.glob(os.path.join(SITE_DIR, "**/*.html"), recursive=True):
    with open(htmlfile, "r", encoding="utf-8") as f:
        content = f.read()
    if "pf-overlay" in content:
        continue
    content = content.replace("</head>", INJECT_STYLE + "</head>")
    content = content.replace("</body>", INJECT_SCRIPT + "</body>")
    with open(htmlfile, "w", encoding="utf-8") as f:
        f.write(content)
    count += 1

print(f"Injected Pagefind into {count} HTML files")
PYEOF

echo "=== Done ==="
