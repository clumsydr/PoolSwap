//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract PoolToken is ERC20 {
    constructor() ERC20("Pool Token", "PQ") {}

    function addLiquidity(address _address, uint _amount) public {
        _mint(_address, _amount);
    }

    function removeLiquidity(address _address, uint _amount) public {
        _burn(_address, _amount);
    }
}


contract Pair {

    uint transferFee;
    uint invariant;
    ERC20 token;
    PoolToken poolToken;

    constructor(uint _transferFee, address _token) {
        transferFee = _transferFee;
        token = ERC20(_token);
        poolToken = new PoolToken();
    }


    modifier etherSent() { require (msg.value != 0, "Please send a non-zero amount of Ether"); _; }

    function _poolEmpty() view public returns(bool) { return token.balanceOf(address(this)) == 0; }

    modifier poolisEmpty() { require(_poolEmpty(), "Exchange has already been Intialised"); _; }

    modifier poolNotEmpty() { require(!_poolEmpty(), "Please setup the Exchange using the createExchange() function"); _; }


    function createExchange(uint tokenAmount) payable public etherSent poolisEmpty {
        require(token.allowance(msg.sender, address(this)) >= tokenAmount, "Insufficient Tokens");
        require(token.transferFrom(msg.sender, address(this), tokenAmount), "Tokens could not be transferred.");

        invariant = address(this).balance * token.balanceOf(address(this));
        poolToken.addLiquidity(msg.sender, msg.value / 100);
    }

    function deposit() payable public etherSent poolNotEmpty {
        uint initialEthAmount = address(this).balance - msg.value;
        uint tokenAmount = (token.balanceOf(address(this)) * msg.value) / initialEthAmount;
        require(token.allowance(msg.sender, address(this)) >= tokenAmount, "Insufficient Tokens");
        require(token.transferFrom(msg.sender, address(this), tokenAmount), "Tokens could not be transferred.");

        invariant = address(this).balance * token.balanceOf(address(this));
        poolToken.addLiquidity(msg.sender, (poolToken.totalSupply() * msg.value) / initialEthAmount);
    }

    function withdraw(uint amount) public poolNotEmpty {
        require(poolToken.balanceOf(msg.sender) >= amount, "Insufficient Pool Tokens");

        payable(msg.sender).transfer((address(this).balance * amount) / poolToken.totalSupply());
        token.transfer(msg.sender, (token.balanceOf(address(this)) * amount) / poolToken.totalSupply());

        invariant = address(this).balance * token.balanceOf(address(this));
        poolToken.removeLiquidity(msg.sender, amount);
    }

    function checkLiquidity() view public poolNotEmpty returns(uint) { return poolToken.balanceOf(msg.sender); }

    function buyTokens() payable public etherSent returns(uint) {
        uint initialTokenPool = token.balanceOf(address(this));
        uint finalTokenPool = invariant / (address(this).balance - ((msg.value * transferFee)/10000));

        require(token.transfer(msg.sender, (initialTokenPool - finalTokenPool)), "Tokens could not be transferred.");
        invariant = address(this).balance * token.balanceOf(address(this));
        return (initialTokenPool - finalTokenPool);
    }

    function sellTokens(uint tokenAmount) payable public returns(uint) {
        uint intialWeiPool = address(this).balance - msg.value;

        require(token.allowance(msg.sender, address(this)) >= tokenAmount, "Insufficient Tokens");
        require(token.transferFrom(msg.sender, address(this), tokenAmount), "Tokens could not be transferred.");
        
        uint finalWeiPool = invariant/(token.balanceOf(address(this)) - (tokenAmount*transferFee/10000));
        payable(msg.sender).transfer(intialWeiPool - finalWeiPool);
        invariant = address(this).balance * token.balanceOf(address(this));
        return intialWeiPool - finalWeiPool;
    }
    
}


contract tokenOne is ERC20 {
    constructor() ERC20("tokenOne", "T1") { _mint(msg.sender, 10000); }
}

contract tokenTwo is ERC20 {
    constructor() ERC20("tokenTwo", "T2") { _mint(msg.sender, 10000); }
}


contract Exchange {
    mapping(ERC20 => Pair) Pools;

    function addPool(address _pool, address _token) public {
        Pools[ERC20(_token)] = Pair(_pool);
    }

    function exchange(uint amount, address _tokenOne, address _tokenTwo) payable public  {
        require(ERC20(_tokenOne).allowance(msg.sender, address(this)) >= amount, "Insufficient Tokens");
        require(ERC20(_tokenOne).transferFrom(msg.sender, address(this), amount), "Tokens could not be transferred.");

        uint weiAmount = Pools[ERC20(_tokenOne)].sellTokens(amount);

        Pools[ERC20(_tokenTwo)].buyTokens{value : weiAmount}();
        ERC20(_tokenTwo).transfer(msg.sender, ERC20(_tokenTwo).balanceOf(address(this)));
    }
}