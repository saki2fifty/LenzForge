"""Serve the same documentation shipped with the repository."""
from pathlib import Path
from flask import Blueprint, jsonify, request

bp = Blueprint('docs', __name__)
ROOT = Path(__file__).resolve().parents[3]
DOCS = {
    'quick_start': ('Getting started', 'README.md'),
    'architecture': ('Architecture and modernization', 'docs/ARCHITECTURE.md'),
    'api_reference': ('Studio API', 'docs/API.md'),
    'gpu_tracking': ('GPU tracking and performance', 'docs/GPU_TRACKING.md'),
}


@bp.get('/list')
def list_docs():
    return jsonify(docs=[{'id': key, 'title': value[0]} for key, value in DOCS.items()])


@bp.get('/<doc_id>')
def get_doc(doc_id):
    if doc_id not in DOCS:
        return jsonify(error='Documentation not found'), 404
    title, path = DOCS[doc_id]
    return jsonify(id=doc_id, title=title, content=(ROOT / path).read_text(encoding='utf-8'))


@bp.get('/search')
def search_docs():
    query = request.args.get('q', '').strip().lower()
    results = []
    if query:
        for key, (title, path) in DOCS.items():
            matches = [line for line in (ROOT / path).read_text(encoding='utf-8').splitlines() if query in line.lower()]
            if matches:
                results.append({'id': key, 'title': title, 'matches': matches[:3]})
    return jsonify(results=results)
