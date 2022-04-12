/*
This is the hostel token contract i have attached it here in comments so as to put both the contracts in one file


pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

//The token has been deployed to rinkeby,you can check the token 
//in etherscan at address "0x1Dd0AC77020B083d6cF0D116f89e3f711214fe1e"

contract Alaknanda is ERC20 {
    constructor(uint256 initialSupply) public ERC20("Alaknanda", "ALK") {
        _mint(msg.sender, initialSupply);
    }
}
*/

//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./alkToken.sol";

/*
Rules assumed:

    1)A lendee can request only one loan at a time.
    2)A lendee can request a new loan only after paying back the loan and only after the time period of the loan
    3)The contract owner can mediate between the lendee and lender as to whether to dissolve the 
    locked assets of the lendee in case the lent time exceeds timeperiod.
    4)Alk(hostel tokens) are used for lending by using ethereum as collateral.
    5)only the owner of the contract can approve the lendee's req for loan and add the lendee to the recipient list,the owner 
    will accept the lendee's request when both the lender and lendee agree for the loan in the platform outside blockchain.
    6)The contract has assumed that the fixed collateral,borrowed alk tokens and the interestAmount remains fixed irrespective 
    of the change in value of cryptoassets.
    7)The lender's identity is hided by transfering the assets from lender to contract first 
    and then the contract gives the tokens to the lendee.
    8)The automation of the contract can make this contract a fully functional lending platform,i have reduced using multiple
    calls within function assuming that the automation will be carried out after the deployment of this contract.

*/

contract LenderContract is Ownable {
    IERC20 private alk;

    constructor(address _tokenAddress) public {
        alk = IERC20(_tokenAddress);
    }

    struct LoanOffer {
        uint256 lockedCollateral;
        uint256 reqAlk;
        address lender;
        uint256 interestAmount;
        uint256 receivedTime;
        uint256 timePeriod;
    }

    mapping(address => LoanOffer) private recipientToLoanOffer;

    address[] private recipients;
    mapping(address => bool) private recipientToStatus;

    function isRecip(address _recip) private returns (bool) {
        //checks if recip address is in the recipient's list

        for (uint256 i = 0; i < recipients.length; ++i) {
            if (recipients[i] == _recip) {
                //to check if the recipient status is active
                require(
                    recipientToStatus[_recip],
                    "you are no longer a recipient,take a new loan to become a recipient again"
                );
                return true;
            }
        }
        return false;
    }

    //modifier function to check if the function callers are valid recipients
    modifier onlyRecipient(address _recip) {
        require(
            isRecip(_recip),
            "This address is not in the recipient list,contact contract owner to request your loan!"
        );
        _;
    }

    //function to add recipients,the contract owner adds the recipients after the verification process in his/her
    //lending platform and after getting a proper lender for the lendee
    function addRecipients(address _recip) public onlyOwner {
        if (recipientToStatus[_recip] == false) {
            recipients.push(_recip);
            //enabling the recipient as active
            recipientToStatus[_recip] = true;
        }
    }

    //function to accept collateral from lendee
    function lockLendeeCollateral(
        uint256 _ethAmount,
        uint256 _reqAlk,
        uint256 _interest
    ) public payable onlyRecipient(msg.sender) {
        require(msg.value == _ethAmount, "Insufficient collateral for ether!");
        //information regarding the Locked collateral,the request alktokens and the proposed interest is stored on blockchain.
        recipientToLoanOffer[msg.sender].lockedCollateral = _ethAmount;
        recipientToLoanOffer[msg.sender].reqAlk = _reqAlk;
        recipientToLoanOffer[msg.sender].interestAmount = _interest;
    }

    //function to lock the lender's lending alk tokens to the contract to conceal the lender's identity.
    function lockLenderAssets(
        uint256 _alkAmount,
        address _recip,
        uint256 _timePeriod
    ) public {
        require(
            _alkAmount == recipientToLoanOffer[_recip].reqAlk,
            "Insufficient alk tokens to lend to the recipient"
        );
        require(
            _alkAmount != 0,
            "Your recipient does not have any lending requests!"
        );
        // transfering the alk tokens to the contract
        alk.transferFrom(msg.sender, address(this), _alkAmount);
        // info regarding the lent alk tokens amount and it's timeperiod is stored
        recipientToLoanOffer[_recip].lender = msg.sender;
        recipientToLoanOffer[_recip].timePeriod = _timePeriod;
    }

    //function to finish lending the alk tokens to the lendee from the contract
    function sendAssetsToLendee(address _recip) public onlyOwner {
        //transfering alk tokens from contract to the lendee
        alk.transfer(_recip, recipientToLoanOffer[_recip].reqAlk);
        recipientToLoanOffer[_recip].receivedTime = block.timestamp;
    }

    //function for the lendee to pay back the loan to the lender with interest,anything short of it cannot be paid back!
    function repayLoan(uint256 _loanAlk)
        public
        payable
        onlyRecipient(msg.sender)
    {
        require(
            _loanAlk == recipientToLoanOffer[msg.sender].reqAlk,
            "You have to pay back according to the agreement!"
        );
        require(
            recipientToLoanOffer[msg.sender].lockedCollateral == 0,
            "Your locked collateral has been dissolved because you have not payed the loan on time"
        );
        require(
            msg.value == recipientToLoanOffer[msg.sender].interestAmount,
            "Pay the guaranteed interest amount!"
        );
        //alk tokens are returned back to lender
        alk.transferFrom(
            msg.sender,
            recipientToLoanOffer[msg.sender].lender,
            _loanAlk
        );
        //the locked ethereum collateral is returned back to the lendee
        payable(msg.sender).transfer(
            recipientToLoanOffer[msg.sender].lockedCollateral
        );

        //mappings done if the lender recieved his monetory value back
        recipientToLoanOffer[msg.sender].reqAlk = 0;
        recipientToLoanOffer[msg.sender].lender = msg.sender;
        recipientToLoanOffer[msg.sender].lockedCollateral = 0;
        recipientToStatus[msg.sender] = false;
    }

    //function to dissolve the assets if the loan is not payed on time,this is called by contract owner only
    function dissolveAssetsToLender(address _recip) public onlyOwner {
        //checks if the lending time is over or not
        require(
            block.timestamp >=
                (recipientToLoanOffer[_recip].receivedTime +
                    recipientToLoanOffer[_recip].timePeriod),
            "The recipient still has the time to return the borrowed loan!"
        );
        //dissolves the ether assets and sends the ether to the lender
        payable(recipientToLoanOffer[_recip].lender).transfer(
            recipientToLoanOffer[_recip].lockedCollateral
        );
        //mappings done if the lender recieved his monetory value back
        recipientToLoanOffer[msg.sender].reqAlk = 0;
        recipientToLoanOffer[msg.sender].lender = msg.sender;
        recipientToLoanOffer[msg.sender].lockedCollateral = 0;
        recipientToStatus[msg.sender] = false;
    }
}
