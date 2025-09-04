//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Messanger {

    error InvalidTargetAddress();

    error InvalidDestinationChain();
    
    error EmptyData();

    event MessageSent(

        bytes32 indexed messageId,

        address indexed sender,

        address indexed target,

        bytes32 data,

        uint256 timestamp,

        uint256 srcChainId,

        uint256 dstChainId
    );

    uint256 public immutable localChainId;

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

        Message memory message = Message({

            sender: msg.sender,

            target: target,

            data: data,

            timestamp: block.timestamp,

            srcChainId: localChainId,

            dstChainId: dstChainId
        });

        messageId = computeMessageId(message);

        emit MessageSent(

            messageId,
            
            msg.sender,

            target,

            data,

            block.timestamp, 

            localChainId, 

            dstChainId);
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

                message.sender,
                
                message.target,
                
                message.data,
                
                message.timestamp,
                
                message.srcChainId,
                
                message.dstChainId
            )
        );
    }
}
