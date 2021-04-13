pragma solidity ^0.5.10;

/*
ERC-20 Implementation
Admin gets initial supply. 
Admin can send funds to any address (transfer) and also allocate (approve) a spending amount for other addresses to spend (transferFrom)
*/
contract Administrable {
	address private _admin;

	event AdminshipTransferred(address indexed currentAdmin, address indexed newAdmin);

	constructor() internal {
		_admin = msg.sender;
		emit AdminshipTransferred(address(0),_admin);
	}

	function getAdmin() public view returns (address){
		return _admin;
	}

	modifier onlyAdmin(){
		require(msg.sender == _admin, "Executer must be the current admin");
		_;
	}

	function transferAdminship(address newAdmin) public onlyAdmin {
		emit AdminshipTransferred(_admin, newAdmin);
		_admin = newAdmin;

	}

}


contract MyTokenAdvanced is MyToken, Administrable {

	constructor (uint256 initialSupply, string memory tokenName, string memory tokenSymbol, uint8 decimalUnits, address newAdmin) public {
		// We use 0 as initial supply so that the balance of the sender stays zero. The msg.sender can appoint someone else as admin. 
		MyToken(0, tokenName, tokenSymbol, decimalUnits);
		if(newAdmin != address(0) && newAdmin != msg.sender){
			transferAdminship(newAdmin);
		}
		setBalance(getAdmin(), initialSupply);
		setTotalSupply = initialSupply;
	}

}



contract MyToken {
	// initialize key-value (address-balance object)
	mapping (address => uint256) private _balances;
	mapping (address => mapping (address => uint256)) private _allowance;
	
	string private _name;
	string private _symbol;
	uint8 private _decimals;
	uint256 private _totalSupply;
	
	event Transfer(address indexed from, address indexed to, uint256 value);
	event Approval(address indexed owner, address indexed spender, uint256 value);

	// msg.sender returns the address of the creator of the contract.
	// in this case, we want the initial supply of the coin to be sent to the admin. 
	constructor (uint256 initialSupply, string memory tokenName, string memory tokenSymbol, uint8 decimalUnits) public {
		_balances[msg.sender] = initialSupply;
		_totalSupply = initialSupply;
		_decimals = decimalUnits;
		_symbol = tokenSymbol;
		_name = tokenName;
	}
	
	function getSymbol() public view returns (string memory){
	    return _symbol;
	}
	
	function getName() public view returns (string memory){
	    return _name;
	}
	
	function getDecimals() public view returns (uint8){
	    return _decimals;
	}
	
	function getTotalSupply() public view returns (uint256){
	    return _totalSupply;
	}
	
	function setTotalSupply (uint256 totalAmount) internal {
	    _totalSupply = totalAmount;
	}

	// returns balance of address
	function balanceOf(address account) public view returns (uint256){
		return _balances[account];
	}

	function setBalance(address account, uint256 balance) internal {
		_balances[account] = balance;
	}
	
	function getAllowance(address owner, address spender) public view returns (uint256) {
	    return _allowance[owner][spender];
	}
	
	function setAllowance(address owner, address spender, uint256 amount) internal{
        _allowance[owner][spender] = amount;
	}
	
	function approve(address spender, uint256 amount) public returns (bool success){
	    require(spender != address(0) , "Spender address cannot be zero");
	    _allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
	    return true;
	}

	function transfer(address beneficiary, uint256 amount) public returns (bool){
	    require(beneficiary != address(0), "Beneficiary address cannot be zero");
	    require(_balances[msg.sender] >= amount, "Sender does not have enough balance");
	    require(_balances[beneficiary] + amount > _balances[beneficiary], "Addition Overflow"); //prevent addition overflow
		_balances[msg.sender] -= amount;
		_balances[beneficiary] += amount;
        emit Transfer(msg.sender, beneficiary, amount);
		return true;
	}
	
	function transferFrom(address sender, address beneficiary, uint256 amount) public returns (bool){
        require(beneficiary != address(0), "Beneficiary address cannot be zero");
        require(sender != address(0), "Sender address cannot be zero");
        require(amount <= _allowance[sender][msg.sender], "Allowance is not enough");
        require(_balances[sender] >= amount, "Sender does not have enough balance");
	    require(_balances[beneficiary] + amount > _balances[beneficiary], "Addition Overflow"); //prevent addition overflow
	    _balances[sender] -= amount;
	    _allowance[sender][msg.sender] -= amount;
	    _balances[beneficiary] += amount;
	    emit Transfer(sender, beneficiary, amount);
	    
	    return true;
	}
}