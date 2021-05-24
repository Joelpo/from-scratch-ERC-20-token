pragma solidity ^0.5.10;

/// @author joelpo

/**
@title AdministrableToken : From scratch ERC-20 token implementation
@dev Admin gets initial supply and can send funds to any address (transfer) and also allocate (approve) a spending amount for other addresses to spend (transferFrom)
Token Minting by the admin is possible. 
Admin can freeze an account.
Token is buyable and sellable according to admin's price. 
*/
contract AdministrableToken is MyToken, Administrable {
    mapping(address => bool) private _frozenAccounts;
    mapping(address => uint256) private _pendingWithdrawals;

    uint256 private _sellPrice = 1; //ether per token
    uint256 private _buyPrice = 1; //ether per token

    event FrozenFund(address indexed target, bool frozen);

    // We use 0 as initial supply so that the balance of the sender stays zero. The msg.sender can appoint someone else as admin.
    constructor(
        uint256 initialSupply,
        string memory tokenName,
        string memory tokenSymbol,
        uint8 decimalUnits,
        address newAdmin
    ) public MyToken(0, tokenName, tokenSymbol, decimalUnits) {
        if (newAdmin != address(0) && newAdmin != msg.sender) {
            transferAdminship(newAdmin);
        }
        setBalance(getAdmin(), initialSupply);
        setTotalSupply(initialSupply);
    }

    function getSellPrice() public view returns (uint256) {
        return _sellPrice;
    }

    function getBuyPrice() public view returns (uint256) {
        return _buyPrice;
    }

    function setPrices(uint256 newSellPrice, uint256 newBuyPrice)
        public
        onlyAdmin
    {
        require(newSellPrice > 0, "Price cannot be zero");
        require(newBuyPrice > 0, "Price cannot be zero");

        _buyPrice = newBuyPrice;
        _sellPrice = newSellPrice;
    }

    function mintToken(address target, uint256 mintedAmount) public onlyAdmin {
        require(
            balanceOf(target) + mintedAmount > balanceOf(target),
            "Addition Overflow"
        );
        require(
            getTotalSupply() + mintedAmount > getTotalSupply(),
            "Addition Overflow"
        );

        setBalance(target, balanceOf(target) + mintedAmount);
        setTotalSupply(getTotalSupply() + mintedAmount);
        emit Transfer(msg.sender, target, mintedAmount);
    }

    //updates _frozenAccounts mapping
    function freezeAccount(address target, bool freeze) public onlyAdmin {
        _frozenAccounts[target] = freeze;
        emit FrozenFund(target, freeze);
    }

    //overrides transfer from MyToken to implement freezing.
    function transfer(address beneficiary, uint256 amount)
        public
        returns (bool)
    {
        require(
            beneficiary != address(0),
            "Beneficiary address cannot be zero"
        );
        require(
            balanceOf(msg.sender) >= amount,
            "Sender does not have enough balance"
        );
        require(
            balanceOf(beneficiary) + amount > balanceOf(beneficiary),
            "Addition Overflow"
        ); //prevent addition overflow
        require(!(_frozenAccounts[msg.sender]), "Address funds are frozen");
        setBalance(msg.sender, balanceOf(msg.sender) - amount);
        setBalance(beneficiary, balanceOf(beneficiary) + amount);
        emit Transfer(msg.sender, beneficiary, amount);

        return true;
    }

    //overrides transferFrom from MyToken to implement freezing.
    function transferFrom(
        address sender,
        address beneficiary,
        uint256 amount
    ) public returns (bool) {
        require(
            beneficiary != address(0),
            "Beneficiary address cannot be zero"
        );
        require(sender != address(0), "Sender address cannot be zero");
        require(
            amount <= getAllowance(sender, msg.sender),
            "Allowance is not enough"
        );
        require(
            balanceOf(sender) >= amount,
            "Sender does not have enough balance"
        );
        require(
            balanceOf(beneficiary) + amount > balanceOf(beneficiary),
            "Addition Overflow"
        ); //prevent addition overflow
        setBalance(sender, balanceOf(sender) - amount);
        setAllowance(
            sender,
            msg.sender,
            getAllowance(sender, msg.sender) - amount
        );
        setBalance(beneficiary, balanceOf(beneficiary) + amount);
        emit Transfer(sender, beneficiary, amount);

        return true;
    }

    //payable modifier indicates ether transactions are manageable by the function.
    function buy() public payable {
        uint256 amount = (msg.value / (1 ether)) / _buyPrice;
        address thisContractAddress = address(this);

        require(
            balanceOf(thisContractAddress) >= amount,
            "Contract does not have enough tokens"
        );
        require(
            balanceOf(msg.sender) + amount > balanceOf(msg.sender),
            "Addition overflow"
        );

        setBalance(
            thisContractAddress,
            balanceOf(thisContractAddress) - amount
        );
        setBalance(msg.sender, balanceOf(msg.sender) + amount);

        emit Transfer(thisContractAddress, msg.sender, amount);
    }

    function sell(uint256 amount) public payable {
        address thisContractAddress = address(this);

        require(
            balanceOf(msg.sender) >= amount,
            "Seller does not have enough tokens"
        );
        require(
            balanceOf(thisContractAddress) + amount >
                balanceOf(thisContractAddress),
            "Addition overflow"
        );

        setBalance(msg.sender, balanceOf(msg.sender) - amount);
        setBalance(
            thisContractAddress,
            balanceOf(thisContractAddress) + amount
        );

        uint256 saleProceed = amount * _sellPrice * (1 ether);
        _pendingWithdrawals[msg.sender] += saleProceed;
        emit Transfer(msg.sender, thisContractAddress, amount);
    }

    function withdraw() public {
        uint256 amount = _pendingWithdrawals[msg.sender];
        _pendingWithdrawals[msg.sender] = 0;
        msg.sender.transfer(amount);
    }
}

