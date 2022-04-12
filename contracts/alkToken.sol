//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

//the token has been deployed to rinkeby,you can check the token in etherscan at address 0x1Dd0AC77020B083d6cF0D116f89e3f711214fe1e

contract Alaknanda is ERC20 {
    constructor(uint256 initialSupply) public ERC20("Alaknanda", "ALK") {
        _mint(msg.sender, initialSupply);
    }
}
