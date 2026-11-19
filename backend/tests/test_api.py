"""Testes reais da integração HTTP com o motor Prolog."""

import pytest
from fastapi.testclient import TestClient
from app.main import app

cliente = TestClient(app)


@pytest.mark.parametrize("nivel,tamanho", [("easy", 5), ("hard", 8)])
def test_fluxo(nivel, tamanho):
    resposta = cliente.post("/api/generate", json={"difficulty": nivel})
    assert resposta.status_code == 200
    jogo = resposta.json()
    assert len(jogo["board"]) == tamanho
    resposta = cliente.post("/api/hint", json=jogo)
    assert resposta.status_code == 200
    dica = resposta.json()
    assert jogo["board"][dica["row"]][dica["col"]] == 0
    resposta = cliente.post("/api/solve", json=jogo)
    assert resposta.status_code == 200
    solucao = resposta.json()
    assert all(sum(linha) == 1 for linha in solucao["board"])
    assert solucao["board"][dica["row"]][dica["col"]] == 1
    assert cliente.post("/api/hint", json=solucao).status_code == 422
    jogo["board"][0] = [1] * tamanho
    for rota in ["solve", "hint"]:
        assert cliente.post(f"/api/{rota}", json=jogo).status_code == 422


@pytest.mark.parametrize(
    "dados",
    [
        {},
        {"board": [[0]], "regions": [[1]]},
        {"board": [[True] * 4] * 4, "regions": [[1] * 4, [2] * 4, [3] * 4, [4] * 4]},
        {"board": [[0] * 4] * 4, "regions": [[1] * 4] * 4},
    ],
)
def test_formato_invalido(dados):
    assert cliente.post("/api/solve", json=dados).status_code == 422


def test_nivel_invalido():
    assert (
        cliente.post("/api/generate", json={"difficulty": "medium"}).status_code
        == 422
    )
