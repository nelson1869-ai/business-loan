"""Command-line helper for creating users and resetting their passwords."""

import argparse
import asyncio
from getpass import getpass
from uuid import uuid4

from sqlalchemy import select

from app.database import AsyncSessionFactory
from app.models.user import User
from app.services import admin_service
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


async def reset_password(username: str, password: str) -> None:
    """Replace the password hash for an existing user."""
    async with AsyncSessionFactory() as db:
        user = await db.scalar(select(User).where(User.username == username))
        if user is None:
            raise ValueError("Username does not exist")
        user.hashed_password = hash_password(password)
        await db.commit()


async def seed_data_for_user(username: str) -> None:
    """Seed sample borrowers, overdue, due today, and paid loans directly in SQL."""
    async with AsyncSessionFactory() as db:
        user = await db.scalar(select(User).where(User.username == username))
        if user is None:
            raise ValueError(f"User {username} does not exist")
        res = await admin_service.seed_database(db, user)
        await db.commit()
        print(res["detail"])


def main() -> None:
    """Prompt securely and create a user, reset a password, or seed database."""
    parser = argparse.ArgumentParser(
        description="Create a Lending Nelson API user, reset password, or seed data"
    )
    parser.add_argument("username")
    parser.add_argument("--role", choices=["officer", "admin"], default="officer")
    parser.add_argument(
        "--reset-password",
        action="store_true",
        help="reset the password of an existing user",
    )
    parser.add_argument(
        "--seed",
        action="store_true",
        help="seed SQL database with sample borrowers, overdue, due today, and paid loans",
    )
    arguments = parser.parse_args()

    if arguments.seed:
        asyncio.run(seed_data_for_user(arguments.username))
        return

    password = getpass("Password: ")
    confirmation = getpass("Confirm password: ")
    if password != confirmation:
        raise ValueError("Passwords do not match")
    if arguments.reset_password:
        asyncio.run(reset_password(arguments.username, password))
        print(f"Reset password for user: {arguments.username}")
    else:
        asyncio.run(create_user(arguments.username, password, arguments.role))
        print(f"Created {arguments.role} user: {arguments.username}")


if __name__ == "__main__":
    main()
