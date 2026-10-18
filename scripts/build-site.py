#!/usr/bin/env python3
"""Render the documentation into a static site for GitHub Pages.

    python3 scripts/build-site.py            # writes ./dist
    gh-pages: git subtree push --prefix dist origin gh-pages

Requires: pip install markdown
"""
import markdown, pathlib, html, re, shutil

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "dist"
if OUT.exists(): shutil.rmtree(OUT)
OUT.mkdir(parents=True)

PAGES = [
    ("index.html", "README.md", "VoiceStudio on Colab — free GPU, full features", "Run the open-source ElevenLabs alternative on a free Colab T4 GPU. Your PC only shows the UI."),
    ("install.html", "INSTALL.md", "Installation", "Set up VoiceStudio on a free Google Colab T4 and pair the desktop app."),
    ("architecture.html", "ARCHITECTURE.md", "Architecture", "Components, environment variables and the API key handshake."),
    ("how-it-works.html", "HOW-IT-WORKS-IN-THE-APP.md", "Inside the app", "Source analysis: auth gates, routes, tiers and licences."),
    ("troubleshooting.html", "TROUBLESHOOTING.md", "Troubleshooting", "Every error message this setup produces, and what it means."),
    ("security.html", "SECURITY.md", "Security", "Threat model, key handling and residual risks."),
    ("faq.html", "FAQ.md", "FAQ", "Cost, privacy, speed and commercial use."),
]
NAV = [("index.html","Overview"),("install.html","Install"),("architecture.html","Architecture"),
       ("how-it-works.html","Inside the app"),("troubleshooting.html","Troubleshooting"),
       ("security.html","Security"),("faq.html","FAQ")]
REPO = "https://github.com/NurMohammadDuari/VoiceStudio-Colab-GPU"
SITE = "https://nurmohammadduari.github.io/VoiceStudio-Colab-GPU"

