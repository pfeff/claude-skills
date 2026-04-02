#!/usr/bin/env python3
"""Render task dependency graph as ASCII or mermaid diagram.

Reads Claude Code task JSON files and visualizes blocking relationships.

Usage:
    render_deps.py [--task-list-id ID] [--mermaid]

Options:
    --task-list-id ID   Task list ID (defaults to CLAUDE_CODE_TASK_LIST_ID env var)
    --mermaid           Output mermaid flowchart instead of ASCII
"""

import argparse
import json
import os
import sys
from collections import defaultdict


STATUS_ICONS = {
    "completed": "✓",
    "in_progress": "◉",
    "pending": "○",
}


def load_tasks(task_dir):
    """Load all task JSON files from a directory."""
    if not os.path.isdir(task_dir):
        return []
    tasks = []
    for name in sorted(os.listdir(task_dir)):
        if not name.endswith(".json"):
            continue
        path = os.path.join(task_dir, name)
        with open(path) as f:
            tasks.append(json.load(f))
    return tasks


def build_graph(tasks):
    """Build directed graph from task data.

    Returns:
        graph: dict mapping task_id -> set of task_ids it blocks
        task_map: dict mapping task_id -> task dict
    """
    task_map = {t["id"]: t for t in tasks}
    graph = defaultdict(set)

    for t in tasks:
        tid = t["id"]
        graph.setdefault(tid, set())
        for blocked_id in t.get("blocks", []):
            if blocked_id in task_map:
                graph[tid].add(blocked_id)
        for blocker_id in t.get("blockedBy", []):
            if blocker_id in task_map:
                graph[blocker_id].add(tid)

    return dict(graph), task_map


def topological_layers(graph):
    """Group nodes into layers by dependency depth (Kahn's algorithm).

    Raises ValueError if the graph contains a cycle.
    """
    if not graph:
        return []

    # Compute in-degrees
    in_degree = {node: 0 for node in graph}
    for node, targets in graph.items():
        for t in targets:
            in_degree.setdefault(t, 0)
            in_degree[t] += 1

    # Seed with zero in-degree nodes
    queue = sorted([n for n, d in in_degree.items() if d == 0])
    layers = []
    processed = 0

    while queue:
        layers.append(list(queue))
        processed += len(queue)
        next_queue = []
        for node in queue:
            for target in sorted(graph.get(node, set())):
                in_degree[target] -= 1
                if in_degree[target] == 0:
                    next_queue.append(target)
        queue = sorted(next_queue)

    if processed < len(in_degree):
        raise ValueError("Cycle detected in task dependencies")

    return layers


def _task_label(task_map, tid):
    """Format a task label: #ID icon Subject."""
    t = task_map.get(tid, {})
    icon = STATUS_ICONS.get(t.get("status", "pending"), "○")
    subject = t.get("subject", "")
    return f"#{tid} {icon} {subject}"


def render_ascii(graph, task_map):
    """Render task dependency graph as ASCII art."""
    if not graph:
        return "No tasks found."

    layers = topological_layers(graph)

    # Compute reverse graph (who blocks each node)
    reverse = defaultdict(set)
    for node, targets in graph.items():
        for t in targets:
            reverse[t].add(node)

    lines = []

    # Render layer by layer, left to right
    # For each task, show its label and arrows to what it blocks
    for layer_idx, layer in enumerate(layers):
        for row_idx, tid in enumerate(layer):
            label = _task_label(task_map, tid)
            targets = sorted(graph.get(tid, set()))

            if targets:
                target_strs = ", ".join(f"#{t}" for t in targets)
                lines.append(f"  {label} ──► {target_strs}")
            else:
                lines.append(f"  {label}")

        if layer_idx < len(layers) - 1:
            lines.append("")

    return "\n".join(lines)


def render_mermaid(graph, task_map):
    """Render task dependency graph as mermaid flowchart."""
    lines = ["graph LR"]

    # Define nodes
    for tid in sorted(task_map.keys()):
        t = task_map[tid]
        icon = STATUS_ICONS.get(t.get("status", "pending"), "○")
        subject = t.get("subject", "")
        lines.append(f'    {tid}["{icon} #{tid} {subject}"]')

    # Define edges
    for source in sorted(graph.keys()):
        for target in sorted(graph[source]):
            lines.append(f"    {source} --> {target}")

    # Style classes by status
    completed = [tid for tid, t in task_map.items() if t.get("status") == "completed"]
    in_progress = [tid for tid, t in task_map.items() if t.get("status") == "in_progress"]
    pending = [tid for tid, t in task_map.items() if t.get("status") == "pending"]

    lines.append("")
    lines.append("    classDef completed fill:#d4edda,stroke:#28a745")
    lines.append("    classDef in_progress fill:#fff3cd,stroke:#ffc107")
    lines.append("    classDef pending fill:#f8f9fa,stroke:#6c757d")

    if completed:
        lines.append(f"    class {','.join(sorted(completed))} completed")
    if in_progress:
        lines.append(f"    class {','.join(sorted(in_progress))} in_progress")
    if pending:
        lines.append(f"    class {','.join(sorted(pending))} pending")

    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description="Render task dependency graph")
    parser.add_argument(
        "--task-list-id",
        default=os.environ.get("CLAUDE_CODE_TASK_LIST_ID", ""),
        help="Task list ID (defaults to CLAUDE_CODE_TASK_LIST_ID env var)",
    )
    parser.add_argument(
        "--mermaid",
        action="store_true",
        help="Output mermaid flowchart instead of ASCII",
    )
    args = parser.parse_args()

    if not args.task_list_id:
        print("Error: --task-list-id required or set CLAUDE_CODE_TASK_LIST_ID", file=sys.stderr)
        sys.exit(1)

    tasks_dir = os.path.join(os.path.expanduser("~"), ".claude", "tasks", args.task_list_id)
    tasks = load_tasks(tasks_dir)
    graph, task_map = build_graph(tasks)

    if args.mermaid:
        print(render_mermaid(graph, task_map))
    else:
        print(render_ascii(graph, task_map))


if __name__ == "__main__":
    main()
