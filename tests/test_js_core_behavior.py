import json
import subprocess
import textwrap
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def run_js(module_path, expression):
    expression_source = json.dumps(f"JSON.stringify({expression})")
    script = textwrap.dedent(
        f"""
        const fs = require("fs");
        const vm = require("vm");
        const path = "{module_path.as_posix()}";
        const source = fs.readFileSync(path, "utf8").replace(/^\\.pragma library\\s*/, "");
        const context = {{}};
        vm.createContext(context);
        vm.runInContext(source, context, {{ filename: path }});
        const result = vm.runInContext({expression_source}, context);
        console.log(result);
        """
    )
    completed = subprocess.run(
        ["node", "-e", script],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=True,
    )
    return json.loads(completed.stdout)


class AuthCoreBehaviorTests(unittest.TestCase):
    def test_normalizes_server_url_and_validates_online_account_readiness(self):
        module = ROOT / "qml/backend/AuthCore.js"

        result = run_js(
            module,
            """({
                normalized: normalizeServerUrl("cloudsite.se///"),
                existingScheme: normalizeServerUrl("https://cloudsite.se/"),
                complete: onlineAccountConfigured(2, "nextnotes.cloudsite_nextnotes_nextcloud", "cloudsite.se"),
                missingService: onlineAccountConfigured(2, "", "cloudsite.se"),
                missingServer: onlineAccountConfigured(2, "nextnotes.cloudsite_nextnotes_nextcloud", "")
            })""",
        )

        self.assertEqual(result["normalized"], "https://cloudsite.se")
        self.assertEqual(result["existingScheme"], "https://cloudsite.se")
        self.assertTrue(result["complete"])
        self.assertFalse(result["missingService"])
        self.assertFalse(result["missingServer"])


class NotesApiCoreBehaviorTests(unittest.TestCase):
    def test_builds_urls_payloads_etags_and_parses_notes(self):
        module = ROOT / "qml/backend/NotesApiCore.js"

        result = run_js(
            module,
            """({
                notesUrl: notesUrl("cloudsite.se/"),
                noteUrl: noteUrl("https://cloudsite.se/", 42),
                payload: notePayload({ title: "Title", category: "Work", favorite: true, content: "Body" }),
                quotedEtag: formatEtagHeader("abc"),
                weakEtag: formatEtagHeader("W/\\\"abc\\\""),
                notes: parseNotesJson(JSON.stringify([
                    { id: 1, title: "One", etag: "e1", modified: 10, favorite: true },
                    { id: null, title: "skip" },
                    { id: 2, content: "Body" }
                ]), "Untitled note"),
                note: parseNoteJson(JSON.stringify({ id: 3, content: "Only content" }), "Untitled note")
            })""",
        )

        self.assertEqual(result["notesUrl"], "https://cloudsite.se/index.php/apps/notes/api/v1/notes")
        self.assertEqual(result["noteUrl"], "https://cloudsite.se/index.php/apps/notes/api/v1/notes/42")
        self.assertEqual(result["payload"], {"title": "Title", "category": "Work", "favorite": True, "content": "Body"})
        self.assertEqual(result["quotedEtag"], '"abc"')
        self.assertEqual(result["weakEtag"], 'W/"abc"')
        self.assertTrue(result["notes"]["ok"])
        self.assertEqual(len(result["notes"]["notes"]), 2)
        self.assertEqual(result["notes"]["notes"][1]["title"], "Untitled note")
        self.assertTrue(result["note"]["ok"])
        self.assertEqual(result["note"]["note"]["noteId"], 3)


class SyncPlannerBehaviorTests(unittest.TestCase):
    def test_plans_queue_skips_and_conflicts(self):
        module = ROOT / "qml/backend/SyncPlanner.js"

        result = run_js(
            module,
            """planSync([
                { noteId: 1, deleted: true },
                { noteId: 2, contentLoaded: false },
                { noteId: 3, contentLoaded: true, conflict: true },
                { noteId: 4, contentLoaded: true, isNew: false, etag: "" },
                { noteId: -1, contentLoaded: true, isNew: true, etag: "" },
                { noteId: 5, contentLoaded: true, isNew: false, etag: "etag-5" }
            ])""",
        )

        self.assertEqual([note["noteId"] for note in result["queue"]], [1, -1, 5])
        self.assertEqual(result["skippedCount"], 1)
        self.assertEqual(result["conflictNoteIds"], [3, 4])
        self.assertEqual(result["conflictCount"], 2)


if __name__ == "__main__":
    unittest.main(verbosity=2)
