//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title The RemoteMessanger contract to receive cross-chain messages from SourceMessanger
 *
 * @author ICON
 *
 * @dev This contract is designed to work in conjunction with the SourceMessanger contract to facilitate cross-chain communication.
 *
 * @notice This is just a minimal eduacational implementation: DO NOT USE IN PRODUCTION WITHOUT AUDIT!!
 *
 * @notice This contract is responsible for receiving messages from the SourceMessanger contract on a different chain.
 *
 * @notice The relayer is a trusted entity responsible for relaying messages between chains.
 *
 * @notice The owner of this contract has the authority to set the relayer and source messanger addresses.
 *
 * @dev The contract ensures that only valid messages from the designated SourceMessanger are processed, therefore sourceMessanger addresses must be set for each chain ID.
 */
contract RemoteMessanger {
    error NotRelayer();

    error InvalidTargetAddress();

    error InvalidDestinationChain();

    error EmptyData();

    error InvalidRelayerAddress();

    error InvalidSourceAddress();

    event RelayerSet(address indexed newRelayer);

    event MessageReceived(
        bytes32 indexed messageId,
        address indexed sender,
        address indexed target,
        bytes32 data,
        uint256 timestamp,
        uint256 srcChainId,
        uint256 dstChainId
    );

    address public immutable owner;

    uint256 public immutable localChainId;

    address public relayer;

    mapping(uint256 => address) public sourceMessangerOf;

    struct Message {
        address sender;
        address target;
        bytes32 data;
        uint256 timestamp;
        uint256 srcChainId;
        uint256 dstChainId;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    constructor() {
        localChainId = block.chainid;
        owner = msg.sender;
    }

    ////////////////////////////////
    /// CORE FUNCTIONS  ///////////
    /////////////////////////////

    /**
     * @notice Set the relayer address
     * @param _relayer The address of the relayer
     */
    function setRelayer(address _relayer) external onlyOwner {
        if (_relayer == address(0)) revert InvalidRelayerAddress();

        relayer = _relayer;

        emit RelayerSet(_relayer);
    }

    /**
     * @notice Set the source messenger address for a specific chain ID
     *
     * @param chainId The ID of the chain
     *
     * @param sourceMessanger The address of the source messenger contract
     */
    function setSourceMessanger(uint256 chainId, address sourceMessanger) external onlyOwner {
        if (sourceMessanger == address(0)) revert InvalidSourceAddress();

        sourceMessangerOf[chainId] = sourceMessanger;
    }

    /**
     * @notice Receive a message from the SourceMessanger contract on a different chain
     *
     * @param message The message struct containing the message details
     *
     * @param sourceMessanger The address of the SourceMessanger contract on the source chain
     *
     * @dev This function can only be called by the relayer
     *
     * @dev The function verifies the message details and emits a MessageReceived event
     *
     * @notice The target contract must implement a handleMessage(bytes32) function to process the received message
     *
     */
    function receiveMessage(Message memory message, address sourceMessanger) external {
        if (msg.sender != relayer) revert NotRelayer();

        if (message.target == address(0)) revert InvalidTargetAddress();

        if (message.dstChainId != localChainId) revert InvalidDestinationChain();

        if (message.data == bytes32(0)) revert EmptyData();

        if (sourceMessanger == address(0)) revert InvalidSourceAddress();

        if (sourceMessangerOf[message.srcChainId] != sourceMessanger) revert InvalidSourceAddress();

        bytes32 messageId = keccak256(
            abi.encodePacked(
                message.sender, message.target, message.data, message.timestamp, message.srcChainId, message.dstChainId
            )
        );

        emit MessageReceived(
            messageId,
            message.sender,
            message.target,
            message.data,
            message.timestamp,
            message.srcChainId,
            message.dstChainId
        );

        (bool success,) = message.target.call(abi.encodeWithSignature("handleMessage(bytes32)", message.data));

        require(success, "Message handling failed");
    }
}
