"""
ai_hybrid_app_import_sync.py

This script enables import, synchronization, and semantic search for ALM
(Application Lifecycle Management) data using Neo4j (graph database) and
Qdrant (vector database). It supports ingesting requirements, test cases,
test runs, and links from JSON, applies unique constraints in Neo4j, and
generates text embeddings via Ollama for semantic and hybrid search. The
script provides FastAPI endpoints for data import, vector search, hybrid
graph+vector search, and contextual Q&A using LLMs.
"""

# ai_hybrid_app_import_sync.py

import json
import logging
import os
from typing import Any, Dict, List

import requests
from fastapi import FastAPI, Request
from neo4j import GraphDatabase, Session
from qdrant_client import QdrantClient
from qdrant_client.models import Distance, PointStruct, VectorParams

# --- Configuration ---
NEO4J_URI = os.getenv("NEO4J_URI", "bolt://localhost:7687")
NEO4J_USER = os.getenv("NEO4J_USER", "neo4j")
NEO4J_PASS = os.getenv("NEO4J_PASS", "password")

QDRANT_URL = os.getenv("QDRANT_URL", "http://localhost:6333")
QDRANT_COLLECTION = os.getenv("QDRANT_COLLECTION", "trace_artifacts")

OLLAMA_URL = os.getenv("OLLAMA_URL", "http://localhost:11434")
EMBED_MODEL = os.getenv("EMBED_MODEL", "nomic-embed-text")
CHAT_MODEL = os.getenv("CHAT_MODEL", "llama3")

CONSTRAINTS = [
    "CREATE CONSTRAINT requirement_id     IF NOT EXISTS FOR (n:Requirement)     REQUIRE n.id IS UNIQUE;",
    "CREATE CONSTRAINT doc_id             IF NOT EXISTS FOR (n:ReqDoc)          REQUIRE n.id IS UNIQUE;",
    "CREATE CONSTRAINT testcase_id        IF NOT EXISTS FOR (n:TestCase)        REQUIRE n.id IS UNIQUE;",
    "CREATE CONSTRAINT testrun_id         IF NOT EXISTS FOR (n:TestRun)         REQUIRE n.id IS UNIQUE;",
    "CREATE CONSTRAINT customer_id        IF NOT EXISTS FOR (n:Customer)        REQUIRE n.id IS UNIQUE;",
    "CREATE CONSTRAINT custreq_id         IF NOT EXISTS FOR (n:CustomerRequirement) REQUIRE n.id IS UNIQUE;",
    "CREATE CONSTRAINT srd_id             IF NOT EXISTS FOR (n:Srd)               REQUIRE n.id IS UNIQUE;",
]

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

driver = GraphDatabase.driver(NEO4J_URI, auth=(NEO4J_USER, NEO4J_PASS))
qdrant = QdrantClient(url=QDRANT_URL)


# --- Helper functions ---
def run_cypher(session: Session, query: str, params: Dict[str, Any] = None) -> None:
    session.run(query, params or {})


def apply_constraints():
    with driver.session() as s:
        for c in CONSTRAINTS:
            logger.info(f"Applying constraint: {c}")
            run_cypher(s, c)


def embed_texts(texts: List[str]) -> List[List[float]]:
    vectors = []
    for t in texts:
        resp = requests.post(
            f"{OLLAMA_URL}/api/embeddings",
            json={"model": EMBED_MODEL, "prompt": t},
            timeout=120,
        )
        resp.raise_for_status()
        vectors.append(resp.json()["embedding"])
    return vectors


def ensure_qdrant_collection(dim: int):
    config = qdrant.get_collections().collections
    names = [c.name for c in config]
    if QDRANT_COLLECTION not in names:
        qdrant.create_collection(
            collection_name=QDRANT_COLLECTION,
            vectors_config=VectorParams(size=dim, distance=Distance.COSINE),
        )
        logger.info(
            f"Created Qdrant collection '{QDRANT_COLLECTION}' with dimension {dim}"
        )
    else:
        logger.info(f"Qdrant collection '{QDRANT_COLLECTION}' already exists")


