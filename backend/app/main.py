"""API do Puppies: validação estrutural e transporte, sem regras do jogo."""

from typing import Annotated, Literal
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field, model_validator
from app import prolog

app = FastAPI(title="Puppies (Queens em Prolog)")
Celula = Annotated[int, Field(strict=True, ge=-1, le=1)]
Regiao = Annotated[int, Field(strict=True, ge=1, le=10)]


class PedidoGeracao(BaseModel):
    difficulty: Literal["easy", "hard"] = "easy"


class PedidoTabuleiro(BaseModel):
    board: list[list[Celula]]
    regions: list[list[Regiao]]

    @model_validator(mode="after")
    def validar_dimensoes(self):
        tamanho = len(self.regions)
        if not 4 <= tamanho <= 10 or len(self.board) != tamanho:
            raise ValueError("O tamanho deve estar entre 4 e 10.")
        if any(len(linha) != tamanho for linha in self.board + self.regions):
            raise ValueError(
                "As duas matrizes devem ser quadradas e do mesmo tamanho."
            )
        if {regiao for linha in self.regions for regiao in linha} != set(
            range(1, tamanho + 1)
        ):
            raise ValueError(
                "As regiões devem usar todos os identificadores de 1 a N."
            )
        return self


@app.post("/api/generate", response_model=PedidoTabuleiro)
def gerar(pedido: PedidoGeracao):
    return prolog.gerar(pedido.difficulty)


@app.post("/api/solve", response_model=PedidoTabuleiro)
def resolver(pedido: PedidoTabuleiro):
    solucao = prolog.resolver(pedido.regions, pedido.board)
    if solucao is None:
        raise HTTPException(
            422, "Este tabuleiro não tem solução. Confira os puppies e as exclusões."
        )
    return {"board": solucao, "regions": pedido.regions}


@app.post("/api/hint")
def dica(pedido: PedidoTabuleiro):
    resultado = prolog.dica(pedido.regions, pedido.board)
    if resultado == "completo":
        raise HTTPException(422, "O tabuleiro já está completo.")
    if resultado == "impossivel":
        raise HTTPException(422, "Este tabuleiro não tem solução.")
    if resultado == "ambiguo":
        raise HTTPException(
            422, "Não há puppy obrigatório: existem múltiplas soluções."
        )
    linha, coluna, valor = resultado
    return {"row": linha, "col": coluna, "value": valor}
