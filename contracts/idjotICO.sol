// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// if ico fails there owner's will get 95% of their ether back since 5% will be charges including gas fees and ICO processing fees
contract idjotICO is ERC20 {
    address public admin;
    address payable public depositAddress;

    // if ICO is successfull only then the tokens will be transfered to the owner wallet
    // else ether's will be reversed back to the owner
    mapping(address => uint) public idjotBalance;

    // keeps a record of ether invested by every wallet address
    mapping(address => uint) public investedAmt;

    // 8220 ether to find if ICO was a success or not
    uint256 public hardCap = 8220000000000000000000;

    // tracks the raisedAmount
    uint256 public raisedAmount;

    // ICO sale starts immediately as the contract is deployed
    uint256 public saleStart = block.timestamp;
    // ICO sale ends after one week
    uint256 public saleEnd = block.timestamp + 604800;

    // max investment is 5 ether
    uint256 public maxInvestment = 5000000000000000000;
    // min investment is 0.05 ether
    uint256 public minInvestment = 50000000000000000;

    uint256 public tokensMinted;

    uint256 public preSaleAmt = 30000000 * 10 ** decimals();
    uint256 public seedSaleAmt = 50000000 * 10 ** decimals();
    uint256 public finalSaleAmt = 20000000 * 10 ** decimals();

    uint256 public preTokens = 30000000 * 10 ** decimals();
    uint256 public seedTokens = 0;
    uint256 public finalTokens = 0;

    // enum to track the state of the contract
    enum IcoState { 
        beforeStart,
        running, 
        afterEnd, 
        halted }
    IcoState public icoState;

    // enum to track the sale of the contract
    enum SaleState { 
        pre_Sale, 
        seed_Sale, 
        final_Sale, 
        Sale_END 
    }
    SaleState public saleState;

    modifier onlyAdmin() {
        require(msg.sender == admin, "Sender must be an admin");
        _;
    }

    constructor(
        address payable _deposit
    ) ERC20("IdjotICO", "WIN"){
        depositAddress = _deposit;
        admin = msg.sender;
        icoState = IcoState.beforeStart;
        _mint(admin, 100000000 * 10 ** decimals());
        idjotBalance[admin] = 100000000 * 10 ** decimals();
    }

    // emergency stop for IdjotICO
    function haltICO() public onlyAdmin {
        icoState = IcoState.halted;
    }

    // resuming IdjotICO
    function resumeICO() public onlyAdmin {
        icoState = IcoState.running;
    }

    // function to change deposit address in case the original one got issues
    function changeDepositAddress(
        address payable _newDeposit
    ) public onlyAdmin {
        depositAddress = _newDeposit;
    }

    // fetch the current state of IdjotICO
    function getCurrentICOState() public payable returns(IcoState) {
        if (icoState == IcoState.halted) {
            return IcoState.halted;
        } else if (block.timestamp < saleStart) {
            return IcoState.beforeStart;
        } else if (block.timestamp >= saleStart && block.timestamp <= saleEnd) {
            return IcoState.running;
        } else {
            return IcoState.afterEnd;
        }
    }

    // function to check the raised amount of ether
    function checkRaisedAmt() internal view returns(uint256) {
        return raisedAmount;
    }

    // investing function
    function invest() public payable returns(bool) {
        
        icoState = getCurrentICOState();
        // investment only possible if IcoState is running
        require(icoState == IcoState.running, "idjotICO is not in running state");

        // address must not have invested previously        
        require(idjotBalance[msg.sender] == 0, "User must invest only once according to our policy");
                
        require(msg.value >= minInvestment && msg.value <= maxInvestment, "Investment amount must be more than 0.05 ETH and less than 5 ETH");

        // hardcap not reached
        require(raisedAmount + msg.value <= hardCap, "hardCap reached");
        raisedAmount += msg.value;

        // tokens calculation
        uint256 tokens = buyTokens(msg.value);

        // add tokens to investor balance from founder balance
        idjotBalance[msg.sender] += tokens;
        idjotBalance[admin] -= tokens;

        investedAmt[msg.sender] += msg.value;
        
        return true;          
    }

    // function to buyTokens 
    function buyTokens(
        uint256 msgValue
    ) internal returns(uint256) {
        if(saleState == SaleState.pre_Sale) {
            uint256 _tokens = preSale(msgValue);
            return _tokens;
        } else if (saleState == SaleState.seed_Sale) {
            uint256 _tokens = seedSale(msgValue);
            return _tokens;
        } else {
            uint256 _tokens = finalSale(msgValue);
            return _tokens;
        }
    }

    // calculate tokens provided the sale is preSale
    function preSale(
        uint _msgValue
    ) internal returns(uint256 tokens) {
        uint256 _tokens = 0;
        // calculated considering eth value as 2500$
        _tokens = _msgValue * 25 * 10 ** 4;
        if((preTokens + _tokens) >= preSaleAmt){
            // find the amount required to fill up the pre sale amount
            // newValue is the value of tokens needed to fill the rest of the presale
            uint256 newValue = (preSaleAmt - preTokens)/(25 * 10 ** 4);
            
            // update the preTokens 
            preTokens = preSaleAmt;
            // update the ico State
            saleState = SaleState.seed_Sale; 

            // call seed Sale
            return seedSale(_msgValue-newValue);
        } else {
            preTokens += _tokens;
            return _tokens;
        }
    }

    // calculate tokens provided the sale is seed Sale
    function seedSale(
        uint256 _msgValue
    ) internal returns(uint256 tokens) {
        uint256 _tokens = 0;
        // calculated considering eth value as 2500$
        _tokens = _msgValue * 625 * 10 ** 2;
        if((seedTokens + _tokens) >= seedSaleAmt){
            // find the amount required to fill up the seed sale amount
            uint256 newValue = (seedSaleAmt - seedTokens)/(625 * 10 ** 2);
            
            // update the seedTokens 
            seedTokens = seedSaleAmt;
            // update the ico State
            saleState = SaleState.final_Sale; 

            // call seed Sale
            return finalSale(_msgValue-newValue);
        } else {
            seedTokens += _tokens;
            return _tokens;
        }
    }

    // calculate tokens provided the sale is final Sale
    function finalSale(
        uint256 _msgValue
    ) internal returns(uint256 tokens) {
        uint256 _tokens = 0;
        // calculated considering eth value as 2500$ and 1 token = 1$ for final sale
        _tokens = _msgValue * 25 * 10 ** 2;
        if((finalTokens + _tokens) >= finalSaleAmt){
            // find the amount required to fill up the final sale amount
            // uint256 newValue = (finalSaleAmt - finalTokens)/(25 * 10 ** 2);
            
            // update the finalTokens 
            finalTokens = finalSaleAmt;
            // update the ico State
            saleState = SaleState.Sale_END; 
        } else {
            finalTokens += _tokens;
            return _tokens;
        }
    }

    // function to check if the ico was a success
    function successCheck() public view returns(bool) {
        require(block.timestamp >= saleEnd, "idjotICO hasn't expired yet, Try after saleEnd!");

        if(checkRaisedAmt() >= hardCap) {
            return true;
        } else {
            return false;
        }        
    }
    
    function withdraw() public payable {
        require(block.timestamp >= saleEnd);

        // if it was a success then transfer all the eth received to the deposit address and transfer WIN tokens to their wallet
        if(successCheck() == true) {         
            // transfer WIN tokens to their owners wallet
            _transfer(admin, msg.sender, idjotBalance[msg.sender]);
            idjotBalance[msg.sender] = 0;

        }
        // if not then revert the eth to the concerned authority and empty their idjotBalances
        else {
            payable(msg.sender).transfer(investedAmt[msg.sender]);
            investedAmt[msg.sender] = 0;
        }
    }

    // only applicable if the idjotICO is success and the sale has ended
    function transferEth() public payable onlyAdmin {
        require(block.timestamp >= saleEnd, "idjotICO hasn't expired yet, Try after saleEnd!");
        require(successCheck() == true, "idjotICO was not a success");

        // transfer all the ether received to the deposit address
        payable(depositAddress).transfer(raisedAmount);
    }
}

// calculation:
/*
To purchase all 100 million tokens, you need to calculate the total amount in US dollars and ETH for each sale.

For the pre-sale tokens:
The total amount in US dollars would be $0.01 x 30 million = $300,000
The total amount in ETH would be $300,000 / $2500 (1 ETH = $2500) = 120 ETH

For the seed sale tokens:
The total amount in US dollars would be $0.02 x 50 million = $1 million
The total amount in ETH would be $1 million / $2500 (1 ETH = $2500) = 400 ETH

For the final sale tokens:
The total amount in US dollars would be $1 x 20 million = $20 million
The total amount in ETH would be $20 million / $2500 (1 ETH = $2500) = 8000 ETH

So, in total, you will need $300,000 + $1 million + $20 million = $21.3 million in US dollars, or 120 ETH + 400 ETH + 8000 ETH = 8220 ETH to purchase all 100 million tokens.
*/