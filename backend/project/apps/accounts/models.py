from django.contrib.auth.models import AbstractUser
from django.db import models

from project.apps.core.models import BaseModel


class User(AbstractUser, BaseModel):
    supabase_user_id: models.UUIDField = models.UUIDField(unique=True, null=True, blank=True)
    email: models.EmailField = models.EmailField(unique=True)
    first_name: models.CharField = models.CharField(max_length=150)
    last_name: models.CharField = models.CharField(max_length=150)

    USERNAME_FIELD = "email"
    REQUIRED_FIELDS = ["username", "first_name", "last_name"]

    def __str__(self) -> str:
        return self.email
