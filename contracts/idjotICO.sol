pragma solidity >= 0.7.0 < 0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract WinToken is ERC20 {
    address public founder;

    constructor() ERC20("IdjotICO", "WIN") {
        founder = msg.sender;
        _mint(founder, 100000000 * 10 ** decimals());
    }
}

// if ico fails there owner's will get 95% of their ether back since 5% will be charges including gas fees and ICO processing fees
contract idjotICO is WinToken {
    address public admin;
    address payable public depositAddress;

    // if ICO is successfull only then the tokens will be transfered to the owner wallet
    // else ether's will be reversed back to the owner
    mapping(address => uint) public idjotBalance;

    // price of 1WIN token is 0.001 ether
    uint256 public tokenPrice = 1000000000000000;

    // 300 ether to find if ICO was a success or not
    uint256 public hardCap = 300000000000000000000;

    uint256 public raisedAmount;

    // ICO sale starts immediately as the contract is deployed
    uint256 public saleStart = block.timestamp;
    // ICO sale ends after one week
    uint256 public saleEnd = block.timestamp + 604800;
    // Tokens can be traded or transferable one week after the sale ends
    uint256 public tradingStart = saleEnd + 604800;

    uint256 public maxInvestment = 5000000000000000000;
    uint256 public minInvestment = 50000000000000000;

    enum IcoState { beforeStart, running, afterEnd, halted }
    IcoState public icoState;

    modifier onlyAdmin() {
        require(msg.sender == admin);
        _;
    }

    constructor(address payable _deposit) {
        depositAddress = _deposit;
        admin = msg.sender;
        icoState = IcoState.beforeStart;
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
    function getCurrentICOState() public view returns(IcoState) {
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

    // investing function
    function invest() public payable returns(bool) {
        icoState = getCurrentICOState();
        // investment only possible if IcoState is running
        require(icoState == IcoState.running);

        require(msg.value >= minInvestment && msg.value <= maxInvestment);

        uint256 tokens = msg.value / tokenPrice;

        // hardcap not reached
        require(raisedAmount + msg.value <= hardCap);
        raisedAmount += msg.value;

        // add tokens to investor balance from founder balance
        idjotBalance[msg.sender] += tokens;
        idjotBalance[founder] -= tokens;


    }

    // function to check if the ico was a success onlyadmin
    // if it was a success then transfer all the eth received to the deposit address and transfer WIN tokens to their wallet
    // if not then revert the eth to the concerned authority and empty their idjotBalances
}