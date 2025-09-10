//SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

interface ICrossChainReceiver {
    /**
     * @notice This is a contract that the target contract of the destination chain must implement.
     *
     * @notice Called by RemoteMessenger on destination chain when a message is delivered.
     *
     * @param data Opaque payload defined by the application.
     */
    function handleMessage(bytes calldata data) external;
}
