# test-ci-cd/test_hello.py
import sys
import os
sys.path.append(os.path.abspath(os.path.dirname(__file__)))  # để import được hello

from hello import hello

def test_hello():
    assert hello() == "Hello CI/CD!"