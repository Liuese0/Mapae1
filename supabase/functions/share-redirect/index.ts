import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

serve(async (req) => {
  const url = new URL(req.url);
  const token = url.searchParams.get("token");

  if (!token) {
    return new Response("Missing token", { status: 400 });
  }

  const deepLink = `com.namecard.app://share/${token}`;

  const html = `<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Mapae</title>
  <script>
    window.location.href = "${deepLink}";
    setTimeout(function() {
      document.getElementById("fallback").style.display = "block";
    }, 2000);
  </script>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
      text-align: center;
      padding: 60px 24px;
      background: #fafafa;
      color: #1a1a1a;
    }
    .logo { font-size: 48px; margin-bottom: 16px; }
    h1 { font-size: 22px; font-weight: 700; margin-bottom: 8px; }
    .subtitle { color: #888; font-size: 15px; margin-bottom: 32px; }
    .spinner {
      width: 32px; height: 32px;
      border: 3px solid #e0e0e0;
      border-top-color: #1a1a1a;
      border-radius: 50%;
      animation: spin 0.8s linear infinite;
      margin: 0 auto 32px;
    }
    @keyframes spin { to { transform: rotate(360deg); } }
    .hidden { display: none; }
    .fallback-text { color: #666; font-size: 14px; line-height: 1.6; margin-bottom: 20px; }
    .btn {
      display: inline-block;
      padding: 14px 32px;
      background: #1a1a1a;
      color: #fff;
      border-radius: 12px;
      text-decoration: none;
      font-size: 15px;
      font-weight: 600;
    }
  </style>
</head>
<body>
  <div class="logo">&#x1F4C7;</div>
  <h1>Mapae</h1>
  <p class="subtitle">&#xC571;&#xC73C;&#xB85C; &#xC774;&#xB3D9; &#xC911;...</p>
  <div class="spinner"></div>
  <div id="fallback" class="hidden">
    <p class="fallback-text">
      &#xC571;&#xC774; &#xC5F4;&#xB9AC;&#xC9C0; &#xC54A;&#xC558;&#xB098;&#xC694;?<br>
      Mapae &#xC571;&#xC744; &#xC124;&#xCE58;&#xD55C; &#xD6C4; &#xB2E4;&#xC2DC; &#xC2DC;&#xB3C4;&#xD574; &#xC8FC;&#xC138;&#xC694;.
    </p>
    <a class="btn" href="${deepLink}">&#xC571;&#xC5D0;&#xC11C; &#xC5F4;&#xAE30;</a>
  </div>
</body>
</html>`;

  const body = new TextEncoder().encode(html);

  return new Response(body, {
    headers: {
      "Content-Type": "text/html; charset=utf-8",
      "Access-Control-Allow-Origin": "*",
    },
  });
});