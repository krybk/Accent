#!/usr/bin/env python3
"""Tests for the DeepSeek worker's request and response contracts.

    python3 scripts/deepseek_apply_test.py

Stdlib only, and deliberately weighted towards the failure modes rather than the
happy path: the happy path costs an API call to get wrong, while a half-applied
patch costs a branch nobody wrote deliberately. Every failing case therefore
asserts that **no target file on disk changed** — the module either applies the
whole answer or none of it.
"""

import json
import os
import shutil
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import deepseek_apply as worker  # noqa: E402

FENCE = worker.FENCE
TRIGGER = worker.TRIGGER


def block(path, contents, fence=FENCE, tag=""):
    """One header plus one fenced block, the shape the contract demands."""
    return "{}\n{}{}\n{}{}\n".format(path, fence, tag, contents, fence)


def response(content, finish_reason="stop"):
    """An API response body carrying `content` as the assistant's answer."""
    return json.dumps(
        {
            "id": "chat-1",
            "choices": [
                {
                    "index": 0,
                    "finish_reason": finish_reason,
                    "message": {"role": "assistant", "content": content},
                }
            ],
        }
    )


class Worktree(unittest.TestCase):
    """A throwaway checkout, plus the assertion that nothing in it moved."""

    def setUp(self):
        self.root = tempfile.mkdtemp(prefix="deepseek-apply-")
        self.addCleanup(shutil.rmtree, self.root, True)

    def write(self, path, contents):
        full = os.path.join(self.root, path)
        os.makedirs(os.path.dirname(full), exist_ok=True)
        with open(full, "w", encoding="utf-8", newline="") as handle:
            handle.write(contents)
        return path

    def read(self, path):
        with open(os.path.join(self.root, path), "r", encoding="utf-8") as handle:
            return handle.read()

    def snapshot(self, *paths):
        return {path: self.read(path) for path in paths}

    def assertUnchanged(self, snapshot):
        for path, contents in snapshot.items():
            self.assertEqual(
                contents, self.read(path), "{} was modified".format(path)
            )

    def apply(self, response_text, paths, http_status=None):
        """Run the apply subcommand as the workflow does. Returns its exit code."""
        response_file = os.path.join(self.root, "_response.json")
        paths_file = os.path.join(self.root, "_paths.txt")
        message_file = os.path.join(self.root, "_message.md")
        with open(response_file, "w", encoding="utf-8") as handle:
            handle.write(response_text)
        with open(paths_file, "w", encoding="utf-8") as handle:
            handle.write("".join(path + "\n" for path in paths))

        argv = [
            "--root",
            self.root,
            "apply",
            "--response",
            response_file,
            "--paths-file",
            paths_file,
            "--message-file",
            message_file,
        ]
        if http_status is not None:
            argv += ["--http-status", str(http_status)]

        stderr, sys.stderr = sys.stderr, open(os.devnull, "w")
        try:
            code = worker.main(argv)
        finally:
            sys.stderr.close()
            sys.stderr = stderr

        self.message = ""
        if os.path.exists(message_file):
            with open(message_file, "r", encoding="utf-8") as handle:
                self.message = handle.read()
        return code


