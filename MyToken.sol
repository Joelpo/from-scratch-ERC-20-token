pragma solidity ^0.5.10;

contract MyToken{
	// initialize key-value (address-balance object)
	mapping (address => uint256) private _balances;

	// msg.sender returns the address of the creator of the contract.
	// in this case, we want the initial supply of the coin to be sent to the admin. 
	constructor (uint256 initialSupply) public {
		_balances[msg.sender] = initialSupply;
	}


	// returns balance of address
	function balanceOf(address account) public view returns (uint256){
		return _balances[account];
	}


	function setBalance(address account, uint256 balance) internal {
		_balances[account] = balance;
	}

	function transfer(address beneficiary, uint256 amount) public returns (bool){
		_balances[msg.sender] -= amount;
		_balances[beneficiary] += amount;
		return true;
	}
}