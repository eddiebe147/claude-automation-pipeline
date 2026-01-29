#!/usr/bin/env python3
"""
Knowledge Base Ingestion Script

Ingests markdown files into PostgreSQL with pgvector embeddings.
Uses Ollama's nomic-embed-text model for local embedding generation.
"""

import os
import re
import json
import hashlib
import asyncio
from pathlib import Path
from datetime import datetime
from typing import Iterator, Optional
import argparse

import httpx
import psycopg
from psycopg.rows import dict_row

# Configuration
POSTGRES_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://postgres:keGAblF7KTwCrWLHYJxBS2DQ@localhost:5433/lobechat"
)
OLLAMA_URL = os.getenv("OLLAMA_URL", "http://localhost:11434")
EMBEDDING_MODEL = "nomic-embed-text"

# Chunk settings
MAX_CHUNK_SIZE = 1500  # Characters per chunk
CHUNK_OVERLAP = 200    # Overlap between chunks


def clean_markdown(text: str) -> str:
    """Remove markdown formatting for cleaner embedding."""
    # Remove code blocks
    text = re.sub(r'```[\s\S]*?```', '', text)
    # Remove inline code
    text = re.sub(r'`[^`]+`', '', text)
    # Remove links but keep text
    text = re.sub(r'\[([^\]]+)\]\([^)]+\)', r'\1', text)
    # Remove images
    text = re.sub(r'!\[[^\]]*\]\([^)]+\)', '', text)
    # Remove HTML tags
    text = re.sub(r'<[^>]+>', '', text)
    # Remove excessive whitespace
    text = re.sub(r'\n{3,}', '\n\n', text)
    text = re.sub(r' {2,}', ' ', text)
    return text.strip()


def extract_title(content: str, filepath: Path) -> str:
    """Extract title from markdown content or filename."""
    # Look for first H1
    match = re.search(r'^#\s+(.+)$', content, re.MULTILINE)
    if match:
        return match.group(1).strip()

    # Look for first H2
    match = re.search(r'^##\s+(.+)$', content, re.MULTILINE)
    if match:
        return match.group(1).strip()

    # Use filename
    return filepath.stem.replace('-', ' ').replace('_', ' ').title()


def chunk_text(text: str, max_size: int = MAX_CHUNK_SIZE, overlap: int = CHUNK_OVERLAP) -> list[str]:
    """Split text into overlapping chunks."""
    if len(text) <= max_size:
        return [text]

    chunks = []
    start = 0

    while start < len(text):
        # Find end of chunk
        end = start + max_size

        if end >= len(text):
            chunks.append(text[start:])
            break

        # Try to break at paragraph
        para_break = text.rfind('\n\n', start, end)
        if para_break > start + max_size // 2:
            end = para_break + 2
        else:
            # Try to break at sentence
            sentence_break = text.rfind('. ', start, end)
            if sentence_break > start + max_size // 2:
                end = sentence_break + 2
            else:
                # Try to break at word
                word_break = text.rfind(' ', start, end)
                if word_break > start + max_size // 2:
                    end = word_break + 1

        chunks.append(text[start:end].strip())
        start = end - overlap

    return [c for c in chunks if c]


def iter_markdown_files(directories: list[str]) -> Iterator[Path]:
    """Iterate over markdown files in directories."""
    for directory in directories:
        path = Path(directory).expanduser()
        if not path.exists():
            print(f"Warning: Directory not found: {directory}")
            continue

        if path.is_file() and path.suffix in ('.md', '.mdx'):
            yield path
        elif path.is_dir():
            for pattern in ('**/*.md', '**/*.mdx'):
                yield from path.glob(pattern)


async def get_embedding(text: str, client: httpx.AsyncClient) -> list[float]:
    """Get embedding from Ollama."""
    try:
        response = await client.post(
            f"{OLLAMA_URL}/api/embeddings",
            json={
                "model": EMBEDDING_MODEL,
                "prompt": text
            },
            timeout=60.0
        )
        response.raise_for_status()
        return response.json()["embedding"]
    except Exception as e:
        print(f"Embedding error: {e}")
        return []


