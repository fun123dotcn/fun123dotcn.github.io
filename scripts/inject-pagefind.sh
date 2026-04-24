#!/bin/bash
# inject-pagefind.sh - 在Mintlify静态导出产物中注入Pagefind搜索功能
set -e
SITE_DIR="${1:-static_site}"

echo "=== Step 1: Running Pagefind ==="
cd "$SITE_DIR"
npx -y pagefind@latest --site . --output-subdir pagefind
echo "Pagefind index created"

echo "=== Step 2: Injecting search into HTML files ==="

find . -name "*.html" -print0 | while IFS= read -r -d "" htmlfile; do
  if grep -q "pf-overlay" "$htmlfile"; then
    continue
  fi
  python3 -c "
import sys
with open('$htmlfile', 'r', encoding='utf-8') as f:
    content = f.read()
if 'pf-overlay' not in content:
    inject = '''<script>
(function(){function init(){var l=document.createElement(\"link\");l.rel=\"stylesheet\";l.href=\"/pagefind/pagefind-ui.css\";document.head.appendChild(l);var s=document.createElement(\"script\");s.src=\"/pagefind/pagefind-ui.js\";s.onload=setup;document.body.appendChild(s)}function setup(){var o=document.createElement(\"div\");o.id=\"pf-overlay\";o.style.cssText=\"display:none;position:fixed;inset:0;z-index:9999;background:rgba(0,0,0,0.5);backdrop-filter:blur(4px);align-items:flex-start;justify-content:center;padding-top:15vh\";var b=document.createElement(\"div\");b.style.cssText=\"background:white;border-radius:12px;width:90%;max-width:580px;max-height:60vh;overflow:hidden;box-shadow:0 25px 50px -12px rgba(0,0,0,0.25)\";b.id=\"pf-container\";o.appendChild(b);document.body.appendChild(o);try{new PagefindUI({element:\"#pf-container\",showImages:false})}catch(e){}o.addEventListener(\"click\",function(e){if(e.target===o)closeSearch()});document.addEventListener(\"keydown\",function(e){if(e.key===\"Escape\")closeSearch();if((e.metaKey||e.ctrlKey)&&e.key===\"k\"){e.preventDefault();openSearch()}});replaceBtns()}function openSearch(){var o=document.getElementById(\"pf-overlay\");if(o){o.style.display=\"flex\";var i=o.querySelector(\"input\");if(i)setTimeout(function(){i.focus()},100)}}function closeSearch(){var o=document.getElementById(\"pf-overlay\");if(o)o.style.display=\"none\"}function replaceBtns(){var btns=document.querySelectorAll(\"#search-bar-entry,#search-bar-entry-mobile,button[aria-label=\\\"Open search\\\"]\");btns.forEach(function(b){b.onclick=function(e){e.preventDefault();e.stopPropagation();openSearch()}})}var n=0;var iv=setInterval(function(){replaceBtns();n++;if(n>20)clearInterval(iv)},500);if(document.readyState===\"loading\")document.addEventListener(\"DOMContentLoaded\",init);else init()})();
</script>'''
    content = content.replace('</body>', inject + '</body>')
    with open('$htmlfile', 'w', encoding='utf-8') as f:
        f.write(content)
"
done

echo "=== Done: Pagefind search injected ==="
echo "Total HTML files: $(find . -name '*.html' | wc -l)"
