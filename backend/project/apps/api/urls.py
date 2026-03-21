from django.urls import include, path
from drf_spectacular.views import SpectacularAPIView, SpectacularRedocView, SpectacularSwaggerView
from rest_framework.permissions import AllowAny

urlpatterns = [
    path("auth/", include("project.apps.accounts.urls")),
    path("staff/", include("project.apps.accounts.staff_urls")),
    path("files/", include("project.apps.files.urls")),
    path("kyc/", include("project.apps.kyc.urls")),
    path("staff/kyc/", include("project.apps.kyc.staff_urls")),
    path("wallets/", include("project.apps.wallets.urls")),
    path("agents/", include("project.apps.agents.urls")),
    path("staff/agents/", include("project.apps.agents.staff_urls")),
    # API Documentation
    path(
        "schema/",
        SpectacularAPIView.as_view(authentication_classes=[], permission_classes=[AllowAny]),
        name="schema",
    ),
    path("docs/", SpectacularSwaggerView.as_view(url_name="schema"), name="swagger-ui"),
    path("redoc/", SpectacularRedocView.as_view(url_name="schema"), name="redoc"),
]
