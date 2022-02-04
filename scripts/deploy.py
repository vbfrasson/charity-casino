from scripts.helpful_scripts import *
from brownie import CharityCasino


def deploy():
    account = get_account()
    charity_casino = CharityCasino.deploy(
        get_contract("matic_token").address,
        get_contract("matic_usd_price_feed").address,
        get_contract("vrf_coordinator").address,
        get_contract("link_token").address,
        config["networks"][network.show_active()]["fee"],
        config["networks"][network.show_active()]["keyhash"],
        {"from": account},
        publish_source=True,
    )


def main():
    deploy()