# --- Import logic for your ALM schema ---
def import_requirements(reqs: List[Dict[str, Any]]):
    with driver.session() as s:
        for r in reqs:
            req_id = r.get("id")
            # ingest all properties into props
            run_cypher(
                s,
                """
                MERGE (req:Requirement {id:$id})
                SET req += $props
                """,
                {"id": req_id, "props": r},
            )

            # ReqDocNo link
            reqdocno = r.get("ReqDocNo")
            if reqdocno:
                run_cypher(
                    s,
                    """
                    MERGE (doc:ReqDoc {id:$doc_id})
                    MERGE (doc)-[:CONTAINS]->(req:Requirement {id:$req_id})
                    """,
                    {"doc_id": reqdocno, "req_id": req_id},
                )

            # src.docno link
            src = r.get("src", {})
            if isinstance(src, dict):
                docno = src.get("docno")
            else:
                docno = None
            if docno:
                run_cypher(
                    s,
                    """
                    MERGE (doc:ReqDoc {id:$doc_id})
                    MERGE (doc)-[:REFERS_REQUIREMENT]->(req:Requirement {id:$req_id})
                    """,
                    {"doc_id": docno, "req_id": req_id},
                )

            # Customers
            customers = r.get("Customer")
            if customers:
                for cust in customers if isinstance(customers, list) else [customers]:
                    if isinstance(cust, dict):
                        cust_id = cust.get("id")
                        cust_name = cust.get("name")
                    else:
                        cust_id = str(cust)
                        cust_name = None
                    run_cypher(
                        s,
                        """
                        MERGE (c:Customer {id:$cust_id})
                        SET c.name = coalesce($cust_name, c.name)
                        MERGE (c)-[:USES_REQUIREMENT]->(req:Requirement {id:$req_id})
                        """,
                        {"cust_id": cust_id, "cust_name": cust_name, "req_id": req_id},
                    )

            # customer_req & parents
            parents = r.get("parents", [])
            cust_reqs = r.get("customer_req", [])
            for p in parents if parents else []:
                if cust_reqs and p in cust_reqs:
                    # treat as CustomerRequirement
                    custreq_id = p
                    run_cypher(
                        s,
                        """
                        MERGE (cr:CustomerRequirement {id:$custreq_id})
                        MERGE (cr)-[:RELATED_TO]->(req:Requirement {id:$req_id})
                        """,
                        {"custreq_id": custreq_id, "req_id": req_id},
                    )
                else:
                    # normal requirement parent
                    run_cypher(
                        s,
                        """
                        MATCH (parent:Requirement {id:$parent_id})
                        MATCH (child :Requirement {id:$child_id})
                        MERGE (parent)-[:PARENT_OF]->(child)
                        """,
                        {"parent_id": p, "child_id": req_id},
                    )

            # srd array processing
            for srd_item in r.get("srd", []):
                srd_no = srd_item.get("no")
                # link to ReqDoc
                if srd_no:
                    run_cypher(
                        s,
                        """
                        MERGE (doc:ReqDoc {id:$doc_id})
                        MERGE (req:Requirement {id:$req_id})
                        MERGE (req)-[:BELONGS_TO_DOC]->(doc)
                        """,
                        {"doc_id": srd_no, "req_id": req_id},
                    )
                # ingest srd_item as Srd node
                run_cypher(
                    s,
                    """
                    MERGE (s:Srd {id:$srd_id})
                    SET s += $srd_props
                    MERGE (s)-[:ASSOCIATED_WITH]->(req:Requirement {id:$req_id})
                    """,
                    {
                        "srd_id": srd_no or f"{req_id}-srd-unknown",
                        "srd_props": srd_item,
                        "req_id": req_id,
                    },
                )


def import_testcases(tcs: List[Dict[str, Any]]):
    with driver.session() as s:
        for tc in tcs:
            tc_id = tc.get("id")
            run_cypher(
                s,
                """
                MERGE (tc:TestCase {id:$id})
                SET tc += $props
                """,
                {"id": tc_id, "props": tc},
            )
            for req_id in tc.get("verifies", []):
                if req_id:
                    run_cypher(
                        s,
                        """
                        MATCH (r:Requirement {id:$req_id})
                        MATCH (tc:TestCase    {id:$tc_id})
                        MERGE (r)-[:VERIFIED_BY]->(tc)
                        """,
                        {"req_id": req_id, "tc_id": tc_id},
                    )