CSS = r"""
:root{
  --bg:#ffffff; --bg-soft:#f5f5f7; --card:#ffffff;
  --text:#1d1d1f; --muted:#6e6e73; --faint:#86868b;
  --hair:rgba(0,0,0,.10); --hair-soft:rgba(0,0,0,.06);
  --accent:#0071e3; --mint:#0a8f6c;
  --code-bg:#f5f5f7; --shadow:0 1px 2px rgba(0,0,0,.04),0 8px 24px rgba(0,0,0,.06);
  --nav-bg:rgba(255,255,255,.72);
}
@media (prefers-color-scheme:dark){:root{
  --bg:#000000; --bg-soft:#0b0b0d; --card:#141416;
  --text:#f5f5f7; --muted:#a1a1a6; --faint:#86868b;
  --hair:rgba(255,255,255,.14); --hair-soft:rgba(255,255,255,.08);
  --accent:#2997ff; --mint:#30d158;
  --code-bg:#1c1c1e; --shadow:0 1px 2px rgba(0,0,0,.5),0 8px 24px rgba(0,0,0,.45);
  --nav-bg:rgba(0,0,0,.72);
}}
*{box-sizing:border-box}
html{-webkit-text-size-adjust:100%}
body{margin:0;background:var(--bg);color:var(--text);
  font:400 17px/1.6 -apple-system,BlinkMacSystemFont,"SF Pro Text","Segoe UI",Inter,Roboto,system-ui,sans-serif;
  -webkit-font-smoothing:antialiased;-moz-osx-font-smoothing:grayscale;letter-spacing:-.011em}

/* frosted top nav */
.nav{position:sticky;top:0;z-index:50;background:var(--nav-bg);
  -webkit-backdrop-filter:saturate(180%) blur(20px);backdrop-filter:saturate(180%) blur(20px);
  border-bottom:1px solid var(--hair-soft)}
.nav-in{max-width:1080px;margin:0 auto;padding:0 22px;height:52px;display:flex;align-items:center;gap:28px}
.brand{display:flex;align-items:center;gap:9px;font-weight:600;font-size:15px;letter-spacing:-.01em;
  color:var(--text);text-decoration:none;white-space:nowrap}
.brand img{width:22px;height:22px;border-radius:6px}
.nav-links{display:flex;gap:4px;margin-left:auto;overflow-x:auto;scrollbar-width:none}
.nav-links::-webkit-scrollbar{display:none}
.nav-links a{color:var(--muted);text-decoration:none;font-size:13.5px;padding:6px 11px;border-radius:8px;
  white-space:nowrap;transition:color .2s,background .2s}
.nav-links a:hover{color:var(--text);background:var(--hair-soft)}
.nav-links a.on{color:var(--text);background:var(--hair-soft)}

/* content column */
main{max-width:820px;margin:0 auto;padding:56px 22px 110px}
.hero{margin-bottom:52px}
.hero .eyebrow{display:inline-block;font-size:12.5px;font-weight:600;letter-spacing:.02em;color:var(--mint);
  background:color-mix(in srgb,var(--mint) 10%,transparent);padding:5px 11px;border-radius:999px;margin-bottom:18px}
.hero h1{font-size:clamp(2.3rem,5.4vw,3.5rem);line-height:1.06;letter-spacing:-.032em;font-weight:700;margin:0 0 14px}
.hero p.lede{font-size:clamp(1.05rem,2.1vw,1.3rem);line-height:1.45;letter-spacing:-.018em;color:var(--muted);margin:0 0 26px}
.cta{display:flex;flex-wrap:wrap;gap:11px}
.btn{display:inline-block;padding:11px 21px;border-radius:980px;font-size:14.5px;font-weight:500;
  text-decoration:none;transition:transform .15s,filter .2s,background .2s}
.btn:active{transform:scale(.97)}
.btn-p{background:var(--accent);color:#fff}
.btn-p:hover{filter:brightness(1.08)}
.btn-s{background:var(--hair-soft);color:var(--text)}

/* typography */
h1{font-size:clamp(2.1rem,4.6vw,2.9rem);line-height:1.08;letter-spacing:-.03em;font-weight:700;margin:0 0 12px}
h2{font-size:clamp(1.5rem,2.6vw,1.85rem);line-height:1.18;letter-spacing:-.022em;font-weight:650;
  margin:2.9em 0 .7em;padding-top:.35em}
h3{font-size:1.22rem;letter-spacing:-.015em;font-weight:600;margin:2.1em 0 .5em}
h4{font-size:1.03rem;font-weight:600;margin:1.7em 0 .4em}
p,li{color:var(--text)}
p{margin:0 0 1.05em}
a{color:var(--accent);text-decoration:none}
a:hover{text-decoration:underline}
hr{border:0;height:1px;background:var(--hair-soft);margin:3.2em 0}
strong{font-weight:600}
small,.hero small{color:var(--faint)}
blockquote{margin:1.6em 0;padding:2px 0 2px 18px;border-left:2px solid var(--accent);
  color:var(--muted);font-style:normal}

/* code */
code{font-family:ui-monospace,SFMono-Regular,"SF Mono",Menlo,Consolas,monospace;font-size:.855em;
  background:var(--code-bg);padding:.15em .38em;border-radius:5px}
pre{background:var(--code-bg);border:1px solid var(--hair-soft);border-radius:12px;padding:16px 18px;
  overflow-x:auto;margin:1.5em 0}
pre code{background:none;padding:0;font-size:.855em;line-height:1.62}

/* tables */
.tw{overflow-x:auto;margin:1.6em 0;border:1px solid var(--hair-soft);border-radius:12px;background:var(--card)}
table{border-collapse:collapse;width:100%;font-size:15px;min-width:460px}
th,td{text-align:left;padding:12px 16px;border-bottom:1px solid var(--hair-soft)}
tr:last-child td{border-bottom:0}
th{font-weight:600;font-size:13px;letter-spacing:.01em;color:var(--muted);background:var(--bg-soft)}
tbody tr:nth-child(even){background:color-mix(in srgb,var(--bg-soft) 55%,transparent)}

img{max-width:100%;height:auto;border-radius:12px;border:1px solid var(--hair-soft);display:block;margin:1.2em 0}
ul,ol{padding-left:1.35em;margin:0 0 1.1em}
li{margin:.32em 0}
li::marker{color:var(--faint)}

footer{border-top:1px solid var(--hair-soft);margin-top:76px;padding-top:26px;
  color:var(--faint);font-size:13.5px;line-height:1.6}
footer a{color:var(--muted)}
.toc{background:var(--bg-soft);border:1px solid var(--hair-soft);border-radius:12px;padding:16px 20px;margin:26px 0}
.toc b{font-size:13px;letter-spacing:.03em;text-transform:uppercase;color:var(--faint)}
.toc ol{margin:8px 0 0;padding-left:1.2em}
.toc li{margin:.2em 0;font-size:14.5px}

@media(max-width:720px){
  .nav-in{height:auto;flex-wrap:wrap;padding:12px 18px;gap:12px}
  .nav-links{margin-left:0;width:100%}
  main{padding:34px 18px 76px}
}
"""

