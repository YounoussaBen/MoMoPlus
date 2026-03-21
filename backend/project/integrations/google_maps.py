from __future__ import annotations

import json
from dataclasses import dataclass
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

from django.conf import settings


class GoogleMapsError(Exception):
    """Base exception for Google Maps integration failures."""


class GoogleMapsConfigurationError(GoogleMapsError):
    """Raised when required Google Maps settings are missing."""


class GoogleMapsRequestError(GoogleMapsError):
    """Raised when the Google Maps API request fails."""


@dataclass(frozen=True)
class RoutePreview:
    distance_meters: int
    duration_seconds: int
    encoded_polyline: str


def _decode_error_message(exc: HTTPError) -> str:
    payload = exc.read().decode("utf-8", errors="ignore")
    if not payload:
        return exc.reason or "Google Maps request failed."

    try:
        data = json.loads(payload)
    except json.JSONDecodeError:
        return payload

    if isinstance(data, dict):
        error = data.get("error")
        if isinstance(error, dict):
            detail = error.get("message")
            if isinstance(detail, str) and detail:
                return detail

        detail = data.get("message") or data.get("detail") or data.get("error")
        if isinstance(detail, str) and detail:
            return detail

    return payload


def _parse_duration_seconds(raw_duration: Any) -> int:
    if isinstance(raw_duration, int | float):
        return int(round(float(raw_duration)))

    if isinstance(raw_duration, str):
        normalized = raw_duration.removesuffix("s")
        try:
            return int(round(float(normalized)))
        except ValueError as exc:
            raise GoogleMapsRequestError("Google Maps returned an invalid route duration.") from exc

    raise GoogleMapsRequestError("Google Maps returned an invalid route duration.")


def compute_driving_route_preview(
    *,
    origin_latitude: float,
    origin_longitude: float,
    destination_latitude: float,
    destination_longitude: float,
) -> RoutePreview:
    api_key = settings.GOOGLE_MAPS_SERVER_KEY
    if not api_key:
        raise GoogleMapsConfigurationError("GOOGLE_MAPS_SERVER_KEY must be configured.")

    payload = json.dumps(
        {
            "origin": {
                "location": {
                    "latLng": {
                        "latitude": origin_latitude,
                        "longitude": origin_longitude,
                    }
                }
            },
            "destination": {
                "location": {
                    "latLng": {
                        "latitude": destination_latitude,
                        "longitude": destination_longitude,
                    }
                }
            },
            "travelMode": "DRIVE",
            "routingPreference": "TRAFFIC_AWARE",
            "polylineQuality": "HIGH_QUALITY",
            "computeAlternativeRoutes": False,
            "units": "METRIC",
        }
    ).encode("utf-8")

    request = Request(
        "https://routes.googleapis.com/directions/v2:computeRoutes",
        method="POST",
        data=payload,
        headers={
            "Content-Type": "application/json",
            "Accept": "application/json",
            "X-Goog-Api-Key": api_key,
            "X-Goog-FieldMask": "routes.distanceMeters,routes.duration,routes.polyline.encodedPolyline",
        },
    )

    try:
        with urlopen(request, timeout=settings.GOOGLE_MAPS_HTTP_TIMEOUT) as response:
            response_payload = json.loads(response.read().decode("utf-8"))
    except HTTPError as exc:
        raise GoogleMapsRequestError(_decode_error_message(exc)) from exc
    except URLError as exc:
        raise GoogleMapsRequestError("Unable to reach Google Maps right now.") from exc
    except json.JSONDecodeError as exc:
        raise GoogleMapsRequestError("Google Maps returned an invalid response.") from exc

    routes = response_payload.get("routes")
    if not isinstance(routes, list) or not routes:
        raise GoogleMapsRequestError("No driving route was returned for that destination.")

    route = routes[0]
    polyline = route.get("polyline") or {}
    encoded_polyline = polyline.get("encodedPolyline")
    if not isinstance(encoded_polyline, str) or not encoded_polyline:
        raise GoogleMapsRequestError("Google Maps did not return route geometry.")

    distance_meters = route.get("distanceMeters")
    if not isinstance(distance_meters, int):
        raise GoogleMapsRequestError("Google Maps returned an invalid route distance.")

    return RoutePreview(
        distance_meters=distance_meters,
        duration_seconds=_parse_duration_seconds(route.get("duration")),
        encoded_polyline=encoded_polyline,
    )
