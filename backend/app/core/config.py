from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    app_name: str = "GlowAi"
    app_env: str = "dev"
    cors_origins: str = "*"

    llm_provider: str = "rule_based"
    llm_api_key: str = ""
    llm_base_url: str = "https://api.openai.com/v1"
    llm_model: str = "gpt-4o-mini"
    llm_timeout_seconds: float = 60.0
    llm_allow_rule_based_fallback: bool = True

    google_maps_api_key: str = ""

    database_url: str = "sqlite:////data/glowai.db"
    jwt_secret: str = "dev-change-me-glowai-jwt"
    jwt_expire_hours: int = 24 * 14
    chat_max_messages_per_day: int = 40

    smtp_host: str = ""
    smtp_port: int = 587
    smtp_user: str = ""
    smtp_password: str = ""
    smtp_from: str = ""
    smtp_use_tls: bool = True
    require_smtp_in_prod: bool = True
    remind_poll_seconds: int = 60
    remind_worker_enabled: bool = True

    @property
    def is_prod(self) -> bool:
        return self.app_env.strip().lower() == "prod"

    @property
    def expose_dev_codes(self) -> bool:
        """Show codes in API only when not prod and SMTP is off (local pilot)."""
        from app.services.mailer import smtp_configured

        return (not self.is_prod) and (not smtp_configured())


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