class ParseTheResponse(Worktree):
    def test_two_files_parse_to_exact_contents(self):
        text = block("a.txt", "alpha\nbeta\n") + "\n" + block("b/c.txt", "gamma\n")
        parsed = worker.parse(text, ["a.txt", "b/c.txt"])
        self.assertEqual(
            {"a.txt": "alpha\nbeta\n", "b/c.txt": "gamma\n"}, parsed
        )

    def test_a_language_tag_on_the_opening_fence_is_allowed(self):
        text = block("a.dart", "void main() {}\n", tag="dart")
        self.assertEqual({"a.dart": "void main() {}\n"}, worker.parse(text, ["a.dart"]))

    def test_a_path_that_was_not_requested_is_refused(self):
        kept = self.write("a.txt", "alpha\n")
        before = self.snapshot(kept)
        text = block("a.txt", "new\n") + block("elsewhere.txt", "sneaky\n")

        with self.assertRaises(worker.ParseError) as caught:
            worker.parse(text, ["a.txt"])
        self.assertIn("elsewhere.txt", str(caught.exception))

        self.assertEqual(2, self.apply(response(text), ["a.txt"]))
        self.assertUnchanged(before)

    def test_a_requested_path_missing_from_the_response_is_refused(self):
        kept = self.write("a.txt", "alpha\n")
        other = self.write("b.txt", "beta\n")
        before = self.snapshot(kept, other)
        text = block("a.txt", "new\n")

        with self.assertRaises(worker.ParseError) as caught:
            worker.parse(text, ["a.txt", "b.txt"])
        self.assertIn("b.txt", str(caught.exception))

        # The crucial case: a.txt parses perfectly and must still not be
        # written, because the patch as a whole did not.
        self.assertEqual(2, self.apply(response(text), ["a.txt", "b.txt"]))
        self.assertUnchanged(before)

    def test_two_blocks_for_the_same_path_are_refused(self):
        kept = self.write("a.txt", "alpha\n")
        before = self.snapshot(kept)
        text = block("a.txt", "first\n") + block("a.txt", "second\n")

        with self.assertRaises(worker.ParseError) as caught:
            worker.parse(text, ["a.txt"])
        self.assertIn("more than one block", str(caught.exception))

        self.assertEqual(2, self.apply(response(text), ["a.txt"]))
        self.assertUnchanged(before)

    def test_an_unterminated_fence_is_refused(self):
        kept = self.write("a.txt", "alpha\n")
        before = self.snapshot(kept)
        text = "a.txt\n{}\nalpha\nbeta\n".format(FENCE)

        with self.assertRaises(worker.ParseError) as caught:
            worker.parse(text, ["a.txt"])
        self.assertIn("never closed", str(caught.exception))

        self.assertEqual(2, self.apply(response(text), ["a.txt"]))
        self.assertUnchanged(before)

    def test_triple_backtick_fences_inside_contents_survive_intact(self):
        # The reason the fence is four backticks: a documentation pass is one of
        # the things this worker is for, and markdown is full of ``` fences.
        contents = "# Title\n\n```dart\nvoid main() {}\n```\n\nProse.\n"
        parsed = worker.parse(block("docs/x.md", contents), ["docs/x.md"])
        self.assertEqual(contents, parsed["docs/x.md"])

    def test_a_four_backtick_line_inside_contents_is_a_failure_not_a_truncation(self):
        kept = self.write("a.md", "original\n")
        before = self.snapshot(kept)
        text = "a.md\n{fence}\nbefore\n{fence}\nafter\n{fence}\n".format(fence=FENCE)

        with self.assertRaises(worker.ParseError):
            worker.parse(text, ["a.md"])

        self.assertEqual(2, self.apply(response(text), ["a.md"]))
        # Silent truncation would have left "before\n" on disk.
        self.assertUnchanged(before)
        self.assertEqual("original\n", self.read("a.md"))

    def test_an_empty_block_is_refused(self):
        kept = self.write("a.txt", "alpha\n")
        before = self.snapshot(kept)
        text = "a.txt\n{fence}\n{fence}\n".format(fence=FENCE)

        with self.assertRaises(worker.ParseError) as caught:
            worker.parse(text, ["a.txt"])
        self.assertIn("empty", str(caught.exception))

        self.assertEqual(2, self.apply(response(text), ["a.txt"]))
        self.assertUnchanged(before)

    def test_prose_the_parser_cannot_attribute_is_refused(self):
        kept = self.write("a.txt", "alpha\n")
        before = self.snapshot(kept)
        text = "Certainly! Here is the updated file:\n\n" + block("a.txt", "new\n")

        with self.assertRaises(worker.ParseError):
            worker.parse(text, ["a.txt"])

        self.assertEqual(2, self.apply(response(text), ["a.txt"]))
        self.assertUnchanged(before)

    def test_a_fence_with_no_path_above_it_is_refused(self):
        text = "{fence}\nalpha\n{fence}\n".format(fence=FENCE)
        with self.assertRaises(worker.ParseError) as caught:
            worker.parse(text, ["a.txt"])
        self.assertIn("no path", str(caught.exception))

    def test_a_successful_apply_writes_every_file_and_nothing_else(self):
        self.write("a.txt", "alpha\n")
        self.write("b/c.txt", "gamma\n")
        untouched = self.write("d.txt", "delta\n")
        before = self.snapshot(untouched)

        text = block("a.txt", "ALPHA\n") + block("b/c.txt", "GAMMA\nmore\n")
        self.assertEqual(0, self.apply(response(text), ["a.txt", "b/c.txt"]))

        self.assertEqual("ALPHA\n", self.read("a.txt"))
        self.assertEqual("GAMMA\nmore\n", self.read("b/c.txt"))
        self.assertUnchanged(before)


