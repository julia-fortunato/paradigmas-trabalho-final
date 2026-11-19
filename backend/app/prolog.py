"""Integração Janus: todas as decisões do jogo pertencem ao Prolog."""

from pathlib import Path
import janus_swi as janus

janus.consult(str(Path(__file__).parent.parent / "prolog" / "queens.pl"))


def gerar(dificuldade):
    resultado = janus.query_once(
        "atom_string(Nivel, Nome), queens:gerar(Nivel, Regioes, Tabuleiro)",
        {"Nome": dificuldade},
    )
    return {"regions": resultado["Regioes"], "board": resultado["Tabuleiro"]}


def resolver(regioes, tabuleiro):
    resultado = janus.query_once(
        "queens:resolver(Regioes, Tabuleiro, Solucao)",
        {"Regioes": regioes, "Tabuleiro": tabuleiro},
    )
    return resultado.get("Solucao") if resultado["truth"] else None


def dica(regioes, tabuleiro):
    return janus.query_once(
        "queens:dica(Regioes, Tabuleiro, Resultado)",
        {"Regioes": regioes, "Tabuleiro": tabuleiro},
    )["Resultado"]
