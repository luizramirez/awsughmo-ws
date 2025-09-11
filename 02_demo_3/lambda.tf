# --- IAM para Lambda ---
data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_role" {
  name               = "${var.project_name}-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
  tags               = local.tags
}

# Permisos mínimos: logs + invocar modelos en Bedrock
data "aws_iam_policy_document" "lambda_policy" {
  statement {
    sid       = "CloudWatchLogs"
    actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["*"]
  }

  statement {
    sid       = "BedrockInvoke"
    actions   = ["bedrock:InvokeModel", "bedrock:InvokeModelWithResponseStream"]
    resources = ["*"] # En prod: usa ARN específico del modelo
  }
}


resource "aws_iam_role_policy" "lambda_inline" {
  name   = "${var.project_name}-policy"
  role   = aws_iam_role.lambda_role.id
  policy = data.aws_iam_policy_document.lambda_policy.json
}

# --- Código de Lambda: se genera localmente y se empaqueta ---
resource "local_file" "lambda_main" {
  filename = "${path.module}/lambda/main.py"
  content  = <<PY
# lambda/main.py
import json
import os
import base64
import boto3

# Variables de entorno esperadas (puedes setearlas desde Terraform)
MODEL_ID        = os.getenv("MODEL_ID", "anthropic.claude-3-5-sonnet-20240620-v1:0")
VISION_MODEL_ID = os.getenv("VISION_MODEL_ID", MODEL_ID)
MAX_TOKENS      = int(os.getenv("MAX_TOKENS", "400"))
TEMPERATURE     = float(os.getenv("TEMPERATURE", "0.2"))

bedrock = boto3.client("bedrock-runtime")


# ---------- Utilidades ----------
def _cors_json(status: int, body_obj: dict, origin: str = "*") -> dict:
    """Respuesta JSON con CORS para API Gateway HTTP API (payload v2)."""
    return {
        "statusCode": status,
        "headers": {
            "content-type": "application/json",
            "access-control-allow-origin": origin,
            "access-control-allow-headers": "content-type",
            "access-control-allow-methods": "POST,OPTIONS",
        },
        "body": json.dumps(body_obj, ensure_ascii=False),
    }


def _parse_body(event: dict) -> dict:
    """Lee el cuerpo del evento (v2), soporta base64-encoded."""
    body = event.get("body") or "{}"
    if event.get("isBase64Encoded"):
        body = base64.b64decode(body).decode("utf-8")
    try:
        return json.loads(body)
    except Exception:
        return {}


def _get_request_info(event: dict):
    http = event.get("requestContext", {}).get("http", {})
    method = http.get("method")
    path = http.get("path", "/")
    hdrs = event.get("headers") or {}
    origin = hdrs.get("origin") or hdrs.get("Origin") or "*"
    return method, path, origin


# ---------- Handler principal ----------
def handler(event, context):
    # Log mínimo de diagnóstico
    print({
        "region": os.getenv("AWS_REGION"),
        "model_id": MODEL_ID,
        "vision_model_id": VISION_MODEL_ID,
    })

    method, path, origin = _get_request_info(event)

    # Responder preflight CORS
    if method == "OPTIONS":
        return _cors_json(200, {"ok": True}, origin)

    try:
        # ------------------------------------------------------------
        # POST /analyze  -> recibe { imageBase64, mediaType? }
        # ------------------------------------------------------------
        if method == "POST" and path.endswith("/analyze"):
            payload = _parse_body(event)
            img_b64 = payload.get("imageBase64")
            media_type = payload.get("mediaType") or "image/jpeg"

            if not img_b64:
                return _cors_json(400, {"error": "imageBase64 is required"}, origin)

            # Si recibimos data URL, separar encabezado
            # ej: data:image/jpeg;base64,/9j/4AAQSkZJRgABA...
            if isinstance(img_b64, str) and img_b64.startswith("data:"):
                try:
                    header, data = img_b64.split(",", 1)
                    img_b64 = data
                    if "image/" in header and ";base64" in header:
                        # extrae p.ej. "image/jpeg"
                        media_type = header.split("data:")[1].split(";")[0]
                except Exception:
                    pass

            # Validación rápida del base64
            try:
                # Solo para validar que sea base64 válido (no usamos el resultado)
                _ = base64.b64decode(img_b64, validate=True)
            except Exception:
                return _cors_json(400, {"error": "imageBase64 is not valid base64"}, origin)

            # Prompt para pedir salida estrictamente JSON
            user_prompt = (
                "Quiero que actúes como juez gastronómico especializado en comida del norte de México. Vas a evaluar la siguiente foto de comida y dar una puntuación del 1 al 10 tomando en cuenta los siguientes criterios:"
                "Apetitosidad: qué tanto provoca hambre o antojo al verla. "
                "Detalles adicionales: si hay guarniciones, salsitas "
                "Justificación breve y coloquial usando regionalismos del norte de México (ejemplos: se ve bien machín, ese plato sí está pa la carnita asada con los plebes, la neta sí se antoja con una coquita helada, le falta punch, quedó medio aguado). "
                "Tono directo, amistoso y con un toque crítico como si fueras juez en un concurso de comida. "
                "Responde SOLO en JSON con estos campos:\n"
                "{ \"score\": <0-100>, \"feedback\": \"texto breve y útil\" }"
            )

            # Payload para Claude 3.x en Bedrock (imagen con tag 'image')
            body = {
                "anthropic_version": "bedrock-2023-05-31",
                "max_tokens": 300,
                "temperature": 0.2,
                "messages": [
                    {
                        "role": "user",
                        "content": [
                            {"type": "text", "text": user_prompt},
                            {
                                "type": "image",
                                "source": {
                                    "type": "base64",
                                    "media_type": media_type,  # p.ej. "image/jpeg" o "image/png"
                                    "data": img_b64,           # SOLO base64, sin prefijo data:
                                },
                            },
                        ],
                    }
                ],
            }

            # (opcional) log de depuración sin el base64 completo
            print({
                "debug_analyze": {
                    "media_type": media_type,
                    "payload_keys": list(body.keys()),
                    "message_content_types": [c.get("type") for c in body["messages"][0]["content"]],
                }
            })

            resp = bedrock.invoke_model(
                modelId=VISION_MODEL_ID,
                contentType="application/json",
                accept="application/json",
                body=json.dumps(body).encode("utf-8"),
            )

            raw = resp["body"].read().decode("utf-8")
            data = json.loads(raw)

            # Claude 3.x devuelve bloques en data["content"] (lista de objetos con type=text/image/etc.)
            text_out = "".join(c.get("text", "") for c in data.get("content", []) if c.get("type") == "text").strip()

            # Intentar parsear JSON; si no, devolver texto como feedback
            result = {"score": None, "feedback": text_out or "(sin texto)"}
            try:
                parsed = json.loads(text_out)
                if isinstance(parsed, dict):
                    result.update(parsed)
            except Exception:
                pass

            return _cors_json(200, result, origin)

        # ------------------------------------------------------------
        # (Opcional) POST /chat  -> { question }
        # ------------------------------------------------------------
        if method == "POST" and path.endswith("/chat"):
            payload = _parse_body(event)
            question = payload.get("question") or "Explica brevemente qué es Terraform y para qué sirve."

            body = {
                "anthropic_version": "bedrock-2023-05-31",
                "max_tokens": MAX_TOKENS,
                "temperature": TEMPERATURE,
                "messages": [
                    {"role": "user", "content": [{"type": "text", "text": question}]}
                ],
            }

            resp = bedrock.invoke_model(
                modelId=MODEL_ID,
                contentType="application/json",
                accept="application/json",
                body=json.dumps(body).encode("utf-8"),
            )

            raw = resp["body"].read().decode("utf-8")
            data = json.loads(raw)
            answer = next((c.get("text") for c in data.get("content", []) if c.get("type") == "text"), None)

            return _cors_json(200, {"answer": answer or raw}, origin)

        # Rutas no encontradas
        return _cors_json(404, {"error": "Not Found"}, origin)

    except Exception as e:
        # Log y respuesta 500
        print({"error": str(e)})
        return _cors_json(500, {"error": str(e)}, origin)
PY
}
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/lambda.zip"

  depends_on = [local_file.lambda_main]
}

resource "aws_lambda_function" "chatbot" {
  function_name = local.lambda_name
  role          = aws_iam_role.lambda_role.arn
  filename      = data.archive_file.lambda_zip.output_path
  handler       = "main.handler"
  runtime       = "python3.12"
  timeout       = 15
  memory_size   = 256
  architectures = ["arm64"]
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  publish = true


  environment {
    variables = {
      MODEL_ID        = var.bedrock_model_id
      MAX_TOKENS      = tostring(var.max_tokens)
      TEMPERATURE     = tostring(var.temperature)
      VISION_MODEL_ID = var.vision_model_id
    }
  }
  tags = local.tags
}

# Congela el código actual en una version inmutable

# Alias estable que usará API Gateway
resource "aws_lambda_alias" "live" {
  name             = "live"
  function_name    = aws_lambda_function.chatbot.function_name
  function_version = aws_lambda_function.chatbot.version
  description      = "Alias 'live' pointing to version ${aws_lambda_function.chatbot.version}"
}