class ExtractTheMessage(Worktree):
    def test_finish_reason_stop_is_accepted(self):
        self.assertEqual("hello", worker.extract_message(response("hello"), 200))

    def test_finish_reason_length_is_refused_as_truncation(self):
        kept = self.write("a.txt", "alpha\n")
        before = self.snapshot(kept)
        body = response(block("a.txt", "new\n"), finish_reason="length")

        with self.assertRaises(worker.ParseError) as caught:
            worker.extract_message(body, 200)
        self.assertIn("finish_reason", str(caught.exception))

        self.assertEqual(2, self.apply(body, ["a.txt"], http_status=200))
        self.assertUnchanged(before)

    def test_a_non_2xx_status_is_refused(self):
        kept = self.write("a.txt", "alpha\n")
        before = self.snapshot(kept)
        body = '{"error": {"message": "Insufficient balance"}}'

        with self.assertRaises(worker.ParseError) as caught:
            worker.extract_message(body, 402)
        self.assertIn("402", str(caught.exception))

        self.assertEqual(2, self.apply(body, ["a.txt"], http_status=402))
        self.assertUnchanged(before)

    def test_an_error_object_on_a_2xx_is_refused(self):
        with self.assertRaises(worker.ParseError) as caught:
            worker.extract_message('{"error": {"message": "model not found"}}', 200)
        self.assertIn("model not found", str(caught.exception))

    def test_an_empty_body_is_refused(self):
        with self.assertRaises(worker.ParseError) as caught:
            worker.extract_message("   ", 200)
        self.assertIn("empty", str(caught.exception))

    def test_a_body_that_is_not_json_is_refused(self):
        kept = self.write("a.txt", "alpha\n")
        before = self.snapshot(kept)
        body = "<html><body>502 Bad Gateway</body></html>"

        with self.assertRaises(worker.ParseError) as caught:
            worker.extract_message(body, 200)
        self.assertIn("not JSON", str(caught.exception))

        self.assertEqual(2, self.apply(body, ["a.txt"], http_status=200))
        self.assertUnchanged(before)

    def test_a_response_with_no_choices_is_refused(self):
        with self.assertRaises(worker.ParseError):
            worker.extract_message('{"choices": []}', 200)

    def test_the_quoted_body_is_bounded(self):
        body = "\n".join("line {}".format(n) for n in range(500))
        with self.assertRaises(worker.ParseError) as caught:
            worker.extract_message(body, 500)
        # A whole response in an Issue comment is noise, not evidence.
        self.assertLess(len(str(caught.exception).splitlines()), 12)


