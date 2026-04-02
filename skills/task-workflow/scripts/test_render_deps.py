"""Tests for render_deps.py - task dependency graph visualization."""

import json
import os
import tempfile
import unittest
from pathlib import Path


def make_task(task_id, subject, status="pending", blocks=None, blocked_by=None):
    """Create a task dict matching Claude Code's JSON format."""
    return {
        "id": str(task_id),
        "subject": subject,
        "status": status,
        "blocks": [str(b) for b in (blocks or [])],
        "blockedBy": [str(b) for b in (blocked_by or [])],
    }


def write_tasks(task_dir, tasks):
    """Write task dicts as individual JSON files in task_dir."""
    os.makedirs(task_dir, exist_ok=True)
    for task in tasks:
        path = os.path.join(task_dir, f"{task['id']}.json")
        with open(path, "w") as f:
            json.dump(task, f)


class TestLoadTasks(unittest.TestCase):
    """Test reading task JSON files from disk."""

    def test_loads_all_json_files(self):
        from render_deps import load_tasks

        with tempfile.TemporaryDirectory() as d:
            tasks = [
                make_task(1, "First"),
                make_task(2, "Second"),
            ]
            write_tasks(d, tasks)
            loaded = load_tasks(d)
            self.assertEqual(len(loaded), 2)
            ids = {t["id"] for t in loaded}
            self.assertEqual(ids, {"1", "2"})

    def test_empty_directory(self):
        from render_deps import load_tasks

        with tempfile.TemporaryDirectory() as d:
            loaded = load_tasks(d)
            self.assertEqual(loaded, [])

    def test_skips_non_json_files(self):
        from render_deps import load_tasks

        with tempfile.TemporaryDirectory() as d:
            write_tasks(d, [make_task(1, "Task")])
            # Write a non-JSON file
            with open(os.path.join(d, "notes.txt"), "w") as f:
                f.write("not a task")
            loaded = load_tasks(d)
            self.assertEqual(len(loaded), 1)

    def test_nonexistent_directory(self):
        from render_deps import load_tasks

        with tempfile.TemporaryDirectory() as d:
            bad_path = os.path.join(d, "nope")
            loaded = load_tasks(bad_path)
            self.assertEqual(loaded, [])


class TestBuildGraph(unittest.TestCase):
    """Test construction of directed graph from task data."""

    def test_linear_chain(self):
        """A -> B -> C"""
        from render_deps import build_graph

        tasks = [
            make_task(1, "A", blocks=[2]),
            make_task(2, "B", blocked_by=[1], blocks=[3]),
            make_task(3, "C", blocked_by=[2]),
        ]
        graph, task_map = build_graph(tasks)
        # graph maps task_id -> set of task_ids it blocks
        self.assertEqual(graph["1"], {"2"})
        self.assertEqual(graph["2"], {"3"})
        self.assertEqual(graph["3"], set())

    def test_fan_out(self):
        """A -> B, A -> C, A -> D"""
        from render_deps import build_graph

        tasks = [
            make_task(1, "A", blocks=[2, 3, 4]),
            make_task(2, "B", blocked_by=[1]),
            make_task(3, "C", blocked_by=[1]),
            make_task(4, "D", blocked_by=[1]),
        ]
        graph, _ = build_graph(tasks)
        self.assertEqual(graph["1"], {"2", "3", "4"})

    def test_fan_in(self):
        """A -> C, B -> C"""
        from render_deps import build_graph

        tasks = [
            make_task(1, "A", blocks=[3]),
            make_task(2, "B", blocks=[3]),
            make_task(3, "C", blocked_by=[1, 2]),
        ]
        graph, _ = build_graph(tasks)
        self.assertEqual(graph["1"], {"3"})
        self.assertEqual(graph["2"], {"3"})
        self.assertEqual(graph["3"], set())

    def test_diamond(self):
        """A -> B, A -> C, B -> D, C -> D"""
        from render_deps import build_graph

        tasks = [
            make_task(1, "A", blocks=[2, 3]),
            make_task(2, "B", blocked_by=[1], blocks=[4]),
            make_task(3, "C", blocked_by=[1], blocks=[4]),
            make_task(4, "D", blocked_by=[2, 3]),
        ]
        graph, _ = build_graph(tasks)
        self.assertEqual(graph["1"], {"2", "3"})
        self.assertEqual(graph["2"], {"4"})
        self.assertEqual(graph["3"], {"4"})
        self.assertEqual(graph["4"], set())

    def test_no_dependencies(self):
        from render_deps import build_graph

        tasks = [
            make_task(1, "A"),
            make_task(2, "B"),
            make_task(3, "C"),
        ]
        graph, _ = build_graph(tasks)
        for tid in ["1", "2", "3"]:
            self.assertEqual(graph[tid], set())

    def test_task_map_contains_all_tasks(self):
        from render_deps import build_graph

        tasks = [
            make_task(1, "Alpha", status="completed"),
            make_task(2, "Beta", status="in_progress"),
        ]
        _, task_map = build_graph(tasks)
        self.assertEqual(task_map["1"]["subject"], "Alpha")
        self.assertEqual(task_map["2"]["status"], "in_progress")