def import_testruns(runs: List[Dict[str, Any]]):
    with driver.session() as s:
        for tr in runs:
            tr_id = tr.get("id")
            run_cypher(
                s,
                """
                MERGE (tr:TestRun {id:$id})
                SET tr += $props
                """,
                {"id": tr_id, "props": tr},
            )
            tc_id = tr.get("testCaseId")
            if tc_id:
                run_cypher(
                    s,
                    """
                    MATCH (tc:TestCase {id:$tc_id})
                    MATCH (tr:TestRun  {id:$tr_id})
                    MERGE (tc)-[:EXECUTED_IN]->(tr)
                    """,
                    {"tc_id": tc_id, "tr_id": tr_id},
                )


def import_generic_links(links: List[Dict[str, Any]]):
    with driver.session() as s:
        for ln in links:
            source = ln.get("sourceId")
            target = ln.get("targetId")
            ltype = ln.get("linkType", "LINKS_TO")
            if source and target:
                run_cypher(
                    s,
                    f"""
                    MATCH (src {{id:$source}})
                    MATCH (tgt {{id:$target}})
                    MERGE (src)-[:{ltype}]->(tgt)
                    """,
                    {"source": source, "target": target},
                )


def export_for_embeddings() -> List[Dict[str, Any]]:
    query = """
    MATCH (n)
    WHERE n:Requirement OR n:TestCase OR n:TestRun
    RETURN
      id(n) AS neo4j_id,
      labels(n)[0] AS label,
      n.id AS business_id,
      CASE
        WHEN n:Requirement THEN coalesce(n.title,'') + '\\n' + coalesce(n.text,'')
        WHEN n:TestCase    THEN coalesce(n.name,'') + '\\n' + coalesce(n.description,'')
        WHEN n:TestRun     THEN 'TestRun ' + coalesce(n.id,'') + ' status ' + coalesce(n.status,'') + '\\n' + coalesce(n.log,'')
      END AS content
    """
    with driver.session() as s:
        return s.run(query).data()


def sync_qdrant():
    rows = export_for_embeddings()
    if not rows:
        logger.info("No items to sync for embeddings.")
        return 0
    texts = [r["content"] for r in rows]
    vectors = embed_texts(texts)
    dim = len(vectors[0])
    ensure_qdrant_collection(dim)
    points = []
    for r, vec in zip(rows, vectors):
        pid = f"{r['label']}:{r['business_id']}"
        payload = {
            "type": r["label"],
            "business_id": r["business_id"],
            "text": r["content"],
        }
        points.append(PointStruct(id=pid, vector=vec, payload=payload))
    qdrant.upsert(collection_name=QDRANT_COLLECTION, points=points)
    logger.info(
        f"Upserted {len(points)} points into Qdrant collection '{QDRANT_COLLECTION}'"
    )
    return len(points)


def import_from_json(data: Dict[str, Any]):
    if "requirements" in data:
        import_requirements(data["requirements"])
    if "testCases" in data:
        import_testcases(data["testCases"])
    if "testRuns" in data:
        import_testruns(data["testRuns"])
    if "links" in data:
        import_generic_links(data["links"])
    # Sync embeddings afterwards
    synced = sync_qdrant()
    logger.info(f"Embeddings sync complete: {synced} vectors indexed.")


def vector_search(query: str) -> List[Dict[str, Any]]:
    vec = embed_texts([query])[0]
    results = qdrant.search(
        collection_name=QDRANT_COLLECTION, query_vector=vec, limit=5
    )
    return [
        {
            "id": r.payload["business_id"],
            "type": r.payload["type"],
            "score": r.score,
            "text": r.payload.get("text"),
        }
        for r in results
    ]


