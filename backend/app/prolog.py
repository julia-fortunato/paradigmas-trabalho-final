import json
import os
from pathlib import Path
import shutil
import subprocess

ARQUIVO_REGRAS = Path(__file__).parent.parent / "prolog" / "queens.pl"

try:
    import janus_swi as janus
    janus.consult(str(ARQUIVO_REGRAS))
except (ImportError, OSError):
    janus = None


def _swipl():
    encontrado = shutil.which("swipl")
    if encontrado:
        return encontrado
    caminho_windows = Path(os.environ.get("ProgramFiles", "C:/Program Files")) / "swipl" / "bin" / "swipl.exe"
    if caminho_windows.is_file():
        return str(caminho_windows)
    raise RuntimeError("SWI-Prolog não encontrado. Instale o swipl ou adicione-o ao PATH.")


def _consultar(objetivo):
    comando = [
        _swipl(), "-q", "-s", str(ARQUIVO_REGRAS),
        "-g", "use_module(library(http/json))," + objetivo + ",halt",
    ]
    resultado = subprocess.run(
        comando, capture_output=True, text=True, encoding="utf-8", timeout=120, check=True
    )
    return json.loads(resultado.stdout)


def _matriz(matriz):
    return json.dumps(matriz, separators=(",", ":"))


def gerar(dificuldade):
    if janus is None:
        if dificuldade not in ("easy", "hard"):
            raise ValueError("Dificuldade inválida.")
        return _consultar(
            f"queens:gerar({dificuldade},Regioes,Tabuleiro),"
            "json_write_dict(current_output,_{regions:Regioes,board:Tabuleiro})"
        )
    resultado = janus.query_once(
        "atom_string(Nivel, Nome), queens:gerar(Nivel, Regioes, Tabuleiro)",
        {"Nome": dificuldade},
    )
    return {"regions": resultado["Regioes"], "board": resultado["Tabuleiro"]}


def resolver(regioes, tabuleiro):
    if janus is None:
        return _consultar(
            f"(queens:resolver({_matriz(regioes)},{_matriz(tabuleiro)},Solucao)"
            "->json_write(current_output,Solucao);write(null))"
        )
    resultado = janus.query_once(
        "queens:resolver(Regioes, Tabuleiro, Solucao)",
        {"Regioes": regioes, "Tabuleiro": tabuleiro},
    )
    return resultado.get("Solucao") if resultado["truth"] else None


def dica(regioes, tabuleiro):
    if janus is None:
        return _consultar(
            f"queens:dica({_matriz(regioes)},{_matriz(tabuleiro)},Resultado),"
            "json_write(current_output,Resultado)"
        )
    return janus.query_once(
        "queens:dica(Regioes, Tabuleiro, Resultado)",
        {"Regioes": regioes, "Tabuleiro": tabuleiro},
    )["Resultado"]

def verificar(regioes, tabuleiro):
    if janus is None:
        resultado = _consultar(
            f"queens:verificar({_matriz(regioes)},{_matriz(tabuleiro)},Status,Conflitos),"
            "json_write_dict(current_output,_{status:Status,conflicts:Conflitos})"
        )
        return resultado["status"], resultado["conflicts"]
    resultado = janus.query_once(
        "queens:verificar(Regioes, Tabuleiro, Status, Conflitos)",
        {"Regioes": regioes, "Tabuleiro": tabuleiro},
    )
    return resultado["Status"], resultado["Conflitos"]