class TestTopologicalSort(unittest.TestCase):
    """Test topological layering of task graph."""

    def test_linear_chain_layers(self):
        from render_deps import build_graph, topological_layers

        tasks = [
            make_task(1, "A", blocks=[2]),
            make_task(2, "B", blocked_by=[1], blocks=[3]),
            make_task(3, "C", blocked_by=[2]),
        ]
        graph, _ = build_graph(tasks)
        layers = topological_layers(graph)
        # Layer 0: A (no deps), Layer 1: B, Layer 2: C
        self.assertEqual(len(layers), 3)
        self.assertIn("1", layers[0])
        self.assertIn("2", layers[1])
        self.assertIn("3", layers[2])

    def test_independent_tasks_same_layer(self):
        from render_deps import build_graph, topological_layers

        tasks = [
            make_task(1, "A"),
            make_task(2, "B"),
            make_task(3, "C"),
        ]
        graph, _ = build_graph(tasks)
        layers = topological_layers(graph)
        self.assertEqual(len(layers), 1)
        self.assertEqual(set(layers[0]), {"1", "2", "3"})

    def test_fan_in_layers(self):
        from render_deps import build_graph, topological_layers

        tasks = [
            make_task(1, "A", blocks=[3]),
            make_task(2, "B", blocks=[3]),
            make_task(3, "C", blocked_by=[1, 2]),
        ]
        graph, _ = build_graph(tasks)
        layers = topological_layers(graph)
        self.assertEqual(len(layers), 2)
        self.assertEqual(set(layers[0]), {"1", "2"})
        self.assertIn("3", layers[1])

    def test_diamond_layers(self):
        from render_deps import build_graph, topological_layers

        tasks = [
            make_task(1, "A", blocks=[2, 3]),
            make_task(2, "B", blocked_by=[1], blocks=[4]),
            make_task(3, "C", blocked_by=[1], blocks=[4]),
            make_task(4, "D", blocked_by=[2, 3]),
        ]
        graph, _ = build_graph(tasks)
        layers = topological_layers(graph)
        self.assertEqual(len(layers), 3)
        self.assertIn("1", layers[0])
        self.assertEqual(set(layers[1]), {"2", "3"})
        self.assertIn("4", layers[2])

    def test_empty_graph(self):
        from render_deps import topological_layers

        layers = topological_layers({})
        self.assertEqual(layers, [])

    def test_cycle_detection(self):
        from render_deps import build_graph, topological_layers

        # Manually construct a cycle: 1->2->3->1
        graph = {"1": {"2"}, "2": {"3"}, "3": {"1"}}
        with self.assertRaises(ValueError):
            topological_layers(graph)


