// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {TestPlus as Test} from "solady-test/utils/TestPlus.sol";
import {Node, NodeType} from "../../src/lib/NodeType.sol";

contract NodeTypeTest is Test {
    function testCreateNode(uint160 value, bool red, uint32 parent, uint32 left, uint32 right) public {
        parent = uint32(bound(parent, 0, 2 ** 31 - 1));
        left = uint32(bound(left, 0, 2 ** 31 - 1));
        right = uint32(bound(right, 0, 2 ** 31 - 1));
        Node node = NodeType.createNode({_value: value, _red: red, _parent: parent, _left: left, _right: right});
        assertEq(node.value(), value, "value incorrect");
        assertEq(node.red(), red, "red incorrect");
        assertEq(node.parent(), parent, "parent incorrect");
        assertEq(node.left(), left, "left incorrect");
        assertEq(node.right(), right, "right incorrect");
        (uint256 _value, bool _red, uint256 _parent, uint256 _left, uint256 _right) = NodeType.unpack(node);
        assertEq(_value, value, "unpacked value incorrect");
        assertEq(_red, red, "unpacked red incorrect");
        assertEq(_parent, parent, "unpacked parent incorrect");
        assertEq(_left, left, "unpacked left incorrect");
        assertEq(_right, right, "unpacked right incorrect");
    }

    function testCreateNode() public {
        Node node = NodeType.createNode({_value: 1, _red: true, _parent: 2, _left: 3, _right: 4});
        assertEq(node.value(), 1, "value incorrect");
        assertEq(node.red(), true, "red incorrect");
        assertEq(node.parent(), 2, "parent incorrect");
        assertEq(node.left(), 3, "left incorrect");
        assertEq(node.right(), 4, "right incorrect");
        (uint256 _value, bool _red, uint256 _parent, uint256 _left, uint256 _right) = node.unpack();
        assertEq(_value, 1, "unpacked value incorrect");
        assertEq(_red, true, "unpacked red incorrect");
        assertEq(_parent, 2, "unpacked parent incorrect");
        assertEq(_left, 3, "unpacked left incorrect");
        assertEq(_right, 4, "unpacked right incorrect");
    }

    function testSafeCreateNode(uint160 value, bool red, uint256 parent, uint256 left, uint256 right) public {
        Node node;
        if (value > type(uint160).max || (parent | left | right) > (2 ** 31) - 1) {
            vm.expectRevert(NodeType.PackedValueTooLarge.selector);
            node = NodeType.safeCreateNode({_value: value, _red: red, _parent: parent, _left: left, _right: right});
        } else {
            node = NodeType.safeCreateNode({_value: value, _red: red, _parent: parent, _left: left, _right: right});
            assertEq(node.value(), value, "value incorrect");
            assertEq(node.red(), red, "red incorrect");
            assertEq(node.parent(), parent, "parent incorrect");
            assertEq(node.left(), left, "left incorrect");
            assertEq(node.right(), right, "right incorrect");
            (uint256 _value, bool _red, uint256 _parent, uint256 _left, uint256 _right) = node.unpack();
            assertEq(_value, value, "unpacked value incorrect");
            assertEq(_red, red, "unpacked red incorrect");
            assertEq(_parent, parent, "unpacked parent incorrect");
            assertEq(_left, left, "unpacked left incorrect");
            assertEq(_right, right, "unpacked right incorrect");
        }
    }

    function testSafeCreateNode() public {
        Node node = NodeType.safeCreateNode({_value: 1, _red: true, _parent: 2, _left: 3, _right: 4});
        assertEq(node.value(), 1, "value incorrect");
        assertEq(node.red(), true, "red incorrect");
        assertEq(node.parent(), 2, "parent incorrect");
        assertEq(node.left(), 3, "left incorrect");
        assertEq(node.right(), 4, "right incorrect");
        (uint256 _value, bool _red, uint256 _parent, uint256 _left, uint256 _right) = node.unpack();
        assertEq(_value, 1, "unpacked value incorrect");
        assertEq(_red, true, "unpacked red incorrect");
        assertEq(_parent, 2, "unpacked parent incorrect");
        assertEq(_left, 3, "unpacked left incorrect");
        assertEq(_right, 4, "unpacked right incorrect");

        vm.expectRevert(NodeType.PackedValueTooLarge.selector);
        node = NodeType.safeCreateNode({_value: 1, _red: true, _parent: 2, _left: 3, _right: 2 ** 31});
    }

    function testSetters() public {
        Node node = NodeType.createNode({_value: 1, _red: true, _parent: 2, _left: 3, _right: 4});
        Node _node = node.setValue(2);
        _assertAll(_node, 2, true, 2, 3, 4);
        _node = node.setRed(false);
        _assertAll(_node, 1, false, 2, 3, 4);
        _node = node.setRedUint(0);
        _assertAll(_node, 1, false, 2, 3, 4);
        _node = node.setRedUint(1);
        _assertAll(_node, 1, true, 2, 3, 4);
        _node = node.setParent(3);
        _assertAll(_node, 1, true, 3, 3, 4);
        _node = node.setLeft(4);
        _assertAll(_node, 1, true, 2, 4, 4);
        _node = node.setRight(5);
        _assertAll(_node, 1, true, 2, 3, 5);
    }

    function _assertAll(Node node, uint256 value, bool red, uint256 parent, uint256 left, uint256 right) internal {
        assertEq(node.value(), value, "value incorrect");
        assertEq(node.red(), red, "red incorrect");
        assertEq(node.parent(), parent, "parent incorrect");
        assertEq(node.left(), left, "left incorrect");
        assertEq(node.right(), right, "right incorrect");
        (uint256 _value, bool _red, uint256 _parent, uint256 _left, uint256 _right) = node.unpack();
        assertEq(_value, value, "unpacked value incorrect");
        assertEq(_red, red, "unpacked red incorrect");
        assertEq(_parent, parent, "unpacked parent incorrect");
        assertEq(_left, left, "unpacked left incorrect");
        assertEq(_right, right, "unpacked right incorrect");
    }
}
