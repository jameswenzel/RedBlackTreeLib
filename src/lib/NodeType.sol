// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

type Node is uint256;

library NodeType {
    uint256 constant UINT31_MASK = 0x7FFFFFFF;
    uint256 constant PackedValueTooLarge__Selector = 0x1e83345b;

    error PackedValueTooLarge();

    function createNode(uint256 _value, bool _red, uint256 _parent, uint256 _left, uint256 _right)
        internal
        pure
        returns (Node node)
    {
        ///@solidity memory-safe-assembly
        assembly {
            node := or(shl(96, _value), or(shl(95, _red), or(shl(64, _parent), or(shl(32, _left), _right))))
        }
    }

    function safeCreateNode(uint160 _value, bool _red, uint256 _parent, uint256 _left, uint256 _right)
        internal
        pure
        returns (Node node)
    {
        ///@solidity memory-safe-assembly
        assembly {
            // _value was cast to 160 on the way in, so no need to double-check
            if gt(or(_parent, or(_left, _right)), UINT31_MASK) {
                mstore(0, PackedValueTooLarge__Selector)
                revert(0x1c, 4)
            }
            node := or(shl(96, _value), or(shl(95, _red), or(shl(64, _parent), or(shl(32, _left), _right))))
        }
    }

    function unpack(Node node)
        internal
        pure
        returns (uint256 _value, bool _red, uint256 _parent, uint256 _left, uint256 _right)
    {
        ///@solidity memory-safe-assembly
        assembly {
            _value := shr(96, node)
            _red := and(shr(95, node), 1)
            _parent := and(shr(64, node), UINT31_MASK)
            _left := and(shr(32, node), UINT31_MASK)
            _right := and(node, UINT31_MASK)
        }
    }

    function value(Node node) internal pure returns (uint256 _value) {
        ///@solidity memory-safe-assembly
        assembly {
            _value := shr(96, node)
        }
    }

    function red(Node node) internal pure returns (bool _red) {
        ///@solidity memory-safe-assembly
        assembly {
            _red := and(shr(95, node), 1)
        }
    }

    function parent(Node node) internal pure returns (uint256 _parent) {
        ///@solidity memory-safe-assembly
        assembly {
            _parent := and(shr(64, node), UINT31_MASK)
        }
    }

    function left(Node node) internal pure returns (uint256 _left) {
        ///@solidity memory-safe-assembly
        assembly {
            _left := and(shr(32, node), UINT31_MASK)
        }
    }

    function right(Node node) internal pure returns (uint256 _right) {
        ///@solidity memory-safe-assembly
        assembly {
            _right := and(node, UINT31_MASK)
        }
    }
}

// using {unpack, value, red, parent, left, right} for Node global;
using NodeType for Node global;
