from __future__ import annotations

import argparse

from app.jobs.build_graph import build_graph
from app.jobs.build_vector_index import build_vector_index
from app.jobs.import_dataset import import_all_sources


def rebuild_all(skip_vector: bool = False) -> dict[str, object]:
    import_result = import_all_sources()
    graph_result = build_graph()
    vector_result = None
    if not skip_vector:
        vector_result = build_vector_index()
    return {
        "import": import_result,
        "graph": graph_result,
        "vector": vector_result,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="Import raw sources and rebuild graph/vector indexes.")
    parser.add_argument("--skip-vector", action="store_true", help="Skip Chroma vector index rebuild.")
    args = parser.parse_args()
    result = rebuild_all(skip_vector=args.skip_vector)
    print(result)


if __name__ == "__main__":
    main()

