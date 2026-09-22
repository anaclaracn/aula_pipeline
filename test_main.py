from main import soma

def test_soma_numeros_positivos():
    assert soma(2, 3) == 5

def test_soma_numeros_negativos():
    assert soma(-1, -1) == -2

def test_soma_zero():
    assert soma(5, 0) == 5
