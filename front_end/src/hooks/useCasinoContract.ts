import { useContractCall, useEthers } from "@usedapp/core"
import CharityCasino from "../chain-info/contracts/CharityCasino.json"
import { utils, constants } from "ethers"
import networkMapping from "../chain-info/deployments/map.json"


export const useCasinoContract = (tokenAddress, amount) => {
    const { account, chainId } = useEthers()
    const { abi } = CharityCasino
    const CharityCasinoContractAddress = chainId ? networkMapping[String(chainId)]["CharityCasino"][0] : constants.AddressZero
    const CharityCasinoInterface = new utils.Interface(abi)
    useContractCall({
        abi: CharityCasinoInterface,
        address: CharityCasinoContractAddress,
        method: "payPlayer",
        args: [tokenAddress, account, amount],
    })

  
}