JS = r"""
(function(){
 var b=document.getElementById('tt');
 if(!b) return;
 var k='vs-theme', mq=window.matchMedia('(prefers-color-scheme: dark)');
 function cur(){ return localStorage.getItem(k) || (mq.matches?'dark':'light'); }
 function apply(t){ document.documentElement.dataset.theme=t; b.textContent = t==='dark'?'Light':'Dark'; }
 apply(cur());
 b.addEventListener('click',function(){
   var t = (localStorage.getItem(k) || (mq.matches?'dark':'light'))==='dark' ? 'light':'dark';
   localStorage.setItem(k,t); apply(t);
 });
 mq.addEventListener && mq.addEventListener('change',function(e){
   if(!localStorage.getItem(k)) apply(e.matches?'dark':'light');
 });
})();
"""

def md_to_html(text):
    return markdown.markdown(text, extensions=["tables","fenced_code","toc","attr_list"])

def wrap_tables(body):
    return re.sub(r'<table>', '<div class="tw"><table>', body).replace('</table>', '</table></div>')

for out_name, src_name, nav_title, lede in PAGES:
    src = ROOT / src_name if src_name == "README.md" else ROOT / "docs" / src_name
    raw = src.read_text(encoding="utf-8")

    if out_name == "index.html":
        # hero + the README body minus its own centre-aligned header block
        m = re.search(r'(<h1.*?</h1>)', raw, re.S)
        body = md_to_html(raw)
        body = re.sub(r'<div align="center">.*?</div>\s*', '', body, flags=re.S)
        hero = (f'<div class="hero"><span class="eyebrow">Open source · AGPL-3.0 · Free GPU</span>'
                f'<h1>Run the ElevenLabs alternative on a free GPU</h1>'
                f'<p class="lede">VoiceStudio’s full voice studio — cloning, dubbing, text-to-speech '
                f'and transcription — running on a free Google Colab T4. Your computer only draws the interface.</p>'
                f'<div class="cta"><a class="btn btn-p" href="{REPO}" target="_blank" rel="noopener">View on GitHub</a>'
                f'<a class="btn btn-s" href="install.html">Get started</a></div></div>')
        body = hero + body
    else:
        body = (f'<div class="hero" style="margin-bottom:38px"><h1>{html.escape(nav_title)}</h1>'
                f'<p class="lede">{html.escape(lede)}</p></div>') + md_to_html(raw)

    body = wrap_tables(body)
    links = "".join(f'<a href="{h}" class="{"on" if h==out_name else ""}">{l}</a>' for h,l in NAV)
    desc = html.escape(lede)
    full_title = nav_title if nav_title.startswith("VoiceStudio") else f"{nav_title} · VoiceStudio on Colab"
    doc = f"""<!doctype html><html lang="en"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>{html.escape(full_title)}</title>
<meta name="description" content="{desc}">
<meta property="og:type" content="website"><meta property="og:title" content="{html.escape(full_title)}">
<meta property="og:description" content="{desc}"><meta property="og:image" content="{SITE}/assets/social-preview.png">
<link rel="canonical" href="{SITE}/{out_name}">
<style>{CSS}</style></head><body>
<nav class="nav"><div class="nav-in">
<a class="brand" href="index.html"><img src="assets/voicestudio.png" alt="">VoiceStudio on Colab</a>
<div class="nav-links">{links}</div>
<button id="tt" style="border:1px solid var(--hair-soft);background:var(--hair-soft);color:var(--muted);
  border-radius:8px;font:inherit;font-size:12.5px;padding:4px 10px;cursor:pointer;margin-left:8px">Dark</button>
</div></nav>
<main>{body}
<footer>A third-party community setup for the AGPL-3.0
<a href="https://github.com/debpalash/VoiceStudio" target="_blank" rel="noopener">VoiceStudio</a> app by debpalash.
Not affiliated with that project. Runs on Google Colab and a Cloudflare tunnel.</footer>
</main><script>{JS}</script></body></html>"""
    (OUT / out_name).write_text(doc, encoding="utf-8")
    print("built", out_name)

shutil.copytree(ROOT / "assets", OUT / "assets", dirs_exist_ok=True)
(OUT / "robots.txt").write_text("User-agent: *\nAllow: /\n", encoding="utf-8")
(OUT / "sitemap.xml").write_text(
  '<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'
  + "".join(f'<url><loc>{SITE}/{n}</loc></url>\n' for n,_,_,_ in PAGES) + '</urlset>\n', encoding="utf-8")
print("assets + robots + sitemap ->", OUT)
