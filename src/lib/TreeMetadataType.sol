// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

type TreeMetadata is uint256;

library TreeMetadataType {
    uint256 constant UINT32_MASK = 0xffffffff;
    uint256 constant NOT_TOTAL_NODES = 0xffffffff00000000;
    uint256 constant ROOT_SHIFT = 32;

    function createTreeMetadata(uint256 _root, uint256 _totalNodes)
        internal
        pure
        returns (TreeMetadata _treeMetadata)
    {
        ///@solidity memory-safe-assembly
        assembly {
            _treeMetadata := or(shl(ROOT_SHIFT, _root), _totalNodes)
        }
    }

    function safeCreateTreeMetadata(uint32 _root, uint32 _totalNodes)
        internal
        pure
        returns (TreeMetadata _treeMetadata)
    {
        ///@solidity memory-safe-assembly
        assembly {
            _treeMetadata := or(shl(ROOT_SHIFT, _root), _totalNodes)
        }
    }

    function unpack(TreeMetadata _treeMetadata) internal pure returns (uint32 _root, uint32 _totalNodes) {
        ///@solidity memory-safe-assembly
        assembly {
            _root := and(shr(ROOT_SHIFT, _treeMetadata), UINT32_MASK)
            _totalNodes := and(_treeMetadata, UINT32_MASK)
        }
    }

    function root(TreeMetadata _treeMetadata) internal pure returns (uint32 _root) {
        ///@solidity memory-safe-assembly
        assembly {
            _root := and(shr(ROOT_SHIFT, _treeMetadata), UINT32_MASK)
        }
    }

    function totalNodes(TreeMetadata _treeMetadata) internal pure returns (uint32 _totalNodes) {
        ///@solidity memory-safe-assembly
        assembly {
            _totalNodes := and(_treeMetadata, UINT32_MASK)
        }
    }

    function setRoot(TreeMetadata _treeMetadata, uint32 _root) internal pure returns (TreeMetadata _newTreeMetadata) {
        ///@solidity memory-safe-assembly
        assembly {
            _newTreeMetadata := or(shl(ROOT_SHIFT, _root), and(_treeMetadata, UINT32_MASK))
        }
    }

    function setTotalNodes(TreeMetadata _treeMetadata, uint32 _totalNodes)
        internal
        pure
        returns (TreeMetadata _newTreeMetadata)
    {
        ///@solidity memory-safe-assembly
        assembly {
            _newTreeMetadata := or(and(_treeMetadata, NOT_TOTAL_NODES), _totalNodes)
        }
    }
}

using TreeMetadataType for TreeMetadata global;
