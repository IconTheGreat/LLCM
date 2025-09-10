//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title The SourceMessanger contract to send cross-chain messages to RemoteMessanger
 * @author ICON
 * @notice This is just a minimal eduacational implementation: DO NOT USE IN PRODUCTION WITHOUT AUDIT!!
 * @notice This contract is responsible for sending messages to the RemoteMessanger contract on a different chain.
 * @notice The owner of this contract has the authority to set the remote messanger addresses for different chain IDs.
 * @dev The contract ensures that messages are sent to valid target addresses on different chains, and that the message data is not empty.
 * @dev The contract computes a unique message ID for each sent message based on its contents.
 */
contract SourceMessanger {
    error InvalidTargetAddress();

    error InvalidDestinationChain();

    error EmptyData();

    error InvalidRemoteAddress();

    event MessageSent(
        bytes32 indexed messageId,
        address indexed sender,
        address indexed target,
        bytes32 data,
        uint256 timestamp,
        uint256 srcChainId,
        uint256 dstChainId
    );

    event RemoteMessangerSet(uint256 indexed chainId, address indexed remoteMessanger);

    uint256 public immutable localChainId;

    mapping(uint256 => address) public remoteMessangerOf;

    struct Message {
        address sender;
        address target;
        bytes32 data;
        uint256 timestamp;
        uint256 srcChainId;
        uint256 dstChainId;
    }

    constructor() {
        localChainId = block.chainid;
    }

    ////////////////////////
    /// CORE FUNCTIONS  ////
    ////////////////////////

    function setRemoteMessanger(uint256 chainId, address remote) external {
        if (remote == address(0)) revert InvalidRemoteAddress();

        remoteMessangerOf[chainId] = remote;

        emit RemoteMessangerSet(chainId, remote);
    }

    /**
     * @notice Sends a message to a target address on a different chain.
     *
     * @param target The address of the target contract on the destination chain.
     *
     * @param data The message data to be sent (up to 32 bytes).
     *
     * @param dstChainId The ID of the destination chain.
     *
     * @return messageId A unique identifier for the sent message.
     */
    function sendMessage(address target, bytes32 data, uint256 dstChainId) external returns (bytes32 messageId) {
        if (target == address(0)) revert InvalidTargetAddress();

        if (dstChainId == localChainId) revert InvalidDestinationChain();

        if (data == bytes32(0)) revert EmptyData();

        address remote = remoteMessangerOf[dstChainId];

        if (remote == address(0)) revert InvalidRemoteAddress();

        Message memory message = Message({
            sender: msg.sender,
            target: target,
            data: data,
            timestamp: block.timestamp,
            srcChainId: localChainId,
            dstChainId: dstChainId
        });

        messageId = computeMessageId(message);

        emit MessageSent(messageId, msg.sender, target, data, block.timestamp, localChainId, dstChainId);
    }

    ////////////////////////
    /// HELPER FUNCTIONS ///
    ////////////////////////

    /**
     * @notice Computes a unique message ID based on the message contents.
     *
     * @param message The message struct containing all relevant fields.
     *
     * @return A bytes32 hash that uniquely identifies the message.
     */
    function computeMessageId(Message memory message) public pure returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                message.sender, message.target, message.data, message.timestamp, message.srcChainId, message.dstChainId
            )
        );
    }
}
