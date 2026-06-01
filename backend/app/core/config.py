from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    app_name: str = "CVBoosta API"
    app_env: str = "dev"
    database_url: str = "postgresql+psycopg://cvboosta:cvboosta@localhost:5432/cvboosta"
    gemini_api_key: str = ""
    gemini_model_fast: str = "gemini-2.5-flash"
    gemini_model_pro: str = "gemini-2.5-pro"
    gemini_timeout_seconds: float = 10.0
    gemini_max_retries: int = 2
    gemini_requests_per_minute: int = 120
    revenuecat_webhook_secret: str = ""


settings = Settings()
