// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

contract BasicAuction {
    address payable public beneficiary;
    uint256 public auctionEndTime;
    bool public beneficiaryHasBeenPaid;

    address public topBidder;
    uint256 public topBid;

    mapping(address => uint256) public pendingReturns;

    modifier isValidBid() {
        require(msg.sender != beneficiary, "Cannot bid on own auction.");
        require(!auctionEnded(), "Auction has ended.");
        require(msg.value > topBid, "Bid must be higher than top bid.");
        require(
            msg.sender != topBidder,
            "Already the top bidder. Increase your current bid instead"
        );
        _;
    }

    function auctionEnded() public view returns (bool) {
        return block.timestamp >= auctionEndTime;
    }

    constructor(uint256 _biddingTime, address payable _beneficiary) {
        beneficiary = _beneficiary;
        auctionEndTime = block.timestamp + _biddingTime;
    }

    function placeBid() public payable isValidBid {
        pendingReturns[topBidder] += topBid;
        topBidder = msg.sender;
        topBid = msg.value;
    }

    function increaseBid() public payable {
        require(
            msg.sender == topBidder,
            "You must be the curent top bidder to increase your bid."
        );
        require(
            msg.value > 0,
            "You must send ether to increase your bid amount."
        );
        topBid += msg.value;
    }

    function withdraw() public {
        address payable sender = payable(msg.sender);
        bool success;

        if (sender == beneficiary) {
            require(auctionEnded(), "Auction has not ended yet");
            require(topBid > 0, "No bids were placed.");
            require(
                !beneficiaryHasBeenPaid,
                "Beneficiary has already been paid."
            );

            beneficiaryHasBeenPaid = true;
            (success, ) = sender.call{value: topBid}("");
        } else {
            uint256 pendingReturn = pendingReturns[sender];
            require(pendingReturn > 0, "You have no pending returns.");
            pendingReturns[sender] = 0;
            (success, ) = sender.call{value: pendingReturn}("");
        }

        if (!success) {
            revert("Could not send funds.");
        }
    }

    function getWinner() public view returns (address) {
        require(auctionEnded(), "Auction has not yet ended.");
        require(topBid > 0, "No bids were placed.");
        return topBidder;
    }
}