class ValidatePaths(Worktree):
    def test_a_regular_file_inside_the_worktree_is_accepted(self):
        self.write("scripts/thing.sh", "echo hi\n")
        self.assertEqual(
            ["scripts/thing.sh"],
            worker.validate_paths(["scripts/thing.sh"], root=self.root),
        )

    def test_parent_traversal_is_refused(self):
        self.write("a.txt", "alpha\n")
        with self.assertRaises(worker.PathError) as caught:
            worker.validate_paths(["../etc/passwd"], root=self.root)
        self.assertIn("..", str(caught.exception))

    def test_a_path_that_climbs_out_and_back_is_refused(self):
        self.write("a.txt", "alpha\n")
        with self.assertRaises(worker.PathError):
            worker.validate_paths(["sub/../a.txt"], root=self.root)

    def test_an_absolute_path_is_refused(self):
        with self.assertRaises(worker.PathError) as caught:
            worker.validate_paths(["/etc/passwd"], root=self.root)
        self.assertIn("absolute", str(caught.exception))

    def test_a_symlink_is_refused(self):
        self.write("real.txt", "alpha\n")
        os.symlink(
            os.path.join(self.root, "real.txt"), os.path.join(self.root, "link.txt")
        )
        with self.assertRaises(worker.PathError) as caught:
            worker.validate_paths(["link.txt"], root=self.root)
        self.assertIn("symlink", str(caught.exception))

    def test_a_symlinked_directory_is_refused(self):
        self.write("real/inner.txt", "alpha\n")
        os.symlink(os.path.join(self.root, "real"), os.path.join(self.root, "alias"))
        with self.assertRaises(worker.PathError):
            worker.validate_paths(["alias/inner.txt"], root=self.root)

    def test_a_missing_file_is_refused(self):
        with self.assertRaises(worker.PathError) as caught:
            worker.validate_paths(["nope.txt"], root=self.root)
        self.assertIn("does not exist", str(caught.exception))

    def test_a_directory_is_refused(self):
        os.makedirs(os.path.join(self.root, "lib"))
        with self.assertRaises(worker.PathError):
            worker.validate_paths(["lib"], root=self.root)

    def test_each_refused_path_is_rejected_even_though_it_exists(self):
        for path in (
            ".github/workflows/x.yml",
            "scripts/check-secrets.sh",
            ".gitignore",
        ):
            with self.subTest(path=path):
                self.write(path, "content\n")
                with self.assertRaises(worker.PathError) as caught:
                    worker.validate_paths([path], root=self.root)
                self.assertIn("refused", str(caught.exception))

    def test_more_than_five_paths_are_refused(self):
        paths = [self.write("f{}.txt".format(n), "x\n") for n in range(6)]
        with self.assertRaises(worker.PathError) as caught:
            worker.validate_paths(paths, root=self.root)
        self.assertIn("at most 5", str(caught.exception))

    def test_input_over_two_hundred_kilobytes_is_refused(self):
        self.write("big.txt", "x" * (worker.MAX_INPUT_BYTES + 1))
        with self.assertRaises(worker.PathError) as caught:
            worker.validate_paths(["big.txt"], root=self.root)
        self.assertIn("ceiling", str(caught.exception))

    def test_the_instruction_counts_towards_the_ceiling(self):
        self.write("big.txt", "x" * (worker.MAX_INPUT_BYTES - 10))
        worker.validate_paths(["big.txt"], root=self.root, instruction="short")
        with self.assertRaises(worker.PathError):
            worker.validate_paths(
                ["big.txt"], root=self.root, instruction="y" * 100
            )

    def test_apply_revalidates_the_paths_it_is_handed(self):
        # The step that writes does not trust a path list it did not check.
        self.write(".gitignore", "build/\n")
        before = self.snapshot(".gitignore")
        text = block(".gitignore", "everything\n")
        self.assertEqual(2, self.apply(response(text), [".gitignore"]))
        self.assertUnchanged(before)