def hybrid_search(query: str) -> Dict[str, Any]:
    vec = embed_texts([query])[0]
    results = qdrant.search(
        collection_name=QDRANT_COLLECTION, query_vector=vec, limit=5
    )

    ids_by_type: Dict[str, List[str]] = {
        "Requirement": [],
        "TestCase": [],
        "TestRun": [],
    }
    for r in results:
        typ = r.payload["type"]
        if r.payload["business_id"] not in ids_by_type.get(typ, []):
            ids_by_type[typ].append(r.payload["business_id"])

    neighbourhood: Dict[str, Any] = {}
    with driver.session() as s:
        if ids_by_type["Requirement"]:
            recs = s.run(
                """
                MATCH (r:Requirement) WHERE r.id IN $ids
                OPTIONAL MATCH (r)-[:VERIFIED_BY]->(tc:TestCase)-[:EXECUTED_IN]->(tr:TestRun)
                OPTIONAL MATCH (r)<-[:USES_REQUIREMENT]-(c:Customer)
                OPTIONAL MATCH (r)<-[:RELATED_TO]-(cr:CustomerRequirement)
                OPTIONAL MATCH (doc:ReqDoc)-[:CONTAINS]->(r)
                OPTIONAL MATCH (req)-[:BELONGS_TO_DOC]->(doc2:ReqDoc)
                RETURN r.id AS reqId,
                        collect(DISTINCT tc.id)  AS testCases,
                        collect(DISTINCT tr.id)  AS testRuns,
                        collect(DISTINCT c.id)   AS customers,
                        collect(DISTINCT cr.id) AS customerReqs,
                        collect(DISTINCT doc.id) AS reqDocs
                """,
                {"ids": ids_by_type["Requirement"]},
            ).data()
            neighbourhood["requirements"] = recs

        if ids_by_type["TestCase"]:
            recs = s.run(
                """
                MATCH (tc:TestCase) WHERE tc.id IN $ids
                OPTIONAL MATCH (r:Requirement)-[:VERIFIED_BY]->(tc)
                OPTIONAL MATCH (tc)-[:EXECUTED_IN]->(tr:TestRun)
                RETURN tc.id AS tcId,
                       collect(DISTINCT r.id)  AS requirements,
                       collect(DISTINCT tr.id) AS testRuns
                """,
                {"ids": ids_by_type["TestCase"]},
            ).data()
            neighbourhood["testCases"] = recs

        if ids_by_type["TestRun"]:
            recs = s.run(
                """
                MATCH (tr:TestRun) WHERE tr.id IN $ids
                OPTIONAL MATCH (tc:TestCase)-[:EXECUTED_IN]->(tr)
                OPTIONAL MATCH (r:Requirement)-[:VERIFIED_BY]->(tc)
                RETURN tr.id AS trId,
                       collect(DISTINCT tc.id)  AS testCases,
                       collect(DISTINCT r.id)   AS requirements
                """,
                {"ids": ids_by_type["TestRun"]},
            ).data()
            neighbourhood["testRuns"] = recs

    return {
        "query": query,
        "vector_matches": [
            {
                "id": r.payload["business_id"],
                "type": r.payload["type"],
                "score": r.score,
            }
            for r in results
        ],
        "graph_neighbourhood": neighbourhood,
    }


def ask(query: str) -> Dict[str, Any]:
    hybrid = hybrid_search(query)
    context = json.dumps(hybrid["graph_neighbourhood"], indent=2)
    system_prompt = (
        "You are a traceability assistant. You receive a question and data about requirements, test cases, test runs, customers, documents.\n"
        "Use only the provided data to answer."
    )
    user_prompt = f"Question:\n{query}\n\nRelevant data:\n{context}"
    resp = requests.post(
        f"{OLLAMA_URL}/api/chat",
        json={
            "model": CHAT_MODEL,
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt},
            ],
        },
        timeout=300,
    )
    resp.raise_for_status()
    answer = resp.json().get("message", {}).get("content", "")
    return {
        "query": query,
        "data_used": hybrid["graph_neighbourhood"],
        "answer": answer,
    }


app = FastAPI()


@app.post("/import")
async def import_endpoint(request: Request):
    data = await request.json()
    import_from_json(data)
    return {"status": "imported"}


@app.get("/vector_search")
def vector_search_endpoint(q: str):
    return vector_search(q)


@app.get("/hybrid_search")
def hybrid_search_endpoint(q: str):
    return hybrid_search(q)


@app.get("/ask")
def ask_endpoint(q: str):
    return ask(q)


def main():
    import sys

    if len(sys.argv) == 2:
        json_path = sys.argv[1]
        if not os.path.isfile(json_path):
            print(f"File not found: {json_path}")
            sys.exit(1)
        with open(json_path, "r", encoding="utf-8") as f:
            data = json.load(f)
        apply_constraints()
        import_from_json(data)
        print("Import complete.")
    else:
        import uvicorn

        apply_constraints()
        print("Starting FastAPI server...")
        uvicorn.run(
            "ai_hybrid_app_import_sync:app", host="0.0.0.0", port=8000, reload=False
        )


if __name__ == "__main__":
    main()
