from scripts.helpful_scripts import *
from brownie import CharityCasino, network, config, interface, accounts
from web3 import Web3
import time

gas_limit = Web3.toWei(0.001, "ether")


def deploy():
    account = get_account()
    matic_token = get_contract("matic_token").address
    matic_usd_price_feed = get_contract("matic_usd_price_feed").address
    vrf_coordinator = get_contract("vrf_coordinator").address
    link_token = get_contract("link_token").address
    charity_casino = CharityCasino.deploy(
        matic_token,
        matic_usd_price_feed,
        vrf_coordinator,
        link_token,
        config["networks"][network.show_active()]["fee"],
        config["networks"][network.show_active()]["keyhash"],
        {"from": account},
        publish_source=True,
    )
    bet = 10
    link_tx = fund_with_link(charity_casino.address)
    link_tx.wait(1)
    add_token = charity_casino.addAllowedTokens(link_token, {"from": account})
    app_tx = approve_erc20(bet, charity_casino.address, link_token, account)
    transferFrom(account, charity_casino.address, bet, link_token, charity_casino)

    # matic_tx = fund_with_matic(charity_casino.address)
    # matic_tx.wait(1)


def transferFrom(_from, _to, _amount, _erc20_address, _account):
    erc20 = interface.IERC20(_erc20_address)
    tx = erc20.transferFrom(_from, _to, _amount, {"from": _account})
    tx.wait(1)


def approve_erc20(_amount, _spender, _erc20_address, _account):
    print("Approving ERC20 Token")
    erc20 = interface.IERC20(_erc20_address)
    tx = erc20.approve(_spender, _amount, {"from": _account})
    tx.wait(1)
    print("ERC20 Approved")


def main():
    deploy()


# verified address: 0x26ea80F2B670949B91616c89D1796e0f2fB8B679
