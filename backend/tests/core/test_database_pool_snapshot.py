from app.core import database


class _DummyPool:
    def __init__(self):
        self._max_overflow = 40

    def size(self):
        return 20

    def checkedout(self):
        return 1

    def overflow(self):
        # SQLAlchemy may report negative overflow while warming up the pool.
        return -19


class _DummyEngine:
    def __init__(self):
        self.pool = _DummyPool()


def test_get_db_pool_snapshot_handles_negative_overflow(monkeypatch):
    monkeypatch.setattr(database, "is_database_configured", lambda: True)
    monkeypatch.setattr(database, "get_engine", lambda: _DummyEngine())

    snapshot = database.get_db_pool_snapshot()

    assert snapshot["pool_size"] == 20
    assert snapshot["checked_out"] == 1
    assert snapshot["overflow"] == -19
    assert snapshot["max_overflow_limit"] == 40
    assert snapshot["capacity"] == 60
    assert snapshot["occupancy_ratio"] == 1 / 60
