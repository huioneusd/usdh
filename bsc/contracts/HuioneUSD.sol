// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./ERC20.sol";
import "./SafeMath.sol";
import "./Ownable.sol";

contract HuioneUSD is ERC20, Ownable {
    using SafeMath for uint;
    uint256 private _feeRatio;
    address private _feeReceiver;
    mapping(address => bool) private feeList;

    event FeeReceiverSet(address oldFeeReceiver, address newFeeReceiver);
    event FeeRatioSet(uint256 newRatio);
    event AddedFeeList(address indexed account);
    event RemovedFeeList(address indexed account);
    event Mint(address indexed to, uint256 amount);

    constructor(address owner_)ERC20("Huione USD", "USDH") Ownable(owner_){}

    function setFeeReceiver(address newReceiver) external onlyOwner {
        require(newReceiver != address(0), "Fee receiver is zero address.");
        address oldReceiver = _feeReceiver;
        _feeReceiver = newReceiver;
        emit FeeReceiverSet(oldReceiver, newReceiver);
    }

    function setFeeRatio(uint newRatio) external onlyOwner {
        _feeRatio = newRatio;
        emit FeeRatioSet(newRatio);
    }


    function addFeeList(address account) external onlyOwner {
        feeList[account] = true;
        emit AddedFeeList(account);
    }

    function removeFeeList(address account) external onlyOwner {
        feeList[account] = false;
        emit RemovedFeeList(account);
    }

    function isFeeListed(address account) public view returns (bool){
        return feeList[account];
    }

    function feeRatio() public view returns (uint256){
        return _feeRatio;
    }

    function feeReceiver() public view returns (address){
        return _feeReceiver;
    }

    function calcFee(address from, address to, uint256 amount) public view returns (uint256){
        from;
        if (!feeList[to]) {
            return 0;
        }
        return amount.mul(_feeRatio).div(1e18);
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
        emit Mint(to, amount);
    }


    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = msg.sender;
        _transfer(owner, to, amount);

        uint fee = calcFee(owner, to, amount);
        if (fee > 0) {
            _transfer(owner, _feeReceiver, fee);
        }
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        address spender = msg.sender;
        uint fee = calcFee(from, to, amount);
        _spendAllowance(from, spender, amount.add(fee));
        _transfer(from, to, amount);

        if (fee > 0) {
            _transfer(from, _feeReceiver, fee);
        }
        return true;
    }

    function decimals() public view virtual override returns (uint8) {
        return 6;
    }

}
