-- Knowledge Base Schema for LobeHub Integration
-- Uses pgvector for semantic search with nomic-embed-text embeddings (768 dimensions)

-- Enable pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- Knowledge documents table
CREATE TABLE IF NOT EXISTS knowledge_documents (
    id SERIAL PRIMARY KEY,

    -- Source information
    source_path TEXT NOT NULL,
    source_type TEXT DEFAULT 'markdown',  -- markdown, json, text

    -- Document content
    title TEXT,
    content TEXT NOT NULL,
    chunk_index INTEGER DEFAULT 0,
    total_chunks INTEGER DEFAULT 1,

    -- Metadata
    metadata JSONB DEFAULT '{}',

    -- Vector embedding (nomic-embed-text produces 768 dimensions)
    embedding vector(768),

    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    indexed_at TIMESTAMPTZ,

    -- Unique constraint to prevent duplicate chunks
    UNIQUE(source_path, chunk_index)
);

-- Indexes for efficient querying
CREATE INDEX IF NOT EXISTS idx_knowledge_source_path ON knowledge_documents(source_path);
CREATE INDEX IF NOT EXISTS idx_knowledge_source_type ON knowledge_documents(source_type);
CREATE INDEX IF NOT EXISTS idx_knowledge_created_at ON knowledge_documents(created_at);
CREATE INDEX IF NOT EXISTS idx_knowledge_metadata ON knowledge_documents USING GIN(metadata);

-- Vector similarity search index (HNSW for fast approximate search)
CREATE INDEX IF NOT EXISTS idx_knowledge_embedding ON knowledge_documents
USING hnsw (embedding vector_cosine_ops)
WITH (m = 16, ef_construction = 64);

-- Function to search documents by semantic similarity
CREATE OR REPLACE FUNCTION search_knowledge(
    query_embedding vector(768),
    match_count INTEGER DEFAULT 10,
    match_threshold FLOAT DEFAULT 0.7
)
RETURNS TABLE (
    id INTEGER,
    source_path TEXT,
    title TEXT,
    content TEXT,
    metadata JSONB,
    similarity FLOAT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        kd.id,
        kd.source_path,
        kd.title,
        kd.content,
        kd.metadata,
        1 - (kd.embedding <=> query_embedding) AS similarity
    FROM knowledge_documents kd
    WHERE kd.embedding IS NOT NULL
    AND 1 - (kd.embedding <=> query_embedding) > match_threshold
    ORDER BY kd.embedding <=> query_embedding
    LIMIT match_count;
END;
$$;

-- Function to update the updated_at timestamp
CREATE OR REPLACE FUNCTION update_knowledge_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-update timestamp
DROP TRIGGER IF EXISTS trigger_update_knowledge_timestamp ON knowledge_documents;
CREATE TRIGGER trigger_update_knowledge_timestamp
    BEFORE UPDATE ON knowledge_documents
    FOR EACH ROW
    EXECUTE FUNCTION update_knowledge_timestamp();

-- Stats view for monitoring
CREATE OR REPLACE VIEW knowledge_stats AS
SELECT
    source_type,
    COUNT(*) as document_count,
    COUNT(embedding) as indexed_count,
    COUNT(*) - COUNT(embedding) as pending_count,
    MIN(created_at) as oldest_document,
    MAX(created_at) as newest_document
FROM knowledge_documents
GROUP BY source_type;

-- Grant permissions (adjust as needed for your setup)
-- GRANT SELECT, INSERT, UPDATE, DELETE ON knowledge_documents TO lobehub;
-- GRANT USAGE, SELECT ON SEQUENCE knowledge_documents_id_seq TO lobehub;
