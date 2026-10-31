from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    app_name: str = "SheMove Backend"
    app_env: str = "development"
    secret_key: str = "shemove-hackathon-secret-change-me"
    access_token_expire_minutes: int = 1440
    mongodb_uri: str = "mongodb://localhost:27017"
    mongodb_db: str = "shemove"
    cors_origins: str = "*"
    heartbeat_timeout_s: int = 90
    monitor_interval_s: int = 5
    demo_open_police: bool = True
    seed_on_start: bool = True
    twilio_account_sid: str = ""
    twilio_auth_token: str = ""
    twilio_from_number: str = ""
    twilio_whatsapp_from_number: str = "+14155238886"
    twilio_enabled: bool = False
    twilio_whatsapp_enabled: bool = True
    public_track_base_url: str = "http://localhost:8000/api/v1/public/track"

    @property
    def cors_origin_list(self) -> list[str]:
        if self.cors_origins.strip() == "*":
            return ["*"]
        return [item.strip() for item in self.cors_origins.split(",") if item.strip()]


@lru_cache
def get_settings() -> Settings:
    return Settings()