contract Administrable {
    address private _admin;

    event AdminshipTransferred(
        address indexed currentAdmin,
        address indexed newAdmin
    );

    constructor() internal {
        _admin = msg.sender;
        emit AdminshipTransferred(address(0), _admin);
    }

    function getAdmin() public view returns (address) {
        return _admin;
    }

    modifier onlyAdmin() {
        require(msg.sender == _admin, "Executer must be the current admin");
        _;
    }

    function transferAdminship(address newAdmin) public onlyAdmin {
        emit AdminshipTransferred(_admin, newAdmin);
        _admin = newAdmin;
    }
}

contract MyToken {
    // initialize key-value (address-balance object)
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowance;

    string private _name;
    string private _symbol;
    uint8 private _decimals;
    uint256 private _totalSupply;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    // msg.sender returns the address of the creator of the contract.
    // in this case, we want the initial supply of the coin to be sent to the admin.
    constructor(
        uint256 initialSupply,
        string memory tokenName,
        string memory tokenSymbol,
        uint8 decimalUnits
    ) public {
        _balances[msg.sender] = initialSupply;
        _totalSupply = initialSupply;
        _decimals = decimalUnits;
        _symbol = tokenSymbol;
        _name = tokenName;
    }

    function getSymbol() public view returns (string memory) {
        return _symbol;
    }

    function getName() public view returns (string memory) {
        return _name;
    }

    function getDecimals() public view returns (uint8) {
        return _decimals;
    }

    function getTotalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function setTotalSupply(uint256 totalAmount) internal {
        _totalSupply = totalAmount;
    }

    // returns balance of address
    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function setBalance(address account, uint256 balance) internal {
        _balances[account] = balance;
    }

    function getAllowance(address owner, address spender)
        public
        view
        returns (uint256)
    {
        return _allowance[owner][spender];
    }

    function setAllowance(
        address owner,
        address spender,
        uint256 amount
    ) internal {
        _allowance[owner][spender] = amount;
    }

    function approve(address spender, uint256 amount)
        public
        returns (bool success)
    {
        require(spender != address(0), "Spender address cannot be zero");
        _allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);

        return true;
    }

    function transfer(address beneficiary, uint256 amount)
        public
        returns (bool)
    {
        require(
            beneficiary != address(0),
            "Beneficiary address cannot be zero"
        );
        require(
            _balances[msg.sender] >= amount,
            "Sender does not have enough balance"
        );
        require(
            _balances[beneficiary] + amount > _balances[beneficiary],
            "Addition Overflow"
        ); //prevent addition overflow
        _balances[msg.sender] -= amount;
        _balances[beneficiary] += amount;
        emit Transfer(msg.sender, beneficiary, amount);

        return true;
    }

    function transferFrom(
        address sender,
        address beneficiary,
        uint256 amount
    ) public returns (bool) {
        require(
            beneficiary != address(0),
            "Beneficiary address cannot be zero"
        );
        require(sender != address(0), "Sender address cannot be zero");
        require(
            amount <= _allowance[sender][msg.sender],
            "Allowance is not enough"
        );
        require(
            _balances[sender] >= amount,
            "Sender does not have enough balance"
        );
        require(
            _balances[beneficiary] + amount > _balances[beneficiary],
            "Addition Overflow"
        ); //prevent addition overflow
        _balances[sender] -= amount;
        _allowance[sender][msg.sender] -= amount;
        _balances[beneficiary] += amount;
        emit Transfer(sender, beneficiary, amount);

        return true;
    }
}
