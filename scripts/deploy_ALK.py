from brownie import Alaknanda
from scripts.get_acc import get_account

initial_supply = 100000000000000000000


def main():
    account = get_account()
    Alaknanda.deploy(initial_supply, {"from": account})
