import pytest
from django.core.files.storage import FileSystemStorage
from django.core.files.uploadedfile import SimpleUploadedFile

from project.apps.files.models import FileAsset
from project.apps.files.services import create_file_asset
from project.apps.kyc.models import KycSubmission
from project.apps.kyc.services import submit_kyc

# Minimal valid 1×1 PNG — no Pillow required
_TINY_PNG = (
    b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01"
    b"\x08\x02\x00\x00\x00\x90wS\xde\x00\x00\x00\x0cIDATx\x9cc\xf8\x0f\x00"
    b"\x00\x01\x01\x00\x05\x18\xd8N\x00\x00\x00\x00IEND\xaeB`\x82"
)


@pytest.fixture
def media_root(settings, tmp_path):
    settings.MEDIA_ROOT = tmp_path
    storage = FileSystemStorage(location=tmp_path, base_url=settings.MEDIA_URL)
    field = FileAsset._meta.get_field("file")
    original_storage = field.storage
    field.storage = storage
    try:
        yield tmp_path
    finally:
        field.storage = original_storage


def make_image(name="test.png") -> SimpleUploadedFile:
    return SimpleUploadedFile(name, _TINY_PNG, content_type="image/png")


def make_submission_asset_ids(user):
    """Create four READY FileAsset records and return their IDs as kwargs for submit_kyc."""

    def _asset(name, kind):
        return create_file_asset(
            owner=user,
            uploaded_by=user,
            uploaded_file=make_image(name),
            kind=kind,
            visibility=FileAsset.Visibility.PRIVATE,
        )

    return {
        "id_front_id": str(_asset("front.jpg", FileAsset.FileKind.PASSPORT).id),
        "id_back_id": str(_asset("back.jpg", FileAsset.FileKind.PASSPORT).id),
        "selfie_id": str(_asset("selfie.jpg", FileAsset.FileKind.SELFIE).id),
        "proof_of_address_id": str(_asset("proof.jpg", FileAsset.FileKind.DOCUMENT).id),
    }


@pytest.fixture
def kyc_submission_factory(media_root):
    def _make(user, id_type=KycSubmission.IdType.NATIONAL_ID):
        return submit_kyc(user=user, id_type=id_type, **make_submission_asset_ids(user))

    return _make


@pytest.fixture
def kyc_user(user_factory):
    return user_factory(
        email="kyc-user@example.com",
        username="kyc-user",
        first_name="Kwame",
        last_name="Mensah",
    )


@pytest.fixture
def kyc_client(auth_client_factory, kyc_user):
    return auth_client_factory(
        {
            "sub": str(kyc_user.supabase_user_id),
            "email": kyc_user.email,
            "user_metadata": {
                "first_name": kyc_user.first_name,
                "last_name": kyc_user.last_name,
            },
        }
    )


@pytest.fixture
def staff_client(api_client, user_factory):
    staff = user_factory(
        email="kyc-admin@example.com",
        username="kyc-admin",
        password="adminpass123",
        is_staff=True,
        is_superuser=True,
        supabase_user_id=None,
    )
    resp = api_client.post(
        "/api/auth/staff/login/",
        {"email": staff.email, "password": "adminpass123"},
        format="json",
    )
    api_client.credentials(HTTP_AUTHORIZATION=f"Bearer {resp.data['access']}")
    return api_client, staff