class TestRenderAscii(unittest.TestCase):
    """Test ASCII diagram output."""

    def test_single_task_no_deps(self):
        from render_deps import build_graph, render_ascii

        tasks = [make_task(1, "Solo task")]
        graph, task_map = build_graph(tasks)
        output = render_ascii(graph, task_map)
        self.assertIn("#1", output)
        self.assertIn("Solo task", output)

    def test_linear_chain_output(self):
        from render_deps import build_graph, render_ascii

        tasks = [
            make_task(1, "First", blocks=[2]),
            make_task(2, "Second", blocked_by=[1], blocks=[3]),
            make_task(3, "Third", blocked_by=[2]),
        ]
        graph, task_map = build_graph(tasks)
        output = render_ascii(graph, task_map)
        self.assertIn("#1", output)
        self.assertIn("#2", output)
        self.assertIn("#3", output)
        # Should contain arrow indicators
        self.assertIn("►", output)

    def test_status_shown(self):
        from render_deps import build_graph, render_ascii

        tasks = [
            make_task(1, "Done", status="completed"),
            make_task(2, "Working", status="in_progress"),
            make_task(3, "Todo", status="pending"),
        ]
        graph, task_map = build_graph(tasks)
        output = render_ascii(graph, task_map)
        self.assertIn("✓", output)  # completed
        self.assertIn("◉", output)  # in_progress
        self.assertIn("○", output)  # pending

    def test_empty_tasks(self):
        from render_deps import build_graph, render_ascii

        graph, task_map = build_graph([])
        output = render_ascii(graph, task_map)
        self.assertIn("No tasks", output)

    def test_multiple_independent_tasks(self):
        from render_deps import build_graph, render_ascii

        tasks = [
            make_task(1, "A"),
            make_task(2, "B"),
        ]
        graph, task_map = build_graph(tasks)
        output = render_ascii(graph, task_map)
        self.assertIn("#1", output)
        self.assertIn("#2", output)


class TestRenderMermaid(unittest.TestCase):
    """Test mermaid diagram output."""

    def test_single_task(self):
        from render_deps import build_graph, render_mermaid

        tasks = [make_task(1, "Solo")]
        graph, task_map = build_graph(tasks)
        output = render_mermaid(graph, task_map)
        self.assertIn("graph LR", output)
        self.assertIn("1", output)

    def test_edge_syntax(self):
        from render_deps import build_graph, render_mermaid

        tasks = [
            make_task(1, "A", blocks=[2]),
            make_task(2, "B", blocked_by=[1]),
        ]
        graph, task_map = build_graph(tasks)
        output = render_mermaid(graph, task_map)
        self.assertIn("-->", output)

    def test_empty_tasks(self):
        from render_deps import build_graph, render_mermaid

        graph, task_map = build_graph([])
        output = render_mermaid(graph, task_map)
        self.assertIn("graph LR", output)

    def test_status_styling(self):
        from render_deps import build_graph, render_mermaid

        tasks = [
            make_task(1, "Done", status="completed"),
            make_task(2, "Working", status="in_progress"),
        ]
        graph, task_map = build_graph(tasks)
        output = render_mermaid(graph, task_map)
        # Mermaid should include style classes for status
        self.assertTrue(
            "class" in output.lower() or "style" in output.lower(),
            "Expected 'class' or 'style' in mermaid output",
        )


class TestEndToEnd(unittest.TestCase):
    """Integration tests using temp directories with fixture JSON."""

    def test_full_pipeline_from_disk(self):
        from render_deps import load_tasks, build_graph, render_ascii

        with tempfile.TemporaryDirectory() as d:
            tasks = [
                make_task(1, "Write tests", blocks=[2]),
                make_task(2, "Implement", blocked_by=[1], blocks=[3]),
                make_task(3, "Document", blocked_by=[2]),
            ]
            write_tasks(d, tasks)

            loaded = load_tasks(d)
            graph, task_map = build_graph(loaded)
            output = render_ascii(graph, task_map)

            self.assertIn("#1", output)
            self.assertIn("#2", output)
            self.assertIn("#3", output)
            self.assertIn("►", output)

    def test_complex_graph_from_disk(self):
        """
        #1 ──► #3 ──► #5
        #2 ──► #4 ──┘
        """
        from render_deps import load_tasks, build_graph, render_ascii

        with tempfile.TemporaryDirectory() as d:
            tasks = [
                make_task(1, "A", blocks=[3]),
                make_task(2, "B", blocks=[4]),
                make_task(3, "C", blocked_by=[1], blocks=[5]),
                make_task(4, "D", blocked_by=[2], blocks=[5]),
                make_task(5, "E", blocked_by=[3, 4]),
            ]
            write_tasks(d, tasks)

            loaded = load_tasks(d)
            graph, task_map = build_graph(loaded)
            output = render_ascii(graph, task_map)

            for i in range(1, 6):
                self.assertIn(f"#{i}", output)


if __name__ == "__main__":
    unittest.main()
