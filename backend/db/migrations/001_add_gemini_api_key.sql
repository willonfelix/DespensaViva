-- 001: Adiciona a API Key do Gemini por usuário
ALTER TABLE users ADD COLUMN IF NOT EXISTS gemini_api_key TEXT;
