"""
ai_hybrid_app.py

FastAPI application providing endpoints for importing ALM (Application Lifecycle
Management) data, performing vector and hybrid graph+vector search, and answering
questions using LLMs with context from Neo4j and Qdrant. Integrates requirements,
test cases, test runs, customers, documents, and SRD links for traceability and
semantic search.
"""

import logging
from typing import Any, Dict, List, Optional

import ai_hybrid_app_import_sync as core
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="Traceability KG + Vector Search + Chat API",
    version="1.0.0",
    description=(
        "API for importing ALM Requirements/TestCases/TestRuns with Customers, Documents, SRD links; "
        "performing vector and hybrid search; and interacting via a chat interface."
    ),
    openapi_tags=[
        {"name": "health", "description": "Health check endpoint"},
        {"name": "import", "description": "Import endpoints for JSON data"},
        {"name": "search", "description": "Vector & hybrid search endpoints"},
        {"name": "ask", "description": "Chat/Ask endpoint using LLM & context"},
    ],
)

# --- Request & Response models ---


class ImportPayload(BaseModel):
    data: Dict[str, Any] = Field(
        ...,
        description="JSON data export (requirements, testCases, testRuns, optional links)",
    )


class SearchQuery(BaseModel):
    query: str = Field(..., description="User text query")


class VectorSearchResult(BaseModel):
    id: str
    type: str
    score: float
    text: Optional[str] = None


class VectorSearchResponse(BaseModel):
    query: str
    matches: List[VectorSearchResult]


class GraphNeighbourhood(BaseModel):
    requirements: Optional[List[Dict[str, Any]]] = None
    testCases: Optional[List[Dict[str, Any]]] = None
    testRuns: Optional[List[Dict[str, Any]]] = None


class HybridSearchResponse(BaseModel):
    query: str
    vector_matches: List[VectorSearchResult]
    graph_neighbourhood: GraphNeighbourhood


class AskResponse(BaseModel):
    query: str
    data_used: GraphNeighbourhood
    answer: str


# --- Endpoints ---


@app.get("/", tags=["health"])
def welcome():
    return {
        "message": (
            "Welcome to the Traceability KG + Vector + Chat API. "
            "See /docs for interactive documentation."
        )
    }


@app.get("/health", tags=["health"])
def health_check():
    return {"status": "ok"}


@app.post("/import-json", tags=["import"], response_model=Dict[str, Any])
def import_json(payload: ImportPayload):
    try:
        core.import_from_json(payload.data)
    except Exception as e:
        logger.error(f"Import failed: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Import failed: {e}")
    return {"status": "imported"}


@app.post("/search/vector", tags=["search"], response_model=VectorSearchResponse)
def vector_search(q: SearchQuery):
    try:
        matches = core.vector_search(q.query)
    except Exception as e:
        logger.error(f"Vector search failed: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Vector search failed: {e}")
    return {"query": q.query, "matches": matches}


@app.post("/search/hybrid", tags=["search"], response_model=HybridSearchResponse)
def hybrid_search(q: SearchQuery):
    try:
        result = core.hybrid_search(q.query)
    except Exception as e:
        logger.error(f"Hybrid search failed: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Hybrid search failed: {e}")
    return result


@app.post("/ask", tags=["ask"], response_model=AskResponse)
def ask_endpoint(q: SearchQuery):
    try:
        resp = core.ask(q.query)
    except Exception as e:
        logger.error(f"Ask endpoint failed: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Ask failed: {e}")
    return resp
