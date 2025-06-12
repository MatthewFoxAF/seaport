// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {
    ZoneParameters,
    Schema
} from "seaport-types/src/lib/ConsiderationStructs.sol";

import { ERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import { ZoneInterface } from "seaport-types/src/interfaces/ZoneInterface.sol";

/**
 * @title TargetedTradeZone
 * @notice A zone that restricts order fulfillment to specific target addresses
 * @dev This zone allows offerers to specify exactly who can fulfill their orders
 */
contract TargetedTradeZone is ERC165, ZoneInterface {
    
    // Events
    event OrderTargeted(bytes32 indexed orderHash, address indexed offerer, address indexed targetFulfiller);
    event OrderFulfilled(bytes32 indexed orderHash, address indexed fulfiller);
    event OrderCancelled(bytes32 indexed orderHash, address indexed offerer);
    
    // Errors
    error UnauthorizedFulfiller(address fulfiller, address expectedFulfiller);
    error OrderNotTargeted(bytes32 orderHash);
    error InvalidTargetAddress();
    error OrderAlreadyFulfilled(bytes32 orderHash);
    
    // Mapping from order hash to the intended fulfiller address
    mapping(bytes32 => address) public orderTargets;
    
    // Mapping from order hash to whether it's been fulfilled
    mapping(bytes32 => bool) public orderFulfilled;
    
    // Mapping from order hash to the offerer address
    mapping(bytes32 => address) public orderOfferers;
    
    /**
     * @notice Authorize an order and set its target fulfiller
     * @dev Called when creating an order. The extraData should contain the target address
     * @param zoneParameters The zone parameters including orderHash and extraData
     * @return The authorize magic value if successful
     */
    function authorizeOrder(
        ZoneParameters calldata zoneParameters
    ) public returns (bytes4) {
        bytes32 orderHash = zoneParameters.orderHash;
        
        // Decode target address from extraData
        // ExtraData format: abi.encode(targetFulfillerAddress)
        if (zoneParameters.extraData.length != 32) {
            revert InvalidTargetAddress();
        }
        
        address targetFulfiller = abi.decode(zoneParameters.extraData, (address));
        
        if (targetFulfiller == address(0)) {
            revert InvalidTargetAddress();
        }
        
        // Store both target and offerer
        orderTargets[orderHash] = targetFulfiller;
        orderOfferers[orderHash] = zoneParameters.offerer;
        
        emit OrderTargeted(orderHash, zoneParameters.offerer, targetFulfiller);
        
        return this.authorizeOrder.selector;
    }

    /**
     * @notice Validate order fulfillment
     * @dev Called during order fulfillment to ensure only the target address can fulfill
     * @param zoneParameters The zone parameters including orderHash and fulfiller info
     * @return validOrderMagicValue The validate magic value if successful
     */
    function validateOrder(
        ZoneParameters calldata zoneParameters
    ) external returns (bytes4 validOrderMagicValue) {
        bytes32 orderHash = zoneParameters.orderHash;
        
        // Check if this order has been targeted
        address targetFulfiller = orderTargets[orderHash];
        if (targetFulfiller == address(0)) {
            // If not found in storage, try to decode from extraData as fallback
            if (zoneParameters.extraData.length == 32) {
                targetFulfiller = abi.decode(zoneParameters.extraData, (address));
                if (targetFulfiller == address(0)) {
                    revert OrderNotTargeted(orderHash);
                }
                // Store it for future reference
                orderTargets[orderHash] = targetFulfiller;
                orderOfferers[orderHash] = zoneParameters.offerer;
            } else {
                revert OrderNotTargeted(orderHash);
            }
        }
        
        // Check if order already fulfilled
        if (orderFulfilled[orderHash]) {
            revert OrderAlreadyFulfilled(orderHash);
        }
        
        // Validate that the fulfiller is the intended recipient
        // The fulfiller address is derived from the transaction context
        // In Seaport, this is typically msg.sender from the fulfillment call
        if (zoneParameters.fulfiller != targetFulfiller) {
            revert UnauthorizedFulfiller(zoneParameters.fulfiller, targetFulfiller);
        }
        
        // Mark order as fulfilled
        orderFulfilled[orderHash] = true;
        
        emit OrderFulfilled(orderHash, zoneParameters.fulfiller);
        
        return ZoneInterface.validateOrder.selector;
    }

    /**
     * @notice Get the target fulfiller for an order
     * @param orderHash The hash of the order
     * @return The address that can fulfill this order
     */
    function getOrderTarget(bytes32 orderHash) external view returns (address) {
        return orderTargets[orderHash];
    }
    
    /**
     * @notice Check if an order has been fulfilled
     * @param orderHash The hash of the order
     * @return Whether the order has been fulfilled
     */
    function isOrderFulfilled(bytes32 orderHash) external view returns (bool) {
        return orderFulfilled[orderHash];
    }
    
    /**
     * @notice Cancel/remove targeting for an order (only callable by offerer)
     * @param orderHash The hash of the order to cancel
     */
    function cancelOrderTargeting(bytes32 orderHash) external {
        address storedOfferer = orderOfferers[orderHash];
        require(storedOfferer != address(0), "Order not found");
        require(msg.sender == storedOfferer, "Only offerer can cancel");
        require(!orderFulfilled[orderHash], "Order already fulfilled");
        
        delete orderTargets[orderHash];
        delete orderOfferers[orderHash];
        
        emit OrderCancelled(orderHash, msg.sender);
    }

    /**
     * @dev Returns the metadata for this zone
     */
    function getSeaportMetadata()
        external
        pure
        override
        returns (
            string memory name,
            Schema[] memory schemas
        )
    {
        schemas = new Schema[](1);
        schemas[0].id = 3003;
        schemas[0].metadata = new bytes(0);

        return ("TargetedTradeZone", schemas);
    }

    function supportsInterface( 
        bytes4 interfaceId
    ) public view override(ERC165, ZoneInterface) returns (bool) {
        return
            interfaceId == type(ZoneInterface).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}