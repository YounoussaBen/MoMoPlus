from __future__ import annotations

from django.core.files.base import ContentFile
from django.core.files.storage import Storage

from project.integrations.supabase import SupabaseStorageClient


class SupabaseStorage(Storage):
    """Django storage backend backed by Supabase Storage."""

    def __init__(self, **kwargs) -> None:
        self.client = SupabaseStorageClient(**kwargs)

    def _open(self, name: str, mode: str = "rb") -> ContentFile:
        if mode != "rb":
            raise ValueError("SupabaseStorage only supports binary reads.")
        return ContentFile(self.client.download(name), name=name)

    def _save(self, name: str, content) -> str:
        content.open("rb")
        self.client.upload(name, content.read(), content_type=getattr(content, "content_type", None))
        return name

    def delete(self, name: str) -> None:
        self.client.delete(name)

    def exists(self, name: str) -> bool:
        return self.client.exists(name)

    def size(self, name: str) -> int:
        return self.client.size(name) or 0

    def url(self, name: str) -> str:
        return self.client.url(name)