class ParseTheRequest(Worktree):
    def test_an_instruction_and_two_paths(self):
        body = (
            "{} Rename the field to `serverId`,\nkeeping the JSON key.\n"
            "\nfiles:\n- protocol/lib/src/server.dart\n- app/lib/main.dart\n"
        ).format(TRIGGER)
        instruction, paths = worker.parse_request(body)
        self.assertEqual(
            "Rename the field to `serverId`,\nkeeping the JSON key.", instruction
        )
        self.assertEqual(
            ["protocol/lib/src/server.dart", "app/lib/main.dart"], paths
        )

    def test_backticks_around_a_path_are_stripped(self):
        body = "{} do it\n\nfiles:\n- `docs/contributing.md`\n".format(TRIGGER)
        _, paths = worker.parse_request(body)
        self.assertEqual(["docs/contributing.md"], paths)

    def test_asterisk_list_items_are_accepted(self):
        body = "{} do it\n\nfiles:\n* a.txt\n".format(TRIGGER)
        _, paths = worker.parse_request(body)
        self.assertEqual(["a.txt"], paths)

    def test_the_block_ends_at_the_first_line_that_is_not_an_item(self):
        body = (
            "{} do it\n\nfiles:\n- a.txt\n\n- b.txt\nThanks!\n".format(TRIGGER)
        )
        _, paths = worker.parse_request(body)
        self.assertEqual(["a.txt"], paths)

    def test_an_empty_instruction_is_refused(self):
        body = "{}\n\nfiles:\n- a.txt\n".format(TRIGGER)
        with self.assertRaises(worker.RequestError) as caught:
            worker.parse_request(body)
        self.assertIn("no instruction", str(caught.exception))

    def test_a_missing_files_block_is_refused_and_shows_the_format(self):
        body = "{} please fix the docs\n".format(TRIGGER)
        with self.assertRaises(worker.RequestError) as caught:
            worker.parse_request(body)
        self.assertIn("files:", str(caught.exception))

    def test_a_files_block_with_no_items_is_refused(self):
        body = "{} do it\n\nfiles:\n\nnothing here\n".format(TRIGGER)
        with self.assertRaises(worker.RequestError) as caught:
            worker.parse_request(body)
        self.assertIn("no paths", str(caught.exception))

    def test_a_body_without_the_trigger_is_refused(self):
        with self.assertRaises(worker.RequestError):
            worker.parse_request("just talking\n\nfiles:\n- a.txt\n")

    def test_a_repeated_path_is_listed_once(self):
        body = "{} do it\n\nfiles:\n- a.txt\n- a.txt\n".format(TRIGGER)
        _, paths = worker.parse_request(body)
        self.assertEqual(["a.txt"], paths)


class BuildThePayload(Worktree):
    def test_the_payload_is_single_shot_and_pinned(self):
        payload = worker.build_payload("do it", {"a.txt": "alpha\n"})
        self.assertEqual("deepseek-chat", payload["model"])
        self.assertEqual(0, payload["temperature"])
        self.assertFalse(payload["stream"])
        self.assertEqual(8192, payload["max_tokens"])
        # A tool call through an OpenAI-compatible translation layer fails
        # quietly, which is why there is no tool loop at all.
        self.assertNotIn("tools", payload)
        self.assertNotIn("functions", payload)

    def test_a_quote_or_a_backtick_in_the_comment_cannot_break_the_json(self):
        nasty = 'Use "double quotes" and `backticks`, $(id), \\ and \n newlines'
        payload = worker.build_payload(nasty, {"a.txt": "```\nx\n```\n"})
        restored = json.loads(json.dumps(payload))
        self.assertIn(nasty, restored["messages"][1]["content"])

    def test_the_system_prompt_names_the_paths_and_the_fence(self):
        payload = worker.build_payload("do it", {"a.txt": "alpha\n", "b.txt": "b\n"})
        system = payload["messages"][0]["content"]
        self.assertIn("a.txt", system)
        self.assertIn("b.txt", system)
        self.assertIn(FENCE, system)

    def test_the_round_trip_through_the_payload_and_back(self):
        # What the worker sends and what it accepts back must be one format.
        self.write("a.txt", "alpha\n")
        instruction, paths = worker.parse_request(
            "{} uppercase it\n\nfiles:\n- a.txt\n".format(TRIGGER)
        )
        paths = worker.validate_paths(paths, root=self.root, instruction=instruction)
        payload = worker.build_payload(instruction, worker.read_files(paths, self.root))
        echoed = payload["messages"][1]["content"]
        start = echoed.index("a.txt\n{}".format(FENCE))
        self.assertEqual(
            {"a.txt": "alpha\n"}, worker.parse(echoed[start:], ["a.txt"])
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
