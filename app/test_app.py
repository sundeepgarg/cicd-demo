import pytest
from app import app as flask_app


@pytest.fixture
def client():
    flask_app.testing = True
    return flask_app.test_client()


def test_hello_returns_200(client):
    r = client.get("/")
    assert r.status_code == 200


def test_hello_has_message(client):
    r = client.get("/")
    data = r.get_json()
    assert "message" in data
    assert "Hello" in data["message"]


def test_health_returns_healthy(client):
    r = client.get("/health")
    assert r.status_code == 200
    data = r.get_json()
    assert data["status"] == "healthy"
