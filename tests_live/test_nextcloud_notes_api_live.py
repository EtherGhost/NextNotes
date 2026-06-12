import base64
import json
import os
import time
import unittest
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
API_PREFIX = "/index.php/apps/notes/api/v1"


def load_local_env():
    env_path = ROOT / ".env.test.local"
    if not env_path.exists():
        return

    for raw_line in env_path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        os.environ.setdefault(key.strip(), value.strip().strip("\"'"))


load_local_env()


def live_tests_enabled():
    return os.environ.get("NEXTNOTES_RUN_LIVE_TESTS") == "1"


def required_config_available():
    return all(
        os.environ.get(name)
        for name in [
            "NEXTNOTES_TEST_SERVER",
            "NEXTNOTES_TEST_USERNAME",
            "NEXTNOTES_TEST_APP_PASSWORD",
        ]
    )


def skip_reason():
    if not live_tests_enabled():
        return "Set NEXTNOTES_RUN_LIVE_TESTS=1 to run live Nextcloud tests."
    if not required_config_available():
        return "Set NEXTNOTES_TEST_SERVER, NEXTNOTES_TEST_USERNAME, and NEXTNOTES_TEST_APP_PASSWORD."
    return ""


def normalize_server_url(value):
    url = value.strip()
    while url.endswith("/"):
        url = url[:-1]
    return url


@unittest.skipIf(bool(skip_reason()), skip_reason())
class LiveNextcloudNotesApiTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server_url = normalize_server_url(os.environ["NEXTNOTES_TEST_SERVER"])
        cls.username = os.environ["NEXTNOTES_TEST_USERNAME"]
        cls.app_password = os.environ["NEXTNOTES_TEST_APP_PASSWORD"]
        cls.created_note_ids = []
        cls.prefix = f"NextNotes live test {int(time.time())}"

    @classmethod
    def tearDownClass(cls):
        for note_id in reversed(cls.created_note_ids):
            try:
                cls.request("DELETE", f"/notes/{note_id}")
            except Exception:
                pass

    @classmethod
    def request(cls, method, path, body=None, headers=None, expected_status=None):
        url = cls.server_url + API_PREFIX + path
        data = None
        request_headers = {
            "Accept": "application/json",
            "Authorization": "Basic " + base64.b64encode(
                f"{cls.username}:{cls.app_password}".encode("utf-8")
            ).decode("ascii"),
        }
        if body is not None:
            data = json.dumps(body).encode("utf-8")
            request_headers["Content-Type"] = "application/json"
        if headers:
            request_headers.update(headers)

        request = urllib.request.Request(url, data=data, headers=request_headers, method=method)
        try:
            with urllib.request.urlopen(request, timeout=20) as response:
                response_body = response.read().decode("utf-8")
                return response.status, response.headers, cls.parse_json(response_body)
        except urllib.error.HTTPError as error:
            try:
                response_body = error.read().decode("utf-8")
                if expected_status is not None and error.code == expected_status:
                    return error.code, error.headers, cls.parse_json(response_body)
                raise
            finally:
                error.close()

    @staticmethod
    def parse_json(value):
        if not value:
            return None
        return json.loads(value)

    def create_note(self, title=None, content=None, category="", favorite=False):
        status, headers, note = self.request(
            "POST",
            "/notes",
            {
                "title": title or f"{self.prefix} create",
                "content": content or "Created by NextNotes live integration test.",
                "category": category,
                "favorite": favorite,
            },
        )
        self.assertGreaterEqual(status, 200)
        self.assertLess(status, 300)
        self.assertIsInstance(note, dict)
        self.assertGreater(int(note["id"]), 0)
        self.created_note_ids.append(int(note["id"]))
        return note

    def test_list_create_fetch_update_conflict_and_delete_note(self):
        status, headers, notes_before = self.request("GET", "/notes")
        self.assertGreaterEqual(status, 200)
        self.assertLess(status, 300)
        self.assertIsInstance(notes_before, list)

        created = self.create_note(
            title=f"{self.prefix} full flow",
            content="Initial live test content.",
            category="nextnotes-test",
            favorite=True,
        )
        note_id = int(created["id"])
        first_etag = str(created.get("etag") or "")
        self.assertTrue(first_etag)
        self.assertEqual(created.get("category"), "nextnotes-test")
        self.assertTrue(created.get("favorite"))

        status, headers, fetched = self.request("GET", f"/notes/{note_id}")
        self.assertEqual(status, 200)
        self.assertEqual(int(fetched["id"]), note_id)
        self.assertEqual(fetched.get("content"), "Initial live test content.")

        status, headers, updated = self.request(
            "PUT",
            f"/notes/{note_id}",
            {
                "title": f"{self.prefix} updated",
                "content": "Updated live test content.",
                "category": "nextnotes-test/updated",
                "favorite": False,
            },
            headers={"If-Match": self.format_etag(first_etag)},
        )
        self.assertEqual(status, 200)
        self.assertEqual(updated.get("content"), "Updated live test content.")
        self.assertEqual(updated.get("category"), "nextnotes-test/updated")
        self.assertFalse(updated.get("favorite"))

        status, headers, conflict = self.request(
            "PUT",
            f"/notes/{note_id}",
            {
                "title": f"{self.prefix} stale update",
                "content": "This stale update should be rejected.",
                "category": "nextnotes-test",
                "favorite": False,
            },
            headers={"If-Match": self.format_etag(first_etag)},
            expected_status=412,
        )
        self.assertEqual(status, 412)

        status, headers, delete_body = self.request("DELETE", f"/notes/{note_id}")
        self.assertGreaterEqual(status, 200)
        self.assertLess(status, 300)
        self.created_note_ids.remove(note_id)

        status, headers, missing = self.request(
            "GET",
            f"/notes/{note_id}",
            expected_status=404,
        )
        self.assertEqual(status, 404)

    def test_delete_already_gone_returns_known_missing_status(self):
        note = self.create_note(title=f"{self.prefix} delete twice")
        note_id = int(note["id"])

        status, headers, body = self.request("DELETE", f"/notes/{note_id}")
        self.assertGreaterEqual(status, 200)
        self.assertLess(status, 300)
        self.created_note_ids.remove(note_id)

        status, headers, body = self.request(
            "DELETE",
            f"/notes/{note_id}",
            expected_status=404,
        )
        self.assertEqual(status, 404)

    @staticmethod
    def format_etag(etag):
        value = str(etag)
        if value.startswith('"') or value.startswith('W/"'):
            return value
        return f'"{value}"'


if __name__ == "__main__":
    unittest.main(verbosity=2)