async def process_file(
    filepath: Path,
    conn: psycopg.AsyncConnection,
    client: httpx.AsyncClient,
    force: bool = False
) -> int:
    """Process a single markdown file."""
    try:
        content = filepath.read_text(encoding='utf-8', errors='ignore')
    except Exception as e:
        print(f"Error reading {filepath}: {e}")
        return 0

    source_path = str(filepath.absolute())
    title = extract_title(content, filepath)
    cleaned = clean_markdown(content)

    if not cleaned or len(cleaned) < 50:
        return 0

    chunks = chunk_text(cleaned)
    total_chunks = len(chunks)
    processed = 0

    for i, chunk in enumerate(chunks):
        if len(chunk) < 30:
            continue

        # Check if already exists
        if not force:
            async with conn.cursor() as cur:
                await cur.execute(
                    "SELECT id FROM knowledge_documents WHERE source_path = %s AND chunk_index = %s",
                    (source_path, i)
                )
                if await cur.fetchone():
                    continue

        # Get embedding
        embedding = await get_embedding(chunk, client)
        if not embedding:
            print(f"  Skipping chunk {i} - no embedding")
            continue

        # Insert/update document
        async with conn.cursor() as cur:
            await cur.execute(
                """
                INSERT INTO knowledge_documents
                    (source_path, source_type, title, content, chunk_index, total_chunks, embedding, metadata, indexed_at)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, NOW())
                ON CONFLICT (source_path, chunk_index)
                DO UPDATE SET
                    title = EXCLUDED.title,
                    content = EXCLUDED.content,
                    total_chunks = EXCLUDED.total_chunks,
                    embedding = EXCLUDED.embedding,
                    metadata = EXCLUDED.metadata,
                    indexed_at = NOW()
                """,
                (
                    source_path,
                    'markdown',
                    title,
                    chunk,
                    i,
                    total_chunks,
                    str(embedding),
                    json.dumps({
                        "filename": filepath.name,
                        "parent": filepath.parent.name,
                        "chars": len(chunk)
                    })
                )
            )
        processed += 1

    return processed


async def main():
    parser = argparse.ArgumentParser(description="Ingest markdown files into knowledge base")
    parser.add_argument(
        "directories",
        nargs="*",
        default=[
            "/Users/eddiebelaval/clawd",
            "/Users/eddiebelaval/.claude/knowledge",
            "/Users/eddiebelaval/Development/Homer/docs"
        ],
        help="Directories to ingest"
    )
    parser.add_argument("--force", action="store_true", help="Re-process existing documents")
    parser.add_argument("--limit", type=int, default=0, help="Max files to process (0 = unlimited)")
    args = parser.parse_args()

    print(f"Connecting to PostgreSQL at {POSTGRES_URL.split('@')[1]}...")

    async with await psycopg.AsyncConnection.connect(POSTGRES_URL) as conn:
        # Apply schema
        print("Applying schema...")
        schema_path = Path(__file__).parent / "schema.sql"
        if schema_path.exists():
            async with conn.cursor() as cur:
                await cur.execute(schema_path.read_text())
            await conn.commit()
            print("Schema applied successfully")

        # Create HTTP client
        async with httpx.AsyncClient() as client:
            # Verify Ollama is running
            try:
                await client.get(f"{OLLAMA_URL}/api/tags", timeout=5.0)
            except Exception as e:
                print(f"Error: Ollama not available at {OLLAMA_URL}")
                print("Please ensure Ollama is running with the nomic-embed-text model")
                return

            # Process files
            print(f"\nIngesting from: {', '.join(args.directories)}")
            total_files = 0
            total_chunks = 0

            files = list(iter_markdown_files(args.directories))
            if args.limit > 0:
                files = files[:args.limit]

            print(f"Found {len(files)} markdown files")

            for i, filepath in enumerate(files, 1):
                rel_path = filepath.name
                if len(str(filepath)) > 60:
                    rel_path = f"...{str(filepath)[-57:]}"

                print(f"[{i}/{len(files)}] {rel_path}", end=" ")

                chunks = await process_file(filepath, conn, client, args.force)
                if chunks > 0:
                    print(f"-> {chunks} chunks")
                    total_files += 1
                    total_chunks += chunks
                else:
                    print("-> skipped")

                await conn.commit()

            # Print stats
            print(f"\n{'='*50}")
            print(f"Ingestion complete!")
            print(f"  Files processed: {total_files}")
            print(f"  Chunks created:  {total_chunks}")

            # Query stats
            async with conn.cursor(row_factory=dict_row) as cur:
                await cur.execute("SELECT * FROM knowledge_stats")
                stats = await cur.fetchall()
                print(f"\nDatabase stats:")
                for row in stats:
                    print(f"  {row['source_type']}: {row['indexed_count']} indexed")


if __name__ == "__main__":
    asyncio.run(main())
