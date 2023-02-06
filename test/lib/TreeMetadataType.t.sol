// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {TestPlus as Test} from "solady-test/utils/TestPlus.sol";
import {TreeMetadata, TreeMetadataType} from "../../src/lib/TreeMetadataType.sol";

contract TreeMetadataTypeTest is Test {
    function testCreateTreeMetadata(uint32 root, uint32 totalNodes) public {
        TreeMetadata treeMetadata = TreeMetadataType.createTreeMetadata(root, totalNodes);
        assertEq(treeMetadata.root(), root, "root incorrect");
        assertEq(treeMetadata.totalNodes(), totalNodes, "totalNodes incorrect");
        (uint256 _root, uint256 _totalNodes) = treeMetadata.unpack();
        assertEq(_root, root, "unpacked root incorrect");
        assertEq(_totalNodes, totalNodes, "unpacked totalNodes incorrect");
    }

    function testCreateTreeMetadata() public {
        TreeMetadata treeMetadata = TreeMetadataType.createTreeMetadata(1, 2);
        assertEq(treeMetadata.root(), 1, "root incorrect");
        assertEq(treeMetadata.totalNodes(), 2, "totalNodes incorrect");
        (uint256 _root, uint256 _totalNodes) = treeMetadata.unpack();
        assertEq(_root, 1, "unpacked root incorrect");
        assertEq(_totalNodes, 2, "unpacked totalNodes incorrect");
    }

    function testSafeCreateTreeMetadata(uint32 root, uint32 totalNodes) public {
        TreeMetadata treeMetadata = TreeMetadataType.safeCreateTreeMetadata(root, totalNodes);
        assertEq(treeMetadata.root(), root, "root incorrect");
        assertEq(treeMetadata.totalNodes(), totalNodes, "totalNodes incorrect");
        (uint256 _root, uint256 _totalNodes) = treeMetadata.unpack();
        assertEq(_root, root, "unpacked root incorrect");
        assertEq(_totalNodes, totalNodes, "unpacked totalNodes incorrect");
    }

    function testSafeCreateTreeMetadata() public {
        TreeMetadata treeMetadata = TreeMetadataType.safeCreateTreeMetadata(1, 2);
        assertEq(treeMetadata.root(), 1, "root incorrect");
        assertEq(treeMetadata.totalNodes(), 2, "totalNodes incorrect");
        (uint256 _root, uint256 _totalNodes) = treeMetadata.unpack();
        assertEq(_root, 1, "unpacked root incorrect");
        assertEq(_totalNodes, 2, "unpacked totalNodes incorrect");
    }

    function testSetters() public {
        TreeMetadata treeMetadata = TreeMetadataType.createTreeMetadata(1, 2);
        TreeMetadata _treeMetadata = treeMetadata.setRoot(3);
        _assertAll(_treeMetadata, 3, 2);
        _treeMetadata = treeMetadata.setTotalNodes(4);
        _assertAll(_treeMetadata, 1, 4);
    }

    function _assertAll(TreeMetadata treeMetadata, uint32 root, uint32 totalNodes) internal {
        assertEq(treeMetadata.root(), root, "root incorrect");
        assertEq(treeMetadata.totalNodes(), totalNodes, "totalNodes incorrect");
        (uint256 _root, uint256 _totalNodes) = treeMetadata.unpack();
        assertEq(_root, root, "unpacked root incorrect");
        assertEq(_totalNodes, totalNodes, "unpacked totalNodes incorrect");
    }
}
