"""Document authorization and content-validation regression tests."""

import base64
import unittest
from types import SimpleNamespace
from unittest.mock import AsyncMock

from fastapi import HTTPException

from app.features.documents import router as documents
from app.features.documents.schemas import DocumentCreate


class DocumentSecurityTests(unittest.IsolatedAsyncioTestCase):
    def test_detects_only_allowed_file_signatures(self) -> None:
        self.assertEqual(
            documents._detected_content_type(b"%PDF-1.7\n"),
            "application/pdf",
        )
        self.assertEqual(
            documents._detected_content_type(b"\xff\xd8\xff\xe0"),
            "image/jpeg",
        )
        self.assertEqual(
            documents._detected_content_type(b"\x89PNG\r\n\x1a\n"),
            "image/png",
        )
        self.assertEqual(
            documents._detected_content_type(b"RIFF\x00\x00\x00\x00WEBP"),
            "image/webp",
        )
        self.assertIsNone(documents._detected_content_type(b"<script>"))

    def test_sanitizes_cross_platform_and_header_unsafe_names(self) -> None:
        self.assertEqual(
            documents._safe_file_name('..\\private\\bad"\r\n.pdf'),
            "bad.pdf",
        )

    async def test_download_hides_document_from_unrelated_officer(self) -> None:
        stored = SimpleNamespace(
            id="doc-1",
            uploaded_by_user_id="officer-a",
            file_name="id.pdf",
            content_type="application/pdf",
            content=b"%PDF-1.7",
        )
        db = SimpleNamespace(get=AsyncMock(return_value=stored))

        with self.assertRaises(HTTPException) as raised:
            await documents.document_content(
                "doc-1",
                db,
                SimpleNamespace(id="officer-b", role="officer"),
            )

        self.assertEqual(raised.exception.status_code, 404)

    async def test_rejects_mismatched_signature(self) -> None:
        payload = DocumentCreate(
            title="Identity",
            fileName="identity.pdf",
            contentType="application/pdf",
            contentBase64=base64.b64encode(b"<html>not a pdf</html>").decode(),
        )
        db = SimpleNamespace(
            get=AsyncMock(
                side_effect=[
                    SimpleNamespace(id="borrower-1", status="Active"),
                ]
            )
        )

        with self.assertRaises(HTTPException) as raised:
            await documents._create(
                db,
                SimpleNamespace(id="officer-a", role="officer"),
                "borrower-1",
                None,
                payload,
            )

        self.assertEqual(raised.exception.status_code, 422)

    async def test_rejects_decoded_file_over_size_limit(self) -> None:
        payload = DocumentCreate(
            title="Large",
            fileName="large.pdf",
            contentType="application/pdf",
            contentBase64=base64.b64encode(
                b"%PDF-" + b"x" * documents._MAX_DOCUMENT_BYTES
            ).decode(),
        )
        db = SimpleNamespace(
            get=AsyncMock(
                return_value=SimpleNamespace(id="borrower-1", status="Active")
            )
        )

        with self.assertRaises(HTTPException) as raised:
            await documents._create(
                db,
                SimpleNamespace(id="officer-a", role="officer"),
                "borrower-1",
                None,
                payload,
            )

        self.assertEqual(raised.exception.status_code, 413)


if __name__ == "__main__":
    unittest.main()
