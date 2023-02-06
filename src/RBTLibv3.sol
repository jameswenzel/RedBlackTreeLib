// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {uint2str} from "./Utils.sol";
import {Node, NodeType} from "./lib/NodeType.sol";
import {TreeMetadata, TreeMetadataType} from "./lib/TreeMetadataType.sol";
import {console} from "forge-std/console.sol";

library RedBlackTreeLib {
    // using LibBitmap for Tree;
    uint256 private constant EMPTY = 0;

    struct Tree {
        // nodes is accessed more frequently, so it comes first
        mapping(uint256 => Node) nodes;
        // user-defined-type containing two uint256s
        TreeMetadata treeMetadata;
    }

    function size(Tree storage self) internal view returns (uint256 totalNodes) {
        TreeMetadata treeMetadata;
        ///@solidity memory-safe-assembly
        assembly {
            // self is a pointer to the second slot of the Tree struct, which contains treeMetadata
            treeMetadata := sload(add(self.slot, 1))
        }
        return treeMetadata.totalNodes();
    }

    function getRoot(Tree storage self) internal view returns (uint256) {
        TreeMetadata rootMetadata;
        ///@solidity memory-safe-assembly
        assembly {
            rootMetadata := sload(add(self.slot, 1))
        }
        // this is the key of the nodes mapping to be looked up
        uint256 key = rootMetadata.root();
        // declare so we can use outside of assembly
        Node rootNode;
        ///@solidity memory-safe-assembly
        assembly {
            // mapping storage slot is keccak(h(k) . p) where h(k) is padded key and p is slot of mapping
            mstore(0, key)
            // add 1 to tree slot to get mapping slot
            mstore(0x20, self.slot)
            rootNode := sload(keccak256(0, 0x40))
        }
        return rootNode.value();
    }

    function getKey(Tree storage self, uint256 value) internal view returns (uint256) {
        require(value != EMPTY, "value != EMPTY");
        uint256 nodesSlot;
        assembly {
            nodesSlot := self.slot
        }
        uint256 probe = self.treeMetadata.root();
        while (probe != EMPTY) {
            Node probeNode = _sloadNodeMap(nodesSlot, probe);
            uint256 probeValue = probeNode.value();
            if (value == probeValue) {
                return uint256(probe);
                // break;
            } else if (value < probeValue) {
                probe = probeNode.left();
            } else {
                probe = probeNode.right();
            }
        }
        return uint256(probe);
    }

    function getNode(Tree storage self, uint256 value)
        internal
        view
        returns (uint256 _returnKey, uint256 _parent, uint256 _left, uint256 _right, bool _red)
    {
        uint256 key = getKey(self, value);
        require(key != EMPTY, string.concat("RBT::getNode()# NOT EXISTS ", uint2str(key)));
        uint256 nodesSlot;
        assembly {
            nodesSlot := self.slot
        }
        Node keyNode = _sloadNodeMap(nodesSlot, key);
        (, bool red, uint256 parent, uint256 left, uint256 right) = keyNode.unpack();
        return (
            value,
            _sloadNodeMap(nodesSlot, parent).value(),
            _sloadNodeMap(nodesSlot, left).value(),
            _sloadNodeMap(nodesSlot, right).value(),
            red
        );
    }

    function getNodeByIndex(Tree storage self, uint256 key)
        internal
        view
        returns (uint256, uint256, uint256, uint256, bool)
    {
        // require(exists(self, value));
        require(key != EMPTY, string.concat("RBT::getNode()# NOT EXISTS ", uint2str(key)));
        // return(value, self._sloadNodeMap(nodesSlot, key).parent(), self._sloadNodeMap(nodesSlot, key).left(), self._sloadNodeMap(nodesSlot, key).right(), self._sloadNodeMap(nodesSlot, key).red());
        uint256 nodesSlot;
        assembly {
            nodesSlot := self.slot
        }
        Node keyNode = _sloadNodeMap(nodesSlot, key);
        (uint256 value, bool red, uint256 parent, uint256 left, uint256 right) = keyNode.unpack();
        return (
            value,
            _sloadNodeMap(nodesSlot, parent).value(),
            _sloadNodeMap(nodesSlot, left).value(),
            _sloadNodeMap(nodesSlot, right).value(),
            red
        );
    }

    function exists(Tree storage self, uint256 value) internal view returns (bool) {
        return (value != EMPTY) && (getKey(self, value) != EMPTY);
        // return (value != EMPTY) && self.totalNodes != EMPTY ;
    }

    function rotateLeft(Tree storage self, uint256 key) private {
        uint256 nodesSlot;
        assembly {
            nodesSlot := self.slot
        }
        Node keyNode = _sloadNodeMap(nodesSlot, key);
        uint256 cursor = keyNode.right();
        Node cursorNode = _sloadNodeMap(nodesSlot, cursor);
        uint256 keyParent = keyNode.parent();
        uint256 cursorLeft = cursorNode.left();
        keyNode = keyNode.setRight(cursorLeft);
        if (cursorLeft != EMPTY) {
            _supdateNodeMap(nodesSlot, cursorLeft, key, NodeType.setParent);
        }
        cursorNode = cursorNode.setParent(keyParent);
        if (keyParent == EMPTY) {
            self.treeMetadata = self.treeMetadata.setRoot(cursor);
        } else if (key == _sloadNodeMap(nodesSlot, keyParent).left()) {
            _supdateNodeMap(nodesSlot, keyParent, cursor, NodeType.setLeft);
        } else {
            _supdateNodeMap(nodesSlot, keyParent, cursor, NodeType.setRight);
        }
        _sstoreNodeMap(nodesSlot, cursor, cursorNode.setLeft(key));
        _sstoreNodeMap(nodesSlot, key, keyNode.setParent(cursor));
    }

    function rotateRight(Tree storage self, uint256 key) private {
        uint256 nodesSlot;
        assembly {
            nodesSlot := self.slot
        }
        Node keyNode = _sloadNodeMap(nodesSlot, key);
        uint256 cursor = keyNode.left();
        Node cursorNode = _sloadNodeMap(nodesSlot, cursor);
        uint256 keyParent = keyNode.parent();
        uint256 cursorRight = cursorNode.right();
        keyNode = keyNode.setLeft(cursorRight);
        if (cursorRight != EMPTY) {
            _supdateNodeMap(nodesSlot, cursorRight, key, NodeType.setParent);
        }
        cursorNode = cursorNode.setParent(keyParent);
        if (keyParent == EMPTY) {
            self.treeMetadata = self.treeMetadata.setRoot(cursor);
        } else if (key == _sloadNodeMap(nodesSlot, keyParent).right()) {
            _supdateNodeMap(nodesSlot, keyParent, cursor, NodeType.setRight);
        } else {
            _supdateNodeMap(nodesSlot, keyParent, cursor, NodeType.setLeft);
        }
        _sstoreNodeMap(nodesSlot, cursor, cursorNode.setRight(key));
        _sstoreNodeMap(nodesSlot, key, keyNode.setParent(cursor));
    }

    function insertFixup(Tree storage self, uint256 key) private {
        uint256 nodesSlot;
        assembly {
            nodesSlot := self.slot
        }
        Node keyNode = _sloadNodeMap(nodesSlot, key);
        uint256 keyParent = keyNode.parent();
        uint256 cursor;
        while (key != self.treeMetadata.root() && _sloadNodeMap(nodesSlot, keyParent).red()) {
            Node keyParentNode = _sloadNodeMap(nodesSlot, keyParent);
            uint256 keyParentNodeParent = keyParentNode.parent();
            Node keyParentNodeParentNode = _sloadNodeMap(nodesSlot, keyParentNodeParent);
            if (keyParent == keyParentNodeParentNode.left()) {
                cursor = keyParentNodeParentNode.right();
                if (_sloadNodeMap(nodesSlot, cursor).red()) {
                    _supdateNodeMap(nodesSlot, keyParent, false);
                    _supdateNodeMap(nodesSlot, cursor, false);
                    keyParentNodeParentNode = keyParentNodeParentNode.setRed(true);
                    _sstoreNodeMap(nodesSlot, keyParentNodeParent, keyParentNodeParentNode);
                    key = keyParentNodeParent;
                } else {
                    if (key == keyParentNode.right()) {
                        key = keyParent;
                        rotateLeft(self, key);
                    }
                    keyParent = _sloadNodeMap(nodesSlot, key).parent();

                    keyParentNode = _supdateNodeMap(nodesSlot, keyParent, false);
                    keyParentNodeParent = keyParentNode.parent();

                    _supdateNodeMap(nodesSlot, keyParentNodeParent, true);
                    rotateRight(self, keyParentNodeParent);
                }
            } else {
                // if keyParent on right side
                cursor = keyParentNodeParentNode.left();
                if (_sloadNodeMap(nodesSlot, cursor).red()) {
                    _supdateNodeMap(nodesSlot, keyParent, false);
                    _supdateNodeMap(nodesSlot, cursor, false);
                    _sstoreNodeMap(nodesSlot, keyParentNodeParent, keyParentNodeParentNode.setRed(true));
                    key = keyParentNodeParent;
                } else {
                    if (key == keyParentNode.left()) {
                        key = keyParent;
                        rotateRight(self, key);
                    }
                    keyParent = _sloadNodeMap(nodesSlot, key).parent();

                    keyParentNode = _supdateNodeMap(nodesSlot, keyParent, false);
                    keyParentNodeParent = keyParentNode.parent();
                    _supdateNodeMap(nodesSlot, keyParentNodeParent, true);
                    rotateLeft(self, keyParentNodeParent);
                }
            }
            keyNode = _sloadNodeMap(nodesSlot, key);
            keyParent = keyNode.parent();
        }
        uint256 root = self.treeMetadata.root();
        _supdateNodeMap(nodesSlot, root, false);
    }

    function insert(Tree storage self, uint160 value) internal {
        // console.log("inserting",value);
        require(value != EMPTY, "value != EMPTY");
        require(!exists(self, value), "No Duplicates! ");
        uint256 cursor = EMPTY;
        TreeMetadata treeMetadata = self.treeMetadata;
        uint256 probe = treeMetadata.root();
        // print(self);

        uint256 nodesSlot;
        assembly {
            nodesSlot := self.slot
        }
        while (probe != EMPTY) {
            cursor = probe;
            Node probeNode = _sloadNodeMap(nodesSlot, probe);
            if (value < probeNode.value()) {
                probe = probeNode.left();
            } else {
                probe = probeNode.right();
            }
        }
        uint256 newNodeIdx;
        unchecked {
            newNodeIdx = treeMetadata.totalNodes() + 1;
        }
        treeMetadata = treeMetadata.setTotalNodes(newNodeIdx);
        self.treeMetadata = treeMetadata;
        _sstoreNodeMap(
            nodesSlot,
            newNodeIdx,
            NodeType.createNode({_value: value, _red: true, _parent: cursor, _left: EMPTY, _right: EMPTY})
        );
        Node cursorNode = _sloadNodeMap(nodesSlot, cursor);
        if (cursor == EMPTY) {
            self.treeMetadata = treeMetadata.setRoot(newNodeIdx);
        } else if (value < cursorNode.value()) {
            // TODO: maybe use supdate
            _sstoreNodeMap(nodesSlot, cursor, cursorNode.setLeft(newNodeIdx));
        } else {
            _sstoreNodeMap(nodesSlot, cursor, cursorNode.setRight(newNodeIdx));
        }

        insertFixup(self, newNodeIdx);
    }

    function replaceParent(Tree storage self, uint256 a, uint256 b) private {
        uint256 nodesSlot;
        assembly {
            nodesSlot := self.slot
        }
        uint256 bParent = _sloadNodeMap(nodesSlot, b).parent();
        _supdateNodeMap(nodesSlot, a, bParent, NodeType.setParent);
        if (bParent == EMPTY) {
            self.treeMetadata = self.treeMetadata.setRoot(a);
        } else {
            Node bParentNode = _sloadNodeMap(nodesSlot, bParent);
            if (b == bParentNode.left()) {
                _sstoreNodeMap(nodesSlot, bParent, bParentNode.setLeft(a));
            } else {
                _sstoreNodeMap(nodesSlot, bParent, bParentNode.setRight(a));
            }
        }
    }

    function removeFixup(Tree storage self, uint256 key) private {
        uint256 nodesSlot;
        assembly {
            nodesSlot := self.slot
        }
        // console.log("removeFixup()#",key,self._sloadNodeMap(nodesSlot, key).value());
        uint256 cursor;
        while (key != self.treeMetadata.root() && !_sloadNodeMap(nodesSlot, key).red()) {
            // console.log("removeFixup()# debug 1");
            Node keyNode = _sloadNodeMap(nodesSlot, key);
            uint256 keyParent = keyNode.parent();
            Node keyParentNode = _sloadNodeMap(nodesSlot, keyParent);
            if (key == keyParentNode.left()) {
                cursor = keyParentNode.right();
                Node cursorNode = _sloadNodeMap(nodesSlot, cursor);
                if (cursorNode.red()) {
                    cursorNode = cursorNode.setRed(false);
                    _sstoreNodeMap(nodesSlot, cursor, cursorNode);
                    keyParentNode = keyParentNode.setRed(true);
                    _sstoreNodeMap(nodesSlot, keyParent, keyParentNode);
                    rotateLeft(self, keyParent);
                    // must reload keyparent after rotating
                    keyParentNode = _sloadNodeMap(nodesSlot, keyParent);
                    cursor = keyParentNode.right();
                    cursorNode = _sloadNodeMap(nodesSlot, cursor);
                }
                if (
                    !_sloadNodeMap(nodesSlot, cursorNode.left()).red()
                        && !_sloadNodeMap(nodesSlot, cursorNode.right()).red()
                ) {
                    cursorNode = cursorNode.setRed(true);
                    _sstoreNodeMap(nodesSlot, cursor, cursorNode);
                    key = keyParent;
                } else {
                    if (!_sloadNodeMap(nodesSlot, cursorNode.right()).red()) {
                        _supdateNodeMap(nodesSlot, cursorNode.left(), false);
                        cursorNode = cursorNode.setRed(true);
                        _sstoreNodeMap(nodesSlot, cursor, cursorNode);
                        rotateRight(self, cursor);
                        keyParentNode = _sloadNodeMap(nodesSlot, keyParent);
                        cursor = keyParentNode.right();
                        cursorNode = _sloadNodeMap(nodesSlot, cursor);
                    }
                    // reload in case it's been modified by rotating
                    // keyParentNode = _sloadNodeMap(nodesSlot, keyParent);
                    cursorNode = cursorNode.setRed(keyParentNode.red());
                    _sstoreNodeMap(nodesSlot, cursor, cursorNode);
                    keyParentNode = keyParentNode.setRed(false);
                    _sstoreNodeMap(nodesSlot, keyParent, keyParentNode);

                    _supdateNodeMap(nodesSlot, cursorNode.right(), false);
                    rotateLeft(self, keyParent);
                    key = self.treeMetadata.root();
                }
            } else {
                cursor = _sloadNodeMap(nodesSlot, keyParent).left();
                Node cursorNode = _sloadNodeMap(nodesSlot, cursor);
                if (cursorNode.red()) {
                    cursorNode = cursorNode.setRed(false);
                    _sstoreNodeMap(nodesSlot, cursor, cursorNode);
                    _sstoreNodeMap(nodesSlot, keyParent, keyParentNode.setRed(true));
                    rotateRight(self, keyParent);
                    keyParentNode = _sloadNodeMap(nodesSlot, keyParent);
                    cursor = keyParentNode.left();
                    cursorNode = _sloadNodeMap(nodesSlot, cursor);
                }
                if (
                    !_sloadNodeMap(nodesSlot, cursorNode.right()).red()
                        && !_sloadNodeMap(nodesSlot, cursorNode.left()).red()
                ) {
                    cursorNode = cursorNode.setRed(true);
                    _sstoreNodeMap(nodesSlot, cursor, cursorNode);
                    key = keyParent;
                } else {
                    if (!_sloadNodeMap(nodesSlot, cursorNode.left()).red()) {
                        _supdateNodeMap(nodesSlot, cursorNode.right(), false); //, NodeType.setRedUint
                        cursorNode = cursorNode.setRed(true);
                        _sstoreNodeMap(nodesSlot, cursor, cursorNode);
                        rotateLeft(self, cursor);
                        keyParentNode = _sloadNodeMap(nodesSlot, keyParent);
                        cursor = keyParentNode.left();
                        cursorNode = _sloadNodeMap(nodesSlot, cursor);
                    }
                    cursorNode = cursorNode.setRed(keyParentNode.red());
                    _sstoreNodeMap(nodesSlot, cursor, cursorNode);
                    keyParentNode = keyParentNode.setRed(false);
                    _sstoreNodeMap(nodesSlot, keyParent, keyParentNode);
                    _supdateNodeMap(nodesSlot, cursorNode.left(), false);
                    rotateRight(self, keyParent);
                    key = self.treeMetadata.root();
                }
            }
        }
        _supdateNodeMap(nodesSlot, key, false);
    }

    function remove(Tree storage self, uint256 value) internal {
        require(value != EMPTY);
        uint256 probe;
        uint256 cursor;
        uint256 key = getKey(self, value);
        uint256 nodesSlot;
        assembly {
            nodesSlot := self.slot
        }
        Node keyNode = _sloadNodeMap(nodesSlot, key);
        Node cursorNode;
        if (keyNode.left() == EMPTY || keyNode.right() == EMPTY) {
            cursor = key;
            cursorNode = _sloadNodeMap(nodesSlot, cursor);
        } else {
            cursor = keyNode.right();
            cursorNode = _sloadNodeMap(nodesSlot, cursor);
            while (cursorNode.left() != EMPTY) {
                cursor = cursorNode.left();
                cursorNode = _sloadNodeMap(nodesSlot, cursor);
            }
        }
        if (cursorNode.left() != EMPTY) {
            probe = cursorNode.left();
        } else {
            probe = cursorNode.right();
        }
        uint256 yParent = cursorNode.parent();
        _supdateNodeMap(nodesSlot, probe, yParent, NodeType.setParent);

        TreeMetadata treeMetadata = self.treeMetadata;

        if (yParent != EMPTY) {
            Node yParentNode = _sloadNodeMap(nodesSlot, yParent);
            if (cursor == yParentNode.left()) {
                _sstoreNodeMap(nodesSlot, yParent, yParentNode.setLeft(probe));
            } else {
                _sstoreNodeMap(nodesSlot, yParent, yParentNode.setRight(probe));
            }
        } else {
            treeMetadata = treeMetadata.setRoot(probe);
            self.treeMetadata = treeMetadata;
        }
        bool doFixup = !_sloadNodeMap(nodesSlot, cursor).red();
        if (cursor != key) {
            replaceParent(self, cursor, key);
            keyNode = _sloadNodeMap(nodesSlot, key);
            cursorNode = _sloadNodeMap(nodesSlot, cursor).setLeft(keyNode.left());
            cursorNode = cursorNode.setRight(keyNode.right());
            {
                uint256 cursorLeft = cursorNode.left();
                uint256 cursorRight = cursorNode.right();
                _supdateNodeMap(nodesSlot, cursorLeft, cursor, NodeType.setParent);
                _supdateNodeMap(nodesSlot, cursorRight, cursor, NodeType.setParent);
            }
            _sstoreNodeMap(nodesSlot, cursor, cursorNode.setRed(_sloadNodeMap(nodesSlot, key).red()));
            (cursor, key) = (key, cursor);
            cursorNode = _sloadNodeMap(nodesSlot, cursor);
        }
        if (doFixup) {
            // todo: can this modify cursor node?
            removeFixup(self, probe);
        }
        // refresh tree metadata
        treeMetadata = self.treeMetadata;
        uint256 last = treeMetadata.totalNodes();
        Node lastNode = _sloadNodeMap(nodesSlot, last);
        if (_sloadNodeMap(nodesSlot, cursor).value() != lastNode.value()) {
            _sstoreNodeMap(nodesSlot, cursor, lastNode);
            uint256 lParent = lastNode.parent();
            Node lastParentNode = _sloadNodeMap(nodesSlot, lParent);
            if (lParent != EMPTY) {
                if (treeMetadata.totalNodes() == lastParentNode.left()) {
                    _sstoreNodeMap(nodesSlot, lParent, lastParentNode.setLeft(cursor));
                } else {
                    _sstoreNodeMap(nodesSlot, lParent, lastParentNode.setRight(cursor));
                }
            } else {
                treeMetadata = treeMetadata.setRoot(cursor);
            }
            if (lastNode.right() != EMPTY) {
                _supdateNodeMap(nodesSlot, lastNode.right(), cursor, NodeType.setParent);
            }
            if (lastNode.left() != EMPTY) {
                _supdateNodeMap(nodesSlot, lastNode.left(), cursor, NodeType.setParent);
            }
        }
        _sstoreNodeMap(nodesSlot, last, Node.wrap(0));
        // todo: could do unchecked, but this will prevent negative overflow when testing
        self.treeMetadata = treeMetadata.setTotalNodes(treeMetadata.totalNodes() - 1);
    }

    ///@dev use assembly to calculate the slot for a node and load it
    ///TODO: consider returning slot value to re-use with other helpers
    function _sloadNodeMap(uint256 slot, uint256 key) private view returns (Node _node) {
        assembly {
            mstore(0, key)
            mstore(0x20, slot)
            _node := sload(keccak256(0, 0x40))
        }
    }

    ///@dev use assembly to calculate the slot for a node and store it
    function _sstoreNodeMap(uint256 slot, uint256 key, Node val) private {
        assembly {
            mstore(0, key)
            mstore(0x20, slot)
            sstore(keccak256(0, 0x40), val)
        }
    }

    ///@dev sload directly from a slot once it's been calculated
    function _sloadNodeMap(uint256 finalSlot) private view returns (Node _node) {
        assembly {
            _node := sload(finalSlot)
        }
    }

    ///@dev sstore direclty to a slot once it's been calculated
    function _sstoreNodeMap(uint256 finalSlot, Node val) private {
        assembly {
            sstore(finalSlot, val)
        }
    }

    ///@dev load, update, store, and return a Node from a slot and key, given an update value and an updater function
    function _supdateNodeMap(
        uint256 slot,
        uint256 key,
        uint256 update,
        function(Node, uint256) internal returns (Node) fn
    ) internal returns (Node) {
        Node val;
        uint256 finalSlot;
        assembly {
            mstore(0, key)
            mstore(0x20, slot)
            finalSlot := keccak256(0, 0x40)
            val := sload(finalSlot)
        }
        val = fn(val, update);
        assembly {
            sstore(finalSlot, val)
        }
        return val;
    }

    ///@dev setRed-specific version of _supdateNodeMap
    function _supdateNodeMap(uint256 slot, uint256 key, bool red) internal returns (Node) {
        Node val;
        uint256 finalSlot;
        assembly {
            mstore(0, key)
            mstore(0x20, slot)
            finalSlot := keccak256(0, 0x40)
            val := sload(finalSlot)
        }
        val = val.setRed(red);
        assembly {
            sstore(finalSlot, val)
        }
        return val;
    }

    function print(Tree storage self) internal view {
        console.log("--------- root", self.treeMetadata.root(), " totalNodes", self.treeMetadata.totalNodes());
        uint256 _size = self.treeMetadata.totalNodes();
        for (uint256 key; key <= _size; key++) {
            console.log(
                string.concat(
                    uint2str(key),
                    " ",
                    self.nodes[key].red() ? "R" : "B",
                    " ",
                    uint2str(self.nodes[key].parent()),
                    " ",
                    uint2str(self.nodes[key].left()),
                    " ",
                    uint2str(self.nodes[key].right()),
                    " ",
                    uint2str(self.nodes[key].value()),
                    " "
                )
            );
        }
        console.log("------------------");
    }

    function printNodeByIndex(Tree storage self, uint256 key) internal view {
        console.log(
            string.concat(
                uint2str(key),
                " ",
                self.nodes[key].red() ? "R" : "B",
                " ",
                uint2str(self.nodes[key].parent()),
                " ",
                uint2str(self.nodes[key].left()),
                " ",
                uint2str(self.nodes[key].right()),
                " ",
                uint2str(self.nodes[key].value()),
                " "
            )
        );
    }

    function printNode(Tree storage self, uint256 val) internal view {
        uint256 key = getKey(self, val);
        console.log(
            string.concat(
                uint2str(key),
                " ",
                self.nodes[key].red() ? "R" : "B",
                " ",
                uint2str(self.nodes[key].parent()),
                " ",
                uint2str(self.nodes[key].left()),
                " ",
                uint2str(self.nodes[key].right()),
                " ",
                uint2str(self.nodes[key].value()),
                " "
            )
        );
    }
}
