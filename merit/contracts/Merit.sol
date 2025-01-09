// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./ERC20.sol";
import "./SafeMath.sol";
import "./Ownable.sol";

contract Merit is ERC20, Ownable {
    using SafeMath for uint;

    event Mint(address indexed to, uint256 amount);

    constructor()ERC20("Merit Hoc", "MERIT") Ownable(msg.sender){}

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
        emit Mint(to, amount);
    }


    function decimals() public view virtual override returns (uint8) {
        return 6;
    }

}
