# ai-hybrid-start-uvicorn.ps1
# Starts the FastAPI ALM traceability app using Uvicorn on port 8000.
# Exposes endpoints for import, search, and chat.

uvicorn ai_hybrid_app:app --host 0.0.0.0 --port 8000
