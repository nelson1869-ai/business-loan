"""FastAPI contract tests for authenticated loan routes."""

import unittest

from app.main import app


class LoanApiContractTests(unittest.TestCase):
    """Verify the loan API appears in the generated OpenAPI contract."""

    @classmethod
    def setUpClass(cls) -> None:
        cls.paths = app.openapi()["paths"]

    def test_collection_supports_authenticated_create_and_list(self) -> None:
        operations = self.paths["/api/v1/loans"]

        self.assertIn("post", operations)
        self.assertIn("get", operations)
        self.assertTrue(operations["post"]["security"])
        self.assertEqual(
            operations["post"]["responses"]["201"]["description"], "Successful Response"
        )

    def test_detail_route_returns_the_installment_response_contract(self) -> None:
        operation = self.paths["/api/v1/loans/{loan_id}"]["get"]
        response_schema = operation["responses"]["200"]["content"]["application/json"][
            "schema"
        ]

        self.assertEqual(
            response_schema["$ref"],
            "#/components/schemas/LoanDetailResponse",
        )
        self.assertTrue(operation["security"])

    def test_quote_is_authenticated_and_non_persistent_contract(self) -> None:
        operation = self.paths["/api/v1/loans/quote"]["post"]

        self.assertTrue(operation["security"])
        self.assertEqual(
            operation["responses"]["200"]["content"]["application/json"]["schema"][
                "$ref"
            ],
            "#/components/schemas/LoanQuoteResponse",
        )


if __name__ == "__main__":
    unittest.main()
