// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/SourceMessanger.sol";
import "../src/RemoteMessanger.sol";

contract DummyTarget {
    bytes32 public lastMessage;

    function handleMessage(bytes32 data) external {
        lastMessage = data;
    }
}

contract MessangerTest is Test {
    SourceMessanger public source;
    RemoteMessanger public remote;
    DummyTarget public target;

    address public owner = address(0xABCD);
    address public user = address(0xBEEF);
    address public relayer = address(0xDEAD);

    uint256 public localChainId;
    uint256 public remoteChainId = 2; // arbitrary non-local chainId

    function setUp() public {
        // Deploy contracts
        vm.startPrank(owner);
        source = new SourceMessanger();
        remote = new RemoteMessanger();
        vm.stopPrank();

        target = new DummyTarget();

        localChainId = block.chainid;

        // Link source <-> remote
        vm.prank(owner);
        source.setRemoteMessanger(remoteChainId, address(remote));

        vm.prank(owner);
        remote.setSourceMessanger(localChainId, address(source));

        vm.prank(owner);
        remote.setRelayer(relayer);
    }

    function testSendMessageEmitsMessageSent() public {
        bytes32 data = keccak256(abi.encodePacked("Hello, World!"));

        uint256 timestamp = block.timestamp; // snapshot current block
        bytes32 expectedMessageId =
            keccak256(abi.encodePacked(user, address(target), data, timestamp, localChainId, remoteChainId));

        vm.prank(user);
        vm.expectEmit(true, true, true, true);
        emit SourceMessanger.MessageSent(
            expectedMessageId, user, address(target), data, timestamp, localChainId, remoteChainId
        );
        source.sendMessage(address(target), data, remoteChainId);
    }

    function testSendMessageRevertsIfTargetZero() public {
        vm.prank(user);
        vm.expectRevert(SourceMessanger.InvalidTargetAddress.selector);
        source.sendMessage(address(0), keccak256("data"), remoteChainId);
    }

    function testSendMessageRevertsIfSameChain() public {
        vm.prank(user);
        vm.expectRevert(SourceMessanger.InvalidDestinationChain.selector);
        source.sendMessage(address(target), keccak256("data"), localChainId);
    }

    function testSendMessageRevertsIfEmptyData() public {
        vm.prank(user);
        vm.expectRevert(SourceMessanger.EmptyData.selector);
        source.sendMessage(address(target), bytes32(0), remoteChainId);
    }

    function testReceiveMessageRevertsIfNotRelayer() public {
        RemoteMessanger.Message memory message = RemoteMessanger.Message({
            sender: user,
            target: address(target),
            data: keccak256("data"),
            timestamp: block.timestamp,
            srcChainId: localChainId,
            dstChainId: remote.localChainId()
        });

        vm.prank(user);
        vm.expectRevert(RemoteMessanger.NotRelayer.selector);
        remote.receiveMessage(message, address(source));
    }

    function testComputedMessageId() public view {
        bytes32 data = keccak256("test");
        uint256 timestamp = block.timestamp;

        SourceMessanger.Message memory message = SourceMessanger.Message({
            sender: user,
            target: address(target),
            data: data,
            timestamp: timestamp,
            srcChainId: localChainId,
            dstChainId: remote.localChainId()
        });

        bytes32 expectedMessageId =
            keccak256(abi.encodePacked(user, address(target), data, timestamp, localChainId, remote.localChainId()));

        bytes32 computedMessageId = source.computeMessageId(message);

        assertEq(computedMessageId, expectedMessageId);
    }

    function testReceiveMessageEmitsMessageReceivedAndCallsTarget() public {
        // 1. Prepare message data
        bytes32 data = keccak256("cross-chain");

        // 2. Send message from source messenger
        vm.prank(user);
        source.sendMessage(address(target), data, remoteChainId);

        // 3. Build the message struct for RemoteMessanger
        RemoteMessanger.Message memory message = RemoteMessanger.Message({
            sender: user,
            target: address(target),
            data: data,
            timestamp: block.timestamp,
            srcChainId: localChainId,
            dstChainId: localChainId // because remote = local chain
        });

        // 4. Compute expected messageId (same as RemoteMessanger does)
        bytes32 expectedMessageId = keccak256(
            abi.encodePacked(
                message.sender, message.target, message.data, message.timestamp, message.srcChainId, message.dstChainId
            )
        );

        // 5. Expect the MessageReceived event with exact values
        vm.prank(relayer);
        vm.expectEmit(true, true, true, true);
        emit RemoteMessanger.MessageReceived(
            expectedMessageId,
            message.sender,
            message.target,
            message.data,
            message.timestamp,
            message.srcChainId,
            message.dstChainId
        );

        // 6. Deliver message to remote messenger
        remote.receiveMessage(message, address(source));

        // 7. Assert target received the message
        assertEq(target.lastMessage(), data);
    }
}
