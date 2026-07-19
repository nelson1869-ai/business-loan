"""Shared schema serialization helpers."""


def to_camel(value: str) -> str:
    """Convert a snake_case field name to lower camelCase."""
    first, *rest = value.split("_")
    return first + "".join(word.capitalize() for word in rest)
