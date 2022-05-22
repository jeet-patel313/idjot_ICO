pragma solidity >= 0.7.0 < 0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "hardhat/console.sol";

// if ico fails there owner's will get 95% of their ether back since 5% will be charges including gas fees and ICO processing fees
contract idjotICO is ERC20 {
    address public admin;
    address payable public depositAddress;

    // if ICO is successfull only then the tokens will be transfered to the owner wallet
    // else ether's will be reversed back to the owner
    mapping(address => uint) public idjotBalance;

    // keeps a record of ether invested by every wallet address
    mapping(address => uint) public investedAmt;

    // price of 1WIN token is 0.001 ether
    uint256 public tokenPrice = 1000000000000000;

    // 300 ether to find if ICO was a success or not
    // uint256 public hardCap = 300000000000000000000;
    uint256 public hardCap = 8000000000000000000;

    uint256 public raisedAmount;

    // ICO sale starts immediately as the contract is deployed
    uint256 public saleStart = block.timestamp;
    // ICO sale ends after one week
    // uint256 public saleEnd = block.timestamp + 604800;
    uint256 public saleEnd = block.timestamp + 120; 

    // max investment is 5 ether
    uint256 public maxInvestment = 5000000000000000000;
    // min investment is 0.05 ether
    uint256 public minInvestment = 50000000000000000;

    enum IcoState { beforeStart, running, afterEnd, halted }
    IcoState public icoState;

    modifier onlyAdmin() {
        require(msg.sender == admin, "Sender must be an admin");
        _;
    }

    constructor(address payable _deposit) ERC20("IdjotICO", "WIN"){
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
    function changeDepositAddress(address payable _newDeposit) public onlyAdmin {
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

        uint256 tokens = msg.value / tokenPrice;

        // hardcap not reached
        require(raisedAmount + msg.value <= hardCap, "hardCap reached");
        raisedAmount += msg.value;

        // add tokens to investor balance from founder balance
        idjotBalance[msg.sender] += tokens;
        idjotBalance[admin] -= tokens;

        investedAmt[msg.sender] += msg.value;
        
        return true;          
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