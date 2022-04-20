// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "ds-test/test.sol";
import "src/BasicAuction.sol";

interface CheatCodes {
    function deal(address who, uint256 newBalance) external;

    function prank(address) external;

    function startPrank(address) external;

    function expectRevert(bytes calldata msg) external;

    function warp(uint256) external;
}

contract ContractTest is DSTest {
    BasicAuction auction;
    uint256 biddingTime = 7 days;
    address payable beneficiary = payable(address(1));
    CheatCodes constant cheats = CheatCodes(HEVM_ADDRESS);

    function setUp() public {
        auction = new BasicAuction(biddingTime, beneficiary);
    }
}

contract ContructorTest is ContractTest {
    function testSetsBeneficiary() public {
        assertEq(auction.beneficiary(), beneficiary);
    }

    function testSetsAuctionEndTime() public {
        uint256 expectedEndTime = block.timestamp + biddingTime;
        assertEq(auction.auctionEndTime(), expectedEndTime);
    }

    function testSetsAuctionEnded() public {
        assertTrue(!auction.auctionEnded());
    }

    function testAuctionDoesEnd() public {
        cheats.warp(block.timestamp + 7 days);
        assertTrue(auction.auctionEnded());
    }
}

contract PlaceBidTests is ContractTest {
    uint256 bidAmount = 1;
    address bidder = address(2);
    address anotherBidder = address(2);

    function testCanSetInitialBid() public {
        cheats.deal(bidder, bidAmount);
        cheats.prank(bidder);
        (bool success, ) = address(auction).call{value: bidAmount}(
            abi.encodeWithSignature("placeBid()")
        );
        assertTrue(success);
        assertEq(auction.topBidder(), bidder);
        assertEq(auction.topBid(), bidAmount);
        assertEq(address(bidder).balance, 0);
    }

    function testBidMustBeHigherThanTopBid() public {
        cheats.deal(bidder, bidAmount);
        cheats.prank(bidder);
        (bool success, ) = address(auction).call{value: bidAmount}(
            abi.encodeWithSignature("placeBid()")
        );
        assertTrue(success);

        cheats.deal(anotherBidder, bidAmount);
        cheats.prank(anotherBidder);
        cheats.expectRevert(bytes("Bid must be higher than top bid."));
        (success, ) = address(auction).call{value: bidAmount}(
            abi.encodeWithSignature("placeBid()")
        );
    }

    function testCannotOutbidYouself() public {
        cheats.deal(bidder, bidAmount);
        cheats.prank(bidder);
        (bool success, ) = address(auction).call{value: bidAmount}(
            abi.encodeWithSignature("placeBid()")
        );
        assertTrue(success);

        cheats.deal(bidder, bidAmount);
        cheats.prank(bidder);
        cheats.expectRevert(
            bytes("Already the top bidder. Increase your current bid instead.")
        );
        (success, ) = address(auction).call{value: bidAmount}(
            abi.encodeWithSignature("placeBid()")
        );
    }

    function testBenificiaryCannotBid() public {
        cheats.deal(beneficiary, bidAmount);
        cheats.prank(beneficiary);
        cheats.expectRevert(bytes("Cannot bid on own auction."));

        (bool success, ) = address(auction).call{value: bidAmount}(
            abi.encodeWithSignature("placeBid()")
        );
        assertTrue(success);
    }
}

contract IncreaseBidTests is ContractTest {
    uint256 bidAmount = 1;
    uint256 increaseAmount = 4;
    address bidder = address(2);
    address otherBidder = address(3);

    function testIncreaseTopBid() public {
        cheats.deal(bidder, bidAmount + increaseAmount);
        cheats.startPrank(bidder);

        (bool success, ) = address(auction).call{value: bidAmount}(
            abi.encodeWithSignature("placeBid()")
        );
        assertTrue(success);
        assertEq(auction.topBid(), bidAmount);
        assertEq(address(bidder).balance, increaseAmount);

        (success, ) = address(auction).call{value: increaseAmount}(
            abi.encodeWithSignature("increaseBid()")
        );
        assertTrue(success);
        assertEq(auction.topBid(), bidAmount + increaseAmount);
        assertEq(address(bidder).balance, 0);
    }

    function testCannotIncreaseIfNotTopBidder() public {
        cheats.deal(bidder, bidAmount);
        cheats.deal(otherBidder, increaseAmount);

        cheats.prank(bidder);
        (bool success, ) = address(auction).call{value: bidAmount}(
            abi.encodeWithSignature("placeBid()")
        );
        assertTrue(success);
        assertEq(auction.topBid(), bidAmount);

        cheats.prank(otherBidder);
        cheats.expectRevert(
            bytes("You must be the curent top bidder to increase your bid.")
        );
        (success, ) = address(auction).call{value: increaseAmount}(
            abi.encodeWithSignature("increaseBid()")
        );
    }

    function testMustPayEtherToIncrease() public {
        cheats.deal(bidder, bidAmount);
        cheats.startPrank(bidder);

        (bool success, ) = address(auction).call{value: bidAmount}(
            abi.encodeWithSignature("placeBid()")
        );
        assertTrue(success);
        assertEq(auction.topBid(), bidAmount);

        cheats.expectRevert(
            bytes("You must send ether to increase your bid amount.")
        );
        (success, ) = address(auction).call(
            abi.encodeWithSignature("increaseBid()")
        );
    }
}

