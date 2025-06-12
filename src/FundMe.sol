// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {PriceConvertor} from "./PriceConvertor.sol";

contract FundMe {
    using PriceConvertor for uint256;

    // Constant
    uint256 public constant MINIMUM_USD = 5e18;

    address[] private s_funders;
    mapping(address funder => uint256 amountFunded) private s_addressToAmountFunded;

    /*  KEYWORDS that help in saving some gas : constant, immutable
    A 'constant' function returns the same value every time it's called and cannot read or modify state 
    variables.  An 'immutable' variable is a global constant that can be set only once during deployment. 
    */

    // Could we make this constant?  /* hint: no! We should make it immutable! */
    address private immutable i_owner;
    AggregatorV3Interface private s_priceFeed;

    constructor(address priceFeed) {
        i_owner = msg /*immutable*/ .sender;
        s_priceFeed = AggregatorV3Interface(priceFeed);
    }

    function fund() public payable {
        require(msg.value.getConversionRate(s_priceFeed) >= MINIMUM_USD, "didn't send enough ETH");
        s_funders.push(msg.sender);
        s_addressToAmountFunded[msg.sender] += msg.value;
    }

    function cheaperWithdraw() public onlyOwner {
        uint256 fundersLength = s_funders.length;

        for (uint256 funderIndex = 0; funderIndex < fundersLength; funderIndex++) {
            address funder = s_funders[funderIndex];
            s_addressToAmountFunded[funder] = 0;
        }

        s_funders = new address[](0);

        (bool callSuccess,) = payable(msg.sender).call{value: address(this).balance}("");
        require(callSuccess, "call failed");
    }

    function withdraw() public onlyOwner {
        // prettier-ignore-start
        for (uint256 funderIndex = 0; funderIndex < s_funders.length; funderIndex++) {
            address funder = s_funders[funderIndex];
            s_addressToAmountFunded[funder] = 0;
        }
        // prettier-ignore-end

        //reset the array
        s_funders = new address[](0);

        //actually withdrawing funds
        //1.transfer ; 2.send ; 3.call

        /*
        //1.transfer
        payable(msg.sender).transfer(address(this).balance);

        //2.send
        bool sendSuccess = payable(msg.sender).send(address(this).balance);
        require(sendSuccess, "Send failed");
        */
        //3.call
        (bool callSuccess,) = payable(msg.sender).call{value: address(this).balance}("");
        require(callSuccess, "call failed");

        //call is currently the most preffered way for transfer of funds.
    }

    modifier onlyOwner() {
        require(msg.sender == i_owner, "Sender is not Owner!");
        _;
    }

    function getVersion() public view returns (uint256) {
        return s_priceFeed.version();
    }

    receive() external payable {
        fund();
    }

    fallback() external payable {
        fund();
    }

    /*
    Receive:
    A special function named "receive" which accepts Ether, but does not return any value. It's used to 
    receive ether without executing a specific logic.
    
    Fallback:
    The default function that gets called when there is no matching function for the given input data or 
    if it doesn't match with payable and non-payable functions.
    */

    function getAddressToAmountFunded(address fundingAddress) external view returns (uint256) {
        return s_addressToAmountFunded[fundingAddress];
    }

    function getFunder(uint256 index) external view returns (address) {
        return s_funders[index];
    }

    function getOwner() public view returns (address) {
        return i_owner;
    }
}
