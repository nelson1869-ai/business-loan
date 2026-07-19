"""Command-line helper for creating the first API user."""

import argparse
import asyncio
from getpass import getpass
from uuid import uuid4

from sqlalchemy import select

from app.database import AsyncSessionFactory
from app.models.user import User
from app.services.auth_service import hash_password


async def create_user(username: str, password: str, role: str) -> None:
    """Create a user unless the username already exists."""
    async with AsyncSessionFactory() as db:
        existing = await db.scalar(select(User).where(User.username == username))
        if existing is not None:
            raise ValueError("Username already exists")
        db.add(
            User(
                id=str(uuid4()),
                username=username,
                hashed_password=hash_password(password),
                role=role,
            )
        )
        await db.commit()


def main() -> None:
    """Prompt securely for a password and create a user."""
    parser = argparse.ArgumentParser(description="Create a Lending Nelson API user")
    parser.add_argument("username")
    parser.add_argument("--role", choices=["officer", "admin"], default="officer")
    arguments = parser.parse_args()
    password = getpass("Password: ")
    confirmation = getpass("Confirm password: ")
    if password != confirmation:
        raise ValueError("Passwords do not match")
    asyncio.run(create_user(arguments.username, password, arguments.role))
    print(f"Created {arguments.role} user: {arguments.username}")


if __name__ == "__main__":
    main()