contract WithdrawTests is ContractTest {
    address bidder = address(2);
    address otherBidder = address(3);
    uint256 bidAmount = 1;
    uint256 otherBidAmount = 2;

    function testCannotWithdrawIfNoPendingReturns() public {
        cheats.prank(bidder);
        cheats.expectRevert(bytes("You have no pending returns."));
        (bool success, ) = address(auction).call(
            abi.encodeWithSignature("withdraw()")
        );
        assertTrue(success);
    }

    function testCanWithdraw() public {
        cheats.deal(bidder, bidAmount);
        cheats.deal(otherBidder, otherBidAmount);

        cheats.prank(bidder);
        (bool success, ) = address(auction).call{value: bidAmount}(
            abi.encodeWithSignature("placeBid()")
        );
        assertTrue(success);
        assertEq(address(bidder).balance, 0);

        cheats.prank(otherBidder);
        (success, ) = address(auction).call{value: otherBidAmount}(
            abi.encodeWithSignature("placeBid()")
        );
        assertTrue(success);

        cheats.prank(bidder);
        (success, ) = address(auction).call(
            abi.encodeWithSignature("withdraw()")
        );
        assertTrue(success);
        assertEq(address(bidder).balance, bidAmount);
    }

    function testBeneficiaryCanGetPaid() public {
        cheats.deal(bidder, bidAmount);

        cheats.prank(bidder);
        (bool success, ) = address(auction).call{value: bidAmount}(
            abi.encodeWithSignature("placeBid()")
        );
        assertTrue(success);
        assertEq(address(bidder).balance, 0);

        cheats.warp(block.timestamp + 7 days);

        cheats.prank(beneficiary);
        (success, ) = address(auction).call(
            abi.encodeWithSignature("withdraw()")
        );
        assertTrue(success);
        assertEq(address(beneficiary).balance, bidAmount);
    }

    function testBeneficiaryCannotGetPaidTwice() public {
        cheats.deal(bidder, bidAmount);

        cheats.prank(bidder);
        (bool success, ) = address(auction).call{value: bidAmount}(
            abi.encodeWithSignature("placeBid()")
        );
        assertTrue(success);

        cheats.warp(block.timestamp + 7 days);

        cheats.prank(beneficiary);
        (success, ) = address(auction).call(
            abi.encodeWithSignature("withdraw()")
        );
        assertTrue(success);

        cheats.prank(beneficiary);
        cheats.expectRevert(bytes("Beneficiary has already been paid."));
        (success, ) = address(auction).call(
            abi.encodeWithSignature("withdraw()")
        );
        assertTrue(success);
    }
}

contract GetWinnerTests is ContractTest {
    address bidder = address(2);
    uint256 bidAmount = 1;

    function testCanGetWinner() public {
        cheats.deal(bidder, bidAmount);

        cheats.prank(bidder);
        (bool success, ) = address(auction).call{value: bidAmount}(
            abi.encodeWithSignature("placeBid()")
        );
        assertTrue(success);

        cheats.warp(block.timestamp + 7 days);

        assertEq(auction.getWinner(), bidder);
    }

    function testCannontGetWinnerIfNotEnded() public {
        cheats.deal(bidder, bidAmount);

        cheats.prank(bidder);
        (bool success, ) = address(auction).call{value: bidAmount}(
            abi.encodeWithSignature("placeBid()")
        );
        assertTrue(success);

        cheats.expectRevert(bytes("Auction has not yet ended."));
        auction.getWinner();
    }

    function testCannontGetWinnerIfNoBids() public {
        cheats.warp(block.timestamp + 7 days);

        cheats.expectRevert(bytes("No bids were placed."));
        auction.getWinner();
    }
}
