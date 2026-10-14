"""Application settings.

This module loads environment variables and exposes them through one shared
settings object.

The purpose is to keep configuration values in one place instead of reading
os.getenv(...) directly throughout the application.
"""

import os

from dotenv import load_dotenv

# Load variables from a local .env file into the environment.
#
# This is mainly useful during local development.
# In production, these values may instead come from Docker, Azure, GitHub
# Actions, or another environment/configuration system.
load_dotenv()


class Settings:
    """Application configuration values.

    Each class attribute reads a value from the environment.

    If the environment variable is missing, an empty string is used as the
    default value.
    """

    # Main database connection string used by the application.
    db_connection_string: str = os.getenv("DBCONNECTIONSTRINGDSA", "")

    # Optional/secondary LIS database connection string.
    lis_db_connection_string: str = os.getenv("DBCONNECTIONSTRINGSERVER29", "")

    # Comma-separated or otherwise encoded API key hashes used for API auth.
    api_key_hashes: str = os.getenv("API_KEY_HASHES", "")

    # DSA: OIDC on/off switch, because DSA runs before its Azure federation
    # exists. Defaults to on — anything but an explicit "false"/"0"/"no"/"off"
    # keeps it on, so a missing or mistyped value fails closed. While off,
    # browser requests resolve to a placeholder user; see aktiv_session in
    # app/api/dependencies.py. API keys are unaffected.
    oidc_enabled: bool = os.getenv("OIDC_ENABLED", "true").strip().lower() not in {
        "false", "0", "no", "off"
    }

    # OpenID Connect settings.
    oidc_issuer: str = os.getenv("OIDC_ISSUER", "")
    oidc_client_id: str = os.getenv("OIDC_CLIENT_ID", "")
    oidc_client_secret: str = os.getenv("OIDC_CLIENT_SECRET", "")
    oidc_redirect_uri: str = os.getenv(
        "OIDC_REDIRECT_URI", "http://localhost:8000/auth/callback"
    )
    oidc_discovery_url: str | None = os.getenv("OIDC_DISCOVERY_URL") or None
    oidc_scopes: str = os.getenv("OIDC_SCOPES", "openid")
    oidc_environment: str = os.getenv("OIDC_ENVIRONMENT", "production")
    # Where the IdP returns the browser after ending the session. Azure B2C
    # rejects a logout that omits it ("AADB2C90036: The request does not contain
    # a URI to redirect the user to post logout"), so leaving this unset turns
    # every logout into an error page. It does *not* have to be a registered
    # reply URL — B2C validates redirect_uri but not this.
    oidc_post_logout_redirect: str | None = (
        os.getenv("OIDC_POST_LOGOUT_REDIRECT") or None
    )
    # Comma-separated IdP role claim values that may write. Configurable
    # because the values are provisioned in Systemregisteret, so they can be
    # renamed there without a code change. Roles that are not listed can read.
    # `or`, not a getenv default: an env var set to "" would otherwise leave
    # the set empty and lock every user out of writing.
    edit_roles: str = os.getenv("EDIT_ROLES") or "admin,user-edit"

    # DSA: PPR_ROLES omitted — PPR's own actions are befordring domain.

    # Secret used to sign the Starlette session cookie.
    session_secret: str = os.getenv("SESSION_SECRET", "dev-only-change-in-prod")

    # DSA: ORS_API_KEY omitted — distance calculation is befordring domain.

# Shared settings instance used throughout the application.
settings = Settings()
