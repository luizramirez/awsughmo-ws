locals {
  lambda_name = "${var.project_name}-lambda"
  tags = {
    Project = var.project_name
    Stack   = "workshop"
  }
}

# --- Random sufijo para nombre global de bucket ---
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# --- Bucket para website estático ---
resource "aws_s3_bucket" "site" {
  bucket = "dogo.zahuaro.com.mx"
  #bucket = "${var.project_name}-site-${random_string.suffix.result}"
  tags   = local.tags
}

# Propiedad del bucket y controles públicos (habilitar website público sólo para el workshop)
resource "aws_s3_bucket_ownership_controls" "site" {
  bucket = aws_s3_bucket.site.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# Configuración de sitio web
resource "aws_s3_bucket_website_configuration" "site" {
  bucket = aws_s3_bucket.site.id
  index_document {
    suffix = "index.html"
  }
}

# Política para permitir lectura pública del contenido del bucket (sólo demo/workshop)
data "aws_iam_policy_document" "public_read" {
  statement {
    sid     = "AllowPublicRead"
    effect  = "Allow"
    actions = ["s3:GetObject"]
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    resources = ["${aws_s3_bucket.site.arn}/*"]
  }
}

resource "aws_s3_bucket_public_access_block" "site" {
  bucket                  = aws_s3_bucket.site.id
  block_public_acls       = false
  block_public_policy     = false # 👈 permitir policy pública
  restrict_public_buckets = false
  ignore_public_acls      = false
}


resource "aws_s3_bucket_policy" "public_read" {
  bucket     = aws_s3_bucket.site.id
  policy     = data.aws_iam_policy_document.public_read.json
  depends_on = [aws_s3_bucket_public_access_block.site] # 👈 asegura orden
}

# --- index.html generado dinámicamente con la URL del API /chat ---
# Usamos el API endpoint ya creado en la opción 1
resource "aws_s3_object" "index_html" {
  bucket       = aws_s3_bucket.site.id
  key          = "index.html"
  content_type = "text/html; charset=utf-8"

  # Inyectamos la URL del API Gateway HTTP API + /chat
  content = <<-HTML
  <!doctype html>
<html lang="es">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Dogo Grader — Terraform + Bedrock</title>
  <style>
    :root{
      --bg: #f2f3f3;
      --panel: #fff;
      --border: #d5dbdb;
      --text: #16191f;
      --muted: #5f6b7a;
      --brand: #0972d3;      /* azul estilo AWS/Cloudscape */
      --brand-700:#075ca9;
      --focus: #0972d3;
      --danger:#B4232A;
      --ok:#1f6f43;
      --warn:#946200;
      --shadow: 0 1px 2px rgba(0,0,0,.06), 0 4px 10px rgba(0,0,0,.04);
      --radius: 10px;
    }
    *{box-sizing:border-box}
    html,body{height:100%}
    body{
      margin:0; background:var(--bg); color:var(--text); font:14px/1.4 system-ui,-apple-system,Segoe UI,Roboto,Arial,sans-serif;
    }
    /* Header estilo AWS */
    .aws-header{
      background:#232f3e; color:#fff; display:flex; align-items:center; gap:12px; padding:10px 16px;
    }
    .aws-logo{
      display:inline-flex; align-items:center; gap:8px; font-weight:700; letter-spacing:.2px;
    }
    .pill{background:#00a1c9;color:#00131a;font-weight:700;border-radius:6px;padding:2px 6px;font-size:12px}
    .subtle{color:#cbd5e1;font-weight:500}
    .container{max-width:1100px;margin:24px auto;padding:0 16px}
    .breadcrumbs{color:var(--muted);font-size:12px;margin-bottom:8px}
    .page-title{display:flex;align-items:center;gap:10px;margin:6px 0 14px}
    h1{font-size:20px; margin:0}
    .cards{display:grid;grid-template-columns:1.1fr .9fr;gap:16px}
    @media (max-width:900px){.cards{grid-template-columns:1fr}}
    .card{
      background:var(--panel); border:1px solid var(--border); border-radius:var(--radius);
      box-shadow:var(--shadow); padding:16px;
    }
    .card h2{font-size:16px; margin:0 0 8px}
    .field{margin:12px 0}
    .label{display:block; font-weight:600; margin-bottom:6px}
    .help{color:var(--muted); font-size:12px}
    input[type="file"], .input{
      width:100%; padding:10px 12px; border:1px solid var(--border); border-radius:8px; background:#fff;
    }
    .btn{
      display:inline-flex; align-items:center; gap:8px;
      background:var(--brand); color:#fff; border:1px solid var(--brand);
      padding:10px 14px; border-radius:8px; cursor:pointer; font-weight:600;
      transition:.15s transform ease, .15s background ease; box-shadow:0 1px 0 rgba(0,0,0,.04);
    }
    .btn:hover{background:var(--brand-700)}
    .btn:disabled{opacity:.55; cursor:not-allowed}
    .btn:focus-visible{outline:3px solid #fff; box-shadow:0 0 0 3px var(--focus), 0 1px 0 rgba(0,0,0,.04)}
    .btn-secondary{
      background:#fff; color:var(--text); border:1px solid var(--border)
    }
    .row{display:flex; gap:8px; flex-wrap:wrap}
    .preview{
      display:block; width:100%; max-height:340px; object-fit:contain;
      border:1px dashed var(--border); border-radius:8px; background:#fafafa;
    }
    .status{color:var(--muted); font-size:12px; margin-left:8px}
    .result{
      display:grid; grid-template-columns:1fr; gap:10px;
    }
    .badge{
      display:inline-block; padding:2px 8px; border-radius:999px; font-weight:700; font-size:12px; border:1px solid var(--border);
    }
    .badge.ok{background:#eaf6ef; color:var(--ok); border-color:#b8dfc6}
    .badge.warn{background:#fff5e5; color:var(--warn); border-color:#f6cf7a}
    .badge.danger{background:#fdecec; color:var(--danger); border-color:#f3b4b7}
    pre{
      background:#fafafa; border:1px solid var(--border); padding:12px; border-radius:8px; max-height:260px; overflow:auto; margin:0;
    }
    .alert{
      display:none; margin:0 0 12px; padding:10px 12px; border-radius:8px; border:1px solid #f0c2c4;
      background:#fdecec; color:#7a1d20; font-weight:600;
    }
    .alert.show{display:block}
    .spinner{
      --s:14px; width:var(--s); height:var(--s); border-radius:50%; border:3px solid #c9d3dc; border-top-color:#1e2a32; animation:spin 1s linear infinite;
    }
    @keyframes spin{to{transform:rotate(360deg)}}
    footer{color:var(--muted); font-size:12px; text-align:center; padding:24px 0}
    .toolbar{display:flex; align-items:center; gap:8px; justify-content:space-between; margin-bottom:12px}
    .ghost{opacity:.65}
  </style>
</head>
<body>
  <!-- Header estilo AWS -->
  <header class="aws-header">
    <div class="aws-logo">🍽️ Dogo Gradder <span class="pill">Beta</span></div>
    <div class="subtle">Terraform + Bedrock</div>
  </header>

  <main class="container">
    <nav class="breadcrumbs">Bedrock / Demos / Food Score</nav>
    <div class="toolbar">
      <div class="page-title">
        <h1>Dogo Grader</h1>
        <span class="status" id="envInfo"></span>
      </div>
      <div class="row">
        <button class="btn btn-secondary" id="resetBtn">Reiniciar</button>
      </div>
    </div>

    <div id="errorBanner" class="alert"></div>

    <section class="cards">
      <!-- Panel izquierdo: carga y acciones -->
      <article class="card">
        <h2>Imagen</h2>
        <div class="field">
          <label for="file" class="label">Selecciona una imagen</label>
          <input id="file" type="file" accept="image/*" />
          <div class="help">Formatos: JPG o PNG. La imagen se procesa en el navegador (redimensionada) y se envía al backend.</div>
        </div>

        <div class="field">
          <img id="preview" class="preview" alt="Vista previa" />
        </div>

        <div class="row">
          <button id="analyzeBtn" class="btn">
            <span class="spinner ghost" id="spin" style="display:none"></span>
            Analizar con Bedrock
          </button>
          <span class="status" id="status"></span>
        </div>
      </article>

      <!-- Panel derecho: resultados -->
      <article class="card">
        <h2>Resultado</h2>
        <div class="result">
          <div>
            <div class="label">Puntuación</div>
            <div id="scoreBox" class="badge">—</div>
          </div>
          <div>
            <div class="label">Feedback</div>
            <pre id="feedback">—</pre>
          </div>
        </div>
      </article>
    </section>

    <footer>© 2025 Demo. Inspirado en AWS Console (Cloudscape).</footer>
  </main>

  <script>
    const API_BASE = "${aws_apigatewayv2_api.http_api.api_endpoint}";
    const el = (id)=>document.getElementById(id);
    const fileInput = el('file');
    const preview   = el('preview');
    const analyzeBtn= el('analyzeBtn');
    const resetBtn  = el('resetBtn');
    const statusEl  = el('status');
    const spin      = el('spin');
    const scoreBox  = el('scoreBox');
    const feedback  = el('feedback');
    const errorBanner = el('errorBanner');
    const envInfo   = el('envInfo');

    envInfo.textContent = API_BASE === "REEMPLAZA_CON_TU_API_BASE" ? "(API no configurada)" : "";

    function setBusy(b){
      analyzeBtn.disabled = b;
      spin.style.display = b ? "inline-block":"none";
    }
    function setError(msg){
      errorBanner.textContent = msg || "";
      errorBanner.classList.toggle("show", !!msg);
    }
    function resetUI(){
      setError("");
      statusEl.textContent = "";
      preview.src = "";
      scoreBox.textContent = "—";
      scoreBox.className = "badge";
      feedback.textContent = "—";
      fileInput.value = "";
    }
    resetBtn.addEventListener('click', resetUI);

    // Redimensiona en cliente y produce Data URL JPEG
    function fileToDataURL(file, maxSize=1280){
      return new Promise((resolve, reject)=>{
        const reader = new FileReader();
        reader.onerror = ()=>reject(new Error("No se pudo leer la imagen"));
        reader.onload = ()=>{
          const img = new Image();
          img.onload = ()=>{
            let {width:w, height:h} = img;
            const m = Math.max(w,h);
            if (m > maxSize){
              const s = maxSize / m; w = Math.round(w*s); h = Math.round(h*s);
            }
            const canvas = document.createElement('canvas');
            canvas.width = w; canvas.height = h;
            const ctx = canvas.getContext('2d');
            ctx.drawImage(img, 0, 0, w, h);
            const dataUrl = canvas.toDataURL('image/jpeg', 0.9);
            resolve({ dataUrl, mediaType: 'image/jpeg' });
          };
          img.onerror = ()=>reject(new Error("No se pudo cargar la imagen"));
          img.src = reader.result;
        };
        reader.readAsDataURL(file);
      });
    }

    async function analyze(){
      try{
        setError("");
        if (API_BASE === "REEMPLAZA_CON_TU_API_BASE"){
          setError("Configura API_BASE con tu endpoint de API Gateway.");
          return;
        }
        const file = fileInput.files && fileInput.files[0];
        if (!file){ setError("Selecciona una imagen."); return; }

        preview.src = URL.createObjectURL(file);
        setBusy(true);
        statusEl.textContent = "Preparando imagen…";

        const { dataUrl, mediaType } = await fileToDataURL(file, 1280);

        statusEl.textContent = "Analizando…";
        const res = await fetch(API_BASE + "/analyze", {
          method: "POST",
          headers: { "content-type": "application/json" },
          body: JSON.stringify({ imageBase64: dataUrl, mediaType })
        });

        let data = {};
        try { data = await res.json(); } catch {}
        if (!res.ok) throw new Error(data.error || ("Error HTTP " + res.status));

        // pintar resultados
        const score = typeof data.score === "number" ? data.score : null;
        scoreBox.textContent = score ?? "N/A";
        scoreBox.className = "badge " + (
          score == null ? "" :
          score >= 70 ? "ok" :
          score >= 40 ? "warn" : "danger"
        );
        feedback.textContent = data.feedback || "(sin feedback)";
        statusEl.textContent = "Listo ✔";
      }catch(err){
        console.error(err);
        setError(err.message || "Error desconocido");
        statusEl.textContent = "Error ✖";
      }finally{
        setBusy(false);
      }
    }

    analyzeBtn.addEventListener('click', analyze);
  </script>
</body>
</html>
HTML

  depends_on = [
    aws_apigatewayv2_stage.default,
    aws_apigatewayv2_route.chat_route,
    aws_apigatewayv2_route.analyze_route
  ]
}

# Salida del website estático (endpoint estilo http://bucket.s3-website-REGION.amazonaws.com)
# Nota: No requiere CloudFront para este workshop.


resource "random_string" "img_suffix" {
  length  = 6
  special = false
  upper   = false
}

